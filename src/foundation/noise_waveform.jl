# --- Field noise as a waveform: seeded, analytic, pure in t ---
#
# A waveform is evaluated MANY times per step — each Strang sub-step, each
# rejected adaptive-dt trial, each Yoshida stage — and sometimes at the same
# `t` twice. So a noise source that draws from an RNG inside `evaluate`
# would hand the propagator a different field on the second look at the same
# instant: not a noisy field, an inconsistent one. It would also make a run
# unreproducible under a change of `dt` alone.
#
# Randomness therefore goes in ONCE, at construction, into the PHASES. What
# is stored is an ordinary finite Fourier sum,
#
#     B(t) = Σ_j A_j sin(2π f_j t + φ_j)
#
# which is an exact analytic function of `t`, deterministic given a seed, and
# free of the interpolation/aliasing questions that a sampled time series
# drags in (no Nyquist relative to the integrator's `dt`, because there is no
# sampling grid).
#
# Amplitudes are deterministic and phases are random — the spectral
# representation of a stationary process. Across an ensemble of seeds the
# realisation varies while the per-shot rms is fixed by construction, which
# is the right thing when the question is "how much does N µG of noise move
# the observable": the answer should not be confounded by the rms itself
# fluctuating shot to shot.
#
# The sum is periodic with period 1/Δf. `field_noise_waveform` sets
# Δf = 1/duration so the period equals the run, and the trace never repeats
# within a shot.
#
# Frequencies and `duration` are in the SAME reciprocal units; the YAML layer
# (`_make_waveform`) converts Hz via the existing ω_ref machinery, and
# amplitudes stay in whatever unit the host field uses (Gauss for Bx/By/Bz).
# Amplitudes do not transform under a change of time unit, which is why this
# spec is written in rms rather than in spectral density — a PSD in G²/Hz
# would need an ω_ref factor and is an easy thing to get wrong.

export SpectralNoiseWaveform, FieldNoiseSpec, field_noise_waveform

"""
    SpectralNoiseWaveform(frequencies, amplitudes, phases)

`value(t) = Σ_j amplitudes[j] · sin(2π · frequencies[j] · t + phases[j])`.

Same frequency convention as [`SinusoidalWaveform`](@ref): in dimensionless
simulation time, `frequency = f_phys[Hz] / ω_ref[rad/s]`.

Zero-mean by construction. A static field error is not represented here — it
is a different value of the field, so it belongs in the field spec (a bare
number in a `sum:`), and as a one-scalar systematic it is better scanned as an
explicit axis than sampled.

Build one with [`field_noise_waveform`](@ref) rather than by hand; the
constructor is deliberately dumb so that a realisation can be serialised and
replayed exactly.
"""
struct SpectralNoiseWaveform <: Waveform
    frequencies::Vector{Float64}
    amplitudes::Vector{Float64}
    phases::Vector{Float64}

    function SpectralNoiseWaveform(frequencies::Vector{Float64},
        amplitudes::Vector{Float64}, phases::Vector{Float64})
        length(frequencies) == length(amplitudes) == length(phases) ||
            throw(ArgumentError(
                "frequencies, amplitudes and phases must have the same length"))
        new(frequencies, amplitudes, phases)
    end
end

function evaluate(w::SpectralNoiseWaveform, t::Float64)
    acc = 0.0
    @inbounds @simd for j in eachindex(w.frequencies)
        acc += w.amplitudes[j] * sin(2π * w.frequencies[j] * t + w.phases[j])
    end
    acc
end

"""
    noise_rms(w::SpectralNoiseWaveform) -> Float64

Long-time rms of the realisation, `√(Σ A_j² / 2)`. Exact for incommensurate
frequencies and the design target for the generated grid.
"""
noise_rms(w::SpectralNoiseWaveform) = sqrt(sum(a -> a^2 / 2, w.amplitudes; init=0.0))

max_frequency(w::SpectralNoiseWaveform) =
    isempty(w.frequencies) ? 0.0 : maximum(abs, w.frequencies)

"""
    FieldNoiseSpec(; seed, lines, shape, rms, f_lo, f_hi, f_corner, n_components)

Declarative description of the TIME-VARYING part of a laboratory field error
budget, in the units of the field it is added to.

- `lines` — discrete tones as `(frequency, rms)` pairs. Mains pickup and its
  harmonics; what a Ramsey measurement reports. A high-permeability Ni-Fe
  (permalloy) shield knocks these down by tens of dB, at which point they
  stop being the limiting term.
- `shape` — broadband shape, one of `:none`, `:white`, `:pink` (1/f),
  `:brown` (1/f²), `:lorentzian`.
- `rms` — TOTAL broadband rms over `[f_lo, f_hi]`, not a spectral density.
- `f_corner` — flattens `:pink` / `:brown` below it (they diverge at f→0) and
  sets the knee of `:lorentzian`.
- `n_components` — tones used to represent the broadband part.

**Static field error is deliberately out of scope.** A constant offset is
simply a different value of the field — set it in the field spec (`Bz: 6.1e-5`,
or a bare number in a `sum:`). And because it is a single scalar, a sweep over
it (`sweep(base; over="…Bz" => …)`) yields the response function directly,
whereas drawing it randomly yields a smeared average you then have to
deconvolve. Randomisation earns its place for the AC phases, which are a few
hundred dimensions and cannot be scanned; it does not earn it for one number.

That distinction is not cosmetic: a constant offset shifts the field AXIS, so
both legs of a hysteresis scan move together and the loop keeps its width
while the absolute jump field is biased. Time-varying error smears the
transition instead. Scanning the offset separates the two; folding it into a
"noise" rms conflates them.

Order-of-magnitude anchors for a magnetic field in Gauss. Coil setups without
a shield: mains pickup ≈ 1.3 mG peak-to-peak at 50 Hz, falling to ≈ 0.01 mG at
50 Hz and ≈ 0.05 mG at 150 Hz under active stabilisation; broadband floor
≈ 10 µG/√Hz over 0–1 kHz (`rms ≈ density · √(f_hi − f_lo)`). A permalloy shield
with AC degaussing pushes the AC terms far below that, leaving a static
residual of order 10 µG — which is a bias on the field value, not a noise
term, and belongs in the scan.

The waveform is analytic, so it has no sampling grid of its own — but the
INTEGRATOR does. A `dt` that fails to resolve the highest component aliases
the noise down to some other frequency rather than averaging it away. Keep
`dt ≲ 1/(10 · f_max)`, or lower `f_hi` to the band the run can represent and
say so.
"""
struct FieldNoiseSpec
    seed::Int
    lines::Vector{Tuple{Float64, Float64}}   # (frequency, rms)
    shape::Symbol
    rms::Float64
    f_lo::Float64
    f_hi::Float64
    f_corner::Float64
    n_components::Int
end

const _NOISE_SHAPES = (:none, :white, :pink, :brown, :lorentzian)

function FieldNoiseSpec(; seed::Integer=0,
    lines=Tuple{Float64, Float64}[],
    shape::Union{Symbol, AbstractString}=:none,
    rms::Real=0.0,
    f_lo::Real=0.0,
    f_hi::Real=0.0,
    f_corner::Real=0.0,
    n_components::Integer=256)
    sh = Symbol(shape)
    sh in _NOISE_SHAPES || throw(
        ArgumentError(
            "FieldNoiseSpec shape=:$sh unknown. Known: $(join(_NOISE_SHAPES, ", "))."),
    )
    ls = Tuple{Float64, Float64}[(Float64(f), Float64(r)) for (f, r) in lines]
    any(fr -> fr[1] < 0, ls) &&
        throw(ArgumentError("FieldNoiseSpec line frequencies must be ≥ 0"))
    if sh !== :none && rms != 0
        f_hi > f_lo || throw(
            ArgumentError(
                "FieldNoiseSpec broadband needs f_hi > f_lo (got f_lo=$f_lo, f_hi=$f_hi)"),
        )
        n_components >= 1 || throw(ArgumentError("n_components must be ≥ 1"))
        if sh in (:pink, :brown) && f_corner <= 0 && f_lo <= 0
            throw(
                ArgumentError(
                    "FieldNoiseSpec shape=:$sh diverges at f→0; set f_corner > 0 " *
                    "or f_lo > 0."),
            )
        end
    end
    FieldNoiseSpec(Int(seed), ls, sh, Float64(rms), Float64(f_lo), Float64(f_hi),
        Float64(f_corner), Int(n_components))
end

# One-sided spectral shape, up to normalisation (the total rms is imposed
# afterwards, so only the SHAPE matters here).
function _noise_shape(shape::Symbol, f::Float64, f_corner::Float64)
    shape === :white && return 1.0
    shape === :pink && return 1.0 / max(f, f_corner)
    shape === :brown && return 1.0 / max(f, f_corner)^2
    shape === :lorentzian && return 1.0 / (1.0 + (f / max(f_corner, eps()))^2)
    0.0
end

"""
    field_noise_waveform(spec::FieldNoiseSpec, duration::Real) -> SpectralNoiseWaveform

Realise `spec` as an analytic waveform over `[0, duration]`.

Broadband power is spread over `spec.n_components` tones on a uniform grid
across `[f_lo, f_hi]`, with amplitudes following `spec.shape` and then
rescaled so the realisation's rms is exactly `spec.rms`. Line tones are added
at their own frequencies with amplitude `√2 · rms`.

`duration` only sets the phase-grid resolution used to keep the sum from
repeating within a shot; the returned waveform is defined for all `t`.
"""
function field_noise_waveform(spec::FieldNoiseSpec, duration::Real)
    dur = Float64(duration)
    dur > 0 || throw(ArgumentError("field_noise_waveform needs duration > 0"))
    rng = Random.MersenneTwister(spec.seed)

    freqs = Float64[]
    amps = Float64[]

    if spec.shape !== :none && spec.rms != 0 && spec.n_components >= 1
        n = spec.n_components
        df = (spec.f_hi - spec.f_lo) / n
        shape_amp = Vector{Float64}(undef, n)
        grid = Vector{Float64}(undef, n)
        for j in 1:n
            f = spec.f_lo + (j - 0.5) * df
            grid[j] = f
            shape_amp[j] = sqrt(max(_noise_shape(spec.shape, f, spec.f_corner), 0.0))
        end
        # Impose the requested rms exactly: rms² = Σ A_j² / 2.
        norm_sq = sum(a -> a^2 / 2, shape_amp)
        scale = norm_sq > 0 ? spec.rms / sqrt(norm_sq) : 0.0
        append!(freqs, grid)
        append!(amps, scale .* shape_amp)
    end

    for (f, r) in spec.lines
        r == 0 && continue
        push!(freqs, f)
        push!(amps, sqrt(2.0) * r)   # rms of A·sin is A/√2
    end

    isempty(freqs) && return SpectralNoiseWaveform(Float64[], Float64[], Float64[])

    # Phases are the only random ingredient. Snapping the broadband grid to multiples of 1/duration would make the sum periodic
    # with exactly the run length; leaving it unsnapped is closer to a
    # continuous spectrum and the beat period is longer still, so no snapping
    # is done — `duration` instead just guards against a component so slow it
    # is indistinguishable from a constant offset, which is a field VALUE and
    # does not belong in a noise spec.
    keep = [i for i in eachindex(freqs) if freqs[i] * dur >= 1e-6]
    length(keep) == length(freqs) || @warn "field_noise_waveform: dropped " *
        "$(length(freqs) - length(keep)) component(s) with period ≫ duration " *
        "(they act as a constant offset, not as noise — put a static field " *
        "error in the field value). Raise f_lo or the step duration." maxlog=1

    phases = [2π * rand(rng) for _ in keep]
    SpectralNoiseWaveform(freqs[keep], amps[keep], phases)
end
