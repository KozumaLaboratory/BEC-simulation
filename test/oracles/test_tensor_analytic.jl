# test/oracles/test_tensor_analytic.jl
#
# TensorTerm covers the c₂ singlet-pair channel (+ higher-rank tensor_cache).
# Here we pin the c₂ singlet-pair piece in isolation: with interactions
# Dict(0,1 => 0, 2 => c₂) and the c₀/c₁ path, `tensor_cache` stays `nothing`,
# so the ONLY active contribution is the singlet-pair operator.
#
# `apply_operator!` is the ANOMALOUS pairing gradient face δE/δψ̄ (it carries
# conj(ψ), NOT the Hartree-Fock mean field the propagator builds) — a real
# implementation, NOT a KNOWN-LIMIT no-op. Pin it against the explicit closed
# form, voxel-wise, at machine precision:
#
#   A₀₀(r) = Σ_m (-1)^{F-m} ψ_m ψ_{-m} / √(2F+1)               (singlet amplitude)
#   (δE/δψ̄)_c = (c₂/√D)·(-1)^{F-m_c}·A₀₀·conj(ψ_{-m_c})         (m_c = F-(c-1))
#   E_pair    = (c₂/2)∫|A₀₀|² dV                                (energy)
#
# The test recomputes A independently from the spinor (component-index ↔ m_c
# mapping c=1→m=F, c=D→m=−F), so a sign/factor/index drift in any of the
# (-1)^{F-m} signature, the 1/√D normalisation, the c_pair = D-c+1 reflection,
# or the conj() would flip the result and fail. F=1 is additionally pinned
# against the hand-expanded form A = (2ψ₊₁ψ₋₁ − ψ₀²)/√3.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: TensorTerm, apply_operator!, energy_contribution

@testset "TensorTerm c₂ singlet pair: operator + energy closed form" begin
    c2 = 0.6
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0, 2 => c2)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )
        @test ws.tensor_cache === nothing   # c₀/c₁ path: singlet pair is the only active piece

        D = 2F + 1
        dV = cell_volume(grid)
        inv_sqrt_D = 1.0 / sqrt(Float64(D))
        psi = randn(ComplexF64, 6, 6, 6, D)
        psi ./= sqrt(sum(abs2, psi) * dV)

        # Independent recompute of A₀₀ and the anomalous operator + energy.
        A = zeros(ComplexF64, 6, 6, 6)
        expected = zeros(ComplexF64, 6, 6, 6, D)
        Eint = 0.0
        @inbounds for I in CartesianIndices((6, 6, 6))
            s = zero(ComplexF64)
            for c in 1:D
                m = F - (c - 1)
                sgn = iseven(F - m) ? 1.0 : -1.0
                s += sgn * psi[I, c] * psi[I, D - c + 1]
            end
            AI = s * inv_sqrt_D
            A[I] = AI
            Eint += abs2(AI)
            for c in 1:D
                m = F - (c - 1)
                sgn = iseven(F - m) ? 1.0 : -1.0
                expected[I, c] = (c2 * inv_sqrt_D) * sgn * AI * conj(psi[I, D - c + 1])
            end
        end

        @testset "F=$F operator = (c₂/√D)·σ_c·A·conj(ψ_pair)" begin
            out = zero(psi)
            apply_operator!(out, TensorTerm(), ws, psi)
            @test isapprox(out, expected; rtol=1e-11, atol=1e-13)
        end

        @testset "F=$F energy = (c₂/2)∫|A|²" begin
            E = energy_contribution(TensorTerm(), psi, ws)
            @test isapprox(E, 0.5 * c2 * Eint * dV; rtol=1e-10, atol=1e-13)
        end

        if F == 1
            # Hand-expanded singlet amplitude A = (2ψ₊₁ψ₋₁ − ψ₀²)/√3 (c=1→m=+1,
            # c=2→m=0, c=3→m=−1). Independent cross-check on the F=1 reduction.
            @testset "F=1 explicit A = (2ψ₊₁ψ₋₁ − ψ₀²)/√3" begin
                A_explicit = similar(A)
                @inbounds for I in CartesianIndices((6, 6, 6))
                    A_explicit[I] =
                        (2 * psi[I, 1] * psi[I, 3] - psi[I, 2]^2) / sqrt(3.0)
                end
                @test isapprox(A, A_explicit; rtol=1e-12, atol=1e-13)
            end
        end
    end
end
