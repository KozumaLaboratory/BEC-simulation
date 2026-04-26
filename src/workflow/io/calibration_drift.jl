# --- Trap drift correction (Phase 4/5 #68) ---
#
# Layered on top of CalibrationHistory (workflow/experiments/calibration.jl):
# converts week-to-week FORT-power-to-trap-frequency drift into a vector of
# trap frequencies as a function of simulation time, so a long run can
# track the gradual change in (ω_x, ω_y, ω_z) instead of using a single
# snapshot calibration.
#
# Two layers of API:
#   sample_trap_drift_omegas    — pure number-crunching: (history, dates,
#                                  axes, fort_mw) → Matrix{Float64} of
#                                  trap frequencies in Hz, one row per date
#   trap_drift_waveforms        — wraps the above into per-axis
#                                  PiecewiseLinearWaveform objects keyed by
#                                  *simulation* time, ready to drop into
#                                  TimeDependentTrap

"""
    sample_trap_drift_omegas(history, dates, fort_mw_per_axis) -> Matrix{Float64}

Linearly interpolate the FORT calibration in `history` to each date in
`dates` and apply `fort_mw_to_trap_hz` per axis. `fort_mw_per_axis` may
be a scalar (same FORT power on every axis) or a Vector / Tuple of length
3.

Returns a (length(dates), 3) matrix of trap frequencies in Hz, one row
per date, columns ordered (x, y, z).

Use this to plot the drift envelope; for actually feeding it into a
simulation, see `trap_drift_waveforms`.
"""
function sample_trap_drift_omegas(
    history::CalibrationHistory,
    dates::AbstractVector{Date},
    fort_mw_per_axis::Union{Real, AbstractVector{<:Real}, NTuple{3, <:Real}},
)
    fort_vec = if fort_mw_per_axis isa Real
        Float64[Float64(fort_mw_per_axis), Float64(fort_mw_per_axis), Float64(fort_mw_per_axis)]
    else
        v = collect(Float64, fort_mw_per_axis)
        length(v) == 3 || throw(ArgumentError("fort_mw_per_axis must be scalar or length 3"))
        v
    end
    out = Matrix{Float64}(undef, length(dates), 3)
    for (i, d) in enumerate(dates)
        cs = interpolate_calibration(history, d)
        for ax in 1:3
            out[i, ax] = fort_mw_to_trap_hz(fort_vec[ax], ax, cs.fort)
        end
    end
    out
end

"""
    trap_drift_waveforms(history, axes; start_date, sim_seconds_per_unit,
                         sim_duration, fort_mw_per_axis, n_samples=8,
                         omega_ref_hz=nothing) -> NTuple{N,PiecewiseLinearWaveform}

Build per-axis `PiecewiseLinearWaveform` objects that track the FORT
calibration drift across a simulation of length `sim_duration`
(dimensionless units). One sample is placed every
`sim_duration / (n_samples - 1)` and the corresponding lab date is
`start_date + sim_seconds_per_unit · t * 1 second` (rounded to the
nearest day).

When `omega_ref_hz` is supplied, each frequency is normalised to that
reference so the resulting waveform speaks in the standard SpinorBEC
dimensionless-units convention; otherwise raw Hz are returned.

`axes` selects which simulation axes get waveforms (e.g. `(1, 2, 3)`
for a 3D run, `(1, 2)` for a quasi-2D pancake).
"""
function trap_drift_waveforms(
    history::CalibrationHistory,
    axes::NTuple{N, Int};
    start_date::Date,
    sim_seconds_per_unit::Real,
    sim_duration::Real,
    fort_mw_per_axis::Union{Real, AbstractVector{<:Real}, NTuple{3, <:Real}},
    n_samples::Int=8,
    omega_ref_hz::Union{Nothing, Real}=nothing,
) where {N}
    n_samples >= 2 || throw(ArgumentError("n_samples must be >= 2"))
    sim_duration > 0 || throw(ArgumentError("sim_duration must be positive"))

    sim_times = collect(range(0.0, Float64(sim_duration); length=n_samples))
    dates = [
        start_date + Day(round(Int, t * Float64(sim_seconds_per_unit) / 86400.0))
        for t in sim_times
    ]
    omegas_hz = sample_trap_drift_omegas(history, dates, fort_mw_per_axis)

    scale = omega_ref_hz === nothing ? 1.0 : 1.0 / Float64(omega_ref_hz)
    waveforms = ntuple(N) do i
        ax = axes[i]
        ax in (1, 2, 3) || throw(ArgumentError("axis $ax out of range 1:3"))
        ys = Float64[omegas_hz[t, ax] * scale for t in 1:n_samples]
        PiecewiseLinearWaveform(sim_times, ys)
    end
    waveforms
end

"""
    apply_trap_drift(base_trap, history, axes; kwargs...) -> TimeDependentTrap

Wrap a static `HarmonicTrap` (or any `AbstractPotential` whose `omega`
field can be re-broadcast) into a `TimeDependentTrap` whose ω(t)
follows the FORT drift. Convenience constructor for the YAML / scripted
pipeline.

Forwards every kwarg to `trap_drift_waveforms`. The returned object can
be passed straight into `make_workspace(; potential=...)` and used by
the standard split-step.
"""
function apply_trap_drift(
    base_trap::AbstractPotential,
    history::CalibrationHistory,
    axes::NTuple{N, Int};
    kwargs...,
) where {N}
    waveforms = trap_drift_waveforms(history, axes; kwargs...)
    TimeDependentTrap(base_trap, waveforms)
end
