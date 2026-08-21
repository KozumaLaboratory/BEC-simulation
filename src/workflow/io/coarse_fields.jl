export write_coarse_fields, COARSE_FIELDS_FILENAME

const COARSE_FIELDS_FILENAME = "coarse.jld2"

"""
    write_coarse_fields(run_dir, jld2_path; n_coarse=16, max_frames=32) -> Symbol

Emit `<run_dir>/coarse.jld2` — the Tier-1 artifact: **what survives deleting the
frames**.

The tiering already had its ends and not its middle. Tier 0 is `summary.json`,
19 scalars per run including `_repo_commit`. Tier 2 is the frames, 5-10 GB and
the first thing anyone deletes. Between them, nothing: the moment the frames go,
every SPATIAL fact about the run goes with them, and what is left cannot answer
"was it a vortex or a domain wall" at any price short of re-running.

So this keeps the shape and throws away the resolution. On a 64³ run with 750
frames it is ~3 MB against ~10 GB — 0.03 %, cheap enough that it never needs to
be deleted, which is the whole point of a tier.

WHAT IT KEEPS, and each choice is a decision about what a deleted run can still
be asked:

  `density`     block-mean |ψ|² on an n_coarse³ grid, per sampled frame.
                Block MEAN, not subsampling: a vortex core is one voxel wide and
                subsampling either lands on it or misses it, while the mean keeps
                the depletion as a shallower dip that is still there.
  `per_m`       the same, per spin component — the texture, not just the cloud.
  `mid_planes`  the z mid-plane at FULL resolution for the last frame, one per
                component. The one place a core is still resolvable.
  `times`       which frames these are, so a scrubber can be rebuilt coarsely.

FRAMES ARE SAMPLED, not all read: `max_frames` evenly spaced. Reading 750 frames
of a 10 GB file at finish time to build a 3 MB summary would cost more than the
run's last minute; 32 is enough to see a trajectory and costs seconds.

Returns `:written`, `:already` (idempotent — the sweep and the finish hook both
call it), `:no_frames`, or `:unreadable`. It never throws: a Tier-1 artifact that
can fail a run is worse than no Tier-1 artifact.
"""
function write_coarse_fields(run_dir::AbstractString, jld2_path::AbstractString;
    n_coarse::Int=16, max_frames::Int=32)
    out = joinpath(run_dir, COARSE_FIELDS_FILENAME)
    isfile(out) && return :already
    isfile(jld2_path) || return :unreadable
    grp = "dynamics/psi_snapshots_streamed"

    try
        jldopen(jld2_path, "r") do f
            haskey(f, "$grp/n_snapshots") || return :no_frames
            n = Int(f["$grp/n_snapshots"])
            n > 0 || return :no_frames
            idx =
                n <= max_frames ? collect(1:n) :
                unique(round.(Int, range(1, n; length=max_frames)))

            times = haskey(f, "dynamics/times") ? Vector{Float64}(f["dynamics/times"]) :
                    Float64[]
            dens = nothing
            perm = nothing
            mid = nothing
            for (j, s) in enumerate(idx)
                key = "$grp/frame_" * lpad(s, 5, '0')
                haskey(f, key) || continue
                psi = f[key]
                sz = size(psi)
                nd = length(sz) - 1
                D = sz[end]
                if dens === nothing
                    dens = zeros(Float32, ntuple(_ -> n_coarse, nd)..., length(idx))
                    perm = zeros(Float32, ntuple(_ -> n_coarse, nd)..., D, length(idx))
                end
                @views for c in 1:D
                    blk = _block_mean(abs2.(psi[ntuple(_ -> Colon(), nd)..., c]), n_coarse)
                    perm[ntuple(_ -> Colon(), nd)..., c, j] .= blk
                    dens[ntuple(_ -> Colon(), nd)..., j] .+= blk
                end
                if j == length(idx) && nd == 3
                    kz = sz[3] ÷ 2 + 1
                    mid = Array{Float32}(abs2.(psi[:, :, kz, :]))
                end
            end
            dens === nothing && return :no_frames

            jldopen(out, "w") do g
                g["density"] = dens
                g["per_m"] = perm
                g["frame_index"] = idx
                g["times"] = isempty(times) ? Float64[] : times[min.(idx, length(times))]
                mid === nothing || (g["mid_planes"] = mid)
                g["n_coarse"] = n_coarse
                g["source"] = basename(jld2_path)
                g["provenance"] = run_provenance()
            end
            :written
        end
    catch err
        @warn "coarse field emit failed (non-fatal)" run_dir exception = err
        isfile(out) && rm(out; force=true)
        :unreadable
    end
end

"""Block MEAN onto an `m`-per-side grid. Averages rather than subsamples, so a
one-voxel feature survives as a shallower feature instead of a coin flip."""
function _block_mean(a::AbstractArray{T, N}, m::Int) where {T, N}
    out = zeros(Float32, ntuple(_ -> m, N))
    cnt = zeros(Int, ntuple(_ -> m, N))
    sz = size(a)
    @inbounds for I in CartesianIndices(a)
        J = CartesianIndex(ntuple(d -> min(m, 1 + ((I[d] - 1) * m) ÷ sz[d]), N))
        out[J] += Float32(a[I])
        cnt[J] += 1
    end
    @inbounds for I in eachindex(out)
        cnt[I] > 0 && (out[I] /= cnt[I])
    end
    out
end
