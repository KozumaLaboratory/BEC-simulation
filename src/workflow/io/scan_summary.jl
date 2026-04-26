# --- Scan result aggregation ---
#
# Walk a run directory, load all point_*.jld2 metadata, and produce
# a summary table for quick comparison. No need to load full psi arrays.

"""
    scan_summary(run_dir) → Vector{NamedTuple}

Collect metadata from all point_*.jld2 files in `run_dir`.
Returns a vector of named tuples sorted by (scan_index, run_name).
"""
function scan_summary(run_dir::String)
    isdir(run_dir) || throw(ArgumentError("Run directory not found: $run_dir"))
    files = sort(filter(f -> startswith(f, "point_") && endswith(f, ".jld2"), readdir(run_dir)))
    isempty(files) && return NamedTuple[]

    rows = NamedTuple[]
    for f in files
        path = joinpath(run_dir, f)
        d = JLD2.load(path)
        push!(
            rows,
            (
                file=f,
                scan_index=get(d, "scan_index", 0),
                run_name=get(d, "run_name", ""),
                energy=Float64(get(d, "energy", NaN)),
                converged=Bool(get(d, "converged", false)),
                mz_actual=Float64(get(d, "mz_actual", NaN)),
                duration_s=Float64(get(d, "duration_seconds", NaN)),
                override=get(d, "override", Dict()),
            ),
        )
    end
    sort!(rows; by=r -> (r.scan_index, r.run_name))
    rows
end

"""
    scan_energy_comparison(run_dir) → Vector{NamedTuple}

Compare energies between comparison_runs at each scan point.
Returns ΔE for each pair of run names at each scan index.
"""
function scan_energy_comparison(run_dir::String)
    summary = scan_summary(run_dir)
    isempty(summary) && return NamedTuple[]

    indices = unique(r.scan_index for r in summary)
    comparisons = NamedTuple[]

    for idx in indices
        runs = filter(r -> r.scan_index == idx, summary)
        length(runs) < 2 && continue

        e_dict = Dict(r.run_name => r.energy for r in runs)
        names = sort(collect(keys(e_dict)))

        for i in 1:length(names), j in (i + 1):length(names)
            push!(
                comparisons,
                (
                    scan_index=idx,
                    run_a=names[i],
                    run_b=names[j],
                    E_a=e_dict[names[i]],
                    E_b=e_dict[names[j]],
                    ΔE=e_dict[names[i]] - e_dict[names[j]],
                    winner=e_dict[names[i]] < e_dict[names[j]] ? names[i] : names[j],
                ),
            )
        end
    end
    comparisons
end

"""
    print_scan_summary(run_dir; io=stdout)

Pretty-print scan results to the terminal.
"""
function print_scan_summary(run_dir::String; io::IO=stdout)
    summary = scan_summary(run_dir)
    isempty(summary) && (println(io, "No results found in $run_dir"); return nothing)

    println(io, "── Scan Summary: $(basename(run_dir)) ──")
    println(
        io,
        "  $(length(summary)) results from $(length(unique(r.scan_index for r in summary))) scan points",
    )
    println(io)

    # Group by scan_index
    for idx in unique(r.scan_index for r in summary)
        runs = filter(r -> r.scan_index == idx, summary)
        println(io, "  Point $idx:")
        for r in runs
            label = isempty(r.run_name) ? "default" : r.run_name
            conv_mark = r.converged ? "✓" : "×"
            println(
                io,
                "    $(rpad(label, 20)) E=$(lpad(string(round(r.energy; sigdigits=8)), 14))  " *
                "Mz=$(lpad(string(round(r.mz_actual; digits=2)), 6))  " *
                "$(conv_mark)  $(round(r.duration_s; digits=0))s",
            )
        end
    end

    # Energy comparison
    comps = scan_energy_comparison(run_dir)
    if !isempty(comps)
        println(io, "\n── Energy Comparison ──")
        for c in comps
            arrow = c.ΔE > 0 ? "$(c.run_b) wins" : "$(c.run_a) wins"
            println(
                io,
                "  Point $(c.scan_index): ΔE($(c.run_a)−$(c.run_b)) = $(round(c.ΔE; sigdigits=4))  → $arrow",
            )
        end
    end
end
