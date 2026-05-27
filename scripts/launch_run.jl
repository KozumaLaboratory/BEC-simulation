# Per-run launcher (parameterised over batch). Resolves config from
# `runs/<batch>/<name>/config.yaml`, runs the pipeline, and writes the
# canonical dashboard-compatible JLD2 layout via
# `save_rotating_basis_result!` (auto-save → `result.jld2` + a
# `point_001.jld2` symlink; dashboard sees the run with no repack step).
#
# Usage:
#   julia --project=. scripts/launch_run.jl <batch> <run_name>
#
# Replaces the per-batch launch_*_run.jl trio (thesis / berry / phi_omega).
using CUDA
using SpinorBEC

length(ARGS) == 2 || error(
    "usage: julia --project=. scripts/launch_run.jl <batch> <run_name>"
)
batch, run_name = ARGS[1], ARGS[2]
config_path = "runs/$batch/$run_name/config.yaml"
run_dir = "runs/$batch/$run_name"

config = SpinorBEC.load_config(config_path)
@time result = SpinorBEC.run_config(config; verbose=true)

dyn = result[:rotating_basis_dynamics]
pm_init = dyn[:per_m_history][1] / sum(dyn[:per_m_history][1])
pm_final = dyn[:per_m_history][end] / sum(dyn[:per_m_history][end])

dyn_hist = get(result, :dynamics_history, nothing)
n_phases = dyn_hist === nothing ? 1 : length(dyn_hist)

println("\n=== $batch/$run_name COMPLETED ===")
println("  phases: $n_phases")
println(
    "  Lz (final phase): [",
    round(minimum(dyn[:Lz]); digits=4),
    ", ",
    round(maximum(dyn[:Lz]); digits=4),
    "]",
)
println(
    "  Fz (final phase): [",
    round(minimum(dyn[:Fz]); digits=4),
    ", ",
    round(maximum(dyn[:Fz]); digits=4),
    "]",
)
println("  m=+F: ", round(pm_init[1]; digits=6), " -> ", round(pm_final[1]; digits=6))
println(
    "  Larmor phase per step: ",
    round(get(dyn, :larmor_phase_per_step, NaN); sigdigits=4),
)

out_path = save_rotating_basis_result!(run_dir, result)
println("Saved (dashboard-canonical) -> $out_path")
