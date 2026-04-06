# Eu151 Ground State Stability Analysis
using SpinorBEC

function analyze_eu151_stability(;
    nx = 32,
    box = 12.0,
    c1_ratio = -0.01,
    B_field = 2.6e-9,
    gs_steps = 5000,
    gs_tol = 1e-8,
    stability_steps = 1000,
)
    println("=== Eu151 Stability Analysis ===")
    println("Grid: $(nx)³, c1_ratio=$c1_ratio")

    # Physical parameters
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

    println("\nFinding ground state...")
    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.001,
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :antiferromagnetic,
        enable_ddi = false,  # DDI-free for ITP
        backend,
    )

    println("  E=$(round(gs.energy; sigdigits=6)), converged=$(gs.converged)")

    # Create workspace WITH DDI for stability analysis
    sim_params = SimParams(; dt=0.0001, n_steps=1, save_every=1)
    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = gs.workspace.state.psi,
        enable_ddi = true,  # DDI ON for stability
        c_dd,
        backend,
    )

    println("\nRunning stability analysis (DDI enabled)...")
    println("  Perturb-and-evolve for $stability_steps steps...")

    stability = analyze_stability(ws; n_steps=stability_steps, sample_every=10)

    println("\n=== RESULTS ===")
    println("Growth rate: $(round(stability.growth_rate; sigdigits=4)) ω")
    println("Unstable: $(stability.unstable)")
    println("Peak k: $(round(stability.k_peak; sigdigits=3))")

    if stability.unstable
        e_fold_time = 1.0 / stability.growth_rate
        e_fold_us = e_fold_time * 1447  # μs (t_unit ≈ 1.447 ms)
        println("E-folding time: $(round(e_fold_time; sigdigits=3)) ω⁻¹ ($(round(e_fold_us; sigdigits=3)) μs)")
        println("\n⚠️  GROUND STATE IS UNSTABLE!")
        println("    Expected dynamics: exponential growth → blow-up")
    else
        println("\n✓ Ground state is dynamically stable")
    end

    stability
end

analyze_eu151_stability()
