# --- P2.4: Shortcut-to-adiabaticity (STA) counter-diabatic driving ---
#
# For a two-level quadratic-Zeeman quench (F=1 polar → AFM at q=0), the
# Berry-Uhlmann counter-diabatic (CD) term can be written in closed form as an
# effective transverse field:
#
#     H(t) = q(t) F_z^2 + p(t) F_z + H_CD(t)
#     H_CD(t) = -(ℏ / 2) · dθ(t)/dt · F_y       (for a single-angle transform)
#
# where θ(t) parameterises the instantaneous eigenbasis rotation. For the
# textbook case θ(t) = arctan(q_0 / q(t)) the CD field reduces to a sinusoidal
# b_y(t) — that's what we compute below.
#
# Reference: Odelin et al., Rev. Mod. Phys. 91, 045001 (2019).
#
# This helper pre-samples q_CD(t), p_CD(t), b_y_CD(t) on a time grid and
# returns three `PiecewiseLinearWaveform`s ready for `TimeDependentZeeman`.
# Pre-sampling (not `FunctionWaveform`) keeps Workspace type parameters
# concrete — critical on the hot path (see CLAUDE.md > Type stability).

using SpinorBEC: PiecewiseLinearWaveform

"""
    sta_counter_diabatic_q_quench(
        ; q_start, q_end, duration, omega_ref=1.0,
          n_samples=2048, p_base=0.0,
    ) -> (p_wf, q_wf, by_wf)

Build three pre-sampled waveforms implementing an STA-accelerated quench of
the quadratic Zeeman parameter from `q_start` to `q_end` over `duration`.

The base quench trajectory is a smooth cubic ramp in q(t); the CD correction
is `b_y(t) = -1/(2 ω_ref) · dθ/dt` with θ(t) = arctan(q_0, q(t)).

Arguments:
- `q_start`, `q_end`: initial and final quadratic Zeeman (dimensionless)
- `duration`: quench time (dimensionless ω_ref⁻¹)
- `omega_ref`: reference frequency used in the dθ/dt → b_y mapping; kept at
  1.0 unless you're driving in SI and need rescaling.
- `n_samples`: number of time-grid points (default 2048, matches the Zeeman
  default in zeeman_levels.jl).
- `p_base`: constant linear-Zeeman offset (rare; usually 0).
- `q0_reference`: the θ=arctan(q0/q) denominator offset. Defaults to
  `|q_start - q_end| / 4` — empirically the STA prefactor that keeps the
  trajectory within the single-well Bloch region.

Returns a 3-tuple `(p_wf, q_wf, by_wf)` all `PiecewiseLinearWaveform`.
"""
function sta_counter_diabatic_q_quench(;
    q_start::Real,
    q_end::Real,
    duration::Real,
    omega_ref::Real=1.0,
    n_samples::Int=2048,
    p_base::Real=0.0,
    q0_reference::Union{Nothing, Real}=nothing,
)
    duration > 0 || throw(ArgumentError("duration must be positive"))
    n_samples >= 4 || throw(ArgumentError("n_samples must be ≥ 4"))

    q0 = q0_reference === nothing ? max(abs(q_start - q_end) / 4, 1e-12) :
         Float64(q0_reference)
    T = Float64(duration)
    times = collect(range(0.0, T; length=n_samples))
    q_vals = Vector{Float64}(undef, n_samples)
    p_vals = Vector{Float64}(undef, n_samples)
    by_vals = Vector{Float64}(undef, n_samples)

    qs = Float64(q_start)
    qe = Float64(q_end)
    p0 = Float64(p_base)
    ωr = Float64(omega_ref)

    # Cubic Hermite ramp with zero derivative at both ends → dq/dt = 0 at
    # t=0 and t=T (the STA CD field vanishes at the boundaries).
    @inbounds for i in 1:n_samples
        s = times[i] / T
        h = 3s^2 - 2s^3              # smooth-step
        dhdt = (6s - 6s^2) / T          # ds/dt = 1/T
        q = qs + (qe - qs) * h
        dqdt = (qe - qs) * dhdt
        θ = atan(q0, q)              # arctan(q0 / q) with full range
        # dθ/dt from d/dt arctan2(q0, q) = -q0/(q0² + q²) · dq/dt
        dθdt = -q0 * dqdt / (q0^2 + q^2)

        q_vals[i] = q
        p_vals[i] = p0
        # CD transverse field: b_y(t) = -1/(2 ω_ref) · dθ/dt
        by_vals[i] = -0.5 * dθdt / ωr
    end

    (PiecewiseLinearWaveform(times, p_vals),
        PiecewiseLinearWaveform(times, q_vals),
        PiecewiseLinearWaveform(times, by_vals))
end

"""
    build_sta_zeeman(; q_start, q_end, duration, atom=nothing, ...) -> TimeDependentZeeman

Convenience wrapper returning a ready-to-use `TimeDependentZeeman` with the
CD transverse-field channel populated. `bx` stays at zero by default.
"""
function build_sta_zeeman(;
    q_start::Real,
    q_end::Real,
    duration::Real,
    omega_ref::Real=1.0,
    n_samples::Int=2048,
    p_base::Real=0.0,
    q0_reference::Union{Nothing, Real}=nothing,
)
    p_wf, q_wf, by_wf = sta_counter_diabatic_q_quench(;
        q_start, q_end, duration, omega_ref, n_samples, p_base, q0_reference
    )
    bx_wf = PiecewiseLinearWaveform(
        [0.0, Float64(duration)], [0.0, 0.0]
    )
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end
