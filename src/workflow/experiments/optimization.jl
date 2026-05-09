# --- Optimization subsystem umbrella ---
#
# Bayesian / multi-fidelity / active-learning drivers for parameter scans.
# Public entry points are exported at definition sites:
#
#   faraday_fit       — fit_faraday_param + load_target_faraday
#   bayesian_opt      — bayesian_optimize, gp_predict, expected_improvement
#   bayesian_opt_mf   — multi_fidelity_optimize_2tier, MultiFidelityBOResult
#   bayesian_opt_yaml — bayesian_optimize_yaml + multi_fidelity_optimize_yaml
#                       + bo_objective_max_m_transfer / max_lz / min_energy
#   active_learning   — active_learn_phase_scan + entropy_uncertainty

include("optimization/faraday_fit.jl")
include("optimization/bayesian_opt.jl")
include("optimization/bayesian_opt_mf.jl")
include("optimization/bayesian_opt_yaml.jl")
include("optimization/active_learning.jl")
