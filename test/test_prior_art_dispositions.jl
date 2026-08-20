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
