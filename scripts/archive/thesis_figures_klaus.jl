#!/usr/bin/env julia
# 修論 figure 生成 — Klaus magnetostir run の output から Fig 2-7 を抽出。
#
# 使い方:
#   julia --project=. scripts/thesis_figures_klaus.jl runs/klaus_option_gamma_full
#   julia --project=. scripts/thesis_figures_klaus.jl runs/klaus_eu151_spin_excitation
#
# 入力: <run_dir>/result.jld2 (pipeline_runner が保存)
# 出力: <run_dir>/figs/ 以下の JLD2 + JSON ファイル群
#   - fig2_population.jld2     N_m(t) for plotting
#   - fig3_spin_texture.jld2   ⟨F_α⟩(x,y) at selected times
#   - fig4_per_m_vortex.jld2   |ψ_m(x,y)|² + detected core positions
#   - fig5_edh.jld2             ⟨F_z⟩(t) + ⟨L_z⟩(t) conservation
#   - fig6_berry.jld2           Â(t) analytical from waveforms
#   - figs.json                 metadata + summary stats

using SpinorBEC
using JLD2
using Printf
using Dates
import JSON

# --- Args ---
length(ARGS) >= 1 || error("Usage: julia thesis_figures_klaus.jl <run_dir>")
run_dir = ARGS[1]
result_file = joinpath(run_dir, "result.jld2")
isfile(result_file) || error("result.jld2 not found in $run_dir — run the pipeline first")
fig_dir = joinpath(run_dir, "figs")
mkpath(fig_dir)

println("="^70)
println("修論 figure generation: $run_dir")
println("="^70)

# --- Load ---
result = JLD2.load(result_file)
times = result["times"]::Vector{Float64}
per_m_history_mat = result["per_m_history"]
# `per_m_history` is saved as a Matrix (cols=time, rows=m). Convert to Vector{Vector}.
per_m_history = [collect(per_m_history_mat[:, i]) for i in 1:size(per_m_history_mat, 2)]
Lz_arr = result["Lz"]::Vector{Float64}
Fz_arr = result["Fz"]::Vector{Float64}
psi_snaps = haskey(result, "psi_snapshots") ? result["psi_snapshots"] : Vector{Array{ComplexF64, 4}}()
θ_const = result["theta_const"]::Float64
φ_omega = result["phi_omega"]::Float64

dyn = Dict{Symbol, Any}(
    :times => times,
    :Lz => Lz_arr, :Fz => Fz_arr,
    :Fx => zeros(length(times)), :Fy => zeros(length(times)),
    :norms => ones(length(times)),
    :per_m_history => per_m_history,
    :psi_snapshots => psi_snaps,
    :theta_const => θ_const,
    :phi_omega => φ_omega,
)

@printf "Frames: %d, ψ̃ snapshots: %d, F = %d\n" length(times) length(psi_snaps) (length(per_m_history[1]) - 1) ÷ 2
@printf "B̂(t): θ_const = %.3f rad (%.1f°), φ_omega = %.3f (= %.1f Hz at ω_ref=2π·50)\n" θ_const (θ_const*180/π) φ_omega (φ_omega*50/(2π))

# --- Fig 2: Population dynamics ---
println("\n--- Fig 2: Population dynamics ---")
pop = SpinorBEC.population_dynamics(dyn)
JLD2.jldsave(joinpath(fig_dir, "fig2_population.jld2");
    times=pop.times, N_m=pop.N_m, F=pop.F)
@printf "N_+F: %.4f → %.4f (Δ = %.4f)\n" pop.N_m[1, 1] pop.N_m[1, end] (pop.N_m[1, 1] - pop.N_m[1, end])
@printf "Saved fig2_population.jld2\n"

# --- Fig 5: EdH conservation ---
println("\n--- Fig 5: EdH (F_z + L_z conservation) ---")
edh = SpinorBEC.edh_conservation(dyn)
JLD2.jldsave(joinpath(fig_dir, "fig5_edh.jld2");
    times=edh.times, Fz=edh.Fz, Lz=edh.Lz, Jz=edh.Jz, Jz_drift=edh.Jz_drift)
@printf "⟨F_z⟩: %.3f → %.3f, ⟨L_z⟩: %.3f → %.3f\n" edh.Fz[1] edh.Fz[end] edh.Lz[1] edh.Lz[end]
@printf "J_z conservation max relative drift: %.2e\n" edh.conservation_max_rel
@printf "Saved fig5_edh.jld2\n"

# --- Fig 6: Berry connection trajectory ---
println("\n--- Fig 6: Berry connection Â(t) ---")
berry = SpinorBEC.berry_connection_trajectory(dyn; gauge_fix=false)
JLD2.jldsave(joinpath(fig_dir, "fig6_berry.jld2");
    times=berry.times, a_x=berry.a_x, a_y=berry.a_y, a_z=berry.a_z, a_mag=berry.a_mag)
@printf "|Â/ℏ|: const = %.3f (rotation rate)\n" berry.a_mag[1]
@printf "Components: (a_x, a_y, a_z) = (%.3f, %.3f, %.3f)\n" berry.a_x[1] berry.a_y[1] berry.a_z[1]
@printf "Saved fig6_berry.jld2\n"

# Snapshots required for Fig 3 + Fig 4
if !isempty(psi_snaps)
    # --- Fig 3: Spin texture at 5 evenly spaced frames ---
    println("\n--- Fig 3: Spin texture ⟨F⟩(x, y) ---")
    n = length(psi_snaps)
    frame_idxs = Int.(round.(range(1, n, length=min(5, n))))
    tex = SpinorBEC.spin_texture_xy(dyn; frame_idxs=frame_idxs)
    JLD2.jldsave(joinpath(fig_dir, "fig3_spin_texture.jld2");
        frame_times=tex.frame_times, frame_idxs=tex.frame_idxs,
        Fx=tex.Fx, Fy=tex.Fy, Fz=tex.Fz, F=tex.F)
    @printf "Frames at t = %s\n" string(round.(tex.frame_times; digits=2))
    @printf "Saved fig3_spin_texture.jld2\n"

    # --- Fig 4: Per-m column density + vortex cores at final frame ---
    println("\n--- Fig 4: Per-m vortex pattern (FINAL frame) ---")
    cd_final = SpinorBEC.per_m_column_density(dyn; frame_idx=length(psi_snaps))
    Nx, Ny, D = size(cd_final)
    F_val = (D - 1) ÷ 2
    println("Per-m population at final frame:")
    for m_idx in 1:D
        m = F_val - (m_idx - 1)
        pop_m = sum(@view cd_final[:, :, m_idx])
        if pop_m > 1e-4
            @printf "  m=%+d: %.4f\n" m pop_m
        end
    end
    vortex = SpinorBEC.detect_per_m_vortices(dyn; frame_idx=length(psi_snaps),
        density_threshold=0.2)
    @printf "Vortex cores per m component:\n"
    for m_idx in 1:D
        m = F_val - (m_idx - 1)
        n_cores = length(vortex.cores[m_idx])
        if n_cores > 0
            @printf "  m=%+d: %d core(s) at %s\n" m n_cores string(vortex.cores[m_idx])
        end
    end
    JLD2.jldsave(joinpath(fig_dir, "fig4_per_m_vortex.jld2");
        column_density=vortex.column_density,
        cores_per_m=[vortex.cores[m_idx] for m_idx in 1:D],
        F=F_val)
    @printf "Saved fig4_per_m_vortex.jld2\n"
else
    println("\n⚠️  No ψ̃ snapshots in result — skip Fig 3 + Fig 4.")
    println("    Re-run with `save_psi_snapshots: true` (default for new pipeline).")
end

# --- Metadata summary ---
metadata = Dict(
    "run_dir" => run_dir,
    "n_frames" => length(times),
    "n_psi_snapshots" => length(psi_snaps),
    "F" => (length(per_m_history[1]) - 1) ÷ 2,
    "theta_const" => θ_const,
    "phi_omega" => φ_omega,
    "duration" => times[end] - times[1],
    "N_plus_F_initial" => per_m_history[1][1] / sum(per_m_history[1]),
    "N_plus_F_final" => per_m_history[end][1] / sum(per_m_history[end]),
    "Fz_initial" => Fz_arr[1],
    "Fz_final" => Fz_arr[end],
    "Lz_initial" => Lz_arr[1],
    "Lz_final" => Lz_arr[end],
    "Jz_drift_max_rel" => edh.conservation_max_rel,
    "berry_a_mag" => berry.a_mag[1],
    "timestamp" => string(now()),
)
open(joinpath(fig_dir, "figs.json"), "w") do io
    JSON.print(io, metadata, 2)
end
println("\n--- Summary ---")
println(metadata)
println("\n✅ All thesis figures generated to $fig_dir")
