# Concrete callable types instead of closures, to avoid the closure-type
# pollution warned about in memory `pitfall_pipeline_inference.md`. Each
# closure site has a unique type → multiplies specialization combinatorics.
# These are reused across all rotating-basis pipeline runs.

struct _ConstAngle <: Function
    val::Float64
end
(c::_ConstAngle)(::Float64) = c.val

struct _LinearPhi <: Function
    omega::Float64
end
(c::_LinearPhi)(t::Float64) = c.omega * t

struct _ConstZero <: Function end
(::_ConstZero)(::Float64) = 0.0

const _ZERO_FUNC = _ConstZero()

# Linear ramp θ(t) = θ_start + (θ_end - θ_start)·clamp(t/T, 0, 1).
# `θ_dot(t) = (θ_end - θ_start)/T` for t ∈ [0,T], else 0.
struct _LinearRamp <: Function
    start_val::Float64
    end_val::Float64
    duration::Float64
end
(r::_LinearRamp)(t::Float64) =
    r.start_val + (r.end_val - r.start_val) * clamp(t / r.duration, 0.0, 1.0)

struct _LinearRampDot <: Function
    rate::Float64           # = (end - start) / duration
    duration::Float64
end
(r::_LinearRampDot)(t::Float64) = (0.0 ≤ t ≤ r.duration) ? r.rate : 0.0

# Linear chirp φ̇(t) = ω_start + (ω_end - ω_start)·clamp(t/T, 0, 1)
# φ(t) = ω_start·t + (ω_end - ω_start)·t²/(2T) for t ≤ T, then steady ω_end·t after.
struct _LinearChirpPhi <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhi)(t::Float64)
    if t ≤ c.duration
        c.omega_start * t + (c.omega_end - c.omega_start) * t^2 / (2 * c.duration)
    else
        # After ramp ends, phase continues at constant ω_end
        c.omega_start * c.duration + (c.omega_end - c.omega_start) * c.duration / 2 +
        c.omega_end * (t - c.duration)
    end
end

struct _LinearChirpPhiDot <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhiDot)(t::Float64)
    if t ≤ c.duration
        c.omega_start + (c.omega_end - c.omega_start) * t / c.duration
    else
        c.omega_end
    end
end
