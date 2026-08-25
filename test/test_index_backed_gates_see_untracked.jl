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
include(joinpath(@__DIR__, "helpers", "scratch_git.jl"))

"Build a throwaway git repo with a known tracked/untracked/ignored layout."
function _scratch_repo(f)
    # `scratch_git_repo`, not `mktempdir` + a bare `git init`: setting
    # `user.email` and `user.name` locally is the half everyone remembers, and the
    # rest of the developer's `~/.gitconfig` arrived behind it. `commit.gpgsign =
    # true` made the commit below exit 128 on the machine that signs its commits,
    # so this file was permanently red locally and green in CI. See
    # test/helpers/scratch_git.jl.
    scratch_git_repo() do dir
        mkpath(joinpath(dir, "scripts", "sub"))
        write(joinpath(dir, ".gitignore"), "scripts/ignored_clutter.sh\n")

        # (a) tracked + committed
        write(joinpath(dir, "scripts", "committed.sh"), "#!/bin/bash\n")
        # (b) staged but not committed
        write(joinpath(dir, "scripts", "staged.sh"), "#!/bin/bash\n")
        scratch_git("add", ".gitignore", "scripts/committed.sh",
            "scripts/staged.sh"; dir)
        scratch_git("commit", "-q", "-m", "init", "--",
            ".gitignore", "scripts/committed.sh"; dir)
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
            split(scratch_git("ls-files", "scripts"; dir, capture=true),
                '\n'; keepempty=false),
        )
        @test !("scripts/untracked_new.sh" in index_only)   # the blindness
        @test "scripts/committed.sh" in index_only          # ...and it looked fine
    end
end

@testset "no gate in the tree builds a corpus from a bare `git ls-files`" begin
    # The class gate. CLAUDE.md commitment 11: a new single source of truth ships
    # with the gate that outlaws the old form, or the migration becomes permanent
    # and the tree carries two live definitions of the same thing.
    #
    # THIS SCAN WAS BLIND FROM THE DAY IT WAS WRITTEN UNTIL 2026-08-26, and blind
    # in the same direction as the defect the file is about. `tree_files(root/test)`
    # returns paths relative to `root`; it joined them against `dirname(root)`, so
    # all 523 candidates resolved to files that do not exist, every one hit the
    # `continue`, and `isempty(bare)` was asserted over a scan that had never
    # opened anything. No probe could have failed — the exact thesis of this file,
    # one level up: an empty result and an unreachable corpus print the same two
    # characters.
    #
    # The moment it could see, it found three hits and ALL THREE WERE PROSE
    # ("never a bare `git ls-files`" in a docstring). So the predicate was also
    # too wide, which the blindness had hidden. Both are fixed here and both are
    # now held by controls, via `calibrated_scan` — which is what should have been
    # used in the first place.
    root = normpath(joinpath(@__DIR__, ".."))
    rels = filter(tree_files(joinpath(root, "test"))) do rel
        # This file states the old spelling in order to reproduce it (above).
        !endswith(rel, "test_index_backed_gates_see_untracked.jl")
    end
    corpus = [
        (rel, read(joinpath(root, rel), String)) for rel in rels
                                                     if isfile(joinpath(root, rel))
    ]

    # A COMMAND, not a mention. Real call sites build the literal inside a `Cmd(`;
    # prose quotes `git ls-files` in running text. `--others` is what makes the
    # call see the working tree, so a call carrying it is fine however spelled.
    call = r"Cmd\(`git\b[^`\n]*\bls-files\b[^`\n]*`"
    offenders(text) = [strip(m.match) for m in eachmatch(call, text)
                        if !occursin("--others", m.match)]

    hits = calibrated_scan(corpus;
        match=e -> !isempty(offenders(e[2])),
        # POSITIVE control: the defect, spelled the way #425 found it.
        present=("<probe>", "index = read(Cmd(`git ls-files scripts`; dir), String)"),
        # NEGATIVE control: the prose that made the sighted scan report three
        # false hits. Widening an exclusion list instead of narrowing the
        # predicate would have been fixing the threshold, not the instrument.
        absent=("<probe>", "Use this, never a bare `git ls-files`, whenever a gate's corpus is"),
        describe=first)

    @test isempty(hits)
    isempty(hits) || @info "bare `git ls-files` corpora (use `git_corpus`)" [
        e[1] * ": " * o for e in hits for o in offenders(e[2])]

    # A correctly-spelled call must NOT be flagged — `calibrated_scan`'s negative
    # probe covers prose, and this covers the other direction: the real helper.
    @test isempty(
        offenders(
            "out = read(Cmd(`git ls-files --cached --others --exclude-standard \$args`; dir), String)"
        ),
    )

    # CALIBRATION OF THE CORPUS ITSELF. Without these, `isempty(hits)` is
    # satisfied by a scan that could not look — which is what it was.
    @test length(corpus) == length(rels)     # every candidate was opened
    @test length(corpus) > 100               # ...and there were candidates
    @test any(e -> occursin("git_corpus(", e[2]), corpus)
end
