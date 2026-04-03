using SpinorBEC

const HAS_CUDA = try
    @eval import CUDA
    CUDA.functional()
catch
    false
end

function bench_split_step(; N_grid=32, F=1, n_steps=100, enable_ddi=false, c_dd=0.0)
    grid = make_grid(GridConfig(ntuple(_ -> N_grid, 3), ntuple(_ -> 10.0, 3)))
    atom = F == 1 ? Rb87 : Eu151
    interactions = compute_interaction_params(atom)
    sp = SimParams(; dt=0.001, n_steps, imaginary_time=false, save_every=n_steps)

    kwargs = (;
        grid, atom, interactions, sim_params=sp,
        enable_ddi, c_dd,
    )

    # CPU benchmark
    ws_cpu = make_workspace(; kwargs..., backend=CPUBackend())
    for _ in 1:3
        split_step!(ws_cpu)
    end
    t_cpu = @elapsed for _ in 1:n_steps
        split_step!(ws_cpu)
    end
    println("CPU: $(N_grid)^3, F=$F, DDI=$enable_ddi")
    println("  $(n_steps) steps in $(round(t_cpu, digits=3))s → $(round(t_cpu/n_steps*1e3, digits=2)) ms/step")

    if HAS_CUDA
        ws_gpu = make_workspace(; kwargs..., backend=CUDABackend())
        for _ in 1:3
            split_step!(ws_gpu)
        end
        CUDA.synchronize()
        t_gpu = @elapsed begin
            for _ in 1:n_steps
                split_step!(ws_gpu)
            end
            CUDA.synchronize()
        end
        speedup = t_cpu / t_gpu
        println("GPU: $(n_steps) steps in $(round(t_gpu, digits=3))s → $(round(t_gpu/n_steps*1e3, digits=2)) ms/step")
        println("Speedup: $(round(speedup, digits=1))×")
    else
        println("  (CUDA not available, GPU benchmark skipped)")
    end
    println()
end

println("=== GPU Benchmark ===\n")

bench_split_step(N_grid=32, F=1, n_steps=200)
bench_split_step(N_grid=64, F=1, n_steps=100)
bench_split_step(N_grid=32, F=1, n_steps=100, enable_ddi=true, c_dd=100.0)
bench_split_step(N_grid=64, F=1, n_steps=50, enable_ddi=true, c_dd=100.0)
bench_split_step(N_grid=32, F=6, n_steps=50)
bench_split_step(N_grid=64, F=6, n_steps=20)
bench_split_step(N_grid=32, F=6, n_steps=20, enable_ddi=true, c_dd=100.0)
bench_split_step(N_grid=64, F=6, n_steps=10, enable_ddi=true, c_dd=100.0)

println("--- 128³ cases ---\n")
bench_split_step(N_grid=128, F=1, n_steps=10)
bench_split_step(N_grid=128, F=1, n_steps=5, enable_ddi=true, c_dd=100.0)
bench_split_step(N_grid=128, F=6, n_steps=3)
bench_split_step(N_grid=128, F=6, n_steps=2, enable_ddi=true, c_dd=100.0)
