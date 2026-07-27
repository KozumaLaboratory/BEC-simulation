# reconcile.jl
# =================================================================
# Two helpers for timing measurements that are allowed to become premises.
#
# A component timing that has not been reconciled against the end-to-end time
# is not a measurement yet. Both of the errors this file exists to prevent were
# made in one session, on the same kernel, hours apart:
#
#   1. `t = @elapsed for _ in 1:10; f(); end; t/10` reported
#      `_bdg_contact_matrices` at 41 ms. Warm value: 1.0 ms. The first
#      iteration was compiling and the JIT time got divided by ten. A
#      derived "85% of runtime is redundant" was published off the back of
#      it — wrong by 37x, and the components on screen at that moment were
#      already mutually contradictory (one part exceeded the whole by 19x).
#
#   2. The corrected run left an 83% residual, which was attributed to "GC
#      pressure" because 650 MB of allocation made that plausible. Measured
#      GC: 2.8%. The residual was really the k-loop, whose isolated benchmark
#      had been fed contact-only matrices — structurally sparser than the
#      dipolar ones the real loop sees, and 7x cheaper to diagonalise.
#
# Same failure both times: a number was reported without a second, independent
# route to it. `timed` removes the JIT artifact; `reconcile` removes the
# freedom to publish a breakdown that does not add up.
#
#   include(joinpath(@__DIR__, "reconcile.jl"))
#
#   total = timed(() -> build_the_thing())
#   parts = ["setup"  => 1 * timed(() -> setup()),
#            "kernel" => N * timed(() -> kernel())]
#   reconcile(total, parts)          # prints the table; throws if it fails
#
# `reconcile` throws by default. That is the point: an unreconciled breakdown
# should stop the analysis, not decorate it with a caveat that gets dropped on
# the way into a commit message.

using Printf

"""
    timed(f; warmup=2, samples=5) -> (t, bytes, gctime)

Wall time for `f()` as the MINIMUM over `samples` runs after `warmup` discarded
runs, plus the allocation and GC time of the best run.

Minimum, not mean: the distribution is a floor plus contamination (GC, other
processes, frequency scaling), so the smallest sample is the best estimate of
the thing being measured and the mean estimates nothing in particular.

Warm-up is not optional in a JIT language, and dividing a cold loop by its
iteration count does not substitute for it — it just spreads the compile over
the samples.
"""
function timed(f; warmup::Int=2, samples::Int=5)
    for _ in 1:warmup
        f()
    end
    best = (t=Inf, bytes=0, gctime=0.0)
    for _ in 1:samples
        r = @timed f()
        r.time < best.t && (best = (t=r.time, bytes=r.bytes, gctime=r.gctime))
    end
    best
end

"""
    reconcile(total, parts; tol=0.20, strict=true) -> Float64

Print a breakdown of `total` (a `timed` result or a plain seconds value) into
`parts` (`name => seconds` pairs, each already multiplied by its call count)
and return the fractional residual.

Throws when `|Σ parts − total| / total > tol`, because a breakdown that does
not close is not evidence about anything: the parts may be mismeasured, the
call counts may be wrong, or the components may not be what the total is
actually spending its time on. Any of those invalidates the conclusion the
breakdown was gathered to support. Pass `strict=false` only when you are
deliberately reporting an incomplete decomposition and say so.

`tol = 0.20` is loose on purpose — it is a blunder detector, not a precision
budget. The failures worth catching here are 37x and 83%.
"""
function reconcile(total, parts; tol::Float64=0.20, strict::Bool=true)
    T = total isa NamedTuple ? total.t : Float64(total)
    T > 0 || throw(ArgumentError("reconcile: total must be positive, got $T"))
    s = sum(Float64(p.second) for p in parts; init=0.0)
    resid = T - s

    width = maximum(length(String(p.first)) for p in parts; init=8)
    for p in parts
        @printf("  %-*s %9.4f s  (%5.1f%%)\n", width, p.first,
            Float64(p.second), 100 * Float64(p.second) / T)
    end
    @printf("  %-*s %9.4f s\n", width, "Σ parts", s)
    @printf("  %-*s %9.4f s\n", width, "measured total", T)
    @printf("  %-*s %9.4f s  (%+.1f%%)  -> %s\n", width, "RESIDUAL", resid,
        100 * resid / T, abs(resid) / T <= tol ? "CLOSES" : "DOES NOT CLOSE")
    if total isa NamedTuple
        @printf("  %-*s %9.1f MB allocated, %.1f%% in GC\n", width, "",
            total.bytes / 2^20, 100 * total.gctime / T)
    end

    if abs(resid) / T > tol && strict
        error(
            "reconcile: breakdown does not close — residual $(round(100 * resid / T; digits=1))% " *
            "exceeds tol=$(round(100 * tol; digits=1))%. The parts, their call " *
            "counts, or the choice of components is wrong; do not use this " *
            "breakdown as evidence. Measure the residual instead of naming it.",
        )
    end
    resid / T
end
