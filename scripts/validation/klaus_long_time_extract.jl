#!/usr/bin/env julia
# Extract data for Fig K13: P_exc(t) trajectories + end-of-hold z=0
# density slices + vortex positions for the 3 long-time cells.

using JLD2
using JSON
using CodecZstd
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs")
const OUT_DATA = joinpath(@__DIR__, "..", "..", "docs", "manuscript", "figures_data",
                          "klaus_long_time_extract.json")
mkpath(dirname(OUT_DATA))

const DIRS = [
    ("t100",        "klaus_long_omm0p5_holdonly_t100_8c6f0e66"),
    ("t350_rot",    "klaus_long_omm0p5_holdonly_t350_e8a7dfe4"),
    ("t350_base",   "klaus_long_om0p0_holdonly_t350_82babe5c"),
]

function _detect_vortices_positions(phase::AbstractMatrix{<:Real}, density::AbstractMatrix{<:Real},
                                     x::Vector{Float64}, y::Vector{Float64};
                                     density_threshold::Float64=0.0)
    nx, ny = size(phase)
    xs = Float64[]; ys = Float64[]; ss = Int[]
    @inbounds for i in 1:nx-1, j in 1:ny-1
        avg_n = (density[i,j] + density[i+1,j] + density[i+1,j+1] + density[i,j+1]) / 4.0
        avg_n < density_threshold && continue
        a = phase[i,j]; b = phase[i+1,j]; c = phase[i+1,j+1]; d = phase[i,j+1]
        total = 0.0
        for (p, q) in ((a,b),(b,c),(c,d),(d,a))
            delta = q - p
            while delta > π;  delta -= 2π;  end
            while delta < -π;  delta += 2π;  end
            total += delta
        end
        w = round(Int, total / (2π))
        if w != 0
            # Plaquette center.
            cx = (x[i] + x[i+1]) / 2
            cy = (y[j] + y[j+1]) / 2
            push!(xs, cx); push!(ys, cy); push!(ss, w)
        end
    end
    return (xs, ys, ss)
end

out = Dict{String, Any}()

for (key, basedir) in DIRS
    d = joinpath(ROOT, basedir)
    res = joinpath(d, "result.jld2")
    println("Processing $key  ←  $res")
    jldopen(res, "r") do f
        times = Vector{Float64}(f["dynamics/times"])
        norms = Vector{Float64}(f["dynamics/norms"])
        cp = Matrix{Float64}(f["dynamics/component_populations"])
        n_t = min(length(times), size(cp, 1))
        times = times[1:n_t]
        cp = cp[1:n_t, :]

        # P_exc(t) trajectory
        P_exc_t = [1 - cp[k, 13] / sum(cp[k, :]) for k in 1:n_t]
        t_ms = times .* 1000 / 691.15

        # End-of-hold psi snapshot.
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        psi_end = g[frames[end]]
        nx, ny, nz, nc = size(psi_end)
        box = 12.0
        dx = box / nx
        x = [(i - (nx + 1) / 2) * dx for i in 1:nx]
        y = [(j - (ny + 1) / 2) * dx for j in 1:ny]
        z_mid = (nz + 1) ÷ 2

        # Total density at z=0
        density_tot = zeros(nx, ny)
        psi_tot_complex = zeros(ComplexF64, nx, ny)
        for c in 1:nc
            sl = view(psi_end, :, :, z_mid, c)
            density_tot .+= abs2.(sl)
            psi_tot_complex .+= sl
        end
        ph_tot = angle.(psi_tot_complex)
        n_peak = maximum(density_tot)
        (vxs, vys, vss) = _detect_vortices_positions(ph_tot, density_tot, x, y;
                                                      density_threshold=0.1 * n_peak)

        out[key] = Dict(
            "t_ms" => collect(t_ms),
            "P_exc_t" => P_exc_t,
            "density_total_end" => [Float64.(density_tot[i, :]) for i in 1:nx],
            "vortex_positions_xs" => vxs,
            "vortex_positions_ys" => vys,
            "vortex_signs" => vss,
            "box" => box,
            "n_vortices_plus"  => count(>(0), vss),
            "n_vortices_minus" => count(<(0), vss),
        )
        println("  P_exc(end) = $(round(P_exc_t[end]; digits=4))")
        println("  vortices: +$(count(>(0), vss)) / -$(count(<(0), vss))")
    end
end

open(OUT_DATA, "w") do io
    JSON.print(io, out, 2)
end
println("Wrote $OUT_DATA")
