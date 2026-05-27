# --- Reference loss kernels (K3, L3, dipolar) + analytic uniform-density
# K3 rate test ---
#
# Production lives in src/hamiltonian/interactions/losses.jl as
# `apply_loss_step!`. Production multiplies ψ by exp(-rate·dt/2) twice
# per step (Strang-symmetric loss substep). Reference: apply the
# *rate* directly to ψ — the "Hψ" of a dissipative term is purely
# imaginary in the Lindblad sense, so we keep the analytic uniform-n
# closed form as the strongest test rather than chasing operator-level
# diff.
#
# Conventions (parameter contract §7):
#   True 3-body K3:  dn_m/dt = -K3 · n² · n_m       (n = total density)
#                    → propagator: ψ_m(r,t) = ψ_m(r,0) · exp(-(K3/2) · n² · t)
#                                              for uniform n.
#   Legacy L3:       dn_m/dt = -L3 · n · n_m        (linear in n)
#   Dipolar:         dn_m/dt = -γ_dr_m · n · n_m    (m-dependent rate)

export reference_k3_rate_apply!
export reference_k3_uniform_analytic
export reference_l3_rate_apply!

"""
    reference_k3_rate_apply!(out, psi, K3)

Write the true 3-body K3 *rate* operator action: out_c(r) = (K3/2) · n²(r) · ψ_c(r).

Production's `apply_loss_step!` multiplies ψ by `exp(-rate·dt)`; here
we return the operator that exponentiates. Compare via finite-difference
of the production step: `(ψ_before - ψ_after) / dt ≈ rate·ψ`.
"""
function reference_k3_rate_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    K3::Real,
)
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_comp = size(psi, ndim + 1)
    n_density = total_density(psi, ndim)
    coeff = 0.5 * K3
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        out_c = view(out, idx...)
        @. out_c = coeff * n_density * n_density * psi_c
    end
    out
end

"""
    reference_k3_uniform_analytic(n0, K3, t) → Float64

Analytic solution to `dn/dt = -K3 n³` (no spatial variation): returns
`n(t) = n0 / sqrt(1 + 2 K3 n0² t)`.

Acceptance criterion for production: time-evolve a uniform-density
state under `loss:` only (no Hamiltonian) for time t, compare
spatial-mean density against this. Tolerance dominated by integrator
order (Strang loss step is exact for uniform density, so should match
to machine precision modulo norm-renormalisation).
"""
function reference_k3_uniform_analytic(n0::Real, K3::Real, t::Real)
    n0_f = Float64(n0)
    n0_f / sqrt(1.0 + 2.0 * K3 * n0_f * n0_f * t)
end

"""
    reference_l3_rate_apply!(out, psi, L3)

Legacy 2-body linear loss: rate = (L3/2) · n(r) · ψ_c(r).
"""
function reference_l3_rate_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    L3::Real,
)
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_comp = size(psi, ndim + 1)
    n_density = total_density(psi, ndim)
    coeff = 0.5 * L3
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        out_c = view(out, idx...)
        @. out_c = coeff * n_density * psi_c
    end
    out
end
