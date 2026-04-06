# Eu151 Ground State with DDI - Continuation Method
using SpinorBEC

function find_eu151_gs_continuation(;
    nx = 32,
    box = 12.0,
    c1_ratio = -0.01,
    B_field = 2.6e-9,
    c_dd_target = 7647.0,
    c_dd_steps = [0.0, 1000.0, 2000.0, 4000.0, 6000.0, 7647.0],
    gs_steps_per = 3000,
    gs_tol = 1e-8,
)
    println("=== Eu151 Ground State - Continuation Method ===")
    println("Grid: $(nx)³, c1_ratio=$c1_ratio")
    println("c_dd path: $(c_dd_steps)")

    N_atoms = 50000
    c_total = 4689.0

    backend = CPUBackend()
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)

    ω_ref_rad = 2π * 110.0
    p_zeeman = linear_zeeman_p(atom, B_field, ω_ref_rad)
    q_zeeman = 0.0

    println("\nBase parameters:")
    println("  c0=$(round(interactions.c0; digits=1))")
    println("  c1=$(round(interactions.c1; digits=2))")
    println("  Target c_dd=$c_dd_target")

    # Initial ground state with c_dd = 0
    psi_current = nothing
    gs_result = nothing

    for (i, c_dd) in enumerate(c_dd_steps)
        println("\n" * "="^60)
        println("Step $i/$(length(c_dd_steps)): c_dd = $c_dd")
        println("="^60)

        enable_ddi = c_dd > 0

        # Use previous result as initial state if available
        initial_state = (psi_current === nothing) ? :antiferromagnetic : nothing
        psi_init = psi_current

        gs = find_ground_state(;
            grid, atom, interactions,
            zeeman = ZeemanParams(p_zeeman, q_zeeman),
            potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
            dt = enable_ddi ? 0.0005 : 0.001,
            n_steps = gs_steps_per,
            tol = gs_tol,
            initial_state,
            psi_init,
            enable_ddi,
            c_dd = enable_ddi ? c_dd : 0.0,
            backend,
        )

        println("\nResult:")
        println("  E=$(round(gs.energy; sigdigits=6))")
        println("  Converged: $(gs.converged)")

        if !gs.converged
            println("\n⚠️  WARNING: Not converged at c_dd=$c_dd")
            println("   Continuing anyway (continuation method)")
        end

        # Check energy is reasonable (positive for this system)
        if gs.energy < 0
            println("\n⚠️  WARNING: Negative energy E=$(gs.energy)")
            println("   This may indicate ITP instability")
        end

        # Save current state for next step
        psi_current = copy(gs.workspace.state.psi)
        gs_result = gs

        # Print energy decomposition
        ed = energy_decomposition(gs.workspace)
        println("\n  Energy decomposition:")
        println("    Kinetic:  $(round(ed.kinetic; sigdigits=4))")
        println("    Trap:     $(round(ed.trap; sigdigits=4))")
        println("    Density:  $(round(ed.density; sigdigits=4))")
        println("    Spin:     $(round(ed.spin; sigdigits=4))")
        println("    DDI:      $(round(ed.ddi; sigdigits=4))")
        println("    Zeeman:   $(round(ed.zeeman; sigdigits=4))")

        # Check populations
        D = 2F + 1
        dV = cell_volume(grid)
        println("\n  Top populations:")
        pops = []
        for c in 1:D
            m = F - (c - 1)
            p = sum(component_density(gs.workspace.state.psi, 3, c)) * dV
            push!(pops, (m, p))
        end
        sort!(pops, by=x->x[2], rev=true)
        for (m, p) in pops[1:min(5, length(pops))]
            p > 0.001 && println("    m=$m: $(round(p; digits=4))")
        end
    end

    println("\n" * "="^60)
    println("CONTINUATION COMPLETE!")
    println("="^60)
    println("\nFinal state at c_dd=$(c_dd_steps[end]):")
    println("  E=$(round(gs_result.energy; sigdigits=6))")
    println("  Converged: $(gs_result.converged)")

    # Final stability check
    println("\nRunning stability analysis on final state...")
    sim_params = SimParams(; dt=0.0001, n_steps=1, save_every=1)
    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = gs_result.workspace.state.psi,
        enable_ddi = true,
        c_dd = c_dd_target,
        backend,
    )

    stability = analyze_stability(ws; n_steps=1000, sample_every=10)

    println("\nStability:")
    println("  Growth rate: $(round(stability.growth_rate; sigdigits=4)) ω")
    println("  Unstable: $(stability.unstable)")

    if !stability.unstable
        println("\n✓ SUCCESS: DDI-enabled ground state is STABLE!")
    else
        e_fold = 1.0 / stability.growth_rate
        println("\n⚠️  Still unstable: e-fold time = $(round(e_fold; sigdigits=3)) ω⁻¹")
    end

    (gs = gs_result, stability = stability)
end

find_eu151_gs_continuation()
