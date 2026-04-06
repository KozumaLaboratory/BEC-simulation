# Eu151 Ground State via p-continuation (Zeeman field sweep)
#
# Strategy: start at large linear Zeeman p where the system is polarized
# (m=-F dominant, DDI acts on a near-scalar condensate → ITP stable),
# then gradually reduce p toward the physical value.
# Each step uses the previous converged state as initial condition.
#
# This avoids the ITP+DDI divergence that occurs when starting from
# a non-polarized initial state with full DDI.

using SpinorBEC
using JLD2
using Printf

function find_eu151_gs_p_continuation(;
    nx = 32,
    box = 12.0,
    c1_ratio = 1 / 36,
    B_field = 2.6e-9,
    c_dd = 7647.0,
    c_total = 4689.0,
    p_values = [100.0, 50.0, 20.0, 10.0, 5.0, 2.0, 1.0, 0.5, 0.2, 0.1, 0.0],
    q_zeeman = 0.0,
    p_threshold = 5.0,
    gs_steps = 3000,
    gs_tol = 1e-8,
    save_dir = "output/eu151_p_continuation",
)
    println("=" ^ 70)
    println("  Eu151 Ground State — p-continuation (Zeeman sweep)")
    println("=" ^ 70)
    println()

    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)
    trap = HarmonicTrap((1.0, 1.0, 130.0 / 110.0))

    omega_ref = 2pi * 110.0
    p_physical = linear_zeeman_p(atom, B_field, omega_ref)

    println("Parameters:")
    println("  Grid:     $(nx)^3, box=$box")
    println("  c0 =      $(round(interactions.c0; digits=1))")
    println("  c1 =      $(round(interactions.c1; digits=3))")
    println("  c_dd =    $c_dd")
    println("  p(phys) = $(round(p_physical; sigdigits=3))  (B=$(B_field*1e9) nT)")
    println("  Sweep:    p = $(p_values)")
    println()

    mkpath(save_dir)

    results = scan_continuation(;
        param_values = Float64.(p_values),
        make_params = p -> (
            zeeman = ZeemanParams(p, q_zeeman),
            dt = p > p_threshold ? 0.001 : 0.0005,
        ),
        grid,
        atom,
        interactions,
        potential = trap,
        initial_state = :polar,
        enable_ddi = true,
        c_dd,
        n_steps_continuation = gs_steps,
        n_steps_fresh = gs_steps * 2,
        energy_jump_threshold = 0.1,
        tol = gs_tol,
    )

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
