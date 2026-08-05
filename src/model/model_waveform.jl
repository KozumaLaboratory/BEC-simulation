# --- ModelWaveform: the model layer's two shared type primitives ---
#
# `ModelValue` is declared here rather than in `model.jl` only because every
# spec struct needs it as a supertype and the specs are `include`d first; the
# operations on it (`with`, `==`, `hash`) live in `model.jl` next to `Model`.

export ModelWaveform, ModelValue
export is_static, waveform_at, waveform_magnitude, to_model_waveform, canonical_waveform

"""
Supertype of `Model` and every `*Spec`. Exists so `with`, structural `==` and
structural `hash` can be declared once, and so the shape gate can enumerate the
model layer's types (`subtypes(ModelValue)`) instead of maintaining a list.
"""
abstract type ModelValue end

"""
    const ModelWaveform = Union{Float64, PiecewiseLinearWaveform}

Every time-dependent knob in a `Model`. The `Float64` arm is the static case;
the `PiecewiseLinearWaveform` arm is the only time dependence a resolved model
can express.

**Why not `Waveform`.** `foundation/waveform.jl:12` already binds
`const Waveform = AbstractWaveform{Float64}` and exports it, so redefining the
name inside the same module is a load error. The collision is fortunate: that
alias is *abstract*, and among its subtypes are `FunctionWaveform` (a bare
`f::Function` field) and `CompositeWaveform` (`Vector{Waveform}`, abstract
element type). A `Model` field typed `Waveform` would therefore re-open the
closure-escape class that CLAUDE.md's "Type stability boundaries" rule 2 exists
to close — every closure site is a distinct type, and specialisation through a
`Workspace` path on distinct closure types is the documented multi-minute JIT
hang with no stack trace. `runtime/pulse_sequence.jl:157` already states the
identical rationale in prose; this union makes it a type.

**Why exactly two members.** Julia union-splits up to four arms; beyond that the
access is a boxed dynamic dispatch. Two arms keep every `getfield` on a spec
inference-transparent while covering the whole surface: a knob is either a
number or a sampled trace of numbers.

**What that costs.** `SinusoidalWaveform`, `ChirpedSinusoidalWaveform`,
`RampWaveform`, `GaussianPulseWaveform` and `InterpolatedWaveform` must be
sampled onto a time grid before they can enter a `Model`. `to_model_waveform`
does that using the existing `max_frequency` / `resample_count` pair, which is
already the aliasing-safe sampler the B-block builders use. `FunctionWaveform`
and `StepWaveform` cannot be sampled automatically — `max_frequency` returns
`NaN` for both, meaning "no sample rate resolves this" — and are refused rather
than silently approximated.
"""
const ModelWaveform = Union{Float64, PiecewiseLinearWaveform}

"""Whether `w` carries no time dependence, i.e. is a single number."""
is_static(w::Float64) = true
is_static(::PiecewiseLinearWaveform) = false

"""Value of `w` at simulation time `t` (dimensionless, unit `1/ω_ref`)."""
waveform_at(w::Float64, ::Real) = w
waveform_at(w::PiecewiseLinearWaveform, t::Real) = evaluate(w, Float64(t))

"""
    waveform_magnitude(w::ModelWaveform) -> Float64

Largest `|value|` the knob ever takes. This is what the `active` predicates
test: a knob that is zero for the whole schedule contributes no operator, and a
knob that is zero only at `t=0` does. Comparing `w[1]` against zero — which the
YAML layer does in several places — would drop a pulse that starts from rest.
"""
waveform_magnitude(w::Float64) = abs(w)
waveform_magnitude(w::PiecewiseLinearWaveform) = isempty(w.values) ? 0.0 : maximum(abs, w.values)

"""
    to_model_waveform(w, duration; n_samples=0, floor_n=1024) -> ModelWaveform

Project any `AbstractWaveform` onto the model layer's two-member union by
sampling it uniformly over `[0, duration]`.

`n_samples = 0` derives the count from `resample_count`, which allots 20 samples
per cycle of `max_frequency(w)` (20 rather than Nyquist's 2 because the
reconstruction here is linear, so the rms error is `O(1/N²)`). Pass `n_samples`
explicitly to sample a waveform whose bandwidth the library cannot bound — that
is a statement the caller is making, not a guess the library is allowed to make,
which is why the unbounded cases throw instead of falling back to `floor_n`.
"""
function to_model_waveform(w::AbstractWaveform, duration::Real;
    n_samples::Int=0, floor_n::Int=1024)
    w isa PiecewiseLinearWaveform && return w
    w isa ConstantWaveform && return w.value
    d = Float64(duration)
    d > 0 || throw(ArgumentError("to_model_waveform needs duration > 0, got $d"))
    n = if n_samples > 0
        n_samples
    else
        isnan(max_frequency(w)) && throw(
            ArgumentError(
                "$(typeof(w)) has no frequency bound, so no sample count is derivable. " *
                "Pass n_samples explicitly, or build the PiecewiseLinearWaveform directly " *
                "if the shape is a jump (a discontinuity is not representable by any " *
                "piecewise-linear grid, and pretending otherwise changes the physics)."),
        )
        resample_count(w, d; floor_n)
    end
    n >= 2 || throw(ArgumentError("to_model_waveform needs n_samples >= 2, got $n"))
    times = collect(range(0.0, d; length=n))
    PiecewiseLinearWaveform(times, [Float64(evaluate(w, t)) for t in times])
end

to_model_waveform(w::Real, ::Real; kwargs...) = Float64(w)

# A number and a two-point flat trace describe the same physics but are
# different values, so they would take different content ids. Collapsing a
# constant trace to its number is what keeps that from happening; nothing else
# in the layer inspects a waveform's shape.
"""
    canonical_waveform(w::ModelWaveform) -> ModelWaveform

Collapse a trace whose values are all equal to the bare number. Two models that
describe identical physics must be the same value, and a constant
`PiecewiseLinearWaveform` is the one way to write a static knob twice.
"""
canonical_waveform(w::Float64) = w
function canonical_waveform(w::PiecewiseLinearWaveform)
    v = w.values
    all(==(v[1]), v) && return v[1]
    # `PiecewiseLinearWaveform` stores its caller's arrays by reference
    # (`foundation/waveform.jl:29-37`). Without this copy a Model's hash stays
    # mutable through the vector the caller happened to pass in, which is not
    # something a content-addressed key may be.
    PiecewiseLinearWaveform(copy(w.times), copy(v))
end

# `is_active(NaN)` is `abs(NaN) > tol` = false, so a NaN coupling takes the
# INACTIVE branch of a spec constructor and is rewritten to zero: a bad unit
# conversion arrives as "this term is off". Specs whose constructor branches on
# activity check finiteness through here first, before that branch can eat it.
_finite_or_throw(x::Float64, what::AbstractString) =
    isfinite(x) ? x :
    throw(ArgumentError("$what must be finite; got $x"))
function _finite_or_throw(w::PiecewiseLinearWaveform, what::AbstractString)
    all(isfinite, w.times) && all(isfinite, w.values) ||
        throw(ArgumentError("$what carries a non-finite sample"))
    w
end
