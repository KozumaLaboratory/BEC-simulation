using Test
# parallel-runner contract: every test file loads the package (plain form)
using SpinorBEC

# The gate for "work that already exists must be dispositioned, not merely
# available".
#
# On 2026-08-20 an SPGPE campaign re-derived a cache-key bug that PR #351 had
# already found, fixed and gated two days earlier, and — worse — shipped a
# documented limit that the same PR had already RETRACTED. An entire ensemble was
# designed on a limit that did not exist. `gh pr list` had been run at the start of
# that session and #351 was IN THE OUTPUT with `feat(spgpe):` in its title, on a
# task that was entirely SPGPE.
#
# Two memory notes covered it exactly and neither fired, which is the argument
# against writing a third: salience loses to task momentum. So the remedy is an
# artifact that must exist and a state it may not be left in —
# `docs/campaign/prior_art/<topic>.md`, one row per matching open PR / issue /
# branch, and `unread` is a failure.
#
# WHAT THIS GATE DOES NOT DO, stated because a gate that implies more than it
# checks is worse than none. It cannot tell whether the enumeration is CURRENT —
# the runner has no network — and it cannot tell whether a `read` row was really
# read. It checks the two things that are decidable from the file: every row has a
# known disposition, and none is still `unread`. The generator
# (`scripts/prior_art.py`) is what makes enumerating cheap; this is what makes
# leaving a row unread impossible to do quietly.
@testset "prior-art records carry a disposition for every entry" begin
    root = normpath(joinpath(@__DIR__, ".."))
    dir = joinpath(root, "docs", "campaign", "prior_art")
    tool = joinpath(root, "scripts", "prior_art.py")
    @test isfile(tool)

    # `--check` is the same predicate the tool exposes to a human, so the gate and
    # the command someone runs by hand cannot drift apart.
    ok = success(pipeline(`python3 $tool --check`; stdout=devnull, stderr=devnull))
    if !ok
        @info "prior-art check failed; run `python3 scripts/prior_art.py --check`" *
            " to see which entries are unread" dir
    end
    @test ok

    # CANARY. A checker that cannot fail is the failure mode this whole family of
    # gates exists to remove, so plant the exact defect and require a refusal.
    mktempdir() do d
        rec = joinpath(d, "prior_art")
        mkpath(rec)
        write(
            joinpath(rec, "canary.md"),
            """
# Prior art — canary

| ref | disposition | what | note |
|---|---|---|---|
| #1 | read | pr: fine | |
| #2 | unread | pr: the one that would have stopped it | |
""",
        )
        # Point the tool at the temporary tree by running it from there: RECORD_DIR
        # is derived from the script's own location, so a copy of the script beside
        # a `docs/campaign/prior_art` is what makes this reachable.
        fake_root = joinpath(d, "fake")
        mkpath(joinpath(fake_root, "scripts"))
        mkpath(joinpath(fake_root, "docs", "campaign"))
        cp(tool, joinpath(fake_root, "scripts", "prior_art.py"))
        cp(rec, joinpath(fake_root, "docs", "campaign", "prior_art"))
        refused =
            !success(
                pipeline(
                    `python3 $(joinpath(fake_root, "scripts", "prior_art.py")) --check`;
                    stdout=devnull, stderr=devnull),
            )
        @test refused          # an `unread` row MUST fail

        # …and the negative half: the same tree with that row dispositioned passes,
        # so the canary is testing the row and not the tree's existence.
        p = joinpath(fake_root, "docs", "campaign", "prior_art", "canary.md")
        write(p, replace(read(p, String), "| unread |" => "| unrelated |"))
        @test success(
            pipeline(
                `python3 $(joinpath(fake_root, "scripts", "prior_art.py")) --check`;
                stdout=devnull, stderr=devnull),
        )
    end
end

# The two ways a record can be destroyed by the thing that maintains it. Both
# were found by running the generator once, not by the gate above — which only
# ever reads the file — so they get their own.
@testset "regenerating a prior-art record cannot destroy it" begin
    root = normpath(joinpath(@__DIR__, ".."))
    tool = joinpath(root, "scripts", "prior_art.py")

    setup = d -> begin
        mkpath(joinpath(d, "scripts"))
        mkpath(joinpath(d, "docs", "campaign", "prior_art"))
        cp(tool, joinpath(d, "scripts", "prior_art.py"))
        rec = joinpath(d, "docs", "campaign", "prior_art", "t.md")
        write(
            rec,
            """
# Prior art — t

> **FROZEN 2026-01-01.**

| ref | disposition | what | note |
|---|---|---|---|
| #7 | read | pr: a thing | THE REASON, which is the part worth keeping |
""",
        )
        (joinpath(d, "scripts", "prior_art.py"), rec)
    end

    # 1. An INCOMPLETE enumeration must not overwrite. `gh` failing and `gh`
    #    returning nothing are identical in the data and opposite in meaning; the
    #    first version could not tell them apart, so an offline moment would have
    #    replaced the record with "nothing open matched these keywords".
    mktempdir() do d
        (script, rec) = setup(d)
        before = read(rec, String)
        # No `gh` on PATH is the cheapest faithful stand-in for "the enumeration
        # failed" — same code path as a network error or an expired token.
        p = pipeline(
            setenv(`python3 $script --topic t --keywords spgpe`, "PATH" => "/usr/bin:/bin");
            stdout=devnull, stderr=devnull,
        )
        @test !success(p)             # must refuse…
        @test read(rec, String) == before   # …and leave the file untouched
    end

    # 2. A COMPLETE regeneration must carry the notes forward. The first version
    #    preserved only the disposition column, so regeneration silently blanked
    #    every note while cheerfully reporting `0 unread`.
    mktempdir() do d
        (script, rec) = setup(d)
        bin = joinpath(d, "bin")
        mkpath(bin)
        gh = joinpath(bin, "gh")
        write(
            gh,
            """
            #!/bin/sh
            case "\$1" in
              pr) echo '[{"number":7,"title":"a thing","headRefName":"f/spgpe"}]' ;;
              *)  echo '[]' ;;
            esac
            """,
        )
        chmod(gh, 0o755)
        # The tree must be a git repo or BRANCH enumeration fails, the run counts
        # as incomplete, and the refusal above fires — which would make this case
        # pass for the opposite of its reason. (It did, the first time.)
        run(pipeline(`git -C $d init -q`; stdout=devnull, stderr=devnull))
        @test success(
            pipeline(
                setenv(
                    `python3 $script --topic t --keywords spgpe`,
                    "PATH" => bin * ":/usr/bin:/bin",
                );
                stdout=devnull, stderr=devnull,
            ),
        )
        @test occursin("THE REASON", read(rec, String))
    end
end
