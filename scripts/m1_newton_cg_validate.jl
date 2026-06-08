#!/usr/bin/env julia
# scripts/m1_newton_cg_validate.jl
#
# Validates the trust-region Newton-CG refiner on the M1 sweep, per the
# three honest checks (Newton-CG is a convergence engine, NOT a gate):
#
#  A. Ω=0 REGRESSION (fidelity): on already-gated Ω=0 cells, Newton-CG
#     must NOT wander — it should stay at the same minimum (fidelity ≈ 1)
#     and keep |∇E| low. Judged by STATE FIDELITY, not |∇E| (Newton-CG can
#     land on a different stationary point; fidelity catches that).
#
#  B. Ω>0 BREAKTHROUGH: on cells LBFGS left at the conditioning floor
#     (:unconverged), does the second-order step push |∇E| below 1e-5 where
#     the first-order method plateaued?
#
#  C. gate-2 on a CONVERGED Ω>0 cell: minimum vs saddle of the
#     Newton-CG-refined state via the SAME constrained operator.
#
# The inner operator is `constrained_hessian_action` — identical to the
# gate-2 operator (shared single source). CPU; GPU verification is a
# follow-on.

using SpinorBEC
using SpinorBEC: energy_gradient!, trapped_bdg_lowest_eigenvalue,
    newton_cg_ground_state, constrained_hessian_params, _tangent_project
using JLD2
using Printf
using LinearAlgebra

const DIR = "runs/sprint5_M1_multistart_groundstate"
const TW = eu151_preset()
const ε = 1e-5
const MAXOUTER = parse(Int, get(ENV, "M1_NCG_MAXOUTER", "20"))
const MAXCG = parse(Int, get(ENV, "M1_NCG_MAXCG", "15"))
const ALPHA = parse(Float64, get(ENV, "M1_NCG_ALPHA", "0.04"))

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
    )
end

load_psi(B, Ω) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om%.2f.jld2", B, Ω)), "psi")

function projgrad(ws, ψ)
    dV = SpinorBEC.cell_volume(ws.grid)
    g = similar(ψ); fill!(g, 0); energy_gradient!(g, ψ, ws)
    gp = _tangent_project(g, ψ, dV, real(sum(abs2, ψ)) * dV)
    sqrt(real(sum(conj.(gp) .* gp)) * dV)
end

function run_cell(B, Ω, role)
    dV = SpinorBEC.cell_volume(TW.grid)
    ψ0 = load_psi(B, Ω)
    n2 = real(sum(abs2, ψ0)) * dV
    ws = build_cpu_ws(B, Ω)
    gn0 = projgrad(ws, ψ0)
    out = newton_cg_ground_state(ws, ψ0;
        tol=1e-7, max_outer=MAXOUTER, max_cg=MAXCG, sobolev_alpha=ALPHA, verbose=false)
    fid = abs(sum(conj.(ψ0) .* out.psi)) * dV / n2
    λ = NaN
    if role == :gate2 || role == :regression
        λ, _ = trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=24, ε)
    end
    (; B, Ω, role, gn0, gn1=out.grad_norm, conv=out.converged,
        iters=out.iterations, fid, λ, E=out.energy)
end

# (B, Ω, role)
const CELLS = if haskey(ENV, "M1_NCG_CELLS")
    # "5.0:0.0:regression,1.0:0.1:breakthrough"
    [(parse(Float64, p[1]), parse(Float64, p[2]), Symbol(p[3]))
     for p in split.(split(ENV["M1_NCG_CELLS"], ","), ":")]
else
    [(5.0, 0.0, :regression), (100.0, 0.0, :regression),
        (1.0, 0.1, :breakthrough), (10.0, 0.1, :breakthrough),
        (100.0, 0.6, :gate2)]
end

@printf("Newton-CG validation — max_outer=%d max_cg=%d α=%.3g\n\n", MAXOUTER, MAXCG, ALPHA)
@printf("%-6s %-5s %-13s %11s %11s %5s %5s %9s %11s\n",
    "B", "Ω", "role", "|∇E|_in", "|∇E|_out", "conv", "it", "fidelity", "λ_min(gate2)")
println("-"^86)
for (B, Ω, role) in CELLS
    t = @elapsed r = run_cell(B, Ω, role)
    @printf("%-6.1f %-5.2f %-13s %11.3e %11.3e %5s %5d %9.5f %11s  (%.0fs)\n",
        r.B, r.Ω, String(r.role), r.gn0, r.gn1, r.conv, r.iters, r.fid,
        isnan(r.λ) ? "—" : @sprintf("%.4f", r.λ), t)
    flush(stdout)
end
