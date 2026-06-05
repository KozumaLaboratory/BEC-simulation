# --- DensityC0Term HamTerm ---
#
# H_c0 = (c0/2) ∫ n² d³r. The mean-field self-coupling per spin
# component is `c0·n(r)·ψ(r)` in the GP equation. Universal positive
# c0 = repulsive contact interaction.

"""Density (c0) interaction term `H = (c0/2)·n²`."""
struct DensityC0Term <: HamTerm
    c0::Float64
end

@inline _density_sign(term::DensityC0Term) = +term.c0   # positive c0 = repulsive

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_c0 is mean-field nonlinear; δE/δψ̄[I, c] = c0 · n(r) · ψ[I, c]
# where n(r) = Σ_c' |ψ[r, c']|².
# Energy is (1/2) · ⟨ψ, apply_op(ψ)⟩ · dV (the mean-field 1/2).
# ============================================================================

function apply_operator!(out::AbstractArray, term::DensityC0Term, ws, psi::AbstractArray)
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_density = total_density(psi, N)
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(out, idx..., c) .= term.c0 .* n_density .* view(psi, idx..., c)
    end
    return out
end

# ============================================================================
# Derived: energy + gradient + propagator from the single source.
# ============================================================================

function energy_contribution(term::DensityC0Term, psi::AbstractArray{<:Complex}, ws)
    # Mean-field: E = (1/2) · Re⟨ψ, apply_op(ψ)⟩ · dV
    # = (1/2)·c0·∫n²·dV (the standard GP density energy).
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return 0.5 * real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function add_gradient!(grad, term::DensityC0Term, psi, ws)
    # δE/δψ̄ per-voxel = c0·n·ψ = apply_operator!(...) action.
    buf = similar(psi)
    fill!(buf, zero(eltype(buf)))
    apply_operator!(buf, term, ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware specialisation: reuse ctx.n_density to skip the recompute.
function add_gradient!(grad, term::DensityC0Term, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(grad, idx..., c) .+= term.c0 .* ctx.n_density .* view(psi, idx..., c)
    end
    return nothing
end

function apply_step!(term::DensityC0Term, psi, dt::Real, imaginary_time::Bool, ws)
    # Propagator: psi *= exp(-c0·n·dt) (IT) or cis(-c0·n·dt) (RT).
    # The `c0·n` here is the SAME coefficient as in apply_operator (single source).
    n = total_density(psi, ndims(psi) - 1)
    D = size(psi, ndims(psi))
    if imaginary_time
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= exp.(.-(term.c0 .* n) .* dt)
        end
    else
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= cis.(.-(term.c0 .* n) .* dt)
        end
    end
    return nothing
end

sign_oracle(::Type{DensityC0Term}) = (
    name="DensityC0Term: +c0 ⇒ E_c0 > 0 (repulsive contact)",
    predicate=function (psi, ws)
        E = energy_contribution(DensityC0Term(), psi, ws)
        c0 = ws.interactions[0]
        return c0 >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)
