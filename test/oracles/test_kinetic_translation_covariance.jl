# test/oracles/test_kinetic_translation_covariance.jl
#
# Kinetic energy is translation-invariant: it commutes with a lattice
# shift, K(Tψ) = T(Kψ) where T is a circular shift on the periodic grid.
# A wrong k-vector phase or an axis-swapped FFT plan breaks this. Cheap,
# exact (≤1e-12), and complements the parity gate.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, apply_operator!

@testset "Kinetic commutes with translation" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    psi = randn(ComplexF64, 8, 8, 8, D)
    shift = (3, -2, 1)
    Kp(p) = (o = zero(p); apply_operator!(o, KineticTerm(), ws, p); o)

    lhs = Kp(circshift(psi, (shift..., 0)))
    rhs = circshift(Kp(psi), (shift..., 0))
    @test isapprox(lhs, rhs; rtol=1e-12, atol=1e-12)
end
