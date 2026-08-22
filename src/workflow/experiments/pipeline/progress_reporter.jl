# --- Wall-clock progress for long dynamics runs ---
#
# WHY THIS EXISTS
#
# On 2026-08-20 three 128³ jobs were killed by `execd enforced h_rt limit` at
# 7195 s having produced one line of output each: `Step 2/2:
# ScalarEGPEDynamicsStep`. The `h_rt` was set too short — that was a human
# error — but the cost of the error was two hours per job, and it was two hours
# only because **"90 % done" and "stuck at 10 %" printed the same thing.**
#
# The three consequences, in the order they bit:
#
#   1. no ETA, so the decision "this will not finish, kill it now" could not be
#      made at all. Two estimates were given in that session and one was
#      withdrawn;
#   2. no way to tell a slow run from a hung one;
#   3. `h_rt` adequacy observable only through "finished" vs "killed", which is
#      the most expensive possible instrument.
#
# WHAT THIS IS NOT
#
# It is not the liveness file. `_emit_live_status` writes `_live_status.json`
# for the autopilot's divergence reaper, and #408 proposed riding on it because
# it already reaches all three dynamics paths. That is the right SHAPE and the
# wrong COUPLING: the liveness callback is built from `live_monitor:`, whose own
# documentation tells batch users to switch it OFF —
#
#     # live_monitor defaults ON (every=50). Disable explicitly with
#     # `live_monitor: false` for batch / TSUBAME / no-dashboard runs.
#
# — so a progress line hung off it would be absent from exactly the hand-submitted
# `qsub` job the issue was opened about. What is borrowed instead is the property
# that made the liveness fix stick: ONE reporter, constructed the same way on
# every dynamics path, with a gate that reddens when a path is added without it
# (`test/workflow/test_every_dynamics_path_reports_progress.jl`).
#
# The knob is an environment variable and not a YAML key, deliberately. A YAML
# key is a per-config decision, and "this config is long enough to want progress"
# is a decision nobody makes correctly in advance — that is the whole content of
# the incident. The variable silences it for the one caller who genuinely wants
# silence (a test), which is the same shape as `SPINORBEC_TEST_TIMING=quiet`.

export ProgressReporter, progress_enabled, PROGRESS_OFF_VALUES

"""
    ProgressReporter(label, n_steps, t_end; interval_s, io)

Wall-clock-throttled progress line for one dynamics phase.

Call it on every step; it prints at most once per `interval_s` seconds. The
throttle is on TIME and not on step count on purpose — a step-count cadence is a
flood at 32³ and silence at 128³, which is the resolution where the silence
actually costs something.

Reports, in the form [`feedback_report_eta_as_completion_time`](@ref) asks for:
elapsed, remaining, **and the wall-clock time it expects to finish at**, because
"66 minutes left" has to be added to the current time by hand before it can be
compared with an `h_rt`.

    [dynamics]  t = 0.44/1.10 (40.0 %)  step 176000/440000  elapsed 44m01s  left 1h06m  ETA 18:32:07

Progress is measured on PHYSICAL time `t / t_end` rather than on the step index,
so a path whose callback receives a save index rather than a step index still
reports a true fraction. `n_steps` is displayed, never divided by.
"""
struct ProgressReporter{IOT <: IO} <: Function
    label::String
    n_steps::Int
    t_end::Float64
    interval_s::Float64
    started::Base.RefValue{Float64}
    last::Base.RefValue{Float64}
    io::IOT
end

# Parameterised on the IO type rather than declaring `io::IO`. The reporter is
# reached from `SimulationCallbacks{typeof(on_step)}`, i.e. it becomes a
# Workspace-path type parameter, and an abstractly-typed field there is the
# boxing that `pitfall_partial_type_params_in_struct_fields` is about.
function ProgressReporter(label::AbstractString, n_steps::Integer, t_end::Real;
    interval_s::Real=_progress_interval(), io::IO=stdout)
    now = time()
    ProgressReporter(String(label), Int(n_steps), Float64(t_end),
        Float64(interval_s), Ref(now), Ref(now), io)
end

"""
    PROGRESS_OFF_VALUES

What `SPINORBEC_PROGRESS` may be set to in order to silence progress lines.
Closed set, and every member means the same thing — a free-text comparison here
would make `SPINORBEC_PROGRESS=false` and `SPINORBEC_PROGRESS=off` behave
differently for no reason a user could predict.
"""
const PROGRESS_OFF_VALUES = ("quiet", "off", "0", "false", "no", "none")

"""
    progress_enabled() -> Bool

Progress is ON unless `SPINORBEC_PROGRESS` names one of
[`PROGRESS_OFF_VALUES`](@ref). Default-on is the whole point: #408 is an issue
about a run that was silent, and an opt-in fix would have been opted out of by
the same person who set the wrong `h_rt`.
"""
progress_enabled() =
    !(lowercase(strip(get(ENV, "SPINORBEC_PROGRESS", ""))) in PROGRESS_OFF_VALUES)

"""
    _progress_interval() -> Float64

Seconds between progress lines, from `SPINORBEC_PROGRESS_INTERVAL` (default 60).
A non-positive or unparseable value falls back to the default rather than
throwing: a malformed environment variable must not be able to kill a job that
had already started, which is the failure this file exists to reduce.
"""
function _progress_interval()
    raw = get(ENV, "SPINORBEC_PROGRESS_INTERVAL", "")
    v = tryparse(Float64, strip(raw))
    (v === nothing || !(v > 0)) ? 60.0 : v
end

"""
    _build_progress_reporter(label, n_steps, t_end) -> Union{Nothing,ProgressReporter}

`nothing` when progress is disabled, so the result composes into
[`_compose_callbacks`](@ref) and into the `cb === nothing || cb(...)` guards the
hand-written loops already use for liveness.
"""
_build_progress_reporter(label::AbstractString, n_steps::Integer, t_end::Real) =
    progress_enabled() ? ProgressReporter(label, n_steps, t_end) : nothing

"Human duration: `44m01s`, `1h06m`, `2d03h`. Never a bare float of seconds."
function _fmt_duration(s::Real)
    (isfinite(s) && s >= 0) || return "--"
    x = round(Int, s)
    x < 60 && return string(x, "s")
    x < 3600 && return string(x ÷ 60, "m", lpad(x % 60, 2, '0'), "s")
    x < 86400 && return string(x ÷ 3600, "h", lpad((x % 3600) ÷ 60, 2, '0'), "m")
    string(x ÷ 86400, "d", lpad((x % 86400) ÷ 3600, 2, '0'), "h")
end

"""
    _progress_line(pr, step, t, now) -> String

The line, as a pure function of the reporter's state and the clock. Split out
from the printing so a test can assert the CONTENT — that the ETA is a clock
time and that the percentage tracks `t / t_end` — without capturing stdout or
waiting a minute for a throttle to open.
"""
function _progress_line(pr::ProgressReporter, step::Integer, t::Real, now::Float64)
    elapsed = now - pr.started[]
    frac = if pr.t_end > 0
        clamp(Float64(t) / pr.t_end, 0.0, 1.0)
    else
        (pr.n_steps > 0 ? clamp(step / pr.n_steps, 0.0, 1.0) : 0.0)
    end
    # Below ~0.1 % the extrapolation is division by noise and would print an ETA
    # of days that moves by hours on the next line. `--` is the honest output:
    # nothing has been measured yet.
    remaining = frac > 1e-3 ? elapsed * (1 - frac) / frac : NaN
    eta = if isfinite(remaining)
        Dates.format(Dates.now() + Dates.Second(round(Int, remaining)), "HH:MM:SS")
    else
        "--"
    end
    string("[", pr.label, "]  t = ", round(Float64(t); digits=4), "/",
        round(pr.t_end; digits=4), " (", round(100 * frac; digits=1), " %)",
        "  step ", step, "/", pr.n_steps,
        "  elapsed ", _fmt_duration(elapsed),
        "  left ", _fmt_duration(remaining),
        "  ETA ", eta)
end

"""
    _progress!(pr, step, t) -> Bool

Print if the throttle has opened; `true` when a line was emitted.

`flush` is not optional here. Julia fully buffers a non-TTY stdout, so a
backgrounded job without it writes a zero-byte log until it exits — which is
indistinguishable from the silence this file was written to remove.
"""
function _progress!(pr::ProgressReporter, step::Integer, t::Real)
    now = time()
    (now - pr.last[]) < pr.interval_s && return false
    pr.last[] = now
    println(pr.io, _progress_line(pr, step, t, now))
    flush(pr.io)
    true
end

_progress!(::Nothing, ::Integer, ::Real) = false

# The spinor path composes its callbacks and hands the result to
# `SimulationCallbacks(; on_step=…)`, so the reporter has to BE the callback
# there. The three hand-written loops (rotating / scalar eGPE / binary) call
# `_progress!` directly, because they have the step and the time in hand and a
# wrapper closure would be one more type on a Workspace path for nothing.
#
# `<: Function` on the struct is load-bearing and was not cosmetic:
# `_run_dynamics_with_optional_streaming!` types its hook
# `extra_on_step::Union{Nothing, Function}`, so a plain callable struct is a
# MethodError at that kwarg. `ComposedCallbacks` had the same defect latent —
# it only ever reached that kwarg when two callbacks were active at once, which
# needed `live_monitor` on (so, a `run_yaml` with a run directory) AND an
# `sgpe:` / `projected_gp:` / `photon_scattering:` block. Making progress
# default-on would have made two callbacks the NORMAL case and turned a latent
# defect into every standard dynamics run.
@inline (pr::ProgressReporter)(ws, step, times, energies) =
    (_progress!(pr, step, Float64(ws.state.t)); nothing)
