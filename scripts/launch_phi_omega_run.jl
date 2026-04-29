# Per-run launcher for the phi_omega scan. Mirrors launch_thesis_run.jl
# but resolves config under runs/phi_omega_scan/<name>/. Writes the
# canonical dashboard-compatible JLD2 layout via
# `save_rotating_basis_result!` so the dashboard sees the run without
# a manual repack.
using CUDA
using SpinorBEC

run_name = ARGS[1]
config_path = "runs/phi_omega_scan/$run_name/config.yaml"
run_dir = "runs/phi_omega_scan/$run_name"

config = SpinorBEC.load_config(config_path)
@time result = SpinorBEC.run_config(config; verbose=true)

dyn = result[:rotating_basis_dynamics]
pm_init = dyn[:per_m_history][1] / sum(dyn[:per_m_history][1])
pm_final = dyn[:per_m_history][end] / sum(dyn[:per_m_history][end])

println("\n=== phi_omega_scan/$run_name COMPLETED ===")
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
println(
    "  m=+F: ",
    round(pm_init[1]; digits=6),
    " -> ",
    round(pm_final[1]; digits=6),
)
println(
    "  Larmor phase per step: ",
    round(get(dyn, :larmor_phase_per_step, NaN); sigdigits=4),
)

out_path = save_rotating_basis_result!(run_dir, result)
println("Saved (dashboard-canonical) -> $out_path")
