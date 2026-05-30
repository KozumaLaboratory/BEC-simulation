export estimate_run_budget

"""
    estimate_run_budget(yaml_path::AbstractString) -> BudgetReport

Parse a pipeline YAML and estimate VRAM, host memory, and disk usage.
Prints a short summary to stdout and returns a named tuple with the raw
numbers so callers can programmatically check whether a run will fit.

Covers:
  - ψ footprint per component dtype (ComplexF64 / ComplexF32)
  - Workspace buffer overhead during split-step (~5 × ψ)
  - DDI padded FFT workspace (~2 × ψ)
  - psi_snapshots buffer count × size when save.psi is true
  - Final JLD2 disk footprint, with/without zlib compression estimate

Not a tight upper bound — CUDA fragmentation, analyzer passes, and
per-snapshot temporaries can add 10–20 %, so plan for headroom.
"""
function estimate_run_budget(yaml_path::AbstractString; io::IO=stdout)
    data = YAML.load_file(String(yaml_path))
    pipeline = get(data, "pipeline", Any[])
    isempty(pipeline) &&
        throw(ArgumentError("No pipeline in $yaml_path"))

    # Grid and component count come from the first ground_state step.
    gs = _first_step_of_kind(pipeline, "ground_state")
    gs === nothing &&
        throw(ArgumentError("No ground_state step — can't infer grid"))
    grid_raw = get(gs, "grid", nothing)
    grid_raw === nothing &&
        throw(ArgumentError("ground_state step has no `grid` entry"))
    n_pts_raw = grid_raw["n"]
    n_pts = NTuple{length(n_pts_raw), Int}(Int.(n_pts_raw))
    box_raw = get(grid_raw, "box", get(grid_raw, "box_size", nothing))

    atom_name = get(gs, "atom", "Eu151")
    F_map = Dict("Na23" => 1, "Rb87" => 1, "Cr52" => 3, "Dy164" => 8, "Eu151" => 6)
    F = get(F_map, atom_name, 6)
    D = 2F + 1

    N_voxels = prod(n_pts)
    psi_f64_bytes = 16 * N_voxels * D
    psi_f32_bytes = 8 * N_voxels * D

    # Walk all dynamics steps to total up snapshot footprint + step counts.
    total_steps = 0
    total_snapshots = 0
    save_psi = false
    save_compressed = false
    for step in pipeline
        step isa Dict || continue
        haskey(step, "dynamics") || continue
        p = step["dynamics"]
        dur = Float64(get(p, "duration", 0.0))
        dt = Float64(get(p, "dt", 1.0))
        every = Int(get(p, "save_every", 1))
        n_steps = round(Int, dur / dt)
        total_steps += n_steps
        total_snapshots += max(1, n_steps ÷ every)
        save_block = get(p, "save", Dict{Any, Any}())
        save_psi |= Bool(get(save_block, "psi", false))
        save_compressed |= Bool(get(p, "save_snapshot_compression", false))
    end

    # Scan multiplier. Each scan point re-runs the whole pipeline.
    scan_points = 1
    if haskey(data, "scan")
        scan = data["scan"]
        prod_dict = get(scan, "product", Dict())
        zip_dict = get(scan, "zip", Dict())
        prod_n = isempty(prod_dict) ? 1 :
                 prod(length(v) for v in values(prod_dict))
        zip_n = isempty(zip_dict) ? 1 : length(first(values(zip_dict)))
        scan_points = max(prod_n, 1) * (isempty(zip_dict) ? 1 : zip_n)
    end

    snap_bytes_per = psi_f32_bytes
    snap_disk_per_run = save_psi ? snap_bytes_per * total_snapshots : 0
    snap_ram_streamed = save_psi ? snap_bytes_per : 0
    snap_ram_accumulated = save_psi ? snap_bytes_per * total_snapshots : 0

    vram_est = psi_f64_bytes * 8          # ψ + ~5× buffers + ~2× DDI pad
    # Host RAM during dynamics: with callback-streamed snapshots the
    # previous 1×psi_F64×n_snaps accumulation collapses to a single
    # ComplexF32 buffer (~26 MB at 64³×13). The +1×F64 below covers the
    # live psi copy on the host after the sim completes.
    host_ram_est = psi_f64_bytes + snap_ram_streamed

    compression_ratio = save_compressed ? 2.5 : 1.0
    disk_per_run = psi_f64_bytes +        # final psi
                   snap_disk_per_run      # snapshots
    disk_total = (disk_per_run / compression_ratio) * scan_points

    _fmt(b) =
        if b < 1024
            @sprintf("%d B", b)
        elseif b < 1 << 20
            @sprintf("%.1f KB", b / 1024)
        elseif b < 1 << 30
            @sprintf("%.1f MB", b / 2^20)
        else
            @sprintf("%.2f GB", b / 2^30)
        end

    println(io, "── Run budget estimate: $(basename(yaml_path)) ──")
    println(io, "  grid:         $(n_pts)   box: $(box_raw)")
    println(io, "  atom / F:     $(atom_name)  (F=$F, D=$D components)")
    println(io, "  scan points:  $(scan_points)")
    println(io, "  dynamics:     $(total_steps) steps total, $(total_snapshots) snapshots")
    println(io, "  ψ:            $(_fmt(psi_f64_bytes))  (ComplexF64 per-instance)")
    println(io, "  VRAM est:     $(_fmt(vram_est))       (8 × ψ; tighten below on small grids)")
    println(io, "  host RAM est: $(_fmt(host_ram_est))   (ψ + dr.psi_snapshots buffer)")
    if save_psi
        print(io, "  snapshot I/O: ")
        println(io, "$(_fmt(snap_bytes_per))/frame  → streamed ~$(_fmt(snap_ram_streamed)) peak")
    end
    println(
        io,
        "  disk / run:   $(_fmt(disk_per_run / compression_ratio))   " *
        "(compression: $(save_compressed ? "zlib ~2.5×" : "none"))",
    )
    println(io, "  disk total:   $(_fmt(disk_total))   (× $(scan_points) scan points)")
    if vram_est > 16 * 2^30
        println(io, "  ⚠ VRAM > 16 GB — needs H100 or mixed-precision rewrite")
    end
    if host_ram_est > 32 * 2^30
        println(io, "  ⚠ Host RAM > 32 GB — consider smaller grid or fewer snapshots")
    end

    return (;
        n_pts,
        F,
        D,
        scan_points,
        total_steps,
        total_snapshots,
        psi_bytes_f64=psi_f64_bytes,
        psi_bytes_f32=psi_f32_bytes,
        vram_est,
        host_ram_est,
        snap_bytes_per,
        snap_ram_streamed,
        snap_ram_accumulated,
        disk_per_run,
        disk_total,
        save_psi,
        save_compressed,
    )
end

function _first_step_of_kind(pipeline::Vector, kind::String)
    for step in pipeline
        step isa Dict || continue
        haskey(step, kind) && return step[kind]
    end
    return nothing
end

# --- Cluster sizing ---------------------------------------------------

export scan_point_count

"""
    scan_point_count(yaml_path) -> Int

Count the scan points implied by a config YAML. Multiplies
`length(scan.points) × length(scan.comparison_runs)` when both are
present. Returns 1 for non-scan configs. Used to size array jobs.
"""
function scan_point_count(yaml_path::AbstractString)
    data = YAML.load_file(String(yaml_path))
    haskey(data, "scan") || return 1
    scan = _parse_override_scan(data["scan"])
    n_pts = length(scan.points)
    n_cmp = max(1, length(scan.comparison_runs))
    n_pts * n_cmp
end

# --- Backend / dtype recommendation ----------------------------------
#
# Empirical lookup table for `split_step_combined!` / `split_step!` on
# Eu-class systems (D=13, F=6). Numbers measured 2026-05-10 on
# RTX 5070 Ti with Julia 1.12.6, see scripts/bench/backend_grid_scan.jl
# for the reproducible benchmark.
#
#   N          CPU F64   CPU F32   GPU F64   GPU F32        winner
#   16³          3237      3607      2450      2877    GPU F64 (1.13×)
#   24³         11368     12277      3195      2629    GPU F32 (4.32×)
#   32³         28735     29290      3835      2546    GPU F32 (11.3×)
#   48³         99225     97608      8428      3041    GPU F32 (32.6×)
#                                                      [µs / split_step]
#
# CPU F32 is uniformly worse than CPU F64 (libm scalar trig + no
# memory-bandwidth gain at these grid sizes). GPU F32 wins above ~16³
# both vs CPU and vs GPU F64.

export recommend_backend_dtype

"""
    recommend_backend_dtype(n_max; cuda_functional, ndim=3, mode=:realtime)
        → (backend_kind::Symbol, dtype::DataType)

Given the largest spatial dimension `n_max` of the planned grid (cubic
or otherwise — pass the max), return the empirically-optimal backend
and float type for `split_step!` / `split_step_combined!`.

# Arguments

* `n_max` — largest grid dimension (e.g. 32 for a 32³ run).
* `cuda_functional` — whether `CUDA.functional()` is true. The caller
  is responsible for checking; this function does not import CUDA.
* `ndim` — spatial dimensionality (1, 2, or 3). 1D/2D stay on CPU
  regardless of size — kernel-launch overhead dominates and several
  analyzer paths lack a GPU specialization.
* `mode` — physics regime. `:realtime` (≤ a few hundred ms) tolerates
  Float32 on GPU. `:itp` (imaginary-time ground state) and
  `:longtime` (≫ 1 s propagation, phase accumulation matters) force
  Float64 even on GPU.

# Returns

Tuple `(backend_kind, dtype)` where `backend_kind ∈ (:cpu, :cuda)`
and `dtype ∈ (Float32, Float64)`.

Recommendation table (3D, GPU available):

| `n_max` | `:realtime` | `:itp` / `:longtime` |
|---------|-------------|----------------------|
| ≤ 16    | (cpu, F64)  | (cpu, F64)           |
| ≥ 24    | (cuda, F32) | (cuda, F64)          |

When `cuda_functional=false`, `ndim < 3`, or `n_max ≤ 16` we always
return `(:cpu, Float64)` — CPU F32 is slower than CPU F64 at every
measured size on the lab path.

`make_workspace(; backend=nothing)` (the default) applies the same
threshold automatically; this function is the explicit form when you
want to inspect or branch on the recommendation.
"""
function recommend_backend_dtype(
    n_max::Int;
    cuda_functional::Bool,
    ndim::Int=3,
    mode::Symbol=:realtime,
)
    n_max > 0 || throw(ArgumentError("n_max must be positive, got $n_max"))
    ndim in (1, 2, 3) || throw(ArgumentError("ndim must be 1, 2, or 3 — got $ndim"))
    mode in (:realtime, :itp, :longtime) || throw(ArgumentError(
        "mode must be :realtime, :itp, or :longtime — got $mode"))

    if !cuda_functional || n_max <= 16 || ndim != 3
        return (:cpu, Float64)
    end
    if mode === :realtime
        return (:cuda, Float32)
    else
        return (:cuda, Float64)
    end
end
