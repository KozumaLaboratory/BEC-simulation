# Helpers for preparing SLURM submissions.
#
# Usage:
#   julia --project=. scripts/slurm_helpers.jl count <config.yaml>
#   julia --project=. scripts/slurm_helpers.jl budget <config.yaml>
#   julia --project=. scripts/slurm_helpers.jl sbatch-suggest <config.yaml>

using SpinorBEC
using YAML
using Printf

function _scan_point_count(yaml_path::String)
    data = YAML.load_file(yaml_path)
    haskey(data, "scan") || return 1
    scan = SpinorBEC._parse_override_scan(data["scan"])
    has_comparison = !isempty(scan.comparison_runs)
    npts = length(scan.points)
    nrun = has_comparison ? length(scan.comparison_runs) : 1
    npts * nrun
end

function _suggest_sbatch(yaml_path::String)
    data = YAML.load_file(yaml_path)
    n_pts = _scan_point_count(yaml_path)

    # Heuristic: 64³ Eu151 ITP + dynamics ≈ 5 min/pt on H100.
    # Refine later by reading grid + n_steps.
    grid_node = haskey(data, "pipeline") && !isempty(data["pipeline"]) ?
                first(values(data["pipeline"][1])) : Dict()
    n_pts_grid = haskey(grid_node, "grid") ?
                 prod(Int.(grid_node["grid"]["n"])) : 64^3
    minutes_per_pt = max(1, round(Int, 5 * (n_pts_grid / 64^3)))

    # Total wall-clock for serial scan
    total_min = minutes_per_pt * n_pts
    safety = 1.5      # 50% headroom
    total_min = ceil(Int, total_min * safety)
    hours, mins = divrem(total_min, 60)

    # VRAM rule of thumb: 8× ψ_F64 + DDI + LHY tables
    vram_gb = max(2, ceil(Int, 8 * 16 * n_pts_grid * 13 / 2^30 + 2))
    mem_gb = max(32, vram_gb * 2)

    println("# Suggested SLURM flags for $yaml_path")
    println("# scan points: $n_pts  ;  grid: $n_pts_grid")
    @printf "#SBATCH --time=%02d:%02d:00\n" hours mins
    @printf "#SBATCH --gres=gpu:h100:1\n"
    @printf "#SBATCH --cpus-per-task=8\n"
    @printf "#SBATCH --mem=%dG\n" mem_gb
    println("#")
    println("# For an array job (parallel scan): add")
    @printf "#SBATCH --array=1-%d%%4   # 4 in flight at once\n" n_pts
    println("# and submit with scripts/slurm/scan_array.sbatch")
end

function main()
    if length(ARGS) < 2
        println("usage: julia $(@__FILE__) <count|budget|sbatch-suggest> <config.yaml>")
        exit(1)
    end
    cmd, path = ARGS[1], ARGS[2]
    if cmd == "count"
        println(_scan_point_count(path))
    elseif cmd == "budget"
        estimate_run_budget(path)
    elseif cmd == "sbatch-suggest"
        _suggest_sbatch(path)
    else
        println("unknown command: $cmd"); exit(1)
    end
end

main()
