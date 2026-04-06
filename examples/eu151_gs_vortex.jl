# Eu151 Ground State with Vortex (ITP with perturbation)
using SpinorBEC
using Random
import CUDA

function find_eu151_vortex_gs(;
    nx = 32,
    box = 12.0,
    gs_steps = 5000,
    perturbation_amp = 1e-3,
    seed = 42,
)
    println("=== Eu151 Vortex Ground State (ITP with Perturbation) ===")
    println("Grid: $(nx)³")
    println("Perturbation: amplitude=$perturbation_amp, seed=$seed")

    N_atoms = 50000
    c_total = 4689.0
    c_dd = 7647.0

    # GPU backend
    backend = CUDA.functional() ? SpinorBEC.CUDABackend() : CPUBackend()
    println("Backend: $(typeof(backend))")

    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F
    D = 2F + 1

    # LHY calculation (same as before)
    ω_ref = 2π * 110.0
    m_eu = 151 * 1.66053906660e-27
    a_ho = sqrt(1.054571817e-34 / (m_eu * ω_ref))
    a_s = atom.a0 / 5.29177210903e-11
    a_s_si = atom.a0

    μ = 7.0 * 9.274009994e-24
    μ0 = 1.25663706212e-6
    a_dd = μ0 * μ^2 * m_eu / (12π * 1.054571817e-34^2)
    eps_dd = a_dd / a_s_si

    Q5 = lima_pelster_Q5(eps_dd)
    c_lhy_dimless = (128.0 / (3.0 * sqrt(π))) * sqrt(a_s_si^3 / a_ho^3) * N_atoms * Q5

    println("\nPhysical parameters:")
    println("  ε_dd = $(round(eps_dd; digits=3))")
    println("  c_lhy = $(round(c_lhy_dimless; digits=1))")

    # Interactions
    base_params = interaction_params_from_constraint(; c_total, c1_ratio=0.0, F)
    interactions = InteractionParams(base_params.c0, base_params.c1, c_lhy_dimless)

    println("\nDimensionless interactions:")
    println("  c0 = $(round(interactions.c0; digits=1))")
    println("  c_lhy = $(round(interactions.c_lhy; digits=1))")
    println("  c_dd = $c_dd")

    # Initial state: polar + perturbation
    println("\n=== Step 1: Create perturbed initial state ===")
    println("  Base: :polar (m=0)")
    println("  + Random noise in all m components")

    # First create pure polar state
    sys = SpinSystem(F)
    psi_init = init_psi(grid, sys; state=:polar)

    # Add small random perturbation to all components
    psi_perturbed = seed_noise(psi_init, D, 3, grid; amplitude=perturbation_amp, seed)

    # Renormalize
    dV = cell_volume(grid)
    norm_init = sqrt(sum(abs2, psi_perturbed) * dV)
    psi_perturbed ./= norm_init

    # Check initial populations
    println("\nInitial populations (after perturbation):")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi_perturbed, 3, c)) * dV
        if p > 1e-6
            println("  m=$(lpad(m, 2)): $(round(p; sigdigits=4))")
        end
    end

    # ITP with DDI + LHY
    println("\n=== Step 2: ITP with DDI + LHY ===")
    println("  Letting DDI spontaneously break symmetry...")

    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.0005,
        n_steps = gs_steps,
        tol = 1e-8,
        psi_init = psi_perturbed,
        enable_ddi = true,
        c_dd,
        backend,
    )

    println("\n=== RESULT ===")
    println("E = $(round(gs.energy; sigdigits=6))")
    println("Converged: $(gs.converged)")

    if gs.energy < 0
        println("⚠️  Negative energy")
    else
        println("✓ Positive energy")
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

    # Check final populations
    psi_final = gs.workspace.state.psi
    dV = cell_volume(grid)

    println("\n=== Final Populations ===")
    println("(Check if symmetry was broken)")

    pops = Float64[]
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi_final, 3, c)) * dV
        push!(pops, p)
        if p > 0.001
            println("  m=$(lpad(m, 2)): $(round(p; digits=4))")
        end
    end

    # Check if still purely m=0
    if pops[7] > 0.99  # m=0 is index 7 for F=6
        println("\n⚠️  Still ~100% m=0!")
        println("   DDI did NOT break symmetry in ITP")
        println("   → Perturbation too small or need longer ITP")
    else
        println("\n✓ Symmetry broken!")
        println("  Population spread across multiple m states")

        # Calculate magnetization
        n_total = total_density(psi_final, 3)
        sm = spin_matrices(F)
        Fz = spin_density_vector(psi_final, sm, 3)[3]
        avg_Fz = sum(Fz .* n_total) * dV / sum(n_total) / dV

        println("  Average ⟨F_z⟩ = $(round(avg_Fz; sigdigits=3))")
    end

    # Density peak
    n_total = total_density(psi_final, 3)
    n_peak = maximum(n_total)
    println("\nn_peak = $(round(n_peak; sigdigits=4))")

    # Stability
    println("\n=== Stability Analysis ===")
    sim_params = SimParams(; dt=0.0001, n_steps=1, save_every=1)
    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = psi_final,
        enable_ddi = true,
        c_dd,
        backend,
    )

    stability = analyze_stability(ws; n_steps=1000, sample_every=10)

    println("  Growth rate: $(round(stability.growth_rate; sigdigits=4)) ω")
    println("  Unstable: $(stability.unstable)")

    if !stability.unstable
        println("\n✓✓✓ STABLE vortex ground state found! ✓✓✓")
    else
        if stability.growth_rate < 1.0
            println("\n→ Weakly unstable (γ < 1 ω)")
            println("  May be acceptable for dynamics")
        else
            println("\n⚠️  Still strongly unstable")
        end
    end

    (gs = gs, stability = stability)
end

find_eu151_vortex_gs()
