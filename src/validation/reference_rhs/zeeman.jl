# --- Reference Hψ: Zeeman (diagonal + transverse) ---
#
# Sign convention — user spec `H_Zeeman = −(g_F μ_B B·F) + q F_z²`
# declared at `workflow/experiments/runtime/b_block_builders.jl`:
#
#   Diagonal:    (H_Z ψ)_c(r) = (-p m_c + q m_c²) ψ_c(r)
#   Transverse:  (H_Z⊥ ψ)_c(r) = (−b_x F_x − b_y F_y)_{c,c'} ψ_{c'}(r)
#
# `p`, `q`, `b_x`, `b_y` come from `linear_p`, `quadratic_q`,
# `transverse_b` so that ZeemanParams and TimeDependentZeeman are
# handled uniformly. Production exponentiates the same −b·F action
# since the 2026-06-04 transverse sign fix (split_step.jl passes
# (−bx, −by) into the rotation).

export reference_zeeman_diag_apply!, reference_zeeman_diag_energy
export reference_zeeman_transverse_apply!, reference_zeeman_transverse_energy
export reference_zeeman_apply!, reference_zeeman_energy

"""
    reference_zeeman_diag_apply!(out, psi, zeeman, sys, t=0.0)

Write `(-p m_c + q m_c²) ψ_c(r)` into `out`. `zeeman` is
`ZeemanParams` or `TimeDependentZeeman`; `sys` is `SpinSystem`.
"""
function reference_zeeman_diag_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    zeeman,
    sys::SpinSystem,
    t::Real=0.0,
)
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_comp = sys.n_components
    p = linear_p(zeeman, t)
    q = quadratic_q(zeeman, t)
    @inbounds for c in 1:n_comp
        m = sys.m_values[c]
        e_c = -p * m + q * m * m
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        out_c = view(out, idx...)
        @. out_c = e_c * psi_c
    end
    out
end

"""
    reference_zeeman_diag_energy(psi, zeeman, sys, grid, t=0.0) → Float64

Matches `_zeeman_energy`: `Σ_c (-p m_c + q m_c²) ∫ |ψ_c|² dV`.
"""
function reference_zeeman_diag_energy(
    psi::AbstractArray{<:Complex},
    zeeman,
    sys::SpinSystem,
    grid::Grid{N},
    t::Real=0.0,
) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = sys.n_components
    dV = cell_volume(grid)
    p = linear_p(zeeman, t)
    q = quadratic_q(zeeman, t)
    E = 0.0
    @inbounds for c in 1:n_comp
        m = sys.m_values[c]
        e_c = -p * m + q * m * m
        idx = _component_slice(N, n_pts, c)
        E += e_c * sum(abs2, view(psi, idx...)) * dV
    end
    E
end

"""
    reference_zeeman_transverse_apply!(out, psi, sm, b_x, b_y)

Write `(−b_x F_x − b_y F_y)_{c,c'} ψ_{c'}(r)` into `out` — the
user-spec convention `H_Zeeman = −(g_F μ_B B·F)` declared at
`workflow/experiments/runtime/b_block_builders.jl`, matching the
production sign fixed 2026-06-04. The pre-2026-06-06 version of THIS
function carried the opposite (+b·F) sign — App. A defect 4; it was
never exercised by a registered comparison (the test defaults were
bx=by=0), which is how it rotted unseen.
"""
function reference_zeeman_transverse_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    b_x::Real,
    b_y::Real,
) where {D}
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    Fx = sm.Fx
    Fy = sm.Fy
    @inbounds for I in CartesianIndices(n_pts)
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += -(b_x * Fx[c, cp] + b_y * Fy[c, cp]) * psi[I, cp]
            end
            out[I, c] = s
        end
    end
    out
end

"""
    reference_zeeman_transverse_energy(psi, sm, b_x, b_y, grid) → Float64

`⟨ψ| −b_x F_x − b_y F_y |ψ⟩ = −∫ (b_x f_x(r) + b_y f_y(r)) dV` —
user-spec sign (see `reference_zeeman_transverse_apply!`). Production
has carried the matching `zeeman_transverse` slot since the GAP-1 fix
(2026-06-04); the previous claim here that production omits it was
stale.
"""
function reference_zeeman_transverse_energy(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    b_x::Real,
    b_y::Real,
    grid::Grid{N},
) where {D, N}
    fx, fy, _ = spin_density_vector(psi, sm, N)
    dV = cell_volume(grid)
    s = 0.0
    @inbounds for i in eachindex(fx, fy)
        s += -(b_x * fx[i] + b_y * fy[i])
    end
    s * dV
end

"""
    reference_zeeman_apply!(out, psi, zeeman, sm, t=0.0)

Combined Zeeman action: diagonal + transverse (if `zeeman` carries
transverse components via `transverse_b`).
"""
function reference_zeeman_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    zeeman,
    sm::SpinMatrices{D},
    t::Real=0.0,
) where {D}
    reference_zeeman_diag_apply!(out, psi, zeeman, sm.system, t)
    b_x, b_y = transverse_b(zeeman, t)
    if abs(b_x) + abs(b_y) > 1e-30
        tmp = similar(out)
        reference_zeeman_transverse_apply!(tmp, psi, sm, b_x, b_y)
        @. out += tmp
    end
    out
end

"""
    reference_zeeman_energy(psi, zeeman, sm, grid, t=0.0) → Float64

Combined Zeeman energy: diagonal + transverse — directly comparable to
production's `:zeeman` legacy-shape slot (= zeeman_z + zeeman_transverse
since the GAP-1 fix).
"""
function reference_zeeman_energy(
    psi::AbstractArray{<:Complex},
    zeeman,
    sm::SpinMatrices{D},
    grid::Grid{N},
    t::Real=0.0,
) where {D, N}
    e_diag = reference_zeeman_diag_energy(psi, zeeman, sm.system, grid, t)
    b_x, b_y = transverse_b(zeeman, t)
    e_trans = if (abs(b_x) + abs(b_y) > 1e-30)
        reference_zeeman_transverse_energy(psi, sm, b_x, b_y, grid)
    else
        0.0
    end
    e_diag + e_trans
end
