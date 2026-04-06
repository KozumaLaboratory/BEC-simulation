# Quasi-2D Eu151 F=6 BEC simulation with DDI
# Einstein-de Haas spin dynamics in quasi-2D geometry
#
# Physics: Start from m=+6 polarized state with small perturbation.
# DDI drives Einstein-de Haas spin relaxation and domain formation.
#
# Approach: ground state found WITHOUT DDI (DDI causes ITP divergence
# when c_dd×F²/3 >> c0_eff). Then DDI is enabled for dynamics.
# Full N=50000 used (DDI-free ITP is stable at any N).

using SpinorBEC
using FFTW
using JSON
using LinearAlgebra
using Random

const NDIM = 2

function run_eu151_quasi2d(;
    nx = 128,
    box = 16.0,
    c1_ratio = -0.01,
    l_z = sqrt(110.0 / 130.0),
    gs_steps = 5000,
    gs_tol = 1e-8,
    dyn_dt = 1e-4,
    dyn_steps = 50000,     # 5.0 ω⁻¹
    save_every = 2500,      # 20 snapshots
    perturb_amp = 0.2,  # 4% population transfer to m=+5 (20% amplitude)
    seed = 42,
)
    c_total = 4689.0
    c_dd = 7647.0

    grid = make_grid(GridConfig((nx, nx), (box, box)))
    atom = Eu151
    F = atom.F
    D = 2F + 1
    sys = SpinSystem(F)
    sm = spin_matrices(F)
    dV = cell_volume(grid)

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)

    factor = 1.0 / (sqrt(2π) * l_z)
    c0_eff = interactions.c0 * factor
    c1_eff = interactions.c1 * factor
    eps_dd = c_dd / c0_eff

    println("=== Quasi-2D ¹⁵¹Eu F=6 EdH Dynamics ===")
    println("Grid: $(nx)×$(nx), box=$(box), l_z=$(round(l_z; digits=4))")
    println("N=50000, c_total=$(round(c_total;digits=2)), c_dd=$(round(c_dd;digits=2))")
    println("c0_eff=$(round(c0_eff;digits=1)), c1_eff=$(round(c1_eff;digits=3)), ε_dd=$(round(eps_dd;digits=3))")
    println()

    # --- Ground state WITHOUT DDI (fast) ---
    println("Finding ground state (ferromagnetic, no DDI)...")
    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0)),
        dt = 0.001,
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :ferromagnetic,
        enable_ddi = false,
        quasi_2d = true, l_z,
    )
    println("  E=$(round(gs.energy; sigdigits=6)), converged=$(gs.converged)")

    gs_ws = gs.workspace
    gs_ed = energy_decomposition(gs_ws)
    gs_psi = copy(gs_ws.state.psi)
    gs_n = total_density(gs_psi, NDIM)
    n_peak = maximum(gs_n)
    println("  n_peak=$(round(n_peak; sigdigits=4))")
    println("  E_kin=$(round(gs_ed.kinetic;sigdigits=4)), E_trap=$(round(gs_ed.trap;sigdigits=4)), E_dens=$(round(gs_ed.density;sigdigits=4))")

    # --- Coherent m=+6 → m=+5 transfer (RF pulse simulation) ---
    # Spatially uniform phase (mimics RF/microwave pulse)
    println("\nAdding coherent m=+6→m=+5 transfer (transfer fraction=$(perturb_amp^2))...")
    psi_perturbed = copy(gs_psi)

    # Component indices: c=1 → m=+6, c=2 → m=+5
    # For 2D: psi[i,j,c]
    psi_m6 = view(psi_perturbed, :, :, 1)
    psi_m5 = view(psi_perturbed, :, :, 2)

    # Coherent transfer with uniform phase (physical RF pulse)
    # |ψ_m5|² = perturb_amp² × |ψ_m6|²
    # ψ_m5 = perturb_amp × ψ_m6  (no random phase)
    # ψ_m6 → sqrt(1 - perturb_amp²) × ψ_m6
    psi_m5 .= perturb_amp .* psi_m6
    psi_m6 .*= sqrt(1 - perturb_amp^2)

    # Already normalized by construction (|a|² + |b|² = (1-ε²) + ε² = 1)

    # Check initial populations
    print("  Initial pops: ")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi_perturbed, NDIM, c)) * dV
        p > 0.005 && print("m=$m:$(round(p;digits=3)) ")
    end
    println()

    # --- Dynamics with DDI ---
    t_total = dyn_steps * dyn_dt
    println("\nRunning dynamics with DDI ($dyn_steps steps, dt=$dyn_dt, T=$(t_total) ω⁻¹)...")
    sim_params = SimParams(; dt=dyn_dt, n_steps=dyn_steps, save_every)

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0)),
        sim_params,
        psi_init = psi_perturbed,
        enable_ddi = true,
        c_dd,
        quasi_2d = true, l_z,
    )

    sim_result = run_simulation!(ws)
    println("  Final E=$(round(sim_result.energies[end]; sigdigits=8))")

    # --- Observables ---
    println("\nComputing observables...")
    n_snaps = length(sim_result.times)
    m_values = [F - (c-1) for c in 1:D]

    all_pops = Dict{Int, Vector{Float64}}()
    for m in m_values; all_pops[m] = Float64[]; end

    # Keep full spatial resolution (128×128)
    stride = 1
    nx_out = nx

    density_snaps = []
    fz_snaps = []
    selected_m = [F, F-1, F÷2, 0, -(F÷2), -F]
    selected_comp_snaps = Dict{Int, Vector{Any}}()
    for m in selected_m; selected_comp_snaps[m] = []; end

    ds(arr) = arr  # No downsampling, keep full precision

    for (i, psi_snap) in enumerate(sim_result.psi_snapshots)
        n = total_density(psi_snap, NDIM)
        norm_total = sum(n) * dV
        for c in 1:D
            m = m_values[c]
            nc = component_density(psi_snap, NDIM, c)
            push!(all_pops[m], sum(nc) * dV / norm_total)
        end

        push!(density_snaps, ds(n))
        fz = spin_density_vector(psi_snap, sm, NDIM)[3]
        push!(fz_snaps, ds(fz))
        for m in selected_m
            c = F - m + 1
            push!(selected_comp_snaps[m], ds(component_density(psi_snap, NDIM, c)))
        end

        if i == 1 || i == n_snaps || i % max(1, n_snaps÷4) == 0
            pf = round(all_pops[F][end]; digits=4)
            p5 = round(all_pops[F-1][end]; digits=4)
            p0 = round(all_pops[0][end]; digits=5)
            println("  t=$(round(sim_result.times[i];digits=4)): P(+6)=$pf, P(+5)=$p5, P(0)=$p0")
        end
    end

    final_ed = energy_decomposition(ws)

    # --- JSON output ---
    println("\nBuilding output data...")
    x = collect(grid.x[1])
    y = collect(grid.x[2])

    pop_dict = Dict("m_$m" => all_pops[m] for m in m_values)

    data = Dict(
        "metadata" => Dict(
            "atom" => "Eu151", "F" => F, "D" => D,
            "nx" => nx, "nx_out" => nx_out, "box" => box, "l_z" => l_z,
            "N_atoms" => 50000,
            "c_total" => c_total, "c1_ratio" => c1_ratio,
            "c0" => interactions.c0, "c1" => interactions.c1,
            "c0_eff" => c0_eff, "c1_eff" => c1_eff,
            "c_dd" => c_dd, "eps_dd" => eps_dd,
            "n_peak" => n_peak,
            "dyn_dt" => dyn_dt, "dyn_steps" => dyn_steps,
            "m_values" => m_values,
            "selected_m" => selected_m,
        ),
        "grid" => Dict("x" => x, "y" => y),
        "ground_state" => Dict(
            "energy" => gs.energy, "converged" => gs.converged,
            "energy_decomposition" => Dict(
                "kinetic" => gs_ed.kinetic, "trap" => gs_ed.trap,
                "density" => gs_ed.density, "spin" => gs_ed.spin,
                "ddi" => gs_ed.ddi, "zeeman" => gs_ed.zeeman,
                "total" => gs_ed.total,
            ),
            "density" => ds(gs_n),
        ),
        "dynamics" => Dict(
            "times" => sim_result.times,
            "energies" => sim_result.energies,
            "norms" => sim_result.norms,
            "populations" => pop_dict,
            "density_snapshots" => density_snaps,
            "fz_snapshots" => fz_snaps,
            "component_snapshots" => Dict(
                "m_$m" => selected_comp_snaps[m] for m in selected_m
            ),
        ),
        "final_energy_decomposition" => Dict(
            "kinetic" => final_ed.kinetic, "trap" => final_ed.trap,
            "density" => final_ed.density, "spin" => final_ed.spin,
            "ddi" => final_ed.ddi, "zeeman" => final_ed.zeeman,
            "total" => final_ed.total,
        ),
    )

    outdir = joinpath(dirname(@__DIR__), "output")
    mkpath(outdir)
    outpath = joinpath(outdir, "quasi_2d_eu151_data.json")
    open(outpath, "w") do io
        JSON.print(io, data)
    end
    println("Saved: $outpath ($(round(filesize(outpath)/1e6; digits=1)) MB)")
    println("Done!")
    data
end

run_eu151_quasi2d()
