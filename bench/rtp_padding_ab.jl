# What the production RTP step actually costs, padded vs bare.
#
#   LD_LIBRARY_PATH=... julia --project=. bench/rtp_padding_ab.jl [N] [steps]
#
# `bench/profile_rtp.jl` builds its workspace by calling `make_workspace`
# directly, where `ddi_padding` defaults to FALSE. Since 9c117c05 the YAML
# parsers default it TRUE (`DDI_PADDED_DEFAULT`, parsing_blocks.jl), and
# `_spin_chain_reason` declines the fused `diag · SM · DDI · SM · diag`
# half-step whenever `ws.ddi_padded !== nothing`. So the benchmark measures the
# fused path and production does not.
#
# This prints, for each arm, BOTH the step time and the reason string, so the
# mechanism is read off the run rather than inferred from the source.

import CUDA
using SpinorBEC
using Printf
include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "reconcile.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10

function build_ws(; n=N_GRID, padded::Bool)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt=1e-4, n_steps=N_STEPS, imaginary_time=false, save_every=10^9)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
        sim_params=sp, enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=padded, backend=CUDABackend(),
    )
    psi = init_psi(grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.6, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    copyto!(ws.state.psi, psi)
    ws
end

step_n!(ws, k) = (for _ in 1:k
    SpinorBEC.split_step!(ws)
end; CUDA.synchronize())

function arm(padded::Bool)
    ws = build_ws(; padded)
    # The eligibility answer, straight from the predicate the propagator calls.
    reason = SpinorBEC._spin_chain_reason(ws, ws.interactions, ws.state.psi)
    fused_ok = reason === nothing && SpinorBEC._spin_chain_available(ws.state.psi, ws)
    step_n!(ws, 3)
    t = 1e3 * timed(() -> step_n!(ws, N_STEPS); warmup=1, samples=5).t / N_STEPS
    ws = nothing
    GC.gc(true)
    CUDA.reclaim()
    (t, fused_ok, reason)
end

function main()
    @printf("RTP padded-vs-bare — %s, Eu151 F=6 (D=13) F64, %d^3\n",
        CUDA.name(CUDA.device()), N_GRID)
    println("  DDI_PADDED_DEFAULT (what every YAML run gets) = ",
        SpinorBEC.DDI_PADDED_DEFAULT)
    println()
    for (label, padded) in (("bare (ddi_padding=false, what bench/profile_rtp.jl builds)", false),
                            ("padded (ddi_padding=true, what run_yaml builds)", true))
        t, ok, reason = arm(padded)
        @printf("  %-58s %8.3f ms/step\n", label, t)
        @printf("      fused half-step taken: %-5s  %s\n", ok,
            reason === nothing ? "(eligible)" : reason)
    end
end

main()
