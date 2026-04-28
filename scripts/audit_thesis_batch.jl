# Comprehensive audit of 24 thesis_batch runs.
# Reports: norm conservation, Mz drift, m-population spectrum start/end,
# Lz extremes, Fz extremes, time-evolution sanity per group.

using JLD2
using Statistics
using Printf

const ROOT = "/home/suzume/workspace/BEC-simulation/runs/thesis_batch"

const BATCH_1 = ["dy164_main_500ms", "eu151_full_500ms", "eu151_no_ddi_500ms",
    "eu151_no_stir_500ms", "eu151_baseline_500ms", "eu151_no_chirp_500ms"]
const BATCH_2 = ["p_30", "p_100", "p_300", "p_1000", "p_3000", "p_10000"]
const BATCH_3 = ["c1_FM_strong", "c1_FM_weak", "c1_AFM_strong", "c1_AFM_weak",
    "cdd_half", "cdd_2x"]
const BATCH_4 = ["duration_1500ms", "duration_2000ms", "grid_48cube",
    "epsilon_1e6", "theta_25deg", "theta_45deg"]

struct RunSummary
    name::String
    n_frames::Int
    norm_init::Float64
    norm_final::Float64
    norm_max_dev::Float64
    Lz_min::Float64
    Lz_max::Float64
    Lz_final::Float64
    Fz_init::Float64
    Fz_final::Float64
    Fz_drift::Float64
    pm_init::Vector{Float64}
    pm_final::Vector{Float64}
    pm_init_top1::Float64
    pm_final_top1::Float64
    pm_final_top1_idx::Int
    duration::Float64
end

function load_run(name)
    path = joinpath(ROOT, name, "result_legacy.jld2")
    isfile(path) || return nothing
    d = JLD2.load(path)
    times = d["times"]::Vector
    norms = d["norms"]::Vector
    Lz = d["Lz"]::Vector
    Fz = d["Fz"]::Vector
    per_m_history = d["per_m_history"]   # D × T matrix
    n_frames = length(times)
    pm_init_raw = per_m_history[:, 1]
    pm_final_raw = per_m_history[:, end]
    pm_init = pm_init_raw / sum(pm_init_raw)
    pm_final = pm_final_raw / sum(pm_final_raw)
    top1_idx = argmax(pm_final)
    RunSummary(
        name, n_frames,
        norms[1], norms[end],
        maximum(abs.(norms .- 1.0)),
        minimum(Lz), maximum(Lz), Lz[end],
        Fz[1], Fz[end], Fz[end] - Fz[1],
        pm_init, pm_final,
        pm_init[1], pm_final[1], top1_idx,
        times[end] - times[1],
    )
end

function print_summary(sum_::RunSummary)
    pm_top3_init = sortperm(sum_.pm_init, rev = true)[1:min(3, length(sum_.pm_init))]
    pm_top3_final = sortperm(sum_.pm_final, rev = true)[1:min(3, length(sum_.pm_final))]
    println("  $(sum_.name)")
    println("    frames=$(sum_.n_frames), duration=$(round(sum_.duration; digits=2))")
    println("    norm: $(round(sum_.norm_init; digits=6)) → $(round(sum_.norm_final; digits=6))   max-dev: $(round(sum_.norm_max_dev; sigdigits=3))")
    println("    Lz:   final=$(round(sum_.Lz_final; digits=4))   range=[$(round(sum_.Lz_min; digits=3)), $(round(sum_.Lz_max; digits=3))]")
    println("    Fz:   $(round(sum_.Fz_init; digits=4)) → $(round(sum_.Fz_final; digits=4))   drift=$(round(sum_.Fz_drift; sigdigits=3))")
    @printf "    pm_init  top:  "
    for i in pm_top3_init
        @printf "[%d:%.4f] " i sum_.pm_init[i]
    end
    println()
    @printf "    pm_final top:  "
    for i in pm_top3_final
        @printf "[%d:%.4f] " i sum_.pm_final[i]
    end
    println()
end

println("=" ^ 80)
println("12h THESIS BATCH AUDIT — 24 runs at $(ROOT)")
println("=" ^ 80)

batches = [("Batch 1: thesis main", BATCH_1),
    ("Batch 2: p-sweep", BATCH_2),
    ("Batch 3: c1 / c_dd sweep", BATCH_3),
    ("Batch 4: protocol / numerical", BATCH_4)]

all_summaries = RunSummary[]
for (label, runs) in batches
    println("\n--- $label ---")
    for name in runs
        s = load_run(name)
        if s === nothing
            println("  $name  MISSING")
            continue
        end
        push!(all_summaries, s)
        print_summary(s)
    end
end

println("\n" * "=" ^ 80)
println("CROSS-RUN ANALYSIS")
println("=" ^ 80)

# Norm conservation — should be 1.0 throughout (RTP unitary)
println("\n# Norm conservation (max deviation from 1.0 across run)")
sorted_by_norm = sort(all_summaries, by = s -> s.norm_max_dev, rev = true)
for s in sorted_by_norm[1:min(5, length(sorted_by_norm))]
    @printf "  %-25s max_dev = %.3e\n" s.name s.norm_max_dev
end

# Fz drift — for spinor evolution, Fz can change (it's not strictly conserved
# under DDI), but huge drift suggests numerical issue.
println("\n# Fz drift (final − initial)")
sorted_by_fz = sort(all_summaries, by = s -> abs(s.Fz_drift), rev = true)
for s in sorted_by_fz[1:min(5, length(sorted_by_fz))]
    @printf "  %-25s drift = %+.4f  (init→final = %+.3f → %+.3f)\n" s.name s.Fz_drift s.Fz_init s.Fz_final
end

# GS quality — pm_init should ideally be 1.0 (m=+F polarised) for runs that
# initialise at m=+F. Anything < 0.95 indicates GS not properly converged.
println("\n# GS quality (pm_init for m=+F: should be ≈ 1.0 for polarised init)")
sorted_by_gs = sort(all_summaries, by = s -> s.pm_init_top1)
for s in sorted_by_gs[1:min(8, length(sorted_by_gs))]
    @printf "  %-25s pm_init[m=+F] = %.4f  (concerning if < 0.95)\n" s.name s.pm_init_top1
end

# Final m=+F populations — for the c_dd sweep, expect monotonic increase
# in transfer with c_dd.
println("\n# c_dd-sweep monotonicity check (B3)")
for nm in ["cdd_half", "eu151_full_500ms", "cdd_2x"]
    s = first(filter(s -> s.name == nm, all_summaries))
    @printf "  %-25s pm_final[m=+F] = %.4f\n" nm s.pm_final_top1
end

# c1 sweep — FM/AFM signs barely matter for m-transfer (DDI-driven), but
# strong vs weak should differ.
println("\n# c1 sweep cross-check (B3)")
for nm in ["c1_FM_strong", "c1_FM_weak", "c1_AFM_weak", "c1_AFM_strong"]
    s = first(filter(s -> s.name == nm, all_summaries))
    @printf "  %-25s pm_final[m=+F] = %.4f\n" nm s.pm_final_top1
end

# duration sweep — 500 → 1500 → 2000 ms, expect monotonic transfer
println("\n# Duration-sweep monotonicity (B1+B4)")
for nm in ["eu151_full_500ms", "duration_1500ms", "duration_2000ms"]
    s = first(filter(s -> s.name == nm, all_summaries))
    @printf "  %-25s pm_final[m=+F] = %.4f  (duration ~ %.1f)\n" nm s.pm_final_top1 s.duration
end

# p sweep — expect Goldilocks: small p adiabatic, intermediate p resonant
# with stir frequency ~4.524, large p adiabatic again
println("\n# p-sweep transfer profile (B2)")
for nm in ["p_30", "p_100", "p_300", "p_1000", "p_3000", "p_10000"]
    s = first(filter(s -> s.name == nm, all_summaries))
    @printf "  %-25s pm_init[+F]=%.4f → pm_final[+F]=%.4f   Fz_drift=%+.3f\n" nm s.pm_init_top1 s.pm_final_top1 s.Fz_drift
end

println("\n# Anomaly inspection: p_3000 final spectrum")
s = first(filter(s -> s.name == "p_3000", all_summaries))
println("  pm_init  = ", round.(s.pm_init; digits = 4))
println("  pm_final = ", round.(s.pm_final; digits = 4))

println("\n# Anomaly inspection: p_10000 initial spectrum")
s = first(filter(s -> s.name == "p_10000", all_summaries))
println("  pm_init  = ", round.(s.pm_init; digits = 4))
println("  pm_final = ", round.(s.pm_final; digits = 4))

println("\n# Anomaly inspection: grid_48cube initial spectrum")
s = first(filter(s -> s.name == "grid_48cube", all_summaries))
println("  pm_init  = ", round.(s.pm_init; digits = 4))
println("  pm_final = ", round.(s.pm_final; digits = 4))

println("\n# Anomaly inspection: dy164_main_500ms (D=17)")
s = first(filter(s -> s.name == "dy164_main_500ms", all_summaries))
println("  pm_init  = ", round.(s.pm_init; digits = 4))
println("  pm_final = ", round.(s.pm_final; digits = 4))
println("\nDone.")
