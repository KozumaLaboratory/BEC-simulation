# Eu151 Ground State with LHY Correction (Li & Saito method)
using SpinorBEC
using SpecialFunctions

function find_eu151_gs_with_lhy(;
    nx = 32,
    box = 12.0,
    c1_ratio = 0.0,  # Li & Saito: neglect spin-dependent interaction
    B_field = 0.0,   # Start from m=0, no external field
    gs_steps = 5000,
    gs_tol = 1e-8,
)
    println("=== Eu151 Ground State with LHY (Li & Saito method) ===")
    println("Grid: $(nx)³")

    N_atoms = 50000
    c_total = 4689.0
    c_dd = 7647.0

    # GPU backend (requires CUDA.jl)
    import CUDA
    backend = CUDA.functional() ? SpinorBEC.CUDABackend() : CPUBackend()
    println("Backend: $(typeof(backend))")
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F

    # Physical parameters for LHY calculation
    ω_ref = 2π * 110.0  # rad/s
    m_eu = 151 * 1.66053906660e-27  # kg
    a_ho = sqrt(1.054571817e-34 / (m_eu * ω_ref))  # m
    a_s = atom.a0 / 5.29177210903e-11  # Convert to a₀ (Bohr radii)
    a_s_si = atom.a0  # m (already in SI)

    # DDI parameter
    μ = 7.0 * 9.274009994e-24  # 7 μ_B in J/T
    μ0 = 1.25663706212e-6  # N/A²
    a_dd = μ0 * μ^2 * m_eu / (12π * 1.054571817e-34^2)  # m
    eps_dd = a_dd / a_s_si

    println("\nPhysical parameters:")
    println("  a_s = $(round(a_s; digits=2)) a₀")
    println("  a_dd = $(round(a_dd/5.29177210903e-11; digits=2)) a₀")
    println("  ε_dd = a_dd/a_s = $(round(eps_dd; digits=3))")
    println("  a_ho = $(round(a_ho*1e6; digits=3)) μm")

    # LHY coefficient (dimensionless)
    # c_lhy = (128/3√π) × √(a_s³/a_ho³) × N × Q₅(ε_dd)
    Q5 = lima_pelster_Q5(eps_dd)
    c_lhy_dimless = (128.0 / (3.0 * sqrt(π))) * sqrt(a_s_si^3 / a_ho^3) * N_atoms * Q5

    println("  Q₅(ε_dd) = $(round(Q5; digits=4))")
    println("  c_lhy (dimless) = $(round(c_lhy_dimless; digits=1))")

    # Interaction params
    # First get c0, c1 from constraint
    base_params = interaction_params_from_constraint(; c_total, c1_ratio, F)

    # Then create InteractionParams with LHY
    interactions = InteractionParams(base_params.c0, base_params.c1, c_lhy_dimless)

    println("\nDimensionless interactions:")
    println("  c0 = $(round(interactions.c0; digits=1))")
    println("  c1 = $(round(interactions.c1; digits=3))")
    println("  c_lhy = $(round(interactions.c_lhy; digits=1))")
    println("  c_dd = $c_dd")
    println("  c_dd/c0 = $(round(c_dd/interactions.c0; digits=2))")

    # Zeeman (start with zero field)
    ω_ref_rad = 2π * 110.0
    p_zeeman = B_field > 0 ? linear_zeeman_p(atom, B_field, ω_ref_rad) : 0.0
    q_zeeman = 0.0

    println("\nFinding ground state (DDI + LHY enabled)...")
    println("  Initial state: :polar (m=0)")
    println("  This allows spontaneous magnetization and vortex formation")

    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.0005,
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :polar,  # Li & Saito: start from m=0
        enable_ddi = true,
        c_dd,
        backend,
    )

    println("\n=== RESULT ===")
    println("E = $(round(gs.energy; sigdigits=6))")
    println("Converged: $(gs.converged)")

    if gs.energy < 0
        println("⚠️  Negative energy - may still indicate instability")
    else
        println("✓ Positive energy - physically reasonable")
    end

    # Energy decomposition
    ed = energy_decomposition(gs.workspace)
    println("\nEnergy decomposition:")
    println("  Kinetic:  $(round(ed.kinetic; sigdigits=4))")
    println("  Trap:     $(round(ed.trap; sigdigits=4))")
    println("  Density:  $(round(ed.density; sigdigits=4))")
    println("  Spin:     $(round(ed.spin; sigdigits=4))")
    println("  DDI:      $(round(ed.ddi; sigdigits=4))")
    println("  LHY:      $(round(ed.lhy; sigdigits=4))")
    println("  Zeeman:   $(round(ed.zeeman; sigdigits=4))")

    # Check populations
    D = 2F + 1
    dV = cell_volume(grid)
    psi = gs.workspace.state.psi

    println("\nPopulations (all components):")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi, 3, c)) * dV
        if p > 0.001
            println("  m=$(lpad(m, 2)): $(round(p; digits=4))")
        end
    end

    # Density peak
    n_total = total_density(psi, 3)
    n_peak = maximum(n_total)
    println("\nn_peak = $(round(n_peak; sigdigits=4))")

    # Stability analysis
    println("\nRunning stability analysis...")
    sim_params = SimParams(; dt=0.0001, n_steps=1, save_every=1)
    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = psi,
        enable_ddi = true,
        c_dd,
        backend,
    )

    stability = analyze_stability(ws; n_steps=1000, sample_every=10)

    println("\nStability:")
    println("  Growth rate: $(round(stability.growth_rate; sigdigits=4)) ω")
    println("  Unstable: $(stability.unstable)")

    if !stability.unstable
        println("\n✓✓✓ SUCCESS! DDI-enabled ground state is STABLE! ✓✓✓")
    else
        e_fold = 1.0 / stability.growth_rate
        e_fold_ms = e_fold * 1447 / 1000  # ms
        println("\n⚠️  Still unstable:")
        println("     Growth rate: $(round(stability.growth_rate; sigdigits=3)) ω")
        println("     E-fold time: $(round(e_fold; sigdigits=3)) ω⁻¹ ($(round(e_fold_ms; sigdigits=3)) ms)")

        if stability.growth_rate < 1.0
            println("     → Slow growth, may be acceptable for short-time dynamics")
        end
    end

    (gs = gs, stability = stability)
end

find_eu151_gs_with_lhy()
