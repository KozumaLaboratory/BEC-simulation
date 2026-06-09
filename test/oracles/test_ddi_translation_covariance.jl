# test/oracles/test_ddi_translation_covariance.jl
#
# The dipolar mean field is a convolution, hence translation-covariant on
# the periodic grid: shifting ψ by a lattice vector shifts the DDI
# potentials Φ_α by the same vector. A bug in the k-space phase, an FFT
# axis swap, or an index-off-by-one in the convolution would break this.

using Test
using SpinorBEC
using SpinorBEC: reference_ddi_potentials, spin_matrices

@testset "DDI potentials are translation-covariant" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    sm = spin_matrices(6)
    D = 13
    psi = randn(ComplexF64, 8, 8, 8, D)

    shift = (2, -3, 1)
    psi_s = circshift(psi, (shift..., 0))

    Φ = reference_ddi_potentials(psi, sm, grid)
    Φs = reference_ddi_potentials(psi_s, sm, grid)

    for a in 1:3
        @test isapprox(Φs[a], circshift(Φ[a], shift); rtol=1e-10, atol=1e-12)
    end
end
