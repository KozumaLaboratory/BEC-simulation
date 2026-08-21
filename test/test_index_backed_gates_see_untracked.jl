# A gate whose corpus is the git INDEX is blind to work that has not been
# `git add`-ed — and it is blind in the GREEN direction.
#
# THE INCIDENT (#422, #425, 2026-08-21)
#
# A new `scripts/` submit script was written. `test_scripts_allowlist.jl` was
# run, was green, and "allowlist gate passes" was reported. The push went red on
# CI with `isempty(["submit_lt64_endpoint_ensemble.sh"])`.
#
# Nothing was skipped and nobody was careless. The gate built its corpus with
# `git ls-files scripts` and intersected the on-disk listing against it, so the
# unstaged file was not judged-and-passed, it was REMOVED FROM THE QUESTION. An
# empty `extra` set then means "no unlisted files" and "I could not see the file
# you are asking about" with the same two characters, which is the
# `calibrated_scan` thesis one layer out: an instrument that cannot distinguish
# absence from unreachability is not evidence.
#
# WHY THIS IS THE DANGEROUS DIRECTION
#
# The set of PRs that add an untracked file matching an allowlisted pattern IS
# the set of PRs the allowlist gate exists for. So the gate was blind exactly
# and only when it mattered, and green the rest of the time. A norm
# ("`git add` before running index-backed gates") is the wrong shape of fix:
# the same day produced four environment-induced false verdicts, and a habit
# that must fire on the rare path is a habit that will not.
#
# WHAT IS ASSERTED HERE
#
#   1. NEGATIVE control — an untracked, unignored file matching the pattern is
#      SEEN. This is the canary: it must be able to go red.
#   2. POSITIVE control — a staged, correctly-allowlisted file stays green.
#      Required by CLAUDE.md's "the sharpest case goes in the PASS direction":
#      a gate that reddens on correct work gets switched off.
#   3. IGNORED files stay invisible — `mcp/.venv` and editor droppings were the
#      only reason the index filter was there, and that reason must survive.
#   4. The class gate — no test in the tree builds a corpus from a bare
#      `git ls-files`.
#
# Every assertion runs against a THROWAWAY repo built in a temp dir, so the
# result does not depend on the state of the checkout running the suite — which
# is the same checkout-dependence bug, and it would be absurd to reintroduce it
# in the test that names it.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

"Build a throwaway git repo with a known tracked/untracked/ignored layout."
function _scratch_repo(f)
    mktempdir() do dir
        run(pipeline(Cmd(`git init -q`; dir), devnull))
        run(pipeline(Cmd(`git config user.email t@t`; dir), devnull))
        run(pipeline(Cmd(`git config user.name t`; dir), devnull))
        mkpath(joinpath(dir, "scripts", "sub"))
        write(joinpath(dir, ".gitignore"), "scripts/ignored_clutter.sh\n")

        # (a) tracked + committed
        write(joinpath(dir, "scripts", "committed.sh"), "#!/bin/bash\n")
        # (b) staged but not committed
        write(joinpath(dir, "scripts", "staged.sh"), "#!/bin/bash\n")
        run(
            pipeline(Cmd(`git add .gitignore scripts/committed.sh scripts/staged.sh`;
                    dir), devnull),
        )
        run(pipeline(Cmd(`git commit -q -m init -- .gitignore scripts/committed.sh`;
                dir), devnull))
        # (c) untracked, NOT ignored — the file the old corpus dropped
        write(joinpath(dir, "scripts", "untracked_new.sh"), "#!/bin/bash\n")
        # (d) untracked AND ignored — must stay invisible
        write(joinpath(dir, "scripts", "ignored_clutter.sh"), "#!/bin/bash\n")
        # (e) untracked, not ignored, in a subdirectory
        write(joinpath(dir, "scripts", "sub", "nested_new.sh"), "#!/bin/bash\n")
        f(dir)
    end
end

@testset "git_corpus sees the working tree, not just the index" begin
    _scratch_repo() do dir
        corpus = git_corpus(dir, "scripts")

        @testset "CANARY: an untracked, unignored file is SEEN" begin
            # This is the assertion that had no counterpart before #425. If the
            # corpus reverts to a bare `git ls-files`, this goes red.
            @test "scripts/untracked_new.sh" in corpus
            @test "scripts/sub/nested_new.sh" in corpus
        end

        @testset "PASS direction: tracked files stay visible" begin
            @test "scripts/committed.sh" in corpus
            @test "scripts/staged.sh" in corpus
        end

        @testset "ignored clutter stays invisible" begin
            # The ONLY thing the index filter was ever wanted for. Losing this
            # would trade a green-side blindness for a red-side one.
            @test !("scripts/ignored_clutter.sh" in corpus)
        end

        @testset "pathspec scopes the corpus" begin
            @test !(".gitignore" in corpus)
            @test ".gitignore" in git_corpus(dir)
        end
    end
end

@testset "the old spelling really was blind — the bug reproduces" begin
    # Pinning the DEFECT, not just the fix. If someone argues the index corpus
    # was fine, this is the counter-example, executed rather than described.
    _scratch_repo() do dir
        index_only = Set(
            split(
                read(Cmd(`git ls-files scripts`; dir), String), '\n'; keepempty=false),
        )
        @test !("scripts/untracked_new.sh" in index_only)   # the blindness
        @test "scripts/committed.sh" in index_only          # ...and it looked fine
    end
end

@testset "no gate in the tree builds a corpus from a bare `git ls-files`" begin
    # The class gate. CLAUDE.md commitment 11: a new single source of truth
    # ships with the gate that outlaws the old form, or the migration becomes
    # permanent and the tree carries two live definitions of the same thing.
    root = normpath(joinpath(@__DIR__, ".."))
    files = tree_files(joinpath(root, "test"))

    # `--others` is what makes an `ls-files` call see the working tree; a call
    # carrying it is fine however it is spelled.
    bare = String[]
    for rel in files
        path = joinpath(dirname(rstrip(root, '/')), rel)
        isfile(path) || continue
        endswith(path, "test_index_backed_gates_see_untracked.jl") && continue
        for m in eachmatch(r"git[^\n`]*ls-files[^\n`]*", read(path, String))
            occursin("--others", m.match) || push!(bare, rel * ": " * strip(m.match))
        end
    end

    @test isempty(bare)
    isempty(bare) || @info "bare `git ls-files` corpora (use `git_corpus`)" bare
end
