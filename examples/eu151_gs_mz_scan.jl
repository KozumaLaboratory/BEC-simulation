# Eu151 Ground State: Mz-constrained scan
#
# ITP doesn't conserve magnetization, so unconstrained ITP at low p falls
# into the global minimum (typically Mz=0 polar). The experiment, however,
# fixes Mz at preparation time, and the observed phase is the lowest-energy
# state at THAT magnetization.
#
# This script scans Mz from -F to 0 with target_magnetization constraint,
# revealing the true Mz-resolved phase diagram (analogous to Kawaguchi-Ueda
# Fig. 3 in the DDI-dominated regime for Eu151).

using SpinorBEC
using JLD2
using Printf

function find_eu151_gs_mz_scan(;
    nx = 32,
    box = 24.0,
    c1_ratio = 0.0,
    c_dd = 7647.0,
    c_total = 4689.0,
    c_lhy_override = 1135.0,
    mz_values = collect(range(-6.0, 0.0; length=13)),
    p_zeeman = 0.0,
    q_zeeman = 0.0,
    dt = 0.00005,
    gs_steps = 5000,
    gs_tol = 1e-6,
    save_dir = "output/eu151_mz_scan",
    backend::AbstractBackend = CPUBackend(),
    T_over_Tc::Float64 = 0.1,
    noise_seed::Int = 42,
)
    println("=" ^ 70)
    println("  Eu151 Ground State — Mz-constrained scan")
    println("=" ^ 70)
    println()

    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    base_ip = interaction_params_from_constraint(; c_total, c1_ratio, F)
    eps_dd = c_dd / (3.0 * base_ip.c0)
    c_lhy = c_lhy_override
    interactions = InteractionParams(base_ip.c0, base_ip.c1, c_lhy, base_ip.c_extra)
    trap = HarmonicTrap((1.0, 1.0, 130.0 / 110.0))

    println("Parameters:")
    println("  Grid:       $(nx)^3, box=$box, dx=$(round(box/nx; digits=2))")
    println("  c0 =        $(round(interactions.c0; digits=1))")
    println("  c1 =        $(round(interactions.c1; digits=3))")
    println("  c_dd =      $c_dd  (ε_dd=$(round(eps_dd; digits=3)))")
    println("  c_lhy =     $(round(c_lhy; digits=1))")
    println("  p, q =      $p_zeeman, $q_zeeman")
    println("  dt =        $dt")
    println("  Mz scan:    $(round.(mz_values; digits=2))")
    println("  noise:      T/T_c=$T_over_Tc " *
            "(η=$(round(thermal_noise_amplitude(T_over_Tc)*100; digits=2))%)")
    println()

    mkpath(save_dir)

    sm = spin_matrices(F)
    sys = SpinSystem(F)
    results = NamedTuple[]
    psi_current = nothing

    for (i, mz) in enumerate(mz_values)
        psi_seed = if psi_current === nothing
            init_state = mz < -F + 0.5 ? :ferromagnetic_min :
                         mz > F - 0.5 ? :ferromagnetic :
                         :polar
            ψ = init_psi(grid, sys; state=init_state)
            T_over_Tc > 0 && add_thermal_noise!(ψ, F; T_over_Tc, seed=noise_seed)
            ψ
        else
            copy(psi_current)
        end

        gs = find_ground_state(;
            grid, atom, interactions,
            zeeman = ZeemanParams(p_zeeman, q_zeeman),
            potential = trap,
            dt,
            n_steps = gs_steps,
            tol = gs_tol,
            psi_init = psi_seed,
            target_magnetization = mz,
            enable_ddi = true,
            c_dd,
            backend,
        )

        psi_host = SpinorBEC._to_host(gs.workspace.state.psi)
        phase_info = classify_phase_detailed(psi_host, F, grid, sm)
        actual_mz = magnetization(psi_host, grid, sys)

        @printf("  Mz=%+5.2f → E=%-12.6g  conv=%-5s  phase=%-15s  spin_ord=%.3f  (Mz_actual=%+.3f)\n",
                mz, gs.energy, gs.converged, phase_info.phase,
                phase_info.spin_order, actual_mz)

        push!(results, (
            param = mz,
            energy = gs.energy,
            converged = gs.converged,
            phase = phase_info.phase,
            phase_info = phase_info,
            actual_mz = actual_mz,
            psi = copy(psi_host),
        ))

        JLD2.jldsave(
            joinpath(save_dir, "step_$(lpad(i, 3, '0'))_mz$(round(mz; digits=2)).jld2");
            psi = psi_host,
            mz_target = mz,
            mz_actual = actual_mz,
            energy = gs.energy,
            converged = gs.converged,
            phase = string(phase_info.phase),
            spin_order = phase_info.spin_order,
        )

        psi_current = copy(gs.workspace.state.psi)
    end

    println("\n" * "=" ^ 70)
    println("  Summary (Mz-resolved phase diagram)")
    println("=" ^ 70)
    println()
    @printf("  %-8s  %-12s  %-8s  %-20s  %-10s\n",
            "Mz/N", "Energy", "Conv?", "Phase", "Spin ord")
    println("  " * "-" ^ 66)
    for r in results
        @printf("  %-+8.2f  %-12.6g  %-8s  %-20s  %.4f\n",
                r.param, r.energy, r.converged, r.phase, r.phase_info.spin_order)
    end

    for (i, r) in enumerate(results)
        JLD2.jldsave(
            joinpath(save_dir, "step_$(lpad(i, 3, '0'))_mz$(round(r.param; digits=2)).jld2");
            psi = r.psi,
            mz_target = r.param,
            mz_actual = r.actual_mz,
            energy = r.energy,
            converged = r.converged,
            phase = string(r.phase),
        )
    end
    println("\n  Results saved to $save_dir/")

    results
end

if abspath(PROGRAM_FILE) == @__FILE__
    find_eu151_gs_mz_scan()
end
