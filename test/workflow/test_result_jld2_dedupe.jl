using Test
using SpinorBEC
using JLD2

# `run_pipeline` auto-saves `result.jld2` with the full streamed snapshot payload
# and symlinks `point_001.jld2` at it, explicitly "so we don't duplicate the
# multi-GB snapshot data". `_run_yaml_single` then writes the real point file
# over that symlink, so both end up carrying every frame. One 753-frame Eu movie
# run measured 10.25 GB + 9.71 GB; 23 such pairs had reached 83.7 GB of pure
# duplication on the TSUBAME work volume.
#
# `_collapse_duplicate_result_jld2` keeps the point file — the richer one — and
# turns `result.jld2` into a symlink to it. The load-bearing precondition is that
# the point file must contain EVERY key `result.jld2` has, top level and one
# level into `dynamics`: `save_rotating_basis_result!` writes `Lz`,
# `per_m_history` and `integrator_meta` for rotating-basis runs, which the point
# file does not carry, and collapsing those would lose data.

const _DEDUPE = SpinorBEC._collapse_duplicate_result_jld2

function _write_pair(dir; point_extra=String[], result_dyn=["times", "norms"],
    point_dyn=["times", "norms"])
    res = joinpath(dir, "result.jld2")
    pt = joinpath(dir, "point_001.jld2")
    jldopen(res, "w") do f
        f["psi"] = ComplexF64[1 2; 3 4]
        for k in result_dyn
            f["dynamics/$k"] = Float64[1.0, 2.0, 3.0]
        end
    end
    jldopen(pt, "w") do f
        f["psi"] = ComplexF64[1 2; 3 4]
        for k in point_dyn
            f["dynamics/$k"] = Float64[1.0, 2.0, 3.0]
        end
        for k in point_extra
            f[k] = 1.0
        end
    end
    (res, pt)
end

@testset "result.jld2 dedupe" begin
    @testset "collapses when the point file is a superset" begin
        d = mktempdir()
        res, pt = _write_pair(d; point_extra=["energy", "converged"],
            point_dyn=["times", "norms", "energies", "peak_density"])
        before = filesize(res)
        @test before > 0
        @test !islink(res)

        @test _DEDUPE(d, pt; verbose=false)
        @test islink(res)                                 # now a symlink
        @test realpath(res) == realpath(pt)               # ... to the point file
        @test readlink(res) == "point_001.jld2"           # relative, so the dir can move

        # Everything a reader of result.jld2 wanted is still reachable through it.
        jldopen(res, "r") do f
            @test haskey(f, "psi")
            @test f["dynamics/times"] == Float64[1.0, 2.0, 3.0]
            @test haskey(f, "energy")                     # bonus: the richer file
        end
    end

    @testset "refuses when result.jld2 has a key the point file lacks" begin
        # The rotating-basis shape: Lz / per_m_history / integrator_meta live in
        # result.jld2 only. Collapsing here would silently lose them.
        d = mktempdir()
        res, pt = _write_pair(d;
            result_dyn=["times", "norms", "Lz", "per_m_history"],
            point_dyn=["times", "norms"])
        @test !_DEDUPE(d, pt; verbose=false)
        @test !islink(res)                                # untouched
        jldopen(res, "r") do f
            @test haskey(f, "dynamics/Lz")                # still there
        end
    end

    @testset "top-level keys count too, not just dynamics" begin
        d = mktempdir()
        res = joinpath(d, "result.jld2")
        pt = joinpath(d, "point_001.jld2")
        jldopen(res, "w") do f
            f["psi"] = ComplexF64[1 2; 3 4]
            f["something_only_result_has"] = 7.0
        end
        jldopen(pt, "w") do f
            f["psi"] = ComplexF64[1 2; 3 4]
        end
        @test !_DEDUPE(d, pt; verbose=false)
        @test !islink(res)
    end

    @testset "idempotent and inert on the already-collapsed / absent cases" begin
        d = mktempdir()
        res, pt = _write_pair(d)
        @test _DEDUPE(d, pt; verbose=false)
        @test !_DEDUPE(d, pt; verbose=false)      # already a symlink → no-op
        @test islink(res)

        d2 = mktempdir()
        pt2 = joinpath(d2, "point_001.jld2")
        jldopen(pt2, "w") do f
            f["psi"] = ComplexF64[1 2]
        end
        @test !_DEDUPE(d2, pt2; verbose=false)    # no result.jld2 at all
    end
end
