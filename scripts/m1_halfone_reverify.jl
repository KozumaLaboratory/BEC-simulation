#!/usr/bin/env julia
# scripts/m1_halfone_reverify.jl
#
# Re-verify half-1's gate-2 (minimum-vs-saddle) on Newton-CG-POLISHED
# stationary points. The original half-1 gate-2 ran on LBFGS ψ (~1e-5,
# non-stationary / save-bug-degraded) — the same contamination that made
# the phantom "B=5 λ dip to 0.72" (polish → 1.36). gate-2 λ is valid ONLY
# at a true stationary point; the contamination shifts λ and its sign is
# NOT universal (the 2 observed cells dropped, but an upward shift could
# disguise a saddle as a minimum). So: polish each Ω=0 cell with Newton-CG,
# then gate-2, and confirm λ_min > 0 everywhere ("verdict robust ≠ safe").
#
# Phase labels (gate-1) and ⟨Lz⟩=0 are independent of gate-2-λ and stand;
# only the stability verdict is re-verified here.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, trapped_bdg_lowest_eigenvalue,
    energy_gradient!, _tangent_project
using JLD2
using Printf
using LinearAlgebra

const TW = eu151_preset()
const DIR = "runs/sprint5_M1_multistart_groundstate"
const BS = haskey(ENV, "M1_BS") ?
    parse.(Float64, split(ENV["M1_BS"], ",")) :
    [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]

zeeman_for(B) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B * TW.p_per_nT), ConstantWaveform(0.0),
)

function build_cpu_ws(B)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.0)
    make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false, backend=CPUBackend(),
    )
end

load_psi(B) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B)), "psi")

function projgrad(ws, ψ)
    dV = SpinorBEC.cell_volume(ws.grid)
    g = similar(ψ); fill!(g, 0); energy_gradient!(g, ψ, ws)
    gp = _tangent_project(g, ψ, dV, real(sum(abs2, ψ)) * dV)
    sqrt(real(sum(conj.(gp) .* gp)) * dV)
end

@printf("half-1 gate-2 re-verify on Newton-CG-polished stationary points (Ω=0)\n\n")
@printf("%-6s %11s %9s   %11s %9s %9s   %s\n",
    "B[nT]", "|∇E|_raw", "λ_raw", "|∇E|_pol", "λ_pol", "Δλ", "verdict")
println("-"^78)
worst = Inf
for B in BS
    ψ0 = load_psi(B)
    ws = build_cpu_ws(B)
    gn_raw = projgrad(ws, ψ0)
    λ_raw, _ = trapped_bdg_lowest_eigenvalue(ws, ψ0; niter=30)        # contaminated
    out = newton_cg_ground_state(ws, ψ0;
        tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
    λ_pol, _ = trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=30)   # true stationary
    global worst = min(worst, λ_pol)
    verdict = out.grad_norm < 1e-4 ?
        (λ_pol > -1e-3 ? "MINIMUM" : "SADDLE") : "polish-incomplete"
    @printf("%-6.1f %11.2e %9.4f   %11.2e %9.4f %+9.4f   %s\n",
        B, gn_raw, λ_raw, out.grad_norm, λ_pol, λ_pol - λ_raw, verdict)
    flush(stdout)
end
println("-"^78)
@printf("min polished λ across all cells = %.4f  ⇒  half-1 %s\n",
    worst, worst > -1e-3 ? "GATED (all minima)" : "NOT fully gated — inspect")
