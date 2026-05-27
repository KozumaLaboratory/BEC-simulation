#!/usr/bin/env julia
#
# eu_robust_factorial_summary.jl — scan runs/eu_robust_factorial/* output
# directories, extract per-cell observables, and print the robustness
# summary table.
#
# Reads from each `result.jld2` (or `point_001.jld2` fallback):
#   - psi_final (last snapshot)
#   - normsq_final / normsq_initial
#   - energy decomposition (if persisted)
# Computes:
#   - N_ratio       = ∫|ψ_final|² / ∫|ψ_initial|²
#   - Fz_final      = ⟨F_z⟩ at t = T_end
#   - peak_density  = max(|ψ_final|²) summed over components
#   - winding       = winding number of m=−F component (proxy for texture)
#
# Writes:
#   - stdout: table
#   - runs/eu_robust_factorial/summary.json
#
# Acceptance: see runs/eu_robust_factorial/README.md → "Acceptance for
# robust" for tolerance bands per observable.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "eu_robust_factorial")

# Find the hashed output dir for each `K?_gdr?_LHY?.yaml` config —
# run_yaml creates `runs/<base>_<hash>/` at the top of runs/, NOT
# adjacent to the YAML file (cf. `runs/K0_gdr0_LHY0_a5478a08/`).
function _find_output_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    runs_root = joinpath(@__DIR__, "..", "..", "runs")
    candidates = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), base * "_") || continue
        isfile(joinpath(d, "result.jld2")) || isfile(joinpath(d, "point_001.jld2")) ||
            continue
        push!(candidates, d)
    end
    isempty(candidates) && return nothing
    sort!(candidates; by=d -> mtime(d))   # newest by mtime
    last(candidates)
end

function _read_obs(jld_path::String)
    # result.jld2 stores: top-level `psi` (final spinor) + `dynamics/`
    # group with `times`, `norms`, `Fz`, `component_populations`,
    # `psi_snapshots_streamed`. We pull final ψ from top-level and the
    # trajectory scalars from dynamics/ directly.
    f = jldopen(jld_path, "r")
    psi = try
        f["psi"]
    catch
        nothing
    end
    times = try
        f["dynamics/times"]
    catch
        Float64[]
    end
    norms = try
        f["dynamics/norms"]
    catch
        Float64[]
    end
    Fz_traj = try
        f["dynamics/Fz"]
    catch
        Float64[]
    end
    close(f)
    (psi=psi,
        t_end=isempty(times) ? nothing : times[end],
        norm_final=isempty(norms) ? nothing : norms[end],
        norm_initial=isempty(norms) ? nothing : norms[1],
        Fz_final=isempty(Fz_traj) ? nothing : Fz_traj[end])
end

function _compute_observables(yaml_path::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (status="MISSING", outdir=nothing)

    res_path = isfile(joinpath(outdir, "result.jld2")) ?
        joinpath(outdir, "result.jld2") :
        joinpath(outdir, "point_001.jld2")
    obs = try
        _read_obs(res_path)
    catch e
        return (status="UNREADABLE", outdir=outdir, error=string(e))
    end

    psi = obs.psi
    psi === nothing && return (status="NO_PSI", outdir=outdir)

    ndim = ndims(psi) - 1
    n_total = SpinorBEC.total_density(psi, ndim)
    peak_density = maximum(n_total)

    # Prefer the persisted Fz / norm trajectories — they are dV-weighted
    # integrals at run time, so we don't have to reconstruct dV from
    # the un-saved grid.
    Fz_per_atom = obs.Fz_final !== nothing && obs.norm_final !== nothing &&
                  obs.norm_final > 1e-30 ?
        obs.Fz_final / obs.norm_final : NaN

    norm_ratio = obs.norm_initial !== nothing && obs.norm_final !== nothing &&
                 obs.norm_initial > 1e-30 ?
        obs.norm_final / obs.norm_initial : NaN

    (status="OK",
        outdir=outdir,
        peak_density=peak_density,
        norm_ratio=norm_ratio,
        Fz_per_atom=Fz_per_atom,
        t_end=obs.t_end)
end

function main()
    yamls = sort(filter(endswith(".yaml"),
        readdir(ROOT; join=true)))
    println("# Eu robust factorial summary")
    println("# Source: $ROOT")
    println("# Observables: Fz_per_atom (⟨F_z⟩/N) / norm_ratio (N(T)/N(0)) / peak_density")
    println()
    @printf("%-22s %-9s %-4s %-4s %-4s %-14s %-12s %-12s\n",
        "config", "status", "K3", "gdr", "LHY", "Fz/N", "norm_ratio", "peak_density")
    println(repeat("-", 90))

    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        K3 = occursin("K1_", base) ? "on" : "off"
        gdr = occursin("_gdr1_", base) ? "on" : "off"
        lhy = occursin("_LHY1", base) ? "on" : "off"
        obs = _compute_observables(y)
        if obs.status === "OK"
            @printf("%-22s %-9s %-4s %-4s %-4s %-+14.6e %-12.6e %-12.4e\n",
                base, "OK", K3, gdr, lhy,
                obs.Fz_per_atom, obs.norm_ratio, obs.peak_density)
        else
            @printf("%-22s %-9s %-4s %-4s %-4s %-14s %-12s %-12s\n",
                base, obs.status, K3, gdr, lhy, "-", "-", "-")
        end
        push!(rows, (config=base, K3=K3, gdr=gdr, lhy=lhy, obs=obs))
    end

    summary_path = joinpath(ROOT, "summary.json")
    open(summary_path, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("config" => r.config,
                "K3" => r.K3,
                "gdr" => r.gdr,
                "lhy" => r.lhy,
                "status" => string(r.obs.status),
                "Fz_per_atom" => r.obs.status === "OK" ? r.obs.Fz_per_atom : nothing,
                "norm_ratio" => r.obs.status === "OK" ? r.obs.norm_ratio : nothing,
                "peak_density" => r.obs.status === "OK" ? r.obs.peak_density : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $summary_path")
end

main()
