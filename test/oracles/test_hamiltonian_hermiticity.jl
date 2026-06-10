# test/oracles/test_hamiltonian_hermiticity.jl
#
# Hermiticity oracle for the LINEAR HamTerms. A linear Hamiltonian term H
# must satisfy ⟨φ|Hψ⟩ = ⟨Hφ|ψ⟩ for all φ, ψ. `apply_operator!` returns
# δE/δψ* = H·ψ for linear terms, so we test the identity directly on random
# broadband states.
#
# This gates the class found via the DDI-Nyquist hunt (2026-06-09): a
# k-space FIRST DERIVATIVE (odd multiplier i·k) that does NOT zero the
# Nyquist mode is not exactly anti-symmetric on an even grid, so the
# momentum / L_z operator it builds is slightly NON-Hermitian. Even-in-k
# operators (kinetic ½k²) are Nyquist-safe and pass; the contrast isolates
# the bug. Nonlinear terms (DDI/LHY/Tensor/contact) are excluded — their
# frozen-mean-field Hermiticity is a separate gate.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, ZeemanTerm,
    CoriolisTerm, apply_operator!
using Random

# even grid ⇒ has a Nyquist mode on every axis (the bug only shows there)
function _herm_ws(; omega_rot::Float64=0.0)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.3, 0.7)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true,
            rotating_frame_omega=omega_rot),
        fft_flags=FFTW.ESTIMATE,
    )
end

function _rand_state(ws, seed)
    Random.seed!(seed)
    D = ws.spin_matrices.system.n_components
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    psi
end

# H must satisfy ⟨φ|Hψ⟩ = ⟨Hφ|ψ⟩. Returns relative violation.
function _herm_violation(term, ws, phi, psi)
    dV = cell_volume(ws.grid)
    Hpsi = zero(psi); apply_operator!(Hpsi, term, ws, psi)
    Hphi = zero(phi); apply_operator!(Hphi, term, ws, phi)
    lhs = sum(conj.(phi) .* Hpsi) * dV       # ⟨φ|Hψ⟩
    rhs = sum(conj.(Hphi) .* psi) * dV       # ⟨Hφ|ψ⟩
    scale = max(abs(lhs), abs(rhs), eps())
    abs(lhs - rhs) / scale
end

@testset "HamTerm Hermiticity: ⟨φ|Hψ⟩ = ⟨Hφ|ψ⟩" begin
    ws = _herm_ws()
    phi = _rand_state(ws, 11)
    psi = _rand_state(ws, 22)

    @testset "KineticTerm (½k², even ⇒ Nyquist-safe)" begin
        @test _herm_violation(KineticTerm(), ws, phi, psi) < 1e-12
    end
    @testset "TrapTerm (real V(x) multiplication)" begin
        @test _herm_violation(TrapTerm(), ws, phi, psi) < 1e-12
    end
    @testset "ZeemanTerm (real diagonal)" begin
        @test _herm_violation(ZeemanTerm(0.0, 0.0, 0.7, 0.2), ws, phi, psi) < 1e-12
    end
    @testset "ZeemanTerm (Hermitian transverse F_x,F_y)" begin
        @test _herm_violation(ZeemanTerm(0.5, 0.3, 0.0, 0.0), ws, phi, psi) < 1e-12
    end
    @testset "ZeemanTerm (full: diagonal + transverse)" begin
        @test _herm_violation(ZeemanTerm(0.5, 0.3, 0.7, 0.2), ws, phi, psi) < 1e-12
    end

    @testset "CoriolisTerm (L_z = x p_y − y p_x; first-derivative)" begin
        wsΩ = _herm_ws(; omega_rot=0.6)
        phiΩ = _rand_state(wsΩ, 11)
        psiΩ = _rand_state(wsΩ, 22)
        v = _herm_violation(CoriolisTerm(0.6), wsΩ, phiΩ, psiΩ)
        @info "Coriolis Hermiticity violation" v
        @test v < 1e-12
    end
end
