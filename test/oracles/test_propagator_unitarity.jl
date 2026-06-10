# test/oracles/test_propagator_unitarity.jl
#
# Every UNITARY HamTerm propagator (real-time apply_step! = e^{-i dt H})
# must conserve the norm exactly. This is the dynamical counterpart of the
# Hermiticity oracle: a Hermitian generator ⇒ unitary evolution ⇒ ‖ψ‖
# invariant. A wrong factor of i, a real-instead-of-imaginary exponent, or
# a non-Hermitian term shows up as norm drift. (Loss is non-unitary by
# design and is excluded.)

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, ZeemanTerm,
    CoriolisTerm, apply_step!

@testset "Unitary propagators conserve norm (real time)" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.3, 0.7)),
        sim_params=SimParams(; dt=0.02, n_steps=1, imaginary_time=false,
            rotating_frame_omega=0.5),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    dt = 0.02

    terms = (
        ("Kinetic", KineticTerm()),
        ("Trap", TrapTerm()),
        ("ZeemanZ", ZeemanTerm(0.0, 0.0, 0.7, 0.2)),
        ("ZeemanTransverse", ZeemanTerm(0.5, 0.3, 0.0, 0.0)),
        ("ZeemanFull", ZeemanTerm(0.5, 0.3, 0.7, 0.2)),
        ("Coriolis", CoriolisTerm(0.5)),
    )
    for (name, term) in terms
        @testset "$name" begin
            psi = randn(ComplexF64, 8, 8, 8, D)
            psi ./= sqrt(sum(abs2, psi) * dV)
            n0 = sum(abs2, psi) * dV
            apply_step!(term, psi, dt, false, ws)   # real time
            n1 = sum(abs2, psi) * dV
            @test isapprox(n1, n0; rtol=1e-10)
        end
    end
end
