# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, atom, params; ws_prev = nothing)
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
    elseif name == :bogoliubov
        _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    else
        throw(ArgumentError("Unknown analyzer: $name. Supported: tomography, faraday, energy_decomposition, phase_classify, stability, bogoliubov"))
    end
end

"""
Extract the local spinor ζ at the density peak and run `bogoliubov_instability_scan`
using the physical couplings (c₀, c₁, c_k, c_dd) from the preceding ground-state step.

Returns a NamedTuple with `max_growth`, `unstable`, `k_peak`, `wavelength`,
`best_direction`, `pattern`, `anisotropy`, suitable for JLD2 persistence.
"""
function _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    ws_prev === nothing &&
        throw(ArgumentError("bogoliubov analyzer requires a preceding ground_state step (ws_prev is nothing)"))

    F = atom.F
    D = 2F + 1
    ndim = length(grid.config.n_points)

    psi_host = _to_host(psi)
    n_total = total_density(psi_host, ndim)
    peak_idx = argmax(n_total)

    spinor = Vector{ComplexF64}(undef, D)
    n0 = 0.0
    for c in 1:D
        spinor[c] = psi_host[peak_idx, c]
        n0 += abs2(spinor[c])
    end
    if n0 > 1e-30
        spinor ./= sqrt(n0)
    end

    interactions = ws_prev.interactions
    c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
    zeeman = ws_prev.zeeman isa ZeemanParams ? ws_prev.zeeman : ZeemanParams(0.0, 0.0)

    k_max = Float64(get(params, "k_max", 10.0))
    n_k = Int(get(params, "n_k", 200))
    dir_mode = Symbol(get(params, "directions", "auto"))
    n_dirs = Int(get(params, "n_directions", 50))
    directions_arg = dir_mode in (:auto, :dense, :planar) ? dir_mode : :auto

    imap = bogoliubov_instability_scan(;
        spinor, n0, F, interactions, zeeman, c_dd = c_dd_val,
        k_max, n_k,
        directions = directions_arg,
        n_directions = n_dirs,
    )
    pred = predict_supersolid_params(imap)

    (
        n0 = n0,
        max_growth = imap.max_growth_rate,
        unstable = imap.unstable,
        k_peak = imap.most_unstable_k,
        wavelength = imap.predicted_wavelength,
        best_direction = imap.most_unstable_direction,
        pattern = pred.pattern_type,
        anisotropy = pred.angular_anisotropy,
    )
end
