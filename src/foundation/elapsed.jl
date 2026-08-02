"""
One place for "how long did that take?".

`time()` is the WALL clock and it steps: NTP corrections, and on WSL2 a resume
from suspend. Subtracting two wall-clock readings therefore does not measure a
duration — it can come out negative, which is how this was found
(`find_ground_state_polished` reported `t_itp = -0.322 s` on 2026-07-29, caught
by `test/solvers/test_polished_ground_state.jl`'s `t_itp > 0`).

`time_ns()` is monotonic, so every duration in this codebase is measured as

    t0 = time_ns()
    …
    secs = elapsed_s(t0)

This matters beyond cosmetics: `runtime_seconds` in the pipeline result is
recorded to disk and the autopilot budget totals realized GPU-hours from it, so
a stepped clock corrupts accounting, not just a progress line.

Wall-clock DEADLINES are a different thing and legitimately use `time()` — the
question there is "what time is it", not "how long has this taken".
"""

"""
    elapsed_s(t0_ns::UInt64) -> Float64

Seconds elapsed since `t0_ns = time_ns()`, from the monotonic clock.
"""
elapsed_s(t0_ns::UInt64) = (time_ns() - t0_ns) / 1e9
