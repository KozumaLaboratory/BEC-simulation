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
# A hand-written "current state" document is exactly the artifact that cannot be
# maintained, because writing it requires the knowledge nobody has. So this file
# does not write one. **It derives one.** Every section below names the code it
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

    p("## Hamiltonian terms in the registry")
    p()
    p("`H_TERMS_CANONICAL_ORDER`, in order. **$(length(H_TERMS_CANONICAL_ORDER)) terms.**")
    p("Each declares its sign in one coefficient function in the file named.")
    p()
    p("| # | registry symbol | struct | defined at |")
    p("|---|---|---|---|")
    for (i, (sym, name, home)) in enumerate(ham_terms())
        p("| $i | `$sym` | `$name` | `$home` |")
    end
    p()

    conv = bfield_converters()
    p("## The B → p sign: every site that touches it")
    p()
    p("`Units.bfield_to_p` is the ONE declaration (`p ≡ -g_F μ_B B`, Kawaguchi-Ueda).")
    p("**$(length(conv)) references** across the tree; every one other than the")
    p("declaration itself must delegate. `CLAUDE.md` said \"the 3 sibling converters\"")
    p("until 2026-08-05, and a stale count is how a wrong-sign converter survived")
    p("two months — so this list is generated, not typed.")
    p()
    for h in conv
        p("- `$h`")
    end
    p()

    top, steps = schema_surface()
    p("## YAML surface")
    p()
    p("**Top-level keys ($(length(top))):** " * join("`" .* top .* "`", ", "))
    p()
    p("**Pipeline step kinds ($(length(steps))):** " * join("`" .* steps .* "`", ", "))
    p()
    krel, kr = retired_keys()
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
    p("## Test tiers")
    p()
    p("File counts from `$trel`. Membership is explicit — no auto-discovery.")
    p()
    for (name, n) in tiers
        p("- `$name` — $n files")
    end
    p()

    p("## Validation ladder — instruments present on disk")
    p()
    p("| level | instrument (located by walking `test/`) |")
    p("|---|---|")
    for (lvl, path) in ladder()
        p("| $lvl | `$path` |")
    end
    p()

    lims = limit_markers()
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

    String(take!(io))
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
