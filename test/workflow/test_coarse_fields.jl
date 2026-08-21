using Test
using SpinorBEC
using JLD2

# TIER 1 — what survives deleting the frames.
#
# The tiering had its ends and not its middle: summary.json is 19 scalars, the
# frames are 5-10 GB and the first thing anyone deletes, and between them nothing.
# The moment the frames go, every SPATIAL fact about the run goes with them.
const _G = "dynamics/psi_snapshots_streamed"

function _frames(path; n, sz=(8, 8, 8), D=3, hot=nothing)
    jldopen(path, "w") do f
        f["dynamics/times"] = collect(1.0:n)
        f["$_G/n_snapshots"] = n
        f["$_G/spatial_shape"] = collect(sz)
        f["$_G/n_components"] = D
        for s in 1:n
            a = zeros(ComplexF32, sz..., D)
            a .= 1.0f0
            hot === nothing || (a[hot..., 1] = 10.0f0)
            f["$_G/frame_" * lpad(s, 5, '0')] = a
        end
    end
end

@testset "coarse fields outlive the frames" begin
    @testset "written, small, and idempotent" begin
        mktempdir() do d
            pt = joinpath(d, "point_001.jld2")
            _frames(pt; n=40)
            @test write_coarse_fields(d, pt; n_coarse=4, max_frames=8) === :written
            out = joinpath(d, "coarse.jld2")
            @test isfile(out)
            # The tier only works if it is cheap enough never to delete.
            @test filesize(out) < filesize(pt)
            jldopen(out, "r") do f
                @test size(f["density"]) == (4, 4, 4, 8)      # frames SAMPLED, not all
                @test size(f["per_m"]) == (4, 4, 4, 3, 8)
                @test length(f["frame_index"]) == 8
                @test haskey(f, "mid_planes")                 # last frame, full res
                # and it says which code produced it — a Tier-1 file that outlives
                # its run is exactly the one whose provenance cannot be looked up
                @test haskey(f["provenance"], "git_hash")
            end
            @test write_coarse_fields(d, pt) === :already      # the sweep may re-call
        end
    end

    @testset "block MEAN keeps a one-voxel feature; subsampling would coin-flip it" begin
        # A vortex core is one voxel wide. This is the reason for the mean, so it
        # is the thing asserted rather than the implementation.
        mktempdir() do d
            pt = joinpath(d, "point_001.jld2")
            _frames(pt; n=1, sz=(8, 8, 8), hot=(2, 2, 2))     # a bright voxel OFF the
            @test write_coarse_fields(d, pt; n_coarse=2) === :written  # subsample grid
            jldopen(joinpath(d, "coarse.jld2"), "r") do f
                dm = f["density"][:, :, :, 1]
                # the block holding it must be brighter than a block without it
                @test dm[1, 1, 1] > dm[2, 2, 2]
            end
        end
    end

    @testset "refuses rather than throwing" begin
        mktempdir() do d
            pt = joinpath(d, "point_001.jld2")
            jldopen(f -> (f["psi"] = zeros(ComplexF32, 2, 2, 2, 3)), pt, "w")
            @test write_coarse_fields(d, pt) === :no_frames    # nothing to coarsen
            @test !isfile(joinpath(d, "coarse.jld2"))
        end
        mktempdir() do d
            pt = joinpath(d, "point_001.jld2")
            write(pt, "truncated")
            @test write_coarse_fields(d, pt) === :unreadable   # and does NOT throw
        end
        mktempdir() do d
            @test write_coarse_fields(d, joinpath(d, "absent.jld2")) === :unreadable
        end
    end
end
