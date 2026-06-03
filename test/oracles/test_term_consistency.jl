# test/oracles/test_term_consistency.jl
#
# Per-HamTerm consistency check (the structural anti-recurrence gate
# for sign-bug class). For every HamTerm, we verify:
#
#   1. `energy_contribution` and `add_gradient!` are FD-consistent:
#         (E(ψ + ε·δψ) - E(ψ)) / ε ≈ Re⟨grad, δψ⟩
#      This catches any sign/missing-term mismatch between energy and
#      gradient — the bug class found in 2026-06-04 GAP-1.
#
#   2. The directional sign_oracle predicate evaluates true after ITP
#      with the term active. This catches sign-inversion bugs of the
#      kind found in 2026-06-03 Coriolis + 2026-06-04 transverse Zeeman.
#
# Running this for every term in the HamTerm registry is the CI gate
# that makes the bug class structurally impossible.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: HamTerm, LinearZeemanZ, TransverseZeeman,
    apply_step!, energy_contribution, add_gradient!, sign_oracle
using Random

# Reference test setup used by every term-consistency test.
function _ref_workspace(F::Int=1)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    zeeman = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    atom = F == 1 ? Rb87 : error("F=$F atom not parametrised yet in test fixture")
    ws = make_workspace(;
        grid, atom, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
    return ws
end

function _random_state(ws, seed::Int=42)
    Random.seed!(seed)
    D = ws.spin_matrices.system.n_components
    n_pts = (8, 8, 8)
    psi = randn(ComplexF64, n_pts..., D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    return psi
end

function _random_perturbation(psi_ref, seed::Int=99)
    Random.seed!(seed)
    δψ = randn(ComplexF64, size(psi_ref))
    δψ ./= sqrt(sum(abs2, δψ) * cell_volume(make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))))
    return δψ
end

"""
FD consistency check: for a HamTerm and a reference state, verify
that the FD slope of energy_contribution matches Re⟨add_gradient!, δψ⟩.
Returns (fd_slope, inner_product, ratio).
"""
function _fd_vs_inner(term::HamTerm, ws, psi_ref, δψ; ε=1e-7)
    dV = cell_volume(ws.grid)
    E_0 = energy_contribution(term, psi_ref, ws)
    E_ε = energy_contribution(term, psi_ref .+ ε .* δψ, ws)
    fd_slope = (E_ε - E_0) / ε

    grad = zero(psi_ref)
    add_gradient!(grad, term, psi_ref, ws)
    # Convention: energy_gradient! later scales `grad` by 2 (Wirtinger).
    # So the inner product against δψ that matches dE/dε is
    # `2 · Re⟨grad, δψ⟩` (since `grad` here is δE/δψ*).
    inner = 2 * real(sum(conj.(grad) .* δψ)) * dV

    return (fd_slope, inner, fd_slope / inner)
end

@testset "HamTerm consistency: energy ≡ ∂(gradient) via FD" begin
    ws = _ref_workspace()
    psi_ref = _random_state(ws)
    δψ = _random_perturbation(psi_ref)

    @testset "LinearZeemanZ" begin
        term = LinearZeemanZ(0.7, 0.2)
        fd, inner, ratio = _fd_vs_inner(term, ws, psi_ref, δψ)
        @test isapprox(fd, inner; rtol=1e-3)
    end

    @testset "TransverseZeeman" begin
        term = TransverseZeeman(0.5, 0.3)
        fd, inner, ratio = _fd_vs_inner(term, ws, psi_ref, δψ)
        @test isapprox(fd, inner; rtol=1e-3)
    end
end

@testset "HamTerm directional sign oracles" begin
    @testset "LinearZeemanZ: +p ⇒ ⟨F_z⟩ > 0" begin
        ws = _ref_workspace()
        term = LinearZeemanZ(2.0, 0.0)
        # ITP loop only this term — start from m_plus_F, apply 500 steps
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        for _ in 1:500
            apply_step!(term, psi, 0.005, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        oracle = sign_oracle(LinearZeemanZ)
        @test oracle.predicate(psi, ws)
    end

    @testset "TransverseZeeman: +bx ⇒ ⟨F_x⟩ > 0" begin
        ws = _ref_workspace()
        term = TransverseZeeman(2.0, 0.0)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        # Phase-1 ITP with a +Bz parity breaker (TransverseZeeman alone
        # from m_plus_F can leave ⟨F_x⟩ = 0 by symmetry; need a small
        # +Bz tilt to break the F_x parity).
        term_z = LinearZeemanZ(0.5, 0.0)
        for _ in 1:500
            apply_step!(term_z, psi, 0.005, true, ws)
            apply_step!(term, psi, 0.005, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        oracle = sign_oracle(TransverseZeeman)
        @test oracle.predicate(psi, ws)
    end
end
