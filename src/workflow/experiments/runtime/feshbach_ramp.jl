# --- P2.10: Feshbach-resonance ramp builder ---
#
# Scattering length as a function of magnetic field near an s-wave Feshbach
# resonance (for a spinor BEC, c0 ∝ a_s at leading order):
#
#     a_s(B) = a_bg · (1 - Δ / (B - B0))
#
# Integrating a linear B(t) ramp gives a non-linear a_s(t). This helper
# pre-samples it and produces a `PiecewiseLinearWaveform` ready to be plugged
# into `TimeDependentInteractions.c0_wf`.
#
# Optical Feshbach resonances admit the same functional form; you would call
# this with the optical-resonance parameters instead of magnetic ones.

using SpinorBEC: PiecewiseLinearWaveform

"""
    feshbach_ramp(; a_bg, Delta, B0, B_start, B_end, duration,
                   ramp_shape=:linear, n_samples=2048,
                   c_scale=1.0) -> (c0_wf, a_s_wf, B_wf)

Build three pre-sampled waveforms for a Feshbach ramp scenario. The B(t)
ramp is governed by `ramp_shape`:

- `:linear` (default): B(t) = B_start + (B_end - B_start) · t/duration
- `:cubic_hermite`: smooth-step (dB/dt = 0 at the endpoints)
- `:exponential`: B(t) = B_end + (B_start - B_end) · exp(-5 t / duration)

`c_scale` maps a_s to dimensionless c0; if your atom gives c0 = g · a_s with
g = 4π ℏ² N / (m · a_ho) / ℏω_ref, pass that as `c_scale`. Default 1.0
leaves a_s in a_0 (Bohr-radius) units as c0.

Returns `(c0_wf, a_s_wf, B_wf)` as three `PiecewiseLinearWaveform`s. Use
`c0_wf` directly in `TimeDependentInteractions(c0_wf, c1_wf)`.

Caveat: near the pole `B = B0` a_s diverges. Inputs `B_start`, `B_end` that
straddle `B0` will produce a sign-flip (BEC → attractive → collapse). The
builder does *not* warn — it's the user's responsibility to stay away from
the pole or to handle the collapse dynamics explicitly.
"""
function feshbach_ramp(;
    a_bg::Real,
    Delta::Real,
    B0::Real,
    B_start::Real,
    B_end::Real,
    duration::Real,
    ramp_shape::Symbol=:linear,
    n_samples::Int=2048,
    c_scale::Real=1.0,
)
    duration > 0 || throw(ArgumentError("duration must be positive"))
    n_samples >= 2 || throw(ArgumentError("n_samples must be ≥ 2"))
    ramp_shape in (:linear, :cubic_hermite, :exponential) || throw(
        ArgumentError("ramp_shape must be :linear, :cubic_hermite, or :exponential"))

    T = Float64(duration)
    times = collect(range(0.0, T; length=n_samples))
    B_vals = Vector{Float64}(undef, n_samples)
    as_vals = Vector{Float64}(undef, n_samples)
    c0_vals = Vector{Float64}(undef, n_samples)

    B0f = Float64(B0)
    Bs = Float64(B_start)
    Be = Float64(B_end)
    ΔB = Be - Bs
    Δ = Float64(Delta)
    abg = Float64(a_bg)
    scale = Float64(c_scale)

    @inbounds for i in 1:n_samples
        s = times[i] / T
        frac = if ramp_shape == :linear
            s
        elseif ramp_shape == :cubic_hermite
            3s^2 - 2s^3
        else # :exponential
            # Converge from Bs toward Be; e^-5 ≈ 0.007 → effectively reaches Be
            1.0 - exp(-5.0 * s)
        end
        B = Bs + ΔB * frac
        # Avoid exact pole — replace with sign(B - B0) × huge if we hit it.
        denom = B - B0f
        a_s = abs(denom) < 1e-12 ? sign(denom) * 1.0e12 * abg :
              abg * (1.0 - Δ / denom)
        B_vals[i] = B
        as_vals[i] = a_s
        c0_vals[i] = scale * a_s
    end

    (PiecewiseLinearWaveform(times, c0_vals),
        PiecewiseLinearWaveform(times, as_vals),
        PiecewiseLinearWaveform(times, B_vals))
end

"""
    feshbach_c0_wf(; kwargs...) -> PiecewiseLinearWaveform

Convenience for when you only need the c0(t) channel. Same arguments as
`feshbach_ramp`.
"""
feshbach_c0_wf(; kwargs...) = feshbach_ramp(; kwargs...)[1]
