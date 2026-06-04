# test/oracles/test_magnetic_gradient_gap.jl
#
# Closes [GAP-2] of the systematic Hamiltonian audit: MagneticGradient
# was silently dropped from `energy_decomposition` and `energy_gradient!`
# because the propagator folds ΔV = g_F·grad·x into V_trap during
# `_apply_mg_to_V!` and immediately reverses it via
# `_remove_mg_from_V!`, leaving ws.potential_values clean between
# split_step calls. The legacy energy / gradient routines only read the
# clean V_trap, so they saw no MG.
#
# Post-fix (2026-06-04): MagneticGradientTerm is a first-class HamTerm
# whose `energy_contribution` and `add_gradient!` compute the same
# integral that the propagator implements. This test pins:
#
#   1. Propagator ↔ HamTerm bit-identity for ITP / RT single step.
#   2. Energy ↔ gradient FD consistency (catches sign-flip regressions).
#   3. Directional sign oracle (post-ITP cloud shift direction).
#   4. Registry breakdown now includes a non-zero MG slot when active.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: MagneticGradientTerm, apply_step!, energy_contribution,
    add_gradient!, sign_oracle, build_h_terms_registry,
    energy_breakdown_via_registry
using Random

# Reference 1D workspace with a magnetic_gradient field active.
function _mg_workspace(grad::Float64=0.5; axis::Int=1, g_F::Float64=1.0,
    n::Int=16, L::Float64=8.0)
    grid = make_grid(GridConfig((n,), (L,)))
    interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    zeeman = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0,)),
        magnetic_gradient=MagneticGradient{1}(grad, axis, g_F),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
    return ws
end

function _normalize!(psi, grid)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    return psi
end

@testset "[GAP-2] MagneticGradientTerm closes the audit" begin
    @testset "Propagator ↔ HamTerm bit-identity (ITP single step)" begin
        # Build two identical workspaces: one drives the legacy propagator
        # (apply_mg_to_V! + diagonal step), one drives the HamTerm.
        ws_leg = _mg_workspace(0.5)
        ws_new = _mg_workspace(0.5)

        Random.seed!(1)
        psi0 = randn(ComplexF64, 16, 3)
        _normalize!(psi0, ws_leg.grid)

        # Legacy: mutate V_trap, apply diagonal multiplication, restore.
        # Mirror what _half_potential_step! does at MG-time.
        psi_leg = copy(psi0)
        V_before = copy(ws_leg.potential_values)
        SpinorBEC._apply_mg_to_V!(ws_leg, 0.0)
        # diagonal step exp(-(V) dt) per voxel:
        dt = 0.01
        @inbounds for c in 1:3, I in CartesianIndices(size(psi_leg)[1:1])
            psi_leg[I, c] *= exp(-ws_leg.potential_values[I] * dt)
        end
        SpinorBEC._remove_mg_from_V!(ws_leg, 0.0)
        # Strip the V_trap-only contribution (since V_trap was also in
        # potential_values during the multiplication):
        @inbounds for c in 1:3, I in CartesianIndices(size(psi_leg)[1:1])
            psi_leg[I, c] *= exp(+V_before[I] * dt)
        end

        # New: apply_step! on the HamTerm only.
        psi_new = copy(psi0)
        apply_step!(MagneticGradientTerm(), psi_new, dt, true, ws_new)

        @test maximum(abs, psi_new .- psi_leg) < 1e-13
    end

    @testset "Energy ↔ gradient FD consistency" begin
        ws = _mg_workspace(0.7)
        Random.seed!(2)
        psi_ref = randn(ComplexF64, 16, 3)
        _normalize!(psi_ref, ws.grid)
        δψ = randn(ComplexF64, 16, 3)
        _normalize!(δψ, ws.grid)

        ε = 1e-7
        E0 = energy_contribution(MagneticGradientTerm(), psi_ref, ws)
        Eε = energy_contribution(MagneticGradientTerm(), psi_ref .+ ε .* δψ, ws)
        fd_slope = (Eε - E0) / ε

        grad = zero(psi_ref)
        add_gradient!(grad, MagneticGradientTerm(), psi_ref, ws)
        # Convention: energy_gradient! later scales grad by 2 (Wirtinger).
        inner = 2 * real(sum(conj.(grad) .* δψ)) * cell_volume(ws.grid)

        @test isapprox(fd_slope, inner; rtol=1e-3)
    end

    @testset "Directional sign oracle: +g_F·grad ⇒ ⟨x⟩ < 0" begin
        # ITP under MG-only with +g_F·grad should push the cloud to −x.
        ws = _mg_workspace(0.8)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        for _ in 1:600
            apply_step!(MagneticGradientTerm(), psi, 0.01, true, ws)
            _normalize!(psi, ws.grid)
        end
        oracle = sign_oracle(MagneticGradientTerm)
        @test oracle.predicate(psi, ws)
    end

    @testset "Negative direction: −g_F·grad ⇒ ⟨x⟩ > 0" begin
        ws = _mg_workspace(-0.8)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        for _ in 1:600
            apply_step!(MagneticGradientTerm(), psi, 0.01, true, ws)
            _normalize!(psi, ws.grid)
        end
        oracle = sign_oracle(MagneticGradientTerm)
        @test oracle.predicate(psi, ws)
    end

    @testset "Registry energy_breakdown reports non-zero MG slot" begin
        ws = _mg_workspace(0.5)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        # Pull the wavefunction off-center so that ⟨x⟩ ≠ 0 and MG energy ≠ 0.
        N = ndims(psi) - 1
        n_pts = ntuple(d -> size(psi, d), Val(N))
        x_axis = ws.grid.x[1]
        for c in 1:size(psi, 2), I in CartesianIndices(n_pts)
            psi[I, c] *= exp(-(x_axis[I[1]] - 1.5)^2 / 2)
        end
        _normalize!(psi, ws.grid)
        copyto!(ws.state.psi, psi)

        bd = energy_breakdown_via_registry(ws)
        @test abs(bd.magnetic_gradient) > 1e-6
        # Cloud is concentrated at +x, so E_MG should be > 0 for +grad.
        @test bd.magnetic_gradient > 0.0
    end
end
