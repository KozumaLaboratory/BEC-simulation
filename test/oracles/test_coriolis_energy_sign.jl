# test/oracles/test_coriolis_energy_sign.jl
#
# The rotating-frame Coriolis term is H_cor = −Ω·L_z, so its energy is
# exactly E_cor = −Ω·⟨L_z⟩. Pin the sign+magnitude against the independent
# orbital_angular_momentum observable. A flipped Coriolis sign (the
# 2026-06-03 incident) moves the vortex-nucleation threshold.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: CoriolisTerm, energy_contribution, orbital_angular_momentum

@testset "Coriolis energy = −Ω·⟨L_z⟩" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    for Ω in (0.4, -0.7)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false,
                rotating_frame_omega=Ω),
            fft_flags=FFTW.ESTIMATE,
        )
        D = ws.spin_matrices.system.n_components
        psi = randn(ComplexF64, 8, 8, 8, D)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
        Lz = orbital_angular_momentum(psi, grid, ws.fft_plans)
        E = energy_contribution(CoriolisTerm(Ω), psi, ws)
        @test isapprox(E, -Ω * Lz; rtol=1e-9, atol=1e-12)
    end
end
