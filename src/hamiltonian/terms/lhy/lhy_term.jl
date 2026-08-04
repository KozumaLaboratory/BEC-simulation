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
    # Via `_lhy_potential_field`, NOT a bare `_lhy_V.(n, Ref(lhy))`. On the GPU a
    # `TabulatedLHY` cannot cross into a kernel — it holds host `Vector{Float64}`
    # tables, so the broadcast dies with "passing non-bitstype argument". The
    # CUDA extension overrides `_lhy_potential_field` for `TabulatedLHY` (uploads
    # the table once per objectid, O(1) uniform-grid lookup); the CPU method is
    # exactly the broadcast this replaces, so CPU behaviour is unchanged.
    V = _lhy_potential_field(lhy, n, real(eltype(psi)))
    phase = imaginary_time ? exp.(.-V .* dt) : cis.(.-V .* dt)
    D = size(psi, N + 1)
    idx = ntuple(_ -> :, Val(N))
    for c in 1:D
        view(psi, idx..., c) .*= phase
    end
    return nothing
end

"""NOT derivable from the operator, so the registry falls back to
`energy_contribution` for this term.

`0.4` is the right constant for the CLOSED FORM: `ε ∝ n^(5/2)` and `V = dε/dn`
give `n·V = (5/2)ε`. It is not right for the implementation. The tabulated
modes integrate a piecewise-linear `V`, and `energy_contribution` measured
`0.96·⟨ψ,V·ψ⟩` against the `0.4` this declared — a 0.93 % error in the total
energy, which surfaced as every cached ground state failing its own verdict
check (`test_gs_admission_axes.jl`).

Declared `NaN` rather than `0.96`: that number is a fit to one fixture at one
density, and pinning a constant that the physics derives is a mistake this
repository has made before. The relationship may well be recoverable — `ε` is
the exact integral of the same piecewise-linear `V` the propagator uses — but
recovering it is a change to `energy_contribution`, not a coefficient to guess
here.

Costs one `energy_contribution` call per gradient pass when LHY is active."""
energy_operator_ratio(::LHYTerm) = NaN

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
    lhy.c_lhy_2d * E * dV
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

Add `δE_LHY/δψ̄ = V_LHY(n)·ψ` to `grad`, for whichever LHY the workspace holds.

`E_LHY = ∫ ε(n) dV` and `V = dε/dn`, so the functional derivative is just the
same potential the propagator applies — there is one `_lhy_V` behind the
propagator, the energy and this.

It used to read `ws.interactions.c_lhy` only, so every table produced a
gradient of EXACTLY ZERO, with no warning. Measured against a finite difference
of `_lhy_energy` for `PolarContactLHY`: |grad| = 0 against a true 628.9, while
`V(n)·ψ` reproduces the FD to 1.4e-7. LBFGS would "converge" on a Hamiltonian
missing the whole LHY term while ITP, which goes through the propagator, had it.
"""
function _grad_lhy!(grad, psi, ws, n_density, n_pts, D, ::Val{N}) where {N}
    lhy = ws.lhy === nothing ? ws.interactions.c_lhy : ws.lhy
    _lhy_is_active(lhy) || return nothing
    _lhy_needs_spin(lhy) && return _grad_lhy_spatial!(grad, psi, lhy, n_pts, D, Val(N))
    # Same reason as `apply_step!` above: this is the LBFGS gradient path, and a
    # bare broadcast of `_lhy_V` over a device array cannot carry a tabulated
    # LHY into the kernel. `method: lbfgs` + `lhy: {kind: full_bdg}` +
    # `backend: gpu` died here with a KernelError once #179 made the table reach
    # this path at all.
    v_lhy = _lhy_potential_field(lhy, n_density, real(eltype(psi)))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= v_lhy .* view(psi, idx...)
    end
    nothing
end

"""
    _grad_lhy_spatial!(grad, psi, lhy::SpatialLHY, n_pts, D, ::Val{N})

`δE/δψ̄` for the spatially-varying LHY, where `ε = n^(5/2) e₁(p)` depends on ψ
through the local polarisation `p = |⟨F⟩|/F` as well as through `n`:

    δε/δψ̄ = (5/2) n^(3/2) e₁(p) ψ  +  n^(3/2) e₁′(p) [ (ŝ·F)ψ / F − p ψ ]

The first term is `_lhy_V(n, p, lhy)·ψ`, the diagonal potential the propagator
applies. The second is not diagonal — `ŝ = ⟨F⟩/|⟨F⟩|` — so it exists only here.
Verified against a finite difference of `_lhy_energy(::SpatialLHY)` to 8e-10.

The diagonal propagator step has no place to put a spin operator, so until issue
#131 it simply omitted the second term — a measured **2.3%** of the gradient
norm on a random F=6 spinor with the ~20% `e₁(p)` variation `spatial.jl` reports
at F=6, which left ITP and LBFGS minimising different functionals for this one
mode. `apply_spatial_lhy_spin_step!` now applies it as its own substep, a
per-voxel rotation about the local ⟨F⟩ axis, and
`test_spatial_lhy_spin_substep.jl` pins that the propagator and this gradient
agree. `test_lhy_gradient_all_modes.jl` still pins the 2.3% as a statement about
the DIAGONAL potential in isolation — which is what keeps the substep's
contribution measured rather than assumed.

`ŝ·F` uses the ladder form, from the SAME `fp_coeffs` and component convention
as `_local_polarisation`: `(F₊ψ)_c = fp[c+1]·ψ_{c+1}`, `(F₋ψ)_c = fp[c]·ψ_{c-1}`,
`(F_zψ)_c = (F−c+1)·ψ_c`.
"""
function _grad_lhy_spatial!(grad, psi, lhy::SpatialLHY, n_pts, D, ::Val{N}) where {N}
    F = lhy.F
    fp = lhy.fp_coeffs
    Ns = prod(n_pts)
    P = reshape(psi, Ns, D)
    G = reshape(grad, Ns, D)
    @inbounds for i in 1:Ns
        n = 0.0
        fz = 0.0
        for c in 1:D
            a = abs2(P[i, c])
            n += a
            fz += (F - (c - 1)) * a
        end
        n < 1e-30 && continue
        sp = zero(ComplexF64)
        for c in 2:D
            sp += fp[c] * conj(P[i, c - 1]) * P[i, c]
        end
        smag = sqrt(abs2(sp) + fz * fz)
        p = smag / (n * F)

        v = _lhy_V(n, p, lhy)
        for c in 1:D
            G[i, c] += v * P[i, c]
        end

        de1 = _lhy_de1_dp(lhy, clamp(p, 0.0, 1.0))
        (de1 == 0.0 || smag < 1e-30) && continue
        pref = n * sqrt(n) * de1
        for c in 1:D
            sf = fz * (F - (c - 1)) * P[i, c]
            c < D && (sf += 0.5 * conj(sp) * fp[c + 1] * P[i, c + 1])
            c > 1 && (sf += 0.5 * sp * fp[c] * P[i, c - 1])
            G[i, c] += pref * (sf / (smag * F) - p * P[i, c])
        end
    end
    nothing
end
