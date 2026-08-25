# A test's throwaway git repo must not read the developer's git config.
#
# THE INCIDENT (2026-08-26). `test_index_backed_gates_see_untracked.jl` and
# `test_submit_scripts_fail_loudly.jl` both build a scratch repo and commit into
# it. Both set `user.email` and `user.name` — the two settings anyone remembers —
# and inherited everything else. On the machine that signs this project's commits
#
#     [commit] gpgsign = true      [gpg] format = ssh
#
# `git commit` in the scratch repo tried to sign, had no usable agent, and exited
# 128 after about a minute. Both files were PERMANENTLY RED locally and green in
# CI, where no global config exists.
#
# That is the worst shape a gate can have, and this project has measured why: the
# dangerous direction is a gate that reddens on correct work, because that is the
# gate that gets switched off. Two red files with nothing to say about the code
# also cost every future run of the fast tier its signal.
#
# WHY THE FIX IS THE ENVIRONMENT AND NOT `commit.gpgsign=false`. Signing is one
# of several things that arrive through the same door — `core.hooksPath` pointing
# at this repo's pre-commit hooks, `init.templateDir`, `core.autocrlf`, an alias
# shadowing a subcommand — each a separate mystery with the same symptom.
# `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` at /dev/null shut the door.
#
# WHAT IS ASSERTED
#
#   1. POSITIVE CONTROL FOR THE ISOLATION ITSELF — a commit through `scratch_git`
#      succeeds while the ambient config demands signing with a key that does not
#      work. Without this the helper is untested: on a machine with no signing
#      configured, every arm below passes whether or not the isolation exists.
#   2. THE DEFECT REPRODUCES — the same commit spelled the old way FAILS under the
#      same hostile ambient config. A fix whose defect cannot be reproduced is not
#      known to be a fix.
#   3. THE CLASS GATE — no test in the tree commits into a scratch repo without
#      going through the helper.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))
include(joinpath(@__DIR__, "helpers", "scratch_git.jl"))

# The ambient configuration to test against. Not "signing on" in the abstract: a
# gpg.program that does not exist, so signing CANNOT succeed and the commit must
# be failing for the reason this file is about.
function _hostile_git_config(dir)
    cfg = joinpath(dir, "hostile.gitconfig")
    write(
        cfg,
        """
[user]
    name = hostile
    email = hostile@example.invalid
    signingkey = ssh-ed25519 AAAAnot-a-real-key
[commit]
    gpgsign = true
[gpg]
    format = ssh
    program = /nonexistent/definitely-not-a-signing-program
[gpg "ssh"]
    program = /nonexistent/definitely-not-a-signing-program
""",
    )
    cfg
end

@testset "a scratch git repo is isolated from the developer's config" begin
    @testset "POSITIVE CONTROL: the helper commits under a hostile ambient config" begin
        mktempdir() do outer
            cfg = _hostile_git_config(outer)
            withenv("GIT_CONFIG_GLOBAL" => cfg, "GIT_CONFIG_SYSTEM" => cfg) do
                # `SCRATCH_GIT_ENV` is captured at include time, so it already
                # holds /dev/null for both — which is the point: the helper does
                # not care what the ambient environment says.
                scratch_git_repo() do dir
                    write(joinpath(dir, "f.txt"), "x\n")
                    scratch_git("add", "f.txt"; dir)
                    scratch_git("commit", "-q", "-m", "init"; dir)
                    log = scratch_git("log", "--oneline"; dir, capture=true)
                    @test occursin("init", log)
                    # And the commit is genuinely unsigned rather than signed by
                    # some fallback — `%G?` is `N` for "no signature".
                    sig = scratch_git("log", "-1", "--format=%G?"; dir, capture=true)
                    @test strip(sig) == "N"
                end
            end
        end
    end

    @testset "THE DEFECT REPRODUCES: the old spelling fails under the same config" begin
        # Pinning the bug, not only the fix. If this ever stops failing, the
        # positive control above has become a tautology and should be re-derived.
        mktempdir() do outer
            cfg = _hostile_git_config(outer)
            withenv("GIT_CONFIG_GLOBAL" => cfg, "GIT_CONFIG_SYSTEM" => cfg) do
                mktempdir() do dir
                    run(pipeline(Cmd(`git init -q`; dir), devnull))
                    write(joinpath(dir, "f.txt"), "x\n")
                    run(pipeline(Cmd(`git add f.txt`; dir), devnull))
                    old = Cmd(`git -c user.email=t@t -c user.name=t commit -qm base`;
                        dir)
                    @test_throws ProcessFailedException run(
                        pipeline(old; stdout=devnull, stderr=devnull))
                end
            end
        end
    end

    @testset "the identity comes from the helper, not from the checkout" begin
        # A scratch repo with the global config switched off has no identity at
        # all, and `git commit` refuses without one. The helper supplies it
        # through the environment so no caller has to remember two `git config`
        # lines — the half that WAS remembered in both incidents.
        scratch_git_repo() do dir
            write(joinpath(dir, "f.txt"), "x\n")
            scratch_git("add", "f.txt"; dir)
            scratch_git("commit", "-q", "-m", "init"; dir)
            who = scratch_git("log", "-1", "--format=%an <%ae>"; dir, capture=true)
            @test strip(who) == "t <t@t>"
        end
    end

    @testset "CLASS GATE: no test commits into a scratch repo the old way" begin
        # CLAUDE.md commitment 11: the PR introducing a canonical form either
        # migrates every caller or lands the gate that makes the next new caller
        # of the old form red. Both callers are migrated; this is what stops a
        # third.
        root = normpath(joinpath(@__DIR__, ".."))
        corpus = String[]
        # `tree_files(root/test)` returns paths relative to `root` — so the join
        # is against `root`, NOT against its parent. Getting that wrong resolves
        # every candidate to a path that does not exist, `continue`s past all of
        # them, and asserts emptiness on a scan that never looked. It is not
        # hypothetical: the sibling gate in
        # test_index_backed_gates_see_untracked.jl had exactly this and had never
        # seen a file. The `length(corpus)` assertion below is what catches it.
        for rel in tree_files(joinpath(root, "test"))
            p = joinpath(root, rel)
            isfile(p) || continue
            # Two named exemptions, both DOCUMENTATION sites rather than call
            # sites: this file states the old spelling in order to reproduce it,
            # and the helper's docstring quotes `git commit` in prose. A named
            # list, not a rule — and everything unknown falls on the GUILTY side,
            # which is the right direction here: a new scratch repo is exactly
            # where the defect lands.
            (
                endswith(p, "test_scratch_git_isolation.jl") ||
                endswith(p, joinpath("helpers", "scratch_git.jl"))
            ) && continue
            push!(corpus, read(p, String))
        end

        # A backtick-quoted git command whose SUBCOMMAND is `commit`. Two
        # narrowings, both from what a wider predicate actually matched:
        #
        #   * comment lines are stripped. `commit` is an ordinary English word in
        #     this tree and the first version flagged a comment in `_tiers.jl`
        #     describing this very incident;
        #   * the subcommand position is required, so
        #     `git rev-parse --verify $(rev * "^{commit}")` in
        #     test_campaign_fix_list_gate.jl is not a commit. A `\bcommit\b`
        #     anywhere in the command matched it.
        #
        # Widening an exclusion list instead would have been fixing the threshold
        # rather than the predicate.
        strip_comments(t) = join(
            (l for l in split(t, '\n') if !startswith(lstrip(l), "#")), '\n')
        raw_commit = r"`git\b(?:\s+-c\s+\S+|\s+-[A-Za-z-]+)*\s+commit\b"
        hits = calibrated_scan(corpus;
            match=t -> count_matches(raw_commit, strip_comments(t)) > 0,
            present="run(pipeline(Cmd(`git commit -q -m init`; dir), devnull))",
            absent="scratch_git(\"commit\", \"-q\", \"-m\", \"init\"; dir)",
            describe=t -> first(t, 60))
        @test isempty(hits)

        # NEGATIVE CONTROLS for the two narrowings, so neither can be widened back
        # without this file going red.
        @test count_matches(raw_commit,
            "_have(rev) = _git_ok(`git rev-parse --verify \$(rev * \"^{commit}\")`)") == 0
        @test count_matches(raw_commit,
            "old = Cmd(`git -c user.email=t@t -c user.name=t commit -qm base`; dir)") == 1

        # And the corpus is real — a scan over an empty file list reports the same
        # zero as a clean tree.
        @test length(corpus) > 100
        @test any(t -> occursin("scratch_git(", t), corpus)
    end
end
