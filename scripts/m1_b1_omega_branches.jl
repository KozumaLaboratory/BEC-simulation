#!/usr/bin/env julia
# scripts/m1_b1_omega_branches.jl
#
# Two-diagnostic boundary characterisation of the B=1 Ω-slice. The Ω=0
# column showed gate-2 λ_min maps PHASES (gapped interior) vs BOUNDARIES
# (softening), BUT λ_min→0 catches only 2ND-order (continuous) boundaries.
# A 1ST-order boundary is a LEVEL CROSSING: both phases stay locally stable
# (λ_min GAPPED) and the GS type switches discontinuously where their
# energies cross. So boundary-mapping needs BOTH diagnostics:
#   (1) λ_min(Ω) per branch  — softening / dynamical instability (2nd order)
#   (2) competing-branch E(Ω) crossing  — Ω_thermo, the GS boundary (1st order)
# For a rotating BEC the two critical Ω usually differ: Ω_thermo (vortex
# energetically crosses vortex-free, GS changes) < Ω_dynamical (vortex-free
# mode softens, becomes unstable). λ_min(Ω) can pass Ω_thermo GAPPED.
#
# Method = branch CONTINUATION (the converged-neighbour bracket along Ω):
#   - vortex-free branch: GPU-warm a polar seed at Ω=0, Newton-CG-continue UP.
#   - vortex branch: GPU-warm a vortex seed at Ω_max, Newton-CG-continue DOWN.
# At each Ω: E, |∇E|, ⟨L_z⟩ (branch identity), and gate-2 λ_min ONLY when the
# branch CONVERGED (|∇E|<GATE_TOL → stationary → λ_min meaningful; never read
# λ_min off a non-stationary plateau — the thrice-made mistake).
# Newton-CG warm-start has no LBFGS history-loss pathology (rebuilds the
# Hessian each outer iter), so it is the clean continuation engine.

import CUDA
using SpinorBEC
using SpinorBEC: newton_cg_ground_state, trapped_bdg_lowest_eigenvalue,
    _tangent_project, energy_gradient!, orbital_angular_momentum, SpinSystem
using Printf
using LinearAlgebra
using Random

const TW = eu151_preset()
const B_NT = parse(Float64, get(ENV, "M1_B", "1.0"))
const OMEGAS = haskey(ENV, "M1_OMEGAS") ?
    parse.(Float64, split(ENV["M1_OMEGAS"], ",")) :
    [0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3]
const ITP = parse(Int, get(ENV, "M1_ITP", "2000"))
const LBFGS = parse(Int, get(ENV, "M1_LBFGS", "8000"))
const GATE_TOL = 1e-4        # report λ_min only below this (near-stationary)
const NOISE = 0.01

# (label, seed, direction). vortex-free marches UP from Ω_min; vortex DOWN
# from Ω_max — the hysteresis bracket that tracks both metastable branches
# through a level crossing.
const BRANCHES = [
    (:vortex_free, :polar, :up),
    (:vortex, :polar_core_vortex, :down),
]

function build_seed(seed::Symbol)
    sys = SpinSystem(TW.F)
    seed === :polar_core_vortex ?
        init_psi(TW.grid, sys; state=seed, init_vortex_charge=1) :
        init_psi(TW.grid, sys; state=seed)
end

zeeman_for(B_nT) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B_nT * TW.p_per_nT), ConstantWaveform(0.0),
)

function build_cpu_ws(Ω::Float64)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)
    make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B_NT), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CPUBackend(),    # import CUDA flips the default to GPU
    )
end

# GPU ITP+LBFGS to put the cold seed onto its branch at this Ω.
function warm_up_gpu(seed::Symbol, Ω::Float64)
    ψ0 = build_seed(seed)
    SpinorBEC.add_white_noise!(ψ0, NOISE, abs(round(Int, 1e6 * B_NT + 1e4 * Ω)), TW.grid)
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B_NT), potential=TW.potential, dt=0.005,
        n_steps=ITP, tol=1e-12, initial_state=:polar, verbose=false, psi_init=ψ0,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=Ω, backend=CUDABackend(),
    )
    r = find_ground_state_lbfgs(; ws_init=r_itp.workspace,
        n_steps=LBFGS, tol=1e-5, sobolev_alpha=0.05, verbose=false)
    Array(r.workspace.state.psi)
end

function track_branch(label, seed, dir)
    order = dir === :up ? OMEGAS : reverse(OMEGAS)
    @printf("\n── branch %s (seed %s, march %s) ──\n", label, seed, dir)
    ψ = warm_up_gpu(seed, order[1])
    rows = NamedTuple[]
    for Ω in order
        ws = build_cpu_ws(Ω)
        out = newton_cg_ground_state(ws, ψ;
            tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
        conv = out.grad_norm < GATE_TOL
        λ = conv ? trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=30)[1] : NaN
        Lz = orbital_angular_momentum(out.psi, ws.grid, ws.fft_plans)
        push!(rows, (; label, Ω, E=out.energy, gn=out.grad_norm, λ, Lz, conv))
        @printf("  Ω=%.2f  E=%.8g  |∇E|=%.2e  ⟨Lz⟩=%+.4f  λ_min=%-9s %s\n",
            Ω, out.energy, out.grad_norm, Lz,
            isnan(λ) ? "(soft)" : @sprintf("%.4f", λ),
            conv ? "GAPPED" : "soft/unconverged")
        flush(stdout)
        conv && (ψ = out.psi)   # continue only from a converged (stationary) state
    end
    rows
end

@printf("B=%.1f Ω-slice two-diagnostic boundary map — Ω∈%s, GPU warm-up ITP=%d LBFGS=%d\n",
    B_NT, OMEGAS, ITP, LBFGS)
all_rows = NamedTuple[]
for (label, seed, dir) in BRANCHES
    append!(all_rows, track_branch(label, seed, dir))
end

# ── boundary analysis: E-crossing (Ω_thermo) + λ_min→0 (Ω_dynamical) ──
println("\n", "="^66)
vf = sort([r for r in all_rows if r.label === :vortex_free]; by=r -> r.Ω)
vx = sort([r for r in all_rows if r.label === :vortex]; by=r -> r.Ω)
println("Ω      E(vortex_free)   E(vortex)      ΔE=Evx−Evf    λvf      λvx")
for Ω in sort(unique([r.Ω for r in all_rows]))
    rvf = findfirst(r -> r.Ω == Ω, vf)
    rvx = findfirst(r -> r.Ω == Ω, vx)
    evf = rvf === nothing ? NaN : vf[rvf].E
    evx = rvx === nothing ? NaN : vx[rvx].E
    lvf = rvf === nothing ? NaN : vf[rvf].λ
    lvx = rvx === nothing ? NaN : vx[rvx].λ
    @printf("%.2f   %13s   %13s   %+11s   %-8s %-8s\n", Ω,
        isnan(evf) ? "—" : @sprintf("%.6f", evf),
        isnan(evx) ? "—" : @sprintf("%.6f", evx),
        (isnan(evf) || isnan(evx)) ? "—" : @sprintf("%.2e", evx - evf),
        isnan(lvf) ? "soft" : @sprintf("%.3f", lvf),
        isnan(lvx) ? "soft" : @sprintf("%.3f", lvx))
end
println("\nReading: ΔE sign-flip ⇒ Ω_thermo (GS boundary, level crossing if both λ GAPPED there).")
println("         a branch's λ → 0 / 'soft' onset ⇒ that branch's Ω_dynamical (2nd-order softening).")
