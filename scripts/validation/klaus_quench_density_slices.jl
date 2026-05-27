#!/usr/bin/env julia
#
# klaus_quench_density_slices.jl — extract z=0 density slices for the
# m=-6, -5, -4 components at 4 protocol checkpoints (initial / post-prep
# / post-quench / post-hold) from selected klaus_quench runs.
#
# Output: runs/<dir>/density_slices.json with per-checkpoint z=0 slices.
# Reads psi snapshots from dynamics/psi_snapshots_streamed/frame_NNNNN.

using JLD2
using JSON
using CodecZstd

const ROOT = joinpath(@__DIR__, "..", "..", "runs")

# Cells to extract (best Ω keep_rot at 32³, Ω=0 baseline at 32³).
const TARGETS = [
    ("klaus_quench_omm0p5_keeprot",  "keep_rot Ω=-0.5"),
    ("klaus_quench_om0p0",           "Ω=0 baseline"),
]

# Protocol-phase boundaries in dimensionless time (ω_ref⁻¹).
const T_ROT_END = 6.9115     # end of rotation_prep
const T_QUENCH_END = 7.6027  # 6.9115 + 0.6912
const T_HOLD_END = 14.5142   # 7.6027 + 6.9115

# z=0 slice: return |psi[:, :, z_mid, c]|² for c ∈ {m=-4, -5, -6} = c ∈ {11, 12, 13}.
function _slice_density(psi::AbstractArray{<:Complex,4})
    nz = size(psi, 3)
    z_mid = (nz + 1) ÷ 2
    out = Dict{String, Vector{Vector{Float64}}}()
    for (m, c) in [(-4, 11), (-5, 12), (-6, 13)]
        # Convert 2D slice to a vector of rows so JSON dumps cleanly.
        rows = [Float64[abs2(psi[ix, iy, z_mid, c]) for iy in 1:size(psi, 2)]
                for ix in 1:size(psi, 1)]
        out["m_$m"] = rows
    end
    return out
end

function _find_dir(base::String)
    for d in readdir(ROOT; join=true)
        isdir(d) || continue
        startswith(basename(d), base * "_") || continue
        isfile(joinpath(d, "result.jld2")) || continue
        return d
    end
    return nothing
end

function _process_cell(base::String, label::String)
    d = _find_dir(base)
    d === nothing && (println("skip $base — no dir"); return)
    res = joinpath(d, "result.jld2")
    println("Reading $res  ($label)")

    jldopen(res, "r") do f
        times = Vector{Float64}(f["dynamics/times"])
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))

        n_t = length(times)
        n_f = length(frames)
        n_use = min(n_t, n_f)
        # Trim to common length.
        times = times[1:n_use]
        frames = frames[1:n_use]

        # Pick checkpoint frames: argmin |t - target|.
        function _pick(t_target)
            i = argmin([abs(t - t_target) for t in times])
            return (idx=i, t=times[i], frame=frames[i])
        end
        cp = Dict(
            "initial"      => _pick(0.0),
            "post_prep"    => _pick(T_ROT_END),
            "post_quench"  => _pick(T_QUENCH_END),
            "post_hold"    => _pick(T_HOLD_END),
        )

        # Build output.
        out = Dict{String, Any}(
            "label" => label,
            "base" => base,
            "checkpoints" => Dict{String, Any}(),
            "box" => 12.0,  # from grid box=[12,12,12]
            "n_grid" => size(g[frames[1]], 1),
        )
        for (name, info) in cp
            psi = g[info.frame]
            out["checkpoints"][name] = Dict(
                "t" => info.t,
                "frame_index" => info.idx,
                "z_slice" => _slice_density(psi),
            )
            println("  $name :  t=$(round(info.t; digits=3))  frame=$(info.frame)")
        end

        outpath = joinpath(d, "density_slices.json")
        open(outpath, "w") do io
            JSON.print(io, out, 2)
        end
        println("  wrote $outpath")
    end
end

for (base, label) in TARGETS
    _process_cell(base, label)
end
