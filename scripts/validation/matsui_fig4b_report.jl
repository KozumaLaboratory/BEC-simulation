#!/usr/bin/env julia
# Turn a runs/matsui_fig4b B-scan into the two numbers Fig. 4B is a test of:
# the dip centre and its half-depth width in N_{m=-6} after the hold.
#
#     julia --project=. scripts/validation/matsui_fig4b_report.jl <run_dir> [out.csv]
#
# `run_dir` is the CAS directory run_yaml wrote (contains point_NNN.jld2 and
# config.yaml). Emits a per-field table, the dip metrics, and — critically — the
# SAME metric applied to the published curve restricted to the SAME field
# window, because a half-depth width measured against a different baseline is
# not the same number.

using SpinorBEC
using CodecZstd   # must be loaded BEFORE jldopen: JLD2's dynamic load of the
# zstd decompressor hits a world-age error mid-call otherwise
using JLD2
using YAML
using DelimitedFiles
using Printf

# Overridable so the report can run from a scratch copy on a cluster login node
# without checking out the repo a second time.
const FIXDIR = get(ENV, "MATSUI_FIXTURES",
    joinpath(@__DIR__, "..", "..", "test", "fixtures", "matsui2025"))

"Field (nT) of each scan point, in the order run_yaml emitted them."
function scan_fields_nT(run_dir)
    cfg = YAML.load_file(joinpath(run_dir, "config.yaml"))
    axis = cfg["scan"]["zip"]["pipeline.1.B.Bz.to"]
    gauss = if axis isa AbstractVector
        Float64.(axis)
    else
        collect(Float64(axis["from"]):Float64(axis["step"]):(Float64(axis["to"]) + 1e-12))
    end
    gauss .* 1e5   # 1 Gauss = 1e-4 T = 1e5 nT
end

"""
Population fraction of every m component at the end of the hold, per scan point.

Read from the last row of `dynamics/component_populations`, NOT from the saved
top-level `psi`. In every multi-point scan run_yaml produced on 2026-07-30,
`point_001`'s `psi` is the **ground state** rather than the evolved state — 45/45,
19/19 and 6/6 point scans each had exactly that one file wrong, and a single-point
run had none. Reading `psi` therefore hands you a first scan point that looks like
a completely untransferred cloud, which at the edge of a scan is exactly where the
baseline of a dip measurement comes from.

The cost of using the series instead is that the last sample lands on the last
multiple of `save.every`, so make `save.every` divide the step count (3456 = 32 x
108). This function checks it did, and refuses rather than quietly reporting a
population from 98 % of the hold.
"""
function final_populations(run_dir; duration=nothing, dt=nothing)
    files = sort(filter(f -> occursin(r"^point_\d+\.jld2$", f), readdir(run_dir)))
    isempty(files) && error("no point_NNN.jld2 in $run_dir")
    map(files) do f
        jldopen(joinpath(run_dir, f), "r") do d
            pops = d["dynamics"]["component_populations"]   # (n_saves, 2F+1)
            times = d["dynamics"]["times"]
            # One dt of slack: the integrator takes ceil(duration/dt) steps, so the
            # last sample lands at 3.4560 for a nominal 3.4558. Anything larger
            # means save.every does not divide the step count.
            if duration !== nothing && abs(times[end] - duration) > 1.1e-3
                error(
                    "$f: last dynamics sample is at t = $(times[end]) but the hold " *
                    "ends at $duration — set save.every to divide the step count",
                )
            end
            psi = d["psi"]
            D = size(psi)[end]
            w = [sum(abs2, selectdim(psi, ndims(psi), c)) for c in 1:D]
            w ./= sum(w)
            if abs(w[D] - pops[end, D]) > 0.02
                @warn "$f: saved psi disagrees with the dynamics series — the known \
                       point_001 ground-state-instead-of-final-state defect" psi_frac = w[D] series_frac = pops[
                    end, D
                ]
            end
            vec(pops[end, :])
        end
    end
end

"Reference curve from the published sheet, restricted to [lo, hi] nT."
function reference_dip(lo, hi)
    raw, _ = readdlm(joinpath(FIXDIR, "dataset_fig4_theo.csv"), ','; header=true)
    B = Float64.(raw[:, 1])
    N6 = Float64.(raw[:, 2])
    p = sortperm(B)
    B, N6 = B[p], N6[p]
    keep = (B .>= lo) .& (B .<= hi)
    (resonance_dip(B[keep], N6[keep]), count(keep))
end

function main(run_dir, out_csv=nothing)
    cfg = YAML.load_file(joinpath(run_dir, "config.yaml"))
    duration = Float64(cfg["pipeline"][2]["dynamics"]["duration"])
    B = scan_fields_nT(run_dir)
    pops = final_populations(run_dir; duration)
    length(B) == length(pops) || error(
        "scan axis has $(length(B)) fields but $(length(pops)) point files — " *
        "the run is incomplete; do not read a dip off it",
    )

    D = length(pops[1])
    F = (D - 1) ÷ 2
    N_atoms = cfg["defaults"]["interactions"]["N_atoms"]
    # c = 1 ↔ m = +F (ours); their sheets are columns m = -F … +F.
    N6 = [Float64(N_atoms) * p[D] for p in pops]   # m = -F

    println("field [nT]   N_{-6}      frac      Fz/N")
    for (b, p) in zip(B, pops)
        fz = sum((F - (c - 1)) * p[c] for c in 1:D) / sum(p)
        @printf("%9.2f  %10.1f  %8.5f  %8.4f\n", b, N_atoms * p[D], p[D], fz)
    end

    d = resonance_dip(B, N6)
    (ref, nref) = reference_dip(minimum(B), maximum(B))

    println()
    @printf("%-28s %12s %12s\n", "", "centre [nT]", "width [nT]")
    @printf("%-28s %12.4f %12.4f\n", "SpinorBEC (this run)", d.center, d.width)
    @printf("%-28s %12.4f %12.4f   (%d pts in window)\n",
        "Matsui simulation, same window", ref.center, ref.width, nref)
    @printf("%-28s %12.4f %12.4f\n", "difference", d.center - ref.center, d.width - ref.width)

    if out_csv !== nothing
        open(out_csv, "w") do io
            println(io, "B_nT," * join(["N_m$(F - (c - 1))" for c in 1:D], ","))
            for (b, p) in zip(B, pops)
                println(io, join([string(b); [string(N_atoms * x) for x in p]], ","))
            end
        end
        println("\nwrote $out_csv")
    end
    (; run=d, ref)
end

isempty(ARGS) && error("usage: matsui_fig4b_report.jl <run_dir> [out.csv]")
main(ARGS[1], length(ARGS) > 1 ? ARGS[2] : nothing)
