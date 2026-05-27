#!/usr/bin/env julia
#
# klaus_quench_mode_extract.jl — Batch A mechanism extraction.
#
# For each of 4 representative cells, extract from the post-hold frame:
#   - |psi[c]|^2 (density) z=0 slice for c = m_init, m_init∓1, m_init∓2
#   - arg(psi[c])         z=0 slice for the same components
#   - winding number on the peak-density ring (m∓1 and m∓2 only)
#   - per-component normalised population N_c / N_total at end
#
# Cells:
#   Ω=0 baseline             (m=-F init, no rotation)
#   Ω=-0.5 keep_rot matched  (m=-F init, Ω=-0.5)
#   Ω=+0.5 mismatched        (m=-F init, Ω=+0.5)   ← weak branch
#   m=+F reversed-matched    (m=+F init, Ω=+0.5)   ← chirality-mirror
#
# Output: docs/manuscript/figures_data/klaus_quench_mode_extract.json
# (read by Python plotter to compose Fig K10).

using JLD2
using JSON
using CodecZstd
using Statistics

const ROOT = joinpath(@__DIR__, "..", "..", "runs")
const OUT = joinpath(@__DIR__, "..", "..", "docs", "manuscript", "figures_data")
mkpath(OUT)

const CELLS = [
    # (label, dir-prefix, init_m_sign)  init_m_sign +1 → m=+F (c=1); -1 → m=-F (c=13)
    ("Ω = 0 baseline (m=−F)",       "klaus_quench_om0p0_",                  -1),
    ("Ω = −0.5 keep_rot matched",   "klaus_quench_omm0p5_keeprot_",         -1),
    ("Ω = +0.5 mismatched (weak)",  "klaus_quench_omp0p5_keeprot_",         -1),
    ("Ω = +0.5 keep_rot, m=+F mirror", "klaus_quench_omp0p5_keeprot_mFplus_", +1),
]

# Component indices for psi[:, :, :, c]:
#   c=1 ↔ m=+6, c=2 ↔ m=+5, ..., c=7 ↔ m=0, ..., c=13 ↔ m=-6
m_to_c(m) = 7 - m   # so m=+6→c=1, m=0→c=7, m=-6→c=13.

function _find_dir(prefix::String)
    for d in readdir(ROOT; join=true)
        isdir(d) || continue
        # Need an EXACT prefix match — "klaus_quench_omp0p5_keeprot_" should NOT
        # accidentally pick up "klaus_quench_omp0p5_keeprot_mFplus_..." dirs.
        b = basename(d)
        startswith(b, prefix) || continue
        rest = b[length(prefix)+1:end]
        # rest should be only hex hash (8 chars) — if it starts with letters, skip.
        occursin(r"^[0-9a-f]+$", rest) || continue
        isfile(joinpath(d, "result.jld2")) || continue
        return d
    end
    return nothing
end

# Winding number on a ring of radius r_grid (in grid units) centred at the box
# centre, sampling n_theta angular points.  Discrete Stokes: sum the wrapped
# 2π-mod phase differences around the loop, divide by 2π.
function _winding_number(arg2d::AbstractMatrix{<:Real}, r_grid::Real, n_theta::Int=128)
    nx, ny = size(arg2d)
    cx = (nx + 1) / 2.0
    cy = (ny + 1) / 2.0
    pts = [(cx + r_grid * cos(2π*k/n_theta), cy + r_grid * sin(2π*k/n_theta))
           for k in 0:(n_theta-1)]
    # Bilinear-interpolate arg at each (real-valued) point.
    function _bilinterp(arr, x, y)
        i0 = clamp(floor(Int, x), 1, nx-1); i1 = i0 + 1
        j0 = clamp(floor(Int, y), 1, ny-1); j1 = j0 + 1
        fx = x - i0; fy = y - j0
        return (1-fx)*(1-fy)*arr[i0,j0] + fx*(1-fy)*arr[i1,j0] +
               (1-fx)*fy*arr[i0,j1] + fx*fy*arr[i1,j1]
    end
    # Bilinear interpolation of a phase array is wrong (would mix wrapped values).
    # Use nearest-neighbour for phase, then unwrap.
    function _nearest(arr, x, y)
        i = clamp(round(Int, x), 1, nx)
        j = clamp(round(Int, y), 1, ny)
        return arr[i, j]
    end
    phases = [_nearest(arg2d, p[1], p[2]) for p in pts]
    # Discrete winding: sum of wrapped phase differences.
    total = 0.0
    for k in 1:n_theta
        next_k = k == n_theta ? 1 : k + 1
        d = phases[next_k] - phases[k]
        while d >  π;  d -= 2π;  end
        while d < -π;  d += 2π;  end
        total += d
    end
    return total / (2π)
end

# Peak-radius search on a density slice (z=0): find the radius r at which
# the azimuthally-averaged density is maximal.
function _peak_radius(density2d::AbstractMatrix{<:Real}, n_theta::Int=64)
    nx, ny = size(density2d)
    cx = (nx + 1) / 2.0
    cy = (ny + 1) / 2.0
    r_max_grid = min(nx, ny) / 2 - 1
    rs = range(1.0, r_max_grid; length=Int(round(r_max_grid)))
    function _nearest(arr, x, y)
        i = clamp(round(Int, x), 1, nx)
        j = clamp(round(Int, y), 1, ny)
        return arr[i, j]
    end
    averages = Float64[]
    for r in rs
        s = 0.0
        for k in 0:(n_theta - 1)
            x = cx + r * cos(2π*k/n_theta)
            y = cy + r * sin(2π*k/n_theta)
            s += _nearest(density2d, x, y)
        end
        push!(averages, s / n_theta)
    end
    if isempty(averages); return 1.0; end
    idx = argmax(averages)
    return rs[idx]
end

function _process(label::String, prefix::String, init_m_sign::Int)
    d = _find_dir(prefix)
    if d === nothing
        println("skip $label — no dir matching $prefix")
        return nothing
    end
    res = joinpath(d, "result.jld2")
    println("Processing $label  ←  $res")
    jldopen(res, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        last_psi = g[frames[end]]
        nz = size(last_psi, 3)
        z_mid = (nz + 1) ÷ 2

        # Pick m components: m_init, m_init∓1, m_init∓2.
        # For m=-F (sign=-1): m_init=-6, m∓1=-5, m∓2=-4 → c=13, 12, 11.
        # For m=+F (sign=+1): m_init=+6, m∓1=+5, m∓2=+4 → c=1, 2, 3.
        m_init = init_m_sign * 6
        m1     = m_init - init_m_sign * 1   # toward 0
        m2     = m_init - init_m_sign * 2

        m_list = [m_init, m1, m2]
        c_list = [m_to_c(m) for m in m_list]

        comp_data = Dict{String, Any}()
        for (m, c) in zip(m_list, c_list)
            psi_c = view(last_psi, :, :, z_mid, c)
            dens = abs2.(psi_c)
            ph   = angle.(psi_c)

            # Peak radius from density.
            r_pk = _peak_radius(dens)
            # Winding on ring at r_pk (only meaningful for excited components).
            w = _winding_number(ph, r_pk)

            comp_data["m_$m"] = Dict(
                "density" => [Float64.(dens[i, :]) for i in 1:size(dens, 1)],
                "phase"   => [Float64.(ph[i, :])  for i in 1:size(ph, 1)],
                "peak_radius_grid" => r_pk,
                "winding_number"   => w,
            )
            println("    m=$m  c=$c  peak_r≈$(round(r_pk; digits=1))  winding≈$(round(w; digits=2))")
        end

        # Also extract total spin populations N_m / N at end for the same m.
        Nm_end = [sum(abs2, view(last_psi, :, :, :, c)) for c in 1:size(last_psi, 4)]
        N_total = sum(Nm_end)
        comp_data["N_per_m_normalised"] = Dict("m_$m" => Nm_end[m_to_c(m)] / N_total
                                                for m in m_list)
        comp_data["label"] = label
        comp_data["init_m_sign"] = init_m_sign
        comp_data["m_init"] = m_init
        comp_data["box"] = 12.0
        comp_data["n_grid"] = size(last_psi, 1)
        return comp_data
    end
end

function main()
    out = Dict{String, Any}()
    for (label, prefix, sign) in CELLS
        result = _process(label, prefix, sign)
        if result !== nothing
            out[label] = result
        end
    end
    outpath = joinpath(OUT, "klaus_quench_mode_extract.json")
    open(outpath, "w") do io
        JSON.print(io, out, 2)
    end
    println("\nWrote $outpath")
end

main()
