# W3: the grandfather arm had no cutoff, and its population is not zero.
#
# Cutover step 3 declined to bound arm (b) — "no marker at all ⇒ admitted as
# `:unmarked`" — on the ground that its population "is zero twice over". That is
# true at the GS STAGE store and false at the three other admission sites, which
# read `runs/`: `experiment.jl:253`, `run_registry.jl:491`, `run_registry.jl:720`.
#
# MEASURED in the main checkout on 2026-08-02: 522 `.jld2`, 0 `.complete.toml`,
# 0 `.incomplete.toml`. Every one of those was admissible FOREVER under arm (b),
# and so was every future run killed by an OOM, a walltime, or a lost node — a
# tombstone only covers writers that KNOW they failed.
#
# Documented precedent: Snakemake issue 3808 — outputs of FAILED jobs stopped
# being marked incomplete, the metadata read `"incomplete": false`, and reruns
# never triggered. Its `incomplete()` is literally "exists and marked ⇒
# incomplete, else complete", i.e. arm (b).
#
# The bound is one dated constant. This file pins it — NOT by reading it back out
# of `src/`, which would be a circular gate that passes against any value, but
# against the literal epoch second of the commit it names. Two of the campaign's
# gates already shipped circular and both were caught only by canary.

using Test
using Dates
using SpinorBEC
using SpinorBEC: admit_payload, write_complete_marker, write_incomplete_marker,
    MARKER_CUTOVER_UNIX, _reset_unmarked_warnings!

# `touch(path)` can only set "now". Setting an explicit mtime needs the syscall,
# and `touch -d @<epoch>` is the portable spelling of it here.
set_mtime!(p, epoch) = (run(pipeline(`touch -d @$(Int(epoch)) $p`; stdout=devnull)); p)

cfixture(dir, name, epoch; nbytes=64) = begin
    p = joinpath(dir, name)
    write(p, rand(UInt8, nbytes))
    set_mtime!(p, epoch)
end

const BEFORE = MARKER_CUTOVER_UNIX - 86_400   # a day before marker writing existed
const AFTER = MARKER_CUTOVER_UNIX + 86_400    # a day after

@testset "W3: a dated cutoff bounds the grandfather arm" begin
    @testset "A: the constant IS the commit it claims to be" begin
        # Pinned literally. `ce9721cb` is "cutover step 2 — a cache hit requires
        # a completion marker": the first commit in which any writer in the tree
        # could produce a marker at all. Verify by hand with
        #   git log -1 --format=%ct ce9721cb
        @test MARKER_CUTOVER_UNIX == 1_785_580_432
        # And that it is the date it is documented as, 2026-08-01T19:33:52+09:00
        # = 2026-08-01T10:33:52Z. Stated in UTC because `unix2datetime` is UTC and
        # a reader in another timezone would otherwise get a different answer.
        @test Dates.unix2datetime(MARKER_CUTOVER_UNIX) == DateTime(2026, 8, 1, 10, 33, 52)
        # A cutoff in the future would disable the whole arm silently: everything
        # would be grandfathered again and every assertion below would still pass
        # for the wrong reason.
        @test MARKER_CUTOVER_UNIX < time()
    end

    @testset "B: before the cutoff is history; after it is a killed run" begin
        mktempdir() do dir
            _reset_unmarked_warnings!()
            # POSITIVE CONTROL for the whole file: an unmarked payload from
            # BEFORE the cutoff is still admitted, warned once, as `:unmarked`.
            # Without this arm, "after ⇒ rejected" would pass equally against an
            # `admit_payload` that rejected every unmarked payload — which is the
            # 522-file recompute this cutoff exists NOT to trigger.
            old = cfixture(dir, "legacy.jld2", BEFORE)
            a = admit_payload(old)
            @test a.hit
            @test a.provenance === :unmarked

            new = cfixture(joinpath(mkpath(joinpath(dir, "fresh"))), "killed.jld2", AFTER)
            r = admit_payload(new)
            @test !r.hit
            @test r.provenance === :rejected
            # The message has to name the two instants, or a person reading a log
            # cannot tell this apart from a truncation.
            @test occursin("NO completion marker", r.reason)
            @test occursin("2026-08-01T10:33:52Z", r.reason)
            @test occursin("ce9721cb", r.reason)
        end
    end

    @testset "C: the boundary is exclusive on the cutoff second itself" begin
        mktempdir() do dir
            _reset_unmarked_warnings!()
            # `>` not `>=`: a payload written in the same second as the cutover
            # commit predates the code being installed anywhere.
            at = cfixture(dir, "at.jld2", MARKER_CUTOVER_UNIX)
            @test admit_payload(at).provenance === :unmarked
            one_later = cfixture(joinpath(mkpath(joinpath(dir, "s"))), "s.jld2",
                MARKER_CUTOVER_UNIX + 1)
            @test admit_payload(one_later).provenance === :rejected
        end
    end

    @testset "D: a MARKED payload after the cutoff is unaffected" begin
        # The cutoff must bound arm (b) only. If it reached the marked path, every
        # run this cutover writes would reject itself — the marker is written
        # after the payload, so its own mtime is always after the cutoff.
        mktempdir() do dir
            _reset_unmarked_warnings!()
            p = cfixture(dir, "good.jld2", AFTER)
            write_complete_marker(p, [p]; kind="point")
            set_mtime!(p, AFTER)   # `write_complete_marker` does not touch it, but pin it
            a = admit_payload(p)
            @test a.hit
            @test a.provenance === :marked
        end
    end

    @testset "E: a TOMBSTONE still out-votes, on both sides of the cutoff" begin
        mktempdir() do dir
            _reset_unmarked_warnings!()
            for (name, epoch) in (("old.jld2", BEFORE), ("new.jld2", AFTER))
                sub = mkpath(joinpath(dir, splitext(name)[1]))
                p = cfixture(sub, name, epoch)
                write_incomplete_marker(p, [p]; kind="point", reason="killed")
                r = admit_payload(p)
                @test r.provenance === :rejected
                # The tombstone is checked FIRST, so its reason is the one
                # reported — not the cutoff's.
                @test occursin("did NOT complete", r.reason)
            end
        end
    end

    @testset "F: an absent payload is still `:absent`, not `:rejected`" begin
        mktempdir() do dir
            a = admit_payload(joinpath(dir, "nothing_here.jld2"))
            @test !a.hit
            @test a.provenance === :absent
        end
    end
end
