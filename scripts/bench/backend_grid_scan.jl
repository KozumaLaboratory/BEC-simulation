# Reproducible benchmark behind `recommend_backend_dtype` (src/workflow/io/budget.jl).
#
# Measures `split_step_combined!` and `split_step!` for Eu151 (D=13) on a
# cubic grid across {CPU, GPU} × {Float64, Float32} for N ∈ {16, 24, 32, 48}.
# Prints a summary table, the recommended (backend, dtype) per N, and
# (optionally) writes a CSV consumable by the matplotlib companion
# `plot_backend_grid_scan.py`.
#
# Run:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. scripts/bench/backend_grid_scan.jl
#   # → also writes /tmp/bench_results.csv unless ENV["NO_CSV"] is set
#
# Reference numbers (RTX 5070 Ti, Julia 1.12.6, 2026-05-10, combined!):
#   N=16: CPU-F64  3227, GPU-F64 2644, GPU-F32 2822 µs
#   N=24: CPU-F64 12316, GPU-F64 2931, GPU-F32 2591 µs
#   N=32: CPU-F64 27065, GPU-F64 3820, GPU-F32 2629 µs
#   N=48: CPU-F64 105607, GPU-F64 8583, GPU-F32 2859 µs
# GPU F32 / CPU F64 speedup: 1.1× → 4.8× → 10.3× → 36.9×

import CUDA
using SpinorBEC, BenchmarkTools, Printf

function _build(::Type{T}, N::Int; gpu::Bool) where {T}
    grid = make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)); dtype=T)
    sp = SimParams(; dt=0.005, n_steps=1)
    backend = gpu ? CUDABackend() : CPUBackend()
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(50.0, 1.0),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=100.0,
        dtype=T, backend=backend,
    )
    psi_h = Array(ws.state.psi)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
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

function _bench(ws; gpu::Bool, samples::Int=50, kernel::Symbol=:combined)
    f! = kernel === :combined ? SpinorBEC.split_step_combined! : SpinorBEC.split_step!
    if gpu
        b = @benchmark begin
            $f!($ws);
            CUDA.synchronize()
        end samples = samples evals = 1
    else
        b = @benchmark $f!($ws) samples = samples evals = 1
    end
    time(minimum(b)) / 1e3
end

function main(Ns=(16, 24, 32, 48); csv_path=get(ENV, "BENCH_CSV", "/tmp/bench_results.csv"))
    gpu_avail = CUDA.functional()
    @printf("CUDA functional: %s\n", gpu_avail)
    write_csv = !haskey(ENV, "NO_CSV")
    csv_io = write_csv ? open(csv_path, "w") : devnull
    write_csv && println(csv_io, "N,backend,dtype,kernel,us")

    @printf("\nGrid scan: split_step_combined! [µs / step]\n")
    @printf("%-5s %12s %12s %12s %12s   %s\n",
        "N", "CPU F64", "CPU F32", "GPU F64", "GPU F32", "recommended")
    for N in Ns
        configs = if gpu_avail
            [("cpu", "f64", Float64, false), ("cpu", "f32", Float32, false),
                ("cuda", "f64", Float64, true), ("cuda", "f32", Float32, true)]
        else
            [("cpu", "f64", Float64, false), ("cpu", "f32", Float32, false)]
        end
        ts = Dict{Tuple{String, String}, Float64}()
        for (be, dt, T, gpu) in configs
            ws = _build(T, N; gpu=gpu)
            for kernel in (:combined, :sequential)
                t = _bench(ws; gpu=gpu, kernel=kernel)
                kernel === :combined && (ts[(be, dt)] = t)
                write_csv && println(csv_io, "$N,$be,$dt,$(String(kernel)),$(round(t, digits=1))")
            end
            ws = nothing;
            gpu && (GC.gc(); CUDA.reclaim())
        end
        rec = recommend_backend_dtype(N; cuda_functional=gpu_avail, mode=:realtime)
        @printf("%-5d %12.1f %12.1f %12.1f %12.1f   %s\n", N,
            ts[("cpu", "f64")], ts[("cpu", "f32")],
            get(ts, ("cuda", "f64"), NaN), get(ts, ("cuda", "f32"), NaN), rec)
    end

    write_csv && (close(csv_io); @printf("\nWrote %s\n", csv_path))
    write_csv && @printf("Plot:  python3 scripts/bench/plot_backend_grid_scan.py %s\n", csv_path)
end

main()
