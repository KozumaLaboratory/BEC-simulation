using Test
using SpinorBEC
using JLD2

# `result.jld2` is a SUMMARY artifact (anko's decision on PR #195, which closed a
# symlink-collapse attempt for changing the design rather than fixing a bug). It
# was not one: 9.11 GB against point_001's 9.55 GB on a 750-frame run, 148.4 GB
# across 136 pairs on the group volume. `make_result_a_summary!` drops the frames
# once a real point file provably carries them.
#
# The assertions are on the CLASSIFICATION and on what survives, because the
# failure mode is silent data loss: a wrong refusal costs disk, a wrong summary
# costs the only copy of a multi-GB run.
const _GRP = "dynamics/psi_snapshots_streamed"

function _write_frames(path; n, shape=[2, 2, 2], comps=3, extra=Dict{String, Any}())
    jldopen(path, "w") do f
        f["psi"] = zeros(ComplexF32, shape..., comps)
        f["dynamics/times"] = collect(1.0:n)
        f["$_GRP/n_snapshots"] = n
        f["$_GRP/spatial_shape"] = shape
        f["$_GRP/n_components"] = comps
        for s in 1:n
            f["$_GRP/frame_" * lpad(s, 5, '0')] = zeros(ComplexF32, shape..., comps)
        end
        for (k, v) in extra
            f[k] = v
        end
    end
end

@testset "result.jld2 becomes a summary only when the point file covers it" begin
    @testset "summarises, and keeps everything that is not a frame" begin
        mktempdir() do d
            res = joinpath(d, "result.jld2")
            pt = joinpath(d, "point_001.jld2")
            _write_frames(
                res;
                n=4,
                extra=Dict("dynamics/Lz" => [1.0, 2.0],
                    "dynamics/integrator_meta/dt_used" => 0.004),
            )
            _write_frames(pt; n=4)
            before = filesize(res)
            @test make_result_a_summary!(d, pt) === :summarised
            @test filesize(res) < before
            jldopen(res, "r") do f
                @test !haskey(f, "$_GRP/n_snapshots")     # the frames are gone
                @test haskey(f, "psi")                     # and nothing else is
                @test f["dynamics/times"] == collect(1.0:4)
                @test f["dynamics/Lz"] == [1.0, 2.0]
                # the nested group must survive as a GROUP, not be flattened away
                @test f["dynamics/integrator_meta/dt_used"] == 0.004
            end
            # idempotent — a second pass has nothing to do and says so
            @test make_result_a_summary!(d, pt) === :already_summary
        end
    end

    @testset "REFUSES when the point file does not cover the frames" begin
        # fewer frames
        mktempdir() do d
            res, pt = joinpath(d, "result.jld2"), joinpath(d, "point_001.jld2")
            _write_frames(res; n=6)
            _write_frames(pt; n=3)
            @test make_result_a_summary!(d, pt) === :not_covered
            @test jldopen(f -> haskey(f, "$_GRP/n_snapshots"), res, "r")
        end
        # different spatial shape — same count, different data
        mktempdir() do d
            res, pt = joinpath(d, "result.jld2"), joinpath(d, "point_001.jld2")
            _write_frames(res; n=3, shape=[2, 2, 2])
            _write_frames(pt; n=3, shape=[4, 2, 2])
            @test make_result_a_summary!(d, pt) === :not_covered
        end
        # point file carries no frames at all
        mktempdir() do d
            res, pt = joinpath(d, "result.jld2"), joinpath(d, "point_001.jld2")
            _write_frames(res; n=3)
            jldopen(f -> (f["psi"] = zeros(ComplexF32, 2, 2, 2, 3)), pt, "w")
            @test make_result_a_summary!(d, pt) === :not_covered
        end
    end

    @testset "REFUSES on the rotating-basis shape — result.jld2 is the only copy" begin
        # `save_rotating_basis_result!` symlinks point_001.jld2 AT result.jld2.
        # Stripping there destroys the frames outright, which is the one outcome
        # this function must never produce.
        mktempdir() do d
            res, pt = joinpath(d, "result.jld2"), joinpath(d, "point_001.jld2")
            _write_frames(res; n=3)
            symlink("result.jld2", pt)
            @test make_result_a_summary!(d, pt) === :skipped
            @test jldopen(f -> f["$_GRP/n_snapshots"], res, "r") == 3
        end
    end

    @testset "inert when there is no result.jld2" begin
        mktempdir() do d
            pt = joinpath(d, "point_001.jld2")
            _write_frames(pt; n=2)
            @test make_result_a_summary!(d, pt) === :skipped
        end
    end
end
