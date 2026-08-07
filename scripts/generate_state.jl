#!/usr/bin/env julia
# Generate `docs/STATE.md` — what the system IS, right now, derived from the code.
#
#     julia --project=. scripts/generate_state.jl          # write docs/STATE.md
#     julia --project=. scripts/generate_state.jl --check   # exit 1 if stale
#
# WHY THIS EXISTS
#
# In AI-assisted development no session can hold all the knowledge, so each one
# writes a DELTA: a corrected sentence, a dated paragraph, a new memory. The
# deltas are individually right and never integrate, and after a few hundred of
# them no reader — human or agent — can state the present. The tree's own history
# is the proof:
#
#   * `CLAUDE.md`'s split-step operator list said FIVE operators, was corrected
#     to SEVEN on 2026-08-04, and the real number is NINE. Two sessions each
#     appended a delta to a hand-copied list.
#   * The same file said "the 3 sibling converters delegate to it"; there are
#     four files and seven call sites.
#   * 158 documents were marked FROZEN on 2026-08-04 because dating them was
#     cheaper than making them true. That is the correct move and it is also an
#     admission: nothing states the current state.
#
# THIS IS SSoT, APPLIED ONE LEVEL UP
#
# The repository already had Single Source of Truth, and it held. Measured
# 2026-08-05: exactly ONE line computes the B->p sign (`units.jl:73`) and all 20
# references delegate; `_outer_operators_fwd!` is the only definition of the
# substep chain. Not one VALUE was duplicated.
#
# What rotted was every DESCRIPTION of those values — "the 3 sibling converters"
# (four files, seven sites), the comment twenty lines above the function listing
# seven of its nine substeps, the same list in CLAUDE.md. SSoT says *one place
# defines it*. It does not say *every other mention must be generated from that
# place* — and a mention is a copy whether or not anyone calls it one. Prose is
# where SSoT quietly stops applying, and prose is what a reader actually reads.
#
# So: a hand-written "current state" document is exactly the artifact that cannot
# be maintained, because writing it requires the knowledge nobody has. This file
# does not write one. **It derives one** — SSoT extended from the declaration to
# the description. Every section below names the code it
# reads. Regenerating costs one command, and `--check` makes a stale copy a test
# failure rather than a thing a future session discovers by being misled.
#
# WHAT BELONGS HERE
#
# Only facts DERIVED from the code, where the derivation is mechanical. A fact
# that needs judgement (why a design is the way it is, what a measurement means)
# belongs in CLAUDE.md or a memory, and those stay hand-written on purpose. The
# division is the point: **derive what is checkable, curate what is not.**

using SpinorBEC
using SpinorBEC: H_TERMS_CANONICAL_ORDER
using InteractiveUtils

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUT = joinpath(ROOT, "docs", "STATE.md")

# ---------------------------------------------------------------- helpers

readsrc(rel) = read(joinpath(ROOT, rel), String)

"Line number of the first line matching `pat` in `rel`, or 0."
function lineno(rel, pat)
    for (n, l) in enumerate(eachline(joinpath(ROOT, rel)))
        occursin(pat, l) && return n
    end
    0
end

"Body of the first `function <name>(` … matching `end` at column 1."
function funcbody(rel, name)
    lines = readlines(joinpath(ROOT, rel))
    i = findfirst(l -> occursin(Regex("function\\s+" * name * "\\("), l), lines)
    i === nothing && return String[]
    j = findnext(l -> l == "end", lines, i)
    j === nothing && return String[]
    lines[i:j]
end

# ---------------------------------------------------------------- sections

"""
The forward outer-potential chain, read out of the function that issues it.

This is the fact that went wrong twice. It is derived by scanning
`_outer_operators_fwd!` for `@timeit_debug TIMER "<name>"` labels and the two
`_apply_*_step!` calls that carry no label, in source order — so adding a
substep updates this document, and no hand-maintained list can disagree with it.
"""
function split_step_chain()
    rel = "src/hamiltonian/integrator/split_step.jl"
    body = funcbody(rel, "_outer_operators_fwd!")
    isempty(body) && return (rel, 0, String[])
    ops = String[]
    for l in body
        m = match(r"@timeit_debug\s+TIMER\s+\"([a-z_0-9]+)\"", l)
        if m !== nothing
            push!(ops, m.captures[1])
            continue
        end
        m = match(r"^\s*_apply_([a-z_0-9]+)_step!\(", l)
        m !== nothing && push!(ops, m.captures[1])
    end
    (rel, lineno(rel, "function _outer_operators_fwd!"), unique(ops))
end

"""
Every HamTerm in the canonical registry order, with the file that DEFINES its struct.

Located by deriving the CamelCase type name from the registry Symbol
(`spin_c1` -> `SpinC1Term`) and finding `struct <Name>` in `src/`. Substring
matching on filenames was tried first and is wrong: `zeeman` matched
`spatial_zeeman.jl`, making two distinct terms look like one file, and `ddi`
matched `apply_ddi_step.jl` rather than the term's own declaration. The struct
definition is the one unambiguous anchor.
"""
function ham_terms()
    files = String[]
    for (root, _, fs) in walkdir(joinpath(ROOT, "src"))
        for f in fs
            endswith(f, ".jl") && push!(files, relpath(joinpath(root, f), ROOT))
        end
    end
    camel(sym) = join(uppercasefirst.(split(string(sym), "_")))
    rows = Tuple{String, String, String}[]
    for sym in H_TERMS_CANONICAL_ORDER
        # Case-INSENSITIVE, and the name reported is whatever the code actually
        # declares. A case-sensitive CamelCase guess got 12 of 14 and missed
        # `DDITerm` / `LHYTerm`, because acronyms stay uppercase — a convention
        # the generator should not have to know.
        want = lowercase(camel(sym) * "Term")
        found, home, ln = "(struct not found)", "", 0
        for f in files
            for (n, l) in enumerate(eachline(joinpath(ROOT, f)))
                m = match(r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)", l)
                m === nothing && continue
                if lowercase(m.captures[1]) == want
                    found, home, ln = m.captures[1], f, n
                    break
                end
            end
            ln > 0 && break
        end
        push!(rows, (string(sym), found, ln > 0 ? "$home:$ln" : "(struct not found)"))
    end
    rows
end

"The one expression in `src/` that combines `g_F` with the Bohr magneton."
function sign_declaration()
    hits = String[]
    for (root, _, files) in walkdir(joinpath(ROOT, "src"))
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            for (n, l) in enumerate(eachline(path))
                occursin("BOHR_MAGNETON", l) && occursin(r"\bg_F\b", l) &&
                    !startswith(strip(l), "#") &&
                    push!(hits, relpath(path, ROOT) * ":" * string(n))
            end
        end
    end
    hits
end

"Every function that turns a lab magnetic field into the dimensionless `p`."
function bfield_converters()
    hits = String[]
    for (root, _, files) in walkdir(joinpath(ROOT, "src"))
        for f in files
            endswith(f, ".jl") || continue
            p = joinpath(root, f)
            rel = relpath(p, ROOT)
            for (n, l) in enumerate(eachline(p))
                occursin("bfield_to_p", l) || continue
                startswith(strip(l), "#") && continue
                occursin(r"^\s*[`\"]", strip(l)) && continue
                push!(hits, "$rel:$n")
            end
        end
    end
    hits
end

"Accepted top-level YAML keys and pipeline step kinds, from the schema itself."
function schema_surface()
    top = sort(collect(SpinorBEC.TOP_LEVEL_KEYS))
    steps = sort(collect(keys(SpinorBEC.STEP_SCHEMAS)))
    (top, steps)
end

"Retired YAML keys, from the migration table that `test_docs_examples_avoid_removed_keys.jl` gates."
function retired_keys()
    rel = "docs/reference/yaml_schema_reference.md"
    lines = readlines(joinpath(ROOT, rel))
    i = findfirst(l -> occursin("Legacy aliases", l), lines)
    i === nothing && return (rel, Tuple{String, String}[])
    rows = Tuple{String, String}[]
    for l in lines[i:end]
        startswith(l, "|") || continue
        c = strip.(split(l, "|"; keepempty=false))
        length(c) >= 2 || continue
        (startswith(c[1], "removed key") || all(x -> all(∈("-: "), x), c)) && continue
        push!(rows, (c[1], c[2]))
    end
    (rel, rows)
end

"""
Test-file counts per tier list, obtained by EVALUATING `_tiers.jl`.

The first version scraped the source with `const NAME = [(.*?)]` and was wrong on
three of four lists — `CI_EXTRA` 90 against a true 113, `FULL_EXTRA` 33 against
71 — because the non-greedy match stops at the first `]` CHARACTER, and one sits
inside a comment in the list. `assert_nondegenerate` did not catch it: a floor
catches COLLAPSE, not CORRUPTION, and 90 is a perfectly healthy-looking number.

**A regex over source is a second implementation of the language's grammar** —
the same duplication this document exists to remove, one level down. Evaluate
instead: include the file into a private module and take `length`. That also
makes `ORACLE_TESTS` and `INTEGRATION_TESTS` derivable, which no text scan could
count because they are `filter(...)` expressions.
"""
function tier_counts()
    rel = "test/_tiers.jl"
    m = Module(:TiersProbe)
    Core.eval(m, :(using SpinorBEC))
    Base.include(m, joinpath(ROOT, rel))
    names = (:FAST_TESTS, :CI_EXTRA, :FULL_EXTRA, :PHYSICS_TESTS,
        :ORACLE_TESTS, :INTEGRATION_TESTS)
    (rel, [(string(n), length(getfield(m, n))) for n in names if isdefined(m, n)])
end

"""
Validation-ladder levels and where their instrument actually lives.

Levels are named by the FILENAME the ladder promises, then located by walking
`test/`. A hardcoded relative path here is a delta of exactly the kind this
document exists to remove: the first version guessed `test/test_lhy_level8_unit.jl`,
the file lives at `test/hamiltonian/test_lhy_level8_unit.jl`, and the generator
reported a present instrument as MISSING.
"""
function ladder()
    want = [
        (0, "test_level0_gpu_cpu_consistency.jl"),
        (1, "test_level1_scalar_exact.jl"),
        (2, "test_level2_strang_convergence.jl"),
        (3, "test_level3_zeeman_only.jl"),
        (4, "test_level4_f1_phase_emergence.jl"),
        (4, "test_level4_general_F_phase_emergence.jl"),
        (8, "test_lhy_level8_unit.jl"),
        (10, "test_level10_hpsi_self_consistency.jl"),
        (11, "test_level11_convergence_sweep.jl"),
        (12, "test_level12_production_audit.jl"),
    ]
    index = Dict{String, String}()
    for (root, _, files) in walkdir(joinpath(ROOT, "test"))
        for f in files
            haskey(index, f) || (index[f] = relpath(joinpath(root, f), ROOT))
        end
    end
    [(lvl, get(index, base, "**NOT FOUND anywhere under test/** ($base)")) for (lvl, base) in want]
end

# `find` is cheap and the marker set is the honest one: what the code itself
# admits is unfinished. Nothing else in the tree enumerates this.
"Files carrying an explicit unfinished-work marker, and how many each has."
function limit_markers()
    rows = Tuple{String, Int}[]
    for (root, dirs, files) in walkdir(joinpath(ROOT, "src"))
        for f in files
            endswith(f, ".jl") || continue
            p = joinpath(root, f)
            n = count(l -> occursin("KNOWN-LIMIT", l) || occursin("NOT IMPLEMENTED", uppercase(l)),
                readlines(p))
            n > 0 && push!(rows, (relpath(p, ROOT), n))
        end
    end
    sort(rows; by=r -> -r[2])
end

"""
The `src/solvers/` surface: what is there, listed by the filesystem.

`CLAUDE.md` restated this directory TWICE and the two disagreed with each other
(one omitted `spgpe`, the other named "embedded-adaptive" whose file was deleted
in `e037867c`), and both omitted `evaporation/`, `newton_cg.jl`,
`preconditioner.jl`, `convergence_metrics.jl`, `thermal_cfield.jl` and
`trapped_bdg.jl`. Two hand-written restatements of one directory in one file is
the disease in its purest form: neither was checked against the tree, and
nothing checked them against each other.
"""
function solver_surface()
    root = joinpath(ROOT, "src", "solvers")
    dirs, files = String[], String[]
    for e in sort(readdir(root))
        if isdir(joinpath(root, e))
            n = count(f -> endswith(f, ".jl"), readdir(joinpath(root, e)))
            push!(dirs, "$e/ ($n)")
        elseif endswith(e, ".jl")
            push!(files, e)
        end
    end
    (dirs, files)
end

"""
What `tol` actually bounds, and when it is even looked at.

`docs/reference/yaml_schema_reference.md` labelled `tol` as
"convergence threshold (`grad_norm`)" while the same table defaults `method` to
`itp` — where `tol` bounds the relative ENERGY change and is evaluated only
inside a `step % save_every == 0` guard. At the YAML default n_steps=100000 that
is 1000 steps apart, so a run can sit converged for 999 steps without noticing,
and a reader tuning `tol` against a gradient is tuning the wrong quantity.

Derived by reading the criterion line and the guard line out of the loop, so the
rendered condition IS the code's condition rather than a paraphrase of it.
"""
function gs_exit_contract()
    rel = "src/solvers/ground_state/itp_loop.jl"
    lines = readlines(joinpath(ROOT, rel))
    crit, crit_n = "", 0
    guard, guard_n = "", 0
    for (n, l) in enumerate(lines)
        if crit_n == 0 && occursin("converged = true", l)
            for k in (n - 1):-1:max(1, n - 6)
                if occursin(r"^\s*if ", lines[k])
                    crit, crit_n = strip(lines[k]), k
                    break
                end
            end
        end
        guard_n == 0 && occursin(r"^\s*if step % ", l) && ((guard, guard_n) = (strip(l), n))
    end
    reasons = String[]
    for l in eachline(joinpath(ROOT, "src", "solvers", "lbfgs", "driver.jl"))
        occursin("stop_reason = ", l) || continue
        append!(reasons, [m.match for m in eachmatch(r":[a-z_]+", l)])
    end
    (rel, crit, crit_n, guard, guard_n, unique(reasons))
end

"""
The cache-admission taxonomy and what audits it.

The reader's question is "when a cache hit is served, what actually checked it?"
and the answer is a RATIO, not a list: four sites admit a cached payload and one
re-derives its verdict. Neither number is stated anywhere else in the tree.

The provenance set is cross-checked against `admission_counts()`. That pair is
the load-bearing assertion: `_count_admission!` mints a key at runtime for an
unknown provenance instead of erroring, while the counter's initializer
hardcodes four — two lists maintained seventy lines apart, and agreeing IS the
check. Deterministic to read: a fresh `using SpinorBEC` never calls
`admit_payload`, so what comes back is the initializer.
"""
function admission_facts()
    body = readlines(joinpath(ROOT, "src", "model", "complete.jl"))
    prov = Tuple{String, String, Int}[]
    for (n, l) in enumerate(body)
        m = match(r"Admission\(\s*(true|false)\s*,\s*:([a-z_]+)", l)
        m === nothing && continue
        push!(prov, (m.captures[2], m.captures[1], n))
    end
    function callsites(fname)
        out = String[]
        for (root, _, fs) in walkdir(joinpath(ROOT, "src"))
            occursin(joinpath("src", "model"), root) && continue
            for f in fs
                endswith(f, ".jl") || continue
                path = joinpath(root, f)
                for (n, l) in enumerate(eachline(path))
                    startswith(strip(l), "#") && continue
                    occursin(Regex("\\b" * fname * "\\("), l) || continue
                    push!(out, relpath(path, ROOT) * ":" * string(n))
                end
            end
        end
        out
    end
    (prov, callsites("admit_payload"), callsites("verify_verdict"))
end

"""
Every key `artifact_id` folds into the digest, against `fieldnames(Stage)`.

Asserted as SET EQUALITY, both directions, not as a lower bound. A missing key
means a `Stage` input silently left the identity — the `_gs_cache_key` defect,
where a hand-listed dict was blind to inputs the same function passed to the
solver. An extra key means something not declared by `Stage` entered it. Both
are findings, and equality is self-defending: a key form this extractor misses
shows up as MISSING and refuses generation rather than passing quietly.
"""
function identity_keys()
    body = funcbody("src/model/identity.jl", "artifact_id")
    keys = String[]
    for l in body
        m = match(r"^\s*\"([a-z_]+)\"\s*=>", l)
        m === nothing || push!(keys, m.captures[1])
    end
    (sort(unique(keys)), sort(string.(collect(fieldnames(SpinorBEC.Stage)))))
end

"""
The ground-state knobs whose default differs by entry path.

The sharpest live trap this document carries: `m_lbfgs` is 20 in BOTH Julia
entries — `ground_state.jl` even holds a `# keep in sync with
find_ground_state_lbfgs default` comment — and 20 is the measured value (~9x
lower grad_norm floor, ~30 % fewer line-search backtracks vs 10 on Eu F=6+DDI
16^3). The YAML path defaults to **10**, so every production run that omits the
key gets the worse value. The sync obligation was written for the two Julia
entries and never extended to the path most runs take.
"""
function gs_knob_defaults()
    rows = Tuple{String, String, String, String}[]
    function sigdefault(rel, fname, key)
        body = funcbody(rel, fname)
        for l in body
            m = match(Regex("^\\s+" * key * "(::[^=]+)?=([^,]+),"), l)
            m === nothing || return strip(m.captures[2])
        end
        "—"
    end
    function yamlfallback(key)
        out = String[]
        for (root, _, fs) in walkdir(joinpath(ROOT, "src", "workflow", "experiments", "pipeline"))
            for f in fs
                endswith(f, ".jl") || continue
                for l in eachline(joinpath(root, f))
                    m = match(Regex("get\\(p, \\\"" * key * "\\\", ([^)]+)\\)"), l)
                    m === nothing || push!(out, strip(m.captures[1]))
                end
            end
        end
        isempty(out) ? "—" : join(unique(out), " / ")
    end
    function specdefault(key)
        spec = get(SpinorBEC.GS_SCHEMA, key, nothing)
        spec === nothing && return "—"
        d = spec.default
        d === nothing ? "—" : string(d)
    end
    for key in ("n_steps", "tol", "m_lbfgs")
        push!(
            rows,
            (key,
                sigdefault("src/solvers/ground_state.jl", "find_ground_state", key),
                sigdefault("src/solvers/lbfgs/driver.jl", "find_ground_state_lbfgs", key),
                yamlfallback(key) * " (schema `" * specdefault(key) * "`)"),
        )
    end
    rows
end

"""
Sizes and vocabularies obtained by INTROSPECTION, not by counting source text.

Every entry here was stated by hand in CLAUDE.md and every one was wrong on
2026-08-05 — `Workspace` "23+" parameters against 20, `AbstractPotential`
"12 subtypes" against 16, "22 named builders" against 26, `lhy.kind` listing 10
of 11 (omitting `spatial`, which the same file recommends elsewhere), the term
registry enumerated as 13 of 14, `RunResult` missing its first field. Each was
correct when written. None was ever re-derived.

Read from the loaded module, so they cannot disagree with the code.
"""
function introspected()
    P = Base.unwrap_unionall(SpinorBEC.Workspace).parameters
    pots = InteractiveUtils.subtypes(SpinorBEC.AbstractPotential)
    zoo = filter(n -> startswith(string(n), "init_psi_"), names(SpinorBEC))
    docs = filter(d -> isdir(joinpath(ROOT, "docs", d)), readdir(joinpath(ROOT, "docs")))
    [
        ("`Workspace` type parameters", string(length(P)),
            "`length(Base.unwrap_unionall(Workspace).parameters)`"),
        ("`AbstractPotential` subtypes", string(length(pots)),
            "`length(subtypes(AbstractPotential))`"),
        ("named `init_psi_*` builders", string(length(zoo)),
            "exported names of `SpinorBEC`"),
        ("`H_TERMS_CANONICAL_ORDER`", string(length(SpinorBEC.H_TERMS_CANONICAL_ORDER)),
            "the registry constant"),
        ("`LHY_KINDS`", string(length(SpinorBEC.LHY_KINDS)), "`src/model/specs.jl`"),
        ("`RunResult` fields", join(string.(fieldnames(SpinorBEC.RunResult)), ", "),
            "`fieldnames(RunResult)`"),
        ("`docs/` subdirectories", string(length(docs)), "`readdir(\"docs\")`"),
    ]
end

"""
How much of each `src/` subtree this document actually cites.

Reported as CITED FILES over TOTAL, not as a boolean. The first version asked
`occursin("src/\$d/", rendered)`, so a single citation of one file flipped all 14
files of `src/model/` from "not covered" to "covered" — a coverage report that
overstates itself the moment any section lands, which is worse than no report:
the section's whole purpose is that gaps stay visible.

A subtree with few cited files is not a defect. It is this document saying
plainly how little it knows about that area, so a reader does not read silence
as absence.
"""
function coverage(rendered)
    rows = Tuple{String, Int, Int}[]
    for d in sort(readdir(joinpath(ROOT, "src")))
        isdir(joinpath(ROOT, "src", d)) || continue
        total, cited = 0, 0
        for (root, _, fs) in walkdir(joinpath(ROOT, "src", d))
            for f in fs
                endswith(f, ".jl") || continue
                total += 1
                rel = relpath(joinpath(root, f), ROOT)
                occursin(rel, rendered) && (cited += 1)
            end
        end
        push!(rows, (d, cited, total))
    end
    rows
end

# ---------------------------------------------------------------- self-checks
#
# The staleness gate compares the committed document against a fresh derivation.
# That catches "the code moved and the document did not". It does NOT catch the
# opposite and worse failure: **a derivation that silently narrows.** If a regex
# stops matching, the section renders empty, someone regenerates, committed ==
# derived, and the gate is green about a document that now omits the fact it
# existed to carry — while still being titled "what this system is". A generated
# document that has quietly stopped deriving is worse than a hand-written one,
# because the hand-written one never claimed to be current.
#
# So every section asserts its own result is non-degenerate, and generation FAILS
# rather than emitting a thinner document. The floors are set from the measured
# value, low enough not to be brittle and high enough that a collapse cannot pass.
# This is the same positive control that caught five blind instruments on
# 2026-08-05: assert the population before reporting on it.

struct DegenerateDerivation <: Exception
    section::String
    detail::String
end
Base.showerror(io::IO, e::DegenerateDerivation) = print(io,
    "DegenerateDerivation in section \"", e.section, "\": ", e.detail,
    "\n\nThe derivation returned less than it must. Generation is REFUSED rather ",
    "than emitting a document that silently stopped carrying this fact. ",
    "Fix the derivation, or lower the floor deliberately and say why.")

"""
    extension_table()

Which package triggers each extension, and whether that trigger is a WEAK
dependency. Derived from `Project.toml` because the prose restating it was
wrong: CLAUDE.md called all four "weak-dep extensions" while CUDA sits in
`[deps]`. Loading is still lazy — `using SpinorBEC` does not pull CUDA in
(measured 2026-08-07: 0.7 s, `CUDA` absent from `Base.loaded_modules`) — so the
mismatch costs installation, not startup, and 74 of the CUDA stack's 77 artifact
entries are lazy. Recorded rather than "fixed": moving CUDA to `[weakdeps]` is a
user-facing packaging change and the saving is small.
"""
function extension_table()
    txt = readsrc("Project.toml")
    sect(name) = begin
        m = match(Regex("\\[" * name * "\\](.*?)(?=\\n\\[|\\z)", "s"), txt)
        if m === nothing
            String[]
        else
            [strip(split(l, "=")[1]) for l in split(m.captures[1], "\n") if occursin("=", l)]
        end
    end
    deps, weak = sect("deps"), sect("weakdeps")
    exts = Dict{String, String}()
    m = match(r"\[extensions\](.*?)(?=\n\[|\z)"s, txt)
    if m !== nothing
        for l in split(m.captures[1], "\n")
            occursin("=", l) || continue
            k, v = split(l, "="; limit=2)
            exts[strip(k)] = strip(replace(v, '"' => "", '[' => "", ']' => ""))
        end
    end
    rows = [(e, t, t in weak, t in deps) for (e, t) in sort(collect(exts))]
    (rows=rows, n_deps=length(deps), n_weak=length(weak))
end

function assert_nondegenerate(section, ok::Bool, detail)
    ok || throw(DegenerateDerivation(section, detail))
    nothing
end

# ---------------------------------------------------------------- render

function render()
    io = IOBuffer()
    p(s="") = println(io, s)

    p("# STATE — what this system is, derived from the code")
    p()
    p("> **GENERATED. Do not edit.** Regenerate with")
    p("> `julia --project=. scripts/generate_state.jl`, and")
    p("> `test/test_state_doc_is_current.jl` fails if this file and the tree disagree.")
    p(">")
    p("> **This is SSoT applied to DESCRIPTIONS.** The repo's value-level SSoT held")
    p("> perfectly — one line computes the B→p sign, one function defines the substep")
    p("> chain. What rotted was every prose restatement of them, because \"one place")
    p("> defines it\" does not imply \"every other mention is generated from it\".")
    p(">")
    p("> This file exists because deltas accumulate and nothing states the present.")
    p("> `CLAUDE.md`'s split-step list said 5 operators, was corrected to 7, and the")
    p("> real number is 9 — two sessions each appending to a hand-copied list. Every")
    p("> section here names the code it is read from, so it cannot drift without")
    p("> the gate going red.")
    p(">")
    p("> **What is NOT here:** anything needing judgement — why a design is what it")
    p("> is, what a measurement means, which convention is deliberate. That stays")
    p("> hand-written in `CLAUDE.md` and the memory store. Derive what is")
    p("> checkable; curate what is not.")
    p()

    rel, ln, ops = split_step_chain()
    assert_nondegenerate("split-step chain", length(ops) >= 5 && ln > 0,
        "derived $(length(ops)) substeps at line $ln; the chain has had 9 since 2026-08-05 " *
        "and cannot plausibly drop below 5 (diagonal, spin_mixing, singlet_pair, tensor, raman " *
        "are all unconditional in the source)")
    p("## Split-step: the forward outer-potential chain")
    p()
    p("Read from `_outer_operators_fwd!` (`$rel:$ln`), in source order.")
    p("**$(length(ops)) substeps.** Each auto-skips when its coupling is ≈ 0.")
    p()
    for (i, o) in enumerate(ops)
        p("$i. `$o`")
    end
    p()
    p("The backward half reverses this; the pair is the Strang sandwich, with `DDI`")
    p("at the centre for RTP. A prose list of this anywhere else is a copy and has")
    p("been wrong twice.")
    p()

    terms = ham_terms()
    n_lost = count(t -> t[3] == "(struct not found)", terms)
    assert_nondegenerate("Hamiltonian terms",
        length(terms) == length(H_TERMS_CANONICAL_ORDER) && n_lost == 0,
        "$(length(terms)) rows for $(length(H_TERMS_CANONICAL_ORDER)) registry entries, " *
        "$n_lost with no struct located — every registry symbol must resolve to a " *
        "`struct <Name>Term`")
    p("## Hamiltonian terms in the registry")
    p()
    p("`H_TERMS_CANONICAL_ORDER`, in order. **$(length(H_TERMS_CANONICAL_ORDER)) terms.**")
    p("Each declares its sign in one coefficient function in the file named.")
    p()
    p("| # | registry symbol | struct | defined at |")
    p("|---|---|---|---|")
    for (i, (sym, name, home)) in enumerate(terms)
        p("| $i | `$sym` | `$name` | `$home` |")
    end
    p()

    conv = bfield_converters()
    decl = sign_declaration()
    assert_nondegenerate("B → p declaration", length(decl) == 1 && length(conv) >= 8,
        "$(length(decl)) expressions compute the sign (must be exactly 1) and " *
        "$(length(conv)) references to `bfield_to_p` (there were 20 on 2026-08-05)")
    p("## The B → p sign")
    p()
    p("Declared **once**, at `$(only(decl))`, as `p ≡ -g_F μ_B B` (Kawaguchi-Ueda);")
    p("$(length(conv)) other references delegate to it. **The uniqueness is a GATE, not a")
    p("list** — `test/oracles/test_bfield_sign_declared_once.jl` fails if a second")
    p("expression in `src/` combines `g_F` with the Bohr magneton. This section used to")
    p("enumerate all $(length(conv)) sites; a derived list cannot rot but only describes,")
    p("whereas the gate refuses the violation. `linear_zeeman_p` carried the opposite")
    p("sign for two months because eight test files checked the VALUE and none checked")
    p("that there was only one of them.")
    p()

    sdirs, sfiles = solver_surface()
    assert_nondegenerate("solver surface",
        length(sdirs) >= 4 && length(sfiles) >= 12,
        "found $(length(sdirs)) subdirectories and $(length(sfiles)) top-level files " *
        "under src/solvers/ (expect >= 4 and >= 12)")
    p("## `src/solvers/` — what is actually there")
    p()
    p("**Subdirectories (.jl count):** " * join("`" .* sdirs .* "`", ", "))
    p()
    p("**Top-level files:** " * join("`" .* sfiles .* "`", ", "))
    p()
    p("`CLAUDE.md` restated this directory twice and the two restatements disagreed")
    p("with each other; both omitted `evaporation/` and five top-level files, and one")
    p("named a module whose file was deleted in `e037867c`. Two hand-written")
    p("restatements of one directory, in one file, neither checked against the tree")
    p("nor against each other.")
    p()

    erel, crit, critn, guard, guardn, reasons = gs_exit_contract()
    assert_nondegenerate("gs exit contract",
        !isempty(crit) && !isempty(guard) && occursin("tol", crit) &&
            !occursin("dpsi", crit) && length(reasons) >= 3,
        "criterion=[$crit] at $critn, guard=[$guard] at $guardn, " *
        "stop_reason values " * join(reasons, " "))
    p("## Ground-state exit contract: what `tol` bounds")
    p()
    p("ITP convergence, read from `$erel:$critn`:")
    p()
    p("```julia")
    p(crit)
    p("```")
    p()
    p("`dE` is `_relative_energy_change` — the relative **energy** change, not a")
    p("gradient norm. It is evaluated only inside `$guard` (`$erel:$guardn`), and")
    p("the YAML path sets `save_every = max(1, n_steps ÷ 100)`, so at the default")
    p("`n_steps=100000` the criterion is tested **1000 steps apart**. A run can be")
    p("converged for 999 steps without noticing. `dpsi` appears in the diagnostics")
    p("and NOT in the condition above — that absence is derived here, not")
    p("remembered.")
    p()
    p(
        "L-BFGS reports `stop_reason` ∈ " * join("`" .* reasons .* "`", ", ") *
        " (`src/solvers/lbfgs/driver.jl`), which is a different exit contract with a",
    )
    p("different meaning of `tol` (there it IS the gradient norm).")
    p()

    prov, adm_sites, ver_sites = admission_facts()
    prov_names = sort([x[1] for x in prov])
    counter_keys = sort(string.(collect(keys(SpinorBEC.admission_counts()))))
    hits = count(x -> x[2] == "true", prov)
    assert_nondegenerate("cache admission",
        prov_names == counter_keys && length(prov) >= 4 &&
            1 <= hits < length(prov) &&
            length(adm_sites) >= 4 && 1 <= length(ver_sites) <= length(adm_sites),
        "provenances [" * join(prov_names, ", ") * "] vs counter keys [" *
        join(counter_keys, ", ") * "]; $hits of $(length(prov)) are hits; " *
        "$(length(adm_sites)) admit sites, $(length(ver_sites)) verify sites")
    p("## Cache admission: what is served, and what verified it")
    p()
    p("| provenance | served as a hit | declared at |")
    p("|---|---|---|")
    for (name, hit, ln) in prov
        p("| `:$name` | $(hit == "true" ? "**yes**" : "no") | `src/model/complete.jl:$ln` |")
    end
    p()
    p("The provenance set is asserted EQUAL to `keys(admission_counts())`, both")
    p("directions. `_count_admission!` mints a key at runtime for an unknown")
    p("provenance rather than erroring, and the counter's initializer hardcodes the")
    p("four — two lists seventy lines apart, and their agreement is the only thing")
    p("checking either.")
    p()
    p(
        "**$(length(adm_sites)) sites admit a cached payload; $(length(ver_sites)) re-derives its verdict.**",
    )
    p()
    for site in adm_sites
        p("- admits: `$site`")
    end
    for site in ver_sites
        p("- **verifies**: `$site`")
    end
    p()
    p("Whether that ratio is a gap is judgement — `:unmarked` being a HIT is a dated")
    p("migration allowance argued at `src/model/complete.jl`, not an oversight — so")
    p("this section reports the counts and does not grade them.")
    p()

    idk, stagef = identity_keys()
    idk_s = join(idk, ", ")
    stagef_s = join(stagef, ", ")
    assert_nondegenerate("artifact identity",
        Set(idk) == union(Set(stagef), Set(["code_rev"])) && length(idk) >= 7,
        "artifact_id folds [$idk_s]; fieldnames(Stage) = [$stagef_s]. " *
        "These must be equal up to `code_rev`.")
    p("## Artifact identity: every key the digest covers")
    p()
    p("`artifact_id` (`src/model/identity.jl`) folds **$(length(idk))** keys:")
    p(join("`" .* idk .* "`", ", ") * ".")
    p()
    p("That set is exactly `fieldnames(Stage)` plus `code_rev`, asserted as an")
    p("EQUALITY in both directions — a missing key means a `Stage` input silently")
    p("left the identity, an extra one means something undeclared entered it. Set")
    p("equality proves no *field* is selected out; it does NOT prove content")
    p("completeness (`model_toml_dict` deliberately omits non-required slots equal")
    p("to their own default), and that qualification is judgement, not derived.")
    p()

    knobs = gs_knob_defaults()
    rowdesc = join([join(r, "|") for r in knobs], "  ;  ")
    assert_nondegenerate("gs knob defaults",
        length(knobs) == 3 && all(r -> r[2] != "—" && r[3] != "—", knobs),
        "resolved $(length(knobs)) knobs; rows " * rowdesc)
    p("## Ground-state knob defaults, by entry path")
    p()
    p("| knob | `find_ground_state` | `find_ground_state_lbfgs` | YAML fallback |")
    p("|---|---|---|---|")
    for (k, a, b, c) in knobs
        p("| `$k` | $a | $b | $c |")
    end
    p()
    p("**`m_lbfgs` is the live trap.** Both Julia entries default to 20 and")
    p("`ground_state.jl` carries a `# keep in sync with find_ground_state_lbfgs")
    p("default` comment; 20 is the MEASURED value (~9× lower grad_norm floor, ~30 %")
    p("fewer line-search backtracks against 10 on Eu F=6+DDI 16³). The YAML path")
    p("defaults to 10, so every production run that omits the key gets the worse")
    p("one. The sync obligation was written for the two Julia entries and never")
    p("extended to the path most runs take. Whether to change it is a decision, so")
    p("this section reports the disagreement and does not assert it away.")
    p()

    intro = introspected()
    assert_nondegenerate("introspected sizes",
        length(intro) >= 7 &&
            all(r -> !isempty(r[2]) && r[2] != "0", intro),
        "read $(length(intro)) introspected facts; values " *
        join([r[2] for r in intro], " / "))
    p("## Sizes and vocabularies, by introspection")
    p()
    p("Read from the loaded module. Every row below was stated by hand in `CLAUDE.md`")
    p("and every one was wrong on 2026-08-05 — each correct when written, none ever")
    p("re-derived. **Do not restate these anywhere.**")
    p()
    p("| what | value | read from |")
    p("|---|---|---|")
    for (what, val, how) in intro
        p("| $what | $val | $how |")
    end
    p()
    p("`LHY_KINDS`: " * join("`" .* string.(SpinorBEC.LHY_KINDS) .* "`", ", "))
    p()

    top, steps = schema_surface()
    assert_nondegenerate("YAML surface", length(top) >= 5 && length(steps) >= 2,
        "$(length(top)) top-level keys and $(length(steps)) step kinds; " *
        "`pipeline` + `scan` + the lab-units block are always present, and " *
        "`ground_state` / `dynamics` both exist")
    p("## YAML surface")
    p()
    p("**Top-level keys ($(length(top))):** " * join("`" .* top .* "`", ", "))
    p()
    p("**Pipeline step kinds ($(length(steps))):** " * join("`" .* steps .* "`", ", "))
    p()
    krel, kr = retired_keys()
    assert_nondegenerate("retired keys", length(kr) >= 8,
        "parsed $(length(kr)) rows from the migration table in $krel; there were 13 on " *
        "2026-08-05, and `test_docs_examples_avoid_removed_keys.jl` depends on this table")
    p("**Retired keys ($(length(kr)))** — from `$krel`. A LIVE document teaching one")
    p("of these fails `test/test_docs_examples_avoid_removed_keys.jl`.")
    p()
    p("| removed | replacement |")
    p("|---|---|")
    for (a, b) in kr
        # a literal `|` inside a cell breaks the markdown row
        p("| " * replace(a, "|" => "\\|") * " | " * replace(b, "|" => "\\|") * " |")
    end
    p()

    trel, tiers = tier_counts()
    # Floors per list, not a blanket `> 0`. The scraping bug produced 90/33 for
    # lists that really hold 113/71 — non-zero, plausible, and wrong. A floor
    # only catches corruption when it is set near the true value.
    want = Dict("FAST_TESTS" => 200, "CI_EXTRA" => 100, "FULL_EXTRA" => 50,
        "PHYSICS_TESTS" => 5, "ORACLE_TESTS" => 50, "INTEGRATION_TESTS" => 40)
    short = [t for t in tiers if t[2] < get(want, t[1], 1)]
    assert_nondegenerate("test tiers",
        length(tiers) >= 6 && isempty(short),
        "read $(length(tiers)) tier lists from $trel (expect >= 6); " *
        (isempty(short) ? "" : "below floor: " *
                               join(["$(t[1])=$(t[2])" for t in short], ", ")) *
        "; all counts " * join(["$(t[1])=$(t[2])" for t in tiers], " "))
    p("## Test tiers")
    p()
    p("File counts from `$trel`. Membership is explicit — no auto-discovery.")
    p()
    for (name, n) in tiers
        p("- `$name` — $n files")
    end
    p()

    lad = ladder()
    n_missing = count(r -> occursin("NOT FOUND", r[2]), lad)
    assert_nondegenerate("validation ladder", n_missing == 0,
        "$n_missing ladder instruments not found anywhere under test/ — either the file " *
        "was deleted (a real finding: record it in CLAUDE.md and remove the level here) " *
        "or the walk is broken")
    p("## Validation ladder — instruments present on disk")
    p()
    p("| level | instrument (located by walking `test/`) |")
    p("|---|---|")
    for (lvl, path) in lad
        p("| $lvl | `$path` |")
    end
    p()

    ext = extension_table()
    # Floor: four extensions are declared today. A regex that matched nothing
    # would report a tree with no GPU path at all, which reads as healthy.
    assert_nondegenerate("extension triggers",
        length(ext.rows) >= 4 && ext.n_deps >= 10 && ext.n_weak >= 3,
        "read $(length(ext.rows)) extensions, $(ext.n_deps) deps, " *
        "$(ext.n_weak) weakdeps from Project.toml (expect >= 4/10/3)")
    p("## Extensions and how their triggers are declared")
    p()
    p("Derived from `Project.toml`. CLAUDE.md called all four *weak-dep*")
    p("extensions; one is not. Loading is lazy either way — a bare")
    p("`using SpinorBEC` pulls in none of them — so the mismatch shows up at")
    p("install time, not startup.")
    p()
    p("| extension | trigger | in `[weakdeps]` | in `[deps]` |")
    p("|---|---|---|---|")
    for (e, t, w, d) in ext.rows
        p("| `$e` | `$t` | " * (w ? "yes" : "**no**") * " | " *
          (d ? "**yes**" : "no") * " |")
    end
    p()

    lims = limit_markers()
    assert_nondegenerate("unfinished markers", !isempty(lims),
        "no `KNOWN-LIMIT` / not-implemented marker found in src/; there were 13 in 8 files " *
        "on 2026-08-05, so an empty result means the scan broke, not that the work finished")
    p("## What the code says about itself is unfinished")
    p()
    p("Files carrying `KNOWN-LIMIT` or an explicit not-implemented marker —")
    p("**$(length(lims)) files, $(sum(last, lims; init=0)) markers.** This is the")
    p("only enumeration of it in the tree; prose elsewhere goes stale (a")
    p("`KNOWN-LIMIT` in `contact.jl` contradicted the function twenty lines below")
    p("it until 2026-08-04).")
    p()
    for (f, n) in lims
        p("- `$f` — $n")
    end
    p()

    body = String(take!(io))

    cov = coverage(body)
    io2 = IOBuffer()
    print(io2, body)
    q(s="") = println(io2, s)
    q("## What this document does NOT cover")
    q()
    q("Cited FILES over total, per `src/` subtree — not a boolean. A first version")
    q("asked only whether the directory name appeared anywhere, so one citation")
    q("would have flipped a whole subtree to \"covered\" and the gap report would")
    q("have overstated itself the moment any section landed. A low ratio is not a")
    q("defect: it is this document saying how little it knows about that area, so")
    q("silence here is not read as absence in the code. **What would be a defect is")
    q("this table vanishing** — a generated document whose gaps are invisible reads")
    q("as complete.")
    q()
    q("| subtree | files cited | of |")
    q("|---|---|---|")
    for (d, cited, total) in sort(cov; by=r -> (-r[2] / max(r[3], 1), r[1]))
        q("| `src/$d/` | $cited | $total |")
    end
    q()
    q("Where the ratio is low the code is the only authority; `CLAUDE.md`'s subsystem")
    q("catalog is a curated summary and carries no staleness gate.")
    q()
    String(take!(io2))
end

# ---------------------------------------------------------------- main

function main()
    text = render()
    if "--check" in ARGS
        if !isfile(OUT)
            println("STALE: $OUT does not exist. Run: julia --project=. scripts/generate_state.jl")
            return 1
        end
        cur = read(OUT, String)
        if cur == text
            println("docs/STATE.md is current")
            return 0
        end
        println("STALE: docs/STATE.md disagrees with the tree.")
        println("Run: julia --project=. scripts/generate_state.jl")
        # Name the first differing line so the failure says WHAT moved.
        a, b = split(cur, '\n'), split(text, '\n')
        for i in 1:max(length(a), length(b))
            x = i <= length(a) ? a[i] : "<eof>"
            y = i <= length(b) ? b[i] : "<eof>"
            if x != y
                println("first difference at line $i:")
                println("  committed: ", x)
                println("  derived  : ", y)
                break
            end
        end
        return 1
    end
    write(OUT, text)
    println("wrote $OUT ($(length(text)) bytes)")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
