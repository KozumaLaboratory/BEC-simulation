# Eu151 Ground State WITH DDI enabled
using SpinorBEC

function find_eu151_gs_with_ddi(;
    nx = 32,
    box = 12.0,
    c1_ratio = -0.01,
    B_field = 2.6e-9,
    gs_steps = 10000,
    gs_tol = 1e-8,
)
    println("=== Eu151 Ground State (DDI ENABLED) ===")
    println("Grid: $(nx)³, c1_ratio=$c1_ratio")

    N_atoms = 50000
    c_total = 4689.0
    c_dd = 7647.0

    backend = CPUBackend()
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)

    ω_ref_rad = 2π * 110.0
    p_zeeman = linear_zeeman_p(atom, B_field, ω_ref_rad)
    q_zeeman = 0.0

    println("\nParameters:")
    println("  c0=$(round(interactions.c0; digits=1))")
    println("  c1=$(round(interactions.c1; digits=2))")
    println("  c_dd=$c_dd")
    println("  c_dd/c0=$(round(c_dd/interactions.c0; digits=2))")

    println("\nFinding ground state WITH DDI...")
    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.0005,  # Smaller dt for stability
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :antiferromagnetic,
        enable_ddi = true,  # DDI ON!
        c_dd,
        backend,
    )

    println("\n=== RESULT ===")
    println("E=$(round(gs.energy; sigdigits=6))")
    println("Converged: $(gs.converged)")

    ed = energy_decomposition(gs.workspace)
    println("\nEnergy decomposition:")
    println("  Kinetic:  $(round(ed.kinetic; sigdigits=4))")
    println("  Trap:     $(round(ed.trap; sigdigits=4))")
    println("  Density:  $(round(ed.density; sigdigits=4))")
    println("  Spin:     $(round(ed.spin; sigdigits=4))")
    println("  DDI:      $(round(ed.ddi; sigdigits=4))")
    println("  Zeeman:   $(round(ed.zeeman; sigdigits=4))")

    # Check populations
    D = 2F + 1
    dV = cell_volume(grid)
    psi = gs.workspace.state.psi

    println("\nPopulations:")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi, 3, c)) * dV
        if p > 0.01
            println("  m=$m: $(round(p; digits=4))")
        end
    end

    gs
end

find_eu151_gs_with_ddi()
