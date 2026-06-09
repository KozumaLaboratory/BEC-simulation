# test/oracles/test_magnetization_conservation_rtp.jl
#
# With no transverse field / Raman and DDI off, the Hamiltonian
# (kinetic + trap + Bz + c₀ + c₁) commutes with F_z, so total ⟨F_z⟩ is a
# constant of the real-time motion — even while c₁ spin-mixing actively
# redistributes population among m-components. Norm is conserved too. A
# spin-mixing step that leaks magnetization (wrong ladder pairing) breaks
# this; the ITP/RTP machinery would silently drift the phase diagram.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, LinearZeemanZTerm, DensityC0Term,
    SpinC1Term, apply_step!

@testset "⟨F_z⟩ conserved under spin-mixing real-time evolution" begin
    F = 1
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.5)),
        zeeman=ZeemanParams(0.3, 0.05), potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=false),
        fft_flags=FFTW.ESTIMATE,
    )
    D = 2F + 1
    dV = cell_volume(grid)
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    Fz(p) = sum((F - (c - 1)) * sum(abs2, @view p[:, :, :, c]) for c in 1:D) * dV
    norm(p) = sum(abs2, p) * dV

    Fz0 = Fz(psi); N0 = norm(psi)
    dt = 0.005
    terms = (LinearZeemanZTerm(0.3, 0.05), DensityC0Term(1.0),
        SpinC1Term(0.5), TrapTerm(), KineticTerm())
    for _ in 1:30
        for term in terms
            apply_step!(term, psi, dt, false, ws)
        end
    end

    # c₁ must have actually mixed (else the test is trivially satisfied)
    @test Fz(psi) !== Fz0
    @test isapprox(Fz(psi), Fz0; atol=1e-8)
    @test isapprox(norm(psi), N0; rtol=1e-10)
end
