#!/usr/bin/env julia
# scripts/m1_lanczos_niter_convergence.jl
#
# CRITICAL check: is the gate-2 Lanczos λ_min CONVERGED in niter? The same
# B=5 cell gave λ_min = 7.6 (niter=12), 1.35 (niter=30), 0.72 (niter=40) —
# a monotone drop, suggesting the 40-dim Krylov subspace does NOT resolve
# the smallest eigenvalue of the ~110k-dim (24³×13) constrained Hessian.
# If λ_min keeps dropping with niter, every λ MAGNITUDE I reported (the
# "B=5 dip", boundary softening, quantitative gate-2) is under-converged
# and unreliable — only the SIGN (minimum, corroborated by Newton-CG
# quadratic convergence) stands. Fixed rng isolates pure niter-convergence.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, trapped_bdg_lowest_eigenvalue
using JLD2
using Printf
using LinearAlgebra
using Random

const TW = eu151_preset()
const DIR = "runs/sprint5_M1_multistart_groundstate"
const BS = haskey(ENV, "M1_BS") ? parse.(Float64, split(ENV["M1_BS"], ",")) : [5.0, 0.0]
const NITERS = [30, 50, 80, 120, 200]

zeeman_for(B) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B * TW.p_per_nT), ConstantWaveform(0.0),
)
function build_cpu_ws(B)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.0)
    make_workspace(; grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false, backend=CPUBackend())
end
load_psi(B) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B)), "psi")

@printf("Lanczos λ_min niter-convergence (fixed rng), polished stationary points\n\n")
for B in BS
    ws = build_cpu_ws(B)
    out = newton_cg_ground_state(ws, load_psi(B);
        tol=1e-8, max_outer=60, max_cg=20, sobolev_alpha=0.04, verbose=false)
    @printf("B=%.1f (polished |∇E|=%.2e):\n", B, out.grad_norm)
    prev = NaN
    for nit in NITERS
        λ, _ = trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=nit, rng=MersenneTwister(1))
        @printf("   niter=%-4d  λ_min=%.5f   Δ_from_prev=%s\n",
            nit, λ, isnan(prev) ? "—" : @sprintf("%+.5f", λ - prev))
        prev = λ
        flush(stdout)
    end
    println()
end
println("Read: λ_min flattening (small Δ) ⇒ converged, magnitude trustworthy.")
println("      still dropping ⇒ dense low spectrum; only the SIGN is reliable.")
