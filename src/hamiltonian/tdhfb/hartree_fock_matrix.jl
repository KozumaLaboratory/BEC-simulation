# TDHFB Hartree-Fock matrix kernel (Phase 2 minimal scope).
#
# Computes h^HF_{m,m'}(r) from spinor mean-field φ_m(r), normal density ρ(r), and
# anomalous density κ(r) for the spinor BEC two-body interaction.
#
# Currently implemented: F=1 (D=3) c_0/c_1 path (= scalar density + spin-spin).
# Generic F implementation via CG channel decomposition is Phase 2+ extension.
#
# Reference: tdhfb_pilot_design.md §"TDHFB equations" + Kawaguchi-Ueda 2012 §3.
#
# Phase 2 minimal scope = HF matrix kernel; full coupled (φ, ρ, κ) evolution +
# Strang TDHFB integrator + YAML pipeline integration are Phase 3-4.
#
# NOTE: this F=1 kernel is the GP-form (first functional derivative of E_int).
# It is the reference for the C5 GP-reduction conservation test. The generic
# `hf_matrix_generic!` returns the BdG self-energy (second derivative form,
# factor-2 Bose-symmetrized) — the two differ by exactly the factor 2 in the
# κ=0 case.

export hf_matrix_F1, hf_matrix_F1!

"""
    hf_matrix_F1!(h_hf, phi, rho, kappa, c0, c1) -> h_hf

Compute Hartree-Fock matrix h^HF[φ, ρ, κ] for F=1 spinor BEC, local approximation.

For F=1 with KU c_0/c_1 convention:
  H_int = (c_0/2) n² + (c_1/2) |F|²

Mean-field densities:
  n(r) = |φ|² + tr ρ
  F_α(r) = ⟨φ|F_α|φ⟩ + tr(F_α · ρ)

HF matrix (F=1 spinor space, 3×3):
  h^HF_{m,m'} = c_0 · n δ_{m,m'} + c_1 · Σ_α (F_α)_{m,m'} · F_α(r)
            + (correction terms involving κ for the anomalous channel)

This Phase 2 kernel implements the **F=1 c_0/c_1 reduced form** for proof-of-concept.
Generic F + g_S channel decomposition deferred to Phase 2 extension.

# Arguments
- `h_hf::Array{ComplexF64, N+2}`: output buffer, shape (spatial..., D=3, D=3)
- `phi::Array{ComplexF64, N+1}`: mean field, shape (spatial..., D=3)
- `rho::Array{ComplexF64, N+2}`: normal density, shape (spatial..., D=3, D=3)
- `kappa::Array{ComplexF64, N+2}`: anomalous density, shape (spatial..., D=3, D=3)
- `c0::Float64`: scalar contact coupling
- `c1::Float64`: spin-spin coupling

# Notes
- Local approximation: h^HF depends only on point r, not r' (≠ r').
- Hermiticity: h^HF[r, m, m'] = conj(h^HF[r, m', m]) — caller should verify.
- Kernel is in-place: modifies `h_hf` array.
- This is the simplest possible TDHFB HF kernel; production code should generalize
  to arbitrary F via CG decomposition.

# Returns
The h_hf array (for chaining).
"""
function hf_matrix_F1!(h_hf::AbstractArray, phi::AbstractArray,
                       rho::AbstractArray, kappa::AbstractArray,
                       c0::Float64, c1::Float64)
    # F=1 spin matrices in (+1, 0, -1) basis
    # F_z = diag(1, 0, -1)
    # F_+ = √2 · (|+1⟩⟨0| + |0⟩⟨-1|)
    # F_x = (F_+ + F_-) / 2 = (√2/2) · (|+1⟩⟨0| + |0⟩⟨-1| + |0⟩⟨+1| + |-1⟩⟨0|)
    # F_y = (F_+ - F_-) / (2i)

    sqrt2 = sqrt(2.0)
    Fz = ComplexF64[1.0 0 0; 0 0 0; 0 0 -1.0]
    Fx = ComplexF64[0 sqrt2/2 0; sqrt2/2 0 sqrt2/2; 0 sqrt2/2 0]
    Fy = ComplexF64[0 -sqrt2*im/2 0; sqrt2*im/2 0 -sqrt2*im/2; 0 sqrt2*im/2 0]

    sz = size(phi)
    n_spatial = length(sz) - 1
    D = sz[end]
    @assert D == 3 "F=1 HF kernel requires D=3 spinor"

    # For each spatial point, compute n, F_α and assemble h^HF
    for idx in CartesianIndices(size(phi)[1:n_spatial])
        # Mean field at this point: phi_m for m = +1, 0, -1 → index 1, 2, 3
        phi_p1 = phi[idx, 1]
        phi_0  = phi[idx, 2]
        phi_m1 = phi[idx, 3]

        # Scalar density n = |φ|² + tr ρ
        n_phi = abs2(phi_p1) + abs2(phi_0) + abs2(phi_m1)
        tr_rho = real(rho[idx, 1, 1] + rho[idx, 2, 2] + rho[idx, 3, 3])
        n_total = n_phi + tr_rho

        # Spin density F_α = ⟨φ|F_α|φ⟩ + tr(F_α · ρ)
        # ⟨φ|F_z|φ⟩ = |phi_p1|² - |phi_m1|²
        # ⟨φ|F_x|φ⟩ = (sqrt2/2) · 2 Re[phi_p1* phi_0 + phi_0* phi_m1]
        # ⟨φ|F_y|φ⟩ = (sqrt2/2) · 2 Im[phi_p1* phi_0 + phi_0* phi_m1] (= -2 Im[phi_p1 phi_0*])
        Fz_phi = abs2(phi_p1) - abs2(phi_m1)
        Fx_phi = sqrt2 * real(conj(phi_p1) * phi_0 + conj(phi_0) * phi_m1)
        Fy_phi = sqrt2 * imag(conj(phi_p1) * phi_0 + conj(phi_0) * phi_m1)

        # tr(F_α · ρ) — diagonal trace
        # F_z · ρ trace: ρ[1,1] - ρ[3,3]
        # F_x · ρ trace: (sqrt2/2)·(ρ[1,2] + ρ[2,1] + ρ[2,3] + ρ[3,2])
        # F_y · ρ trace: (sqrt2/2)·(...) for Fy structure
        tr_Fz_rho = real(rho[idx, 1, 1] - rho[idx, 3, 3])
        tr_Fx_rho = real(sqrt2/2 * (rho[idx, 1, 2] + rho[idx, 2, 1] + rho[idx, 2, 3] + rho[idx, 3, 2]))
        tr_Fy_rho = real(sqrt2*im/2 * (rho[idx, 2, 1] - rho[idx, 1, 2] + rho[idx, 3, 2] - rho[idx, 2, 3]))

        Fx_total = Fx_phi + tr_Fx_rho
        Fy_total = Fy_phi + tr_Fy_rho
        Fz_total = Fz_phi + tr_Fz_rho

        # Assemble h^HF = c_0 · n · I + c_1 · (F_x · F_x_total + F_y · F_y_total + F_z · F_z_total)
        # (suppressing anomalous contribution from κ at minimal Phase 2 scope)
        for m in 1:3, m_prime in 1:3
            val = c0 * n_total * (m == m_prime ? 1.0 : 0.0)
            val += c1 * (Fx[m, m_prime] * Fx_total +
                         Fy[m, m_prime] * Fy_total +
                         Fz[m, m_prime] * Fz_total)
            h_hf[idx, m, m_prime] = val
        end
    end

    return h_hf
end

"""
    hf_matrix_F1(phi, rho, kappa, c0, c1)

Allocating version of [`hf_matrix_F1!`](@ref).
"""
function hf_matrix_F1(phi::AbstractArray, rho::AbstractArray,
                      kappa::AbstractArray, c0::Float64, c1::Float64)
    h_hf = similar(rho)
    return hf_matrix_F1!(h_hf, phi, rho, kappa, c0, c1)
end

# Smoke test: at the trivial vacuum (rho=0, kappa=0), h^HF reduces to
# mean-field-only c_0 |φ|² + c_1 |⟨F⟩|² contributions.
function _test_hf_matrix_F1_vacuum()
    # Test on a 1D grid with 4 points
    nx = 4
    phi = zeros(ComplexF64, nx, 3)
    rho = zeros(ComplexF64, nx, 3, 3)
    kappa = zeros(ComplexF64, nx, 3, 3)

    # Initialize phi to a polar state: phi = (0, 1, 0)
    phi[:, 2] .= 1.0 + 0im

    c0 = 1.0
    c1 = 0.1

    h_hf = hf_matrix_F1(phi, rho, kappa, c0, c1)

    # Expected: polar mean-field, ⟨F⟩ = 0, n = 1 everywhere
    # h^HF = c_0 · 1 · I = diag(c_0, c_0, c_0)
    # Plus c_1 · 0 (zero ⟨F⟩ contribution) = 0
    # So h^HF_{m,m'} = c_0 · δ_{m,m'} = δ_{m,m'}
    for i in 1:nx, m in 1:3, m_prime in 1:3
        expected = (m == m_prime) ? c0 : 0.0
        @assert abs(h_hf[i, m, m_prime] - expected) < 1e-12 "F=1 vacuum HF mismatch at ($i, $m, $m_prime)"
    end
    return true
end
