# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, atom, params)
    F = atom.F
    if name == :tomography
        spin_tomography(psi, grid, F;
            rotation_axis = Symbol(get(params, "axis", "y")),
            n_angles = Int(get(params, "n_angles", 19)),
            theta_min = Float64(get(params, "theta_min", 0.0)),
            theta_max = Float64(get(params, "theta_max", Float64(π))),
            reference_m = let v = get(params, "reference_m", nothing); v === nothing ? nothing : Int(v) end,
            tof_params = let td = get(params, "tof", Dict())
                TOFParams(Float64(get(td, "t_tof", 11.0)),
                         Float64(get(td, "gradient", 0.0)),
                         Int(get(td, "imaging_axis", 3)))
            end,
        )
    elseif name == :faraday
        faraday_image(psi, grid, F;
            params = FaradayParams(;
                probe_axis = Int(get(params, "probe_axis", get(params, "axis", 3))),
                detuning = Float64(get(params, "detuning", -64.0)),
                polarization = Symbol(get(params, "polarization", "linear_x")),
            ),
        )
    elseif name == :energy_decomposition
        sm = spin_matrices(F)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :phase_classify
        sm = spin_matrices(F)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :stability
        ndim = length(grid.config.n_points)
        sp = SimParams(; dt = 0.0001, n_steps = 1, save_every = 1)
        ws = make_workspace(;
            grid, atom,
            interactions = InteractionParams(0.0, 0.0),
            potential = HarmonicTrap(ntuple(_ -> 1.0, ndim)),
            sim_params = sp,
            psi_init = psi,
        )
        perturbation = Float64(get(params, "perturbation", 1e-4))
        n_steps_stab = Int(get(params, "n_steps", 1000))
        sample_every = Int(get(params, "sample_every", 10))
        analyze_stability(ws; perturbation, n_steps = n_steps_stab, sample_every)
    else
        throw(ArgumentError("Unknown analyzer: $name. Supported: tomography, faraday, energy_decomposition, phase_classify, stability"))
    end
end
