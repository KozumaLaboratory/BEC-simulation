# test/oracles/test_energy_operator_identity.jl
#
# For a LINEAR HamTerm, the energy is the operator expectation:
#     E = ⟨ψ|H|ψ⟩·dV = Re Σ conj(ψ)·(H·ψ)·dV.
# `energy_contribution` (the scalar face) and `apply_operator!` (the
# operator face) derive from the same coefficient declaration, so they
# must agree exactly. Complements the FD oracle (test_term_consistency):
# that pins energy↔gradient via finite differences; this pins energy↔
# operator via the inner product, with no ε.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, LinearZeemanZTerm, TransverseZeemanTerm,
    CoriolisTerm, apply_operator!, energy_contribution

@testset "Linear term energy = Re⟨ψ|Hψ⟩·dV" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.3, 0.7)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true,
            rotating_frame_omega=0.6),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    for (name, term) in (
        ("Kinetic", KineticTerm()),
        ("Trap", TrapTerm()),
        ("LinearZeemanZ", LinearZeemanZTerm(0.7, 0.2)),
        ("TransverseZeeman", TransverseZeemanTerm(0.5, 0.3)),
        ("Coriolis", CoriolisTerm(0.6)),
    )
        @testset "$name" begin
            Hpsi = zero(psi)
            apply_operator!(Hpsi, term, ws, psi)
            E_op = real(sum(conj.(psi) .* Hpsi)) * dV
            E_face = energy_contribution(term, psi, ws)
            @test isapprox(E_face, E_op; rtol=1e-9, atol=1e-12)
        end
    end
end
