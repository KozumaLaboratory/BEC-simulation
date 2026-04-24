"""
    estimate_run_budget(yaml_path::AbstractString) -> BudgetReport

Parse a pipeline YAML and estimate VRAM, host memory, and disk usage.
Prints a short summary to stdout and returns a named tuple with the raw
numbers so callers can programmatically check whether a run will fit.

Covers:
  - ψ footprint per component dtype (ComplexF64 / ComplexF32)
  - Workspace buffer overhead during split-step (~5 × ψ)
  - DDI padded FFT workspace (~2 × ψ)
  - psi_snapshots buffer count × size when save_psi_snapshots is true
  - Final JLD2 disk footprint, with/without zlib compression estimate

Not a tight upper bound — CUDA fragmentation, analyzer passes, and
per-snapshot temporaries can add 10–20 %, so plan for headroom.
"""
function estimate_run_budget(yaml_path::AbstractString; io::IO = stdout)
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
    n_pts = NTuple{length(n_pts_raw),Int}(Int.(n_pts_raw))
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
        save_psi |= Bool(get(p, "save_psi_snapshots", false))
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

    _fmt(b) = b < 1024       ? @sprintf("%d B", b) :
              b < 1 << 20    ? @sprintf("%.1f KB", b / 1024) :
              b < 1 << 30    ? @sprintf("%.1f MB", b / 2^20) :
                               @sprintf("%.2f GB", b / 2^30)

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
    println(io, "  disk / run:   $(_fmt(disk_per_run / compression_ratio))   " *
                 "(compression: $(save_compressed ? "zlib ~2.5×" : "none"))")
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
        psi_bytes_f64 = psi_f64_bytes,
        psi_bytes_f32 = psi_f32_bytes,
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
