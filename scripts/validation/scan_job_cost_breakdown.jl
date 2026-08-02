#!/usr/bin/env julia
# Where does a scan JOB's wall-clock go? Not where the integrator work is.
#
#     julia --project=. scripts/validation/scan_job_cost_breakdown.jl <config.yaml> [npoints]
#
# The Matsui Fig. 4B campaign job ran 600 s for 45 points. Reading the points'
# own `started_at` / `finished_at` / `duration_seconds`, the scan span was 245 s
# — so 59 % of the job was startup and first-point JIT, and the dynamics stepping
# inside that 245 s is only 44 x 3456 x 0.604 ms = 92 s, i.e. **15 % of the job**.
# Shaving the integrator is the smallest of the three levers.
#
# This times the same config three ways in ONE session, so the JIT is paid once
# and the deltas are marginal costs:
#
#   A  first point           — JIT of run_pipeline / make_workspace / ITP / step
#   B  steady-state point    — what a scan point actually costs
#   C  same, with the GS stage cache on (SPINORBEC_STAGE_CACHE=1)
#
# and reports the stepping fraction of B, so the ceiling on any integrator-side
# optimisation is explicit.

using SpinorBEC
using Printf
using YAML

const CFG = length(ARGS) >= 1 ? ARGS[1] : error("usage: scan_job_cost_breakdown.jl <config.yaml>")
const NPTS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 3

"""
Write a copy of the config whose scan has exactly `n` points, and VERIFY it.

A scan axis is either an explicit vector or a `{from, to, step}` range under
`zip:` / `grid:`. The first version of this handled only the vector case, so on
a range-spec config it silently returned the config unchanged and the probe ran
four full 45-point scans while reporting them as 1- and 3-point timings. Hence
`_count_points` and the assertion: a trim that does not trim must be loud.
"""
function trimmed(cfg::String, n::Int, tag::String)
    d = YAML.load_file(cfg)
    sc = get(d, "scan", nothing)
    sc === nothing && error("config has no scan block")
    for axes in values(sc)
        axes isa AbstractDict || continue
        for (k, v) in axes
            if v isa AbstractVector
                length(v) > n && (axes[k] = v[1:n])
            elseif v isa AbstractDict && haskey(v, "from") && haskey(v, "step")
                v["to"] = Float64(v["from"]) + (n - 1) * Float64(v["step"])
            end
        end
    end
    got = _count_points(sc)
    got == n || error("trim asked for $n points, config yields $got — see the docstring")
    # Under the store, not mktempdir(): run_yaml derives its output directory
    # from the config's path, and a config in a compute node's /tmp puts the run
    # somewhere no other machine can watch.
    dir = joinpath(get(ENV, "SPINORBEC_STORE", "runs"), "_probe")
    mkpath(dir)
    out = joinpath(dir, "trim_$(tag).yaml")
    YAML.write_file(out, d)
    out
end

"Points a scan block will expand to (zip axes are parallel, grid axes multiply)."
function _count_points(sc::AbstractDict)
    total = 1
    for (mode, axes) in sc
        axes isa AbstractDict || continue
        lens = Int[]
        for v in values(axes)
            if v isa AbstractVector
                push!(lens, length(v))
            elseif v isa AbstractDict && haskey(v, "from")
                f, t, st = Float64(v["from"]), Float64(v["to"]), Float64(v["step"])
                push!(lens, floor(Int, (t - f) / st + 1e-9) + 1)
            end
        end
        isempty(lens) && continue
        total *= (mode == "zip" ? maximum(lens) : prod(lens))
    end
    total
end

function dyn_steps_and_dt(cfg::String)
    d = YAML.load_file(cfg)
    for st in d["pipeline"]
        haskey(st, "dynamics") || continue
        p = st["dynamics"]
        return (round(Int, Float64(p["duration"]) / Float64(p["dt"])), Float64(p["dt"]))
    end
    (0, NaN)
end

function main()
    nsteps, dt = dyn_steps_and_dt(CFG)
    @printf("config %s\n  dynamics: %d steps at dt = %.1e\n\n", basename(CFG), nsteps, dt)
    flush(stdout)

    # Announce BEFORE each phase and flush: with verbose=false a run_yaml prints
    # nothing, so a probe that only reports afterwards is indistinguishable from
    # a hung one. The first pass at this sat 19 minutes with no way to tell.
    function timed(label, path; verbose=false)
        @printf("  ... %s\n", label)
        flush(stdout)
        t = @elapsed run_yaml(path; verbose=verbose)
        @printf("  %-38s %8.2f s\n", label, t)
        flush(stdout)
        t
    end

    b_per_point = NaN
    withenv("SPINORBEC_STAGE_CACHE" => "0") do
        timed("A  1 point, cold (JIT rides here)", trimmed(CFG, 1, "a"); verbose=true)
        b = timed("B  $NPTS points, warm", trimmed(CFG, NPTS, "b"))
        b_per_point = b / NPTS
        @printf("     -> %.2f s/point\n", b_per_point)
    end

    withenv("SPINORBEC_STAGE_CACHE" => "1") do
        timed("C  $NPTS points, stage cache filling", trimmed(CFG, NPTS, "c1"))
        d = timed("C' $NPTS points, stage cache reusing", trimmed(CFG, NPTS, "c2"))
        @printf("     -> %.2f s/point  (%+.1f %% vs B)\n",
            d / NPTS, 100 * (d / NPTS - b_per_point) / b_per_point)
    end

    @printf("\nStepping is %d steps x (ms/step from step_cost_ablation_gpu.jl).\n", nsteps)
    println("At 32^3 that is 3456 x 0.604 ms = 2.09 s, so anything above that in the")
    println("per-point figure is setup the integrator cannot touch.")
end

main()
