#!/usr/bin/env julia
#
# klaus_magnetic_stirrer_summary.jl — Klaus-II observables.  For each cell
# read result.jld2, compute:
#   N(t), Fz(t)         (from pre-computed arrays)
#   N_m(t)              for m=+6, +5, +4 (load-bearing for m=+F init)
#   peak_density(t)
#   Q(t) ellipticity    (from psi snapshots; complex-valued density quadrupole)
#
# Output: runs/magnetic_stirrer/summary.json

using JLD2
using JSON
using CodecZstd
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "magnetic_stirrer")

function _find_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    ymtime = mtime(yaml_path)
    runs_root = joinpath(@__DIR__, "..", "..", "runs")
    cand = String[]
    re = Regex("^" * base * "_[0-9a-f]{8}\$")
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        occursin(re, basename(d)) || continue
        isfile(joinpath(d, "result.jld2")) || continue
        mtime(d) > ymtime || continue
        push!(cand, d)
    end
    isempty(cand) && return nothing
    sort!(cand; by=d -> mtime(d))
    last(cand)
end

# Density ellipticity Q = (⟨x²−y²⟩ + 2i⟨xy⟩) / ⟨x²+y²⟩.  Box = 12 a_ho, n=32.
function _density_ellipticity(psi::AbstractArray{<:Complex,4}; box::Float64=12.0)
    nx, ny, nz, nc = size(psi)
    dx = box / nx
    cx = (nx + 1) / 2.0
    cy = (ny + 1) / 2.0
    Sxmy = 0.0; Sxy = 0.0; Sxpy = 0.0
    @inbounds for ix in 1:nx
        x = (ix - cx) * dx
        for iy in 1:ny
            y = (iy - cy) * dx
            for iz in 1:nz
                ntot = 0.0
                for ic in 1:nc
                    ntot += abs2(psi[ix, iy, iz, ic])
                end
                Sxmy += (x*x - y*y) * ntot
                Sxy  += x * y * ntot
                Sxpy += (x*x + y*y) * ntot
            end
        end
    end
    if Sxpy < 1e-30
        return complex(0.0)
    end
    return (Sxmy / Sxpy) + 2im * (Sxy / Sxpy)
end

function _compute(yaml_path::String, label::String)
    d = _find_dir(yaml_path)
    d === nothing && return (label=label, status="PENDING")
    res = joinpath(d, "result.jld2")
    f = try; jldopen(res, "r"); catch; return (label=label, status="LOCKED"); end
    try
        times = haskey(f, "dynamics/times") ? Vector{Float64}(f["dynamics/times"]) : Float64[]
        norms = haskey(f, "dynamics/norms") ? Vector{Float64}(f["dynamics/norms"]) : Float64[]
        Fz = haskey(f, "dynamics/Fz") ? Vector{Float64}(f["dynamics/Fz"]) : Float64[]
        cp = haskey(f, "dynamics/component_populations") ?
             Matrix{Float64}(f["dynamics/component_populations"]) : nothing
        g = haskey(f, "dynamics/psi_snapshots_streamed") ?
            f["dynamics/psi_snapshots_streamed"] : nothing

        # Q ellipticity at each snapshot.
        Q_real = Float64[]; Q_imag = Float64[]
        if g !== nothing
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            for fr in frames
                psi = g[fr]
                Q = _density_ellipticity(psi)
                push!(Q_real, real(Q))
                push!(Q_imag, imag(Q))
            end
        end

        # Layout: c=1↔m=+6, c=2↔m=+5, c=3↔m=+4, ..., c=13↔m=−6.
        # For m=+F init, load-bearing P_adj uses m=+5 (c=2), m=+4 (c=3).
        max_P_p54 = 0.0
        max_P_exc_high = 0.0
        if cp !== nothing
            n_frames = size(cp, 1)
            for k in 1:n_frames
                Ntot = sum(cp[k, :])
                Ntot < 1e-30 && continue
                p54 = (cp[k, 2] + cp[k, 3]) / Ntot
                pe  = 1.0 - cp[k, 1] / Ntot
                max_P_p54     = max(max_P_p54, p54)
                max_P_exc_high = max(max_P_exc_high, pe)
            end
        end

        peak_ratio = 1.0
        if g !== nothing
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            if !isempty(frames)
                peak0 = maximum(SpinorBEC.total_density(g[frames[1]], 3))
                peak_max = peak0
                for fr in frames
                    pk = maximum(SpinorBEC.total_density(g[fr], 3))
                    peak_max = max(peak_max, pk)
                end
                peak_ratio = peak_max / peak0
            end
        end

        N_final_ratio = (isempty(norms) ? NaN : norms[end] / norms[1])
        Fz_per_N_initial = (isempty(Fz) ? NaN : Fz[1] / norms[1])
        Fz_per_N_final   = (isempty(Fz) ? NaN : Fz[end] / norms[end])

        return (label=label, status="OK", outdir=d,
                sample_t = times,
                sample_N = norms,
                sample_Fz = Fz,
                sample_cp = cp,
                Q_real = Q_real, Q_imag = Q_imag,
                max_P_p54 = max_P_p54,
                max_P_exc_high = max_P_exc_high,
                peak_ratio = peak_ratio,
                N_final_ratio = N_final_ratio,
                Fz_per_N_initial = Fz_per_N_initial,
                Fz_per_N_final = Fz_per_N_final,
                DeltaFz_per_N = Fz_per_N_final - Fz_per_N_initial,
                max_Q_abs = isempty(Q_real) ? 0.0 :
                    maximum(sqrt(Q_real[i]^2 + Q_imag[i]^2) for i in eachindex(Q_real)),
        )
    finally
        close(f)
    end
end

function _parse_meta(label::String)
    omega = if occursin("omega_p", label)
        s = match(r"omega_p(\d+p\d+)", label).captures[1]
        +parse(Float64, replace(s, "p" => "."))
    else
        NaN
    end
    variant = if occursin("staticB", label)
        "staticB"
    elseif occursin("DDIoff", label)
        "DDIoff"
    elseif occursin("noquench", label)
        "noquench"
    else
        "core"
    end
    (omega=omega, variant=variant)
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# Klaus-II magnetic-stirrer summary")
    @printf("%-44s %-+6s %-10s %-8s %-9s %-9s %-+8s %-9s %-7s\n",
        "config", "Ω", "variant", "status", "max_P54", "max_Pexc", "Fz/N(T)", "N(T)/N(0)", "max|Q|")
    println(repeat("-", 130))
    rows = []
    for y in yamls
        label = splitext(basename(y))[1]
        meta = _parse_meta(label)
        obs = _compute(y, label)
        if obs.status == "OK"
            @printf("%-44s %-+6.1f %-10s %-8s %-9.4f %-9.4f %-+8.4f %-9.5f %-7.4f\n",
                label, meta.omega, meta.variant, "OK",
                obs.max_P_p54, obs.max_P_exc_high,
                obs.Fz_per_N_final, obs.N_final_ratio, obs.max_Q_abs)
        else
            @printf("%-44s %-+6.1f %-10s %-8s %-9s %-9s %-8s %-9s %-7s\n",
                label, meta.omega, meta.variant, obs.status, "-", "-", "-", "-", "-")
        end
        push!(rows, (label=label, meta=meta, obs=obs))
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        out_rows = []
        for r in rows
            if r.obs.status == "OK"
                push!(out_rows, Dict(
                    "label" => r.label,
                    "omega" => r.meta.omega,
                    "variant" => r.meta.variant,
                    "status" => "OK",
                    "sample_t" => r.obs.sample_t,
                    "sample_N" => r.obs.sample_N,
                    "sample_Fz" => r.obs.sample_Fz,
                    "Q_real" => r.obs.Q_real,
                    "Q_imag" => r.obs.Q_imag,
                    "max_P_p54" => r.obs.max_P_p54,
                    "max_P_exc_high" => r.obs.max_P_exc_high,
                    "peak_ratio" => r.obs.peak_ratio,
                    "N_final_ratio" => r.obs.N_final_ratio,
                    "Fz_per_N_initial" => r.obs.Fz_per_N_initial,
                    "Fz_per_N_final" => r.obs.Fz_per_N_final,
                    "DeltaFz_per_N" => r.obs.DeltaFz_per_N,
                    "max_Q_abs" => r.obs.max_Q_abs,
                ))
            else
                push!(out_rows, Dict(
                    "label" => r.label,
                    "omega" => r.meta.omega,
                    "variant" => r.meta.variant,
                    "status" => string(r.obs.status),
                ))
            end
        end
        JSON.print(io, Dict("rows" => out_rows), 2)
    end
    println("\nWrote $sjson")
end

main()
