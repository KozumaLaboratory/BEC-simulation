# --- Stability + Bogoliubov analyzers ---
#
# `_analyze_stability` runs the linear-stability routine on a fresh
# workspace seeded from the supplied ψ. `_analyze_bogoliubov` and
# `_analyze_bogoliubov_dispersion` both extract the spinor at the
# density peak and feed it into the BdG diagonaliser; the former
# scans direction grids to flag instabilities, the latter returns
# the full ω(k) for every band so the dashboard can plot it.
#
# `_run_bogoliubov_analyzer` is the shared peak-spinor extractor +
# instability-scan helper used by `_analyze_bogoliubov` and the
# `bogoliubov_mode` analyzer in analyzers_large.jl.

function _analyze_stability(psi, grid, atom, params, ws_prev)
    ndim = length(grid.config.n_points)
    sp = SimParams(; dt=0.0001, n_steps=1, save_every=1)
    ws = make_workspace(;
        grid, atom,
        interactions=InteractionParams(Dict{Int, Float64}()),
        potential=HarmonicTrap(ntuple(_ -> 1.0, ndim)),
        sim_params=sp,
        psi_init=psi,
    )
    perturbation = Float64(get(params, "perturbation", 1e-4))
    n_steps_stab = Int(get(params, "n_steps", 1000))
    sample_every = Int(get(params, "sample_every", 10))
    analyze_stability(ws; perturbation, n_steps=n_steps_stab, sample_every)
end

function _analyze_bogoliubov(psi, grid, atom, params, ws_prev)
    _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
end

function _analyze_bogoliubov_dispersion(psi, grid, atom, params, ws_prev)
    # Full ω(k) for every BdG band, returned as a (n_k, 2D) matrix.
    # Useful to plot the full dispersion (not just max growth)
    # — roton dips, gapped vs gapless modes, branch crossings.
    ws_prev === nothing && throw(ArgumentError(
        "bogoliubov_dispersion requires a preceding ground_state step"))
    F = atom.F
    D = 2F + 1
    ndim = length(grid.config.n_points)
    psi_host = _to_host(psi)
    n_total = total_density(psi_host, ndim)
    peak_idx = argmax(n_total)
    spinor = ComplexF64[psi_host[peak_idx, c] for c in 1:D]
    n0 = sum(abs2, spinor)
    n0 > COUPLING_TOL && (spinor ./= sqrt(n0))
    interactions = ws_prev.interactions
    c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
    zeeman = if is_uniform(ws_prev.zeeman)
        ZeemanParams(linear_p(ws_prev.zeeman), quadratic_q(ws_prev.zeeman))
    else
        ZeemanParams(0.0, 0.0)
    end
    k_max = Float64(get(params, "k_max", 10.0))
    n_k = Int(get(params, "n_k", 200))
    k_dir_raw = get(params, "k_direction", [0.0, 0.0, 1.0])
    k_direction = NTuple{3, Float64}(Tuple(Float64.(k_dir_raw)))
    result = bogoliubov_spectrum(;
        spinor=spinor, n0=n0, F=F,
        interactions=interactions, zeeman=zeeman, c_dd=c_dd_val,
        k_max=k_max, n_k=n_k, k_direction=k_direction,
    )
    omega_sorted = similar(result.omega)
    for ik in 1:n_k
        col = result.omega[:, ik]
        perm = sortperm(real.(col))
        omega_sorted[:, ik] .= col[perm]
    end
    (k_values=result.k_values,
        omega_real=real.(omega_sorted),
        omega_imag=imag.(omega_sorted),
        max_growth=result.max_growth_rate,
        direction=collect(k_direction))
end

"""
Extract the local spinor ζ at the density peak and run `bogoliubov_instability_scan`
using the physical couplings (c₀, c₁, c_k, c_dd) from the preceding ground-state step.

Returns a NamedTuple with `max_growth`, `unstable`, `k_peak`, `wavelength`,
`best_direction`, `pattern`, `anisotropy`, suitable for JLD2 persistence.
"""
function _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    ws_prev === nothing &&
        throw(
            ArgumentError(
                "bogoliubov analyzer requires a preceding ground_state step (ws_prev is nothing)"
            ),
        )

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
    if n0 > COUPLING_TOL
        spinor ./= sqrt(n0)
    end

    interactions = ws_prev.interactions
    c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
    zeeman = if is_uniform(ws_prev.zeeman)
        ZeemanParams(linear_p(ws_prev.zeeman), quadratic_q(ws_prev.zeeman))
    else
        ZeemanParams(0.0, 0.0)
    end

    k_max = Float64(get(params, "k_max", 10.0))
    n_k = Int(get(params, "n_k", 200))
    dir_mode = Symbol(get(params, "directions", "auto"))
    n_dirs = Int(get(params, "n_directions", 50))
    directions_arg = dir_mode in (:auto, :dense, :planar) ? dir_mode : :auto

    imap = bogoliubov_instability_scan(;
        spinor, n0, F, interactions, zeeman, c_dd=c_dd_val,
        k_max, n_k,
        directions=directions_arg,
        n_directions=n_dirs,
    )
    pred = predict_supersolid_params(imap)

    (
        n0=n0,
        max_growth=imap.max_growth_rate,
        unstable=imap.unstable,
        k_peak=imap.most_unstable_k,
        wavelength=imap.predicted_wavelength,
        best_direction=imap.most_unstable_direction,
        pattern=pred.pattern_type,
        anisotropy=pred.angular_anisotropy,
    )
end
