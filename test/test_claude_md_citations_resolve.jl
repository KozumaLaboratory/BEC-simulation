using Test
using SpinorBEC

# Every code path and every `file:line` that CLAUDE.md cites must resolve.
#
# CLAUDE.md is the only file loaded into every session, so a wrong line in it is
# paid by every future agent, forever. On 2026-08-05 six of its statements were
# false against the tree — two directories relocated ten weeks earlier, a status
# token the target document had disclaimed, a converter count off by more than
# half, an operator list short by two, and a pointer that round-tripped back to
# itself. Each was individually cheap to write correctly at the time. None was
# ever re-checked, because nothing checked it.
#
# This gate covers the mechanical half: does the thing named still exist, and
# does the cited line still say what the citation implies. It cannot tell whether
# a sentence is TRUE — no test can — which is precisely why the derivable facts
# belong in `docs/STATE.md` (generated, gated by `test_state_doc_is_current.jl`)
# and CLAUDE.md keeps the judgement.

const CLAUDE = normpath(joinpath(@__DIR__, "..", "CLAUDE.md"))
const REPO = normpath(joinpath(@__DIR__, ".."))

# `...` is an elision in prose ("ext/.../gpu_lhy_field.jl"), and foo/bar are the
# naming-convention EXAMPLE. Both are correct writing, not dead references.
const _PLACEHOLDER = r"\.\.\.|/(?:foo|bar|my_config)\b|<[a-z_]+>"

"Every repo path cited in backticks, minus prose placeholders."
function cited_paths(text)
    hits = String[]
    for m in eachmatch(
        r"`((?:src|test|ext|scripts|bench|docs|runs|dashboard|figs)/[A-Za-z0-9_./-]+\.[a-z]{1,4})(?::(\d+))?`",
        text,
    )
        occursin(_PLACEHOLDER, m.captures[1]) && continue
        push!(hits, m.match[2:(end - 1)])   # strip backticks, keep any :line
    end
    unique(hits)
end

"Every directory cited in backticks as `path/to/dir/`."
function cited_dirs(text)
    hits = String[]
    for m in eachmatch(r"`((?:src|test|ext|scripts|bench|docs|dashboard)/[A-Za-z0-9_./-]*/)`", text)
        occursin(_PLACEHOLDER, m.captures[1]) && continue
        push!(hits, m.captures[1])
    end
    unique(hits)
end

@testset "CLAUDE.md's citations resolve" begin
    text = read(CLAUDE, String)
    lines = split(text, '\n')
    paths = cited_paths(text)
    dirs = cited_dirs(text)

    # CALIBRATION. An extractor that matches nothing reports a clean file in
    # exactly the words a clean file uses. Five instruments failed this way on
    # 2026-08-05 alone, so assert the population before judging it, and assert a
    # fabricated path would be caught.
    @testset "the instrument sees its inputs" begin
        @test length(paths) >= 20
        @test length(dirs) >= 3
        @test any(p -> startswith(p, "src/"), paths)
        @test any(p -> startswith(p, "test/"), paths)
        fake = cited_paths("see `src/zzz_no_such_file.jl` here")
        @test fake == ["src/zzz_no_such_file.jl"]
        @test !isfile(joinpath(REPO, only(fake)))
        # and the CONTEXT lookup, which is where the first version broke: it must
        # find the line CONTAINING a known citation, not the first empty line.
        probe = "docs/STATE.md"
        ci = findfirst(l -> occursin(probe, l), lines)
        @test ci !== nothing
        @test occursin(probe, lines[ci])
        @test !isempty(lines[ci])
    end

    # A path that resolves on ANOTHER ref is not simply dead — the claim is true
    # in one worktree and false in another while reading as universal. That is
    # allowed here ONLY if the sentence names the ref, which is what makes it
    # honest. `bench/probe_lbfgs_orbit_fraction.jl` is the live example: it exists
    # on `perf/lbfgs-orbit-probe` and carries the measurement CLAUDE.md quotes as
    # evidence for a physics conclusion.
    @testset "every cited file exists, or its ref is named" begin
        dead = String[]
        for p in paths
            f = first(split(p, ':'))
            isfile(joinpath(REPO, f)) && continue
            # The sentence citing it must say where it lives. NOTE the argument
            # order: `occursin(x)` fixes the SECOND argument, so `occursin(f)`
            # asks "is this LINE inside the filename" — true for every empty
            # line. The first version of this check did exactly that and reported
            # a correctly-anchored citation as unanchored.
            ctx = findfirst(l -> occursin(f, l), lines)
            ctx !== nothing &&
                occursin(r"origin/[\w./-]+|only on `[\w./-]+`|NOT on `main`", lines[ctx]) &&
                continue
            push!(dead, f)
        end
        isempty(dead) ||
            println("\nCLAUDE.md cites files that exist nowhere, with no ref named:\n  ",
                join(dead, "\n  "))
        @test isempty(dead)
    end

    @testset "every cited directory exists" begin
        dead = [d for d in dirs if !isdir(joinpath(REPO, rstrip(d, '/')))]
        isempty(dead) || println("\nCLAUDE.md cites directories that do not exist:\n  ",
            join(dead, "\n  "))
        @test isempty(dead)
    end

    # A `file:line` citation is the shape that rots WITHOUT the file being
    # deleted — the file survives, the line drifts, and the citation now points
    # at unrelated code. Verified here only as "the line exists", because
    # checking what it says needs the claim, which is judgement.
    @testset "every cited line number is in range" begin
        bad = String[]
        for p in paths
            parts = split(p, ':')
            length(parts) == 2 || continue
            f, n = parts[1], tryparse(Int, parts[2])
            n === nothing && continue
            total = countlines(joinpath(REPO, f))
            n <= total || push!(bad, "$p (file has $total lines)")
        end
        isempty(bad) || println("\nCLAUDE.md cites line numbers past end of file:\n  ",
            join(bad, "\n  "))
        @test isempty(bad)
    end

    # A NAME is the other half of a citation, and until 2026-08-19 nothing
    # checked it. `even_c_extra(F; c2, c4, c6, …)` was named as the canonical
    # API on two lines for months; the function has never existed in this tree
    # (#342), and it is the second of its kind — `compute_interaction_params_
    # general_f` was the first. Both were invisible to a path check, and both
    # are invisible to grep too: the name occurs in a docstring and in a hook's
    # warning pattern, so "does this string appear in src/" answers YES for a
    # function that cannot be called. The question is whether it RESOLVES, so
    # ask the loaded package, not the text.
    @testset "every backticked call symbol resolves" begin
        mods = Module[SpinorBEC]
        for n in names(SpinorBEC; all=true)
            v = try
                getglobal(SpinorBEC, n)
            catch
                nothing
            end
            v isa Module && v !== SpinorBEC && push!(mods, v)
        end
        # Test-side helpers are not in the package but are real, callable code.
        helpers = Module[]
        let m = Module(:_ClaudeMdHelpers)
            Base.include(m, joinpath(REPO, "test", "helpers", "calibrated_scan.jl"))
            push!(helpers, m)
        end

        # Prose that is call-SHAPED but is not a call. Each entry states why;
        # the ratchet below deletes any that starts resolving, so this cannot
        # become the place unresolved names go to be forgotten.
        allowed = Dict(
            "Q" => "the DDI tensor Q_αβ(k̂) in prose, not a function",
            "V" => "the potential V(dt/2) in the split-step sandwich",
            "g" => "the ramp time-warp g(t) = log(1 + (e-1)t)",
            "diagonal" =>
                "names the c₀ substep in prose (`diagonal(c₀)`), " *
                "not the function `Diagonal`",
            "make_params" =>
                "a callback the CALLER supplies to " *
                "`scan_phase_diagram_2d` / `find_phase_boundary`; " *
                "a kwarg name, never a global",
        )

        call_symbols(s) = unique([m.captures[1]
                for m in eachmatch(r"`([A-Za-z_][A-Za-z0-9_!]*)\(", s)])
        syms = call_symbols(text)
        resolves(t) =
            any(m -> isdefined(m, Symbol(t)), mods) ||
            any(m -> isdefined(m, Symbol(t)), helpers) ||
            isdefined(Base, Symbol(t)) || isdefined(Core, Symbol(t))

        # CALIBRATION, the same discipline as above: an extractor that finds
        # nothing and a resolver that says YES to everything both report a clean
        # file. Probe each on synthetic input so the controls do not depend on
        # CLAUDE.md's current wording — a control that moves with the thing under
        # test is not a control.
        @test call_symbols("call `foo_bar!(x)` but not `plain_name` or foo(y)") == ["foo_bar!"]
        @test length(syms) >= 20
        @test count(resolves, syms) >= 15         # the resolver resolves
        @test !resolves("zzz_no_such_function")   # and rejects
        @test !resolves("even_c_extra")           # the #342 name, still absent

        dead = [t for t in syms if !resolves(t) && !haskey(allowed, t)]
        isempty(dead) || println(
            "\nCLAUDE.md names functions that do not resolve:\n  ", join(dead, "\n  "),
            "\n(if one is prose rather than a call, add it to `allowed` WITH ITS REASON)")
        @test isempty(dead)

        stale = [t for t in keys(allowed) if resolves(t)]
        isempty(stale) || println("\n`allowed` entries that now resolve — delete them:\n  ",
            join(stale, "\n  "))
        @test isempty(stale)
        unused = [t for t in keys(allowed) if !(t in syms)]
        isempty(unused) || println("\n`allowed` entries CLAUDE.md no longer mentions:\n  ",
            join(unused, "\n  "))
        @test isempty(unused)
    end

    # The derived document must stay reachable from the always-loaded one, or it
    # is written and never read — the failure mode the memory index had.
    @testset "CLAUDE.md points at the derived state document" begin
        @test occursin("docs/STATE.md", text)
        @test occursin("scripts/generate_state.jl", text)
        @test isfile(joinpath(REPO, "docs", "STATE.md"))
    end
end
