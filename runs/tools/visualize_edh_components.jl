#!/usr/bin/env julia
# Per-m diagnostic for an EdH-style 3D Eu151 result. Reports populations,
# Mz drift, density envelope, and the |F→F-k| phase winding signature
# expected from Einstein-de Haas spin-orbital coupling.
#
# Usage:
#   julia --project=. runs/tools/visualize_edh_components.jl <path.jld2> [box]
#
# `box` overrides the dimensionless box length per axis (defaults to
# 20.0 — matches `runs/eu151_edh/config.yaml`). When the input lives
# under runs/<run>/, the script also reads <run>/config.yaml's
# `grid.box` if present; the explicit CLI arg always wins.

using JLD2, Statistics, Printf, YAML

function _resolve_box(jld2_path::String; cli_box::Union{Nothing, Float64}=nothing)
    cli_box !== nothing && return cli_box
    cfg_path = joinpath(dirname(jld2_path), "config.yaml")
    if isfile(cfg_path)
        try
            data = YAML.load_file(cfg_path)
            pipeline = get(data, "pipeline", nothing)
            if pipeline isa Vector && !isempty(pipeline)
                gs = get(pipeline[1], "ground_state", nothing)
                if gs isa Dict
                    grid = get(gs, "grid", nothing)
                    if grid isa Dict
                        b = get(grid, "box", nothing)
                        b isa AbstractVector && return Float64(b[1])
                        b isa Number && return Float64(b)
                    end
                end
            end
        catch e
            @warn "Failed to read box from $cfg_path; using default 20.0" exception=e
        end
    end
    20.0
end

function main(jld2_path::String, box::Float64)
    isfile(jld2_path) || error("File not found: $jld2_path")

    psi, energy = jldopen(jld2_path, "r") do f
        (f["psi"], haskey(f, "energy") ? f["energy"] : NaN)
    end

    ndim = ndims(psi) - 1
    ndim == 3 || error("visualize_edh_components.jl requires a 3D ψ (got $(ndim)D)")
    D = size(psi, 4)
    F = (D - 1) ÷ 2
    Ns = ntuple(d -> size(psi, d), ndim)
    dx = box / Ns[1]
    dV = dx^ndim

    total_norm = sum(abs2, psi) * dV
    @printf("File: %s\n", jld2_path)
    @printf("Grid: %s  F=%d  D=%d\n", join(string.(Ns), "×"), F, D)
    @printf("Total norm: %.6f  Energy: %.4f\n\n", total_norm, energy)

    # Per-component analysis
    mz_total = 0.0
    println("=== Per-component populations ===")
    for c in 1:D
        m = F + 1 - c
        pop = sum(abs2, @view psi[:,:,:,c]) * dV
        mz_total += m * pop / total_norm
        @printf("  m=%+d: %.5f (%.2f%%)\n", m, pop, 100 * pop / total_norm)
    end
    @printf("\nMz = %.4f (initial = %+d.0)\n", mz_total, F)
    @printf("ΔMz = %.4f → ΔLz = %.4f (EdH: Jz conserved)\n",
            F - mz_total, mz_total - F)

    # Total density
    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    @printf("\n=== Total density ===\n")
    @printf("  Peak: %.6f  Min(>0): %.2e\n", maximum(dens), minimum(dens[dens .> 0]))
    cloud = dens[dens .> maximum(dens) * 0.01]
    @printf("  Max/Mean(cloud): %.2f  Std/Mean: %.4f\n",
            maximum(dens) / mean(cloud), std(cloud) / mean(cloud))

    # RMS radius
    x = range(-box/2 + dx/2, box/2 - dx/2; length=Ns[1])
    r2_sum = 0.0; d_sum = 0.0
    for iz in 1:Ns[3], iy in 1:Ns[2], ix in 1:Ns[1]
        d = dens[ix, iy, iz]
        r2_sum += d * (x[ix]^2 + x[iy]^2 + x[iz]^2)
        d_sum += d
    end
    @printf("  RMS radius: %.3f a_ho\n", sqrt(r2_sum / d_sum))

    # Column densities (integrate along z)
    println("\n=== Column densities (z-integrated) ===")
    for c in 1:D
        m = F + 1 - c
        col = dropdims(sum(abs2.(@view psi[:,:,:,c]); dims=3); dims=3) * dx
        pk = maximum(col)
        # Radial profile through center
        cx = Ns[1] ÷ 2
        radial = col[cx, :]
        @printf("  m=%+d: peak_col=%.6f\n", m, pk)
    end

    # Phase winding analysis (vortex detection)
    z0 = Ns[3] ÷ 2
    cx = Ns[1] ÷ 2; cy = Ns[2] ÷ 2
    r_test = 3.0  # ring radius in a_ho
    n_angles = 16

    println("\n=== Phase winding at r=$(r_test) a_ho (z=0 slice) ===")
    for c in 1:D
        m = F + 1 - c
        comp = @view psi[:,:,z0,c]
        amp_center = abs(psi[cx, cy, z0, c])

        phases = Float64[]
        for θ in range(0, 2π; length=n_angles+1)[1:end-1]
            ix = clamp(round(Int, cx + r_test / dx * cos(θ)), 1, Ns[1])
            iy = clamp(round(Int, cy + r_test / dx * sin(θ)), 1, Ns[2])
            push!(phases, angle(psi[ix, iy, z0, c]))
        end
        dphase = [mod(phases[i+1] - phases[i] + π, 2π) - π for i in 1:length(phases)-1]
        push!(dphase, mod(phases[1] - phases[end] + π, 2π) - π)
        winding = sum(dphase) / (2π)
        amp_ring = mean([abs(psi[
            clamp(round(Int, cx + r_test / dx * cos(θ)), 1, Ns[1]),
            clamp(round(Int, cy + r_test / dx * sin(θ)), 1, Ns[2]),
            z0, c]) for θ in range(0, 2π; length=n_angles)])

        @printf("  m=%+d: winding=%.2f  |ψ|_center=%.2e  |ψ|_ring=%.2e\n",
                m, winding, amp_center, amp_ring)
    end

    # EdH signature: Δm = -1 carries Δℓ = +1 vorticity
    println("\n=== Expected EdH pattern ===")
    println("  m=F:   ℓ=0 (no vortex, sphere)")
    println("  m=F-1: ℓ=1 (single vortex, ring)")
    println("  m=F-2: ℓ=2 (double vortex, 2 rings)")
    println("  ...each Δm=-1 adds Δℓ=+1")
end

function _entry()
    if isempty(ARGS)
        # Default: latest EdH result if present
        default = "runs/eu151_edh/point_001.jld2"
        isfile(default) ||
            (println("Usage: julia --project=. runs/tools/visualize_edh_components.jl <path.jld2> [box]"); return)
        main(default, _resolve_box(default))
    else
        path = ARGS[1]
        cli_box = length(ARGS) >= 2 ? Float64(parse(Float64, ARGS[2])) : nothing
        main(path, _resolve_box(path; cli_box))
    end
end

_entry()
