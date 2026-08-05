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

"Test-file counts per tier list, read out of `_tiers.jl`."
function tier_counts()
    rel = "test/_tiers.jl"
    src = readsrc(rel)
    rows = Tuple{String, Int}[]
    for name in ("FAST_TESTS", "CI_EXTRA", "FULL_EXTRA", "PHYSICS_TESTS")
        m = match(Regex("const\\s+$name\\s*=\\s*\\[(.*?)\\]", "s"), src)
        m === nothing && continue
        push!(rows, (name, count(c -> c == '"', m.captures[1]) ÷ 2))
    end
    (rel, rows)
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
Which parts of `src/` this document says anything about, and which it does not.

The staleness gate cannot see the second way a generated document goes wrong: a
new subsystem appears, nobody teaches the generator to derive it, and STATE.md
stays green while being INCOMPLETE about a file titled "what this system is".
Incompleteness that is invisible reads as absence — "STATE.md does not mention
it, so it must not exist".

So the gap is derived too. A directory listed as not-covered is not a bug; it is
an honest statement that this document is silent about it, and the place to look
is the code. What would be a bug is the list disappearing.
"""
function coverage(rendered)
    dirs = sort([d for d in readdir(joinpath(ROOT, "src"))
                 if isdir(joinpath(ROOT, "src", d))])
    [(d, occursin("src/$d/", rendered)) for d in dirs]
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
    assert_nondegenerate("test tiers", length(tiers) == 4 && all(t -> t[2] > 0, tiers),
        "parsed $(length(tiers)) of 4 tier lists from $trel; counts " *
        join(string.(last.(tiers)), "/"))
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
    q("Derived by asking which `src/` subtrees any section above cites. A directory")
    q("in the second list is not a defect — it is this document stating plainly that")
    q("it is silent about that subsystem, so its absence above is not evidence of")
    q("absence in the code. **What would be a defect is this list vanishing**: a")
    q("generated document whose gaps are invisible reads as complete.")
    q()
    q("**Covered:** " * join(("`src/" .* first.(filter(c -> c[2], cov)) .* "/`"), ", "))
    q()
    q("**Not covered:** " * join(("`src/" .* first.(filter(c -> !c[2], cov)) .* "/`"), ", "))
    q()
    q("For anything in the second list the code is the only authority; `CLAUDE.md`'s")
    q("subsystem catalog is a curated summary and carries no staleness gate.")
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
