#!/usr/bin/env julia
# Read `bench/ab_driver.sh` rows and say what they do and do NOT establish.
#
#   julia --project=. bench/ab_report.jl out.jsonl [label_a=<sha>] [label_b=<sha>]
#
# The rule this exists to enforce: **a difference smaller than the spread WITHIN
# an arm is not a result.** Every wrong performance claim I made on 2026-08-02
# had that shape — 15 % read off two single runs that turned out to be node
# drift, and "+17 % more iterations" read off n = 2 against a moving baseline.
# Eyeballing two medians cannot catch it, which is why the rule is code with a
# test rather than a habit.
#
# The comparison is deliberately non-parametric and blunt. These are 3-6 sample
# arms from a shared cluster node; a t-test would import an independence and
# normality assumption neither of which holds, and would license claims the
# samples cannot support. `resolved` asks only whether the arms SEPARATE:
# whether the observed ranges are disjoint by more than the wider arm's own
# spread.

module ABReport

export Arm, summarize, compare, ComparisonResult

using Printf
using Statistics: median

struct Arm
    label::String
    values::Vector{Float64}
end

"Median, min, max, and the half-range used as this arm's own spread."
function summarize(a::Arm)
    v = sort(a.values)
    n = length(v)
    n == 0 && return (; n=0, med=NaN, lo=NaN, hi=NaN, spread=NaN)
    (; n, med=median(v), lo=first(v), hi=last(v), spread=(last(v) - first(v)) / 2)
end

struct ComparisonResult
    metric::String
    a::NamedTuple
    b::NamedTuple
    delta::Float64          # b.med - a.med
    rel::Float64            # delta / a.med
    resolved::Bool
    reason::String
end

"""
    compare(metric, a::Arm, b::Arm; min_n=3) → ComparisonResult

`resolved` is true only when

  * both arms have at least `min_n` samples, and
  * the observed ranges are DISJOINT — `max` of the lower arm below `min` of the
    upper — and
  * the gap between those ranges is at least the wider arm's spread.

Anything else is reported as unresolved, with what it would take. Two medians
differing by less than the samples scatter is exactly the situation in which
the honest answer is "this measurement cannot tell", and the whole point of
this file is that the honest answer is produced automatically rather than
remembered.
"""
function compare(metric::AbstractString, a::Arm, b::Arm; min_n::Int=3)
    sa, sb = summarize(a), summarize(b)
    delta = sb.med - sa.med
    rel = sa.med == 0 ? NaN : delta / abs(sa.med)

    if sa.n < min_n || sb.n < min_n
        return ComparisonResult(metric, sa, sb, delta, rel, false,
            "n = $(sa.n)/$(sb.n), need $min_n per arm")
    end
    lower, upper = sa.hi <= sb.lo ? (sa, sb) : (sb, sa)
    if !(lower.hi < upper.lo)
        return ComparisonResult(metric, sa, sb, delta, rel, false,
            @sprintf("ranges OVERLAP (%.4g..%.4g vs %.4g..%.4g); the arms are not separated",
                sa.lo, sa.hi, sb.lo, sb.hi))
    end
    gap = upper.lo - lower.hi
    widest = max(sa.spread, sb.spread)
    if gap < widest
        return ComparisonResult(metric, sa, sb, delta, rel, false,
            @sprintf("gap %.4g is under the wider arm's own spread %.4g", gap, widest))
    end
    ComparisonResult(metric, sa, sb, delta, rel, true,
        @sprintf("ranges disjoint by %.4g, above the wider spread %.4g", gap, widest))
end

function Base.show(io::IO, r::ComparisonResult)
    @printf(io, "  %-14s %-9s med=%-10.4g [%.4g..%.4g] n=%d\n",
        r.metric, "A", r.a.med, r.a.lo, r.a.hi, r.a.n)
    @printf(io, "  %-14s %-9s med=%-10.4g [%.4g..%.4g] n=%d\n",
        "", "B", r.b.med, r.b.lo, r.b.hi, r.b.n)
    if r.resolved
        @printf(io, "  %-14s => %+.4g (%+.1f %%)  RESOLVED — %s\n\n",
            "", r.delta, 100 * r.rel, r.reason)
    else
        @printf(io, "  %-14s => %+.4g (%+.1f %%)  NOT RESOLVED — %s\n\n",
            "", r.delta, 100 * r.rel, r.reason)
    end
end

"Minimal JSONL reader for the driver's row shape. No dependency: the rows are
written by an awk one-liner and must stay readable without one."
function read_rows(path::AbstractString)
    rows = NamedTuple{(:metric, :value, :sha), Tuple{String, Float64, String}}[]
    for line in eachline(path)
        startswith(line, "{\"metric\"") || continue
        m = match(r"\"metric\"\s*:\s*\"([^\"]*)\"", line)
        v = match(r"\"value\"\s*:\s*(-?[\d.eE+]+)", line)
        s = match(r"\"sha\"\s*:\s*\"([^\"]*)\"", line)
        (m === nothing || v === nothing || s === nothing) && continue
        push!(rows, (metric=m.captures[1], value=parse(Float64, v.captures[1]),
            sha=s.captures[1]))
    end
    rows
end

function main(args)
    isempty(args) && (println("usage: ab_report.jl out.jsonl"); return 1)
    rows = read_rows(args[1])
    isempty(rows) && (println("no rows in $(args[1]) — the driver wrote nothing"); return 1)
    shas = unique(r.sha for r in rows)
    length(shas) == 2 ||
        (println("expected exactly 2 SHAs, found $(length(shas)): $shas"); return 1)
    A, B = shas
    println("A = $A\nB = $B\n")
    unresolved = 0
    for metric in unique(r.metric for r in rows)
        a = Arm("A", [r.value for r in rows if r.sha == A && r.metric == metric])
        b = Arm("B", [r.value for r in rows if r.sha == B && r.metric == metric])
        res = compare(metric, a, b)
        res.resolved || (unresolved += 1)
        show(stdout, res)
    end
    unresolved > 0 && println("$unresolved metric(s) NOT RESOLVED — do not quote those.")
    return 0
end

end # module

# Run as a script, not when `include`d by the test — `PROGRAM_FILE` is empty
# under `julia -e`, and `abspath("")` is the working directory, which happily
# compares unequal and then exits anyway on some paths.
if !isempty(PROGRAM_FILE) && abspath(PROGRAM_FILE) == @__FILE__
    exit(ABReport.main(ARGS))
end
