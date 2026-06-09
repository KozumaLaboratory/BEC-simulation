# test/oracles/test_parity_symmetry.jl
#
# The kinetic + harmonic-trap Hamiltonian commutes with the PHYSICAL spatial
# parity P (x → −x): -½∇² is parity-even and V = ½Σω²x² is parity-even for
# ANY trap frequencies, so H·(Pψ) = P·(Hψ) to machine precision.
#
# The grid is centred (x symmetric about 0), so the physical parity is the
# reflection about the geometric centre, index i → n+1−i — NOT the FFT-origin
# reflection n+2−i. For even n this reflection has NO fixed point (it swaps
# index pairs (1,n),(2,n−1),…), so it is free of the Nyquist self-mirror that
# would otherwise complicate parity on an even grid. Verified: both terms
# commute at ≤2e-14 (`/tmp` diagnostic, 2026-06-10).
#
# Gates: a wrong k-vector sign, an off-by-one in the trap coordinate, or an
# axis-asymmetric FFT treatment would break the commutation.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, apply_operator!

@inline _mir(i, n) = n + 1 - i        # reflection about the geometric centre

function _parity(psi)
    nx, ny, nz, D = size(psi)
    out = similar(psi)
    @inbounds for I in CartesianIndices((nx, ny, nz)), c in 1:D
        out[I, c] = psi[_mir(I[1], nx), _mir(I[2], ny), _mir(I[3], nz), c]
    end
    out
end

@testset "Parity commutes with kinetic+trap" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.3, 0.7)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components

    # sanity: the grid axis is exactly anti-symmetric under the mirror
    x = ws.grid.x[1]
    @test maximum(abs, [x[_mir(i, 8)] + x[i] for i in 1:8]) < 1e-14

    psi = randn(ComplexF64, 8, 8, 8, D)
    Hpsi(p) = (o = zero(p);
        apply_operator!(o, KineticTerm(), ws, p);
        apply_operator!(o, TrapTerm(), ws, p); o)

    @test isapprox(Hpsi(_parity(psi)), _parity(Hpsi(psi)); rtol=1e-10, atol=1e-10)
end
