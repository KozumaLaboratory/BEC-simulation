# Eu151 3D Einstein-de Haas Effect
# Based on Matsui et al. arXiv:2025 (Science 2026)
#
# Key experimental conditions:
# - 3D trap: ω = (110, 110, 130) Hz
# - N = 5×10⁴ atoms
# - Initial: m=-6 polarized (spin-up along z)
# - Magnetic field: 2.6 nT (spin relaxation) → 0.1 mT (resonant EdH)
# - Observation: spin relaxation + ring/vortex formation
# - Time scale: 40 ms (≈ 27.6 ω⁻¹)

using SpinorBEC
using FFTW
using JSON
using LinearAlgebra
import CUDA

const NDIM = 3

function run_eu151_edh_3d(;
    nx = 32,
    box = 12.0,
    c1_ratio = -0.01,
    B_field = 2.6e-9,  # 2.6 nT in Tesla
    gs_steps = 3000,
    gs_tol = 1e-7,
    dyn_dt = 0.0002,
    dyn_steps = 15000,  # 3.0 ω⁻¹ ≈ 4.3 ms
    save_every = 750,
    seed = 42,
)
    # Physical parameters
    N_atoms = 50000
    c_total = 4689.0
    c_dd = 7647.0

    # Use CPU backend (GPU has scalar indexing issues in observables)
    backend = CPUBackend()

    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F
    D = 2F + 1
    sys = SpinSystem(F)
    sm = spin_matrices(F)
    dV = cell_volume(grid)

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)

    # Compute Zeeman parameters (dimensionless)
    # ω_ref in rad/s for dimensionless units
    ω_ref_rad = 2π * 110.0  # rad/s
    p_zeeman = linear_zeeman_p(atom, B_field, ω_ref_rad)
    # Eu151: no hyperfine splitting → quadratic Zeeman negligible
    q_zeeman = 0.0

    println("=== 3D ¹⁵¹Eu F=6 Einstein-de Haas Effect ===")
    println("Grid: $(nx)³, box=$(box)")
    println("N=$N_atoms, c_total=$(round(c_total;digits=2)), c_dd=$(round(c_dd;digits=2))")
    println("c0=$(round(interactions.c0;digits=1)), c1=$(round(interactions.c1;digits=2))")
    println("B=$(B_field*1e9) nT, p=$(round(p_zeeman;sigdigits=3)), q=$(round(q_zeeman;sigdigits=3))")
    println()

    # --- Ground state: m=-6 polarized WITHOUT DDI ---
    # DDI causes ITP divergence for F=6 (c_dd × F²/3 >> c0)
    # Find GS without DDI, then enable DDI for dynamics only
    println("Finding ground state (m=-6 polarized, DDI-free ITP)...")

    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.001,
        n_steps = gs_steps,
        tol = gs_tol,
        initial_state = :antiferromagnetic,  # m=-F polarized
        enable_ddi = false,  # DDI off for ITP
        backend,
    )
    println("  E=$(round(gs.energy; sigdigits=6)), converged=$(gs.converged)")

    gs_ws = gs.workspace
    gs_ed = energy_decomposition(gs_ws)
    gs_psi = copy(gs_ws.state.psi)
    gs_n = total_density(gs_psi, NDIM)
    n_peak = maximum(gs_n)
    println("  n_peak=$(round(n_peak; sigdigits=4))")
    println("  E_kin=$(round(gs_ed.kinetic;sigdigits=4)), E_trap=$(round(gs_ed.trap;sigdigits=4))")
    println("  E_dens=$(round(gs_ed.density;sigdigits=4)), E_ddi=$(round(gs_ed.ddi;sigdigits=4))")

    # Check initial populations
    println("\nInitial populations:")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(gs_psi, NDIM, c)) * dV
        p > 0.01 && println("  m=$m: $(round(p;digits=4))")
    end

    # --- Dynamics with weak magnetic field ---
    t_total = dyn_steps * dyn_dt
    println("\nRunning dynamics ($dyn_steps steps, dt=$dyn_dt, T=$(t_total) ω⁻¹)...")
    sim_params = SimParams(; dt=dyn_dt, n_steps=dyn_steps, save_every)

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(p_zeeman, q_zeeman),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = gs_psi,
        enable_ddi = true,
        c_dd,
        backend,
    )

    sim_result = run_simulation!(ws)
    println("  Final E=$(round(sim_result.energies[end]; sigdigits=8))")

    # --- Observables ---
    println("\nComputing observables...")
    n_snaps = length(sim_result.times)
    m_values = [F - (c-1) for c in 1:D]

    all_pops = Dict{Int, Vector{Float64}}()
    for m in m_values; all_pops[m] = Float64[]; end

    # Central slice (xy at z=nx/2) for visualization
    z_slice = nx ÷ 2
    density_slices = []
    fz_slices = []

    for (i, psi_snap) in enumerate(sim_result.psi_snapshots)
        n = total_density(psi_snap, NDIM)
        norm_total = sum(n) * dV

        for c in 1:D
            m = m_values[c]
            nc = component_density(psi_snap, NDIM, c)
            push!(all_pops[m], sum(nc) * dV / norm_total)
        end

        # Save central xy slice
        push!(density_slices, n[:, :, z_slice])
        fz = spin_density_vector(psi_snap, sm, NDIM)[3]
        push!(fz_slices, fz[:, :, z_slice])

        if i == 1 || i == n_snaps || i % max(1, n_snaps÷4) == 0
            p_m6 = round(all_pops[-F][end]; digits=4)
            p_m5 = round(all_pops[-F+1][end]; digits=4)
            p0 = round(all_pops[0][end]; digits=5)
            println("  t=$(round(sim_result.times[i];digits=4)): P(-6)=$p_m6, P(-5)=$p_m5, P(0)=$p0")
        end
    end

    final_ed = energy_decomposition(ws)

    # --- JSON output ---
    println("\nBuilding output data...")
    x = collect(grid.x[1])
    y = collect(grid.x[2])
    z = collect(grid.x[3])

    pop_dict = Dict("m_$m" => all_pops[m] for m in m_values)

    data = Dict(
        "metadata" => Dict(
            "atom" => "Eu151", "F" => F, "D" => D,
            "nx" => nx, "box" => box,
            "N_atoms" => N_atoms,
            "c_total" => c_total, "c1_ratio" => c1_ratio,
            "c0" => interactions.c0, "c1" => interactions.c1,
            "c_dd" => c_dd,
            "B_field" => B_field, "p_zeeman" => p_zeeman, "q_zeeman" => q_zeeman,
            "n_peak" => n_peak,
            "dyn_dt" => dyn_dt, "dyn_steps" => dyn_steps,
            "m_values" => m_values,
            "trap_omega" => [1.0, 1.0, 130.0/110.0],
        ),
        "grid" => Dict("x" => x, "y" => y, "z" => z),
        "ground_state" => Dict(
            "energy" => gs.energy, "converged" => gs.converged,
            "energy_decomposition" => Dict(
                "kinetic" => gs_ed.kinetic, "trap" => gs_ed.trap,
                "density" => gs_ed.density, "spin" => gs_ed.spin,
                "ddi" => gs_ed.ddi, "zeeman" => gs_ed.zeeman,
                "total" => gs_ed.total,
            ),
            "density_slice_xy" => gs_n[:, :, z_slice],
        ),
        "dynamics" => Dict(
            "times" => sim_result.times,
            "energies" => sim_result.energies,
            "norms" => sim_result.norms,
            "populations" => pop_dict,
            "density_slices_xy" => density_slices,
            "fz_slices_xy" => fz_slices,
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
    outpath = joinpath(outdir, "eu151_edh_3d_data.json")
    open(outpath, "w") do io
        JSON.print(io, data)
    end
    println("Saved: $outpath ($(round(filesize(outpath)/1e6; digits=1)) MB)")
    println("Done!")
    data
end

run_eu151_edh_3d()
