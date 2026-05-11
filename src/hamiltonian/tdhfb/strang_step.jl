# TDHFB Strang split-step integrator — voxel-local BdG matrix exponential.
#
# Strang factorization:
#
#   V(dt/2)  HF(dt/2)  K(dt)  HF(dt/2)  V(dt/2)
#
# where
#   V  = trap step on φ              (one-body diagonal potential)
#   K  = kinetic step on φ           (FFT)
#   HF = voxel-local BdG step on
#        (φ, ρ, κ) under the local
#        BdG generator W(r)          (the new substep this file implements)
#
# In the local approximation, ρ and κ have no explicit ∂_r kinetic content;
# their kinetic structure lives in the off-diagonal blocks of W via U and Δ.
#
# HF substep at each spatial point r — TWO BdG generators (Stoof 1999 /
# Castin-Dum / Holzmann-Castin particle-conserving form). The condensate φ
# and the quasi-particle modes (ρ, κ) see DIFFERENT effective potentials:
#
#   For φ Nambu doublet (φ, φ*):
#     U^φ_{a,b} = Σ V_{a,b;c,d} (φ*_c φ_d + 2 ρ_{c,d})    ← factor 1 on φ*φ,
#                                                            factor 2 on ρ
#     Δ^φ_{a,b} = Σ V_{a,b;c,d} κ_{c,d}                    ← NO φφ source
#     W^φ      = [[U^φ, Δ^φ], [-conj(Δ^φ), -conj(U^φ)]]
#
#   For (ρ, κ) Nambu density R:
#     U^R_{a,b} = 2 Σ V_{a,b;c,d} (φ*_c φ_d + ρ_{c,d})    ← factor 2 everywhere
#                 (this is `hf_matrix_generic!`)
#     Δ^R_{a,b} = Σ V_{a,b;c,d} (φ_c φ_d + κ_{c,d})        ← full pair source
#                 (this is `pair_potential_generic!`)
#     W^R      = [[U^R, Δ^R], [-conj(Δ^R), -conj(U^R)]]
#
# The asymmetry is what makes TDHFB reduce to GP at ρ = κ = 0 (then Δ^φ = 0
# and U^φ = V·(φ*φ) gives the standard GP self-interaction — verified by
# conservation test C5). It is also what makes particle number exactly
# conserved (C3).
#
# The matrix exponentials M^φ = exp(-i W^φ dt), M^R = exp(-i W^R dt) are
# computed via Julia's general `Base.exp` (Padé) since both W's are
# pseudo-Hermitian but NOT Hermitian.
#
# Within the HF substep both updates are done sequentially; their
# non-commutation is O(dt²) per substep, of the same order as the outer
# Strang remainder, so the overall scheme stays second-order globally
# (validated by C4: energy drift < 1e-6 over T = 5).
#
# Conservation guarantees (validated by test/hamiltonian/test_tdhfb_conservation.jl):
#   - Particle number N = ∫ (|φ|² + tr ρ)     conserved to ~1e-8 over T = 2
#   - ρ Hermiticity                           preserved to ~1e-10 over N steps
#   - κ symmetry                              preserved to ~1e-10 over N steps
#   - Total energy E[φ, ρ, κ]                 relative drift < 1e-6 over T = 5
#   - ρ = κ = 0 limit                         exactly reproduces F=1 GP

export tdhfb_strang_step!

"""
    tdhfb_strang_step!(state, F, g_S, V_ext, dt; k_squared=nothing, fft_plans=nothing)

Advance `state::TDHFBState{N}` by one Strang split-step of duration `dt`.

The order is `V(dt/2) HF(dt/2) K(dt) HF(dt/2) V(dt/2)`. The inner HF substep
is a voxel-local Bogoliubov-de Gennes matrix exponential that evolves
`(φ, ρ, κ)` together under the local generator `W = [[U, Δ]; [-Δ̄, -Ū]]`.

# Arguments
- `state::TDHFBState{N}`: mutated in place (φ, ρ, κ, t, step all updated).
- `F::Int`: spin quantum number.
- `g_S::AbstractDict{Int, Float64}`: channel couplings keyed by S.
- `V_ext::AbstractArray{<:Real}`: external potential, shape `(spatial..., D)`.
- `dt::Float64`: time step.

# Keyword arguments
- `k_squared::AbstractArray{<:Real, N}`: precomputed `|k|²` for the FFT
  kinetic step. If `nothing`, a default `dx = 1, L = nx_d` grid is used
  (matches the box convention of the energy functional).
- `fft_plans`: reserved for future precomputed FFT plans (currently unused;
  the kinetic step allocates per call).

# Returns
The state (mutated in place).
"""
function tdhfb_strang_step!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64;
    k_squared=nothing,
    fft_plans=nothing,
) where {N}
    # V step (dt/2): one-body trap on φ
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    # HF step (dt/2): voxel-local BdG matrix exponential on (φ, ρ, κ)
    _tdhfb_hf_step!(state, F, g_S, dt / 2)

    # K step (dt): FFT kinetic on φ
    _tdhfb_kinetic_step!(state.phi, dt; k_squared=k_squared)

    # HF step (dt/2)
    _tdhfb_hf_step!(state, F, g_S, dt / 2)

    # V step (dt/2)
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    state.t += dt
    state.step += 1
    return state
end

"""
Trap potential step on φ:  φ_m(r) ← exp(-i V_ext[r, m] dt) · φ_m(r)
"""
function _tdhfb_v_step!(phi::AbstractArray, V_ext::AbstractArray, dt::Float64)
    sz = size(phi)
    D = sz[end]
    @assert size(V_ext, ndims(V_ext)) == D
    @inbounds for idx in CartesianIndices(size(phi)[1:end-1]), m in 1:D
        phi[idx, m] *= cis(-V_ext[idx, m] * dt)
    end
    return phi
end

"""
Voxel-local Hartree-Fock + anomalous step.

Inner symmetric Strang for the coupled (φ, ρ, κ) HF substep:
    φ(dt/2)  →  R(dt)  →  φ(dt/2)

φ is updated using the current (ρ, κ); the R update is then done with the
new φ; the final φ sub-update uses the new (ρ, κ). This makes the inner HF
substep second-order in dt (without it, the operator-splitting error is
O(dt) per substep — fine for kinematic tests, but too coarse for the
energy-conservation test C4).

Convention reminder: `rho[idx, c, c'] = ⟨m(c) | ρ̂ | m(c')⟩` (standard
matrix); `kappa[idx, c, c'] = ⟨ψ_m(c) ψ_m(c')⟩` (symmetric in c, c').
"""
function _tdhfb_hf_step!(
    state::TDHFBState{N}, F::Int, g_S::AbstractDict{Int, Float64}, dt::Float64
) where {N}
    # Symmetric inner Strang for the coupled HF substep.
    V = channel_kernel(F, g_S)
    half = dt / 2
    _tdhfb_phi_subupdate!(state, F, g_S, V, half)  # uses current (ρ, κ)
    _tdhfb_R_subupdate!(state, F, g_S, V, dt)      # uses new φ
    _tdhfb_phi_subupdate!(state, F, g_S, V, half)  # uses new (ρ, κ)
    return state
end

# φ Nambu doublet sub-update: φ ← top(M^φ · (φ, conj(φ))).
# U^φ_{a,b} = V·(φ*φ + 2ρ),  Δ^φ_{a,b} = V·κ.
function _tdhfb_phi_subupdate!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V::AbstractArray{Float64, 4},
    dt::Float64,
) where {N}
    D = 2 * F + 1
    sz = size(state.phi)
    n_spatial = length(sz) - 1
    spatial = sz[1:n_spatial]
    twoD = 2 * D

    @inbounds for idx in CartesianIndices(spatial)
        # Build U^φ and Δ^φ at this voxel.
        U_phi = zeros(ComplexF64, D, D)
        Delta_phi = zeros(ComplexF64, D, D)
        for c in 1:D, c_p in 1:D
            uval = ComplexF64(0)
            dval = ComplexF64(0)
            for c2 in 1:D, c2_p in 1:D
                Vk = V[c, c_p, c2, c2_p]
                Vk == 0.0 && continue
                # U^φ:  φ*_{c2_p} φ_{c2}  +  2 ρ_{c2_p, c2}
                uval += Vk * (conj(state.phi[idx, c2_p]) * state.phi[idx, c2]
                              + 2 * state.rho[idx, c2_p, c2])
                # Δ^φ:  κ_{c2, c2_p}                  (no φφ source)
                dval += Vk * state.kappa[idx, c2, c2_p]
            end
            U_phi[c, c_p] = uval
            Delta_phi[c, c_p] = dval
        end

        # Assemble W^φ = [[U^φ, Δ^φ], [-conj(Δ^φ), -conj(U^φ)]].
        W = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            W[c, c_p]           = U_phi[c, c_p]
            W[c, D + c_p]       = Delta_phi[c, c_p]
            W[D + c, c_p]       = -conj(Delta_phi[c, c_p])
            W[D + c, D + c_p]   = -conj(U_phi[c, c_p])
        end

        # General matrix exponential.
        M = exp(-1im * W * dt)

        # Apply to (φ, conj(φ)) doublet.
        phi_vec = Vector{ComplexF64}(undef, twoD)
        for c in 1:D
            phi_vec[c]     = state.phi[idx, c]
            phi_vec[D + c] = conj(state.phi[idx, c])
        end
        new_phi = M * phi_vec
        for c in 1:D
            state.phi[idx, c] = new_phi[c]
        end
    end
    return state
end

# (ρ, κ) Nambu density sub-update: R ← M^R · R · (M^R)^{-1}.
# U^R = 2V·(φ*φ + ρ),  Δ^R = V·(φφ + κ).
function _tdhfb_R_subupdate!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V::AbstractArray{Float64, 4},
    dt::Float64,
) where {N}
    D = 2 * F + 1
    sz = size(state.phi)
    n_spatial = length(sz) - 1
    spatial = sz[1:n_spatial]
    twoD = 2 * D

    @inbounds for idx in CartesianIndices(spatial)
        # Build U^R and Δ^R at this voxel.
        U_R = zeros(ComplexF64, D, D)
        Delta_R = zeros(ComplexF64, D, D)
        for c in 1:D, c_p in 1:D
            uval = ComplexF64(0)
            dval = ComplexF64(0)
            for c2 in 1:D, c2_p in 1:D
                Vk = V[c, c_p, c2, c2_p]
                Vk == 0.0 && continue
                # U^R:  2 V·(φ*φ + ρ)
                uval += 2 * Vk * (conj(state.phi[idx, c2_p]) * state.phi[idx, c2]
                                  + state.rho[idx, c2_p, c2])
                # Δ^R:  V·(φφ + κ)
                dval += Vk * (state.phi[idx, c2] * state.phi[idx, c2_p]
                              + state.kappa[idx, c2, c2_p])
            end
            U_R[c, c_p] = uval
            Delta_R[c, c_p] = dval
        end

        # Assemble W^R.
        W = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            W[c, c_p]           = U_R[c, c_p]
            W[c, D + c_p]       = Delta_R[c, c_p]
            W[D + c, c_p]       = -conj(Delta_R[c, c_p])
            W[D + c, D + c_p]   = -conj(U_R[c, c_p])
        end

        M = exp(-1im * W * dt)

        # R(t+dt) = M · R · M^{-1}.
        R = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            R[c, c_p]           = state.rho[idx, c, c_p]
            R[c, D + c_p]       = state.kappa[idx, c, c_p]
            R[D + c, c_p]       = conj(state.kappa[idx, c, c_p])
            R[D + c, D + c_p]   = (c == c_p ? one(ComplexF64) : zero(ComplexF64)) +
                                  conj(state.rho[idx, c, c_p])
        end
        Minv = inv(M)
        R_new = M * R * Minv

        # Read back; project ρ Hermitian and κ symmetric.
        for c in 1:D, c_p in 1:D
            rho_new   = R_new[c, c_p]
            rho_new_T = R_new[c_p, c]
            state.rho[idx, c, c_p] = 0.5 * (rho_new + conj(rho_new_T))

            kappa_new   = R_new[c, D + c_p]
            kappa_new_T = R_new[c_p, D + c]
            state.kappa[idx, c, c_p] = 0.5 * (kappa_new + kappa_new_T)
        end
    end
    return state
end

"""
Kinetic step on φ via FFT.

`k_squared::AbstractArray{<:Real, N}` is the precomputed `|k|²` grid; if
`nothing`, a default grid with `dx = 1, L = nx_d` is built (matches the
energy functional's default — so conservation tests on tiny grids are
self-consistent).
"""
function _tdhfb_kinetic_step!(
    phi::AbstractArray, dt::Float64; k_squared=nothing, fft_plans=nothing
)
    sz = size(phi)
    D = sz[end]
    n_spatial = length(sz) - 1
    spatial = sz[1:n_spatial]

    if k_squared === nothing
        k_squared = _default_tdhfb_k_squared(spatial)
    end
    @assert size(k_squared) == spatial "k_squared shape must match spatial dims"

    # exp(-i (1/2) k² dt) — kinetic phase (ℏ=m=1)
    kinetic_phase = cis.(-0.5 .* k_squared .* dt)

    for m in 1:D
        phi_m = view(phi, ntuple(_ -> Colon(), n_spatial)..., m)
        phi_k = fft(collect(phi_m))
        phi_k .*= kinetic_phase
        phi_back = ifft(phi_k)
        @inbounds for idx in CartesianIndices(size(phi_m))
            phi_m[idx] = phi_back[idx]
        end
    end
    return phi
end
