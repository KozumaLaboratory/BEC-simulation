# test/oracles/test_registry_energy_decomposition_parity.jl
#
# Phase 5 gate: `energy_breakdown_via_registry` must match the legacy
# `energy_decomposition` field-by-field (modulo the now-restored MG slot,
# which legacy silently dropped — see test_magnetic_gradient_gap.jl).
#
# When this passes, `energy_decomposition` can delegate to the registry
# (one production path, single source of sign truth).

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: energy_breakdown_via_registry,
    energy_decomposition_via_registry_legacy_shape
using Random

function _build_workspace(; F::Int=1, dims=(8, 8, 8), Lscale=4.0,
    c0::Float64=0.0, c1::Float64=0.0,
    bz::Float64=0.0, q::Float64=0.0,
    bx::Float64=0.0, by::Float64=0.0,
    Ω::Float64=0.0, mg::Bool=false)
    grid = make_grid(GridConfig(dims, ntuple(_ -> Lscale, length(dims))))
    interactions = InteractionParams(Dict(0 => c0, 1 => c1))
    zeeman = if bx == 0.0 && by == 0.0
        ZeemanParams(bz, q)
    else
        # Transverse B requires TimeDependentZeeman with waveforms.
        TimeDependentZeeman(
            ConstantWaveform(bz), ConstantWaveform(q),
            ConstantWaveform(bx), ConstantWaveform(by),
        )
    end
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true,
        rotating_frame_omega=Ω)
    mg_pot = mg ? MagneticGradient{length(dims)}(0.3, 1, 1.0) : nothing
    ws = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap(ntuple(_ -> 1.0, length(dims))),
        magnetic_gradient=mg_pot,
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
    return ws
end

function _random_psi(ws, seed::Int=42)
    Random.seed!(seed)
    D = ws.spin_matrices.system.n_components
    n_pts = size(ws.state.psi)[1:(end - 1)]
    psi = randn(ComplexF64, n_pts..., D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    copyto!(ws.state.psi, psi)
    return psi
end

@testset "Registry breakdown ≡ legacy energy_decomposition" begin
    @testset "Minimal (kinetic + trap only)" begin
        ws = _build_workspace()
        psi = _random_psi(ws)
        bd_reg = energy_decomposition_via_registry_legacy_shape(ws)
        bd_leg = SpinorBEC.energy_decomposition(ws)
        for field in (:kinetic, :trap, :total)
            @test isapprox(bd_reg[field], bd_leg[field]; rtol=1e-12, atol=1e-14)
        end
        # Both report zero for inactive channels.
        @test bd_reg.density ≈ 0.0
        @test bd_reg.spin ≈ 0.0
    end

    @testset "Full Hamiltonian (Bz + q + c0 + c1 + Ω, no MG)" begin
        ws = _build_workspace(F=1, c0=0.5, c1=-0.3, bz=0.4, q=0.1, Ω=0.2)
        psi = _random_psi(ws)
        bd_reg = energy_decomposition_via_registry_legacy_shape(ws)
        bd_leg = SpinorBEC.energy_decomposition(ws)
        for field in (:kinetic, :trap, :zeeman, :density, :spin,
            :ddi, :lhy, :tensor, :raman, :light_shift, :coriolis)
            @test isapprox(bd_reg[field], bd_leg[field]; rtol=1e-12, atol=1e-13)
        end
        # Totals match.
        @test isapprox(bd_reg.total, bd_leg.total; rtol=1e-12, atol=1e-13)
    end

    @testset "Transverse Zeeman (Bx, By): legacy and registry both include" begin
        ws = _build_workspace(F=1, bz=0.2, bx=0.3, by=0.1)
        psi = _random_psi(ws)
        bd_reg = energy_decomposition_via_registry_legacy_shape(ws)
        bd_leg = SpinorBEC.energy_decomposition(ws)
        # Zeeman field in legacy = diag + transverse (post-[GAP-1] fix).
        @test isapprox(bd_reg.zeeman, bd_leg.zeeman; rtol=1e-12, atol=1e-13)
    end

    @testset "MG slot included in BOTH registry AND legacy (post-[GAP-2] fix)" begin
        ws = _build_workspace(F=1, c0=0.1, mg=true)
        psi = _random_psi(ws)
        # Force a non-symmetric ψ so ⟨x⟩ ≠ 0:
        x_axis = ws.grid.x[1]
        for c in 1:size(psi, ndims(psi)), I in CartesianIndices(size(psi)[1:(end - 1)])
            psi[I, c] *= exp(-(x_axis[I[1]] - 1.0)^2)
        end
        psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        copyto!(ws.state.psi, psi)

        bd_reg = energy_decomposition_via_registry_legacy_shape(ws)
        @test abs(bd_reg.magnetic_gradient) > 1e-6

        # Post-fix: legacy `energy_decomposition` ALSO includes the
        # :magnetic_gradient slot (closes [GAP-2] on the legacy side).
        bd_leg = SpinorBEC.energy_decomposition(ws)
        @test haskey(bd_leg, :magnetic_gradient)
        @test isapprox(bd_reg.magnetic_gradient, bd_leg.magnetic_gradient;
            rtol=1e-12, atol=1e-13)
        for field in (:kinetic, :trap, :zeeman, :density, :spin)
            @test isapprox(bd_reg[field], bd_leg[field]; rtol=1e-12, atol=1e-13)
        end
        # Totals now match — both include MG.
        @test isapprox(bd_reg.total, bd_leg.total; rtol=1e-12, atol=1e-13)
    end
end
