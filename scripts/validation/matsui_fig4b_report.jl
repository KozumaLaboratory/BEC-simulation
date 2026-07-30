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

const FIXDIR = joinpath(@__DIR__, "..", "..", "test", "fixtures", "matsui2025")

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
Population fraction of every m component at the END of the hold, per scan point.

Taken from the saved final `psi`, not from the last row of
`dynamics/component_populations`: with `save.every = 100` over 3456 steps the
last *sample* is at step 3400, 1.6 % of the hold short of the 5 ms the
comparison is about. ψ is normalised to 1, so the fractions need no grid.
"""
function final_populations(run_dir)
    files = sort(filter(f -> occursin(r"^point_\d+\.jld2$", f), readdir(run_dir)))
    isempty(files) && error("no point_NNN.jld2 in $run_dir")
    map(files) do f
        jldopen(joinpath(run_dir, f), "r") do d
            psi = d["psi"]                                   # (n..., 2F+1)
            D = size(psi)[end]
            w = [sum(abs2, selectdim(psi, ndims(psi), c)) for c in 1:D]
            w ./ sum(w)
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
    B = scan_fields_nT(run_dir)
    pops = final_populations(run_dir)
    length(B) == length(pops) || error(
        "scan axis has $(length(B)) fields but $(length(pops)) point files — " *
        "the run is incomplete; do not read a dip off it",
    )

    D = length(pops[1])
    F = (D - 1) ÷ 2
    N_atoms = YAML.load_file(joinpath(run_dir, "config.yaml"))["defaults"]["interactions"]["N_atoms"]
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
