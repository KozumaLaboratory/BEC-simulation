# test/oracles/test_raman_analytic.jl
#
# Raman two-photon coupling. The propagator (apply_raman_step!) is
#   H_R(r) = (Ω_R/2)(e^{ik·r} F_+ + e^{-ik·r} F_-) + δ·F_z
#          = Ω_R cos(k·r) F_x − Ω_R sin(k·r) F_y + δ·F_z,
# and the registry energy face is
#   E_Raman = ∫ d³r [ δ·⟨F_z⟩ + Ω_R·Re(e^{ik·r}·⟨F_+⟩) ].
#
# Both faces are pinned against explicit spin matrices, voxel-wise, at machine
# precision. The gradient face used to be a declared NO-OP and this file
# asserted that contract; it was implemented 2026-07-31 because a term with an
# energy and no gradient made L-BFGS descend a functional it did not report.
#
# The energy test is NON-TRIVIAL: a wrong sign on δ or Ω_R, a flipped
# k·r phase, or F_+ ↔ F_- would all break it (the e^{ik·r}·⟨F_+⟩ term is
# complex and direction-sensitive). Pinned for F=1 and F=6.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC:
    RamanTerm, RamanCoupling, apply_operator!, energy_contribution,
    spin_matrices, cell_volume

@testset "RamanTerm energy and gradient vs explicit spin matrices" begin
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        D = 2F + 1
        Omega_R = 1.7
        delta = -0.6
        k_eff = (0.9, -0.4, 1.3)
        raman = RamanCoupling{3}(Omega_R, delta, k_eff)

        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            raman=raman,
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )

        sm = spin_matrices(F)
        Fx = Matrix(sm.Fx);
        Fy = Matrix(sm.Fy);
        Fz = Matrix(sm.Fz)
        Fp = Fx + im * Fy   # raising operator F_+

        psi = randn(ComplexF64, 6, 6, 6, D)
        dV = cell_volume(grid)

        # Independent closed-form energy from the explicit spin matrices.
        expected_E = 0.0
        @inbounds for I in CartesianIndices((6, 6, 6))
            v = psi[I, :]
            kr =
                k_eff[1] * grid.x[1][I[1]] +
                k_eff[2] * grid.x[2][I[2]] +
                k_eff[3] * grid.x[3][I[3]]
            fz = real(v' * Fz * v)
            fp = v' * Fp * v                       # ⟨F_+⟩ (complex)
            expected_E += (delta * fz + Omega_R * real(exp(im * kr) * fp)) * dV
        end

        @testset "F=$F energy" begin
            E = energy_contribution(RamanTerm(), psi, ws)
            @test isapprox(E, expected_E; rtol=1e-10, atol=1e-12)
            # Sanity: term is genuinely active (energy not accidentally zero).
            @test abs(expected_E) > 1e-6
        end

        @testset "F=$F gradient = H_R·ψ from the explicit matrices" begin
            # Same construction as the energy above, one derivative up:
            # H_R = δ·F_z + (Ω_R/2)(e^{ik·r}F₊ + e^{−ik·r}F₋). Built here from
            # `Fz`/`Fp` rather than from the production ladder coefficients, so
            # the two statements share nothing but the physics.
            Fm = Fp'
            expected_g = zeros(ComplexF64, 6, 6, 6, D)
            @inbounds for I in CartesianIndices((6, 6, 6))
                kr =
                    k_eff[1] * grid.x[1][I[1]] +
                    k_eff[2] * grid.x[2][I[2]] +
                    k_eff[3] * grid.x[3][I[3]]
                H = delta * Fz + (Omega_R / 2) * (exp(im * kr) * Fp + exp(-im * kr) * Fm)
                expected_g[I, :] = H * psi[I, :]
            end

            # ACCUMULATE contract: a pre-filled `out` must gain H_R·ψ, not be
            # overwritten — the defect class `test_apply_operator_accumulates.jl`
            # gates generally, checked here on the term this file owns.
            out = randn(ComplexF64, 6, 6, 6, D)
            before = copy(out)
            ret = apply_operator!(out, RamanTerm(), ws, psi)
            @test ret === out
            @test isapprox(out, before .+ expected_g; rtol=1e-12, atol=1e-13)

            # And the two faces are the same operator: E = Re⟨ψ, H_R ψ⟩·dV.
            @test isapprox(
                real(sum(conj.(psi) .* expected_g)) * dV, expected_E;
                rtol=1e-10, atol=1e-12,
            )
        end
    end
end
