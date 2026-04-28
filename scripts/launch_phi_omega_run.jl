# Per-run launcher for the phi_omega scan. Mirrors launch_thesis_run.jl
# but resolves config under runs/phi_omega_scan/<name>/config.yaml.
using CUDA
using SpinorBEC
using JLD2

run_name = ARGS[1]
config_path = "runs/phi_omega_scan/$run_name/config.yaml"
out_path = "runs/phi_omega_scan/$run_name/result_legacy.jld2"

config = SpinorBEC.load_config(config_path)
@time result = SpinorBEC.run_config(config; verbose = true)

dyn = result[:rotating_basis_dynamics]
pm_init = dyn[:per_m_history][1] / sum(dyn[:per_m_history][1])
pm_final = dyn[:per_m_history][end] / sum(dyn[:per_m_history][end])

println("\n=== phi_omega_scan/$run_name COMPLETED ===")
println(
    "  Lz (final phase): [",
    round(minimum(dyn[:Lz]); digits = 4),
    ", ",
    round(maximum(dyn[:Lz]); digits = 4),
    "]",
)
println(
    "  Fz (final phase): [",
    round(minimum(dyn[:Fz]); digits = 4),
    ", ",
    round(maximum(dyn[:Fz]); digits = 4),
    "]",
)
println(
    "  m=+F: ",
    round(pm_init[1]; digits = 6),
    " -> ",
    round(pm_final[1]; digits = 6),
)
println(
    "  Larmor phase per step: ",
    round(get(dyn, :larmor_phase_per_step, NaN); sigdigits = 4),
)

snapshots = get(dyn, :psi_snapshots, [])
JLD2.jldsave(
    out_path;
    times = dyn[:times],
    norms = dyn[:norms],
    Lz = dyn[:Lz],
    Fz = dyn[:Fz],
    per_m_history = hcat(dyn[:per_m_history]...),
    psi_snapshots = Vector{Array{ComplexF64, 4}}([Array(s) for s in snapshots]),
    theta_const = get(dyn, :theta_const, nothing),
    phi_omega = get(dyn, :phi_omega, nothing),
    dt_used = get(dyn, :dt_used, NaN),
    larmor_phase_per_step = get(dyn, :larmor_phase_per_step, NaN),
)
println("Saved -> $out_path")
