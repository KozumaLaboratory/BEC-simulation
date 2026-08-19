# --- Spec → runtime: the other direction of the layer ---
#
# `gs_model` (`pipeline/resolve_gs.jl`) walks RUNTIME objects and produces
# `Model`. This file is its inverse: it walks a `Model` and produces the runtime
# objects `make_workspace` takes. Until 2026-08-19 only the forward arrow
# existed, which is why `src/model.jl` said `make_workspace(::Model)` was "still
# to come" — a Model could be built from a solve but could not drive one.
#
# WHY THIS IS AN INVERSE AND NOT A SECOND PARSER
#
# The whole point of the Model layer is to delete second readers of `potential:`
# / `B:` / `lhy:` / `ddi:`. A realisation layer that re-derived those from the
# YAML would be exactly the thing being deleted, one level down. So nothing here
# touches a config: every function's input is a `*Spec` and its output is the
# runtime object that spec was built FROM.
#
# That makes the layer testable by ROUND TRIP rather than by pinned values:
#
#     realise_* (gs_model(r)) == the runtime object in r
#
# for every config in the corpus. A pinned-number test would move with the
# resolver it is checking; a round trip cannot — it fails the moment the two
# directions disagree about anything, including a field neither test author
# thought about. `test/model/test_realise_matches_resolver.jl` is that gate, and
# it earned its keep on the first run: two sign flips (`c1`, `p`), from using
# `waveform_magnitude` — which is `abs` — where a signed value was wanted.
#
# WHERE THE ROUND TRIP IS NOT EXACT, AND WHY
#
# Three places, each named rather than smoothed over:
#
#   1. `PotentialSpec` is a SUM of typed terms, so realising it produces a
#      `CompositePotential` even when the original was a bare `HarmonicTrap`.
#      One term round-trips to itself (see `_realise_potential`), which is the
#      case every committed config takes.
#   2. `QuarticPotential` and `HarmonicTrap` share `HarmonicSpec`: the former is
#      the latter with `lambda != 0`. Realisation picks by `lambda`, which is
#      what the forward walk encoded.
#   3. `ShakenLatticePotential` forward-samples its shake waveform to a
#      `PiecewiseLinearWaveform`; realising gives back the sampled form, not the
#      analytic one. Values agree at the sample points by construction, and the
#      round-trip gate compares EVALUATED potentials rather than struct equality
#      for that reason.

export realise_grid, realise_interactions, realise_potential, realise_zeeman,
    realise_ddi_kwargs, realise_lhy, realise_raman, realise_light_shift,
    realise_magnetic_gradient, realise_sim_params, model_physics_kwargs

# ---------------------------------------------------------------------------
# waveforms
# ---------------------------------------------------------------------------
#
# `ModelWaveform = Union{Float64, PiecewiseLinearWaveform}` and the second member
# is already a runtime `AbstractWaveform`, so this direction has nothing to
# reconstruct. It exists as a named function anyway: the call sites read as
# "realise this waveform" rather than as an untyped pass-through, and a future
# `ModelWaveform` member that is NOT already runtime-shaped gets one place to be
# handled.
@inline _realise_wf(w::Float64) = w
@inline _realise_wf(w::PiecewiseLinearWaveform) = w

"Is this model waveform a plain constant? Decides `Zeeman{Params,Field}` etc."
@inline _wf_is_const(w::Float64) = true
@inline _wf_is_const(::PiecewiseLinearWaveform) = false

"""
The SIGNED value of a constant model waveform.

`waveform_magnitude` is NOT this: it returns `max|value|`, because its job is to
answer the `active` predicates ("does this knob ever contribute an operator"),
and for that `abs` is right. Using it to extract a value silently drops the sign.

That is not hypothetical — the first draft of this file used it at six sites and
`test_realise_matches_resolver.jl` caught two of them numerically: `c1` realised
as `+16.35` against the resolver's `-16.35`, and `p` as `+162.76` against
`-162.76`. A sign-flipped `p` inverts the Zeeman ground state (m = -F becomes
m = +F) and a sign-flipped `c1` swaps ferromagnetic for polar. Both are the
`bfield_to_p` defect class, arriving through a helper whose name reads like an
accessor.

So: `_wf_value` for values, `waveform_magnitude` for activity, and never the
other way round.
"""
@inline _wf_value(w::Float64) = w
@inline _wf_value(w::PiecewiseLinearWaveform) = waveform_at(w, 0.0)

# ---------------------------------------------------------------------------
# grid
# ---------------------------------------------------------------------------

"""
    realise_grid(s::GridSpec) -> Grid

Build the `Grid` the spec describes. The dealias globals are NOT touched here:
`GridSpec` carries them because they change the physical meaning of a grid (the
Orszag cutoff is dimensionful, `ddi_loss.jl:25`), but they live in `Ref`s that
`run_yaml` owns and restores. `realise_sim_params` reports them instead so a
caller can apply them under its own `finally`.
"""
function realise_grid(s::GridSpec)
    n = ntuple(d -> s.n_points[d], s.ndim)
    box = ntuple(d -> s.box[d], s.ndim)
    make_grid(GridConfig(n, box))
end

# ---------------------------------------------------------------------------
# interactions
# ---------------------------------------------------------------------------

"""
    realise_interactions(s::InteractionSpec) -> InteractionParams

Rebuild the rank => coupling `Dict`. `c_lhy` is deliberately NOT set here even
though `InteractionParams` has the field: `LHYSpec` owns the LHY, and
`realise_lhy` returns the `(spinor_lhy, lhy_opts)` pair that `make_workspace`
dispatches on. Writing `c_lhy` here as well would put the LHY in two slots, and
the forward walk had to REFUSE a config in that state (`gs_model`'s c_lhy check)
precisely because make_workspace builds a `ScalarLHY` from a stray `c_lhy`
regardless of the kind.

The closed-form scalar kinds ARE driven by `c_lhy`, and `realise_lhy` passes it
through the `spinor_lhy` symbol + the coefficient on the spec, so nothing is
lost.
"""
function realise_interactions(s::InteractionSpec)
    c = Dict{Int, Float64}()
    c0, c1 = _wf_value(s.c0), _wf_value(s.c1)
    # Rank 0/1 are always present, including when zero: the scattering-lengths
    # path is exactly `c0 = c1 = 0` with the tensor cache carrying every channel,
    # and dropping the keys would make that path indistinguishable from "no
    # contact interaction declared".
    c[0] = c0
    c[1] = c1
    for (k, v) in zip(s.c_extra_ranks, s.c_extra_values)
        c[k] = v
    end
    InteractionParams(c)
end

# ---------------------------------------------------------------------------
# potential
# ---------------------------------------------------------------------------

"""
    realise_potential(s::PotentialSpec, ndim::Int) -> AbstractPotential

Sum the spec's typed terms back into one `AbstractPotential`.

Returns `NoPotential()` for an inactive spec and the bare term for a
single-term one, so the common shapes round-trip to themselves rather than to a
one-element `CompositePotential`. Multi-term specs give a `CompositePotential`,
which is what the forward walk decomposed.

`ndim` is required: every potential type is parameterised on it and carries
`NTuple{ndim}` fields, while the spec pads to 3. Every constructor call below
mirrors `_build_potential` (`schema/builders_potential.jl`) — the config-driven
builder that actually runs — rather than the struct definitions, so the two
construction paths cannot drift into different `{N}` conventions.
"""
function realise_potential(s::PotentialSpec, ndim::Int)
    terms = AbstractPotential[]
    for h in s.harmonic
        push!(terms, _realise_harmonic(h, ndim))
    end
    for l in s.lattice
        push!(terms, _realise_lattice(l, ndim))
    end
    for r in s.ring
        push!(terms, RingPotential{ndim}(r.radius, r.strength, r.width))
    end
    for b in s.box
        push!(terms, BoxPotential{ndim}(_trim(b.size, ndim), b.wall_strength, b.wall_width))
    end
    for g in s.gravity
        push!(terms, GravityPotential{ndim}(g.g, g.axis))
    end
    for d in s.double_well
        push!(terms,
            DoubleWellPotential{ndim}(d.separation, d.barrier, _trim(d.omega, ndim), d.axis))
    end
    for b in s.beam
        push!(terms, _realise_beam(b, ndim))
    end
    for d in s.dipole_trap
        push!(terms, CrossedDipoleTrap{ndim}(collect(d.beams), d.polarizability))
    end
    isempty(terms) && return NoPotential()
    length(terms) == 1 && return terms[1]
    CompositePotential{ndim}(terms)
end

"Drop a 3-padded spec tuple to the grid's dimensionality."
@inline _trim(t::NTuple{3, T}, ndim::Int) where {T} = NTuple{ndim, T}(t[1:ndim])

# `HarmonicSpec` covers both traps: `lambda == 0` is `HarmonicTrap`, non-zero is
# `QuarticPotential`. A waveform-valued omega is `TimeDependentTrap`, which is
# what the forward walk's "subsumed by a waveform-valued HarmonicSpec.omega"
# note refers to.
function _realise_harmonic(h::HarmonicSpec, ndim::Int)
    om = NTuple{ndim, Float64}(ntuple(d -> _wf_value(h.omega[d]), ndim))
    lam = _trim(h.lambda, ndim)
    if all(_wf_is_const, h.omega)
        return any(is_active, lam) ? QuarticPotential{ndim}(om, lam) : HarmonicTrap(om)
    end
    any(is_active, lam) && throw(
        ArgumentError(
            "a time-dependent omega with a non-zero quartic lambda has no runtime type: " *
            "`TimeDependentTrap` wraps a base potential and carries omega waveforms, " *
            "`QuarticPotential` is static. Refused rather than dropping the quartic term."),
    )
    # `TimeDependentTrap` wraps a BASE potential and modulates its omegas; the
    # base is the trap at the waveform's own t=0 value, which is what
    # `HarmonicTrap(om)` above already is (`waveform_magnitude` of a ramp is its
    # representative magnitude, so the base is only a shape carrier — the
    # evaluator reads `omega_wf`).
    TimeDependentTrap{ndim}(HarmonicTrap(om),
        NTuple{ndim, Waveform}(ntuple(d -> _as_waveform(h.omega[d]), ndim)))
end

# `LatticeSpec.phase` is a waveform triple: constant is the static lattice,
# time-dependent is the shaken one.
function _realise_lattice(l::LatticeSpec, ndim::Int)
    depth = _trim(l.depth, ndim)
    period = _trim(l.period, ndim)
    if all(_wf_is_const, l.phase)
        ph = NTuple{ndim, Float64}(ntuple(d -> _wf_value(l.phase[d]), ndim))
        return OpticalLatticePotential{ndim}(depth, period, ph)
    end
    ShakenLatticePotential{ndim}(depth, period,
        NTuple{ndim, Waveform}(ntuple(d -> _as_waveform(l.phase[d]), ndim)))
end

# `BeamSpec` is `amplitude * (rho^2)^l * exp(-rho^2)` with `rho = sqrt(2) r /
# waist`. `l_mode == 0` is the `PlugBeam` shape and carries the factor-of-two
# waist convention the forward walk documents (`PlugBeam.waist` is HALF the
# 1/e^2 radius); non-zero l needs the Laguerre-Gauss term.
function _realise_beam(b::BeamSpec, ndim::Int)
    b.l_mode == 0 && return PlugBeam{ndim}(b.amplitude, b.waist / 2)
    # Forward folded `amplitude = -polarizability * power`; one factorisation of
    # that product is as good as another for the evaluated potential, so put it
    # all in `power` and leave polarizability at -1. Field order is
    # (power, waist, l_mode, p_mode, polarizability) — from `_build_potential`,
    # not from the struct's declaration order, which is the same thing here but
    # would not have to be.
    LaguerreGaussBeam{ndim}(b.amplitude, b.waist, b.l_mode, 0, -1.0)
end

_as_waveform(w::Float64) = ConstantWaveform(w)
_as_waveform(w::PiecewiseLinearWaveform) = w

# ---------------------------------------------------------------------------
# zeeman
# ---------------------------------------------------------------------------

"""
    realise_zeeman(s::ZeemanSpec, grid) -> AbstractZeemanField

`ZeemanParams` when every knob is constant and there is no transverse or
spatial structure — the shape almost every ground state takes, and the one whose
diagonal the fused kernel folds in. `TimeDependentZeeman` when a knob ramps or a
transverse component is present. A `spatial_kind` other than `:uniform` builds
the per-voxel field, which needs the grid.

`grid` is required rather than optional: a spatial field cannot be built without
it, and an API that silently dropped the spatial arm when the grid was missing is
the drop-shaped defect this whole campaign is about.
"""
function realise_zeeman(s::ZeemanSpec, grid)
    if s.spatial_kind !== :uniform
        return _realise_spatial_zeeman(s, grid)
    end
    static = all(_wf_is_const, (s.p, s.q, s.bx, s.by))
    transverse = is_active(waveform_magnitude(s.bx)) || is_active(waveform_magnitude(s.by))
    if static && !transverse
        return ZeemanParams(_wf_value(s.p), _wf_value(s.q))
    end
    TimeDependentZeeman(
        _as_waveform(s.p), _as_waveform(s.q), _as_waveform(s.bx), _as_waveform(s.by))
end

function _realise_spatial_zeeman(s::ZeemanSpec, grid)
    k = s.spatial_kind
    ndim = length(grid.config.n_points)
    ax = min(3, ndim)
    if k === :gradient
        # bz(r) = bias + gradient * x_ax. The builder's own name for this axis
        # argument is the axis the gradient runs along.
        return spatial_zeeman_field(grid;
            bz=_spatial_bz_gradient(s, ax), bx=nothing, by=nothing)
    elseif k === :curvature
        return spatial_zeeman_field(grid;
            bz=_spatial_bz_curvature(s, ax), bx=nothing, by=nothing)
    end
    throw(
        ArgumentError(
            "ZeemanSpec.spatial_kind = :$k has no realisation. The known kinds are " *
            ":uniform, :gradient and :curvature; a new one needs a builder here, which " *
            "is a reviewed diff by design."),
    )
end

# Closures over the spec's scalars, built OUTSIDE the field constructor so each
# is one concrete function rather than a fresh closure type per call site.
_spatial_bz_gradient(s::ZeemanSpec, ax::Int) =
    let b = s.spatial_bias, g = s.spatial_gradient, c = s.spatial_center[ax]
        x -> b + g * (x[ax] - c)
    end

_spatial_bz_curvature(s::ZeemanSpec, ax::Int) =
    let b = s.spatial_bias, g = s.spatial_gradient, k = s.spatial_curvature,
        c = s.spatial_center[ax]

        x -> (d=x[ax] - c; b + g * d + 0.5 * k * d * d)
    end

# ---------------------------------------------------------------------------
# DDI
# ---------------------------------------------------------------------------

"""
    realise_ddi_kwargs(s::DDISpec, ndim::Int) -> NamedTuple

The eight `make_workspace` DDI kwargs, named. `DDISpec` has no `enabled` flag by
design — zero strength IS disabled — so `enable_ddi` is derived from `c_dd`.

`pad_factor` is trimmed to `ndim`: `make_workspace` takes a per-axis tuple whose
length must match the grid, while the spec pads to 3 (and `Model`'s constructor
normalises the unused axes for exactly this reason).
"""
function realise_ddi_kwargs(s::DDISpec, ndim::Int)
    enable = is_active(s.c_dd)
    (
        enable_ddi=enable,
        c_dd=enable ? s.c_dd : NaN,
        secular_ddi=s.secular,
        quasi_2d_ddi=s.quasi_2d,
        l_z_ddi=s.l_z,
        ddi_padding=s.padded,
        ddi_pad_factor=ntuple(d -> s.pad_factor[d], ndim),
        # `nothing` is the spec's spelling of "auto"; the kwarg's is the sentinel
        # `DDI_TRUNC_RADIUS_DEFAULT`. One conversion, and it is the inverse of
        # `ddi_trunc_radius_from_kwarg` that the forward walk uses.
        ddi_trunc_radius=s.trunc_radius === nothing ? DDI_TRUNC_RADIUS_DEFAULT :
                         s.trunc_radius,
    )
end

# ---------------------------------------------------------------------------
# LHY
# ---------------------------------------------------------------------------

"""
    realise_lhy(s::LHYSpec, n_atoms::Int) -> (spinor_lhy, lhy_opts, c_lhy)

The three things `make_workspace` needs, as a triple rather than as two kwargs
plus a hidden field:

  * `spinor_lhy::Union{Nothing,Symbol}` — the dispatch tag
  * `lhy_opts::LHYTableOpts`           — table resolution AND `n_atoms`
  * `c_lhy::Float64`                   — the closed-form scalar coefficient

`n_atoms` comes from `InteractionSpec`, not from the LHY spec, because
`LHYTableOpts` carrying its own is the drift that makes a tabulated table
`N_atoms`x too strong (defect #174). The spec deliberately has no slot for it;
this is where the two are joined, once.
"""
function realise_lhy(s::LHYSpec, n_atoms::Int)
    s.kind === :none && return (nothing, LHYTableOpts(; n_atoms), 0.0)
    if s.kind in LHY_CLOSED_SCALAR_KINDS
        return (s.kind, LHYTableOpts(; n_atoms), s.c_lhy)
    end
    (s.kind,
        LHYTableOpts(; n_max=s.n_max, n_points=s.n_points, n_bins=s.n_bins, n_atoms),
        0.0)
end

# ---------------------------------------------------------------------------
# the remaining field terms
# ---------------------------------------------------------------------------

"""
    realise_raman(s::RamanSpec, ndim::Int) -> Union{Nothing, RamanCoupling, TimeDependentRaman}
"""
function realise_raman(s::RamanSpec, ndim::Int)
    active(s) || return nothing
    k = ntuple(d -> s.k_eff[d], ndim)
    if _wf_is_const(s.omega_r) && _wf_is_const(s.delta)
        return RamanCoupling{ndim}(
            _wf_value(s.omega_r), _wf_value(s.delta), k)
    end
    TimeDependentRaman{ndim}(_as_waveform(s.omega_r), _as_waveform(s.delta), k)
end

"""
    realise_light_shift(s::LightShiftSpec, V_trap, F::Int, backend) -> Union{Nothing, LightShift}

Delegates to `make_light_shift_from_trap`, which is where the (eta_vector,
eta_tensor, polarization) triple becomes eigenvalues and where `profile =
abs.(V_trap)` is taken — the SAME call `_parse_light_shift` makes, so the two
entry points cannot disagree about the envelope.

`V_trap` is the evaluated potential ARRAY, not the potential object:
`profile_source = :trap` means "reuse the trap's own spatial envelope", and that
envelope only exists once the potential has been evaluated on a grid. That is
also why this is not called from `model_physics_kwargs` — the caller has to
evaluate the potential first, and `make_workspace` is what does that.
"""
function realise_light_shift(s::LightShiftSpec, V_trap, F::Int,
    backend::AbstractBackend=CPUBackend())
    active(s) || return nothing
    s.profile_source === :trap || throw(
        ArgumentError(
            "LightShiftSpec.profile_source = :$(s.profile_source) has no realisation. " *
            "`:trap` is the only member of LIGHT_SHIFT_PROFILE_SOURCES; a beam-shaped " *
            "profile needs its own builder here, which is a reviewed diff by design."),
    )
    make_light_shift_from_trap(V_trap, F, s.eta_tensor;
        eta_vector=s.eta_vector, polarization=s.polarization, backend)
end

"""
    realise_magnetic_gradient(s::GradientSpec, ndim::Int)
"""
function realise_magnetic_gradient(s::GradientSpec, ndim::Int)
    active(s) || return nothing
    _wf_is_const(s.gradient) &&
        return MagneticGradient{ndim}(_wf_value(s.gradient), s.axis, s.g_F)
    TimeDependentMagneticGradient{ndim}(_as_waveform(s.gradient), s.axis, s.g_F)
end

"""
    realise_sim_params(m::Model; dt, n_steps, kwargs...) -> SimParams

`Model` carries the physics; `dt` / `n_steps` / `imaginary_time` are METHOD, and
a Model that hashed them would make the artifact id move with how a state was
reached. So they are arguments here, and the only thing the model contributes is
the frame — `rotating_frame_omega` and `spin_rotating_frame_omega`, which are
physics (they change the Hamiltonian, via Coriolis and the p_eff shift).
"""
function realise_sim_params(m::Model; dt::Real, n_steps::Integer, kwargs...)
    SimParams(; dt=Float64(dt), n_steps=Int(n_steps),
        rotating_frame_omega=m.frame.rotating_omega,
        spin_rotating_frame_omega=m.frame.spin_rotating_omega,
        kwargs...)
end

# ---------------------------------------------------------------------------
# the bundle
# ---------------------------------------------------------------------------

"""
    model_physics_kwargs(m::Model, grid) -> NamedTuple

Every physics kwarg `make_workspace` takes, realised from the model.

This is the `Model`-driven counterpart of `gs_physics_kwargs(::GSResolved)`: both
exist so that the seventeen-kwarg bundle is written ONCE per source rather than
at each call site. `grid` is passed in rather than realised here so a caller that
already holds one (every pipeline step does) does not rebuild it — building a
Grid allocates FFT-shaped coordinate vectors and `make_workspace` is the
inference hot path.

Runtime knobs are absent by design: `sim_params`, `psi_init`, `backend`,
`fft_flags` and `dtype` are not physics and not model slots.

`light_shift` is also absent, and that is not an omission: `profile_source =
:trap` means its envelope is `abs.(V_trap)`, which does not exist until the
potential has been evaluated on the grid. `make_workspace(::Model)` evaluates it
and passes `realise_light_shift`'s result alongside this bundle.
"""
function model_physics_kwargs(m::Model, grid)
    ndim = m.grid.ndim
    spinor_lhy, lhy_opts, c_lhy = realise_lhy(m.lhy, m.interactions.n_atoms)
    (
        atom=m.atom,
        interactions=_realise_interactions_with_lhy(m.interactions, c_lhy),
        potential=realise_potential(m.potential, ndim),
        zeeman=realise_zeeman(m.zeeman, grid),
        raman=realise_raman(m.raman, ndim),
        magnetic_gradient=realise_magnetic_gradient(m.magnetic_gradient, ndim),
        loss=active(m.loss) ? m.loss : nothing,
        absorbing_boundary=if is_active(m.geometry.absorbing.strength)
            m.geometry.absorbing
        else
            nothing
        end,
        quasi_2d=m.geometry.quasi_2d,
        l_z=m.geometry.l_z,
        spinor_lhy=spinor_lhy,
        lhy_opts=lhy_opts,
        realise_ddi_kwargs(m.ddi, ndim)...,
    )
end

# The one place `c_lhy` re-enters `InteractionParams`. `make_workspace` reads
# `interactions.c_lhy` for the closed-form scalar kinds and `spinor_lhy` for the
# tabulated ones; doing this here rather than inside `realise_interactions` keeps
# "the LHY lives in LHYSpec" true of the spec layer, with one named exception
# instead of a silent second home.
function _realise_interactions_with_lhy(s::InteractionSpec, c_lhy::Float64)
    ip = realise_interactions(s)
    c_lhy == 0.0 && return ip
    InteractionParams(ip.c; c_lhy)
end
