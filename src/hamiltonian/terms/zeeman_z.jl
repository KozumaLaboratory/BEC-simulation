# --- LinearZeemanZTerm HamTerm: proof-of-concept ---
#
# Single-source-of-truth declaration of `H_z = -p·F_z + q·F_z²`. The
# convention in `b_block_builders.jl:27` is `H_Zeeman = -(g_F μ_B B · F) + q F_z²`;
# the z-piece is `-p·F_z` with `p = g_F·μ_B·B_z/(ℏ·ω_ref)`. Lower
# energy at `+F_z` when `p > 0`.
#
# Bit-identicity discipline: `apply_step!` / `energy_contribution` /
# `add_gradient!` produce results bit-identical to the legacy
# `_diagonal_step_svec!` / `_zeeman_energy` / `_grad_zeeman!` for the
# z-only case (no transverse, no quadratic). Verified by
# `test/oracles/test_term_legacy_equivalence.jl`.

"""
Linear z-Zeeman + quadratic z-Zeeman.

`H = -p·F_z + q·F_z²` per user spec (`b_block_builders.jl:27`).
"""
struct LinearZeemanZTerm <: HamTerm
    p::Float64
    q::Float64
end

# THE ONE LINE. The user-spec sign convention lives here exclusively.
# Every method below derives from this. Flipping `-p*m` to `+p*m`
# flips propagator AND energy AND gradient simultaneously — the
# sign_oracle test catches it immediately.
@inline _diag_coef(term::LinearZeemanZTerm, m::Real) = -term.p * m + term.q * m * m

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_z is diagonal in m: H · ψ[I, c] = coef(m_c) · ψ[I, c]
# ============================================================================

function apply_operator!(out::AbstractArray, term::LinearZeemanZTerm, ws, psi::AbstractArray)
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    @inbounds for c in 1:D
        m = F - (c - 1)
        coef = _diag_coef(term, m)
        view(out, ntuple(_ -> :, Val(N))..., c) .=
            coef .* view(psi, ntuple(_ -> :, Val(N))..., c)
    end
    return out
end

# ============================================================================
# Derived: energy + gradient + propagator from the single source.
# ============================================================================

function energy_contribution(term::LinearZeemanZTerm, psi::AbstractArray{<:Complex}, ws)
    # Linear: E = Re⟨ψ, H·ψ⟩ · dV. apply_operator returns H·ψ.
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function add_gradient!(grad::AbstractArray{<:Complex}, term::LinearZeemanZTerm,
    psi::AbstractArray{<:Complex}, ws)
    buf = similar(psi)
    fill!(buf, zero(eltype(buf)))
    apply_operator!(buf, term, ws, psi)
    grad .+= buf
    return nothing
end

function apply_step!(term::LinearZeemanZTerm, psi::AbstractArray{<:Complex},
    dt::Real, imaginary_time::Bool, ws)
    # Propagator: psi[I, c] *= exp(-coef·dt) (IT) or cis(-coef·dt) (RT).
    # Uses the SAME `_diag_coef` as apply_operator (single source).
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))

    # ITP shift to prevent overflow: subtract min(diag) per the
    # standard SpinorBEC convention (CLAUDE.md "ITP Zeeman shift").
    shift = imaginary_time ? minimum(_diag_coef(term, F - (c - 1)) for c in 1:D) : 0.0

    @inbounds for c in 1:D
        m = F - (c - 1)
        coef = _diag_coef(term, m)
        if imaginary_time
            factor = exp(-(coef - shift) * dt)
            for I in CartesianIndices(n_pts)
                psi[I, c] *= factor
            end
        else
            factor = cis(-coef * dt)
            for I in CartesianIndices(n_pts)
                psi[I, c] *= factor
            end
        end
    end
    return nothing
end

"""
Directional sign oracle for `LinearZeemanZTerm`. With +p (representing
+Bz), ITP from `:m_plus_F` initial state should preserve ⟨F_z⟩ ≈ +F.
With −p (representing −Bz), ITP should push ⟨F_z⟩ toward −F.
"""
function sign_oracle(::Type{LinearZeemanZTerm})
    return (
        name="LinearZeemanZTerm: +p ⇒ ⟨F_z⟩ > 0",
        # `predicate(ws)` is called by the test harness after the
        # workspace is constructed with `[LinearZeemanZTerm(0.5, 0.0)]`
        # as the only HamTerm and an ITP loop has run for ~100 steps.
        # Returns Bool: does the observable have the expected sign?
        predicate=function (psi, ws)
            sm = ws.spin_matrices
            N = ndims(psi) - 1
            _, _, fz = spin_density_vector(psi, sm, N)
            return sum(fz) * cell_volume(ws.grid) > 0.5
        end,
    )
end
