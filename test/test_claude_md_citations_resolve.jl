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

    # The derived document must stay reachable from the always-loaded one, or it
    # is written and never read — the failure mode the memory index had.
    @testset "CLAUDE.md points at the derived state document" begin
        @test occursin("docs/STATE.md", text)
        @test occursin("scripts/generate_state.jl", text)
        @test isfile(joinpath(REPO, "docs", "STATE.md"))
    end
end
