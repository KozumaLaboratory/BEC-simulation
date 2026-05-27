# --- Reference Hψ: Zeeman (diagonal + transverse) ---
#
# Sign conventions (matched to src/analysis/energy.jl `_zeeman_energy`
# and src/hamiltonian/potentials/raman.jl `apply_uniform_spin_rotation!`):
#
#   Diagonal:    (H_Z ψ)_c(r) = (-p m_c + q m_c²) ψ_c(r)
#   Transverse:  (H_Z⊥ ψ)_c(r) = (b_x F_x + b_y F_y)_{c,c'} ψ_{c'}(r)
#
# `p`, `q`, `b_x`, `b_y` come from `linear_p`, `quadratic_q`,
# `transverse_b` so that ZeemanParams and TimeDependentZeeman are
# handled uniformly.
#
# Production applies `exp(-i (b_x F_x + b_y F_y) dt_frac)`, so the
# operator action being exponentiated is `(b_x F_x + b_y F_y) ψ` — the
# sign convention is *additive* (not -μ·B times anything explicit;
# `b_x`, `b_y` carry whatever sign the caller supplied). Reference
# matches.

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

Write `(b_x F_x + b_y F_y)_{c,c'} ψ_{c'}(r)` into `out`. Reads
F_x, F_y from `sm` (SpinMatrices).
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
                s += (b_x * Fx[c, cp] + b_y * Fy[c, cp]) * psi[I, cp]
            end
            out[I, c] = s
        end
    end
    out
end

"""
    reference_zeeman_transverse_energy(psi, sm, b_x, b_y, grid) → Float64

`⟨ψ| b_x F_x + b_y F_y |ψ⟩ = ∫ (b_x f_x(r) + b_y f_y(r)) dV` where
`f_α(r) = ⟨ψ(r)|F_α|ψ(r)⟩`. There is no corresponding term in
`_zeeman_energy`; this is here for completeness of the
self-contained chain.
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
        s += b_x * fx[i] + b_y * fy[i]
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

Combined Zeeman energy: diagonal + transverse. For comparison against
`_zeeman_energy` (production), only the diagonal part is comparable;
production currently omits the transverse term from energy_decomposition.
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
