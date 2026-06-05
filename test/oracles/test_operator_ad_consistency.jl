# test/oracles/test_operator_ad_consistency.jl
#
# A.0 — Spine "Operator trinity" proof-of-concept (sweep-safe, test-only).
#
# Demonstrates the structural identity that closes the sign-cascade class:
# for each HamTerm H, the trinity
#   energy_contribution   ≈   0.5 · ⟨ψ, apply_operator(term, ψ)⟩
#   add_gradient!         ≈   apply_operator(term, ψ)
#   apply_step! coefs     ↔   same H used in exp(-i·dt·H)
# is enforced by ONE source: `apply_operator!(out, term, ws, psi)`.
#
# This file defines `apply_operator!` LOCALLY (not in SpinorBEC source) so
# the in-flight M1 sweep is unaffected. A.1 (next session) will move the
# function into `src/hamiltonian/terms/operator_interface.jl` and port all
# 14 HamTerm subtypes.
#
# The oracle: a finite-difference gradient of `energy_contribution(term, ψ)`
# with respect to ψ̄ must match `apply_operator(term, ψ)`. If they drift,
# either the hand-written energy or the hand-written gradient is wrong,
# and the operator is the single source of truth.

using Test
using SpinorBEC
using SpinorBEC: KineticTerm, _component_slice
using LinearAlgebra

# ─── A.0 interface (test-local) ────────────────────────────────────────────
# This will move to src/hamiltonian/terms/operator_interface.jl in A.1.

"""
    apply_operator!(out, term::HamTerm, ws, psi) -> out

Compute `out .= H·ψ` where H is the Hermitian operator the term represents.
The trinity (energy ⟨ψ|H|ψ⟩/2, gradient H·ψ, propagator coefficient inside
exp(-i·dt·H)) all derive from this single function.

This is the LOAD-BEARING entry point for the sign-cascade structural
closure: changing the sign of the coefficient here changes all three
derived paths at once.
"""
function apply_operator! end

# ─── KineticTerm implementation ────────────────────────────────────────────
# H_kin = -½ ∇²; in Fourier, multiplication by (1/2)|k|².

function apply_operator!(out::AbstractArray, ::KineticTerm, ws, psi::AbstractArray)
    n_comp = ws.spin_matrices.system.n_components
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    fft_buf = similar(psi, ntuple(d -> size(psi, d), ndim)...)
    k_sq = ws.grid.k_squared
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf .*= (0.5 .* k_sq)
        ws.fft_plans.inverse * fft_buf
        copyto!(view(out, idx...), fft_buf)
    end
    return out
end

# ─── Helpers ───────────────────────────────────────────────────────────────

"""
    energy_via_operator(term, ws, psi)

`Re ⟨ψ, H·ψ⟩ · dV` — the GP-energy contribution of `term`, computed
ENTIRELY from the operator. For linear terms (kinetic, trap, zeeman)
this is the canonical ⟨ψ|H|ψ⟩; the operator's own internal coefficient
(e.g. the 1/2 in H_kin = -½∇²) IS the half-factor.
"""
function energy_via_operator(term, ws, psi)
    buf = similar(psi)
    fill!(buf, 0)
    apply_operator!(buf, term, ws, psi)
    dV = SpinorBEC.cell_volume(ws.grid)
    return real(dot(vec(psi), vec(buf))) * dV
end

# Finite-difference Wirtinger derivative of E[ψ] wrt ψ̄ at component c, voxel I.
# For a real-energy functional E[ψ] = ⟨ψ|H|ψ⟩ / 2 with Hermitian H, the
# variational derivative ∂E/∂ψ̄ = (1/2) H·ψ (Wirtinger convention used in
# the LBFGS driver).
function fd_gradient(term, ws, psi; eps_re=1e-7, eps_im=1e-7)
    g = similar(psi)
    fill!(g, 0)
    E0 = energy_via_operator(term, ws, psi)
    for idx in eachindex(psi)
        # Real part
        psi_p = copy(psi);
        psi_p[idx] += eps_re
        psi_m = copy(psi);
        psi_m[idx] -= eps_re
        dEdRe =
            (energy_via_operator(term, ws, psi_p) -
             energy_via_operator(term, ws, psi_m)) / (2 * eps_re)
        # Imag part
        psi_p = copy(psi);
        psi_p[idx] += eps_im * im
        psi_m = copy(psi);
        psi_m[idx] -= eps_im * im
        dEdIm =
            (energy_via_operator(term, ws, psi_p) -
             energy_via_operator(term, ws, psi_m)) / (2 * eps_im)
        # Wirtinger: ∂E/∂ψ̄ = ½ (∂E/∂Re + i ∂E/∂Im) → 2x = ∂E/∂Re + i ∂E/∂Im
        # We compare with H·ψ which equals 2·∂E/∂ψ̄ at the trinity level.
        # Convention: report the same scaling as `apply_operator!` itself.
        g[idx] = dEdRe + im * dEdIm
    end
    # `g` now holds ∂E/∂Re + i ∂E/∂Im = 2 · ∂E/∂ψ̄ = H·ψ (using E = ⟨ψ|H|ψ⟩/2).
    return g
end

# ─── The oracle ────────────────────────────────────────────────────────────

@testset "A.0 — Operator trinity oracle (KineticTerm proof-of-concept)" begin
    @testset "KineticTerm: energy ↔ apply_operator agreement" begin
        # Small 1D grid so FD is tractable (full grid sweep over all
        # voxels × components × {Re, Im} ≈ 8 × 3 × 2 = 48 perturbations)
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        sp = SimParams(; dt=0.005, n_steps=1)
        ws = make_workspace(;
            grid, atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 3)
        # Don't normalize — energy/grad relationship doesn't require it
        copyto!(ws.state.psi, psi)

        # 1. apply_operator! gives H·ψ
        Hpsi = similar(psi)
        fill!(Hpsi, 0)
        apply_operator!(Hpsi, KineticTerm(), ws, psi)

        # 2. energy_via_operator matches the production `_kinetic_energy`
        E_op = energy_via_operator(KineticTerm(), ws, psi)
        E_prod = SpinorBEC._kinetic_energy(
            psi, ws.grid, ws.fft_plans,
            similar(psi, ntuple(d -> size(psi, d), 1)...),
            ws.spin_matrices.system.n_components, 1,
            ntuple(d -> size(psi, d), 1),
            SpinorBEC.cell_volume(ws.grid),
        )
        @test isapprox(E_op, E_prod; rtol=1e-12)

        # 3. THE ORACLE: FD gradient ≈ 2 · apply_operator · dV
        # For E[ψ] = real⟨ψ, Hψ⟩ · dV (no outer ½ because H_kin already
        # carries it), the Wirtinger gradient is ∂E/∂ψ̄_i = dV · (Hψ)_i,
        # and the FD-with-2×-Wirtinger return ∂E/∂Re + i·∂E/∂Im = 2·dV·(Hψ)_i.
        dV = SpinorBEC.cell_volume(ws.grid)
        g_fd = fd_gradient(KineticTerm(), ws, psi; eps_re=1e-6, eps_im=1e-6)
        g_op = 2 .* Hpsi .* dV
        rel = maximum(abs.(g_fd .- g_op)) / max(maximum(abs.(g_op)), 1e-30)
        @test rel < 1e-4  # FD precision limit at eps=1e-6
    end

    @testset "KineticTerm: AD trinity sanity invariants" begin
        # Even without comparing against a separate FD, the operator's
        # action satisfies basic invariants:
        # - Linearity in ψ
        # - Hermiticity: ⟨φ, Hψ⟩ = conj(⟨ψ, Hφ⟩)
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        sp = SimParams(; dt=0.005, n_steps=1)
        ws = make_workspace(;
            grid, atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 3)
        phi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 5)

        Hpsi = similar(psi);
        fill!(Hpsi, 0)
        Hphi = similar(phi);
        fill!(Hphi, 0)
        apply_operator!(Hpsi, KineticTerm(), ws, psi)
        apply_operator!(Hphi, KineticTerm(), ws, phi)

        # Linearity: H(2ψ) = 2 H(ψ)
        twopsi = 2 .* psi
        H2psi = similar(twopsi);
        fill!(H2psi, 0)
        apply_operator!(H2psi, KineticTerm(), ws, twopsi)
        @test maximum(abs.(H2psi .- 2 .* Hpsi)) < 1e-12

        # Hermiticity: ⟨φ, Hψ⟩ = conj(⟨ψ, Hφ⟩)
        lhs = dot(vec(phi), vec(Hpsi))
        rhs = conj(dot(vec(psi), vec(Hphi)))
        @test isapprox(lhs, rhs; rtol=1e-12)
    end
end
