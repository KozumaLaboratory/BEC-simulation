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
using Random
using SpinorBEC
using LinearAlgebra: norm
using SpinorBEC: KineticTerm, TrapTerm, ZeemanTerm, DensityC0Term,
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
    # Seeded: the "c1 actually mixed" check below used to read `Fz(psi) !== Fz0`,
    # i.e. it asked a CONSERVED quantity to change, and so passed only when
    # floating-point noise happened to move its last bits. Unseeded, that is a
    # coin flip — it reddened CI on 2026-08-01 with the two values bit-identical.
    psi = randn(Xoshiro(20260801), ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    Fz(p) = sum((F - (c - 1)) * sum(abs2, @view p[:, :, :, c]) for c in 1:D) * dV
    norm(p) = sum(abs2, p) * dV

    pops(p) = [sum(abs2, @view p[:, :, :, c]) * dV for c in 1:D]

    Fz0 = Fz(psi)
    N0 = norm(psi)
    pops0 = pops(psi)
    psi0_saved = copy(psi)
    dt = 0.005
    terms = (ZeemanTerm(0.0, 0.0, 0.3, 0.05), DensityC0Term(1.0),
        SpinC1Term(0.5), TrapTerm(), KineticTerm())
    for _ in 1:30
        for term in terms
            apply_step!(term, psi, dt, false, ws)
        end
    end

    # c₁ must have actually mixed, else conservation is trivially satisfied.
    # Asked of the per-component POPULATIONS, which spin mixing redistributes —
    # not of ⟨F_z⟩, which this file exists to show is conserved.
    #
    # Gated against the c₁ = 0 control rather than a fitted constant: with no
    # spin mixing the populations are conserved to round-off, so the ratio is
    # the statement "mixing happened", and it does not need retuning if the
    # configuration changes.
    psi_c1off = copy(psi0_saved)
    terms_c1off = (ZeemanTerm(0.0, 0.0, 0.3, 0.05), DensityC0Term(1.0),
        SpinC1Term(0.0), TrapTerm(), KineticTerm())
    for _ in 1:30
        for term in terms_c1off
            apply_step!(term, psi_c1off, dt, false, ws)
        end
    end
    mixed = maximum(abs.(pops(psi) .- pops0))
    unmixed = maximum(abs.(pops(psi_c1off) .- pops0))
    @test mixed > 1e3 * max(unmixed, eps())
    @test isapprox(Fz(psi), Fz0; atol=1e-8)
    @test isapprox(norm(psi), N0; rtol=1e-10)
end
