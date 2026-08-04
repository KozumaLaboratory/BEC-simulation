# --- Model: the resolved physics of one computation, as one value ---

export Model, with

"""
    Model(; grid, atom, interactions, <slot>=<inactive>, …)

The resolved physics of one computation.

**Invariant 1.** `Model` is one concrete immutable struct with no free-form
slot. There is no `metadata:`, no `extra::Dict`, no `Any` field, no `Function`
field, and no type parameter. Nothing downstream specialises on it, so the
23-parameter `Workspace` explosion cannot be triggered from the plan layer.
Gated by `test_model_shape.jl`, whose rule is stated on the LEAVES rather than
on the fields: a field may be a tuple or a typed vector, and what must be
concrete-or-a-closed-union-of-concretes is what you reach by decomposing it.
`HarmonicSpec.omega::NTuple{3, ModelWaveform}` is the case that forces the
distinction — the tuple type is abstract, while each of its three leaves is the
same two-member union the layer already accepts as a bare field.

**Invariant 3.** Every slot but `grid`, `atom` and `interactions` has a
documented inactive value, and an inactive slot has exactly ONE representation
(the spec constructors normalise to it). Serialisation omits inactive slots, so
adding physics never invalidates work that did not use it.

# Slots

| slot | type | inactive |
|---|---|---|
| `grid` | `GridSpec` | — (always present) |
| `atom` | `AtomSpecies` | — (always present) |
| `interactions` | `InteractionSpec` | — (always present) |
| `potential` | `PotentialSpec` | `PotentialSpec()` (free particle) |
| `zeeman` | `ZeemanSpec` | `ZeemanSpec()` (no field) |
| `ddi` | `DDISpec` | `DDISpec()` (`c_dd = 0`) |
| `lhy` | `LHYSpec` | `LHYSpec()` (`kind = :none`) |
| `raman` | `RamanSpec` | `RamanSpec()` (`Ω_R = 0`) |
| `light_shift` | `LightShiftSpec` | `LightShiftSpec()` (`η = 0`) |
| `magnetic_gradient` | `GradientSpec` | `GradientSpec()` (no tilt) |
| `frame` | `FrameSpec` | `FrameSpec()` (lab frame) |
| `geometry` | `GeometrySpec` | `GeometrySpec()` (3-D, no absorber) |
| `reservoir` | `ReservoirSpec` | `ReservoirSpec()` (closed system) |
| `loss` | `LossParams` | `LossParams()` (no channel) |

# Deviations from the design sketch's 14 slots, and why

- **`tensor` dropped.** It is not an input: there is no `tensor` kwarg, and
  `make_workspace.jl:365-394` derives the tensor cache entirely from
  `interactions.c`'s even ranks ≥ 4 plus `atom.F`, or from
  `atom.scattering_lengths` when those are empty. A `tensor` slot would be a
  second, drift-capable declaration of coefficients that already exist in two
  other slots — the parallel-declaration disease the HamTerm registry was built
  to eliminate. It would also make representable the exact state the
  double-counting guard at `:382-392` throws on (channel data *and* a non-zero
  `c0`/`c1`).
- **`reservoir` added.** SGPE growth, the projected-GP cutoff and photon
  scattering are open-system *physics* that fit none of the fourteen. See
  `ReservoirSpec`.
- **`spatial_zeeman` folded into `zeeman`**, and **`time_dep_interactions` folded
  into `interactions`** — see those specs.
- **`quasi_2d_ddi` / `l_z_ddi` live in `ddi`, not `geometry`** — see `DDISpec`.
- **`DDISpec.euler` dropped** — it names a propagator cache, not an input.
- **dealias moved from a global `Ref` into `GridSpec`** — see `GridSpec`.

# What is deliberately NOT here, and where it goes

`Model` is the physics. Everything below changes *how* the physics is computed,
or *what it is computed from*, and lives in the `Stage` layer:

| excluded | goes to | why |
|---|---|---|
| `psi_init` | `Initial` | the serial-dependency carrier; a model plus two seeds is one model |
| `backend` | `Job` | GPU and CPU are gated to bit-parity by Level 0, so the backend cannot move the physics id |
| `fft_flags` | `Job` | `MEASURE` vs `ESTIMATE` is a planner hint; it moves timing, not numbers |
| `dtype` | `Method` digest | changes the numbers but not the physics; see `GridSpec` |
| `dt`, `n_steps`, `imaginary_time`, `normalize_every` | `Method` | integration control |
| `save_every`, `n_snapshots` | `SaveSpec` | output policy |
| stochastic seeds | `Initial` | a seed picks a realisation, not a physics |

`SimParams` (`sim_fft.jl:15`) must therefore be **split**, not carried: five of
its seven fields are `Method`, and `rotating_frame_omega` /
`spin_rotating_frame_omega` are physics and live in `frame`.

One honest leak: the absorbing mask is built from `geometry.absorbing` **and**
`dt`, so that one materialised object is not derivable from a `Model` alone.
Named in `GeometrySpec` rather than papered over.
"""
struct Model <: ModelValue
    grid::GridSpec
    atom::AtomSpecies
    interactions::InteractionSpec
    potential::PotentialSpec
    zeeman::ZeemanSpec
    ddi::DDISpec
    lhy::LHYSpec
    raman::RamanSpec
    light_shift::LightShiftSpec
    magnetic_gradient::GradientSpec
    frame::FrameSpec
    geometry::GeometrySpec
    reservoir::ReservoirSpec
    loss::LossParams

    function Model(grid::GridSpec, atom::AtomSpecies, interactions::InteractionSpec,
        potential::PotentialSpec, zeeman::ZeemanSpec, ddi::DDISpec, lhy::LHYSpec,
        raman::RamanSpec, light_shift::LightShiftSpec, magnetic_gradient::GradientSpec,
        frame::FrameSpec, geometry::GeometrySpec, reservoir::ReservoirSpec, loss::LossParams)
        # `ddi.pad_factor` is the one per-axis knob whose unused-axis value is
        # not zero and whose default (2.0 on every axis) is therefore
        # non-canonical on a 1-D or 2-D grid. Rejecting it would make every
        # low-dimensional DDI model restate a number it does not use;
        # normalising keeps two models of the same 2-D physics identical
        # without that tax. Every other per-axis tuple already defaults to its
        # own unused-axis value, so a non-default entry beyond `ndim` there is a
        # genuine wrong-dimensionality error and `_validate_model` rejects it
        # rather than papering over it.
        ddi = _trim_pad_factor(ddi, grid.ndim)
        # `LossParams`' 7-argument positional form — the one `_dec` and every
        # hand-written call use — stores its caller's vectors by reference. The
        # keyword form `collect`s, so rebuilding through it is what stops a
        # Model's hash from staying mutable through a handle it was handed.
        loss = LossParams(; loss.gamma_dr, loss.L3, loss.L3_per_m, loss.K3_cubic,
            loss.K3_per_m_cubic, loss.evap_energy_cutoff, loss.evap_rate)
        m = new(grid, atom, interactions, potential, zeeman, ddi, lhy, raman,
            light_shift, magnetic_gradient, frame, geometry, reservoir, loss)
        _validate_model(m)
        m
    end
end

Model(; grid::GridSpec, atom::AtomSpecies, interactions::InteractionSpec,
    potential::PotentialSpec=PotentialSpec(), zeeman::ZeemanSpec=ZeemanSpec(),
    ddi::DDISpec=DDISpec(), lhy::LHYSpec=LHYSpec(), raman::RamanSpec=RamanSpec(),
    light_shift::LightShiftSpec=LightShiftSpec(),
    magnetic_gradient::GradientSpec=GradientSpec(), frame::FrameSpec=FrameSpec(),
    geometry::GeometrySpec=GeometrySpec(), reservoir::ReservoirSpec=ReservoirSpec(),
    loss::LossParams=LossParams()) = Model(grid, atom, interactions, potential, zeeman,
    ddi, lhy, raman, light_shift, magnetic_gradient, frame, geometry, reservoir, loss)

# ---------------------------------------------------------------------------
# Cross-spec validation
# ---------------------------------------------------------------------------
#
# Constraints that no single spec can see. They live here rather than in
# `make_workspace` because a value that can encode a state the builder throws on
# is a value that lies about being resolved — and because a check that runs at
# construction runs before a job is submitted, not after it starts.

function _validate_model(m::Model)
    _require_finite(m, "model")
    nd = m.grid.ndim
    F = m.atom.F
    F >= 0 || throw(ArgumentError("atom.F must be >= 0; got $F"))

    for k in m.interactions.c_extra_ranks
        k <= 2F || throw(ArgumentError(
            "contact channel S=$k exceeds 2F = $(2F) for $(m.atom.name)"))
    end

    m.lhy.kind === :icosahedral && F != 6 &&
        throw(
            ArgumentError(
                "lhy kind :icosahedral is an F=6 channel structure, not a general-F closed " *
                "form; got F=$F"),
        )

    if m.geometry.quasi_2d && nd != 2
        throw(ArgumentError("geometry.quasi_2d requires a 2-D grid; got ndim=$nd"))
    end
    if m.ddi.quasi_2d && nd != 2
        throw(
            ArgumentError(
                "ddi.quasi_2d selects the quasi-2-D dipolar kernel and " *
                "requires a 2-D grid; got ndim=$nd",
            ),
        )
    end

    # Full DDI's off-diagonal components Larmor-average to zero only in the
    # secular limit, so a spin-rotating frame with a non-secular kernel is a
    # silently wrong Hamiltonian, not an approximation.
    if is_active(m.frame.spin_rotating_omega, ROTATION_TOL) && is_active(m.ddi.c_dd)
        m.ddi.secular || throw(ArgumentError(
            "frame.spin_rotating_omega != 0 requires ddi.secular = true"))
    end

    _axis_in_range(m.magnetic_gradient.axis, nd, "magnetic_gradient.axis",
        is_active(waveform_magnitude(m.magnetic_gradient.gradient)))
    for (i, g) in enumerate(m.potential.gravity)
        _axis_in_range(g.axis, nd, "potential.gravity[$i].axis", true)
    end
    for (i, dw) in enumerate(m.potential.double_well)
        _axis_in_range(dw.axis, nd, "potential.double_well[$i].axis", true)
    end
    isempty(m.potential.ring) || nd >= 2 ||
        throw(ArgumentError("a ring potential needs ndim >= 2; got $nd"))
    isempty(m.potential.beam) || nd >= 2 ||
        throw(ArgumentError("a transverse beam needs ndim >= 2; got $nd"))

    _axes_padded(m.raman.k_eff, nd, 0.0, "raman.k_eff")
    _axes_padded(m.zeeman.spatial_center, nd, 0.0, "zeeman.spatial_center")
    _axes_padded(m.ddi.pad_factor, nd, 1.0, "ddi.pad_factor")
    for (i, h) in enumerate(m.potential.harmonic)
        _axes_padded(map(waveform_magnitude, h.omega), nd, 0.0, "potential.harmonic[$i].omega")
        _axes_padded(h.lambda, nd, 0.0, "potential.harmonic[$i].lambda")
    end
    for (i, l) in enumerate(m.potential.lattice)
        _axes_padded(l.depth, nd, 0.0, "potential.lattice[$i].depth")
    end
    for (i, b) in enumerate(m.potential.box)
        _axes_padded(b.size, nd, 0.0, "potential.box[$i].size")
    end
    for (i, dw) in enumerate(m.potential.double_well)
        _axes_padded(dw.omega, nd, 0.0, "potential.double_well[$i].omega")
    end

    n_per_m = (m.loss.L3_per_m, m.loss.K3_per_m_cubic)
    for v in n_per_m
        isempty(v) || length(v) == 2F + 1 ||
            throw(ArgumentError(
                "per-m loss vector has $(length(v)) entries; F=$F needs $(2F + 1)"))
    end
    nothing
end

# `specs.jl:27-33` states the rule — no NaN sentinels anywhere in a Model — and
# four constructors enforce it on their own field. That left the other ~30
# `Float64` fields open, and a NaN in any of them breaks reflexivity: `m != m`,
# `hash` diverges from `==`, and `content_id` then dies at
# `experiment.jl:85-86`. One recursive walk over everything a Model can reach is
# the enforcement that cannot be forgotten when a slot is added.
function _require_finite(x, path::AbstractString)
    if x isa AbstractFloat
        isfinite(x) || throw(
            ArgumentError(
                "$path is $x; a Model carries no non-finite value (NaN != NaN, so one " *
                "sentinel makes two identical models compare unequal and hash apart)"),
        )
    elseif x isa Integer || x isa Bool || x isa Symbol || x isa AbstractString
        return nothing
    elseif x isa AbstractDict
        for k in sort!(collect(keys(x)); by=string)
            _require_finite(x[k], "$path[$k]")
        end
    elseif x isa Tuple || x isa AbstractArray
        for (i, v) in pairs(x)
            _require_finite(v, "$path[$i]")
        end
    elseif isstructtype(typeof(x))
        T = typeof(x)
        for i in 1:fieldcount(T)
            _require_finite(getfield(x, i), "$path.$(fieldname(T, i))")
        end
    end
    nothing
end

function _axis_in_range(axis::Int, ndim::Int, what::AbstractString, checked::Bool)
    checked || return nothing
    1 <= axis <= ndim ||
        throw(ArgumentError("$what = $axis is outside 1:$ndim"))
    nothing
end

# A slot that names an axis the grid does not have is either a typo or a model
# built for a different dimensionality. Either way two models of the same 2-D
# physics must not be able to differ in a number no operator reads.
function _axes_padded(t::NTuple{3, Float64}, ndim::Int, unused::Float64, what::AbstractString)
    _axes_ok(t, ndim, unused) || throw(ArgumentError(
        "$what = $t has a non-$unused entry beyond ndim=$ndim"))
    nothing
end

# ---------------------------------------------------------------------------
# with — the generated reconstructor
# ---------------------------------------------------------------------------

"""
    with(x::ModelValue; field = value, …) -> typeof(x)

Reconstruct `x` with the named fields replaced. `with(m; ddi = with(m.ddi;
secular = false))` is the idiom; nesting is ordinary function composition, so no
lens library is involved.

Every constructor's validation re-runs, so `with` cannot produce a value the
constructor would have refused — which is what makes it safe as the only
mutation-shaped operation in the layer.

Reused foundation types (`AtomSpecies`, `LossParams`, `AbsorbingBoundary`) are
not `ModelValue`s and are not reachable through `with`; `AtomSpecies` in
particular derives two of its fields in its constructor and has no all-positional
form. Rebuild those with their own constructors.
"""
with(x::ModelValue; kwargs...) = _with(x, NamedTuple(kwargs))

@generated function _with(x::T, nt::NamedTuple{names}) where {T <: ModelValue, names}
    fns = fieldnames(T)
    unknown = setdiff(collect(names), collect(fns))
    isempty(unknown) || return :(throw(
        ArgumentError(
            string(
                $(string(T)), " has no field ", $(join(unknown, ", ")),
                "; fields are ", $(join(fns, ", "))),
        ),
    ))
    Expr(:call, T, (n in names ? :(nt.$n) : :(getfield(x, $(QuoteNode(n)))) for n in fns)...)
end

# ---------------------------------------------------------------------------
# Structural equality and hashing
# ---------------------------------------------------------------------------
#
# Immutable is not the same as a value: `Vector` fields make the default `==`
# fall back to `===`, i.e. object identity, so two models parsed from the same
# TOML would compare unequal. Identity in this architecture is derived from the
# model, so `==` has to mean "describes the same physics".
#
# `_speceq` is defined only for the model layer and recurses through the reused
# foundation structs from the outside. Overriding `Base.==` for `AtomSpecies`
# itself would change behaviour outside `src/model/`, which Step 1a may not do.

# One method each, branching on `isa`, rather than a family of dispatched
# methods: the natural family (`(a::T, b::T) where T` for the struct case beside
# `(a::Number, b::Number)` for the leaf case) is genuinely ambiguous for
# `Float64`, and an ambiguity that only fires on one field type is the kind of
# defect that surfaces months later on an unusual model. These run once per
# comparison, not in a hot loop.

function _speceq(a, b)
    typeof(a) === typeof(b) || return false
    a isa Number && return a == b
    a isa Symbol && return a === b
    a isa AbstractString && return a == b
    a isa AbstractDict && return a == b        # content-based, order-independent
    if a isa Tuple || a isa AbstractArray
        length(a) == length(b) || return false
        return all(i -> _speceq(a[i], b[i]), eachindex(a))
    end
    T = typeof(a)
    isstructtype(T) || return a == b
    all(i -> _speceq(getfield(a, i), getfield(b, i)), 1:fieldcount(T))
end

function _spechash(x, h::UInt)
    (x isa Number || x isa Symbol || x isa AbstractString || x isa AbstractDict) &&
        return hash(x, h)
    if x isa Tuple || x isa AbstractArray
        acc = hash(length(x), h)
        for v in x
            acc = _spechash(v, acc)
        end
        return acc
    end
    T = typeof(x)
    isstructtype(T) || return hash(x, h)
    acc = hash(nameof(T), h)
    for i in 1:fieldcount(T)
        acc = _spechash(getfield(x, i), acc)
    end
    acc
end

Base.:(==)(a::T, b::T) where {T <: ModelValue} = _speceq(a, b)
Base.hash(x::ModelValue, h::UInt) = _spechash(x, h)

# The predicate SERIALISATION needs, which is not `active`. Omitting a slot is
# lossless exactly when the decoder's `T()` reproduces it, i.e. when the slot
# already equals its own inactive value — and the two predicates come apart on
# the two slots with no normalising constructor: a `PotentialSpec` holding a
# zero-ω harmonic term and a `LossParams` holding an all-zero `L3_per_m` are
# both `active == false` and both != `T()`, so `active`-gated omission dropped
# them. `active` stays what it says (does this contribute to the computation),
# and is what `active_slots` reports.
_is_inactive_value(s) = _speceq(s, typeof(s)())

# ---------------------------------------------------------------------------

"""
    slots(::Type{Model}) -> NTuple{14,Symbol}

The slot names, in declaration order. `to_toml` and the shape gate both read
this rather than restating the list.
"""
slots(::Type{Model}) = fieldnames(Model)

"Slots with no inactive value; always written, never omitted."
const REQUIRED_SLOTS = (:grid, :atom, :interactions)

export slots, REQUIRED_SLOTS
