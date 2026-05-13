# EdH × K_3 A/B comparison — extract time series from both branches of
# `runs/eu151_edh_k3_compare` and emit a tidy CSV + matplotlib renderer.
#
# Usage:
#   julia --project=. scripts/analysis/compare_edh_k3.jl \
#       runs/eu151_edh_k3_compare
#
# Then:
#   python3 runs/eu151_edh_k3_compare/edh_k3_compare.py
#
# Metrics extracted per frame:
#   - norm           : total atom number conservation (K_3 → decay)
#   - peak_density   : max |ψ|² across space (K_3 → suppresses spike)
#   - Fz, Lz         : spin / orbital angular momentum (EdH transfer; K_3 local)
#   - per_m fractions: m-resolved populations (EdH redistribution)

using JLD2
using SpinorBEC: SpinorBEC  # forces CodecZstd to load with correct world age
using Printf

const BRANCHES = ("baseline_no_K3", "K3_dy_like")

function _peak_density_history(path::String)
    JLD2.jldopen(path, "r") do f
        haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots") || return Float64[]
        n_snaps = f["dynamics/psi_snapshots_streamed/n_snapshots"]
        peaks = Float64[]
        for i in 1:n_snaps
            key = "dynamics/psi_snapshots_streamed/frame_$(lpad(i, 5, '0'))"
            haskey(f, key) || continue
            psi = f[key]
            # |psi|² per voxel summed over spinor index (last dim), then max
            n_tot = dropdims(sum(abs2, psi; dims=ndims(psi)); dims=ndims(psi))
            push!(peaks, Float64(maximum(n_tot)))
        end
        peaks
    end
end

function _read_branch(path::String)
    out = Dict{Symbol, Any}()
    JLD2.jldopen(path, "r") do f
        haskey(f, "dynamics/times") || return
        out[:times] = Float64.(f["dynamics/times"])
        # Norms & energies always present in the spinor save path.
        for (k_jld, k_out) in (
            ("dynamics/norms", :norms),
            ("dynamics/energies", :energies),
            ("dynamics/magnetizations", :magnetizations),
            ("dynamics/peak_density", :peak_density),
            ("dynamics/Fz", :Fz),
            ("dynamics/Fx", :Fx),
            ("dynamics/Fy", :Fy),
            ("dynamics/Lz", :Lz),
            ("dynamics/per_m_history", :per_m),
        )
            haskey(f, k_jld) && (out[k_out] = Float64.(f[k_jld]))
        end
    end
    # Backward-compatibility: pre-2026-05-13 saves wrote `magnetizations`
    # but not `Fz`. Treat them as the same physical quantity ⟨F_z⟩.
    if !haskey(out, :Fz) && haskey(out, :magnetizations)
        out[:Fz] = out[:magnetizations]
    end
    # peak_density fallback: derive from per-snapshot if available.
    if !haskey(out, :peak_density)
        out[:peak_density] = _peak_density_history(path)
    end
    out
end

function compare_branches(run_dir::String)
    paths = Dict{String, String}()
    for branch in BRANCHES
        # comparison_runs save as point_001_<branch>.jld2 (run_registry.jl
        # `_point_filename(i, run_name)`).
        candidate = joinpath(run_dir, "point_001_$(branch).jld2")
        if isfile(candidate)
            paths[branch] = candidate
        else
            @warn "missing branch result" branch path=candidate
        end
    end
    isempty(paths) && error("no branch result files found in $run_dir")

    data = Dict{String, Any}()
    for (branch, path) in paths
        data[branch] = _read_branch(path)
    end
    data
end

function _emit_csv(data, run_dir::String)
    csv_path = joinpath(run_dir, "edh_k3_compare.csv")
    # Long-format CSV: branch, frame, t, norm, peak_density, Fz, Lz, ...
    open(csv_path, "w") do io
        header = ["branch", "frame", "t", "norm", "peak_density",
                  "Fz", "Fx", "Fy", "Lz"]
        println(io, join(header, ","))
        for branch in BRANCHES
            haskey(data, branch) || continue
            d = data[branch]
            times = d[:times]
            peaks = get(d, :peak_density, Float64[])
            norms = get(d, :norms, Float64[])
            Fz    = get(d, :Fz, Float64[])
            Fx    = get(d, :Fx, Float64[])
            Fy    = get(d, :Fy, Float64[])
            Lz    = get(d, :Lz, Float64[])
            for (i, t) in enumerate(times)
                row = String[
                    branch,
                    string(i),
                    @sprintf("%.6f", t),
                    i <= length(norms) ? @sprintf("%.6e", norms[i]) : "",
                    i <= length(peaks) ? @sprintf("%.6e", peaks[i]) : "",
                    i <= length(Fz)    ? @sprintf("%.6e", Fz[i])    : "",
                    i <= length(Fx)    ? @sprintf("%.6e", Fx[i])    : "",
                    i <= length(Fy)    ? @sprintf("%.6e", Fy[i])    : "",
                    i <= length(Lz)    ? @sprintf("%.6e", Lz[i])    : "",
                ]
                println(io, join(row, ","))
            end
        end
    end
    csv_path
end

const PY_RENDERER = """
#!/usr/bin/env python3
\"\"\"Render EdH × K_3 A/B comparison from `edh_k3_compare.csv`.

Four-panel comparison:
  (a) total norm vs t           — K_3 atom-number decay signature
  (b) peak density vs t         — K_3 collapse mitigation
  (c) F_z, L_z vs t             — EdH angular-momentum transfer (should
                                   match between branches at early time;
                                   K_3 is local so doesn't affect transfer
                                   until density spikes diverge)
  (d) F_z + L_z conservation    — EdH check (should be flat)
\"\"\"
import csv
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "edh_k3_compare.csv")
BASE = os.path.join(HERE, "edh_k3_compare")

def load(csv_path):
    data = defaultdict(lambda: defaultdict(list))
    with open(csv_path) as f:
        for r in csv.DictReader(f):
            b = r["branch"]
            for k, v in r.items():
                if k in ("branch", "frame"): continue
                try:
                    data[b][k].append(float(v))
                except ValueError:
                    data[b][k].append(np.nan)
    return data

def main():
    data = load(CSV)
    branches = list(data.keys())
    colors = {"baseline_no_K3": "C0", "K3_dy_like": "C3"}

    fig, axes = plt.subplots(2, 2, figsize=(11, 7), sharex=True)

    for b in branches:
        d = data[b]
        t = np.array(d["t"])
        c = colors.get(b, "k")
        axes[0, 0].plot(t, d["norm"], "-", color=c, label=b, lw=1.5)
        axes[0, 1].plot(t, d["peak_density"], "-", color=c, label=b, lw=1.5)
        axes[1, 0].plot(t, d["Fz"], "-", color=c, label=f"{b} F_z", lw=1.5)
        if any(np.isfinite(d.get("Lz", [np.nan]))):
            axes[1, 0].plot(t, d["Lz"], "--", color=c, label=f"{b} L_z", lw=1.5)
        Fz = np.array(d["Fz"])
        Lz = np.array(d.get("Lz", np.full_like(Fz, np.nan)))
        if np.all(np.isfinite(Lz)):
            axes[1, 1].plot(t, Fz + Lz, "-", color=c, label=b, lw=1.5)

    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number conservation")
    axes[0, 0].grid(alpha=0.3); axes[0, 0].legend(fontsize=9)

    axes[0, 1].set_ylabel(r"max \$n_{\\rm tot}\$ (a.u.)")
    axes[0, 1].set_title("(b) peak density")
    axes[0, 1].set_yscale("log")
    axes[0, 1].grid(alpha=0.3, which="both"); axes[0, 1].legend(fontsize=9)

    axes[1, 0].set_xlabel(r"\$t\$ (\$\\omega_{\\rm ref}^{-1}\$)")
    axes[1, 0].set_ylabel(r"\$\\langle F_z \\rangle\$, \$\\langle L_z \\rangle\$")
    axes[1, 0].set_title("(c) EdH transfer: spin → orbital")
    axes[1, 0].grid(alpha=0.3); axes[1, 0].legend(fontsize=8)

    axes[1, 1].set_xlabel(r"\$t\$ (\$\\omega_{\\rm ref}^{-1}\$)")
    axes[1, 1].set_ylabel(r"\$\\langle F_z + L_z \\rangle\$")
    axes[1, 1].set_title("(d) total angular momentum (should be ≈ const)")
    axes[1, 1].grid(alpha=0.3); axes[1, 1].legend(fontsize=9)

    fig.suptitle(
        "Eu151 EdH × K_3 three-body loss (32³, phase 2 = 0.3 ω⁻¹ ≈ 0.43 ms)",
        fontsize=11)
    plt.tight_layout()
    plt.savefig(BASE + ".pdf", bbox_inches="tight")
    plt.savefig(BASE + ".png", bbox_inches="tight", dpi=180)
    plt.savefig(BASE + ".svg", bbox_inches="tight")
    print(f"Wrote {BASE}.{{pdf,png,svg}}")

if __name__ == "__main__":
    main()
"""

function _diagnose_jld2(run_dir::String)
    println("== JLD2 contents of each branch result file ==")
    for branch in BRANCHES
        path = joinpath(run_dir, "point_001_$(branch).jld2")
        isfile(path) || (println("  $branch: MISSING ($path)"); continue)
        println("  $branch ($(round(filesize(path) / 1e6; digits=1)) MB):")
        JLD2.jldopen(path, "r") do f
            haskey(f, "dynamics") || (println("    no dynamics/ group"); return)
            for k in sort(collect(keys(f["dynamics"])))
                v = f["dynamics/" * k]
                if v isa AbstractArray
                    @printf("    dynamics/%-30s :: %s %s\n", k, typeof(v), size(v))
                else
                    @printf("    dynamics/%-30s :: %s\n", k, typeof(v))
                end
            end
        end
    end
end

function main(args)
    if length(args) == 1 && args[1] == "--help"
        println("usage: julia compare_edh_k3.jl <run_dir> [--diagnose]")
        return
    end
    isempty(args) && error(
        "usage: julia compare_edh_k3.jl <run_dir> [--diagnose]\n" *
        "  --diagnose prints the JLD2 contents of each branch (debug aid)")
    run_dir = args[1]
    if length(args) >= 2 && args[2] == "--diagnose"
        _diagnose_jld2(run_dir)
        return
    end

    println("Reading branches from $run_dir...")
    data = compare_branches(run_dir)
    println("Found branches: ", collect(keys(data)))
    # Report what's available per branch so the user knows which panels will
    # render (and which will need new save wiring or longer runs).
    for branch in BRANCHES
        haskey(data, branch) || continue
        present = sort(string.(collect(keys(data[branch]))))
        println("  $branch: ", join(present, ", "))
    end
    csv_path = _emit_csv(data, run_dir)
    py_path = joinpath(run_dir, "edh_k3_compare.py")
    open(py_path, "w") do io
        write(io, PY_RENDERER)
    end
    println("Wrote $csv_path")
    println("Wrote $py_path")
    println()
    println("Build figure: python3 $py_path")
    println("Diagnose:     julia $(@__FILE__) $run_dir --diagnose")
end

main(ARGS)
