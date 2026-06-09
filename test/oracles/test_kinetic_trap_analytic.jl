# test/oracles/test_kinetic_trap_analytic.jl
#
# Analytic-limit oracles for the two simplest linear terms:
#   • Kinetic  H_kin = -½∇²  → on a plane wave e^{ik·x} gives ½|k|²·ψ exactly.
#   • Trap     H_trap = V(x) → multiplies pointwise by V = ½Σ_d ω_d² x_d².
# Both are exact (machine precision) on the grid, so any factor/sign drift
# in the kinetic prefactor or the trap potential assembly is caught here.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, apply_operator!

function _kt_ws(omega)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap(omega),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
end

@testset "Kinetic/Trap analytic limits" begin
    ws = _kt_ws((1.0, 1.3, 0.7))
    D = ws.spin_matrices.system.n_components
    L = 4.0

    @testset "Kinetic on a plane wave = ½|k|²ψ" begin
        for mode in (1, 2, 3)
            kx = 2π / L * mode
            psi = zeros(ComplexF64, 8, 8, 8, D)
            @inbounds for I in CartesianIndices((8, 8, 8))
                psi[I, 1] = cis(kx * ws.grid.x[1][I[1]])
            end
            out = zero(psi)
            apply_operator!(out, KineticTerm(), ws, psi)
            @test isapprox(out, 0.5 * kx^2 .* psi; rtol=1e-10, atol=1e-10)
        end
    end

    @testset "Trap = V(x)·ψ pointwise, V = ½Σω²x²" begin
        ωx, ωy, ωz = 1.0, 1.3, 0.7
        psi = randn(ComplexF64, 8, 8, 8, D)
        out = zero(psi)
        apply_operator!(out, TrapTerm(), ws, psi)
        expected = similar(psi)
        @inbounds for I in CartesianIndices((8, 8, 8))
            V = 0.5 * (ωx^2 * ws.grid.x[1][I[1]]^2 +
                       ωy^2 * ws.grid.x[2][I[2]]^2 +
                       ωz^2 * ws.grid.x[3][I[3]]^2)
            for c in 1:D
                expected[I, c] = V * psi[I, c]
            end
        end
        @test isapprox(out, expected; rtol=1e-12, atol=1e-12)
    end
end
