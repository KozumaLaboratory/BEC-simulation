# The run directory is keyed on the config's BYTES, not on the producing commit.
# So the same YAML under a different commit lands in the same directory and every
# cached point is skipped — silently returning results computed by other code.
# `_assert_point_provenance` is what stops that, and this pins it.
#
# Audited 2026-07-31: docs/validation/cas_run_dir_audit.md.

using Test
using SpinorBEC
using JLD2

const _PG_TMP = mktempdir()

"Write a point file carrying a given env dict (or none at all)."
function _fake_point(name; env=nothing)
    p = joinpath(_PG_TMP, name)
    jldopen(p, "w") do d
        d["psi"] = ComplexF64[1.0;;;;]
        env === nothing || (d["env"] = env)
    end
    p
end

_env(hash, dirty) = Dict{String, Any}("git_hash" => hash, "git_dirty" => dirty)

@testset "run-dir key + cached-point provenance gate" begin
    @testset "compute_run_dir: 16 hex, and byte-sensitive" begin
        a = joinpath(_PG_TMP, "cfg_a.yaml")
        b = joinpath(_PG_TMP, "cfg_b.yaml")
        write(a, "pipeline: []\n")
        write(b, "pipeline: []\n# a comment changes the bytes\n")

        da = SpinorBEC.compute_run_dir(a; base_dir=_PG_TMP)
        db = SpinorBEC.compute_run_dir(b; base_dir=_PG_TMP)
        suffix = split(basename(da), "_")[end]

        # Commitment #4 says 16 hex. It was 8 (32 bits), which reaches a 1 %
        # collision probability at ~9e3 files sharing a basename.
        @test length(suffix) == 16
        @test all(c -> c in "0123456789abcdef", suffix)
        @test da != db                                   # different bytes, different dir
        @test da == SpinorBEC.compute_run_dir(a; base_dir=_PG_TMP)   # deterministic
    end

    @testset "provenance gate" begin
        clean = _env("abc1234", false)

        # POSITIVE CONTROL FIRST: a matching clean provenance must be ALLOWED,
        # otherwise every assertion below would pass against a gate that simply
        # rejects everything.
        ok = _fake_point("point_ok.jld2"; env=clean)
        @test SpinorBEC._assert_point_provenance(ok, clean; verbose=false) === nothing

        # Different commit — the case this exists for.
        @test_throws ErrorException SpinorBEC._assert_point_provenance(
            ok, _env("def5678", false); verbose=false)

        # Dirty on either side: the commit does not identify the code.
        dirty_pt = _fake_point("point_dirty.jld2"; env=_env("abc1234", true))
        @test_throws ErrorException SpinorBEC._assert_point_provenance(
            dirty_pt, clean; verbose=false)
        @test_throws ErrorException SpinorBEC._assert_point_provenance(
            ok, _env("abc1234", true); verbose=false)

        # No provenance recorded at all — every pre-2026-07-31 point file.
        bare = _fake_point("point_bare.jld2")
        @test_throws ErrorException SpinorBEC._assert_point_provenance(
            bare, clean; verbose=false)

        # The message has to name the override, or nobody can act on it.
        err = try
            SpinorBEC._assert_point_provenance(ok, _env("def5678", false); verbose=false)
            nothing
        catch e
            sprint(showerror, e)
        end
        @test err !== nothing
        @test occursin("SPINORBEC_ALLOW_STALE_POINTS", err)
        @test occursin("def5678", err)                   # names the commit it wanted
    end

    @testset "override opens the gate, and only while set" begin
        clean = _env("abc1234", false)
        bare = _fake_point("point_bare2.jld2")
        withenv("SPINORBEC_ALLOW_STALE_POINTS" => "1") do
            @test SpinorBEC._assert_point_provenance(bare, clean; verbose=false) === nothing
        end
        # ...and closes again, so a stray export cannot silently persist.
        @test_throws ErrorException SpinorBEC._assert_point_provenance(
            bare, clean; verbose=false)
    end
end
