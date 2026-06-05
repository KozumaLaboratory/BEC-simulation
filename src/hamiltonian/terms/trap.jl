# --- Trap HamTerm ---
#
# H_trap = +V_trap(r).  Universal positive potential, no sign
# question. Delegates to the existing diagonal step.

"""External trap potential `H = +V_trap(r)`."""
struct TrapTerm <: HamTerm end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_trap is linear; H · ψ = V_trap(r) · ψ per voxel.
# ============================================================================

function apply_operator!(out::AbstractArray, ::TrapTerm, ws, psi::AbstractArray)
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    V = ws.potential_values
    @inbounds for c in 1:D
        idx = ntuple(_ -> :, Val(N))
        view(out, idx..., c) .= V .* view(psi, idx..., c)
    end
    return out
end

# ============================================================================
# Derived: energy + gradient + propagator from the single source.
# ============================================================================

function energy_contribution(term::TrapTerm, psi::AbstractArray{<:Complex}, ws)
    # Linear term: E = Re⟨ψ, V·ψ⟩ · dV (no outer 1/2)
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

function add_gradient!(grad, term::TrapTerm, psi, ws)
    # δE/δψ̄ per-voxel = V · ψ = apply_operator!(...) action
    buf = similar(psi)
    fill!(buf, zero(eltype(buf)))
    apply_operator!(buf, term, ws, psi)
    grad .+= buf
    return nothing
end

function apply_step!(::TrapTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # Propagator: psi *= exp(-V·dt) (IT) or cis(-V·dt) (RT).
    # Uses the SAME V_trap as apply_operator (single source).
    V = ws.potential_values
    D = size(psi, ndims(psi))
    if imaginary_time
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= exp.(.-V .* dt)
        end
    else
        for c in 1:D
            view(psi, ntuple(_ -> :, Val(ndims(psi) - 1))..., c) .*= cis.(.-V .* dt)
        end
    end
    return nothing
end

"""
    _trap_energy(psi, V_trap, n_comp, ndim, n_pts, dV)

`E_trap = Σ_c ∫ V(r)·|ψ_c(r)|² dV`. Body used by `_energy_decomposition_cpu`.
Manual reduction loop avoids the `n_pts`-shaped temporary that
`V_trap .* abs2.(psi_c)` would materialise per component.
"""
function _trap_energy(psi, V_trap, n_comp, ndim, n_pts, dV)
    E = 0.0
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        Ec = 0.0
        for i in eachindex(V_trap, psi_c)
            Ec += V_trap[i] * abs2(psi_c[i])
        end
        E += Ec * dV
    end
    E
end

"""
    _grad_trap!(grad, psi, ws, n_pts, D, ::Val{N})

Add V_trap(r)·ψ contribution to `grad`. Body used by `energy_gradient!`.
"""
function _grad_trap!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= ws.potential_values .* view(psi, idx...)
    end
    nothing
end

sign_oracle(::Type{TrapTerm}) = (
    name="TrapTerm: V_trap≥0 ⇒ ⟨V_trap⟩ ≥ 0",
    predicate=function (psi, ws)
        any(<(0), ws.potential_values) && return true
        E = energy_contribution(TrapTerm(), psi, ws)
        return E >= -1e-12
    end,
)
