# --- Waveform: typed time-dependent parameter abstraction ---

abstract type AbstractWaveform{T <: Number} end

"""Type alias for real-valued waveforms (the common case)."""
const Waveform = AbstractWaveform{Float64}

struct ConstantWaveform <: Waveform
    value::Float64
end

struct RampWaveform <: Waveform
    from::Float64
    to::Float64
    duration::Float64
    scale::Symbol
end

struct PiecewiseLinearWaveform <: Waveform
    times::Vector{Float64}
    values::Vector{Float64}

    function PiecewiseLinearWaveform(times::Vector{Float64}, values::Vector{Float64})
        length(times) == length(values) ||
            throw(ArgumentError("times and values must have the same length"))
        length(times) >= 2 ||
            throw(ArgumentError("PiecewiseLinearWaveform requires at least 2 points"))
        issorted(times) ||
            throw(ArgumentError("times must be sorted"))
        new(times, values)
    end
end

struct FunctionWaveform <: Waveform
    f::Function
end

"""
    SinusoidalWaveform(; center, amplitude, frequency, phase)

`value(t) = center + amplitude · sin(2π · frequency · t + phase)`.

**Frequency convention** — `t` here is the dimensionless simulation time
(unit = `1 / ω_ref` where `ω_ref` is in **rad/s**). Because the formula
multiplies by `2π`, the YAML/Julia `frequency` field is

    frequency = f_phys[Hz] / ω_ref[rad/s] = f_phys / (2π · f_ref[Hz])

NOT `f_phys / f_ref`. With the typical `ω_ref = 2π · 50 rad/s ≈ 314.159`,
a 226 Hz drive needs `frequency ≈ 0.72`, not `4.52`. The `4.52` form
gives a 2π× rotation and a quasi-DC field as far as the BEC is concerned
(caught 2026-04-27 in the Klaus 2022 magnetostir reproduction).
"""
struct SinusoidalWaveform <: Waveform
    center::Float64
    amplitude::Float64
    frequency::Float64
    phase::Float64
end

SinusoidalWaveform(; center=0.0, amplitude=1.0, frequency=1.0, phase=0.0) = SinusoidalWaveform(
    center, amplitude, frequency, phase
)

"""
    ChirpedSinusoidalWaveform

Sinusoidal oscillation with a **linearly varying instantaneous frequency**:
f(t) = freq_start + (freq_end - freq_start) · t / duration.

The evaluated signal is
  value(t) = center + amplitude · sin(φ(t) + phase)
where φ(t) = 2π · ∫₀ᵗ f(τ) dτ = 2π · (freq_start · t + (freq_end − freq_start) · t² / (2 · duration)).

Use case: magnetostir spin-up phases where the stirring frequency ramps
from 0 to its steady-state value over some time. Preserves phase continuity
at the ramp boundaries (no discontinuous freq jumps).

**Frequency convention** — same as [`SinusoidalWaveform`](@ref): both
`freq_start` and `freq_end` are in units of `1 / (dimensionless time)`,
which means `f_phys[Hz] / ω_ref[rad/s] = f_phys / (2π · f_ref)`. For
`ω_ref = 2π · 50 rad/s`, a chirp ending at 226 Hz needs
`freq_end ≈ 0.72`, not `4.52`.
"""
struct ChirpedSinusoidalWaveform <: Waveform
    center::Float64
    amplitude::Float64
    freq_start::Float64
    freq_end::Float64
    duration::Float64
    phase::Float64
end

ChirpedSinusoidalWaveform(; center=0.0, amplitude=1.0,
freq_start=0.0, freq_end=1.0,
duration=1.0, phase=0.0) = ChirpedSinusoidalWaveform(
    center, amplitude, freq_start, freq_end, duration, phase
)

struct GaussianPulseWaveform <: Waveform
    center::Float64
    amplitude::Float64
    t_center::Float64
    sigma::Float64
end

GaussianPulseWaveform(; center=0.0, amplitude=1.0, t_center=0.0, sigma=0.01) = GaussianPulseWaveform(
    center, amplitude, t_center, sigma
)

struct InterpolatedWaveform <: Waveform
    times::Vector{Float64}
    values::Vector{Float64}

    function InterpolatedWaveform(times::Vector{Float64}, values::Vector{Float64})
        length(times) == length(values) ||
            throw(ArgumentError("times and values must have the same length"))
        length(times) >= 2 ||
            throw(ArgumentError("InterpolatedWaveform requires at least 2 points"))
        issorted(times) ||
            throw(ArgumentError("times must be sorted"))
        new(times, values)
    end
end

struct CompositeWaveform <: Waveform
    waveforms::Vector{Waveform}
    operation::Symbol
end

CompositeWaveform(waveforms::Vector{<:Waveform}; operation::Symbol=:add) = CompositeWaveform(
    convert(Vector{Waveform}, waveforms), operation
)

evaluate(w::ConstantWaveform, ::Float64) = w.value

function evaluate(w::RampWaveform, t::Float64)
    w.duration <= 0 && return w.from
    t_frac = clamp(t / w.duration, 0.0, 1.0)
    s = _scale_function(Val(w.scale), t_frac)
    w.from + (w.to - w.from) * s
end

function evaluate(w::PiecewiseLinearWaveform, t::Float64)
    t <= w.times[1] && return w.values[1]
    t >= w.times[end] && return w.values[end]
    i = searchsortedlast(w.times, t)
    i >= length(w.times) && return w.values[end]
    t0, t1 = w.times[i], w.times[i + 1]
    v0, v1 = w.values[i], w.values[i + 1]
    frac = (t - t0) / (t1 - t0)
    v0 + (v1 - v0) * frac
end

evaluate(w::FunctionWaveform, t::Float64) = w.f(t)

evaluate(w::SinusoidalWaveform, t::Float64) =
    w.center + w.amplitude * sin(2π * w.frequency * t + w.phase)

function evaluate(w::ChirpedSinusoidalWaveform, t::Float64)
    # Clamp t to [0, duration] so evaluations past the ramp use f_end freely:
    # after t >= duration, effective f is f_end and phase continues linearly.
    if t <= w.duration
        φ = 2π * (w.freq_start * t + 0.5 * (w.freq_end - w.freq_start) * t^2 / w.duration)
    else
        # Integrate the ramp fully, then continue with f_end.
        φ_ramp = 2π * (w.freq_start * w.duration + 0.5 * (w.freq_end - w.freq_start) * w.duration)
        φ = φ_ramp + 2π * w.freq_end * (t - w.duration)
    end
    w.center + w.amplitude * sin(φ + w.phase)
end

evaluate(w::GaussianPulseWaveform, t::Float64) =
    w.center + w.amplitude * exp(-0.5 * ((t - w.t_center) / w.sigma)^2)

function evaluate(w::InterpolatedWaveform, t::Float64)
    t <= w.times[1] && return w.values[1]
    t >= w.times[end] && return w.values[end]
    i = searchsortedlast(w.times, t)
    i >= length(w.times) && return w.values[end]
    t0, t1 = w.times[i], w.times[i + 1]
    v0, v1 = w.values[i], w.values[i + 1]
    h = t1 - t0
    frac = (t - t0) / h
    if length(w.times) >= 4
        # Cubic Hermite spline (Catmull-Rom)
        i0 = max(1, i - 1)
        i3 = min(length(w.times), i + 2)
        m0 = (w.values[i + 1] - w.values[i0]) / (w.times[i + 1] - w.times[i0])
        m1 = (w.values[i3] - w.values[i]) / (w.times[i3] - w.times[i])
        m0 *= h;
        m1 *= h
        t2 = frac * frac;
        t3 = t2 * frac
        return (2t3 - 3t2 + 1) * v0 + (t3 - 2t2 + frac) * m0 +
               (-2t3 + 3t2) * v1 + (t3 - t2) * m1
    end
    v0 + (v1 - v0) * frac
end

function evaluate(w::CompositeWaveform, t::Float64)
    if w.operation === :add
        sum(wf -> evaluate(wf, t), w.waveforms)
    elseif w.operation === :multiply
        prod(wf -> evaluate(wf, t), w.waveforms)
    else
        throw(ArgumentError("Unknown composite operation: $(w.operation)"))
    end
end

struct StepWaveform <: Waveform
    value_before::Float64
    value_after::Float64
    t_step::Float64
end

evaluate(w::StepWaveform, t::Float64) = t < w.t_step ? w.value_before : w.value_after

"""
    load_waveform_csv(path; time_col=1, value_col=2, header=true, delimiter=',')

Load a waveform from a CSV file. Returns an InterpolatedWaveform.
"""
function load_waveform_csv(path::String; time_col::Int=1, value_col::Int=2,
    header::Bool=true, delimiter::Char=',')
    lines = readlines(path)
    header && !isempty(lines) && popfirst!(lines)
    times = Float64[]
    values = Float64[]
    for line in lines
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, '#') && continue
        parts = split(stripped, delimiter)
        length(parts) < max(time_col, value_col) && continue
        push!(times, parse(Float64, parts[time_col]))
        push!(values, parse(Float64, parts[value_col]))
    end
    InterpolatedWaveform(times, values)
end

_scale_function(::Val{:linear}, t) = t
_scale_function(::Val{:log}, t) = log(1.0 + (exp(1.0) - 1.0) * t)
_scale_function(::Val{:sqrt}, t) = sqrt(t)
_scale_function(::Val{:cosine}, t) = (1 - cos(π * t)) / 2
_scale_function(::Val{:exponential}, t) = (exp(t) - 1) / (exp(1.0) - 1)
_scale_function(::Val{:reverse_sqrt}, t) = 1 - sqrt(1 - t)
