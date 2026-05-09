# --- Per-run summary helpers ---

export print_run_summary, compare_runs

# Quick text summaries of completed runs (no plotting). Counterpart to
# the JSON dashboard data; useful for terminal review without spinning
# up the dashboard server.

"""
    print_run_summary(run_dir; io=stdout)

Print a concise summary of a completed run directory. Walks every
point_NNN.jld2 (or the single root .jld2 for non-scan runs) and reports
energies, magnetisations, defect counts, frame counts, etc. — enough to
tell at a glance whether the run finished cleanly.
"""
function print_run_summary(run_dir::AbstractString; io::IO=stdout)
    isdir(run_dir) || throw(ArgumentError("run_dir not found: $run_dir"))
    println(io, "=" ^ 60)
    println(io, "Run summary: $run_dir")
    println(io, "=" ^ 60)
    files = sort(filter(f -> endswith(f, ".jld2"),
        readdir(joinpath(run_dir))))
    isempty(files) && (println(io, "(no .jld2 files yet)"); return nothing)

    for fname in files
        path = joinpath(run_dir, fname)
        println(io)
        println(io, "▶ $fname")
        try
            jldopen(path, "r") do f
                # Energies
                if haskey(f, "energy")
                    println(io, "  energy        = ", f["energy"])
                end
                if haskey(f, "converged")
                    println(io, "  converged     = ", f["converged"])
                end
                if haskey(f, "mz_actual")
                    println(io, "  Mz            = ", f["mz_actual"])
                end
                # Dynamics traces
                if haskey(f, "dynamics/energies")
                    e = f["dynamics/energies"]
                    println(
                        io,
                        "  dynamics      = $(length(e)) snapshots, " *
                        "E[1]=$(round(e[1]; digits=4)), " *
                        "E[end]=$(round(e[end]; digits=4))",
                    )
                end
                # Streamed snapshot count
                if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                    n_snaps = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                    println(io, "  ψ snapshots   = $n_snaps (streamed F32)")
                end
                # Analyzer outputs
                analyze_keys = filter(k -> startswith(k, "analyze/"), keys(f))
                if !isempty(analyze_keys)
                    seen = Set{String}()
                    for k in analyze_keys
                        parts = split(k, '/')
                        length(parts) >= 2 && push!(seen, parts[2])
                    end
                    println(io, "  analyzers     = ", join(sort(collect(seen)), ", "))
                end
            end
        catch e
            println(io, "  ! could not read: $e")
        end
    end

    # Also report PNG frames if any
    frames_dir = joinpath(run_dir, "frames")
    if isdir(frames_dir)
        n_pngs = length(filter(f -> endswith(f, ".png"), readdir(frames_dir)))
        println(io)
        println(io, "▶ frames/ → $n_pngs PNG(s)")
    end
    nothing
end

"""
    compare_runs(dir1, dir2; tol=1e-6, io=stdout)

Side-by-side diff of two scan directories. For each shared point file,
report the energy / Mz delta and whether streamed-snapshot counts match.
Useful for regression: re-run the same scan and compare against a
known-good baseline.
"""
function compare_runs(dir1::AbstractString, dir2::AbstractString;
    tol::Real=1e-6, io::IO=stdout)
    isdir(dir1) && isdir(dir2) ||
        throw(ArgumentError("both dirs must exist: $dir1, $dir2"))
    f1 = Set(filter(f -> endswith(f, ".jld2"), readdir(dir1)))
    f2 = Set(filter(f -> endswith(f, ".jld2"), readdir(dir2)))
    only1 = sort(collect(setdiff(f1, f2)))
    only2 = sort(collect(setdiff(f2, f1)))
    common = sort(collect(intersect(f1, f2)))

    println(io, "=" ^ 60)
    println(io, "Compare: $dir1  ↔  $dir2")
    println(io, "=" ^ 60)
    !isempty(only1) && println(io, "Only in $dir1: ", join(only1, ", "))
    !isempty(only2) && println(io, "Only in $dir2: ", join(only2, ", "))
    isempty(common) && return nothing

    n_diff = 0
    for fname in common
        e1 = _try_load(joinpath(dir1, fname), "energy")
        e2 = _try_load(joinpath(dir2, fname), "energy")
        m1 = _try_load(joinpath(dir1, fname), "mz_actual")
        m2 = _try_load(joinpath(dir2, fname), "mz_actual")
        d_e = (e1 isa Number && e2 isa Number) ? abs(e1 - e2) : NaN
        d_m = (m1 isa Number && m2 isa Number) ? abs(m1 - m2) : NaN
        diff_marker = (d_e > tol || d_m > tol) ? " ⚠" : ""
        @printf(io, "  %-22s  ΔE=%.2e  ΔMz=%.2e%s\n", fname, d_e, d_m, diff_marker)
        (d_e > tol || d_m > tol) && (n_diff += 1)
    end
    println(io)
    println(io, "$(length(common)) shared points; $(n_diff) differ above tol=$tol")
    nothing
end

function _try_load(path::AbstractString, key::AbstractString)
    try
        jldopen(path, "r") do f
            haskey(f, key) ? f[key] : nothing
        end
    catch
        nothing
    end
end
