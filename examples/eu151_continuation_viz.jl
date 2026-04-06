# Eu151 Continuation with Density Visualization
using SpinorBEC
using JSON

function continuation_with_viz(;
    nx = 32,
    box = 12.0,
    c1_ratio = -0.01,
    B_field = 2.6e-9,
    c_dd_steps = [0.0, 4000.0, 7647.0],  # Quick 3-step version
    gs_steps_per = 2000,
)
    println("=== Continuation with Density Visualization ===")
    println("Steps: $c_dd_steps")

    N_atoms = 50000
    c_total = 4689.0
    backend = CPUBackend()
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F
    D = 2F + 1

    interactions = interaction_params_from_constraint(; c_total, c1_ratio, F)
    ω_ref_rad = 2π * 110.0
    p_zeeman = linear_zeeman_p(atom, B_field, ω_ref_rad)
    q_zeeman = 0.0

    psi_current = nothing
    results = []

    for (i, c_dd) in enumerate(c_dd_steps)
        println("\n=== Step $i/$(length(c_dd_steps)): c_dd=$c_dd ===")

        enable_ddi = c_dd > 0
        initial_state = (psi_current === nothing) ? :antiferromagnetic : nothing
        psi_init = psi_current

        gs = find_ground_state(;
            grid, atom, interactions,
            zeeman = ZeemanParams(p_zeeman, q_zeeman),
            potential = HarmonicTrap((1.0, 1.0, 130.0/110.0)),
            dt = enable_ddi ? 0.0005 : 0.001,
            n_steps = gs_steps_per,
            tol = 1e-8,
            initial_state,
            psi_init,
            enable_ddi,
            c_dd = enable_ddi ? c_dd : 0.0,
            backend,
        )

        println("  E=$(round(gs.energy; sigdigits=5)), converged=$(gs.converged)")

        psi_current = copy(gs.workspace.state.psi)

        # Extract density slice (xy at z=nx/2)
        z_mid = nx ÷ 2
        n_total = total_density(psi_current, 3)
        n_slice = n_total[:, :, z_mid]

        # Extract populations
        dV = cell_volume(grid)
        pops = Dict{Int, Float64}()
        for c in 1:D
            m = F - (c - 1)
            p = sum(component_density(psi_current, 3, c)) * dV
            pops[m] = p
        end

        # Energy decomposition
        ed = energy_decomposition(gs.workspace)

        push!(results, Dict(
            "c_dd" => c_dd,
            "energy" => gs.energy,
            "converged" => gs.converged,
            "energy_decomp" => Dict(
                "kinetic" => ed.kinetic,
                "trap" => ed.trap,
                "density" => ed.density,
                "spin" => ed.spin,
                "ddi" => ed.ddi,
            ),
            "density_slice" => collect(n_slice),
            "populations" => pops,
            "n_peak" => maximum(n_total),
        ))
    end

    # Save to JSON
    data = Dict(
        "metadata" => Dict(
            "nx" => nx,
            "box" => box,
            "c1_ratio" => c1_ratio,
            "c_dd_steps" => c_dd_steps,
            "F" => F,
        ),
        "grid" => Dict(
            "x" => collect(grid.x[1]),
            "y" => collect(grid.x[2]),
        ),
        "results" => results,
    )

    outpath = "output/continuation_viz_data.json"
    open(outpath, "w") do io
        JSON.print(io, data)
    end
    println("\nSaved: $outpath")
    println("Done!")
end

continuation_with_viz()
