# --- Pipeline analyzers umbrella ---
#
# Per-step analyzer functions used by the YAML pipeline `analyze:` block.
# Each topic file owns its handlers; `pipeline_analyzers.jl` (loaded
# elsewhere) is the dispatch table.
#
#   helpers       — _phase_diff, _line_through_peak, _fwhm_1d, _rms_width_1d
#   imaging       — tomography, faraday, absorption, phase_contrast,
#                   sg_tof, momentum_distribution
#   phase         — phase_classify, phase_classify_distance,
#                   energy_decomposition, multipole_order, majorana_order
#   topology      — winding_map, monopole_charge, vortex_detect,
#                   skyrmion_density, non_abelian_homotopy
#   spectroscopy  — bragg, droplet, correlation_length, defect_density,
#                   kibble_zurek_stats, domain_analysis
#   stability     — stability, bogoliubov, bogoliubov_dispersion
#   misc          — summary_json (only analyzer that needs pipeline_results)
#   analyzers_large — skyrmion_detect, synthetic_dim, bogoliubov_mode,
#                     rosensweig_pattern, column_density_movie

include("analyzers/helpers.jl")
include("analyzers/imaging.jl")
include("analyzers/phase.jl")
include("analyzers/topology.jl")
include("analyzers/spectroscopy.jl")
include("analyzers/stability.jl")
include("analyzers/misc.jl")
include("analyzers/analyzers_large.jl")
include("analyzers/rotating_basis.jl")  # population_dynamics / spin_texture / per-m vortex (fast-Larmor regime)
