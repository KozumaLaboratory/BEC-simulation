# TDHFB Strang split-step integrator (Phase 3 minimal scope).
#
# Strang factorization of the TDHFB equations:
#
#   i ∂φ/∂t  = (T + V_ext) φ + h^HF · φ
#   i ∂ρ/∂t  = [h^HF, ρ]
#   i ∂κ/∂t  = h^HF · κ + κ · h^HF^T + ...
#
# Phase 3 minimal scope:
#   - Kinetic step via spinor-shared FFT plan
#   - Trap step via diagonal V_ext multiplication
#   - HF self-energy step via hf_matrix_generic! (channel-decomposed)
#   - Anomalous κ evolution: stubbed (Phase 4 work)
#
# Reference: docs/tdhfb_pilot_design.md §"TDHFB equations" + Kawaguchi-Ueda 2012 §3.
#
# Test scope: F=1 polar reduces to standard split-step GP (ρ=0 limit).

"""
    tdhfb_strang_step!(state, F, g_S, V_ext, dt; fft_plans=nothing)

Perform one Strang split-step of TDHFB evolution by time dt.

Strang factorization:
  V(dt/2) HF(dt/2) K(dt) HF(dt/2) V(dt/2)
where V is trap potential, HF is Hartree-Fock self-energy step, K is kinetic.

# Arguments
- `state::TDHFBState{N}`: mutated in place (φ, ρ, κ, t, step all updated)
- `F::Int`: spin quantum number
- `g_S::AbstractDict{Int, Float64}`: channel couplings
- `V_ext::AbstractArray`: trap potential, shape (spatial..., D) (V_ext can be
  m-dependent for Zeeman; use V_ext[r, m] = V_trap(r) + V_Zeeman(m) for scalar trap)
- `dt::Float64`: time step

# Keyword arguments
- `fft_plans`: optional precomputed forward/backward FFT plans (otherwise allocates)

# Notes
- Phase 3 minimal: ρ evolution uses simple commutator [h^HF, ρ]; full Bogoliubov
  equations including κ are Phase 4.
- The kinetic step is shared across all spinor components (∇² doesn't mix spin).
- Returns the modified state for chaining.

# Returns
The state (modified in place).
"""
function tdhfb_strang_step!(state::TDHFBState{N}, F::Int,
                            g_S::AbstractDict{Int, Float64},
                            V_ext::AbstractArray,
                            dt::Float64;
                            fft_plans=nothing) where N
    D = 2 * F + 1

    # V step (dt/2): trap multiplication on φ
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    # HF step (dt/2): apply h^HF · φ via matrix-vector product at each spatial point
    _tdhfb_hf_step!(state, F, g_S, dt / 2)

    # K step (dt): kinetic via FFT
    _tdhfb_kinetic_step!(state.phi, dt; fft_plans=fft_plans)

    # HF step (dt/2)
    _tdhfb_hf_step!(state, F, g_S, dt / 2)

    # V step (dt/2)
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    state.t += dt
    state.step += 1

    return state
end

"""
Trap potential step on φ: φ_m(r) ← exp(-i V_ext[r, m] dt) · φ_m(r)
"""
function _tdhfb_v_step!(phi::AbstractArray, V_ext::AbstractArray, dt::Float64)
    sz = size(phi)
    D = sz[end]
    @assert size(V_ext, ndims(V_ext)) == D
    for idx in CartesianIndices(size(phi)[1:end-1]), m in 1:D
        phi[idx, m] *= exp(-1im * V_ext[idx, m] * dt)
    end
    return phi
end

"""
Hartree-Fock step on (φ, ρ, κ): evolves under h^HF.

Phase 3 minimal: applies exp(-i h^HF dt) · φ via spectral exponentiation of
the (small) D×D matrix h^HF at each spatial point. For ρ evolution, applies
the commutator [h^HF, ρ] to first order. κ evolution stubbed (Phase 4).
"""
function _tdhfb_hf_step!(state::TDHFBState{N}, F::Int,
                         g_S::AbstractDict{Int, Float64}, dt::Float64) where N
    D = 2 * F + 1
    sz = size(state.phi)
    n_spatial = length(sz) - 1

    # Compute h^HF at every spatial point
    h_hf = zeros(ComplexF64, sz[1:n_spatial]..., D, D)
    hf_matrix_generic!(h_hf, state.phi, state.rho, F, g_S)

    # For each spatial point: exp(-i h^HF dt) · φ_m
    # h^HF is Hermitian, so eigendecomposition works.
    for idx in CartesianIndices(size(state.phi)[1:n_spatial])
        h_mat = h_hf[idx, :, :]
        # Note: factor 2 from Bose symmetrization is for BdG. For GP-like evolution
        # we use the first-derivative form h^GP · φ = (1/2) h^BdG · φ (for the diagonal
        # part that doesn't double-count). For Phase 3 minimal, use h^HF/2 → matches GP.
        h_gp = h_mat / 2

        # Diagonalize Hermitian h_gp
        ev = eigen(Hermitian(h_gp))
        U = ev.vectors
        λ = ev.values
        exp_h = U * Diagonal(exp.(-1im .* λ .* dt)) * U'

        # Apply to phi
        phi_vec = state.phi[idx, :]
        state.phi[idx, :] = exp_h * phi_vec

        # ρ evolution: ρ → exp(-i h_gp dt) · ρ · exp(+i h_gp dt)
        # First-order: ρ - i dt [h_gp, ρ]
        rho_mat = state.rho[idx, :, :]
        commut = h_gp * rho_mat - rho_mat * h_gp
        state.rho[idx, :, :] = rho_mat - 1im * dt * commut

        # κ evolution: stub for Phase 3 (Phase 4 work)
    end
    return state
end

"""
Kinetic step on φ via FFT.
"""
function _tdhfb_kinetic_step!(phi::AbstractArray, dt::Float64;
                              fft_plans=nothing)
    # Simple kinetic step assuming periodic boundary conditions.
    # ∇² → -k² in Fourier space.
    sz = size(phi)
    D = sz[end]
    n_spatial = length(sz) - 1
    # k² grid
    L = [sz[i] for i in 1:n_spatial]  # grid size

    for m in 1:D
        phi_m = view(phi, ntuple(i -> 1:sz[i], n_spatial)..., m)
        # FFT: φ → φ̂
        phi_k = fft(phi_m)
        # Multiply by exp(-i k² dt / 2)
        for idx in CartesianIndices(size(phi_k))
            k_sq = 0.0
            for d in 1:n_spatial
                # 2π normalization, assuming box length L_d (default 1)
                ki = idx[d] - 1 < sz[d] / 2 ? (idx[d] - 1) : (idx[d] - 1 - sz[d])
                k_sq += (2π * ki / L[d])^2
            end
            phi_k[idx] *= exp(-1im * k_sq * dt / 2)
        end
        # IFFT
        phi_back = ifft(phi_k)
        for idx in CartesianIndices(size(phi_m))
            phi_m[idx] = phi_back[idx]
        end
    end
    return phi
end
