#!/usr/bin/env julia
#
# klaus_quench_summary.jl — extract trajectory observables for the
# 10-cell klaus_quench scan and write summary.json.
#
# Per cell:
#   N_m(t)              population in each m component (13 entries)
#   N_total(t)
#   Fz(t)               = Σ m · N_m(t)
#   peak_density(t)
#
# Per-cell derived metrics:
#   max P_{-5,-4}       = max_t [N_{-5}(t) + N_{-4}(t)] / N(t)
#   max P_exc           = 1 - min_t N_{-6}(t) / N(t)
#   peak_ratio          = max(peak_density) / peak_density(0)
#   N_final_ratio       = N(T) / N(0)
#   Fz_per_N_final      = Fz(T) / N(T)

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench")

function _find_output_dir(yaml_path::String)
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

"""
    _spin_populations(psi)

Sum |psi|^2 over space for each spin component, returning a 13-element Vector{Float64}.
psi has layout psi[x, y, z, c] with c=1..13 corresponding to m=+F..−F.
"""
function _spin_populations(psi::AbstractArray{<:Complex,4})
    D = size(psi, 4)
    Nm = zeros(Float64, D)
    for c in 1:D
        @views Nm[c] = sum(abs2, psi[:, :, :, c])
    end
    return Nm
end

function _compute(yaml_path::String, label::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (label=label, status="PENDING")
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (label=label, status="PENDING")
    f = try
        jldopen(res, "r")
    catch
        return (label=label, status="LOCKED")
    end
    try
        # Use the last dynamics step's snapshots (weak-field hold). For the
        # protocol we want the full timeline; concatenate per-step trajectories
        # if multiple dynamics blocks were emitted.
        g_root = f
        # Streamed snapshots may live in subgroups per dynamics step.
        # First try "dynamics/psi_snapshots_streamed" (single-stage convention);
        # else iterate "dynamics_<n>/psi_snapshots_streamed".
        psi_groups = String[]
        times_grp = String[]
        norm_grp = String[]
        Fz_grp = String[]
        if haskey(f, "dynamics/psi_snapshots_streamed")
            push!(psi_groups, "dynamics/psi_snapshots_streamed")
            push!(times_grp, "dynamics/times")
            push!(norm_grp, "dynamics/norms")
            push!(Fz_grp, "dynamics/Fz")
        else
            for key in keys(f)
                if startswith(key, "dynamics") && haskey(f[key], "psi_snapshots_streamed")
                    push!(psi_groups, "$key/psi_snapshots_streamed")
                    haskey(f[key], "times") && push!(times_grp, "$key/times")
                    haskey(f[key], "norms") && push!(norm_grp, "$key/norms")
                    haskey(f[key], "Fz") && push!(Fz_grp, "$key/Fz")
                end
            end
        end

        isempty(psi_groups) && return (label=label, status="NO_SNAPSHOTS", outdir=outdir)

        all_times = Float64[]
        all_norms = Float64[]
        all_Fz = Float64[]
        all_Nm = Vector{Vector{Float64}}()
        all_peaks = Float64[]
        for pg in psi_groups
            g = f[pg]
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            for fr in frames
                psi = g[fr]
                Nm = _spin_populations(psi)
                push!(all_Nm, Nm)
                push!(all_norms, sum(Nm))
                push!(all_Fz, sum((6.0 - (c-1)) * Nm[c] for c in 1:length(Nm)))
                push!(all_peaks, Float64(maximum(SpinorBEC.total_density(psi, 3))))
            end
            # times array if present
            tname = replace(pg, "psi_snapshots_streamed" => "times")
            if haskey(f, tname)
                t_arr = Vector{Float64}(f[tname])
                append!(all_times, t_arr)
            else
                # fall back to indices
                for k in 1:length(frames)
                    push!(all_times, length(all_times) + 1.0)
                end
            end
        end

        # Derived metrics. Layout: c=1 (m=+6), c=2 (m=+5), ..., c=7 (m=0), ..., c=13 (m=-6).
        # So m=+5 → c=2, m=+4 → c=3, m=+6 → c=1; m=−5 → c=12, m=−4 → c=11, m=−6 → c=13.
        c_m_plus_6  = 1
        c_m_plus_5  = 2
        c_m_plus_4  = 3
        c_m_minus_6 = 13
        c_m_minus_5 = 12
        c_m_minus_4 = 11
        P_54 = [(Nm[c_m_minus_5] + Nm[c_m_minus_4]) / sum(Nm) for Nm in all_Nm]
        P_p54 = [(Nm[c_m_plus_5] + Nm[c_m_plus_4]) / sum(Nm) for Nm in all_Nm]
        P_exc_low  = [1.0 - Nm[c_m_minus_6] / sum(Nm) for Nm in all_Nm]
        P_exc_high = [1.0 - Nm[c_m_plus_6]  / sum(Nm) for Nm in all_Nm]
        # For m=+F initial states, the symmetric observable is P_{+5,+4} and
        # 1 − N_{+6}/N. Provide both so the analysis can pick.
        max_P_54  = maximum(P_54)
        max_P_p54 = maximum(P_p54)
        max_P_exc = maximum(P_exc_low)
        max_P_exc_high = maximum(P_exc_high)
        peak_ratio = maximum(all_peaks) / all_peaks[1]
        N_final_ratio = all_norms[end] / all_norms[1]
        Fz_per_N_final = all_Fz[end] / all_norms[end]
        Fz_per_N_initial = all_Fz[1] / all_norms[1]

        return (label=label, status="OK", outdir=outdir,
            n_frames=length(all_Nm),
            sample_t=collect(all_times),
            sample_Nm=[Vector{Float64}(Nm) for Nm in all_Nm],
            sample_N=all_norms,
            sample_Fz=all_Fz,
            sample_peak=all_peaks,
            sample_P_54=P_54,
            sample_P_p54=P_p54,
            sample_P_exc=P_exc_low,
            sample_P_exc_high=P_exc_high,
            max_P_54=max_P_54,
            max_P_p54=max_P_p54,
            max_P_exc=max_P_exc,
            max_P_exc_high=max_P_exc_high,
            peak_ratio=peak_ratio,
            N_initial=all_norms[1],
            N_final=all_norms[end],
            N_final_ratio=N_final_ratio,
            Fz_per_N_initial=Fz_per_N_initial,
            Fz_per_N_final=Fz_per_N_final,
            DeltaFz_per_N=Fz_per_N_final - Fz_per_N_initial,
        )
    finally
        close(f)
    end
end

function _parse_meta(label::String)
    # name pattern: klaus_quench_omNAME[_VARIANT]
    # NAME ∈ {0p0, m0p3, m0p5, m0p7, p0p3, p0p5}
    # VARIANT ∈ {<none>, DDIoff, noBquench, keeprot}
    omega = if occursin("omm", label)
        s = match(r"omm(\d+p\d+)", label).captures[1]
        -parse(Float64, replace(s, "p" => "."))
    elseif occursin("omp", label)
        s = match(r"omp(\d+p\d+)", label).captures[1]
        +parse(Float64, replace(s, "p" => "."))
    elseif occursin("om0p0", label)
        0.0
    else
        NaN
    end
    ddi_on = !occursin("DDIoff", label)
    do_quench = !occursin("noBquench", label)
    keep_rot = occursin("keeprot", label)
    # Combined-flag variants take precedence (most specific first).
    variant = if occursin("mFplus", label) && occursin("keeprot", label)
        "keeprot_mFplus"
    elseif occursin("holdonly", label)
        "holdonly"
    elseif occursin("dt2", label) && occursin("keeprot", label)
        "keeprot_dt2"
    elseif occursin("dt2", label)
        "core_dt2"
    elseif occursin("N50k", label) && occursin("keeprot", label)
        "keeprot_N50k"
    elseif occursin("N50k", label)
        "core_N50k"
    elseif occursin("Bf", label)
        "keeprot_" * match(r"Bf\d+p?\d*", label).match
    elseif occursin("keeprot", label) && occursin("DDIoff", label)
        "keeprot_DDIoff"
    elseif occursin("keeprot", label) && occursin("n64", label)
        "keeprot_n64"
    elseif occursin("n64", label)
        "core_n64"
    elseif occursin("DDIoff", label)
        "DDIoff"
    elseif occursin("noBquench", label)
        "noBquench"
    elseif occursin("keeprot", label)
        "keeprot"
    else
        "core"
    end
    init_m_sign = occursin("mFplus", label) ? +1 : -1
    (omega=omega, ddi_on=ddi_on, do_quench=do_quench, keep_rot=keep_rot,
     variant=variant, init_m_sign=init_m_sign)
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# klaus_quench summary — 2-phase rotation/quench protocol scan")
    println("# Eu-151 F=6, 32³, N=1e4, c1/c0=1/36, ω_⊥=2π·110 Hz, t_total ≈ 21 ms")
    println()
    @printf("%-40s %-+6s %-5s %-10s %-9s %-9s %-9s %-+8s %-10s\n",
        "config", "Ω", "DDI", "variant", "status", "maxP_54", "maxP_exc", "Fz/N(T)", "N(T)/N(0)")
    println(repeat("-", 130))

    rows = []
    for y in yamls
        label = splitext(basename(y))[1]
        meta = _parse_meta(label)
        obs = _compute(y, label)
        if obs.status == "OK"
            @printf("%-40s %-+6.1f %-5s %-10s %-9s %-9.4f %-9.4f %-+8.4f %-10.5f\n",
                label, meta.omega, meta.ddi_on ? "on" : "off", meta.variant, "OK",
                obs.max_P_54, obs.max_P_exc, obs.Fz_per_N_final, obs.N_final_ratio)
        else
            @printf("%-40s %-+6.1f %-5s %-10s %-9s %-9s %-9s %-8s %-10s\n",
                label, meta.omega, meta.ddi_on ? "on" : "off", meta.variant, obs.status,
                "-", "-", "-", "-")
        end
        push!(rows, (label=label, meta=meta, obs=obs))
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            r.obs.status == "OK" ?
            Dict(
                "label" => r.label,
                "omega" => r.meta.omega, "ddi_on" => r.meta.ddi_on,
                "do_quench" => r.meta.do_quench, "keep_rot" => r.meta.keep_rot,
                "variant" => r.meta.variant,
                "init_m_sign" => r.meta.init_m_sign,
                "status" => "OK",
                "n_frames" => r.obs.n_frames,
                "sample_t" => r.obs.sample_t,
                "sample_Nm" => r.obs.sample_Nm,
                "sample_N" => r.obs.sample_N,
                "sample_Fz" => r.obs.sample_Fz,
                "sample_peak" => r.obs.sample_peak,
                "sample_P_54" => r.obs.sample_P_54,
                "sample_P_p54" => r.obs.sample_P_p54,
                "sample_P_exc" => r.obs.sample_P_exc,
                "sample_P_exc_high" => r.obs.sample_P_exc_high,
                "max_P_54" => r.obs.max_P_54,
                "max_P_p54" => r.obs.max_P_p54,
                "max_P_exc" => r.obs.max_P_exc,
                "max_P_exc_high" => r.obs.max_P_exc_high,
                "peak_ratio" => r.obs.peak_ratio,
                "N_initial" => r.obs.N_initial,
                "N_final" => r.obs.N_final,
                "N_final_ratio" => r.obs.N_final_ratio,
                "Fz_per_N_initial" => r.obs.Fz_per_N_initial,
                "Fz_per_N_final" => r.obs.Fz_per_N_final,
                "DeltaFz_per_N" => r.obs.DeltaFz_per_N,
            ) :
            Dict(
                "label" => r.label,
                "omega" => r.meta.omega, "ddi_on" => r.meta.ddi_on,
                "do_quench" => r.meta.do_quench, "keep_rot" => r.meta.keep_rot,
                "variant" => r.meta.variant,
                "init_m_sign" => r.meta.init_m_sign,
                "status" => string(r.obs.status),
            )
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
