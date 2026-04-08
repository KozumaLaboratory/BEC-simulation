# Quasi-2D Rb87 F=1 BEC simulation with DDI
# Demonstrates: ground state in quasi-2D geometry + quench dynamics
#
# Physics: Polar state stabilized by quadratic Zeeman q>0.
# Quench q→0 triggers parametric spin mixing instability (m=0 → m=±1).
# DDI modifies the spatial pattern of spin domain formation.
#
# Output: quasi_2d_demo_data.json for dashboard visualization

using SpinorBEC
using FFTW
using JSON
using LinearAlgebra

const NDIM = 2

function run_quasi_2d_demo(;
    nx = 64,
    box = 8.0,
    c0 = 500.0,
    c1 = -500.0,
    c_dd = 50.0,
    l_z = 1.5,
    q_gs = 40.0,
    gs_steps = 5000,
    gs_tol = 1e-9,
    dyn_steps = 3000,
    dyn_dt = 0.001,
    save_every = 30,
    perturb_amp = 0.01,
    seed = 42,
)
    grid = make_grid(GridConfig((nx, nx), (box, box)))
    atom = Rb87
    F = atom.F
    D = 2F + 1
    sys = SpinSystem(F)
    sm = spin_matrices(F)
    interactions = InteractionParams(c0, c1)
    dV = cell_volume(grid)

    # Effective after quasi-2D scaling
    factor = 1.0 / (sqrt(2π) * l_z)
    c0_eff = c0 * factor
    c1_eff = c1 * factor

    println("=== Quasi-2D Rb87 F=1 Demo ===")
    println("Grid: $(nx)×$(nx), box=$(box), l_z=$(l_z)")
    println("c0=$c0 → c0_eff=$(round(c0_eff; digits=1))")
    println("c1=$c1 → c1_eff=$(round(c1_eff; digits=1))")
    println("c_dd=$c_dd, ε_dd=$(round(c_dd/c0; digits=3))")
    println()

    # --- Ground state: polar phase stabilized by large q ---
    println("Finding ground state (q=$q_gs)...")
    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, q_gs),
        potential = HarmonicTrap((1.0, 1.0)),
        dt = 0.005,
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :polar,
        enable_ddi = true,
        c_dd,
        quasi_2d = true, l_z,
    )
    println("  E=$(round(gs.energy; sigdigits=6)), converged=$(gs.converged)")

    gs_ws = gs.workspace
    gs_ed = energy_decomposition(gs_ws)
    println("  E_kin=$(round(gs_ed.kinetic; sigdigits=4)), E_trap=$(round(gs_ed.trap; sigdigits=4))")
    println("  E_density=$(round(gs_ed.density; sigdigits=4)), E_spin=$(round(gs_ed.spin; sigdigits=4))")
    println("  E_ddi=$(round(gs_ed.ddi; sigdigits=4))")

    # --- Ground state observables ---
    gs_psi = copy(gs_ws.state.psi)
    gs_n = total_density(gs_psi, NDIM)
    n_peak = maximum(gs_n)
    println("  n_peak=$(round(n_peak; sigdigits=4))")
    println("  q_crit = 2|c1_eff|n_peak = $(round(2*abs(c1_eff)*n_peak; sigdigits=4))")

    gs_comp = [component_density(gs_psi, NDIM, c) for c in 1:D]
    gs_fz = spin_density_vector(gs_psi, sm, NDIM)[3]

    # --- Perturbation ---
    println("\nAdding noise perturbation (amp=$perturb_amp)...")
    psi_perturbed = SpinorBEC.seed_noise(gs_psi, D, NDIM, grid; amplitude=perturb_amp, seed)

    # --- Dynamics: quench q→0 ---
    println("\nRunning dynamics (q=0, $(dyn_steps) steps, dt=$dyn_dt)...")
    sim_params = SimParams(; dt = dyn_dt, n_steps = dyn_steps, save_every)

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
    println("  Final norm=$(round(sim_result.norms[end]; sigdigits=6))")

    # --- Compute populations and snapshots from sim_result ---
    snap_times = sim_result.times
    snap_energies = sim_result.energies

    pop_data = Dict{String,Vector{Float64}}(
        "m_plus1" => Float64[], "m_0" => Float64[], "m_minus1" => Float64[],
    )
    density_snaps = []
    comp_snaps_p1 = []
    comp_snaps_0 = []
    comp_snaps_m1 = []
    fz_snaps = []

    for psi_snap in sim_result.psi_snapshots
        n = total_density(psi_snap, NDIM)
        norm_total = sum(n) * dV
        for (key, c) in [("m_plus1", D), ("m_0", F+1), ("m_minus1", 1)]
            nc = component_density(psi_snap, NDIM, c)
            push!(pop_data[key], sum(nc) * dV / norm_total)
        end
        push!(density_snaps, n)
        push!(comp_snaps_p1, component_density(psi_snap, NDIM, D))
        push!(comp_snaps_0, component_density(psi_snap, NDIM, F+1))
        push!(comp_snaps_m1, component_density(psi_snap, NDIM, 1))
        push!(fz_snaps, spin_density_vector(psi_snap, sm, NDIM)[3])
    end

    final_ed = energy_decomposition(ws)

    println("\nPopulation evolution:")
    for (i, t) in enumerate(snap_times)
        if i == 1 || i == length(snap_times) || i % max(1, length(snap_times) ÷ 5) == 0
            println("  t=$(round(t; digits=3)): P(+1)=$(round(pop_data["m_plus1"][i]; digits=4)), " *
                "P(0)=$(round(pop_data["m_0"][i]; digits=4)), " *
                "P(-1)=$(round(pop_data["m_minus1"][i]; digits=4))")
        end
    end

    # --- Build output data ---
    println("\nBuilding output data...")
    x = collect(grid.x[1])
    y = collect(grid.x[2])
    stride = nx > 64 ? 2 : 1
    x_out = x[1:stride:end]
    y_out = y[1:stride:end]

    ds(arr) = arr[1:stride:end, 1:stride:end]

    data = Dict(
        "metadata" => Dict(
            "atom" => "Rb87", "F" => F, "D" => D,
            "nx" => nx, "box" => box, "l_z" => l_z,
            "c0" => c0, "c1" => c1, "c_dd" => c_dd,
            "c0_eff" => c0_eff, "c1_eff" => c1_eff,
            "eps_dd" => c_dd / c0,
            "q_gs" => q_gs, "dyn_dt" => dyn_dt,
            "dyn_steps" => dyn_steps,
            "n_peak" => n_peak,
        ),
        "grid" => Dict("x" => x_out, "y" => y_out),
        "ground_state" => Dict(
            "energy" => gs.energy,
            "converged" => gs.converged,
            "energy_decomposition" => Dict(
                "kinetic" => gs_ed.kinetic, "trap" => gs_ed.trap,
                "density" => gs_ed.density, "spin" => gs_ed.spin,
                "ddi" => gs_ed.ddi, "zeeman" => gs_ed.zeeman,
                "total" => gs_ed.total,
            ),
            "density" => ds(gs_n),
            "component_densities" => [ds(gs_comp[c]) for c in 1:D],
            "fz" => ds(gs_fz),
        ),
        "dynamics" => Dict(
            "times" => snap_times,
            "energies" => snap_energies,
            "norms" => sim_result.norms,
            "populations" => pop_data,
            "density_snapshots" => [ds(s) for s in density_snaps],
            "component_snapshots" => Dict(
                "m_plus1" => [ds(s) for s in comp_snaps_p1],
                "m_0" => [ds(s) for s in comp_snaps_0],
                "m_minus1" => [ds(s) for s in comp_snaps_m1],
            ),
            "fz_snapshots" => [ds(s) for s in fz_snaps],
        ),
        "final_energy_decomposition" => Dict(
            "kinetic" => final_ed.kinetic, "trap" => final_ed.trap,
            "density" => final_ed.density, "spin" => final_ed.spin,
            "ddi" => final_ed.ddi, "zeeman" => final_ed.zeeman,
            "total" => final_ed.total,
        ),
    )

    outpath = joinpath(@__DIR__, "quasi_2d_demo_data.json")
    open(outpath, "w") do io
        JSON.print(io, data, 2)
    end
    println("Saved: $outpath ($(round(filesize(outpath)/1e6; digits=1)) MB)")
    println("Done!")

    data
end

run_quasi_2d_demo()
