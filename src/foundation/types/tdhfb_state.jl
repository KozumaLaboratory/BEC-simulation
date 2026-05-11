# TDHFB state (post-修論 / D 論 Year 2 Phase 1)
#
# Time-Dependent Hartree-Fock-Bogoliubov (TDHFB) tracks pair amplitudes
# ⟨ψψ⟩ (κ, anomalous) and normal density ⟨ψ†ψ⟩ (ρ) alongside the mean
# field φ = ⟨ψ⟩.
#
# This struct is Phase 1 of the TDHFB pilot per docs/tdhfb_pilot_design.md.
# Storage layout:
#   φ:     spatial dims... × D     (mean field, like SimState.psi)
#   ρ:     spatial dims... × D × D (normal density, Hermitian: ρ[m,m'] = ⟨ψ†_m ψ_m'⟩)
#   κ:     spatial dims... × D × D (anomalous: κ[m,m'] = ⟨ψ_m ψ_m'⟩, symmetric in m,m')
#
# For local (= no r,r' separation) approximation: ρ, κ depend on r only.
# Full non-local treatment (ρ[r,r',m,m']) is post-Phase 1 extension.
#
# Type parameters follow SpinorBEC discipline (concrete, narrow):
#   N: number of spatial dimensions (1, 2, or 3)
#   A: array type for φ (matches SimState.psi, e.g. Array{ComplexF64, N+1} for CPU
#      or CuArray for GPU)
#   B: array type for ρ, κ (one extra spinor dim than A, e.g. Array{ComplexF64, N+2})
#   T: real precision (Float64 default, Float32 for mixed-precision)
#
# Memory cost estimate (Eu F=6, D=13, 32³ grid):
#   φ:  32³ × 13 = 425,984 ComplexF64 = 6.5 MB
#   ρ:  32³ × 13² = 5,537,792 ComplexF64 = 84 MB
#   κ:  32³ × 13² = 84 MB
#   Total: ~175 MB per TDHFBState, fits 16 GB GPU
#
# Construction conventions:
#   - φ initialized from a SimState.psi (= mean-field GS)
#   - ρ initialized to vacuum (= 0) or thermal occupation (Bose-Einstein)
#   - κ initialized to 0 (vacuum); thermal initial state may use non-zero
#     pair amplitudes from BdG ground-state modes
#
# This struct is currently in foundation/types/ scaffolding. Kernels +
# integrators are post-Phase 1 work (Q3-Q4 2027 per dthesis_year1_roadmap.md).

"""
    TDHFBState{N, A, B, T}

Time-dependent Hartree-Fock-Bogoliubov state.

Tracks coupled (φ, ρ, κ) on a spatial grid. Generic over spatial dim N,
array container types (A for φ, B for ρ/κ), and real precision T.

# Fields
- `phi::A`   — mean field, size = (spatial..., D), eltype = Complex{T}
- `rho::B`   — normal density, size = (spatial..., D, D), eltype = Complex{T}
- `kappa::B` — anomalous density, size = (spatial..., D, D), eltype = Complex{T}
- `t::T`     — simulation time
- `step::Int` — step counter

# Construction (high-level convenience)

Use `TDHFBState(psi; rho=:vacuum, kappa=:vacuum)` to initialize from a SimState.psi
with default vacuum (ρ = κ = 0) initial state.

For thermal initial state with T/T_c ratio, see `init_tdhfb_thermal!`
(post-Phase 1 helper).

# Memory layout

ρ and κ are stored as full 2-spinor-index tensors. Hermiticity (ρ[m,m'] = ρ[m',m]*)
and symmetry (κ[m,m'] = κ[m',m]) are NOT enforced at storage level; kernels must
preserve these properties. Future Phase 2 may add `Hermitian` / `Symmetric`
wrappers for type-stability + reduced storage.

# References
- design doc: `docs/tdhfb_pilot_design.md`
- D 論 Year 1 Q3-Q4 plan: `docs/dthesis_year1_roadmap.md` §4.2
- physics primer: Chapter 5 §5.8 of master thesis
"""
mutable struct TDHFBState{N, A <: AbstractArray, B <: AbstractArray, T <: AbstractFloat}
    phi::A
    rho::B
    kappa::B
    t::T
    step::Int
end

# Convenience constructor: infer T from eltype(A)
TDHFBState{N, A, B}(phi::A, rho::B, kappa::B, t, step) where {N, A, B} = TDHFBState{
    N, A, B, real(eltype(A))
}(phi, rho, kappa, t, step)

"""
    init_tdhfb_vacuum(psi::A) where {A <: AbstractArray}

Initialize TDHFBState from a mean-field spinor `psi` with vacuum (ρ = κ = 0).

`psi` must be a (spatial..., D) array (= SimState.psi shape). Returns a
TDHFBState with same backend (CPU/GPU), same precision, and zero pair amplitudes.

This is the starting point for TDHFB evolution of an initially condensed state
without pre-existing pair correlations.
"""
function init_tdhfb_vacuum(psi::AbstractArray)
    sz = size(psi)
    spatial_dims = sz[1:end-1]
    D = sz[end]
    N = length(spatial_dims)

    T_real = real(eltype(psi))
    T_complex = eltype(psi)

    rho_shape = (spatial_dims..., D, D)
    kappa_shape = rho_shape

    rho = similar(psi, T_complex, rho_shape)
    fill!(rho, zero(T_complex))
    kappa = similar(psi, T_complex, kappa_shape)
    fill!(kappa, zero(T_complex))

    return TDHFBState{N, typeof(psi), typeof(rho), T_real}(
        psi, rho, kappa, zero(T_real), 0
    )
end

"""
    tdhfb_total_particle_number(state::TDHFBState; integration_weight=1.0)

Compute total particle number N = ∫ (|φ|² + tr ρ) d³r.

`integration_weight` should be the spatial volume element dV (= dx·dy·dz for
3D grid). For uniform grid: `dV = prod(dx)`.

Conservation invariant for TDHFB evolution.
"""
function tdhfb_total_particle_number(state::TDHFBState; integration_weight::Real=1.0)
    phi = state.phi
    rho = state.rho

    N_phi = sum(abs2, phi)

    # trace of ρ over spinor indices, summed over spatial points
    sz = size(rho)
    D = sz[end]
    n_spatial_dims = length(sz) - 2
    N_rho = zero(real(eltype(rho)))
    for idx in CartesianIndices(size(rho)[1:n_spatial_dims])
        for m in 1:D
            N_rho += real(rho[idx, m, m])
        end
    end

    return (N_phi + N_rho) * integration_weight
end

"""
    tdhfb_hermiticity_check(state::TDHFBState; tol=1e-10)

Verify that ρ is Hermitian (ρ[m,m'] = ρ[m',m]*) and κ is symmetric
(κ[m,m'] = κ[m',m]).

Returns (rho_hermitian_max_dev, kappa_symmetric_max_dev). Both should be < tol
for a physical TDHFB state.

Use this to validate integrator correctness during development.
"""
function tdhfb_hermiticity_check(state::TDHFBState; tol::Real=1e-10)
    rho = state.rho
    kappa = state.kappa
    sz = size(rho)
    D = sz[end]
    n_spatial_dims = length(sz) - 2

    rho_dev = zero(real(eltype(rho)))
    kappa_dev = zero(real(eltype(kappa)))

    # Iterate over all spatial points and check spinor matrix structure
    # Naive iteration; for production use vectorized ops
    for idx in CartesianIndices(size(rho)[1:n_spatial_dims])
        for m in 1:D, m_prime in 1:D
            r_mm = rho[idx, m, m_prime]
            r_mm_swap = rho[idx, m_prime, m]
            rho_dev = max(rho_dev, abs(r_mm - conj(r_mm_swap)))

            k_mm = kappa[idx, m, m_prime]
            k_mm_swap = kappa[idx, m_prime, m]
            kappa_dev = max(kappa_dev, abs(k_mm - k_mm_swap))
        end
    end

    return rho_dev, kappa_dev
end

"""
    tdhfb_energy(state::TDHFBState, hf_matrix; integration_weight=1.0)

Compute total TDHFB energy E[φ, ρ, κ] from the Hartree-Fock matrix h^HF.

Phase 1 placeholder: returns mean-field energy only (= ⟨φ| h^HF |φ⟩).
Phase 2 will add pair-amplitude contributions tr(h^HF · ρ) and anomalous
coupling terms.

This is the conserved quantity for TDHFB Hamiltonian dynamics.
"""
function tdhfb_energy(state::TDHFBState, hf_matrix; integration_weight::Real=1.0)
    # Phase 1 placeholder: not yet wired to actual HF kernel
    # Returns dummy value; replace with proper energy functional in Phase 2
    @warn "tdhfb_energy is a Phase 1 placeholder; production energy functional " *
          "will be implemented alongside HF kernels in Phase 2."
    return zero(real(eltype(state.phi)))
end

# Export TDHFBState only (kernels + integrators in Phase 2 hamiltonian/tdhfb/)
# Not yet exported from SpinorBEC.jl umbrella; will add when Phase 2 lands.
