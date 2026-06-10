# test/oracles/test_strang_energy_conservation.jl
#
# A symmetric Strang step  V(dt/2) K(dt) V(dt/2)  built from the unitary
# propagators is symplectic: real-time evolution of the non-interacting
# kinetic+trap Hamiltonian conserves both the norm (machine precision) and
# the energy (bounded O(dt²) oscillation, no secular drift). A wrong step
# ordering, a non-symmetric split, or a non-unitary substep breaks this.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, apply_step!, energy_contribution

@testset "Strang step conserves norm + energy (kinetic+trap)" begin
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)

    # smooth (well-resolved) initial state so the discretization is faithful
    psi = zeros(ComplexF64, 16, 16, 16, D)
    @inbounds for I in CartesianIndices((16, 16, 16))
        r2 = ws.grid.x[1][I[1]]^2 + ws.grid.x[2][I[2]]^2 + ws.grid.x[3][I[3]]^2
        psi[I, 1] = exp(-0.5 * r2) * cis(0.3 * ws.grid.x[1][I[1]])  # offset ⇒ breathing+sloshing
    end
    psi ./= sqrt(sum(abs2, psi) * dV)

    energy(p) = energy_contribution(KineticTerm(), p, ws) +
                energy_contribution(TrapTerm(), p, ws)
    E0 = energy(psi)
    N0 = sum(abs2, psi) * dV

    dt = 0.01
    for _ in 1:100
        apply_step!(TrapTerm(), psi, dt / 2, false, ws)
        apply_step!(KineticTerm(), psi, dt, false, ws)
        apply_step!(TrapTerm(), psi, dt / 2, false, ws)
    end

    @test isapprox(sum(abs2, psi) * dV, N0; rtol=1e-10)
    @test isapprox(energy(psi), E0; rtol=2e-3)
end
