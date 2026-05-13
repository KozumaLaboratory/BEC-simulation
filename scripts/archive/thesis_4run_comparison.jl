#!/usr/bin/env julia
# 修論 mechanism map (Fig 1, 2, 3, 4): overlay of 4 corners.
#
# Inputs: <run_dir>/figs/fig{2,5,6}_*.jld2 from each of the 4 runs.
# Output: <out_dir>/comparison_*.jld2 with overlays.
#
# Usage:
#   julia --project=. scripts/thesis_4run_comparison.jl \
#       runs/klaus_eu151_spin_excitation \
#       runs/klaus_eu151_weak_field \
#       runs/klaus_option_gamma_full \
#       runs/klaus_dy164_weak_field \
#       runs/_thesis_comparison

using JLD2
using Printf

length(ARGS) == 5 || error("Usage: <A> <B> <C> <D> <out_dir>  (4 run_dirs + output dir)")
run_dirs = ARGS[1:4]
out_dir = ARGS[5]
mkpath(out_dir)

labels = ["A: Eu adiabatic", "B: Eu weak field", "C: Dy adiabatic", "D: Dy weak field"]

println("="^70)
println("4-run comparison: mechanism map")
println("="^70)

# Per-run summary metrics (for Fig 1 mechanism table)
summary_table = Vector{Dict{String,Any}}()

# Time series overlays (Fig 2: Lz, Fig 3: Fz, Fig 4: m=+F)
all_times = Vector{Vector{Float64}}()
all_Lz = Vector{Vector{Float64}}()
all_Fz = Vector{Vector{Float64}}()
all_NplusF = Vector{Vector{Float64}}()

for (i, run_dir) in enumerate(run_dirs)
    fig5 = joinpath(run_dir, "figs", "fig5_edh.jld2")
    fig2 = joinpath(run_dir, "figs", "fig2_population.jld2")
    metafile = joinpath(run_dir, "figs", "figs.json")

    if !isfile(fig5) || !isfile(fig2)
        @warn "Skip $(labels[i]): missing fig5 or fig2 in $run_dir"
        push!(all_times, Float64[]); push!(all_Lz, Float64[])
        push!(all_Fz, Float64[]); push!(all_NplusF, Float64[])
        push!(summary_table, Dict("label" => labels[i], "missing" => true))
        continue
    end

    f5 = JLD2.load(fig5)
    f2 = JLD2.load(fig2)

    times = f5["times"]::Vector{Float64}
    Lz = f5["Lz"]::Vector{Float64}
    Fz = f5["Fz"]::Vector{Float64}
    N_m = f2["N_m"]
    N_plus_F = N_m[1, :]

    push!(all_times, times); push!(all_Lz, Lz)
    push!(all_Fz, Fz); push!(all_NplusF, collect(N_plus_F))

    s = Dict{String,Any}(
        "label" => labels[i],
        "Lz_swing" => maximum(Lz) - minimum(Lz),
        "Lz_max" => maximum(abs, Lz),
        "Fz_drop" => Fz[1] - Fz[end],
        "NplusF_drop" => N_plus_F[1] - N_plus_F[end],
        "duration" => times[end] - times[1],
        "n_frames" => length(times),
    )
    push!(summary_table, s)

    @printf "%-20s  Lz_swing=%6.3f  Fz_drop=%8.6f  m=+F drop=%8.6f\n" labels[i] s["Lz_swing"] s["Fz_drop"] s["NplusF_drop"]
end

# Save 4-overlay JLD2 — each row aligned by index, plotter overlays them
out_file = joinpath(out_dir, "mechanism_overlay.jld2")
JLD2.jldsave(out_file;
    labels = labels,
    times = all_times,
    Lz = all_Lz,
    Fz = all_Fz,
    NplusF = all_NplusF,
)
@printf "\nSaved overlay → %s\n" out_file

# Mechanism map summary table
import JSON
open(joinpath(out_dir, "mechanism_table.json"), "w") do io
    JSON.print(io, summary_table, 2)
end
@printf "Saved table  → %s\n" joinpath(out_dir, "mechanism_table.json")

# 2×2 mechanism map (text rendering — for thesis caption / inline LaTeX)
println()
println("Mechanism map (Lz_swing / Fz_drop / m=+F drop):")
println("─"^70)
@printf "%-15s  %-25s  %-25s\n" "" "Eu (ε_dd=0.54)" "Dy (ε_dd=1.42)"
println("─"^70)
adia_eu = summary_table[1]; weak_eu = summary_table[2]
adia_dy = summary_table[3]; weak_dy = length(summary_table) >= 4 ? summary_table[4] : Dict("missing" => true)

if !get(adia_eu, "missing", false) && !get(adia_dy, "missing", false)
    @printf "%-15s  Lz=%.3f Fz=%.4f mF=%.4f  Lz=%.3f Fz=%.4f mF=%.4f\n" "adiabatic" adia_eu["Lz_swing"] adia_eu["Fz_drop"] adia_eu["NplusF_drop"] adia_dy["Lz_swing"] adia_dy["Fz_drop"] adia_dy["NplusF_drop"]
end
if !get(weak_eu, "missing", false)
    if !get(weak_dy, "missing", false)
        @printf "%-15s  Lz=%.3f Fz=%.4f mF=%.4f  Lz=%.3f Fz=%.4f mF=%.4f\n" "non-adiabatic" weak_eu["Lz_swing"] weak_eu["Fz_drop"] weak_eu["NplusF_drop"] weak_dy["Lz_swing"] weak_dy["Fz_drop"] weak_dy["NplusF_drop"]
    else
        @printf "%-15s  Lz=%.3f Fz=%.4f mF=%.4f  (D not yet run)\n" "non-adiabatic" weak_eu["Lz_swing"] weak_eu["Fz_drop"] weak_eu["NplusF_drop"]
    end
end
println("─"^70)
println()
println("✅ mechanism comparison saved.")
