# TDHFB total energy functional E[φ, ρ, κ].
#
# Conserved by Hamiltonian TDHFB dynamics. The functional is designed so that
# δE/δφ*_m = i ∂_t φ_m (variational consistency with the equations of motion):
#
#   E = E_kin + E_trap + E_int
#
# where, in the local approximation,
#
#   E_kin  = Σ_m ∫ |∇φ_m(r)|² dr                                       (mean field only;
#                                                                       ρ, κ have no
#                                                                       explicit kinetic
#                                                                       in r in the local
#                                                                       limit)
#
#   E_trap = Σ_m ∫ V_ext(r, m) (|φ_m(r)|² + ρ_{m,m}(r)) dr
#
#   E_int  = (1/2) Σ_{c, c', c2, c2'} V_{c c'; c2 c2'} ×
#              [ φ_{c'}* φ_{c2'}* φ_{c} φ_{c2}                          (mean-field φ⁴)
#              + 2 ρ_{c, c'} φ_{c2'}* φ_{c2}                            (φ²ρ cross, ×2 from
#                                                                       the two equivalent
#                                                                       pair labels)
#              + ρ_{c, c'} ρ_{c2, c2'}                                  (ρρ)
#              + κ_{c, c2}* κ_{c', c2'}                                 (κ*κ)
#              + Re( φ_{c} φ_{c2} κ_{c', c2'}* ) ]                      (φφ κ* cross + h.c.)
#
# V is the un-symmetrized channel kernel (`channel_kernel`). The factor 1/2 is
# the standard Bose two-body normalization. The cross term `Re(...)` is twice
# the real part of one summand — it represents `(φφ)*κ + (φφ) κ*` symmetrized.
#
# Validation: test C4 (`test_tdhfb_conservation.jl`) asserts relative drift
# < 1e-6 over T = 5 ω⁻¹ at dt = 0.01, which is the operational Noether check
# that this functional is consistent with the EOMs implemented in
# `tdhfb_strang_step!`.

export tdhfb_energy

"""
    tdhfb_energy(state, F, g_S, V_ext; k_squared=nothing, dV=1.0) -> Float64

Total TDHFB energy `E[φ, ρ, κ]` (real scalar). Conserved by
`tdhfb_strang_step!`.

# Arguments
- `state::TDHFBState`: current TDHFB state
- `F::Int`: spin quantum number
- `g_S::AbstractDict{Int, Float64}`: channel couplings
- `V_ext::AbstractArray{<:Real}`: external potential, shape `(spatial..., D)`
  (m-dependent, e.g. `V_ext[r, m] = V_trap(r) + V_Zeeman(m)`)

# Keyword arguments
- `k_squared::AbstractArray{<:Real, N}`: precomputed `|k|²` grid for the FFT
  kinetic step. If `nothing`, a default `dx = 1, L = nx_d` grid is built (this
  matches the box convention used by `_tdhfb_kinetic_step!` when no grid is
  given, so the conservation test C4 is self-consistent).
- `dV::Real`: spatial volume element (e.g. `prod(dx)`). Default 1.0.

# Returns
The total energy as a `Float64`.

# Notes
- The interaction term uses the un-symmetrized channel kernel `V`; the factor
  1/2 is the standard Bose two-body normalization.
- ρ-trap and φ-trap contributions are summed separately (`ρ_{m,m}` is the
  non-condensed density).
- All cross terms are taken via `real(...)` to be robust against
  accumulated complex round-off.
"""
function tdhfb_energy(state::TDHFBState, F::Int,
                      g_S::AbstractDict{Int, Float64},
                      V_ext::AbstractArray{<:Real};
                      k_squared::Union{Nothing, AbstractArray{<:Real}}=nothing,
                      dV::Real=1.0)
    D = 2 * F + 1
    phi = state.phi
    rho = state.rho
    kappa = state.kappa

    sz_phi = size(phi)
    n_spatial = length(sz_phi) - 1
    spatial = sz_phi[1:n_spatial]

    @assert sz_phi[end] == D "phi spinor dim mismatch (got $(sz_phi[end]), expected $D)"

    # Default k²: dx=1 box with L = nx_d in each direction (matches the
    # default kinetic step in `_tdhfb_kinetic_step!`).
    if k_squared === nothing
        k_squared = _default_tdhfb_k_squared(spatial)
    end
    @assert size(k_squared) == spatial "k_squared shape must match spatial dims"

    # --- E_kin: Σ_m ∫ |∇φ_m|² dr  via Parseval (∫ |∇φ|² = Σ_k k² |φ̂_k|² / N_spatial)
    n_pts = prod(spatial)
    E_kin = 0.0
    for m in 1:D
        phi_m = view(phi, ntuple(_ -> Colon(), n_spatial)..., m)
        phi_k = fft(collect(phi_m))
        for idx in CartesianIndices(spatial)
            E_kin += k_squared[idx] * abs2(phi_k[idx])
        end
    end
    # Continuum normalization: ∫|∇φ|² dr ≈ (dV / n_pts) Σ_k k² |φ̂_k|² with the
    # FFT convention that ∑_x f(x) g*(x) = (1/n_pts) Σ_k f̂_k ĝ_k*. Together
    # with dV (cell volume), this gives the continuum integral.
    E_kin *= 0.5 * dV / n_pts  # 0.5 from ½|∇φ|² (kinetic, ℏ=m=1)

    # --- E_trap
    E_trap = 0.0
    for idx in CartesianIndices(spatial), m in 1:D
        E_trap += V_ext[idx, m] * (abs2(phi[idx, m]) + real(rho[idx, m, m]))
    end
    E_trap *= dV

    # --- E_int (channel-decomposed two-body)
    V = channel_kernel(F, g_S)
    E_int = 0.0
    for idx in CartesianIndices(spatial)
        s = 0.0
        for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
            Vk = V[c, c_p, c2, c2_p]
            Vk == 0.0 && continue
            phi_c = phi[idx, c]
            phi_cp = phi[idx, c_p]
            phi_c2 = phi[idx, c2]
            phi_c2p = phi[idx, c2_p]
            rho_cc = rho[idx, c, c_p]
            rho_22 = rho[idx, c2, c2_p]
            kappa_cc2 = kappa[idx, c, c2]
            kappa_pp = kappa[idx, c_p, c2_p]

            # φ⁴
            phi4 = conj(phi_cp) * conj(phi_c2p) * phi_c * phi_c2
            # φ²ρ (×2 factor: two equivalent pair labels)
            phi2_rho = 2 * rho_cc * conj(phi_c2p) * phi_c2
            # ρρ
            rho_rho = rho_cc * rho_22
            # κ*κ
            kk = conj(kappa_cc2) * kappa_pp
            # (φφ)·κ* + h.c. = 2 Re((φφ)·κ*)
            cross = 2 * real(phi_c * phi_c2 * conj(kappa_pp))

            s += Vk * real(phi4 + phi2_rho + rho_rho + kk + cross)
        end
        E_int += s
    end
    E_int *= 0.5 * dV

    return E_kin + E_trap + E_int
end

# `_default_tdhfb_k_squared` is defined in `strang_step.jl` and loaded before
# this file by the `hamiltonian/tdhfb.jl` umbrella. Sharing one helper keeps
# the kinetic-energy expectation in `tdhfb_energy` numerically consistent with
# the kinetic propagator in `_tdhfb_kinetic_step!`.
