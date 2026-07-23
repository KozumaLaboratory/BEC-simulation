# Accuracy-gate producer for the /goal optimisation loop (runs on the H100 node).
#
#   LD_LIBRARY_PATH=... julia --project=. observability/gates.jl
#
# Writes observability/gates_status.json = {"gates": {name: true|false, ...}}.
# round.jl reads it: accepted=true requires ALL gates true. This is the
# deterministic correctness check that stops a perf win from shipping broken
# physics — the machine-eps threshold gates, verified on the SAME env as the
# measurement (so a GPU-only kinetic regression cannot hide).
#
# Gates (relevant to a kinetic / split-step kernel change):
#   gpu_cpu_split_parity : ‖ψ_gpu − ψ_cpu‖₂ / ‖ψ_cpu‖₂ < 1e-10 after 5 steps
#   norm_conservation    : |‖ψ‖ − 1| < 1e-8 after 5 steps

import CUDA
using SpinorBEC, JSON, LinearAlgebra, Dates

include(joinpath(@__DIR__, "..", "bench", "eu151_params.jl"))

const NG = 48                      # small: fast on both CPU and GPU, within the 300s floor
const CT = ComplexF64

function ferro_init(grid, D)
    psi = zeros(CT, grid.config.n_points..., D)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r2 = sum(grid.x[d][I[d]]^2 for d in 1:length(grid.config.n_points))
        psi[I, 1] = exp(-r2 / 2)
    end
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    psi ./= sqrt(sum(abs2, psi) * dV)
    psi
end

function build_ws(psi0; backend)
    grid = make_grid(GridConfig(ntuple(_ -> NG, 3), ntuple(_ -> 16.0, 3)))
    make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(Dict(0 => EU_c0, 1 => 0.0)),
        zeeman = ZeemanParams(EU_p_weak, 0.0),
        potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params = SimParams(; dt = 0.005, n_steps = 1), psi_init = copy(psi0),
        enable_ddi = true, c_dd = 100.0, backend,
    )
end

grid0 = make_grid(GridConfig(ntuple(_ -> NG, 3), ntuple(_ -> 16.0, 3)))
psi0 = ferro_init(grid0, 13)
dV = prod(grid0.config.box_size ./ grid0.config.n_points)

gates = Dict{String,Bool}()

# --- GPU=CPU parity + norm conservation ---
try
    ws_cpu = build_ws(psi0; backend = CPUBackend())
    ws_gpu = build_ws(psi0; backend = CUDABackend())
    for _ in 1:5; split_step!(ws_cpu); end
    for _ in 1:5; split_step!(ws_gpu); end
    psi_cpu = ws_cpu.state.psi
    psi_gpu = Array(ws_gpu.state.psi)
    rel = norm(vec(psi_gpu) .- vec(psi_cpu)) / norm(vec(psi_cpu))
    nrm = sqrt(sum(abs2, psi_cpu) * dV)
    gates["gpu_cpu_split_parity"] = rel < 1e-10
    gates["norm_conservation"]    = abs(nrm - 1) < 1e-8
    println("gpu_cpu rel-L2 = ", rel, "  (<1e-10: ", gates["gpu_cpu_split_parity"], ")")
    println("norm = ", nrm, "  (|·-1|<1e-8: ", gates["norm_conservation"], ")")
catch e
    println("GATE ERROR: ", e)
    gates["gpu_cpu_split_parity"] = false
    gates["norm_conservation"]    = false
end

# --- spin_mixing GPU=CPU parity (c₁≠0 exercises the SMA Euler path) ---
try
    c1 = 0.1 * EU_c0
    ws_cpu = build_ws(psi0; backend = CPUBackend())
    ws_gpu = build_ws(psi0; backend = CUDABackend())
    SpinorBEC.apply_spin_mixing_step!(ws_cpu.state.psi, ws_cpu.spin_matrices, c1, 0.00125, 3)
    SpinorBEC.apply_spin_mixing_step!(ws_gpu.state.psi, ws_gpu.spin_matrices, c1, 0.00125, 3)
    pc = ws_cpu.state.psi
    pg = Array(ws_gpu.state.psi)
    rel = norm(vec(pg) .- vec(pc)) / norm(vec(pc))
    gates["spin_mixing_gpu_cpu_parity"] = rel < 1e-10
    println("spin_mixing gpu_cpu rel-L2 = ", rel, "  (<1e-10: ", gates["spin_mixing_gpu_cpu_parity"], ")")
catch e
    println("SPIN_MIXING GATE ERROR: ", e)
    gates["spin_mixing_gpu_cpu_parity"] = false
end

out = Dict("ts" => string(now()), "gates" => gates,
           "all_pass" => all(values(gates)))
open(joinpath(@__DIR__, "gates_status.json"), "w") do io; JSON.print(io, out, 2); end
println("\ngates_status.json: ", JSON.json(out))
println(out["all_pass"] ? "GATES_PASS" : "GATES_FAIL")
