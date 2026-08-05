# dt-convergence order of `split_step!` on the shape production actually runs.
#
#   LD_LIBRARY_PATH=... julia --project=. bench/rtp_order_padded.jl [N] [steps]
#
# `bench/conv_order.jl` measures the same property on the CPU, at N=12, with an
# UNPADDED DDI, and by calling the half-potential helpers directly. None of that
# is what `run_yaml` runs: since `DDI_PADDED_DEFAULT` flipped to `true`
# (9c117c05) production is GPU + zero-padded + `split_step!`, and once the fused
# V half-step stopped declining a padded DDI it is also the fused kernel. Order
# had never been measured on that combination.
#
# Self-convergence, so no reference solution is needed and no other integrator is
# trusted: with e(h) = ‖ψ_h − ψ_{h/2}‖ at a common final time,
#
#     order ≈ log2( e(h) / e(h/2) )
#
# Strang ⇒ 2. The mean field is what puts that at risk — evaluated at each
# substep's entry it collapses to ~1 with DDI on, which is why the midpoint
# predictor-corrector exists — so this is the measurement that would catch a
# fused half-step that had quietly become a different splitting.

import CUDA
using SpinorBEC
using Printf
using LinearAlgebra: norm
include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const N_COARSE = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 64
const DT0 = 2.0e-4
const T_FINAL = DT0 * N_COARSE

function run_to_T(dt::Float64; n::Int=N_GRID, padded::Bool, fused::Bool)
    old = SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[]
    SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = fused
    try
        grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 10.0, 3)))
        nsteps = round(Int, T_FINAL / dt)
        sp = SimParams(; dt, n_steps=nsteps, imaginary_time=false, save_every=10^9)
        ws = make_workspace(;
            grid, atom=Eu151, interactions=eu_interaction_params(0.05),
            zeeman=ZeemanParams(EU_p_weak, 0.0),
            potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
            sim_params=sp, enable_ddi=true, c_dd=EU_c_dd,
            ddi_padding=padded, backend=CUDABackend(),
        )
        # Tilted spin-coherent: ⟨F⟩ has all three components non-zero, so the
        # spin-mixing and DDI rotations are both genuinely exercised.
        psi = init_psi(grid, ws.spin_matrices.system;
            state=:spin_coherent, init_theta=0.6, init_phi=0.4)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
        copyto!(ws.state.psi, psi)
        for _ in 1:nsteps
            SpinorBEC.split_step!(ws)
        end
        CUDA.synchronize()
        out = Array(ws.state.psi)
        ws = nothing
        GC.gc(true)
        CUDA.reclaim()
        return out
    finally
        SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = old
    end
end

function order_table(; padded::Bool, fused::Bool)
    @printf("\n  DDI %s, fused half-step %s   (T = %.4g, %d³)\n",
        padded ? "zero-padded (production)" : "bare", fused ? "ON" : "OFF",
        T_FINAL, N_GRID)
    dts = [DT0 / 2^k for k in 0:3]
    psis = [run_to_T(dt; padded, fused) for dt in dts]
    errs = [norm(psis[i] - psis[i + 1]) for i in 1:(length(psis) - 1)]
    @printf("  %10s %14s %8s\n", "dt", "‖ψ_h−ψ_h/2‖", "order")
    for i in eachindex(errs)
        o = i < length(errs) ? log2(errs[i] / errs[i + 1]) : NaN
        if isnan(o)
            @printf("  %10.3e %14.6e %8s\n", dts[i], errs[i], "—")
        else
            @printf("  %10.3e %14.6e %8.3f\n", dts[i], errs[i], o)
        end
    end
    psis
end

function main()
    @printf("RTP dt-order — %s, Eu151 F=6 (D=13) F64\n", CUDA.name(CUDA.device()))
    println("  DDI_PADDED_DEFAULT = ", SpinorBEC.DDI_PADDED_DEFAULT,
        "   (what every run_yaml run gets)")

    a = order_table(; padded=true, fused=true)
    b = order_table(; padded=true, fused=false)

    # The fused and unfused arms claim to be the same splitting, so they must
    # agree bit for bit at every dt — not merely converge to the same order.
    # An order table alone cannot tell those apart.
    same = all(a[i] == b[i] for i in eachindex(a))
    @printf("\n  fused ≡ unfused at every dt, bit for bit: %s\n", same)

    order_table(; padded=false, fused=true)
end

main()
