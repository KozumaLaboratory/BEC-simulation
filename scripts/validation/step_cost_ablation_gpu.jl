#!/usr/bin/env julia
# Where does a split-step go on the GPU, and what is removable?
#
#     julia --project=. scripts/validation/step_cost_ablation_gpu.jl [n]
#
# By ABLATION, not by `@timeit_debug`. GPU launches are asynchronous, so a timer
# that does not synchronise measures launch cost and charges the real work to
# whichever region happens to contain the next sync. Every number below is an
# outer-level synchronised wall-clock over many steps, and each row differs from
# the one above it by exactly one feature, so the difference IS that feature's
# cost.
#
# Rows are ordered cheapest-first so each delta is read downward.

import CUDA
using SpinorBEC
using Printf

const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 128

function build(; ddi::Bool, padded::Bool, pad_factor::Float64, secular::Bool)
    grid = make_grid(GridConfig(ntuple(_ -> N, 3), ntuple(_ -> 16.0, 3)))
    kw = (; grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 4687.2663 / 50, 1 => -0.5)),
        zeeman=ZeemanParams(0.4, 0.02),
        potential=HarmonicTrap((1.0, 1.0, 1.181818)),
        sim_params=SimParams(; dt=1e-3, n_steps=1, save_every=10^9),
        backend=CUDABackend())
    ddi || return make_workspace(; kw...)
    make_workspace(; kw..., enable_ddi=true, c_dd=147.715012,
        secular_ddi=secular, ddi_padding=padded, ddi_pad_factor=pad_factor)
end

function ms_per_step(ws, stepper, reps)
    copyto!(ws.state.psi, init_psi(ws.grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.35, init_phi=0.2))
    for _ in 1:3
        stepper(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:3
        CUDA.synchronize()
        t = @elapsed begin
            for _ in 1:reps
                stepper(ws)
            end
            CUDA.synchronize()
        end
        best = min(best, t / reps)
    end
    1e3 * best
end

function main()
    CUDA.functional() || error("CUDA not functional")
    reps = N >= 128 ? 8 : (N >= 64 ? 25 : 60)
    @printf("device %s, Eu F=6 D=13, %d^3 box 16, %d reps\n\n", CUDA.name(CUDA.device()), N, reps)

    rows = Tuple{String, Any}[]
    push!(rows, ("no DDI at all", () -> build(; ddi=false, padded=false, pad_factor=2.0, secular=false)))
    push!(rows, ("DDI secular, unpadded", () -> build(; ddi=true, padded=false, pad_factor=2.0, secular=true)))
    push!(rows, ("DDI full, unpadded", () -> build(; ddi=true, padded=false, pad_factor=2.0, secular=false)))
    push!(rows, ("DDI full, pad 1.5", () -> build(; ddi=true, padded=true, pad_factor=1.5, secular=false)))
    push!(rows, ("DDI full, pad 2 (production)", () -> build(; ddi=true, padded=true, pad_factor=2.0, secular=false)))

    @printf("%-30s %12s %12s %10s\n", "configuration", "ms/step", "delta", "cumulative")
    base = NaN
    prev = NaN
    for (name, mk) in rows
        t = try
            ws = mk()
            v = ms_per_step(ws, split_step!, reps)
            CUDA.reclaim()
            v
        catch e
            @printf("%-30s  FAILED: %s\n", name, sprint(showerror, e)[1:min(end, 90)])
            continue
        end
        isnan(base) && (base = t)
        @printf("%-30s %12.3f %12s %10s\n", name, t,
            isnan(prev) ? "—" : @sprintf("%+.3f", t - prev),
            isnan(base) || base == 0 ? "—" : @sprintf("%.2fx", t / base))
        prev = t
    end

    # The predictor-corrector engages automatically whenever DDI is on. It is a
    # global Ref, so it can be ablated without touching the config.
    println("\nmidpoint predictor-corrector (auto-on with DDI):")
    ws = build(; ddi=true, padded=true, pad_factor=2.0, secular=false)
    on = ms_per_step(ws, split_step!, reps)
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = false
    off = ms_per_step(ws, split_step!, reps)
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
    @printf("  on %.3f   off %.3f   costs %+.3f ms/step (%.0f %% of the step)\n",
        on, off, on - off, 100 * (on - off) / on)
    println("  Off is the LEGACY 1st-order-with-DDI path — this is what accuracy buys,")
    println("  not a free saving. Quoted so the trade is visible.")
    CUDA.reclaim()
end

main()
