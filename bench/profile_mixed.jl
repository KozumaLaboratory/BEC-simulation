# Profile split_step! at F32 and F64 on GPU to see where time goes.
# Uses CUDA.@profile + TimerOutputs (already in SpinorBEC via @timeit_debug).

using CUDA
using SpinorBEC
using Printf

function mk_ws(; T, F=6, enable_ddi=true, dims=(128,128,128))
    cfg = GridConfig(dims, ntuple(_ -> 10.0, length(dims)))
    grid = make_grid(cfg; dtype=T)
    atom = F == 1 ? AtomSpecies("Na23", 3.8e-26, 1, 52.0*5.29e-11, 54.3*5.29e-11, 0.0) :
                     AtomSpecies("Eu151", 2.5e-25, 6, 110*5.29e-11, 0.0, 6.977*9.274e-24)
    ip = F == 1 ? InteractionParams(50.0, -0.2) : InteractionParams(100.0, 2.8)
    trap = HarmonicTrap(1.0,1.0,1.0)
    sp = SimParams(; dt=0.001, n_steps=50)
    kw = (; grid, atom, interactions=ip, sim_params=sp, potential=trap,
            backend=SpinorBEC.CUDABackend(), dtype=T)
    kw = enable_ddi ? merge(kw, (; enable_ddi=true, c_dd=100.0)) : kw
    make_workspace(; kw...)
end

function profile_run(label::String; T, F, enable_ddi, dims, n_steps=30)
    println("\n========== $label ==========")
    ws = mk_ws(; T, F, enable_ddi, dims)
    CUDA.allowscalar(false)

    # Warm up
    for _=1:5; SpinorBEC.split_step!(ws); end
    CUDA.synchronize()

    # Enable timers
    SpinorBEC.reset_tracing!()
    SpinorBEC.enable_tracing!()

    CUDA.synchronize()
    t0 = time_ns()
    for _=1:n_steps
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()
    wall = (time_ns() - t0) / 1e9

    SpinorBEC.disable_tracing!()
    @printf("  total wall: %.3f s (%.2f ms/step)\n", wall, wall*1000/n_steps)
    # print TimerOutputs tree
    println("  === timer breakdown ===")
    show(stdout, SpinorBEC.TIMER; allocations=false, compact=true)
    println()
end

profile_run("Eu151 F64 DDI 128³"; T=Float64, F=6, enable_ddi=true, dims=(128,128,128))
profile_run("Eu151 F32 DDI 128³"; T=Float32, F=6, enable_ddi=true, dims=(128,128,128))
