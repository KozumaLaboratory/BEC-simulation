# Eu151 Ground State via p-continuation
#
# Full c_dd from the start. At large p, ferromagnetic m=+F is the ground state
# even with DDI. Sweep p downward to discover spin textures / quantum phases.

using SpinorBEC
using JLD2
using Printf

function find_eu151_gs_p_continuation(;
    nx = 32,
    box = 24.0,
    c1_ratio = 1 / 36,
    B_field = 2.6e-9,
    c_dd = 7647.0,
    c_total = 4689.0,
    p_values = [exp10.(range(5, -1; length=100)); 0.0],
    q_zeeman = 0.0,
    dt = 0.00005,
    gs_steps_first = 5000,
    gs_steps = 1000,
    gs_tol = 1e-8,
    save_dir = "output/eu151_p_continuation",
    backend::AbstractBackend = CPUBackend(),
)
    println("=" ^ 70)
    println("  Eu151 Ground State — p-continuation")
    println("=" ^ 70)
    println()

    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    base_ip = interaction_params_from_constraint(; c_total, c1_ratio, F)
    eps_dd = c_dd / (3.0 * base_ip.c0)
    c_lhy_scalar = 2.5 * sqrt(base_ip.c0)
    c_lhy = compute_c_lhy_with_ddi(c_lhy_scalar, eps_dd)
    interactions = InteractionParams(base_ip.c0, base_ip.c1, c_lhy, base_ip.c_extra)
    trap = HarmonicTrap((1.0, 1.0, 130.0 / 110.0))

    omega_ref = 2pi * 110.0
    p_physical = linear_zeeman_p(atom, B_field, omega_ref)

    println("Parameters:")
    println("  Grid:       $(nx)^3, box=$box, dx=$(round(box/nx; digits=2))")
    println("  c0 =        $(round(interactions.c0; digits=1))")
    println("  c1 =        $(round(interactions.c1; digits=3))")
    println("  c_dd =      $c_dd  (ε_dd=$(round(eps_dd; digits=3)))")
    println("  c_lhy =     $(round(c_lhy; digits=1))")
    println("  dt =        $dt")
    println("  p(phys) =   $(round(p_physical; sigdigits=3))  (B=$(B_field*1e9) nT)")
    println("  Sweep:      p = $(round.(p_values; digits=1))")
    println()

    mkpath(save_dir)

    sm = spin_matrices(F)
    results = NamedTuple[]
    psi_current = nothing

    for (i, p) in enumerate(p_values)
        zeeman = ZeemanParams(p, q_zeeman)

        gs = find_ground_state(;
            grid, atom, interactions, zeeman,
            potential = trap,
            dt,
            n_steps = i == 1 ? gs_steps_first : gs_steps,
            tol = gs_tol,
            initial_state = psi_current === nothing ? :ferromagnetic : nothing,
            psi_init = psi_current,
            enable_ddi = true,
            c_dd,
            backend,
        )

        psi_host = SpinorBEC._to_host(gs.workspace.state.psi)
        phase_info = classify_phase_detailed(psi_host, F, grid, sm)

        @printf("  p=%6.1f → E=%.6g  conv=%-5s  phase=%-15s  spin_ord=%.3f\n",
                p, gs.energy, gs.converged, phase_info.phase, phase_info.spin_order)

        push!(results, (
            param = p,
            energy = gs.energy,
            converged = gs.converged,
            phase = phase_info.phase,
            phase_info = phase_info,
            psi = copy(psi_host),
        ))

        psi_current = copy(gs.workspace.state.psi)
    end

    println("\n" * "=" ^ 70)
    println("  Summary")
    println("=" ^ 70)
    println()
    @printf("  %-8s  %-12s  %-8s  %-20s  %-10s\n",
            "p", "Energy", "Conv?", "Phase", "Spin ord")
    println("  " * "-" ^ 66)
    for r in results
        @printf("  %-8.3g  %-12.6g  %-8s  %-20s  %.4f\n",
                r.param, r.energy, r.converged, r.phase, r.phase_info.spin_order)
    end

    for (i, r) in enumerate(results)
        JLD2.jldsave(
            joinpath(save_dir, "step_$(lpad(i, 3, '0'))_p$(round(r.param; sigdigits=3)).jld2");
            psi = r.psi,
            p = r.param,
            energy = r.energy,
            converged = r.converged,
            phase = string(r.phase),
        )
    end
    println("\n  Results saved to $save_dir/")

    results
end

if abspath(PROGRAM_FILE) == @__FILE__
    find_eu151_gs_p_continuation()
end
