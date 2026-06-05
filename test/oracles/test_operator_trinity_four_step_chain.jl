# test/oracles/test_operator_trinity_four_step_chain.jl
#
# The 4-step validation chain that the user-specified shipping gate
# requires for operator-trinity collapses. The per-term FD oracle
# (test_operator_trinity_per_term.jl) is the WEAKER ancestor: it
# checks FD-vs-hand at a single ε with a "1× or 2× factor" heuristic
# but does NOT verify (a) that the FD oracle itself is trustworthy
# (no ε-scaling), (b) Hermiticity of `apply_operator!`, or (c) that
# the oracle would actually catch a sign drift (no canary). All three
# are independent failure modes; this file closes them.
#
# Chain:
#   step0:  FD ε-scaling — verify FD itself is trustworthy by showing
#           |fd(ε) − fd(ε/10)| shrinks as ε decreases (O(ε²) for
#           centered FD). Without this, step1 could pass on an FD
#           value that's not actually converging.
#   step1:  FD vs hand-grad per term, REGISTRY-FUNCTORIAL (iterate
#           build_h_terms_registry(ws), NOT hand-rolled per term).
#           Same "1× or 2× factor" heuristic as the per-term test
#           (some mean-field terms have an extra 1/2 in energy that
#           cancels the FD factor 2).
#   step2:  Per-term Hermiticity — for random φ, ψ verify
#           ⟨φ|H|ψ⟩ = conj(⟨ψ|H|φ⟩) (Hermitian) OR
#           ⟨φ|H|ψ⟩ = −conj(⟨ψ|H|φ⟩) (anti-Hermitian; Loss).
#           Known-limit no-ops (Tensor/Raman/Loss with apply_operator=0)
#           trivially pass.
#   step3:  Canary — wrap each term with GradFlippedCanary (negates
#           apply_operator output) and verify step1 FAILS; wrap with
#           NonHermitianCanary (adds (0.05+0.1im)·ψ) and verify
#           step2 FAILS. Confirms the oracles are NOT tautologies.
#
# Per the user-mandated shipping gate, a collapse ships per-term only
# when all 4 steps are green for that term. This file is the auditor
# applied retroactively to the already-shipped collapse (the prior
# per-term test was weaker; this is the strong gate).
#
# All in seconds-tier.

using Test
using SpinorBEC
using SpinorBEC: HamTerm, apply_operator!, energy_contribution, add_gradient!,
    build_h_terms_registry, LossTerm
using LinearAlgebra
using Random

# ─── Tolerances ────────────────────────────────────────────────────────────

const STEP01_TOL = 1e-2          # ratio fd / (factor·hand) within ±tol of 1
const STEP02_REL_TOL = 1e-8      # |a - conj(b)| / max(|a|,|b|) < tol for Hermitian
const ε_LIST = (1e-3, 1e-4, 1e-5, 1e-6)
const NO_OP_THRESHOLD = 1e-12

# ─── Test workspace: as many terms simultaneously active as practical ──────

function _build_full_ws()
    F = 1
    grid = make_grid(GridConfig{3}((6, 6, 6), (4.0, 4.0, 4.0)))
    atom = Rb87
    ip = InteractionParams(Dict(0 => 0.5, 1 => 0.1); c_lhy=0.3)
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.2),   # bx — TransverseZeeman
        ConstantWaveform(0.15),  # by — TransverseZeeman
        ConstantWaveform(0.3),   # p  — LinearZeemanZ
        ConstantWaveform(0.05),  # q  — LinearZeemanZ
    )
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.2)  # Coriolis
    ws = make_workspace(;
        grid, atom, interactions=ip, zeeman=zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=true, c_dd=0.05, secular_ddi=true)
    psi = init_psi(grid, SpinSystem(F); state=:spin_coherent, init_theta=π / 4)
    dV = SpinorBEC.cell_volume(grid)
    psi ./= sqrt(sum(abs2, psi) * dV)
    return ws, psi
end

_termname(term) = string(typeof(term).name.name)

function _is_no_op(term::HamTerm, ws, psi)
    g = similar(psi)
    fill!(g, 0)
    apply_operator!(g, term, ws, psi)
    return sqrt(sum(abs2, g)) < NO_OP_THRESHOLD
end

# ─── step0 + step1: ε-scaling FD oracle + FD vs hand-grad ─────────────────

function check_fd_oracle(term::HamTerm, ws, psi, δ)
    dV = SpinorBEC.cell_volume(ws.grid)
    fds = [real((energy_contribution(term, psi .+ ε .* δ, ws) -
                 energy_contribution(term, psi .- ε .* δ, ws)) / (2ε))
           for ε in ε_LIST]

    # step0: ε-scaling. For centered FD with truncation O(ε²), |fd(ε) − true|
    # should DECREASE as ε → 0 (until FP noise floor). Successive differences
    # |fds[i] − fds[end]| should be monotone non-increasing (allowing equality
    # in FP noise regime).
    fd_finest = fds[end]
    diffs = [abs(fds[i] - fd_finest) for i in 1:length(fds)-1]
    step0_pass = true
    for i in 1:length(diffs)-1
        # Allow tie/decrease, OR finer ε having near-zero diff (FP-noise floor).
        if !(diffs[i] >= diffs[i+1] - 1e-14 || diffs[i+1] < 1e-12)
            step0_pass = false
            break
        end
    end

    # step1: ε=1e-5 FD vs hand. Per-existing-trinity-convention some terms
    # use factor 1×, others 2× — accept either.
    g = similar(psi)
    fill!(g, 0)
    apply_operator!(g, term, ws, psi)
    raw_dot = real(sum(conj.(g) .* δ)) * dV
    fd_choice = fds[3]  # ε=1e-5 is the sweet spot
    if abs(fd_choice) < 1e-12 && abs(raw_dot) < 1e-12
        return (step0_pass=true, step1_pass=true, fd=fd_choice,
            hand_1x=raw_dot, ratio_best=NaN, is_zero=true)
    end
    # ratios — if either matches 1, step1 passes
    ratio_1x = abs(raw_dot) > 1e-14 ? fd_choice / raw_dot : Inf
    ratio_2x = abs(raw_dot) > 1e-14 ? fd_choice / (2 * raw_dot) : Inf
    err_1x = abs(ratio_1x - 1)
    err_2x = abs(ratio_2x - 1)
    step1_pass = (err_1x < STEP01_TOL) || (err_2x < STEP01_TOL)
    return (; step0_pass, step1_pass, fd=fd_choice, hand_1x=raw_dot,
        ratio_best=min(err_1x, err_2x), is_zero=false)
end

# ─── step2: Hermiticity per term ──────────────────────────────────────────
#
# For any term, the operator should be either Hermitian (most) or
# anti-Hermitian (Loss). Known-limit no-ops trivially pass either.

function check_hermiticity(term::HamTerm, ws, φ, ψ)
    dV = SpinorBEC.cell_volume(ws.grid)
    Hψ = similar(ψ)
    fill!(Hψ, 0)
    apply_operator!(Hψ, term, ws, ψ)
    Hφ = similar(φ)
    fill!(Hφ, 0)
    apply_operator!(Hφ, term, ws, φ)
    a = sum(conj.(φ) .* Hψ) * dV   # ⟨φ|H|ψ⟩
    b = sum(conj.(ψ) .* Hφ) * dV   # ⟨ψ|H|φ⟩
    herm_resid = abs(a - conj(b))  # 0 ⇒ Hermitian
    anti_resid = abs(a + conj(b))  # 0 ⇒ anti-Hermitian
    nrm = max(abs(a), abs(b))
    if nrm < 1e-14
        return (; herm_resid, anti_resid, nrm, kind=:no_op)
    end
    kind = if herm_resid < STEP02_REL_TOL * nrm
        :hermitian
    elseif anti_resid < STEP02_REL_TOL * nrm
        :anti_hermitian
    else
        :non_hermitian
    end
    return (; herm_resid, anti_resid, nrm, kind)
end

# ─── step3: canary wrappers ────────────────────────────────────────────────
#
# GradFlippedCanary: negates apply_operator output → energy_contribution
# unchanged → FD ≠ hand. step1 should FAIL.
#
# NonHermitianCanary: adds (0.05 + 0.1im)·ψ to apply_operator output
# → non-Hermitian, non-anti-Hermitian → step2 should classify as
# :non_hermitian.

struct GradFlippedCanary{T <: HamTerm} <: HamTerm
    inner::T
end
SpinorBEC.apply_operator!(out, ft::GradFlippedCanary, ws, psi) = begin
    SpinorBEC.apply_operator!(out, ft.inner, ws, psi)
    out .*= -1
    return out
end
SpinorBEC.energy_contribution(ft::GradFlippedCanary, psi, ws) =
    SpinorBEC.energy_contribution(ft.inner, psi, ws)

struct NonHermitianCanary{T <: HamTerm} <: HamTerm
    inner::T
end
SpinorBEC.apply_operator!(out, p::NonHermitianCanary, ws, psi) = begin
    SpinorBEC.apply_operator!(out, p.inner, ws, psi)
    out .+= (0.05 + 0.1im) .* psi
    return out
end
SpinorBEC.energy_contribution(p::NonHermitianCanary, psi, ws) =
    SpinorBEC.energy_contribution(p.inner, psi, ws)

# ─── The chain ────────────────────────────────────────────────────────────

@testset "Operator-trinity 4-step chain (functorial over registry)" begin
    ws, psi = _build_full_ws()
    rng = MersenneTwister(2026)
    δ = randn(rng, ComplexF64, size(psi))
    # Random φ, ψ for Hermiticity — normalized so dot products are O(1).
    dV = SpinorBEC.cell_volume(ws.grid)
    φ = randn(rng, ComplexF64, size(psi))
    φ ./= sqrt(sum(abs2, φ) * dV)
    ψ_rand = randn(rng, ComplexF64, size(psi))
    ψ_rand ./= sqrt(sum(abs2, ψ_rand) * dV)

    registry = SpinorBEC.build_h_terms_registry(ws)
    no_ops = String[]
    active = String[]
    for term in registry
        tname = _termname(term)
        if _is_no_op(term, ws, psi)
            push!(no_ops, tname)
        else
            push!(active, tname)
        end
    end
    @info "Registry: $(length(registry)) terms" active no_ops

    @testset "step0+1: ε-scaling FD oracle + FD vs hand-grad" begin
        for term in registry
            tname = _termname(term)
            r = check_fd_oracle(term, ws, psi, δ)
            @testset "$tname" begin
                if r.is_zero
                    @test r.step0_pass
                    @test r.step1_pass  # both zero ⇒ trivially consistent
                else
                    @test r.step0_pass
                    @test r.step1_pass
                end
            end
        end
    end

    @testset "step2: Hermiticity (random φ, ψ)" begin
        for term in registry
            tname = _termname(term)
            r = check_hermiticity(term, ws, φ, ψ_rand)
            @testset "$tname" begin
                # Every term must be Hermitian, anti-Hermitian, or no-op.
                @test r.kind in (:hermitian, :anti_hermitian, :no_op)
            end
        end
    end

    @testset "step3 canary: GradFlipped MUST fail step1" begin
        for term in registry
            tname = _termname(term)
            if _is_no_op(term, ws, psi)
                @info "  $tname is no-op, GradFlipped canary moot — skipped"
                continue
            end
            @testset "$tname (grad-flipped)" begin
                canary = GradFlippedCanary(term)
                r = check_fd_oracle(canary, ws, psi, δ)
                # step1 MUST fail: FD positive, hand negative ⇒ ratio = -1 or -0.5
                @test !r.step1_pass
            end
        end
    end

    @testset "step3 canary: NonHermitian MUST be classified :non_hermitian" begin
        for term in registry
            tname = _termname(term)
            @testset "$tname (non-Hermitian-perturbed)" begin
                canary = NonHermitianCanary(term)
                r = check_hermiticity(canary, ws, φ, ψ_rand)
                @test r.kind === :non_hermitian
            end
        end
    end
end
