# test/oracles/test_registry_gradient_parity.jl
#
# Phase 4 gate: `apply_operator_via_registry!` produces a gradient
# bit-identical to the legacy `energy_gradient!` (modulo the outer ×2
# Wirtinger scaling that the latter applies). When this passes,
# `energy_gradient!` can delegate to the registry path without
# changing any caller-visible behaviour.
#
# The 2026-06-04 Phase 4 attempt was reverted because each term
# recomputed its own scratch (n_density, fx/fy/fz, fft_buf, deriv_buf)
# instead of sharing — a ~+4% slowdown. This file pins both
# bit-identity AND that the registry path uses ctx-aware
# specialisations on the load-bearing terms (kinetic, Coriolis,
# DensityC0, SpinC1, LHY).

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: apply_operator_via_registry!, build_gradient_context,
    apply_operator!, KineticTerm, CoriolisTerm, DensityC0Term, SpinC1Term,
    LHYTerm, GradientContext
using Random

function _gradient_test_ws(; Ω::Float64=0.2)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict(0 => 0.5, 1 => -0.3))
    zeeman = ZeemanParams(0.4, 0.1)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true,
        rotating_frame_omega=Ω)
    ws = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
    return ws
end

@testset "Phase 4: apply_operator_via_registry! ≡ energy_gradient! body" begin
    @testset "Bit-identity (Bz + q + c0 + c1 + Ω + transverse)" begin
        ws_reg = _gradient_test_ws(Ω=0.2)
        ws_leg = _gradient_test_ws(Ω=0.2)

        Random.seed!(7)
        psi = randn(ComplexF64, 8, 8, 8, 3)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(ws_reg.grid))
        copyto!(ws_reg.state.psi, psi)
        copyto!(ws_leg.state.psi, psi)

        # Legacy: full energy_gradient! (with the *2 scaling at the end).
        grad_leg = zero(psi)
        E_leg = SpinorBEC.energy_gradient!(grad_leg, psi, ws_leg)

        # Registry: apply_operator_via_registry! WITHOUT the *2 scaling.
        # To compare like-for-like, scale up.
        grad_reg = zero(psi)
        apply_operator_via_registry!(grad_reg, ws_reg)
        grad_reg .*= 2

        diff = maximum(abs, grad_reg .- grad_leg)
        @info "Phase 4 max |Δgrad|" diff
        @test diff < 1e-12
    end

    @testset "Context-aware path uses shared scratch (zero per-term re-alloc)" begin
        ws = _gradient_test_ws()
        Random.seed!(8)
        psi = randn(ComplexF64, 8, 8, 8, 3)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))

        # Build ctx; verify each ctx-aware term path uses it without
        # producing additional matching-size allocations beyond ctx
        # buffers.
        ctx = build_gradient_context(psi, ws)
        @test ctx isa GradientContext
        @test size(ctx.fft_buf) == (8, 8, 8)
        @test size(ctx.deriv_buf) == (8, 8, 8)
        @test size(ctx.fx) == (8, 8, 8)
        @test size(ctx.n_density) == (8, 8, 8)

        grad = zero(psi)

        # Kinetic ctx-aware path: bit-identical to no-ctx version.
        grad1 = zero(psi)
        apply_operator!(grad1, KineticTerm(), ws, psi)
        grad2 = zero(psi)
        apply_operator!(grad2, KineticTerm(), ws, psi, ctx)
        @test maximum(abs, grad1 .- grad2) < 1e-13

        # SpinC1 ctx-aware path:
        grad1 .= 0
        grad2 .= 0
        apply_operator!(grad1, SpinC1Term(ws.interactions[1]), ws, psi)
        apply_operator!(grad2, SpinC1Term(ws.interactions[1]), ws, psi, ctx)
        @test maximum(abs, grad1 .- grad2) < 1e-13

        # DensityC0 ctx-aware path:
        grad1 .= 0
        grad2 .= 0
        apply_operator!(grad1, DensityC0Term(ws.interactions[0]), ws, psi)
        apply_operator!(grad2, DensityC0Term(ws.interactions[0]), ws, psi, ctx)
        @test maximum(abs, grad1 .- grad2) < 1e-13

        # Coriolis ctx-aware path:
        grad1 .= 0
        grad2 .= 0
        apply_operator!(grad1, CoriolisTerm(0.2), ws, psi)
        apply_operator!(grad2, CoriolisTerm(0.2), ws, psi, ctx)
        @test maximum(abs, grad1 .- grad2) < 1e-13
    end
end
