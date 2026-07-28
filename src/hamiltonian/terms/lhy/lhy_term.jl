# --- LHY HamTerm ---
#
# Lee-Huang-Yang correction. Multiple LHY models share a HamTerm:
# the propagator/energy/gradient go through ws.lhy.

"""LHY beyond-mean-field correction. Repulsive by physics."""
struct LHYTerm <: HamTerm end

function apply_step!(::LHYTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # Standalone per-term LHY phase. Production folds LHY into the
    # fused diagonal step (`_diagonal_step_svec!`); this face shares
    # that SAME potential function `_lhy_V`, so the sign/coefficient
    # source is common: phase = exp(−V_LHY·dτ) (IT) / cis(−V_LHY·dt)
    # (RT) with V_LHY = _lhy_V(n, lhy). The previous body called
    # `apply_lhy_step!`, which was defined nowhere — latent
    # UndefVarError (arch doc App. A defect 1).
    ws.lhy === nothing && ws.interactions.c_lhy == 0.0 && return nothing
    lhy = ws.lhy !== nothing ? ws.lhy : ws.interactions.c_lhy
    N = ndims(psi) - 1
    n = total_density(psi, N)
    V = _lhy_V.(n, Ref(lhy))
    phase = imaginary_time ? exp.(.-V .* dt) : cis.(.-V .* dt)
    D = size(psi, N + 1)
    idx = ntuple(_ -> :, Val(N))
    for c in 1:D
        view(psi, idx..., c) .*= phase
    end
    return nothing
end

function energy_contribution(::LHYTerm, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    if ws.lhy !== nothing
        return _lhy_energy(psi, ws.lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    elseif ws.interactions.c_lhy != 0.0
        return _lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    end
    return 0.0
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# E_LHY = (2/5)·c_lhy·∫n^(5/2)·dV (scalar) or ws.lhy's specific formula.
# δE/δψ̄ = c_lhy·n^(3/2)·ψ (scalar LHY). `_grad_lhy!` implements this;
# apply_operator! is a fill-then-call wrapper.
# ============================================================================

function apply_operator!(out::AbstractArray, ::LHYTerm, ws, psi::AbstractArray)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    n_density = total_density(psi, N)
    _grad_lhy!(out, psi, ws, n_density, n_pts, D, Val(N))
    return out
end

# Context-aware: borrow ctx.n_density.
function apply_operator!(out, ::LHYTerm, ws, psi, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    _grad_lhy!(out, psi, ws, ctx.n_density, ctx.n_pts, D, Val(N))
    return out
end

sign_oracle(::Type{LHYTerm}) = (
    name="LHYTerm: c_lhy > 0 ⇒ E_LHY > 0 (repulsive correction)",
    predicate=function (psi, ws)
        c_lhy = ws.lhy === nothing ? ws.interactions.c_lhy : 1.0
        E = energy_contribution(LHYTerm(), psi, ws)
        return c_lhy >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)

# ============================================================================
# LHY energy bodies (multi-dispatch over LHY type)
# ============================================================================
#
# Used by both `_energy_decomposition_cpu` and the trinity `energy_contribution`
# above. Scalar (fully-polarized) variant emits a one-shot warning for
# spinor condensates — the spinor LHY is research-open (Eu F=6 + DDI not
# closed; the codebase ships closed forms only for specific phase ansatze).

"""
LHY energy in the scalar (fully-polarized) approximation:
`E_LHY = (2/5) c_lhy ∫ n^{5/2} dV`.

For spinor condensates (n_comp > 1), the true LHY correction depends on the
Bogoliubov spectrum of the full spin-F system and can differ qualitatively.
For F ≥ 3 (e.g. Eu151 F=6) the spinor LHY problem is **research-open**
— use the `lhy: {kind: ...}` block in `ground_state` to select an
appropriate closed-form table, or disable LHY (`gamma_lhy: 0`) and rely
on TF when ε_dd ≲ 1 and the cloud is far from droplet onset.
"""
function _lhy_energy(psi, c_lhy, n_comp, ndim, n_pts, dV)
    if n_comp > 1
        @warn """LHY energy uses scalar (fully-polarized) approximation for a \
spinor condensate (n_comp=$n_comp). Spin-dependent LHY corrections are not \
included. To use the two-channel spinor LHY table, set `lhy: {kind: two_channel}` \
in the YAML ground_state step. \
For F ≥ 3 the two-channel table is also incomplete — see _lhy_energy docstring.""" maxlog=1
    end
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        E += ni * ni * sqrt(ni)
    end
    (2.0 / 5.0) * c_lhy * E * dV
end

function _lhy_energy(psi, lhy::ScalarLHY, n_comp, ndim, n_pts, dV)
    _lhy_energy(psi, lhy.c_lhy, n_comp, ndim, n_pts, dV)
end

function _lhy_energy(psi, lhy::Quasi2DLHY, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        ni < 1e-30 && continue
        E += ni * ni * (log(ni * lhy.a_2d_sq) + lhy.log_const)
    end
    0.5 * lhy.c_lhy_2d * E * dV
end

function _lhy_energy(::Any, ::NoLHY, _n_comp, _ndim, _n_pts, _dV)
    0.0
end

# Spatially-varying: ε_LHY = n^(5/2) e₁(p(r)), so the energy needs the same
# local polarisation the propagator uses. Kept beside `_lhy_V(n, p, ·)` in
# spirit — if these two ever disagree the term drifts silently, which is the
# bug class the HamTerm protocol exists to prevent.
function _lhy_energy(psi, lhy::SpatialLHY, n_comp, ndim, n_pts, dV)
    D = n_comp
    F = lhy.F
    fp = lhy.fp_coeffs
    Ns = prod(n_pts)
    P = reshape(psi, Ns, D)
    E = 0.0
    @inbounds for i in 1:Ns
        s = 0.0
        for c in 1:D
            s += abs2(P[i, c])
        end
        s < 1e-30 && continue
        p = _local_polarisation(P, i, s, F, fp, Val(D))
        e1 = _interpolate_1d(lhy.polarisations, lhy.e1_values, clamp(p, 0.0, 1.0))
        E += e1 * s * s * sqrt(s)          # n^(5/2)
    end
    E * dV
end

# Shared energy eval for all table-based modes (TabulatedLHY subtypes).
#
# E = ∫ ε(n) dV, and the table stores V = dε/dn, so the energy density is the
# INTEGRAL of the table from 0 to n — not `n·V(n)`.
#
# It was `n·V(n)`, which for the ε ∝ n^(5/2) that every one of these tables
# has gives `n·V = (5/2)ε`: the reported LHY energy was exactly 2.5× too large
# for every tabulated mode. Verified against the closed form on a uniform
# cloud — ratio 2.500002 — while `∫₀ⁿ V dn'` reproduces ε to 6.8e-5, so the
# tables themselves were always right and only this reduction was wrong.
# The propagator was unaffected: it uses V directly.
function _lhy_energy(psi, lhy::TabulatedLHY, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    cum = _lhy_energy_density_table(lhy)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        ni < 1e-30 && continue
        E += _lhy_energy_density(lhy.densities, lhy.potential_values, cum, ni)
    end
    E * dV
end

# ε(n) = ∫₀ⁿ V dn', by cumulative trapezoid over the table's own nodes. Cached
# per table object: the tables are immutable and built once per workspace, and
# an energy call would otherwise redo this over every voxel.
"""
    _lhy_energy_density(xs, ys, cum, n) -> ε(n)

`ε(n) = ∫₀ⁿ V dn'` with V taken to be the SAME piecewise-linear interpolant the
propagator evaluates, so the integral is exact rather than table-resolution
accurate: on the interval containing `n`,

    ε = cum[i] + V(xᵢ)·δ + ½·slope·δ²,     δ = n − xᵢ

Linearly interpolating `cum` instead would make dε/dn the interval AVERAGE of V
rather than V(n) — a 0.5% mismatch between the energy and the potential at
n_points = 4000, i.e. the two faces of the term disagreeing by a discretisation
artifact. Doing it this way, `dE/dn == V` to FD precision by construction.
"""
@inline function _lhy_energy_density(xs::Vector{Float64}, ys::Vector{Float64},
    cum::Vector{Float64}, n::Float64)
    m = length(xs)
    m < 2 && return 0.0
    n <= xs[1] && return 0.0
    @inbounds if n >= xs[m]
        return cum[m] + ys[m] * (n - xs[m])      # flat extrapolation, as `_lhy_V`
    end
    i = searchsortedlast(xs, n)
    i < 1 && return 0.0
    @inbounds begin
        h = xs[i + 1] - xs[i]
        d = n - xs[i]
        slope = (ys[i + 1] - ys[i]) / h
        cum[i] + ys[i] * d + 0.5 * slope * d * d
    end
end

const _LHY_EPS_CACHE = IdDict{Any, Vector{Float64}}()

function _lhy_energy_density_table(lhy::TabulatedLHY)
    get!(_LHY_EPS_CACHE, lhy) do
        xs, ys = lhy.densities, lhy.potential_values
        cum = similar(ys)
        acc = 0.0
        @inbounds cum[1] = 0.0
        @inbounds for i in 2:length(xs)
            acc += 0.5 * (ys[i] + ys[i - 1]) * (xs[i] - xs[i - 1])
            cum[i] = acc
        end
        cum
    end
end

"""
    _grad_lhy!(grad, psi, ws, n_density, n_pts, D, ::Val{N})

Add scalar LHY contribution `c_lhy·n^(3/2)·ψ` to `grad`. Active only
for the scalar c_lhy branch (rest delegate to apply_step!). Gated on
`ws.interactions.c_lhy != 0`.
"""
function _grad_lhy!(grad, psi, ws, n_density, n_pts, D, ::Val{N}) where {N}
    c_lhy_val = ws.interactions.c_lhy
    c_lhy_val != 0.0 || return nothing
    v_lhy = c_lhy_val .* n_density .* sqrt.(max.(n_density, 0.0))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= v_lhy .* view(psi, idx...)
    end
    nothing
end
