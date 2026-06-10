# --- Zeeman: data accessors + static builders + the ZeemanTerm HamTerm ---
#
# `H_Zeeman = -(g_F μ_B B · F) + q F_z²` (user spec
# `b_block_builders.jl:27`), written as ONE operator:
#
#   H = -(bx·F_x + by·F_y + bz·F_z) + q·F_z²
#
# with `bz ≡ p` the linear z-Zeeman coefficient.
#
# Three concerns, one file (each small, one cohesive subsystem):
#   1. accessors — operations on the Zeeman DATA type
#      (ZeemanParams / TimeDependentZeeman), shared across split_step,
#      GPU energy, the registry, and the reference RHS.
#   2. builders — config-facing constructors (named kwargs / lab units).
#   3. ZeemanTerm — the HamTerm (trinity faces + sign oracle).
#
# MagneticGradient (spin-INDEPENDENT scalar tilt) is NOT a Zeeman; it
# lives in `terms/magnetic_gradient.jl`.

# ============================================================================
# Accessors — operations on the Zeeman data type
# ============================================================================

export zeeman_diagonal, zeeman_energies, zeeman_at

"""
Return Zeeman energy shifts as a vector indexed by m = F, F-1, ..., -F.

Linear Zeeman: E_m = -p * m
Quadratic Zeeman: E_m = q * m²
"""
function zeeman_energies(z::ZeemanParams, sys::SpinSystem)
    [(-z.p * m + z.q * m^2) for m in sys.m_values]
end

function zeeman_diagonal(z::ZeemanParams, sys::SpinSystem)
    SVector{sys.n_components, Float64}(zeeman_energies(z, sys))
end

function zeeman_diagonal(z::ZeemanParams, sm::SpinMatrices{D}) where {D}
    F = sm.system.F
    SVector{D, Float64}(ntuple(c -> -z.p * (F - (c - 1)) + z.q * (F - (c - 1))^2, Val(D)))
end

# Spin rotating-frame variant: returns the H_rot diagonal for ψ_rot evolution.
# H_rot_diag(m) = -(p - ω_R) m + q m²  (the +ω_R F_z from i ∂_t U U† cancels
# the -p F_z linear Zeeman when ω_R = p).
function zeeman_diagonal(z::ZeemanParams, sm::SpinMatrices{D}, omega_R::Float64) where {D}
    F = sm.system.F
    p_eff = z.p - omega_R
    SVector{D, Float64}(ntuple(c -> -p_eff * (F - (c - 1)) + z.q * (F - (c - 1))^2, Val(D)))
end

"""
    zeeman_at(zeeman, t) -> ZeemanParams

DIAGONAL-ONLY accessor: collapses `TimeDependentZeeman` to
`ZeemanParams(p(t), q(t))`, **dropping bx/by**. Calling
`transverse_b` on the collapsed value is identically (0, 0) — read
the transverse components from the ORIGINAL object:
`transverse_b(ws.zeeman, t)`. (This trap was App. A defect 8: the
combined_spin_step transverse branch was structurally dead for it.)
"""
zeeman_at(z::ZeemanParams, ::Float64) = z
zeeman_at(z::TimeDependentZeeman, t::Float64) = ZeemanParams(
    evaluate(z.p_wf, t), evaluate(z.q_wf, t)
)

# ============================================================================
# Builders — static Zeeman constructors
# ============================================================================
#
# Named-kwargs wrappers around `TimeDependentZeeman` to eliminate the
# `(0, 0, p_lab, 0)` positional footgun that surfaced as the M1
# in-plane-vs-Bz misidentification (memory:
# m1_in_plane_bx_disambiguation_2026_06_04). The slot order is
# `TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)` — p is Bz, NOT Bx.

export static_zeeman, static_zeeman_lab

"""
    static_zeeman(; Bz=0.0, Bx=0.0, By=0.0, q=0.0) → TimeDependentZeeman

Build a time-independent `TimeDependentZeeman` from dimensionless slot
values. The kwargs correspond directly to the components of the rotated
Zeeman Hamiltonian (sign convention `H = −(g_F μ_B B·F) + q F_z²`):

  * `Bz` (the slot historically named `p`)
  * `q`  (quadratic Zeeman)
  * `Bx`, `By` (transverse)

Use this instead of the 4-arg positional `TimeDependentZeeman(...)`
constructor — names make slot identity explicit and prevent the M1
incident class (p_lab meant Bx, not Bz).
"""
function static_zeeman(;
    Bz::Real=0.0, Bx::Real=0.0, By::Real=0.0, q::Real=0.0
)
    return TimeDependentZeeman(
        ConstantWaveform(Float64(Bz)),
        ConstantWaveform(Float64(q)),
        ConstantWaveform(Float64(Bx)),
        ConstantWaveform(Float64(By)),
    )
end

"""
    static_zeeman_lab(preset; Bz_nT=0.0, Bx_nT=0.0, By_nT=0.0, q=0.0)
        → TimeDependentZeeman

Lab-units convenience: nT → dimensionless via `preset.p_per_nT`. The
quadratic term `q` is still passed dimensionless (auto-derive from |B|²
is the YAML pipeline's job; for scripted runs `q` is usually 0 or
hand-set).
"""
function static_zeeman_lab(
    preset::Preset;
    Bz_nT::Real=0.0, Bx_nT::Real=0.0, By_nT::Real=0.0, q::Real=0.0,
)
    p = preset.p_per_nT
    return static_zeeman(;
        Bz=p * Bz_nT, Bx=p * Bx_nT, By=p * By_nT, q=q
    )
end

# ============================================================================
# ZeemanTerm — linear + quadratic Zeeman as one HamTerm
# ============================================================================
#
# The diagonal piece (bz, q) and the transverse piece (bx, by) used to
# be two separate HamTerms (LinearZeemanZTerm + TransverseZeemanTerm).
# They are the SAME physical object — a vector field coupling to F plus
# a rank-2 diagonal — split only because z is diagonal in m (cheap exp)
# and the transverse part is off-diagonal. Folding them into one term
# makes the user-spec sign convention live in a single coefficient pair,
# which removes the [GAP-1] class structurally: a workspace can no
# longer carry a face that reads only (p, q) and silently drops (bx, by).

"""
Linear + quadratic Zeeman as one operator.

`H = -(bx·F_x + by·F_y + bz·F_z) + q·F_z²` per user spec
(`b_block_builders.jl:27`), with `bz ≡ p` the linear z coefficient.
"""
struct ZeemanTerm <: HamTerm
    bx::Float64
    by::Float64
    bz::Float64
    q::Float64
end

# THE diagonal coefficient. The user-spec z + quadratic sign convention
# lives here exclusively (`H_z(m) = -bz·m + q·m²`). The transverse
# ladder coefficients below are the off-diagonal counterpart of the SAME
# declaration; flipping any of them flips propagator AND energy AND
# gradient simultaneously — the sign oracle + master oracle catch it.
@inline _diag_coef(term::ZeemanTerm, m::Real) = -term.bz * m + term.q * m * m

@inline _is_inactive(term::ZeemanTerm) =
    term.bx == 0.0 && term.by == 0.0 && term.bz == 0.0 && term.q == 0.0
@inline _has_transverse(term::ZeemanTerm) = !(term.bx == 0.0 && term.by == 0.0)

# ---------------------------------------------------------------------------
# Operator face (gradient): out .+= H·ψ
# ---------------------------------------------------------------------------

function apply_operator!(out::AbstractArray, term::ZeemanTerm, ws, psi::AbstractArray)
    _is_inactive(term) && return out
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    # diagonal (-bz·m + q·m²)
    for c in 1:D
        coef = _diag_coef(term, F - (c - 1))
        coef == 0.0 && continue
        idx = _component_slice(N, n_pts, c)
        view(out, idx...) .+= coef .* view(psi, idx...)
    end
    # transverse (-bx·F_x - by·F_y) via ladder accumulation
    if _has_transverse(term)
        coeff_lower = -(term.bx + im * term.by) / 2   # acts at c reading psi at c-1
        coeff_upper = -(term.bx - im * term.by) / 2   # acts at c-1 reading psi at c
        for c in 2:D
            idx_c = _component_slice(N, n_pts, c)
            idx_cm1 = _component_slice(N, n_pts, c - 1)
            fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            view(out, idx_c...) .+= coeff_lower .* fp .* view(psi, idx_cm1...)
            view(out, idx_cm1...) .+= coeff_upper .* fp .* view(psi, idx_c...)
        end
    end
    return out
end

# ---------------------------------------------------------------------------
# Energy face: ⟨ψ|H|ψ⟩
# ---------------------------------------------------------------------------

function energy_contribution(term::ZeemanTerm, psi::AbstractArray{<:Complex}, ws)
    _is_inactive(term) && return 0.0
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    dV = cell_volume(ws.grid)
    E = 0.0
    for c in 1:D
        coef = _diag_coef(term, F - (c - 1))
        coef == 0.0 && continue
        idx = _component_slice(N, n_pts, c)
        E += coef * sum(abs2, view(psi, idx...))
    end
    E *= dV
    if _has_transverse(term)
        fx, fy, _ = spin_density_vector(psi, sm, N)
        E += ((-term.bx) * sum(fx) + (-term.by) * sum(fy)) * dV
    end
    return E
end

# Context-aware: diagonal via per-component density (CPU Array, no big
# alloc); transverse from the shared spin densities.
function energy_contribution(
    term::ZeemanTerm, psi::AbstractArray{<:Complex}, ws, ctx::EnergyContext
)
    _is_inactive(term) && return 0.0
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    E = 0.0
    for c in 1:D
        coef = _diag_coef(term, F - (c - 1))
        coef == 0.0 && continue
        idx = _component_slice(N, n_pts, c)
        E += coef * sum(abs2, view(psi, idx...))
    end
    E *= ctx.dV
    if _has_transverse(term)
        s = 0.0
        @inbounds for i in eachindex(ctx.fx, ctx.fy)
            s += -term.bx * ctx.fx[i] - term.by * ctx.fy[i]
        end
        E += s * ctx.dV
    end
    return E
end

# ---------------------------------------------------------------------------
# Propagator face: exp(-i·dt·H) (RT) / exp(-dt·H) (IT)
# ---------------------------------------------------------------------------
#
# H is spatially uniform in the spin axis, so the WHOLE operator
# (diagonal + transverse) exponentiates to a single D×D matrix applied
# to the spin axis — exact, no Strang split between the diagonal and
# transverse pieces, and GPU-safe via `_apply_rotation_to_spin_axis!`.

"""
Build the D×D Zeeman propagator: `exp(-i·dt·H)` (RT) or
`exp(-dt·(H − λ_min·I))` (IT). The IT shift subtracts the minimum
eigenvalue to prevent overflow — the matrix-form generalisation of the
`min(diag)` shift used for the diagonal-only Zeeman (CLAUDE.md "ITP
Zeeman shift").
"""
function _zeeman_propagator(
    sm::SpinMatrices{D}, term::ZeemanTerm, dt::Float64, imaginary_time::Bool
) where {D}
    F = sm.system.F
    M = Matrix{ComplexF64}(undef, D, D)
    @inbounds for j in 1:D, i in 1:D
        M[i, j] = -term.bx * sm.Fx[i, j] - term.by * sm.Fy[i, j] - term.bz * sm.Fz[i, j]
    end
    @inbounds for c in 1:D
        m = F - (c - 1)
        M[c, c] += term.q * m * m
    end
    P = if imaginary_time
        shift = minimum(real, eigvals(Hermitian(M)))
        exp(-dt * (M - shift * I))
    else
        exp((-im * dt) * M)
    end
    return SMatrix{D, D, ComplexF64}(P)
end

function apply_step!(term::ZeemanTerm, psi::AbstractArray{<:Complex},
    dt::Real, imaginary_time::Bool, ws)
    _is_inactive(term) && return nothing
    sm = ws.spin_matrices
    N = ndims(psi) - 1
    if !_has_transverse(term)
        # Diagonal-only fast path: per-component scalar phase/decay via
        # broadcast (GPU-safe). Bit-identical to the per-component
        # `exp(-(diag - shift)·dt)` diagonal step. ITP shift subtracts
        # min(diag) for overflow (CLAUDE.md "ITP Zeeman shift").
        F = sm.system.F
        D = sm.system.n_components
        n_pts = ntuple(d -> size(psi, d), Val(N))
        shift = imaginary_time ? minimum(_diag_coef(term, F - (c - 1)) for c in 1:D) : 0.0
        for c in 1:D
            coef = _diag_coef(term, F - (c - 1))
            factor = imaginary_time ? exp(-(coef - shift) * dt) : cis(-coef * dt)
            idx = _component_slice(N, n_pts, c)
            view(psi, idx...) .*= factor
        end
        return nothing
    end
    # Transverse active: the full operator is one spatially-uniform D×D
    # matrix exponential applied to the spin axis (exact, no Strang
    # split between diagonal and transverse).
    P = _zeeman_propagator(sm, term, Float64(dt), imaginary_time)
    _apply_rotation_to_spin_axis!(psi, P, N; scratch=ws.state.psi_scratch)
    return nothing
end

"""
Directional sign oracle for `ZeemanTerm`. With +bz (representing +Bz),
ITP from `:m_plus_F` should preserve ⟨F_z⟩ ≈ +F.
"""
function sign_oracle(::Type{ZeemanTerm})
    return (
        name="ZeemanTerm: +bz ⇒ ⟨F_z⟩ > 0",
        predicate=function (psi, ws)
            sm = ws.spin_matrices
            N = ndims(psi) - 1
            _, _, fz = spin_density_vector(psi, sm, N)
            return sum(fz) * cell_volume(ws.grid) > 0.5
        end,
    )
end

# ---------------------------------------------------------------------------
# Standalone energy bodies used by the GPU energy_decomposition path
# (`ext/SpinorBECCUDAExt/gpu_energy.jl`). Same physics as the trinity
# faces above; kept as plain functions because the GPU path resolves
# (p, q, bx, by) from `ws.zeeman` directly rather than from a term.
# ---------------------------------------------------------------------------

"""
    _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)

Diagonal `-p·F_z + q·F_z²` energy. `zeeman` is `ZeemanParams` (already
sampled at the current time by the caller).
"""
function _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)
    p = zeeman.p
    q = zeeman.q
    E = 0.0
    @inbounds for c in 1:n_comp
        m = sys.m_values[c]
        zee_c = -p * m + q * m * m
        idx = _component_slice(ndim, n_pts, c)
        E += zee_c * sum(abs2, view(psi, idx...)) * dV
    end
    E
end

"""
    _transverse_zeeman_energy(psi, bx, by, sm, ndim, dV)

`⟨H_perp⟩ = -bx·⟨F_x⟩ - by·⟨F_y⟩` for the spatially-uniform
transverse-Zeeman field.
"""
function _transverse_zeeman_energy(psi, bx::Real, by::Real, sm, ndim, dV)
    (bx == 0.0 && by == 0.0) && return 0.0
    fx, fy, _ = spin_density_vector(psi, sm, ndim)
    return (-bx) * sum(fx) * dV + (-by) * sum(fy) * dV
end
