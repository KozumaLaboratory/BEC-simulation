# test/oracles/test_contact_meanfield_analytic.jl
#
# The density (c₀) contact term is the local mean field c₀·n·ψ, with
# n(r)=Σ_c|ψ_c|² the total density. `apply_operator!` (δE/δψ*) must equal
# c₀·n·ψ pointwise, and the energy must be ½c₀∫n² (the GP self-energy ½).
# Pins both the mean-field factor and the energy ½, for several F.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: DensityC0Term, apply_operator!, energy_contribution

@testset "Density c₀ mean field = c₀·n·ψ, energy ½c₀∫n²" begin
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )
        D = 2F + 1
        dV = cell_volume(grid)
        c0 = 0.75
        psi = randn(ComplexF64, 6, 6, 6, D)
        psi ./= sqrt(sum(abs2, psi) * dV)

        n = zeros(Float64, 6, 6, 6)
        @inbounds for I in CartesianIndices((6, 6, 6)), c in 1:D
            n[I] += abs2(psi[I, c])
        end

        @testset "F=$F mean field" begin
            out = zero(psi)
            apply_operator!(out, DensityC0Term(c0), ws, psi)
            expected = similar(psi)
            @inbounds for I in CartesianIndices((6, 6, 6)), c in 1:D
                expected[I, c] = c0 * n[I] * psi[I, c]
            end
            @test isapprox(out, expected; rtol=1e-12, atol=1e-12)
        end
        @testset "F=$F energy = ½c₀∫n²" begin
            E = energy_contribution(DensityC0Term(c0), psi, ws)
            E_expected = 0.5 * c0 * sum(n .^ 2) * dV
            @test isapprox(E, E_expected; rtol=1e-10, atol=1e-12)
        end
    end
end
