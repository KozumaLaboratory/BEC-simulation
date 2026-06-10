# test/oracles/test_spin_c1_analytic.jl
#
# The c₁ spin term H = (c₁/2)|F|² has mean-field operator (δE/δψ*)
# = c₁·(f·F̂)·ψ, where f(r)=⟨F⟩(r) is the local spin density vector. Pin
# both faces:
#   • apply_operator! = c₁·(f_x F_x + f_y F_y + f_z F_z)·ψ  voxel-wise
#   • energy          = (c₁/2)∫|f|²
# The sign of c₁ selects polar (>0) vs ferromagnetic (<0); a drift here
# silently moves the F=1 phase boundary, so pin it analytically for F=1,6.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: SpinC1Term, apply_operator!, energy_contribution, spin_matrices

@testset "SpinC1 mean field = c₁·(f·F̂)·ψ, energy (c₁/2)∫|f|²" begin
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
        sm = spin_matrices(F)
        Fx = Matrix(sm.Fx); Fy = Matrix(sm.Fy); Fz = Matrix(sm.Fz)
        c1 = 0.4
        psi = randn(ComplexF64, 6, 6, 6, D)
        psi ./= sqrt(sum(abs2, psi) * dV)

        # local spin densities and the expected mean-field action
        expected = similar(psi)
        f2int = 0.0
        @inbounds for I in CartesianIndices((6, 6, 6))
            v = psi[I, :]
            fx = real(v' * Fx * v); fy = real(v' * Fy * v); fz = real(v' * Fz * v)
            expected[I, :] = c1 * (fx * Fx + fy * Fy + fz * Fz) * v
            f2int += fx^2 + fy^2 + fz^2
        end

        @testset "F=$F" begin
            out = zero(psi)
            apply_operator!(out, SpinC1Term(c1), ws, psi)
            @test isapprox(out, expected; rtol=1e-10, atol=1e-12)
            E = energy_contribution(SpinC1Term(c1), psi, ws)
            @test isapprox(E, 0.5 * c1 * f2int * dV; rtol=1e-10, atol=1e-12)
        end
    end
end
