#!/usr/bin/env julia
# RK4IP on GPU: does it agree with CPU, what does a step cost, and does it fit?
#
#     julia --project=. scripts/validation/rk4ip_gpu_cost_probe.jl
#
# RK4IP was measured on CPU at 12^3 — 2.61 ms/step against `split_step!`'s 3.00,
# net 2.7x at a 1e-4 error budget once the larger step it holds is folded in.
# None of that has been shown to transfer. Two things could break it:
#
#   * it has never been executed on GPU at all. `_rk4ip_scratch` uses `similar`,
#     so the buffers should follow the array type, but every term's
#     `apply_operator!` face has to have a GPU path or the answer is silently
#     wrong (or scalar-indexes and is silently 1000x slow).
#   * five full-state scratch buffers. At 128^3 with D=13 ComplexF64 that is
#     5 x 436 MB = 2.2 GB on top of the workspace's own, and the DDI path is
#     zero-padded 2x, i.e. 8x the volume for its own transforms.
#
# So: PARITY FIRST, then cost, then the memory high-water mark. A cost number
# for a wrong result is worth nothing, and the parity check is the reason this
# is a script and not a benchmark.

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf

const D_EU = 13

function build(n::Int, dt::Float64, backend)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 16.0, 3)))
    make_workspace(;
        grid,
        atom=Eu151,
        interactions=InteractionParams(Dict(0 => 4687.2663 / 50, 1 => -0.5)),
        zeeman=ZeemanParams(0.4, 0.02),
        potential=HarmonicTrap((1.0, 1.0, 1.181818)),
        sim_params=SimParams(; dt=dt, n_steps=1, save_every=10^9),
        enable_ddi=true,
        c_dd=147.715012,
        secular_ddi=false,
        ddi_padding=true,
        backend=backend,
    )
end

psi0(ws) = init_psi(ws.grid, ws.spin_matrices.system;
    state=:spin_coherent, init_theta=0.35, init_phi=0.2)

"One step from the same start on both backends, compared component by component."
function parity(n::Int)
    dt = 1e-3
    ws_c = build(n, dt, CPUBackend())
    p0 = ComplexF64.(psi0(ws_c))

    copyto!(ws_c.state.psi, p0)
    ws_c.state.t = 0.0
    rk4ip_step!(ws_c)
    a = Array(ws_c.state.psi)

    ws_g = build(n, dt, CUDABackend())
    copyto!(ws_g.state.psi, p0)
    ws_g.state.t = 0.0
    rk4ip_step!(ws_g)
    b = Array(ws_g.state.psi)

    total = norm(a .- b) / norm(a)
    per = [norm(selectdim(a, 4, c) .- selectdim(b, 4, c)) /
           max(norm(selectdim(a, 4, c)), eps()) for c in 1:size(a, 4)]
    (total, maximum(per), argmax(per))
end

function ms_per_step(stepper, ws, n_reps::Int)
    for _ in 1:3
        stepper(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:3
        CUDA.synchronize()
        t = @elapsed begin
            for _ in 1:n_reps
                stepper(ws)
            end
            CUDA.synchronize()
        end
        best = min(best, t / n_reps)
    end
    1e3 * best
end

gib(x) = x / 2^30

function main()
    CUDA.functional() || error("CUDA not functional — this probe is about the GPU")
    dev = CUDA.device()
    @printf("device: %s, %.1f GiB total\n\n", CUDA.name(dev), gib(CUDA.totalmem(dev)))

    # --- 1. parity, before any timing is believed ---
    println("=== GPU vs CPU, one RK4IP step (Eu F=6, D=13, DDI on, padded) ===")
    @printf("%6s %16s %16s %8s\n", "n", "total rel L2", "worst component", "at m")
    for n in (16, 32)
        tot, worst, c = parity(n)
        @printf("%6d %16.3e %16.3e %8d\n", n, tot, worst, 6 - (c - 1))
    end
    println("\nA per-component split is the point: a term missing its GPU path can")
    println("contribute nothing to the aggregate while being wrong in one channel.\n")

    # --- 2. cost, at sizes production actually runs ---
    println("=== ms/step on GPU ===")
    @printf("%6s %14s %14s %14s %10s %10s\n",
        "n", "split_step!", "midpoint", "rk4ip", "vs split", "psi [GiB]")
    for (n, reps) in ((32, 40), (64, 20), (128, 6))
        local row
        try
            ws = build(n, 1e-3, CUDABackend())
            copyto!(ws.state.psi, psi0(ws))
            psi_gib = gib(n^3 * D_EU * 16)
            a = ms_per_step(split_step!, ws, reps)
            b = ms_per_step(split_step_midpoint!, ws, reps)
            free_before = CUDA.available_memory()
            c = ms_per_step(rk4ip_step!, ws, reps)
            free_after = CUDA.available_memory()
            @printf("%6d %14.2f %14.2f %14.2f %10.2fx %10.2f   (scratch %.2f GiB)\n",
                n, a, b, c, c / a, psi_gib, gib(max(0, free_before - free_after)))
        catch e
            @printf("%6d  FAILED: %s\n", n, sprint(showerror, e)[1:min(end, 120)])
        end
        CUDA.reclaim()
    end

    println("\nRK4IP holds 2.4x split_step!'s step at a 1e-4 error budget and 4.2x at")
    println("1e-5 (CPU, scripts/validation/rk4ip_step_size_probe.jl). Net speedup is")
    println("that ratio divided by the `vs split` column above. Below 1.0 in that")
    println("column means RK4IP is cheaper per step as well.")
end

main()
