# test/oracles/test_ddi_uniform_zero.jl
#
# A uniformly-magnetized cloud produces ZERO dipolar mean field on a
# periodic grid: a constant spin density is a pure k=0 mode, and the DDI
# kernel satisfies Q(k=0)=0 (a pinned convention). So Φ_α ≡ 0 and E_DDI=0.
# This gates Q(0)=0 + the FFT convolution wiring (a stray DC term, a
# non-zero Q(0), or an index slip would light up here).

using Test
using FFTW
using SpinorBEC
using SpinorBEC: DDITerm, apply_operator!, energy_contribution,
    reference_ddi_potentials, compute_c_dd

@testset "Uniform magnetization ⇒ zero DDI field" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.1)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        enable_ddi=true, c_dd=compute_c_dd(Eu151),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)

    # uniform, fully polarized (single component) ⇒ constant f_z, f_x=f_y=0
    psi = zeros(ComplexF64, 8, 8, 8, D)
    psi[:, :, :, 1] .= 1.0
    psi ./= sqrt(sum(abs2, psi) * dV)

    Φx, Φy, Φz = reference_ddi_potentials(psi, ws.spin_matrices, grid)
    @test maximum(abs, Φx) < 1e-12
    @test maximum(abs, Φy) < 1e-12
    @test maximum(abs, Φz) < 1e-12

    E_ddi = energy_contribution(DDITerm(), psi, ws)
    @test abs(E_ddi) < 1e-12

    Hpsi = zero(psi)
    apply_operator!(Hpsi, DDITerm(), ws, psi)
    @test maximum(abs, Hpsi) < 1e-12
end
