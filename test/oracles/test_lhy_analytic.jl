# test/oracles/test_lhy_analytic.jl
#
# Scalar (fully-polarized) Lee–Huang–Yang correction. With n = total
# density and c_lhy the scalar coefficient, the closed form is
#   E_LHY        = (2/5)·c_lhy·∫ n^{5/2} dV
#   δE/δψ̄ (Hψ)  = c_lhy·n^{3/2}·ψ          (same on every spinor component)
# These are δE/δψ̄-consistent: d/dψ̄ of (2/5)c∫(ψ̄ψ)^{5/2} = c·(ψ̄ψ)^{3/2}·ψ.
#
# Pin BOTH faces voxel-wise at machine precision for F=1 and F=6:
#   • apply_operator! (the accumulating gradient face) vs c_lhy·n^{3/2}·ψ
#   • energy_contribution           vs (2/5)·c_lhy·Σ n^{5/2}·dV
#
# make_workspace wraps the scalar c_lhy as a ScalarLHY (ws.lhy) while
# interactions.c_lhy stays the gate for _grad_lhy!; both faces evaluate the
# SAME scalar closed form. The spinor (n_comp>1) energy path emits a one-shot
# scalar-approximation @warn (KNOWN-LIMIT: true spinor LHY needs the full
# Bogoliubov spectrum) but still evaluates the scalar closed form exactly,
# which is what this gate pins. The 3/2 power and the 2/5 prefactor make
# this non-trivial: any sign, exponent, or prefactor drift turns it red.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: LHYTerm, apply_operator!, energy_contribution,
    total_density, cell_volume

@testset "LHYTerm scalar: Hψ = c_lhy·n^{3/2}·ψ, E = (2/5)·c_lhy·∫n^{5/2}" begin
    c_lhy = 0.37
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0); c_lhy=c_lhy),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )
        # make_workspace wraps the scalar c_lhy into a ScalarLHY for ws.lhy,
        # while interactions.c_lhy stays the gate for _grad_lhy! — both faces
        # therefore evaluate the SAME scalar closed form below.
        @test ws.interactions.c_lhy == c_lhy

        D = 2F + 1
        dV = cell_volume(grid)
        psi = randn(ComplexF64, 6, 6, 6, D)

        # n = total (spinor-summed) density; closed forms built independently.
        n = total_density(psi, 3)
        expected_grad = similar(psi)
        @inbounds for I in CartesianIndices((6, 6, 6))
            expected_grad[I, :] = c_lhy * n[I]^(3 / 2) .* psi[I, :]
        end
        expected_E = (2 / 5) * c_lhy * sum(ni -> ni^(5 / 2), n) * dV

        @testset "F=$F" begin
            out = zero(psi)                 # apply_operator! ACCUMULATES (.+=)
            apply_operator!(out, LHYTerm(), ws, psi)
            @test isapprox(out, expected_grad; rtol=1e-12, atol=1e-12)

            E = energy_contribution(LHYTerm(), psi, ws)
            @test isapprox(E, expected_E; rtol=1e-12, atol=1e-12)
        end
    end
end
