#!/usr/bin/env julia
# scripts/m1_b1_multistart_newton.jl
#
# Globalisation test for the B=1 Ω=0.1 stall. The Newton-CG validation
# (m1_newton_cg_validate.jl) showed this cell stalls at |∇E|≈1.5e-2 from
# the LBFGS-saved ψ, BUT its local curvature is GAPPED (gate-2 λ=2.44) —
# so the pathology is multi-basin / globalisation, not local conditioning.
#
# Hypothesis: from a GOOD starting basin Newton-CG reaches a gated minimum.
# Test: run Newton-CG DIRECTLY from several diverse cold seeds (it handles
# far-from-stationary starts — validation drove |∇E|=0.46→4e-7). Then:
#   - if the converged seeds AGREE on energy → single well-defined GS, the
#     LBFGS-saved ψ was just a bad basin (globalisation solved by multi-start).
#   - if they SCATTER to distinct gated minima → genuine near-degeneracy at
#     weak field (physical multi-basin) — a real finding, not a tool failure.
# Each survivor is gated by gate-2 (minimum vs saddle) — Newton-CG is a
# convergence engine, not a gate.
#
# CPU (Newton-CG GPU path is a follow-on). Seeds: TIER1 + polar, the
# seeds_for_cell(1.0, 0.1) set from sprint5_M1_multistart_groundstate.jl.

import CUDA
using SpinorBEC
using SpinorBEC: energy_gradient!, newton_cg_ground_state,
    trapped_bdg_lowest_eigenvalue, _tangent_project, SpinSystem
using JLD2
using Printf
using LinearAlgebra
using Random

const TW = eu151_preset()
const ε = 1e-5
const B_NT = parse(Float64, get(ENV, "M1_B", "1.0"))
const OMEGA = parse(Float64, get(ENV, "M1_OMEGA", "0.1"))
const MAXOUTER = parse(Int, get(ENV, "M1_NCG_MAXOUTER", "60"))
const MAXCG = parse(Int, get(ENV, "M1_NCG_MAXCG", "20"))
const ITP = parse(Int, get(ENV, "M1_ITP", "2000"))      # GPU ITP warm-up
const LBFGS = parse(Int, get(ENV, "M1_LBFGS", "4000"))  # GPU LBFGS warm-up
const NOISE = 0.01

const SEEDS = haskey(ENV, "M1_SEEDS") ?
    Symbol.(split(ENV["M1_SEEDS"], ",")) :
    [:polar_core_vortex, :fl_vortex, :antiferromagnetic,
        :chiral_spin_vortex, :skyrmion_lattice, :polar]

function build_seed(seed::Symbol, grid)
    sys = SpinSystem(TW.F)
    vortex = (:polar_core_vortex, :fl_vortex, :chiral_spin_vortex)
    seed in vortex ?
        init_psi(grid, sys; state=seed, init_vortex_charge=1) :
        init_psi(grid, sys; state=seed)
end

function build_cpu_ws(B_nT::Float64, Ω::Float64)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=Ω)
    make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman, potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CPUBackend(),   # explicit: import CUDA flips the default to GPU
    )
end

function projgrad(ws, ψ)
    dV = SpinorBEC.cell_volume(ws.grid)
    g = similar(ψ); fill!(g, 0); energy_gradient!(g, ψ, ws)
    gp = _tangent_project(g, ψ, dV, real(sum(abs2, ψ)) * dV)
    sqrt(real(sum(conj.(gp) .* gp)) * dV)
end

# GPU ITP+LBFGS warm-up to settle the seed into its basin (cold-direct
# Newton-CG stalls — a textured seed at |∇E|~100 is too far for the
# FD-HvP trust region). Then bring ψ to CPU for Newton-CG + gate-2.
function warm_up_gpu(seed)
    ψ0 = build_seed(seed, TW.grid)
    SpinorBEC.add_white_noise!(ψ0, NOISE, abs(round(Int, 1e6 * B_NT + 1e4 * OMEGA)), TW.grid)
    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman, potential=TW.potential, dt=0.005, n_steps=ITP, tol=1e-12,
        initial_state=:polar, verbose=false, psi_init=ψ0,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=CUDABackend(),
    )
    r = find_ground_state_lbfgs(; ws_init=r_itp.workspace,
        n_steps=LBFGS, tol=1e-5, sobolev_alpha=0.05, verbose=false)
    Array(r.workspace.state.psi), r.grad_norm
end

function run_seed(seed)
    ψ_warm, gn_warm = warm_up_gpu(seed)
    ws = build_cpu_ws(B_NT, OMEGA)             # CPU ws for Newton-CG + gate-2
    out = newton_cg_ground_state(ws, ψ_warm;
        tol=1e-7, max_outer=MAXOUTER, max_cg=MAXCG, sobolev_alpha=0.04, verbose=false)
    gated = out.grad_norm < 1e-5
    # λ_min always: rigorous only when gated (stationary); otherwise a HINT —
    # a near-zero λ at a non-converged plateau flags a soft/flat valley.
    λ = trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=30, ε)[1]
    (; seed, gn0=gn_warm, gn1=out.grad_norm, E=out.energy, gated, λ, psi=out.psi)
end

@printf("Multi-start Newton-CG globalisation test — B=%.1f Ω=%.2f, %d seeds, GPU warm-up ITP=%d LBFGS=%d\n\n",
    B_NT, OMEGA, length(SEEDS), ITP, LBFGS)
@printf("%-20s %11s %11s %14s %7s %11s\n",
    "seed", "|∇E|_in", "|∇E|_out", "E", "gated", "λ_min")
println("-"^80)
results = NamedTuple[]
for s in SEEDS
    t = @elapsed r = run_seed(s)
    push!(results, r)
    @printf("%-20s %11.3e %11.3e %14.8g %7s %11s  (%.0fs)\n",
        String(r.seed), r.gn0, r.gn1, r.E, r.gated,
        isnan(r.λ) ? "—" : @sprintf("%.4f", r.λ), t)
    flush(stdout)
end

# cross-seed verdict among gated minima
gated = [r for r in results if r.gated && r.λ > -1e-3]
println("\n", "="^60)
if isempty(gated)
    println("No gated minimum found — none of the seeds converged + passed gate-2.")
else
    Es = [r.E for r in gated]
    Emin, imin = findmin(Es)
    spread = maximum(Es) - minimum(Es)
    winner = gated[imin]
    @printf("gated minima: %d/%d seeds | E-spread = %.3e | winner: %s (E=%.8g, λ=%.4f)\n",
        length(gated), length(SEEDS), spread, String(winner.seed), winner.E, winner.λ)
    if spread < 1e-3
        println("→ seeds AGREE (spread < 1e-3): single well-defined GS; the LBFGS-saved")
        println("  ψ was a bad basin. Globalisation solved by multi-start + Newton-CG.")
    else
        println("→ seeds SCATTER: genuine multi-basin / near-degeneracy at weak field.")
        println("  Distinct gated minima — a physical finding (each gate-2-confirmed).")
        for r in gated
            @printf("    %-20s E=%.8g  λ=%.4f\n", String(r.seed), r.E, r.λ)
        end
    end
end
