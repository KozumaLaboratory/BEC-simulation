# Reproducible benchmark behind `recommend_backend_dtype` (src/workflow/io/budget.jl).
#
# Measures `split_step_combined!` for Eu151 (D=13) on a cubic grid across
# {CPU, GPU} × {Float64, Float32} for N ∈ {16, 24, 32, 48}. Prints a
# summary table and the recommended (backend, dtype) per N.
#
# Run:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. scripts/bench/backend_grid_scan.jl
#
# Reference numbers (RTX 5070 Ti, Julia 1.12.6, 2026-05-10):
#   N=16: CPU-F64 3237, GPU-F64 2450, GPU-F32 2877 µs
#   N=24: CPU-F64 11368, GPU-F64 3195, GPU-F32 2629 µs
#   N=32: CPU-F64 28735, GPU-F64 3835, GPU-F32 2546 µs
#   N=48: CPU-F64 99225, GPU-F64 8428, GPU-F32 3041 µs

import CUDA
using SpinorBEC, BenchmarkTools, Printf

function _build(::Type{T}, N::Int; gpu::Bool) where {T}
    grid = make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)); dtype = T)
    sp = SimParams(; dt = 0.005, n_steps = 1)
    backend = gpu ? CUDABackend() : CPUBackend()
    ws = make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(50.0, 1.0),
        zeeman = ZeemanParams(0.5, 0.1),
        potential = HarmonicTrap(1.0, 1.0, 1.0),
        sim_params = sp,
        enable_ddi = true, c_dd = 100.0,
        dtype = T, backend = backend,
    )
    psi_h = Array(ws.state.psi)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        g = T(exp(-(x*x + y*y + z*z) / 2.0))
        for c in 1:13
            psi_h[I, c] = g * Complex{T}(cos(T(0.1)*c), sin(T(0.1)*c))
        end
    end
    copyto!(ws.state.psi, psi_h)
    SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, 13, 3)
    for _ in 1:20
        SpinorBEC.split_step_combined!(ws)
    end
    gpu && CUDA.synchronize()
    ws
end

function _bench(ws; gpu::Bool, samples::Int = 50)
    if gpu
        b = @benchmark begin
            SpinorBEC.split_step_combined!($ws); CUDA.synchronize()
        end samples = samples evals = 1
    else
        b = @benchmark SpinorBEC.split_step_combined!($ws) samples = samples evals = 1
    end
    time(minimum(b)) / 1e3
end

function main(Ns = (16, 24, 32, 48))
    gpu_avail = CUDA.functional()
    @printf("CUDA functional: %s\n", gpu_avail)
    @printf("\nGrid scan: split_step_combined! [µs / step]\n")
    @printf("%-5s %12s %12s %12s %12s   %s\n",
        "N", "CPU F64", "CPU F32", "GPU F64", "GPU F32", "recommended")
    for N in Ns
        ws_cf64 = _build(Float64, N; gpu = false)
        t_cf64 = _bench(ws_cf64; gpu = false)
        ws_cf32 = _build(Float32, N; gpu = false)
        t_cf32 = _bench(ws_cf32; gpu = false)

        if gpu_avail
            ws_gf64 = _build(Float64, N; gpu = true)
            t_gf64 = _bench(ws_gf64; gpu = true)
            ws_gf32 = _build(Float32, N; gpu = true)
            t_gf32 = _bench(ws_gf32; gpu = true)
        else
            t_gf64 = NaN; t_gf32 = NaN
        end

        rec = recommend_backend_dtype(N; cuda_functional = gpu_avail, mode = :realtime)
        @printf("%-5d %12.1f %12.1f %12.1f %12.1f   %s\n",
            N, t_cf64, t_cf32, t_gf64, t_gf32, rec)

        gpu_avail && (GC.gc(); CUDA.reclaim())
    end
end

main()
