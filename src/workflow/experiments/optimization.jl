# --- Optimization subsystem (real submodule) ---
#
# Bayesian / multi-fidelity / active-learning drivers for parameter scans.
# Wrapped in `module Optimization` for namespace isolation. Public entry
# points are re-exported by SpinorBEC.jl.
#
#   faraday_fit       — fit_faraday_param + load_target_faraday
#   bayesian_opt      — bayesian_optimize, gp_predict, expected_improvement
#   bayesian_opt_mf   — multi_fidelity_optimize_2tier, MultiFidelityBOResult
#   bayesian_opt_yaml — bayesian_optimize_yaml + multi_fidelity_optimize_yaml
#                       + bo_objective_max_m_transfer / max_lz / min_energy
#   active_learning   — active_learn_phase_scan + entropy_uncertainty

module Optimization

using JSON
using JLD2
using YAML
using Random
using Printf

# Pipeline + classification helpers come from SpinorBEC.
using ..SpinorBEC: parse_pipeline, run_pipeline, apply_overrides
using ..SpinorBEC: OverrideMap

include("optimization/faraday_fit.jl")
include("optimization/bayesian_opt.jl")
include("optimization/bayesian_opt_mf.jl")
include("optimization/bayesian_opt_yaml.jl")
include("optimization/active_learning.jl")

end # module Optimization
