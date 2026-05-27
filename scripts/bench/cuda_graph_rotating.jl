# Benchmark `split_step_rotating!` plain vs CUDA Graph captured.
#
# After commits a03d264 + adf51ef + dde694f the rotating_basis split-step
# hot path has zero per-step CUDA allocations (`kspace_phase_buf`,
# `xspace_phase_buf`, `rotation_scratch`, `_ROTATION_RT_CACHE` and DDI
# `cis_PD` cover all the broadcast temps that previously invalidated
# captured argument pointers). This script measures whether
# `CUDA.@captured` now beats plain `split_step!` — if so, we re-enable
# `split_step_captured!` to dispatch to the captured path.
#
# Usage (after the scan v4 finishes, GPU free):
#   julia --project=. scripts/bench_cuda_graph_rotating.jl
#
# Output: `t_plain_ms`, `t_captured_ms`, `speedup` per-grid.

using CUDA
using SpinorBEC
using BenchmarkTools

CUDA.functional() ||
    error("CUDA not functional — needed for graph capture bench")

@info "Setting up workspace…"

# Eu151-style F=6 D=13 24×24×12 (matches phi_omega_scan dimensions —
# what the audit cares about). Use ε=1e-6 to land in the
# Larmor-stiff regime that the alloc reduction was supposed to help.
F = 6
D = 2F + 1
config = GridConfig((24, 24, 12), (10.0, 10.0, 5.0))
grid = make_grid(config)
V_trap = zeros(Float64, 24, 24, 12)
@inbounds for I in CartesianIndices(V_trap)
    x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
    V_trap[I] = 0.5 * (x^2 + y^2 + 6.76 * z^2)
end

ws = SpinorBEC.make_rotating_basis_ws(grid, F, V_trap;
    p=26700.0, q=0.0, c0=3792.0, c1=0.0,
    c_dd=170.7, gamma_lhy=0.0,
    theta_func=t -> 0.611, phi_func=t -> 4.524 * t,
    theta_dot_func=t -> 0.0, phi_dot_func=t -> 4.524,
    gauge_fix=false,
    backend=SpinorBEC.CUDABackend())

# Initialise GS
psi_init = zeros(ComplexF64, 24, 24, 12, D)
@inbounds for I in CartesianIndices((24, 24, 12))
    x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
    psi_init[I, 1] = exp(-(x^2 + y^2 + z^2) / 2)
end
copyto!(ws.psi_tilde, psi_init)
SpinorBEC.normalize_rotating!(ws)

dt = 0.01
@info "Warmup (compile both paths)…"
SpinorBEC.split_step_rotating!(ws, dt, 0.0)
CUDA.synchronize()

# Plain bench
@info "Benchmarking plain split_step_rotating! …"
b_plain = @benchmark begin
    SpinorBEC.split_step_rotating!($ws, $dt, 0.0)
    CUDA.synchronize()
end samples = 50 evals = 1
t_plain = median(b_plain).time / 1e6

# CUDA Graph bench. This is the test: does the captured replay actually
# work after the alloc reduction?
@info "Benchmarking CUDA.@captured split_step_rotating! …"
t_capt = NaN
try
    # Establish capture
    CUDA.@captured SpinorBEC.split_step_rotating!(ws, dt, 0.0)
    CUDA.synchronize()
    b_capt = @benchmark begin
        CUDA.@captured SpinorBEC.split_step_rotating!($ws, $dt, 0.0)
        CUDA.synchronize()
    end samples = 50 evals = 1
    global t_capt = median(b_capt).time / 1e6
catch e
    @warn "CUDA Graph capture failed: $e"
end

println("=" ^ 60)
println("CUDA Graph Bench — rotating_basis split_step on Eu151 D=13 24³")
println("=" ^ 60)
@printf "  plain     : %.3f ms / step\n" t_plain
@printf "  captured  : %s\n" (isnan(t_capt) ? "FAILED" : "$(round(t_capt; digits=3)) ms / step")
if !isnan(t_capt)
    @printf "  speedup   : %.2fx\n" (t_plain / t_capt)
    if t_capt < t_plain * 0.9
        println("  ✅ Captured beats plain — graph capture viable, re-enable in")
        println("     `ext/SpinorBECCUDAExt/gpu_graph.jl::split_step_captured!`")
    else
        println("  ⚠ Captured no better than plain — alloc reduction not enough,")
        println("     more work needed (likely DDI inner FFT path or local spin host work).")
    end
end
