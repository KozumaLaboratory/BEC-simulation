# test/oracles/test_velocity_planewave.jl
#
# A plane wave ψ ∝ e^{ik·x} carries uniform superfluid velocity v = k
# (ℏ=m=1): j = Im(ψ*∇ψ) = |ψ|²·k and v = j/n = k. Pins the sign and
# magnitude of the FFT-spectral current/velocity used for vortex and
# transport diagnostics — a flipped i·k or a missing 1/n would show here.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: superfluid_velocity

@testset "Plane-wave superfluid velocity v = k" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    L = 4.0
    kx = 2π / L * 1;
    ky = 2π / L * 2;
    kz = -2π / L * 1   # integer modes on the grid

    psi = zeros(ComplexF64, 8, 8, 8, D)
    @inbounds for I in CartesianIndices((8, 8, 8))
        ph = kx * ws.grid.x[1][I[1]] + ky * ws.grid.x[2][I[2]] + kz * ws.grid.x[3][I[3]]
        psi[I, 1] = cis(ph)
    end

    v = superfluid_velocity(psi, grid, ws.fft_plans)
    @test isapprox(v[1], fill(kx, 8, 8, 8); rtol=1e-9, atol=1e-9)
    @test isapprox(v[2], fill(ky, 8, 8, 8); rtol=1e-9, atol=1e-9)
    @test isapprox(v[3], fill(kz, 8, 8, 8); rtol=1e-9, atol=1e-9)
end
