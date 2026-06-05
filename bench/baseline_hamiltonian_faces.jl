# Stage-0 measured baseline: Hamiltonian faces at Eu production scale.
#
# 24³ × D=13 (eu151_preset), secular DDI, B≈1-class Zeeman, RT — a
# representative M1 sweep cell. These numbers are the reference for the
# performance gates (arch doc §8: correctness gate ⊥ performance gate
# ≤ baseline +2%) and the input the fusion / KernelAbstractions
# decisions in the performance-architecture design are gated on.
#
# Run:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/baseline_hamiltonian_faces.jl
#
# Notes:
# - @allocated on the GPU backend measures HOST-side allocation only
#   (CuArray pool churn is not counted); device-side churn shows up in
#   the timing instead.
# - split_step! advances ws.state — per-step cost is what matters, the
#   trajectory itself is irrelevant here.

import CUDA
using SpinorBEC
using Printf
using Statistics: median

const TW = eu151_preset()
const SYS = SpinSystem(TW.atom.F)

function build_ws(backend)
    psi_init = init_psi(TW.grid, SYS; state=:m_minus_F)
    sp = SimParams(; dt=0.005, n_steps=10, imaginary_time=false, normalize_every=0)
    return make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZeemanParams(1.0, 0.05), potential=TW.potential,
        sim_params=sp, psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=true,
        backend=backend,
    )
end

_sync(backend) = backend isa CUDABackend ? CUDA.synchronize() : nothing

function bench(f!, name, backend; n=20)
    f!()  # warmup / JIT
    _sync(backend)
    ts = Float64[]
    for _ in 1:n
        t0 = time_ns()
        f!()
        _sync(backend)
        push!(ts, (time_ns() - t0) / 1e9)
    end
    al = @allocated f!()
    _sync(backend)
    @printf(
        "%-32s  median %8.2f ms   min %8.2f ms   host alloc %12d B\n",
        name, 1e3 * median(ts), 1e3 * minimum(ts), al,
    )
    return (; name, median=median(ts), min=minimum(ts), alloc=al)
end

function run_backend(backend, label)
    println("\n=== $label ===")
    t0 = time()
    ws = build_ws(backend)
    println("make_workspace + first init: $(round(time() - t0; digits=1)) s (incl. JIT)")
    psi = ws.state.psi
    grad = similar(psi)
    bench(() -> SpinorBEC.energy_decomposition(ws), "energy_decomposition", backend)
    bench(() -> SpinorBEC.energy_gradient!(grad, psi, ws), "energy_gradient!", backend)
    bench(() -> SpinorBEC.split_step!(ws), "split_step! (RT, secular DDI)", backend)
    backend isa CUDABackend && CUDA.reclaim()
    return nothing
end

run_backend(CPUBackend(), "CPU 24³ × D=13 (Eu preset)")
if CUDA.functional()
    run_backend(CUDABackend(), "GPU 24³ × D=13 (Eu preset)")
else
    println("\nGPU skipped: CUDA not functional")
end
println("\nbaseline complete")
