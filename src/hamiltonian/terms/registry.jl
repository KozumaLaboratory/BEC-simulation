# --- HamTerm registry: structural single-source-of-truth dispatch ---
#
# Phase 3 (Phase 1-3 = the "sign-bug-proof architecture";
# `docs/conventions/sign_bug_proof_architecture.md`).
#
# The registry is an `NTuple{14, HamTerm}` derived from a Workspace.
# Hot paths (`energy_decomposition`, `energy_gradient!`,
# `split_step!`) delegate to the registry; per-term implementations
# declare their sign in one place (`apply_step!` /
# `energy_contribution` / `apply_operator!`) and CI oracles
# (`test/oracles/`) verify both directional sign and FD consistency
# between energy and gradient.
#
# ## Performance discipline
#
# The registry is wrapped in a `Tuple` (NOT `Vector`) so that
# `for term in registry` is unrolled by the compiler — each iteration
# specializes on its term's concrete type, eliding abstract dispatch.
# Inactive terms (`DDITerm()` when `ws.ddi === nothing`, etc.)
# short-circuit at the top of each method so the cost is one branch.
#
# ## Context-aware variants
#
# `energy_contribution(term, psi, ws)` recomputes shared scratch each
# call. For the production hot path,
# `energy_contribution(term, psi, ws, ctx::EnergyContext)` reuses the
# pre-built density, spin density, and FFT buffer. The non-context
# variant remains the canonical entry point for single-term tests.

# ============================================================================
# Built-in 14-term ordering
# ============================================================================

"""
    H_TERMS_CANONICAL_ORDER

The canonical ordering of HamTerm subtypes that `build_h_terms_registry`
and `energy_breakdown_via_registry` use. Adding a new term means:

1. Add the subtype to this list at its physically meaningful slot.
2. Add the corresponding field to `energy_breakdown_via_registry`'s
   NamedTuple return.
3. Update `legacy_energy_field_for` if there is a legacy synonym in
   `energy_decomposition` for the new term.
"""
const H_TERMS_CANONICAL_ORDER = (
    :kinetic,
    :trap,
    :zeeman,
    :density_c0,
    :spin_c1,
    :ddi,
    :lhy,
    :tensor,
    :raman,
    :light_shift,
    :coriolis,
    :magnetic_gradient,
    :spatial_zeeman,
    :loss,
)

"""
    build_h_terms_registry(ws) → NTuple{14, HamTerm}

Build a fresh NTuple from `ws` for the current `t = ws.state.t`. For
time-dependent fields (Zeeman, MagneticGradient, Coriolis Ω) the
returned terms are evaluated at the current time; downstream callers
should rebuild after `ws.state.t` changes.

Inactive terms are still emitted with neutral state so the NTuple is
type-stable across configurations. Methods on each `HamTerm` subtype
short-circuit at the top of `energy_contribution` / `apply_operator!` /
`apply_step!` when their controlling workspace field is `nothing` or
coefficients are zero.
"""
function build_h_terms_registry(ws)
    t = ws.state.t
    z = zeeman_at(ws.zeeman, t)
    bx, by = transverse_b(ws.zeeman, t)
    Ω = ws.sim_params.rotating_frame_omega
    # Spin-rotating-frame corrections (App. A defect-5 fix, 2026-06-06):
    # the propagator evolves in the RF — `zeeman_diagonal(z, sm, ω_R)`
    # uses p_eff = p − ω_R (accessors.jl) and the transverse step
    # rotates (bx, by) into RF coordinates at t (split_step.jl). The
    # registry faces must present the SAME effective Hamiltonian, or
    # LBFGS optimizes a lab-frame functional while the dynamics run a
    # rotated one. Conventions mirror those two production sites.
    ω_R = ws.sim_params.spin_rotating_frame_omega
    p_eff = z.p - ω_R
    if is_active(ω_R, ROTATION_TOL)
        cR = cos(ω_R * t)
        sR = sin(ω_R * t)
        bx, by = bx * cR + by * sR, -bx * sR + by * cR
    end
    return (
        KineticTerm(),
        TrapTerm(),
        ZeemanTerm(bx, by, p_eff, z.q),
        DensityC0Term(ws.interactions[0]),
        SpinC1Term(ws.interactions[1]),
        DDITerm(),
        LHYTerm(),
        TensorTerm(),
        RamanTerm(),
        LightShiftTerm(),
        CoriolisTerm(Ω),
        MagneticGradientTerm(),
        SpatialZeemanTerm(),
        LossTerm(),
    )
end

# ============================================================================
# Shared scratch context builders (struct defs are in `base.jl`)
# ============================================================================

function build_energy_context(psi_host::Array{<:Complex, ND_psi}, ws) where {ND_psi}
    # Scratch-backed (P1): the previous builder allocated a full ψ copy
    # + 5 grid-sized buffers per call (~4 MB at 24³×D=13) and had zero
    # callers. Buffers come from the shared scratch registry; ψ is
    # never copied (CPU-only entry point — the GPU energy path is
    # `_energy_decomposition_gpu`, P2 territory).
    N = ND_psi - 1
    n_pts = ntuple(d -> size(psi_host, d), Val(N))
    dV = cell_volume(ws.grid)
    n_comp = size(psi_host, ND_psi)
    fft_buf, n_density, fx, fy, fz = scratch_get!(
        :energy_context, (eltype(psi_host), n_pts)
    ) do
        (
            zeros(ComplexF64, n_pts), zeros(Float64, n_pts),
            zeros(Float64, n_pts), zeros(Float64, n_pts), zeros(Float64, n_pts),
        )
    end
    _total_density!(n_density, psi_host, n_comp, N, n_pts)
    _compute_spin_density!(fx, fy, fz, psi_host, ws.spin_matrices, Val(n_comp), N, n_pts)
    return EnergyContext(
        psi_host, fft_buf, ws.fft_plans, ws.spin_matrices,
        n_density, fx, fy, fz, dV, n_pts,
    )
end

function build_gradient_context(psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fft_buf, fx_scratch, fy_scratch, fz_scratch, deriv_buf = _energy_gradient_scratch(psi, n_pts)
    # Scratch-backed density on CPU (P1: total_density allocated a
    # grid-sized array per LBFGS gradient call); the GPU branch keeps
    # the device-aware allocating helper until P2.
    n_density = if psi isa Array
        buf = scratch_get!(:gradient_n_density, (eltype(psi), n_pts)) do
            zeros(Float64, n_pts)
        end
        _total_density!(buf, psi, D, N, n_pts)
        buf
    else
        total_density(psi, N)
    end
    _compute_spin_density!(
        fx_scratch, fy_scratch, fz_scratch, psi, ws.spin_matrices,
        Val(D), N, n_pts,
    )
    return GradientContext(
        fft_buf, deriv_buf, fx_scratch, fy_scratch, fz_scratch,
        n_density, n_pts,
    )
end

# ============================================================================
# Registry sums (context-free convenience entry points)
# ============================================================================

"""
    apply_operator_via_registry!(grad, ws) → grad

Build δE/δψ* by iterating the registry. Bit-identical to the in-place
sum performed by `energy_gradient!` modulo the `* 2` Wirtinger scaling
that `energy_gradient!` applies at the end. The
`GradientContext`-aware overload below is the production path.

Callers receive an accumulated result: `grad` is zeroed here before
the registry loop so callers get bare H·ψ, not H·ψ added to whatever
was in `grad` before the call.
"""
function apply_operator_via_registry!(grad, ws)
    fill!(grad, zero(eltype(grad)))
    psi = ws.state.psi  # same-device as grad; trinity methods are device-aware
    ctx = build_gradient_context(psi, ws)
    registry = build_h_terms_registry(ws)
    for term in registry
        apply_operator!(grad, term, ws, psi, ctx)
    end
    return grad
end

# Default fallback: terms that have not opted into ctx-aware dispatch
# fall back to the simpler signature (zero `out` first, then accumulate).
@inline apply_operator!(out, term::HamTerm, ws, psi, ::GradientContext) =
    apply_operator!(out, term, ws, psi)

@inline energy_contribution(term::HamTerm, psi, ws, ::EnergyContext) =
    energy_contribution(term, psi, ws)

# ============================================================================
# Per-term energy breakdown
# ============================================================================

"""
    energy_breakdown_via_registry(ws) → NamedTuple

Per-term energy breakdown via the registry. Returns a NamedTuple with
one field per `H_TERMS_CANONICAL_ORDER` slot plus `:total`. The field
names match `energy_decomposition`'s legacy keys (via
`legacy_energy_field_for`) so callers expecting the legacy shape can
slot in this implementation directly.
"""
function energy_breakdown_via_registry(ws)
    registry = build_h_terms_registry(ws)
    psi = ws.state.psi  # same-device as ws; trinity methods handle GPU vs CPU
    contributions = if psi isa Array
        # P1 hot path: shared EnergyContext (scratch-backed) lets the
        # ctx-aware overloads skip per-term grid-sized allocations.
        ctx = build_energy_context(psi, ws)
        map(term -> energy_contribution(term, psi, ws, ctx), registry)
    else
        map(term -> energy_contribution(term, psi, ws), registry)
    end
    total = sum(contributions)
    return NamedTuple{(H_TERMS_CANONICAL_ORDER..., :total)}((contributions..., total))
end

"""
    legacy_energy_field_for(slot::Symbol) → Symbol

Map a registry slot name to the corresponding field name in the
legacy `energy_decomposition` NamedTuple. Used by
`energy_decomposition_via_registry_legacy_shape` to emit a NamedTuple
in the historic shape `(kinetic, trap, zeeman, density, spin, ddi,
lhy, tensor, raman, light_shift, coriolis, total)`.
"""
function legacy_energy_field_for(slot::Symbol)
    slot === :density_c0 && return :density
    slot === :spin_c1 && return :spin
    return slot
end

"""
    energy_decomposition_via_registry_legacy_shape(ws) → NamedTuple

Emit the same shape as `energy_decomposition(ws)`:
`(kinetic, trap, zeeman, density, spin, ddi, lhy, tensor, raman,
light_shift, coriolis, total)` — fused diagonal+transverse Zeeman
into a single `:zeeman` field, mapped contact terms to
`:density`/`:spin`. Drops the `:magnetic_gradient` and `:loss` slots
when their energy is identically zero (MG energy is non-trivial when
present and is reported in the extra `_extra` NamedTuple).
"""
function energy_decomposition_via_registry_legacy_shape(ws)
    bd = energy_breakdown_via_registry(ws)
    return (
        kinetic=bd.kinetic,
        trap=bd.trap,
        zeeman=bd.zeeman,
        density=bd.density_c0,
        spin=bd.spin_c1,
        ddi=bd.ddi,
        lhy=bd.lhy,
        tensor=bd.tensor,
        raman=bd.raman,
        light_shift=bd.light_shift,
        coriolis=bd.coriolis,
        magnetic_gradient=bd.magnetic_gradient,
        spatial_zeeman=bd.spatial_zeeman,
        loss=bd.loss,
        total=bd.total,
    )
end
