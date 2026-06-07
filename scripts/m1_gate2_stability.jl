#!/usr/bin/env julia
# scripts/m1_gate2_stability.jl
#
# Gate (2) of the M1 phase-verdict: minimum-vs-saddle for the converged
# Ω=0 cells, via the now-ANCHORED FD-Hessian (test_bdg_fd_hessian:
# FD of the gated gradient ≡ the hand-built BdG, both blocks). The cell
# "stability" field was left "ambiguous" by the sweep; this is the gate.
#
# Constrained energetic stability: ψ0 minimises E at fixed N ⟺ the
# constrained Hessian (H_E − 2μ) is ≥ 0 on the tangent ⊥_complex ψ0
# (the complex projection removes the norm AND phase gauge modes; the
# −2μ is the norm-constraint shift, μ = Re⟨ψ0,g⟩/(2‖ψ0‖²) since
# g = 2·δE/δψ̄ = 2μψ0 at the GS). Lowest eigenvalue via hand-rolled
# fully-reorthogonalised Lanczos on the HvP (no KrylovKit in deps);
# λ_min ≥ −tol ⇒ minimum, < −tol ⇒ saddle.
#
# Method validation (printed, before any verdict — point-3 discipline):
#  - phase mode: H·(iψ0) = 2μ·(iψ0) (E phase-invariance makes the phase
#    Goldstone the 2μ eigenvector of the RAW H — zeroed by H−2μ and
#    removed by the complex projection). ‖H·iψ0‖/‖iψ0‖ ≈ 2μ calibrates
#    the HvP convention.
#  - μ residual: ‖g − 2μψ0‖/‖g‖ = the cell's ‖∇E‖ (confirms g∥ψ0).
#
# Cost: ~2 grad evals / Lanczos iter; ~niter·2·(5-10s) per cell.

using SpinorBEC
using SpinorBEC: energy_gradient!
using JLD2
using Printf
using LinearAlgebra

const DIR = "runs/sprint5_M1_multistart_groundstate"
const TW = eu151_preset()
const ε = 1e-5
const NITER = parse(Int, get(ENV, "M1_NITER", "24"))

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

_ipR(a, b, dV) = real(sum(conj.(a) .* b)) * dV
_grad(ws, ψ) = (g=similar(ψ); fill!(g, 0); energy_gradient!(g, ψ, ws); g)
_hvp(ws, ψ0, δ) = (_grad(ws, ψ0 .+ ε .* δ) .- _grad(ws, ψ0 .- ε .* δ)) ./ (2ε)

function gate2_cell(B_nT, Ω; validate=false)
    f = joinpath(DIR, @sprintf("cell_B%.1f_Om%.2f.jld2", B_nT, Ω))
    ψ0 = JLD2.load(f, "psi")
    ws = build_cpu_ws(B_nT, Ω)
    dV = SpinorBEC.cell_volume(TW.grid)
    n2 = _ipR(ψ0, ψ0, dV)
    g0 = _grad(ws, ψ0)
    μ = _ipR(ψ0, g0, dV) / (2 * n2)             # g = 2μψ0 at the GS

    if validate
        Hiψ = _hvp(ws, ψ0, im .* ψ0)
        rng_v = randn(ComplexF64, size(ψ0))
        Hrnd = _hvp(ws, ψ0, rng_v)
        rphase = sqrt(_ipR(Hiψ, Hiψ, dV)) / sqrt(_ipR(im .* ψ0, im .* ψ0, dV))
        rrand = sqrt(_ipR(Hrnd, Hrnd, dV)) / sqrt(_ipR(rng_v, rng_v, dV))
        gres = sqrt(_ipR(g0 .- 2μ .* ψ0, g0 .- 2μ .* ψ0, dV)) /
               sqrt(_ipR(g0, g0, dV))
        @printf(
            "  VALIDATE B=%.1f Ω=%.2f: μ=%.4f  ‖H·iψ0‖/‖iψ0‖=%.3f≈2μ=%.3f (phase=2μ eigvec, zeroed by H−2μ; ‖H·rnd‖=%.1f)  ‖g−2μψ0‖/‖g‖=%.2e\n",
            B_nT, Ω, μ, rphase, 2μ, rrand, gres)
    end

    proj(δ) = δ .- ψ0 .* (sum(conj.(ψ0) .* δ) * dV / n2)
    Hc(δ) = (pδ=proj(δ); proj(_hvp(ws, ψ0, pδ) .- 2μ .* pδ))

    # fully-reorthogonalised Lanczos in the real inner product
    V = Vector{typeof(ψ0)}()
    v = proj(randn(ComplexF64, size(ψ0)))
    v ./= sqrt(_ipR(v, v, dV))
    push!(V, v)
    α = Float64[]
    β = Float64[]
    for j in 1:NITER
        w = Hc(V[end])
        αj = _ipR(V[end], w, dV)
        push!(α, αj)
        for u in V                              # full reorth
            w = w .- u .* (_ipR(u, w, dV))
        end
        βj = sqrt(_ipR(w, w, dV))
        βj < 1e-10 && break
        push!(β, βj)
        push!(V, w ./ βj)
    end
    T = SymTridiagonal(α, β[1:(length(α) - 1)])
    λ = eigvals(T)
    minimum(λ), μ
end

function main()
    af = JLD2.load(joinpath(DIR, "groundstate_audit.jld2"), "rows")
    # default: the Ω=0 column (the static phase diagram). M1_CLASS lets the
    # diagnostic also target the converged Ω>0 corner (converged_single) to
    # read λ_min(Ω) across the convergence boundary — physical-vs-numerical.
    wanted = if haskey(ENV, "M1_CLASS")
        Tuple(Symbol.(split(ENV["M1_CLASS"], ",")))
    else
        (:GS_confident, :goldstone)
    end
    converged = [r for r in af if r.cls in wanted]
    haskey(ENV, "M1_CLASS") || (converged = [r for r in converged if r.Ω == 0.0])
    if haskey(ENV, "M1_CELLS")
        keep = parse.(Float64, split(ENV["M1_CELLS"], ","))
        converged = [r for r in converged if r.B in keep]
    end
    sort!(converged; by=x -> (x.B, x.Ω))
    @printf("Gate (2) minimum-vs-saddle — %d converged Ω=0 cells, Lanczos niter=%d\n\n",
        length(converged), NITER)
    first_done = false
    @printf(
        "%-7s %-6s %-20s %12s %12s   %s\n", "B[nT]", "Ω", "winner", "λ_min", "λ_min/|E|", "verdict"
    )
    println("-"^74)
    for r in converged
        λmin, μ = gate2_cell(r.B, r.Ω; validate=(!first_done))
        first_done = true
        tol = 1e-3 * max(abs(r.winnerE), 1.0)
        verdict = λmin > -tol ? "MINIMUM" : "SADDLE"
        @printf("%-7.1f %-6.2f %-20s %12.5f %12.2e   %s\n",
            r.B, r.Ω, r.winner, λmin, λmin / max(abs(r.winnerE), 1.0), verdict)
    end
end

main()
