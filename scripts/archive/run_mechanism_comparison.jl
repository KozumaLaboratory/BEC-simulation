#!/usr/bin/env julia
# X5: 修論 Fig 7 — DDI × stir mechanism comparison.
#
# Runs 4 Eu151 configs sequentially (each ~25 min first time, ~5-10 min cached):
#   - full       : DDI on,  stir on   (= klaus_eu151_spin_excitation)
#   - no_ddi     : DDI off, stir on   (Berry connection isolated)
#   - no_stir    : DDI on,  stir off  (static B̂ at tilt — no Â driver)
#   - baseline   : DDI off, stir off  (free dynamics — should be ≈ trivial)
#
# Usage: julia --project=. scripts/run_mechanism_comparison.jl

using SpinorBEC
using JLD2
using Printf

const RUNS = [
    ("klaus_eu151_mechanism_full",     "Full Klaus Eu151 (DDI+stir)"),
    ("klaus_eu151_mechanism_no_ddi",   "Berry connection isolated (no DDI)"),
    ("klaus_eu151_mechanism_no_stir",  "Static tilted B̂ (no Â)"),
    ("klaus_eu151_mechanism_baseline", "Free dynamics (no DDI, no stir)"),
]

println("="^70)
println("X5 Mechanism comparison: 4 corners")
println("="^70)

for (run_name, descr) in RUNS
    run_dir = "runs/$run_name"
    config_file = "$run_dir/config.yaml"
    isfile(config_file) || (println("Missing: $config_file"); continue)

    println("\n", "▶ ", run_name, " — ", descr)
    println("="^60)

    config = SpinorBEC.load_config(config_file)
    t_start = time()
    result = SpinorBEC.run_config(config; verbose=true)
    t_run = time() - t_start

    dyn = result[:rotating_basis_dynamics]
    pm_init = dyn[:per_m_history][1] / sum(dyn[:per_m_history][1])
    pm_final = dyn[:per_m_history][end] / sum(dyn[:per_m_history][end])
    @printf "  Run time: %.1f s\n" t_run
    @printf "  m=+F: %.4f → %.4f (Δ = %.4f)\n" pm_init[1] pm_final[1] (pm_init[1] - pm_final[1])
    @printf "  ⟨L_z⟩: %.4f → %.4f\n" dyn[:Lz][1] dyn[:Lz][end]
    @printf "  ⟨F_z⟩: %.4f → %.4f\n" dyn[:Fz][1] dyn[:Fz][end]

    # Save result for analyzer
    JLD2.jldsave("$run_dir/result.jld2";
        times=dyn[:times], norms=dyn[:norms], Lz=dyn[:Lz], Fz=dyn[:Fz],
        per_m_history=hcat(dyn[:per_m_history]...),
        psi_snapshots=get(dyn, :psi_snapshots, Vector{Array{ComplexF64,4}}()),
        theta_const=dyn[:theta_const], phi_omega=dyn[:phi_omega],
    )

    # Run thesis figures for this corner
    println("\n  Generating thesis figures...")
    SpinorBEC._unused_for_export = nothing  # keep load active
    # Inline analyzer call (avoid re-loading SpinorBEC for each script)
    fig_dir = "$run_dir/figs"
    mkpath(fig_dir)
    pop = SpinorBEC.population_dynamics(dyn)
    JLD2.jldsave("$fig_dir/fig2_population.jld2";
        times=pop.times, N_m=pop.N_m, F=pop.F)
    edh = SpinorBEC.edh_conservation(dyn)
    JLD2.jldsave("$fig_dir/fig5_edh.jld2";
        times=edh.times, Fz=edh.Fz, Lz=edh.Lz, Jz=edh.Jz, Jz_drift=edh.Jz_drift)
    berry = SpinorBEC.berry_connection_trajectory(dyn; gauge_fix=false)
    JLD2.jldsave("$fig_dir/fig6_berry.jld2";
        times=berry.times, a_x=berry.a_x, a_y=berry.a_y, a_z=berry.a_z, a_mag=berry.a_mag)
    if !isempty(get(dyn, :psi_snapshots, []))
        n_snaps = length(dyn[:psi_snapshots])
        frame_idxs = Int.(round.(range(1, n_snaps, length=min(5, n_snaps))))
        tex = SpinorBEC.spin_texture_xy(dyn; frame_idxs=frame_idxs)
        JLD2.jldsave("$fig_dir/fig3_spin_texture.jld2";
            frame_times=tex.frame_times, frame_idxs=tex.frame_idxs,
            Fx=tex.Fx, Fy=tex.Fy, Fz=tex.Fz, F=tex.F)
        vortex = SpinorBEC.detect_per_m_vortices(dyn; frame_idx=n_snaps,
            density_threshold=0.2)
        JLD2.jldsave("$fig_dir/fig4_per_m_vortex.jld2";
            column_density=vortex.column_density,
            cores_per_m=[vortex.cores[m_idx] for m_idx in 1:size(vortex.column_density, 3)],
            F=(size(vortex.column_density, 3) - 1) ÷ 2)
    end
    @printf "  ✅ %s figures saved to %s\n" run_name fig_dir
end

println("\n", "="^70)
println("All 4 mechanism corners complete. Compare m=+F drop:")
for (run_name, _) in RUNS
    f = "runs/$run_name/figs/fig2_population.jld2"
    if isfile(f)
        d = JLD2.load(f)
        N_m = d["N_m"]
        Δ = N_m[1, 1] - N_m[1, end]
        @printf "  %-40s ΔN_+F = %.4f\n" run_name Δ
    end
end
println("="^70)
println("Decisive evidence: which corner shows largest spin transfer?")
