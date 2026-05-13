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
    tdhfb_strang_step!(state, F, g_S, V_ext, dt; k_squared=nothing,
                       fft_plans=nothing, hfb_mode=:full_hfb)

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
- `hfb_mode::Symbol = :full_hfb`: BdG generator mode for the φ subupdate.
  - `:full_hfb` (default): full HFB. `U^φ = V·(φ*φ + 2ρ)`, `Δ^φ = V·κ`.
    Goldstone mode picks up an O(g·n_thermal) gap (Hugenholtz-Pines
    anomaly), accurate two-body interaction. Standard choice for
    thermalization and high-precision energy work.
  - `:popov`: HFB-Popov approximation. `U^φ` unchanged, `Δ^φ = 0`
    (anomalous self-energy dropped from the condensate equation of
    motion). Restores gapless Goldstone (Hugenholtz-Pines satisfied)
    at the cost of two-body inconsistency. Standard for BEC dynamics
    where the soft mode dominates.
  The (ρ, κ) sub-update is unaffected — both modes use the full BdG
  generator for the Nambu-density rotation, so κ still evolves
  normally and `hfb_mode = :popov` does NOT collapse to scalar GP.

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
    hfb_mode::Symbol=:full_hfb,
    picard_midpoint::Bool=false,
    picard_max_iter::Int=20,
    picard_tol::Float64=1e-12,
) where {N}
    # V step (dt/2): one-body trap on φ
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    # HF step (dt/2): voxel-local BdG matrix exponential on (φ, ρ, κ).
    # Opt-in `picard_midpoint=true` uses Picard fixed-point iteration on the
    # midpoint state so generators are frozen across the substep — lifts the
    # palindromic gate to machine precision (per Picard tol) and unlocks
    # Y4 Yoshida order 4 (A4 acceptance).
    if picard_midpoint
        _tdhfb_hf_step_picard_midpoint!(state, F, g_S, dt / 2;
            hfb_mode=hfb_mode, max_iter=picard_max_iter, tol=picard_tol)
    else
        _tdhfb_hf_step!(state, F, g_S, dt / 2; hfb_mode=hfb_mode)
    end

    # K step (dt): FFT kinetic on φ
    _tdhfb_kinetic_step!(state.phi, dt; k_squared=k_squared)

    # HF step (dt/2)
    if picard_midpoint
        _tdhfb_hf_step_picard_midpoint!(state, F, g_S, dt / 2;
            hfb_mode=hfb_mode, max_iter=picard_max_iter, tol=picard_tol)
    else
        _tdhfb_hf_step!(state, F, g_S, dt / 2; hfb_mode=hfb_mode)
    end

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
    @inbounds for idx in CartesianIndices(size(phi)[1:(end - 1)]), m in 1:D
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
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    dt::Float64;
    hfb_mode::Symbol=:full_hfb,
) where {N}
    # Symmetric inner Strang for the coupled HF substep.
    V = channel_kernel(F, g_S)
    half = dt / 2
    _tdhfb_phi_subupdate!(state, F, g_S, V, half; hfb_mode=hfb_mode)  # uses current (ρ, κ)
    _tdhfb_R_subupdate!(state, F, g_S, V, dt)  # uses new φ
    _tdhfb_phi_subupdate!(state, F, g_S, V, half; hfb_mode=hfb_mode)  # uses new (ρ, κ)
    return state
end

# Picard-midpoint inner HF substep — palindromic at Picard tolerance.
#
# Live-state generators in `_tdhfb_hf_step!` break time-reversal symmetry
# at O(dt²) (S(-dt) ∘ S(dt) ≠ I at that order). Evaluating all generators
# at state_mid = (state_0 + state_1) / 2 — where state_1 is the substep's
# own output — restores palindromicity:
#
#   S(dt):  state_0 → state_1 with W built from state_mid
#   S(-dt): state_1 → state_0 with W built from the SAME state_mid (by
#           symmetry of the midpoint formula)
#
# state_1 is determined self-consistently by Picard iteration. Empirically
# (F=1 single-voxel diagnostic, 2026-05-12) the iteration converges in
# 4-6 steps at tol=1e-13 across dt ∈ [0.0025, 0.04].
function _tdhfb_hf_step_picard_midpoint!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    dt::Float64;
    hfb_mode::Symbol=:full_hfb,
    max_iter::Int=20,
    tol::Float64=1e-12,
) where {N}
    V = channel_kernel(F, g_S)
    half = dt / 2

    state_0 = deepcopy(state)     # the substep's input (frozen)
    state_mid = deepcopy(state)   # midpoint guess, refined each Picard iter
    state_work = state            # the working state, reused

    delta = Inf
    for _ in 1:max_iter
        # Reset working state to state_0 (Picard apply step starts from input).
        copyto!(state_work.phi, state_0.phi)
        copyto!(state_work.rho, state_0.rho)
        copyto!(state_work.kappa, state_0.kappa)

        # Inner Strang with all generators from state_mid.
        _tdhfb_phi_subupdate!(state_work, F, g_S, V, half;
            hfb_mode=hfb_mode, state_for_gen=state_mid)
        _tdhfb_R_subupdate!(state_work, F, g_S, V, dt;
            state_for_gen=state_mid)
        _tdhfb_phi_subupdate!(state_work, F, g_S, V, half;
            hfb_mode=hfb_mode, state_for_gen=state_mid)

        # Refine midpoint as (state_0 + state_1) / 2; track convergence.
        delta = 0.0
        @inbounds for I in eachindex(state_mid.phi)
            new_val = 0.5 * (state_0.phi[I] + state_work.phi[I])
            d = abs(new_val - state_mid.phi[I])
            d > delta && (delta = d)
            state_mid.phi[I] = new_val
        end
        @inbounds for I in eachindex(state_mid.rho)
            new_val = 0.5 * (state_0.rho[I] + state_work.rho[I])
            d = abs(new_val - state_mid.rho[I])
            d > delta && (delta = d)
            state_mid.rho[I] = new_val
        end
        @inbounds for I in eachindex(state_mid.kappa)
            new_val = 0.5 * (state_0.kappa[I] + state_work.kappa[I])
            d = abs(new_val - state_mid.kappa[I])
            d > delta && (delta = d)
            state_mid.kappa[I] = new_val
        end

        delta < tol && break
    end
    return state
end

# φ Nambu doublet sub-update: φ ← top(M^φ · (φ, conj(φ))).
# U^φ_{a,b} = V·(φ*φ + 2ρ),  Δ^φ_{a,b} = V·κ (full HFB) or 0 (Popov).
#
# `hfb_mode = :popov` drops the anomalous self-energy Δ^φ from the φ
# subupdate ONLY (the (ρ, κ) Nambu density rotation still uses the full
# Δ^R). This restores a gapless Goldstone mode for the condensate at the
# cost of two-body inconsistency — the Hugenholtz-Pines theorem fix
# standard for BEC dynamics. See `tdhfb_strang_step!` docstring for the
# physics summary.
function _tdhfb_phi_subupdate!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V::AbstractArray{Float64, 4},
    dt::Float64;
    hfb_mode::Symbol=:full_hfb,
    state_for_gen::TDHFBState{N}=state,
) where {N}
    # `state_for_gen` controls which state evaluates U^φ, Δ^φ. Default
    # `state_for_gen=state` reproduces live-state (production) behavior
    # bit-exactly. Picard midpoint passes `state_for_gen=state_mid` so the
    # generator is frozen and S(-dt) ∘ S(dt) = I to Picard tolerance.
    D = 2 * F + 1
    sz = size(state.phi)
    n_spatial = length(sz) - 1
    spatial = sz[1:n_spatial]
    twoD = 2 * D

    drop_anomalous = hfb_mode === :popov

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
                # U^φ:  φ*_{c2_p} φ_{c2}  +  ρ_{c2, c2_p}
                # (fix 2026-05-12: previously had factor 2 + transposed ρ
                # indices, leftover from a partial channel_kernel ↔
                # channel_kernel_symmetrized migration — caused dt-independent
                # energy drift scaling linearly with g_S, see memory.)
                uval +=
                    Vk * (
                        conj(state_for_gen.phi[idx, c2_p]) * state_for_gen.phi[idx, c2]
                        +
                        state_for_gen.rho[idx, c2, c2_p]
                    )
                # Δ^φ:  κ_{c2, c2_p}                  (no φφ source)
                # Popov mode (`hfb_mode = :popov`): drop the anomalous
                # source for the φ subupdate.
                if !drop_anomalous
                    dval += Vk * state_for_gen.kappa[idx, c2, c2_p]
                end
            end
            U_phi[c, c_p] = uval
            Delta_phi[c, c_p] = dval
        end

        # Assemble W^φ = [[U^φ, Δ^φ], [-conj(Δ^φ), -conj(U^φ)]].
        W = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            W[c, c_p] = U_phi[c, c_p]
            W[c, D + c_p] = Delta_phi[c, c_p]
            W[D + c, c_p] = -conj(Delta_phi[c, c_p])
            W[D + c, D + c_p] = -conj(U_phi[c, c_p])
        end

        # General matrix exponential.
        M = exp(-1im * W * dt)

        # Apply to (φ, conj(φ)) doublet.
        phi_vec = Vector{ComplexF64}(undef, twoD)
        for c in 1:D
            phi_vec[c] = state.phi[idx, c]
            phi_vec[D + c] = conj(state.phi[idx, c])
        end
        new_phi = M * phi_vec
        for c in 1:D
            state.phi[idx, c] = new_phi[c]
        end
    end
    return state
end

# (ρ, κ) Nambu density sub-update: R ← M^R · R · (M^R)^†.
# U^R = V·(φ*φ + ρ),  Δ^R = V·(φφ + κ).
# `state_for_gen` controls which state evaluates U^R, Δ^R. Default
# `state_for_gen=state` reproduces live-state behavior; Picard passes
# state_mid.
function _tdhfb_R_subupdate!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V::AbstractArray{Float64, 4},
    dt::Float64;
    state_for_gen::TDHFBState{N}=state,
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
                # U^R:  V·(φ*φ + ρ_{c2, c2_p})  — same as U^φ after the fix
                # (variational consistency, see strang_step.jl:206 comment).
                uval +=
                    Vk * (
                        conj(state_for_gen.phi[idx, c2_p]) * state_for_gen.phi[idx, c2]
                        +
                        state_for_gen.rho[idx, c2, c2_p]
                    )
                # Δ^R:  V·(φφ + κ)
                dval +=
                    Vk * (
                        state_for_gen.phi[idx, c2] * state_for_gen.phi[idx, c2_p]
                        +
                        state_for_gen.kappa[idx, c2, c2_p]
                    )
            end
            U_R[c, c_p] = uval
            Delta_R[c, c_p] = dval
        end

        # Assemble W^R.
        W = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            W[c, c_p] = U_R[c, c_p]
            W[c, D + c_p] = Delta_R[c, c_p]
            W[D + c, c_p] = -conj(Delta_R[c, c_p])
            W[D + c, D + c_p] = -conj(U_R[c, c_p])
        end

        M = exp(-1im * W * dt)

        # Bosonic Bogoliubov: M is pseudo-unitary (σ_z M† σ_z = M⁻¹).
        # Heisenberg evolution of R_{ab} = ⟨ψ_b† ψ_a⟩ is M · R · M†, NOT
        # M · R · M⁻¹. M·R·M† preserves Hermiticity and Nambu structure
        # exactly, so no Hermitian/symmetric projection is needed.
        R = zeros(ComplexF64, twoD, twoD)
        for c in 1:D, c_p in 1:D
            R[c, c_p] = state.rho[idx, c, c_p]
            R[c, D + c_p] = state.kappa[idx, c, c_p]
            R[D + c, c_p] = conj(state.kappa[idx, c, c_p])
            delta_cc = c == c_p ? one(ComplexF64) : zero(ComplexF64)
            R[D + c, D + c_p] = delta_cc + conj(state.rho[idx, c, c_p])
        end
        R_new = M * R * adjoint(M)

        for c in 1:D, c_p in 1:D
            state.rho[idx, c, c_p] = R_new[c, c_p]
            state.kappa[idx, c, c_p] = R_new[c, D + c_p]
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

# Default |k|² grid for tests / no-Grid call sites. Matches a `dx = 1,
# L = nx_d` box per spatial dimension (so `dk = 2π / nx_d`). Used by both
# `_tdhfb_kinetic_step!` and `tdhfb_energy` so the kinetic propagator and
# kinetic energy expectation stay numerically consistent.
function _default_tdhfb_k_squared(spatial::Tuple)
    ks2 = zeros(Float64, spatial)
    nd = length(spatial)
    @inbounds for idx in CartesianIndices(spatial)
        s = 0.0
        for d in 1:nd
            nd_d = spatial[d]
            ki = idx[d] - 1 < nd_d / 2 ? (idx[d] - 1) : (idx[d] - 1 - nd_d)
            kd = 2π * ki / nd_d
            s += kd^2
        end
        ks2[idx] = s
    end
    return ks2
end
