# Eu151: search for FL vortex phase by sweeping c1_ratio
#
# At each c1_ratio:
#   1. Compute uniform polarized state (Mz=-6) → E_uniform
#   2. Compute FL vortex state (Mz=0)         → E_FL
#   3. Compare: ΔE = E_FL - E_uniform
#
# When ΔE < 0, FL is the ground state.
#
# Constraint: c₀ + 36 c₁ = c_total = 4689 (Eu151)
# c₁ < 0 → c₀ > 4689, ε_dd = c_dd/(3c₀) decreases (DDI relatively weaker)
# c₁ > 0 → c₀ < 4689, ε_dd increases (DDI relatively stronger but ε_dd>1 unstable)

using SpinorBEC, JLD2, Printf
import CUDA

function run_phase_search(;
    nx::Int = 64,
    box::Float64 = 12.0,
    c_total::Float64 = 4689.0,
    c_dd::Float64 = 7647.0,
    c1_ratios::Vector{Float64} = collect(range(-0.02, 0.0; length=11)),
    dt::Float64 = 0.0001,
    n_steps::Int = 5000,
    tol::Float64 = 1e-7,
    save_dir::String = "output/eu151_c1_phase_search",
    backend = CUDABackend(),
)
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F
    sys = SpinSystem(F)
    trap = HarmonicTrap((1.0, 1.0, 130.0/110.0))
    mkpath(save_dir)

    println("Threads: ", Threads.nthreads())
    println("c1_ratio sweep: ", round.(c1_ratios; digits=4))
    println()

    results = NamedTuple[]

    for (i, r) in enumerate(c1_ratios)
        base_ip = interaction_params_from_constraint(; c_total, c1_ratio=r, F)
        eps_dd = c_dd / (3.0 * base_ip.c0)
        c_lhy_scalar = 1135.0 * (base_ip.c0 / 4689.0)
        c_lhy = if 0.0 <= eps_dd < 1.0
            c_lhy_scalar * lima_pelster_Q5(eps_dd)
        else
            c_lhy_scalar  # Q5 extension handles >1 internally now
        end
        interactions = InteractionParams(base_ip.c0, base_ip.c1, c_lhy, base_ip.c_extra)

        @printf("=== c1_ratio = %+.4f (step %d/%d) ===\n", r, i, length(c1_ratios))
        @printf("  c0=%.1f c1=%.3f  ε_dd=%.3f  c_lhy=%.1f\n",
                base_ip.c0, base_ip.c1, eps_dd, c_lhy)

        # --- Uniform Mz=-6 state ---
        gs_u = find_ground_state(;
            grid, atom, interactions,
            zeeman = ZeemanParams(0.0, 0.0),
            potential = trap,
            dt, n_steps, tol,
            initial_state = :ferromagnetic_min,
            target_magnetization = -6.0,
            enable_ddi = true,
            c_dd,
            backend,
        )
        psi_u = SpinorBEC._to_host(gs_u.workspace.state.psi)
        E_uniform = gs_u.energy
        @printf("  Uniform Mz=-6: E = %.4f  (dE=%.3g)\n", E_uniform, gs_u.dE)

        # --- FL vortex Mz=0 state ---
        gs_fl = find_ground_state(;
            grid, atom, interactions,
            zeeman = ZeemanParams(0.0, 0.0),
            potential = trap,
            dt, n_steps, tol,
            initial_state = :fl_vortex,
            enable_ddi = true,
            c_dd,
            backend,
        )
        psi_fl = SpinorBEC._to_host(gs_fl.workspace.state.psi)
        E_FL = gs_fl.energy
        mz_fl = magnetization(psi_fl, grid, sys)
        @printf("  FL vortex   : E = %.4f  (dE=%.3g  Mz=%+.3f)\n", E_FL, gs_fl.dE, mz_fl)

        delta_E = E_FL - E_uniform
        winner = delta_E < 0 ? "FL" : "Uniform"
        @printf("  ΔE = E_FL - E_uniform = %+.4f  → %s wins\n\n", delta_E, winner)

        push!(results, (
            c1_ratio = r,
            c0 = base_ip.c0,
            c1 = base_ip.c1,
            eps_dd = eps_dd,
            c_lhy = c_lhy,
            E_uniform = E_uniform,
            E_FL = E_FL,
            delta_E = delta_E,
            mz_fl = mz_fl,
        ))

        JLD2.jldsave(
            joinpath(save_dir, "step_$(lpad(i,3,'0'))_r$(round(r; digits=4)).jld2");
            psi_uniform=psi_u, psi_fl=psi_fl,
            E_uniform=E_uniform, E_FL=E_FL,
            c1_ratio=r, c0=base_ip.c0, c1=base_ip.c1, c_lhy=c_lhy, eps_dd=eps_dd,
        )
    end

    println("\n=== Phase search summary ===")
    @printf("  %-9s  %-7s  %-7s  %-7s  %-12s  %-12s  %-10s  %s\n",
            "c1_ratio", "c0", "c1", "ε_dd", "E_uniform", "E_FL", "ΔE", "winner")
    println("  " * "-" ^ 90)
    for r in results
        winner = r.delta_E < 0 ? "FL" : "Uniform"
        @printf("  %+9.4f  %7.1f  %+7.2f  %.3f  %12.4f  %12.4f  %+10.4f  %s\n",
                r.c1_ratio, r.c0, r.c1, r.eps_dd,
                r.E_uniform, r.E_FL, r.delta_E, winner)
    end
    results
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_phase_search()
end
