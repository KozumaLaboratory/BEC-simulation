using JSON

# --- Analyzer dispatch (R23 split 2026-05-02) ---
#
# This was a 710-line monolith holding every `_run_analyzer` branch +
# helpers + _run_bogoliubov_analyzer. The bodies have been moved to
# topical files under analyzers/ (loaded from SpinorBEC.jl):
#
#   analyzers/helpers.jl       ← _phase_diff, _line_through_peak, _fwhm_1d,
#                                 _rms_width_1d, _max_forward_grad
#   analyzers/imaging.jl       ← tomography, faraday, absorption_image,
#                                 phase_contrast_image, sg_tof, momentum_distribution
#   analyzers/phase.jl         ← phase_classify[/distance], energy_decomposition,
#                                 multipole_order, majorana_order
#   analyzers/topology.jl      ← winding_map, winding_field, monopole_charge,
#                                 vortex_detect, skyrmion_density, non_abelian_homotopy
#   analyzers/spectroscopy.jl  ← bragg_spectroscopy, droplet_profile,
#                                 correlation_length, defect_density,
#                                 kibble_zurek_stats, domain_analysis
#   analyzers/stability.jl     ← stability, bogoliubov, bogoliubov_dispersion,
#                                 _run_bogoliubov_analyzer
#   analyzers/misc.jl          ← summary_json (the only analyzer needing pipeline_results)
#   analyzers_large.jl         ← skyrmion_detect, synthetic_dim, bogoliubov_mode,
#                                 rosensweig_pattern, column_density_movie (extracted earlier)
#
# Every helper is named `_analyze_<name>` and takes
# `(psi, grid, atom, params, ws_prev)`; `_analyze_summary_json` adds
# the `pipeline_results` dict as a 6th arg.

function _run_analyzer(name::Symbol, psi, grid, atom, params; ws_prev=nothing,
    pipeline_results::Dict{Symbol, Any}=Dict{Symbol, Any}())
    # Analyzers perform reductions over psi and are not GPU-safe in general.
    # Move to host once here; no-op on CPU.
    psi = _to_host(psi)

    if name == :tomography
        return _analyze_tomography(psi, grid, atom, params, ws_prev)
    elseif name == :faraday
        return _analyze_faraday(psi, grid, atom, params, ws_prev)
    elseif name == :energy_decomposition
        return _analyze_energy_decomposition(psi, grid, atom, params, ws_prev)
    elseif name == :phase_classify
        return _analyze_phase_classify(psi, grid, atom, params, ws_prev)
    elseif name == :phase_classify_distance
        return _analyze_phase_classify_distance(psi, grid, atom, params, ws_prev)
    elseif name == :stability
        return _analyze_stability(psi, grid, atom, params, ws_prev)
    elseif name == :bogoliubov
        return _analyze_bogoliubov(psi, grid, atom, params, ws_prev)
    elseif name == :multipole_order
        return _analyze_multipole_order(psi, grid, atom, params, ws_prev)
    elseif name == :winding_map
        return _analyze_winding_map(psi, grid, atom, params, ws_prev)
    elseif name == :absorption_image
        return _analyze_absorption_image(psi, grid, atom, params, ws_prev)
    elseif name == :sg_tof
        return _analyze_sg_tof(psi, grid, atom, params, ws_prev)
    elseif name == :domain_analysis
        return _analyze_domain_analysis(psi, grid, atom, params, ws_prev)
    elseif name == :skyrmion_density
        return _analyze_skyrmion_density(psi, grid, atom, params, ws_prev)
    elseif name == :phase_contrast_image
        return _analyze_phase_contrast_image(psi, grid, atom, params, ws_prev)
    elseif name == :momentum_distribution
        return _analyze_momentum_distribution(psi, grid, atom, params, ws_prev)
    elseif name == :vortex_detect
        return _analyze_vortex_detect(psi, grid, atom, params, ws_prev)
    elseif name == :correlation_length
        return _analyze_correlation_length(psi, grid, atom, params, ws_prev)
    elseif name == :defect_density
        return _analyze_defect_density(psi, grid, atom, params, ws_prev)
    elseif name == :kibble_zurek_stats
        return _analyze_kibble_zurek_stats(psi, grid, atom, params, ws_prev)
    elseif name == :bragg_spectroscopy
        return _analyze_bragg_spectroscopy(psi, grid, atom, params, ws_prev)
    elseif name == :droplet_profile
        return _analyze_droplet_profile(psi, grid, atom, params, ws_prev)
    elseif name == :bogoliubov_dispersion
        return _analyze_bogoliubov_dispersion(psi, grid, atom, params, ws_prev)
    elseif name == :bogoliubov_mode
        return _analyze_bogoliubov_mode(psi, grid, atom, params, ws_prev)
    elseif name == :skyrmion_detect
        return _analyze_skyrmion_detect(psi, grid, atom, params, ws_prev)
    elseif name == :synthetic_dim
        return _analyze_synthetic_dim(psi, grid, atom, params, ws_prev)
    elseif name == :non_abelian_homotopy
        return _analyze_non_abelian_homotopy(psi, grid, atom, params, ws_prev)
    elseif name == :monopole_charge
        return _analyze_monopole_charge(psi, grid, atom, params, ws_prev)
    elseif name == :majorana_order
        return _analyze_majorana_order(psi, grid, atom, params, ws_prev)
    elseif name == :winding_field
        return _analyze_winding_field(psi, grid, atom, params, ws_prev)
    elseif name == :rosensweig_pattern
        return _analyze_rosensweig_pattern(psi, grid, atom, params, ws_prev)
    elseif name == :column_density_movie
        return _analyze_column_density_movie(psi, grid, atom, params, ws_prev)
    elseif name == :summary_json
        return _analyze_summary_json(psi, grid, atom, params, ws_prev, pipeline_results)
    end

    _known =
        "tomography, faraday, energy_decomposition, phase_classify, " *
        "phase_classify_distance, stability, bogoliubov, multipole_order, " *
        "winding_map, absorption_image, sg_tof, domain_analysis, skyrmion_density, " *
        "phase_contrast_image, momentum_distribution, vortex_detect, " *
        "correlation_length, defect_density, kibble_zurek_stats, " *
        "bragg_spectroscopy, droplet_profile, bogoliubov_dispersion, " *
        "bogoliubov_mode, skyrmion_detect, synthetic_dim, non_abelian_homotopy, " *
        "monopole_charge, majorana_order, winding_field, rosensweig_pattern, " *
        "column_density_movie, summary_json"
    throw(ArgumentError("Unknown analyzer: $name. Supported: $_known"))
end
