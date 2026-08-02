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

"Write a copy of the config whose scan has exactly `n` points."
function trimmed(cfg::String, n::Int, tag::String)
    d = YAML.load_file(cfg)
    sc = get(d, "scan", nothing)
    sc === nothing && error("config has no scan block")
    for (k, v) in sc
        v isa AbstractVector && length(v) > n && (sc[k] = v[1:n])
    end
    out = joinpath(mktempdir(), "trim_$(tag).yaml")
    YAML.write_file(out, d)
    out
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

    withenv("SPINORBEC_STAGE_CACHE" => "0") do
        a = @elapsed run_yaml(trimmed(CFG, 1, "a"); verbose=false)
        @printf("A  1 point,  cold (JIT rides here)   : %8.2f s\n", a)
        b = @elapsed run_yaml(trimmed(CFG, NPTS, "b"); verbose=false)
        @printf("B  %d points, warm                    : %8.2f s  -> %.2f s/point\n",
            NPTS, b, b / NPTS)
        global _B_PER_POINT = b / NPTS
    end

    withenv("SPINORBEC_STAGE_CACHE" => "1") do
        c = @elapsed run_yaml(trimmed(CFG, NPTS, "c1"); verbose=false)   # populates
        d = @elapsed run_yaml(trimmed(CFG, NPTS, "c2"); verbose=false)   # reuses
        @printf("C  %d points, stage cache populating  : %8.2f s  -> %.2f s/point\n",
            NPTS, c, c / NPTS)
        @printf("C' %d points, stage cache reusing     : %8.2f s  -> %.2f s/point  (%+.1f %%)\n",
            NPTS, d, d / NPTS, 100 * (d / NPTS - _B_PER_POINT) / _B_PER_POINT)
    end

    println("\nSteady-state point, where the time goes:")
    println("  Run scripts/validation/step_cost_ablation_gpu.jl for ms/step at this n,")
    println("  multiply by the step count above, and the remainder is per-point setup")
    println("  (two make_workspace calls, the ground state, analyzers, the JLD2 save).")
    println("  The integrator can only ever address the stepping fraction.")
end

main()
