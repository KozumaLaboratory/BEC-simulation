# test/oracles/test_ddi_energy_potential_crosscheck.jl
#
# Cross-check the production DDI energy against the INDEPENDENT reference
# potential:  E_DDI = (c_dd/2)·∫ Φ·f  dV,  with Φ from reference_ddi_potentials
# (built on a fresh rfft plan, no production cache) and f = ⟨F⟩ the spin
# density. Pins the self-energy ½, the c_dd prefactor, and the
# potential·density contraction simultaneously, via two independent code
# paths.

using Test
using FFTW
using SpinorBEC
using SpinorBEC:
    DDITerm, energy_contribution, reference_ddi_potentials,
    spin_density_vector, compute_c_dd

@testset "E_DDI = (c_dd/2)∫Φ·f (production vs reference)" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    c_dd = compute_c_dd(Eu151)
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.1)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        enable_ddi=true, c_dd=c_dd,
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    Φx, Φy, Φz = reference_ddi_potentials(psi, ws.spin_matrices, grid)  # no c_dd
    fx, fy, fz = spin_density_vector(psi, ws.spin_matrices, 3)
    E_ref = 0.5 * c_dd * sum(Φx .* fx .+ Φy .* fy .+ Φz .* fz) * dV

    @test isapprox(energy_contribution(DDITerm(), psi, ws), E_ref; rtol=1e-9, atol=1e-12)
end
