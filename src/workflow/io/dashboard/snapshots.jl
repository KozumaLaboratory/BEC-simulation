# --- Snapshot resolution: load_psi_cached + sibling-result.jld2 redirect + metadata ---

"""Load psi from JLD2 with caching. Returns (psi, n_comp, ndim, n_pts, F).

When `snap_idx === nothing` (default) the final `psi` field is returned.
When `snap_idx` is a positive integer, loads the requested time-slice
from `dynamics/psi_snapshots` (saved by runs with
`save_psi_snapshots: true`); the 5D array is up-cast to ComplexF64 so
downstream code (FFT, probability_current, etc.) runs at its native
precision."""
function _load_psi_cached(
    jld2_path::String,
    cache::Dict{String, Any},
    snap_idx::Union{Nothing, Int}=nothing,
)
    key = snap_idx === nothing ? jld2_path : "$(jld2_path)#snap=$(snap_idx)"
    if haskey(cache, key)
        return cache[key]
    end
    # Evict oldest when at cap (Dicts iterate in insertion order in Julia,
    # so popfirst!-style first-key removal gives us FIFO eviction).
    while length(cache) >= PSI_CACHE_MAX_ENTRIES
        _evict_one!(cache)
    end
    # Snap requests redirect to the sibling result.jld2 when the requested
    # file (typically point_NNN.jld2 from the lab-frame spinor pipeline)
    # only carries a static final ψ. Static-ψ requests stay on jld2_path
    # so the dashboard's "open run" hop still gets the metadata-bearing
    # point file even when result.jld2 also exists.
    src_path = snap_idx === nothing ? jld2_path : _resolve_snapshot_source(jld2_path)
    get!(cache, key) do
        if snap_idx === nothing
            d = JLD2.load(src_path)
            psi = d["psi"]
        else
            # Two on-disk layouts are supported:
            #   (1) streamed — one key per frame, keys
            #       "dynamics/psi_snapshots_streamed/frame_00001" … 00154.
            #       Written by the current simulator; peak memory on the
            #       write side is one snapshot.
            #   (2) legacy — a single 5D array "dynamics/psi_snapshots"
            #       with the snapshot index on the trailing axis.
            # Only read the requested frame in either case; never stack.
            #
            # Read at the on-disk precision (ComplexF32 by default per
            # `save_snapshot_precision: "f32"`). Promoting to ComplexF64
            # here doubled disk read + conversion cost; the binary
            # column/phase packers already cast to Float32, and the
            # JSON helpers promote via `Float64(...)` lazily, so they
            # don't care.
            psi = _with_jld_handle(src_path) do f
                if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                    n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                    k = clamp(snap_idx, 1, n)
                    key = "dynamics/psi_snapshots_streamed/frame_" *
                          lpad(string(k), 5, '0')
                    f[key]
                elseif haskey(f, "dynamics/psi_snapshots")
                    snaps = f["dynamics/psi_snapshots"]
                    n = size(snaps, ndims(snaps))
                    k = clamp(snap_idx, 1, n)
                    idx = ntuple(
                        d -> d == ndims(snaps) ? k : Colon(),
                        ndims(snaps),
                    )
                    Array(view(snaps, idx...))
                elseif haskey(f, "psi_snapshots")
                    # Top-level Vector{Array{Complex,N+1}} layout (legacy
                    # launch_thesis_run.jl / launch_phi_omega_run.jl prior
                    # to 2026-04-28 unification — kept for back-compat).
                    snaps = f["psi_snapshots"]
                    n = length(snaps)
                    k = clamp(snap_idx, 1, n)
                    snaps[k]
                else
                    throw(
                        ArgumentError(
                            "No psi snapshots in $(jld2_path). Re-run with " *
                            "`save_psi_snapshots: true`.",
                        ),
                    )
                end
            end
        end
        n_comp = size(psi, ndims(psi))
        ndim = ndims(psi) - 1
        F = div(n_comp - 1, 2)
        n_pts = ntuple(i -> size(psi, i), ndim)
        (psi, n_comp, ndim, n_pts, F)
    end
end

"""Return the path that actually carries the streamed dynamics snapshots
for `jld2_path`. The lab-frame spinor pipeline writes only the static
final ψ + scalar traces to point_NNN.jld2, while the per-frame spinor
volumes live in sibling result.jld2 (canonical streamed layout). If
the requested file has its own snapshots (rotating_basis path, or a
legacy run that embedded them) return it unchanged; otherwise
redirect to the sibling result.jld2 when present."""
function _resolve_snapshot_source(jld2_path::String)
    try
        has_streams = jldopen(jld2_path, "r") do f
            haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots") ||
                haskey(f, "dynamics/psi_snapshots") ||
                haskey(f, "psi_snapshots")
        end
        has_streams && return jld2_path
    catch
        # fall through to sibling search
    end
    sibling = joinpath(dirname(jld2_path), "result.jld2")
    if isfile(sibling) && sibling != jld2_path
        return sibling
    end
    jld2_path
end

"""Return metadata about the saved snapshot time series, or nothing if
the file has no `dynamics/psi_snapshots` key."""
function _snapshots_metadata(jld2_path::String)
    src_path = _resolve_snapshot_source(jld2_path)
    try
        # Use a fresh handle here rather than the persistent
        # _OPEN_JLD_HANDLES one: this function holds the lock for the
        # entire 16-frame `_global_density_max_total_sampled` walk
        # (~250 ms), which would block the background prepack and any
        # in-flight scrub fetches sharing the handle. /api/snapshots is
        # called once per run-open hop, so the per-call open cost is
        # acceptable in exchange for not starving the hot path.
        jldopen(src_path, "r") do f
            times = haskey(f, "dynamics/times") ?
                    Float64.(f["dynamics/times"]) : Float64[]
            if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                shape = Int.(f["dynamics/psi_snapshots_streamed/spatial_shape"])
                D = Int(f["dynamics/psi_snapshots_streamed/n_components"])
                # `times` includes t=0 (the GS state) PLUS one entry per
                # save_every checkpoint. Streamed frames only cover the
                # checkpoints, so times has length n+1. Slice the leading
                # t=0 off so times[k] aligns with frame_NNNNN where N=k.
                times_aligned = length(times) == n + 1 ? times[2:end] : times
                # density_max_total moved to its own /api/density_max
                # endpoint — the 16-frame walk took ~0.8 s and blocked the
                # snapshots response. Lazy fetch keeps run-open instant.
                return Dict{String, Any}(
                    "n_snapshots" => n,
                    "times" => times_aligned,
                    "shape" => vcat(shape, D),
                )
            elseif haskey(f, "dynamics/psi_snapshots")
                snaps = f["dynamics/psi_snapshots"]
                n_snaps = size(snaps, ndims(snaps))
                times_aligned = length(times) == n_snaps + 1 ? times[2:end] : times
                return Dict{String, Any}(
                    "n_snapshots" => n_snaps,
                    "times" => times_aligned,
                    "shape" => collect(size(snaps)[1:(end - 1)]),
                )
            end
            nothing
        end
    catch
        nothing
    end
end

"""Sub-sample n_samples evenly-spaced snapshots and return the max
spin-summed total density across them. Full sweep through all 157
Klaus frames takes ~8 s; sub-sampled to 16 frames it's ~0.8 s,
within HTTP timeout budget. Always includes the first + last frame.

Returned value is the physically correct normalisation reference
for the 3D viewer (same density renders the same color frame-to-frame).
"""
function _global_density_max_total_sampled(f, n_snapshots::Int; n_samples::Int=16)
    n_snapshots == 0 && return 1.0
    # Sample indices: evenly spaced + include endpoints
    idxs = if n_snapshots <= n_samples
        collect(1:n_snapshots)
    else
        unique([1; round.(Int, range(1, n_snapshots; length=n_samples)); n_snapshots])
    end
    g_max = 0.0
    for k in idxs
        key = "dynamics/psi_snapshots_streamed/frame_" * lpad(string(k), 5, '0')
        haskey(f, key) || continue
        frame = f[key]
        ndim = ndims(frame) - 1
        D = size(frame, ndim + 1)
        # Spin-summed density per grid cell. Avoid CartesianIndices
        # for speed: sum over component axis with abs2.(view(...)).
        n_total = sum(c -> abs2.(view(frame, ntuple(d -> d <= ndim ? Colon() : c, ndim + 1)...)),
            1:D)
        local_max = Float64(maximum(n_total))
        local_max > g_max && (g_max = local_max)
    end
    g_max
end
