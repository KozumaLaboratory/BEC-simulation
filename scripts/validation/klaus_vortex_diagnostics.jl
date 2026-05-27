#!/usr/bin/env julia
#
# klaus_vortex_diagnostics.jl — fluid diagnostics for the Klaus mechanism.
#
# anko 2026-05-27: Q(t) ellipticity only sees the global cloud shape; the
# real Klaus mechanism is "chirality-selected vortex-carrying EdH modes"
# — a cloud that looks circular in density can still host many small
# mass vortices and carry significant L_z per component.  This script
# extracts the load-bearing fluid observables on the post-hold z=0 plane:
#
#   total density            n(x, y) = Σ_c |ψ_c|²
#   total mass current       j(x, y) = Σ_c Im[ψ_c* ∇ ψ_c]
#   velocity                 v(x, y) = j(x, y) / n(x, y)
#   vorticity                ω_z(x, y) = (∇ × v)_z
#   per-component L_z        L_z^{(m)} = ∫ ψ_c* (-i)(x ∂_y − y ∂_x) ψ_c d³r
#   per-component vortex count via plaquette phase winding
#     for each plaquette of size 1 grid cell on the z=0 slice, sum
#     wrapped phase differences around the loop; integer = ±1 → vortex
#
# Output: docs/manuscript/figures_data/klaus_quench_vortex_extract.json
# Cells: same 4 as klaus_quench_mode_extract.jl (Ω=0 baseline,
#        Ω=−0.5 matched, Ω=+0.5 mismatched, m=+F mirror).

using JLD2
using JSON
using CodecZstd

const ROOT = joinpath(@__DIR__, "..", "..", "runs")
const OUT = joinpath(@__DIR__, "..", "..", "docs", "manuscript", "figures_data")
mkpath(OUT)

const CELLS = [
    ("Ω = 0 baseline (m=−F)",          "klaus_quench_om0p0_",                  -1),
    ("Ω = −0.5 keep_rot matched",      "klaus_quench_omm0p5_keeprot_",         -1),
    ("Ω = +0.5 mismatched (weak)",     "klaus_quench_omp0p5_keeprot_",         -1),
    ("Ω = +0.5 keep_rot, m=+F mirror", "klaus_quench_omp0p5_keeprot_mFplus_", +1),
]

m_to_c(m) = 7 - m

function _find_dir(prefix::String)
    for d in readdir(ROOT; join=true)
        isdir(d) || continue
        b = basename(d)
        startswith(b, prefix) || continue
        rest = b[length(prefix)+1:end]
        occursin(r"^[0-9a-f]+$", rest) || continue
        isfile(joinpath(d, "result.jld2")) || continue
        return d
    end
    return nothing
end

# Central-difference ∂_x on a 2D slice (Float).  Returns a same-shape array.
function _ddx(field::AbstractMatrix{T}, dx::Float64) where T
    nx, ny = size(field)
    out = zeros(T, nx, ny)
    @inbounds for i in 2:nx-1
        for j in 1:ny
            out[i, j] = (field[i+1, j] - field[i-1, j]) / (2 * dx)
        end
    end
    return out
end
function _ddy(field::AbstractMatrix{T}, dy::Float64) where T
    nx, ny = size(field)
    out = zeros(T, nx, ny)
    @inbounds for j in 2:ny-1
        for i in 1:nx
            out[i, j] = (field[i, j+1] - field[i, j-1]) / (2 * dy)
        end
    end
    return out
end

# Plaquette vortex detection: for each unit square (i,j)-(i+1,j+1) on the
# 2D phase array, sum the wrapped phase differences around the loop.
# Returns: (n_plus, n_minus, vortex_mask)
function _detect_vortices(phase::AbstractMatrix{<:Real}, density::AbstractMatrix{<:Real};
                          density_threshold::Float64=0.0)
    nx, ny = size(phase)
    n_plus = 0; n_minus = 0
    mask = zeros(Int, nx-1, ny-1)
    @inbounds for i in 1:nx-1
        for j in 1:ny-1
            # Loop: (i,j) → (i+1,j) → (i+1,j+1) → (i,j+1) → (i,j)
            ph_corners = [phase[i,j], phase[i+1,j], phase[i+1,j+1], phase[i,j+1]]
            avg_n = (density[i,j] + density[i+1,j] +
                     density[i+1,j+1] + density[i,j+1]) / 4.0
            if avg_n < density_threshold
                continue
            end
            total = 0.0
            for k in 1:4
                a = ph_corners[k]
                b = ph_corners[k == 4 ? 1 : k + 1]
                d = b - a
                while d > π;  d -= 2π;  end
                while d < -π;  d += 2π;  end
                total += d
            end
            w = round(Int, total / (2π))
            if w > 0
                n_plus += w
                mask[i, j] = w
            elseif w < 0
                n_minus += -w
                mask[i, j] = w
            end
        end
    end
    return (n_plus, n_minus, mask)
end

# Component-resolved L_z (volume-integrated, dimensionless ℏ=M=1).
function _Lz_component(psi_c::AbstractArray{<:Complex,3}, dx::Float64, x::Vector{Float64},
                       y::Vector{Float64})
    nx, ny, nz = size(psi_c)
    Lz = 0.0
    @inbounds for k in 1:nz
        for j in 2:ny-1
            for i in 2:nx-1
                # (-i)(x ∂_y − y ∂_x)  acting on psi_c, sandwiched with psi_c*
                # First compute (x ∂_y − y ∂_x) psi_c at (i,j,k):
                dpsi_dx = (psi_c[i+1, j, k] - psi_c[i-1, j, k]) / (2 * dx)
                dpsi_dy = (psi_c[i, j+1, k] - psi_c[i, j-1, k]) / (2 * dx)
                Lc = x[i] * dpsi_dy - y[j] * dpsi_dx
                # ⟨L_z⟩ contribution: Im(ψ*·Lψ) since L = -i d/dφ
                Lz += imag(conj(psi_c[i, j, k]) * Lc) * (-1.0)
            end
        end
    end
    return Lz * dx^3
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
        psi = g[frames[end]]
        nx, ny, nz, nc = size(psi)
        box = 12.0
        dx = box / nx
        x = [(i - (nx + 1) / 2) * dx for i in 1:nx]
        y = [(j - (ny + 1) / 2) * dx for j in 1:ny]
        z_mid = (nz + 1) ÷ 2

        # z=0 slice quantities.
        density_total = zeros(nx, ny)
        jx_total = zeros(nx, ny)
        jy_total = zeros(nx, ny)
        for c in 1:nc
            psi_c_2d = view(psi, :, :, z_mid, c)
            dens_c = abs2.(psi_c_2d)
            density_total .+= dens_c
            # j = Im[ψ* ∇ψ]
            re_psi = real.(psi_c_2d); im_psi = imag.(psi_c_2d)
            dpsi_dx = (real.(_ddx(complex.(re_psi, im_psi), dx)) +
                       1im * imag.(_ddx(complex.(re_psi, im_psi), dx)))
            dpsi_dy = (real.(_ddy(complex.(re_psi, im_psi), dx)) +
                       1im * imag.(_ddy(complex.(re_psi, im_psi), dx)))
            jx_total .+= imag.(conj.(psi_c_2d) .* dpsi_dx)
            jy_total .+= imag.(conj.(psi_c_2d) .* dpsi_dy)
        end

        # Velocity v = j/n with density-floor mask.
        n_peak = maximum(density_total)
        density_floor = 1e-3 * n_peak
        vx = similar(jx_total)
        vy = similar(jy_total)
        for i in eachindex(density_total)
            n = density_total[i]
            vx[i] = (n > density_floor) ? jx_total[i] / n : 0.0
            vy[i] = (n > density_floor) ? jy_total[i] / n : 0.0
        end

        # Vorticity ω_z = ∂_x v_y − ∂_y v_x.
        vort = _ddx(vy, dx) .- _ddy(vx, dx)

        # Per-component vortex count + L_z^{(m)} on m_init, m_init∓1, m_init∓2.
        m_init = init_m_sign * 6
        m_list = [m_init, m_init - init_m_sign, m_init - 2 * init_m_sign]
        c_list = [m_to_c(m) for m in m_list]
        # Vortex threshold: half-peak of the component density on z=0 plane.
        comp_data = Dict{String, Any}()
        Lz_per_m = Dict{String, Float64}()
        for (m, c) in zip(m_list, c_list)
            psi_c_3d = view(psi, :, :, :, c)
            psi_c_2d = view(psi_c_3d, :, :, z_mid)
            dens_c = abs2.(psi_c_2d)
            ph_c = angle.(psi_c_2d)
            comp_peak = maximum(dens_c)
            # Detect vortices ABOVE half of the COMPONENT peak (so they appear
            # within the support of that m component).
            thr = 0.2 * comp_peak
            (n_plus, n_minus, mask) = _detect_vortices(ph_c, dens_c; density_threshold=thr)
            comp_data["m_$m"] = Dict(
                "n_plus_vortices" => n_plus,
                "n_minus_vortices" => n_minus,
                "component_peak_density" => comp_peak,
            )
            # L_z per component (volume-integrated).
            Lz_per_m["m_$m"] = _Lz_component(psi_c_3d, dx, x, y)
            println("    m=$m  c=$c  vortices: +$n_plus / −$n_minus  L_z^{(m)} = $(round(Lz_per_m["m_$m"]; digits=4))")
        end

        # Total L_z (sum over components).
        Lz_total = sum(values(Lz_per_m))

        # Reduced slices for plotting (downsample if large).
        # Keep full 32×32 for visualisation; 1024 floats per slice = trivial.
        out = Dict{String, Any}(
            "label" => label,
            "init_m_sign" => init_m_sign,
            "m_init" => m_init,
            "box" => box,
            "n_grid" => nx,
            "density_total" => [Float64.(density_total[i, :]) for i in 1:nx],
            "jx_total"      => [Float64.(jx_total[i, :])      for i in 1:nx],
            "jy_total"      => [Float64.(jy_total[i, :])      for i in 1:nx],
            "vorticity_z"   => [Float64.(vort[i, :])          for i in 1:nx],
            "n_peak"        => n_peak,
            "components"    => comp_data,
            "Lz_per_m"      => Lz_per_m,
            "Lz_total"      => Lz_total,
        )
        return out
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
    outpath = joinpath(OUT, "klaus_quench_vortex_extract.json")
    open(outpath, "w") do io
        JSON.print(io, out, 2)
    end
    println("\nWrote $outpath")
end

main()
