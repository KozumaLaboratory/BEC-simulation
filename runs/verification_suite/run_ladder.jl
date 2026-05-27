# Batch-run the validation ladder YAMLs in a single Julia process.
# Shares JIT cascade cost across all runs (CLAUDE.md §Type-stability cascade —
# `using SpinorBEC` + first `make_workspace` ~4-5 min). Subsequent same-shape
# workspaces are cache-fast.
#
# Usage:
#   julia --project=. runs/verification_suite/run_ladder.jl [--level N]
#       --level 0   run only Level 0/1 (original 00-09)
#       --level 2   run only L2_* (DDI kernel)
#       --level 3   run only L3_* (Cr F=3 EdH toy)
#       --level 4   run only L4_* (Eu Hamiltonian-only)
#       no flag     run all
#
# Per-run timing + status written to runs/verification_suite/outputs/ladder_log.json.
# Stop-on-first-fail is OFF by default — collect all failures.

using SpinorBEC, JSON

const YAMLS_DIR = "runs/verification_suite/yamls"
const OUTPUTS_DIR = "runs/verification_suite/outputs"
mkpath(OUTPUTS_DIR)

# Parse optional --level filter
level_filter = nothing
for (i, a) in enumerate(ARGS)
    if a == "--level" && i < length(ARGS)
        global level_filter = parse(Int, ARGS[i + 1])
    end
end

# Collect YAMLs
all_files = sort(readdir(YAMLS_DIR; join=true))
all_files = filter(f -> endswith(f, ".yaml"), all_files)

# Filter by level
function level_of(path::String)
    name = basename(path)
    if startswith(name, "L2_")
        return 2
    elseif startswith(name, "L3_")
        return 3
    elseif startswith(name, "L4_")
        return 4
    else
        return 1   # original 00-09 are Level 0/1
    end
end

files = level_filter === nothing ? all_files :
    filter(f -> level_of(f) == level_filter, all_files)

if isempty(files)
    println("No YAMLs match level $level_filter")
    exit(1)
end

println("Running $(length(files)) YAMLs:")
for f in files
    println("  L$(level_of(f)) $(basename(f))")
end
println()

results = Dict{String, Any}()
total_t0 = time()

for f in files
    name = basename(f)
    println("\n=== $(name) ===")
    t0 = time()
    try
        run_yaml(f)
        dt = time() - t0
        results[name] = Dict(
            "status" => "OK",
            "elapsed_sec" => round(dt; digits=2),
            "level" => level_of(f),
        )
        println("  PASS in $(round(dt; digits=2))s")
    catch e
        dt = time() - t0
        emsg = sprint(showerror, e)[1:min(400, end)]
        results[name] = Dict(
            "status" => "FAIL",
            "elapsed_sec" => round(dt; digits=2),
            "level" => level_of(f),
            "error" => emsg,
        )
        println("  FAIL in $(round(dt; digits=2))s: $emsg")
    end
end

total = time() - total_t0
results["_total_sec"] = round(total; digits=2)
results["_n_yamls"] = length(files)
results["_level_filter"] = level_filter

log_name = level_filter === nothing ? "ladder_log_all.json" : "ladder_log_L$(level_filter).json"
open(joinpath(OUTPUTS_DIR, log_name), "w") do io
    JSON.print(io, results, 2)
end

println("\n" * "="^60)
println("TOTAL: $(round(total; digits=2))s ($(length(files)) YAMLs)")
println("="^60)

n_pass = count(r -> r isa Dict && get(r, "status", "") == "OK", values(results))
n_fail = count(r -> r isa Dict && get(r, "status", "") == "FAIL", values(results))
println("PASS: $n_pass")
println("FAIL: $n_fail")
println()
for f in sort(collect(keys(results)))
    startswith(f, "_") && continue
    r = results[f]
    marker = r["status"] == "OK" ? "✓" : "✗"
    println("  $marker L$(r["level"]) $f: $(r["status"]) ($(r["elapsed_sec"])s)")
end

exit(n_fail == 0 ? 0 : 1)
