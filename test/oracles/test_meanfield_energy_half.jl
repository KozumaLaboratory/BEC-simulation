# test/oracles/test_meanfield_energy_half.jl
#
# A NONLINEAR mean-field term carries the self-energy factor ½: its energy
# is E = ½·Re⟨ψ|H[ψ]·ψ⟩·dV (half the operator expectation), because the
# mean field H[ψ] already contains one power of the density. This is the
# nonlinear counterpart of test_energy_operator_identity (linear terms have
# NO ½). A missing or doubled ½ in any interaction energy is caught here for
# the contact c₀, spin c₁, and dipolar DDI terms.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: DensityC0Term, SpinC1Term, DDITerm, apply_operator!,
    energy_contribution, compute_c_dd

@testset "Nonlinear term energy = ½·Re⟨ψ|Hψ⟩·dV" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.1)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        enable_ddi=true, c_dd=compute_c_dd(Eu151),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    for (name, term) in (
        ("DensityC0", DensityC0Term(0.7)),
        ("SpinC1", SpinC1Term(0.3)),
        ("DDI", DDITerm()),
    )
        @testset "$name" begin
            Hpsi = zero(psi)
            apply_operator!(Hpsi, term, ws, psi)
            E_half = 0.5 * real(sum(conj.(psi) .* Hpsi)) * dV
            @test isapprox(energy_contribution(term, psi, ws), E_half; rtol=1e-9, atol=1e-12)
        end
    end
end
