# test/oracles/test_harmonic_virial.jl
#
# The non-interacting harmonic-trap ground state obeys the virial theorem
# ⟨T⟩ = ⟨V⟩ (each = ¼Σω_d, total E = ½Σω_d). Imaginary-time relaxation of
# the kinetic+trap Hamiltonian from a random state must reach it. This is an
# end-to-end gate on the ITP propagator + kinetic/trap energies: a wrong
# kinetic prefactor, a broken Strang split, or a trap factor would push
# ⟨T⟩≠⟨V⟩ or move the energy off ½Σω.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, apply_step!, energy_contribution

@testset "Harmonic ground state virial ⟨T⟩=⟨V⟩ (ITP)" begin
    grid = make_grid(GridConfig((24, 24, 24), (12.0, 12.0, 12.0)))
    ωs = (1.0, 1.0, 1.0)
    # `backend` is NOT optional here even though this is a CPU test: with no
    # explicit backend `_resolve_backend` auto-selects CUDA for a 3D grid of
    # 24³ or larger whenever `cuda_functional()` — which depends on whether
    # some EARLIER file in the same parallel-worker session happened to
    # `import CUDA`. The ψ below is a host Array, so the auto-selected GPU
    # `potential_values` would scalar-index and throw. Pin it.
    ws = make_workspace(;
        grid, atom=Rb87, backend=CPUBackend(),
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap(ωs),
        sim_params=SimParams(; dt=0.02, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)

    # single occupied component; relax kinetic+trap in imaginary time
    psi = zeros(ComplexF64, 24, 24, 24, D)
    psi[:, :, :, 1] .= randn.(ComplexF64)
    psi ./= sqrt(sum(abs2, psi) * dV)
    dt = 0.02
    for _ in 1:800
        apply_step!(TrapTerm(), psi, dt / 2, true, ws)
        apply_step!(KineticTerm(), psi, dt, true, ws)
        apply_step!(TrapTerm(), psi, dt / 2, true, ws)
        psi ./= sqrt(sum(abs2, psi) * dV)
    end

    T = energy_contribution(KineticTerm(), psi, ws)
    V = energy_contribution(TrapTerm(), psi, ws)
    Etot = T + V
    @test isapprox(T, V; rtol=2e-2)                  # virial
    @test isapprox(Etot, 0.5 * sum(ωs); rtol=2e-2)   # zero-point energy ½Σω
end
