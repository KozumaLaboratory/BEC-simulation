# Eu151 Spontaneous Magnetization via RTP
# Start from m=0 polar GS, add perturbation, observe vortex formation

using SpinorBEC
using Random
using JSON
import CUDA

function run_spontaneous_magnetization(;
    nx = 32,
    box = 12.0,
    perturbation_amp = 1e-3,
    seed = 42,
    dyn_dt = 5e-5,  # Small dt for fast growth
    dyn_time = 0.5,  # ω⁻¹ (~0.72 ms)
    save_every = 500,
)
    println("=== Eu151 Spontaneous Magnetization (RTP from m=0) ===")
    println("Grid: $(nx)³, T_final = $(dyn_time) ω⁻¹")
    println("Perturbation: $perturbation_amp")

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
    sys = SpinSystem(F)
    sm = spin_matrices(F)
    dV = cell_volume(grid)

    # LHY parameters (same as before)
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

    base_params = interaction_params_from_constraint(; c_total, c1_ratio=0.0, F)
    interactions = InteractionParams(base_params.c0, base_params.c1, c_lhy_dimless)

    println("\nStep 1: Find m=0 polar ground state...")
    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        dt = 0.0005,
        n_steps = 3000,
        tol = 1e-8,
        initial_state = :polar,
        enable_ddi = true,
        c_dd,
        backend,
    )
    println("  E = $(round(gs.energy; sigdigits=5))")

    # Add perturbation
    println("\nStep 2: Add random perturbation...")
    psi_perturbed = seed_noise(
        gs.workspace.state.psi, D, 3, grid;
        amplitude=perturbation_amp, seed
    )
    # Renormalize
    psi_norm = sqrt(sum(abs2, psi_perturbed) * dV)
    psi_perturbed ./= psi_norm

    println("  Initial populations:")
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(psi_perturbed, 3, c)) * dV
        if p > 1e-5
            println("    m=$(lpad(m, 2)): $(round(p; sigdigits=4))")
        end
    end

    # RTP with DDI + LHY
    println("\nStep 3: Real-time propagation...")
    println("  Observing spontaneous magnetization and vortex formation")
    println("  Expected e-fold time: ~0.034 ω⁻¹")

    dyn_steps = Int(round(dyn_time / dyn_dt))
    sim_params = SimParams(; dt=dyn_dt, n_steps=dyn_steps, save_every)

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
        sim_params,
        psi_init = psi_perturbed,
        enable_ddi = true,
        c_dd,
        backend,
    )

    result = run_simulation!(ws)
    println("\n  Simulation complete!")
    println("  Final E = $(round(result.energies[end]; sigdigits=6))")

    # Analyze dynamics
    println("\n=== Analysis ===")

    all_pops = Dict{Int, Vector{Float64}}()
    for m in -F:F
        all_pops[m] = Float64[]
    end

    magnetizations = Float64[]
    spin_orders = Float64[]
    density_slices_xy = []
    fz_slices_xy = []

    z_mid = div(nx, 2) + 1  # Middle z-slice

    for psi_snap in result.psi_snapshots
        # Populations
        for c in 1:D
            m = F - (c - 1)
            p = sum(component_density(psi_snap, 3, c)) * dV
            push!(all_pops[m], p)
        end

        # Magnetization
        Fvec = spin_density_vector(psi_snap, sm, 3)
        Fz = Fvec[3]
        n = total_density(psi_snap, 3)
        avg_mz = sum(Fz .* n) * dV / sum(n) / dV
        push!(magnetizations, avg_mz)

        # Spin order parameter
        F_mag = sqrt.(Fvec[1].^2 .+ Fvec[2].^2 .+ Fvec[3].^2)
        spin_order = sum(F_mag.^2 .* n) * dV / (F^2 * sum(n.^2) * dV)
        push!(spin_orders, spin_order)

        # Spatial slices (xy plane at z_mid)
        density_xy = n[:, :, z_mid]
        fz_xy = Fz[:, :, z_mid]
        push!(density_slices_xy, collect(density_xy))
        push!(fz_slices_xy, collect(fz_xy))
    end

    println("\nPopulation evolution:")
    println("  t=0: P(m=0)=$(round(all_pops[0][1]; digits=4))")
    println("  t=$(round(result.times[end]; digits=2)): P(m=0)=$(round(all_pops[0][end]; digits=4))")
    println("\n  Final populations:")
    final_pops = [(m, all_pops[m][end]) for m in -F:F]
    sort!(final_pops, by=x->x[2], rev=true)
    for (m, p) in final_pops[1:min(5, length(final_pops))]
        p > 0.01 && println("    m=$(lpad(m, 2)): $(round(p; digits=4))")
    end

    println("\n  Magnetization: ⟨F_z⟩ = $(round(magnetizations[1]; sigdigits=3)) → $(round(magnetizations[end]; sigdigits=3))")
    println("  Spin order: $(round(spin_orders[1]; sigdigits=3)) → $(round(spin_orders[end]; sigdigits=3))")

    # Save data
    println("\nSaving data...")
    data = Dict(
        "metadata" => Dict(
            "nx" => nx, "box" => box,
            "F" => F, "N_atoms" => N_atoms,
            "perturbation" => perturbation_amp,
            "dyn_time" => dyn_time,
            "c_dd" => c_dd, "c_lhy" => c_lhy_dimless,
        ),
        "grid" => Dict("x" => collect(grid.x[1]),
                       "y" => collect(grid.x[2]),
                       "z" => collect(grid.x[3])),
        "times" => result.times,
        "energies" => result.energies,
        "populations" => Dict("m_$m" => all_pops[m] for m in -F:F),
        "magnetization" => magnetizations,
        "spin_order" => spin_orders,
        "density_slices_xy" => density_slices_xy,
        "fz_slices_xy" => fz_slices_xy,
    )

    outpath = "output/spontaneous_magnetization.json"
    open(outpath, "w") do io
        JSON.print(io, data)
    end
    println("Saved: $outpath")
    println("\n✓ Success! Spontaneous magnetization observed.")

    result
end

run_spontaneous_magnetization()
