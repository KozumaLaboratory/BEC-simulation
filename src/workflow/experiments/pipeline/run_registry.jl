# --- Run Registry: resumable YAML-driven experiments ---

export run_yaml, run_status, list_runs, compute_run_dir

# Directory-per-run design: 1 config.yaml ↔ 1 directory containing one
# self-contained JLD2 per scan point. Re-running the same YAML skips files
# that already exist; deleting a single jld2 forces that point to recompute.
#
# All experiments are expressed as pipelines. If the YAML has a `scan:`
# block, each scan point applies its override to the pipeline dict and
# runs `run_pipeline` independently.

"""
    compute_run_dir(yaml_path; base_dir="runs") → String

Map a YAML file to its run directory. Identical YAML content → identical
directory, enabling transparent resume.
"""
function compute_run_dir(yaml_path::String; base_dir::String="runs")
    isfile(yaml_path) || throw(ArgumentError("YAML file not found: $yaml_path"))
    content = read(yaml_path, String)
    hash8 = bytes2hex(sha256(content))[1:8]
    basename_no_ext = splitext(basename(yaml_path))[1]
    joinpath(base_dir, "$(basename_no_ext)_$(hash8)")
end

function _env_metadata()
    git_hash = try
        readchomp(`git rev-parse --short HEAD`)
    catch
        ;
        "unknown"
    end
    git_dirty = try
        !isempty(readchomp(`git status --porcelain`))
    catch
        ;
        false
    end
    Dict{String, Any}(
        "git_hash" => git_hash,
        "git_dirty" => git_dirty,
        "julia_version" => string(VERSION),
        "julia_threads" => Threads.nthreads(),
        "hostname" => gethostname(),
        "platform" => string(Sys.KERNEL),
    )
end

_now_iso() = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")

function _point_filename(i::Int, run_name::String="")
    base = "point_$(lpad(i, 3, '0'))"
    isempty(run_name) ? "$(base).jld2" : "$(base)_$(run_name).jld2"
end

"""
    run_yaml(yaml_path; base_dir="runs", verbose=true) → String

Run or resume the experiment defined by `yaml_path`. Returns the run dir.

The YAML must have a `pipeline:` key. If a `scan:` key is present,
each scan point × comparison run is executed independently via
`run_pipeline` with the corresponding overrides applied to the raw dict.
"""
function run_yaml(yaml_path::String; base_dir::String="runs", verbose::Bool=true,
    dry_run::Bool=false)
    data = YAML.load_file(yaml_path)
    haskey(data, "pipeline") || throw(ArgumentError(
        "YAML must have a 'pipeline:' key. Got keys: $(collect(keys(data)))"))

    # Auto-apply lab-unit calibration. Three forms recognised:
    #
    #   1. `calibration:`         single CalibrationSet
    #   2. `calibration_history:` + optional `target_date:` — interpolate
    #      between dated snapshots so weekly drift is captured automatically
    #      (Phase 5.5 / Scenario #68). Without target_date, defaults to
    #      today's date.
    #
    # All calibration-related top-level keys are popped before schema
    # validation so they don't trigger "unknown key" warnings.
    if haskey(data, "calibration") && data["calibration"] isa Dict
        calib = _calibration_from_dict(pop!(data, "calibration"))
        verbose && println("  applying calibration epoch=$(calib.epoch) date=$(calib.date)")
        apply_calibration!(data, calib)
    elseif haskey(data, "calibration_history")
        hist_raw = pop!(data, "calibration_history")
        target = if haskey(data, "target_date")
            Dates.Date(String(pop!(data, "target_date")))
        else
            Dates.today()
        end
        # Reuse the loader logic by stuffing into the expected wrapper
        tmp = Dict{String, Any}("calibration_history" => hist_raw)
        tmp_path = tempname() * ".yaml"
        YAML.write_file(tmp_path, tmp)
        try
            hist = load_calibration_history(tmp_path)
            calib = interpolate_calibration(hist, target)
            verbose && println("  applying interpolated calibration → $(calib.epoch)")
            apply_calibration!(data, calib)
        finally
            rm(tmp_path; force=true)
        end
    end

    # Expand templates + mixins (named protocols, reusable parameter sets).
    apply_templates_and_mixins!(data)

    # Auto-inject schema-level block defaults (e.g. `ground_state.ddi: {}`
    # so the parser auto-derives c_dd from atom + N_atoms + ω_ref). Must
    # run after templates/mixins so the steps it walks are fully expanded;
    # before unit/B/noise normalisation so those see consistent shape.
    apply_schema_defaults!(data)

    # Apply opt-in `units:` block AFTER calibration + templates (template
    # output may already be in Quantity strings; `units:` rewrite only
    # touches bare Reals).
    apply_units_block!(data)

    # Top-level `accuracy:` and `auto_grid:` shortcuts → physics-first
    # defaults seeded into pipeline steps where missing.
    apply_auto_defaults!(data)

    # Unified `B:` block → split into legacy zeeman: + B_hat: for the
    # runner. Validates Cartesian/spherical mutual exclusion.
    apply_B_block_normalize!(data)

    # Unified `noise:` block → temperature_ratio / twa / sgpe / etc.
    # Validates `initial.thermal` ⊕ `twa` mutex.
    apply_noise_block_normalize!(data)

    # Schema validation: catch typos and invalid values before starting.
    # strict=true fails the run on unknown keys; this is the production
    # default so silent-drop bugs (2026-04-27 `trap:` incident) cannot
    # repeat.
    validate_pipeline!(data; strict=true)

    # Dry-run: print the calibration-applied + units-applied + validated
    # YAML and exit without touching the GPU / building any workspace.
    # Useful for checking that lab-unit YAML expanded as expected before
    # committing to a long compute.
    if dry_run
        buf = IOBuffer()
        println(buf, "# === run_yaml dry-run (post calibration + units + validation) ===")
        println(buf, "# original: $yaml_path")
        println(buf, "#")
        println(buf, "# Stages applied:")
        println(buf, "#   1. calibration:  lab-control values → physical units")
        println(buf, "#   2. units:        bare Reals → unit-bearing strings")
        println(buf, "#   3. schema:       unknown-key + range + enum validation")
        println(buf, "#")
        println(buf, "# Numerics defaults (dt, save_every, n_steps) are still expressed")
        println(buf, "# in their YAML form here; final resolved values are logged when")
        println(buf, "# the actual run starts. To inspect resolved values without running,")
        println(buf, "# use a 1-step ground_state with verbose=true.")
        println(buf, "#")
        YAML.write(buf, data)
        out = String(take!(buf))
        print(out)
        return out
    end

    # If the YAML is already runs/foo/config.yaml, use runs/foo/ as the run dir
    # (user manages directory names). Otherwise compute a hash-based dir.
    run_dir = if basename(yaml_path) == "config.yaml" && isdir(dirname(yaml_path))
        dirname(yaml_path)
    else
        compute_run_dir(yaml_path; base_dir)
    end
    mkpath(run_dir)

    config_snapshot = joinpath(run_dir, "config.yaml")
    if abspath(yaml_path) != abspath(config_snapshot)
        isfile(config_snapshot) || cp(yaml_path, config_snapshot)
    end

    env = _env_metadata()

    # Make relative paths inside the YAML (e.g. `csv: beams.csv`) resolve
    # against the YAML's own directory, not the caller's cwd.
    prev_yaml_dir = get(ENV, "SPINORBEC_YAML_DIR", nothing)
    ENV["SPINORBEC_YAML_DIR"] = dirname(abspath(yaml_path))

    try
        # Expand scan points (if any)
        scan_dict = get(data, "scan", nothing)
        if scan_dict !== nothing
            scan = _parse_override_scan(scan_dict)
            _run_yaml_scan(data, scan, run_dir, env; verbose)
        else
            # Single-shot pipeline: one point
            _run_yaml_single(data, run_dir, env, 1, ""; verbose)
        end
    finally
        if prev_yaml_dir === nothing
            delete!(ENV, "SPINORBEC_YAML_DIR")
        else
            (ENV["SPINORBEC_YAML_DIR"] = prev_yaml_dir)
        end
    end

    verbose && println("Done: $run_dir")
    run_dir
end

function _run_yaml_scan(data::Dict, scan::OverrideScan, run_dir, env; verbose=true)
    has_comparison = !isempty(scan.comparison_runs)
    chain_state = Dict{String, Any}()  # run_name → (psi, mz_actual)

    pause_file = joinpath(run_dir, ".pause")

    # SLURM array-job hook: if SPINORBEC_SCAN_ONLY_INDEX is set (e.g. by
    # scripts/slurm/scan_array.sbatch), compute only that single point and
    # exit. Indices are 1-based and clamped silently.
    only_idx = let v = get(ENV, "SPINORBEC_SCAN_ONLY_INDEX", nothing)
        v === nothing ? nothing : parse(Int, v)
    end

    for (i, point_override) in enumerate(scan.points)
        # SLURM array-job mode: skip everything except the assigned index
        if only_idx !== nothing && i != only_idx
            continue
        end
        # Check for pause signal
        if isfile(pause_file)
            verbose && println(
                "  Paused: detected $pause_file ($(i-1)/$(length(scan.points)) points completed)"
            )
            verbose && println("  Remove .pause file and re-run to continue.")
            return nothing
        end

        runs = has_comparison ? scan.comparison_runs : [("", Dict{String, Any}())]
        for (run_name, cmp_override) in runs
            psi_file = joinpath(run_dir, _point_filename(i, run_name))

            if isfile(psi_file)
                verbose && println("  ✓ $(basename(psi_file)) (cached)")
                if scan.continuation
                    d = JLD2.load(psi_file)
                    chain_state[run_name] = (psi=d["psi"], mz_actual=get(d, "mz_actual", NaN))
                end
                continue
            end

            merged = merge(point_override, cmp_override)
            verbose && println("  → $(basename(psi_file))")

            # Apply overrides to pipeline dict
            patched = apply_overrides(data, merged)
            # Strip scan block to prevent recursion
            delete!(patched, "scan")

            started_at = _now_iso()
            t_start = time()

            # Continuation: inject previous psi as initial condition
            prev = scan.continuation ? get(chain_state, run_name, nothing) : nothing
            psi_prev = prev !== nothing ? prev.psi : nothing

            if psi_prev !== nothing && scan.auto_rotate_on_mz
                prev_mz = prev !== nothing ? prev.mz_actual : NaN
                psi_prev = auto_rotate_psi(psi_prev, patched, prev_mz)
            end

            config = parse_pipeline(patched)
            ckpt_dir = joinpath(run_dir, ".checkpoints", basename(psi_file))
            live_path = joinpath(run_dir, "_live_status.json")
            result = run_pipeline(config; verbose=false, psi_init=psi_prev,
                checkpoint_dir=ckpt_dir, live_status_path=live_path)

            finished_at = _now_iso()
            duration = time() - t_start

            psi_host = _to_host(result.psi)
            energy = get(result, :ground_state_energy, NaN)
            converged = get(result, :ground_state_converged, true)

            # Mz measurement
            grid = result.grid
            sys = SpinSystem(result.atom.F)
            mz_actual =
                haskey(result, :ground_state_energy) ?
                magnetization(psi_host, grid, sys) : NaN

            tmp_file = _scratch_tmp_path(psi_file)
            jld_kwargs = _snapshot_compression_kwargs(result)
            try
                jldopen(tmp_file, "w"; jld_kwargs...) do f
                    f["psi"] = psi_host
                    f["scan_index"] = i
                    f["run_name"] = run_name
                    f["override"] = merged
                    f["started_at"] = started_at
                    f["finished_at"] = finished_at
                    f["duration_seconds"] = duration
                    f["energy"] = energy
                    f["converged"] = converged
                    f["mz_actual"] = mz_actual
                    # Embed grid geometry — see single-run path for rationale.
                    f["grid_box_size"] = collect(Float64, grid.config.box_size)
                    f["grid_n_points"] = collect(Int, grid.config.n_points)
                    for (k, v) in env
                        f["env/$k"] = v
                    end
                    _save_units_metadata!(f, patched)
                    _save_analyzer_results!(f, result)
                end
                _move_scratch_to_final(tmp_file, psi_file)
            catch err
                isfile(tmp_file) && rm(tmp_file; force=true)
                rethrow(err)
            end

            # Clean up checkpoint (point completed successfully)
            isdir(ckpt_dir) && rm(ckpt_dir; recursive=true, force=true)

            if scan.continuation
                chain_state[run_name] = (psi=psi_host, mz_actual=mz_actual)
            end

            verbose && @printf("    E=%.4f conv=%s (%.1fs)\n", energy, converged, duration)

            # Free the workspace's GPU buffers before the next scan point.
            # Without this, ~96 ComplexF64 64³ workspaces can accumulate on
            # a 16 GB device before CUDA's allocator reclaims (each
            # workspace pins ~150 MB across psi/fft_buf/k²/ddi_kernel/...).
            result = nothing
            GC.gc()
            _maybe_cuda_reclaim()
        end
    end
end

"""
Callback the CUDA extension sets at `__init__` to release cached GPU
memory between scan points. Default is a no-op so the CPU-only build
doesn't pay any cost.
"""
const _cuda_reclaim_callback = Ref{Function}(() -> nothing)
_maybe_cuda_reclaim() = _cuda_reclaim_callback[]()

"""
    _scratch_tmp_path(final_path)

Return a filesystem path suitable for the JLD2 `.tmp` write. When the env
var `SPINORBEC_SCRATCH_DIR` is set (typically node-local fast storage on
HPC — TSUBAME's T4_TMPDIR, SLURM's TMPDIR, or `/tmp`), write there and
copy to the final shared-filesystem path at the end. On Lustre-style
shared storage the per-dataset JLD2 writes can otherwise saturate the
metadata server.
"""
function _scratch_tmp_path(final_path::String)
    scratch = get(ENV, "SPINORBEC_SCRATCH_DIR", "")
    if isempty(scratch)
        return final_path * ".tmp"
    end
    isdir(scratch) || mkpath(scratch)
    joinpath(scratch, string(hash(final_path); base=16) * ".jld2.tmp")
end

"""
    _move_scratch_to_final(tmp_path, final_path)

Atomically move the scratch file into place. If the scratch dir is on a
different filesystem (typical on HPC: local SSD vs shared home) `mv`
falls back to copy+delete automatically. Creates the destination
directory if it doesn't exist.
"""
function _move_scratch_to_final(tmp_path::String, final_path::String)
    final_dir = dirname(final_path)
    isdir(final_dir) || mkpath(final_dir)
    mv(tmp_path, final_path; force=true)
end

"""
    _snapshot_compression_kwargs(result) -> NamedTuple

When the pipeline result flags `:save_snapshot_compression` as true, emit
`(; compress = ZlibCompressor())` kwargs so the JLD2 file compresses
every dataset transparently. zlib was picked over zstd because JLD2's
codec integration is stable across 0.4/0.5 and the `CodecZlib` pkg is
a tiny dep. Compression ratio on spinor snapshots is typically 1.8–3×
depending on how much the density concentrates in the cloud core.
Leaves the kwargs empty (no compression) when the flag is absent.
"""
function _snapshot_compression_kwargs(result)
    if get(result, :save_snapshot_compression, false)
        return (; compress=ZlibCompressor())
    end
    return (;)
end

function _run_yaml_single(data::Dict, run_dir, env, index, run_name; verbose=true)
    psi_file = joinpath(run_dir, _point_filename(index, run_name))

    if isfile(psi_file)
        verbose && println("  ✓ $(basename(psi_file)) (cached)")
        return nothing
    end

    started_at = _now_iso()
    t_start = time()

    config = parse_pipeline(data)
    ckpt_dir = joinpath(run_dir, ".checkpoints", basename(psi_file))
    live_path = joinpath(run_dir, "_live_status.json")
    result = run_pipeline(config; verbose, checkpoint_dir=ckpt_dir,
        live_status_path=live_path)

    finished_at = _now_iso()
    duration = time() - t_start

    psi_host = _to_host(result.psi)
    energy = get(result, :ground_state_energy, NaN)
    converged = get(result, :ground_state_converged, true)

    tmp_file = _scratch_tmp_path(psi_file)
    jld_kwargs = _snapshot_compression_kwargs(result)
    try
        jldopen(tmp_file, "w"; jld_kwargs...) do f
            f["psi"] = psi_host
            f["scan_index"] = index
            f["run_name"] = run_name
            f["started_at"] = started_at
            f["finished_at"] = finished_at
            f["duration_seconds"] = duration
            f["energy"] = energy
            f["converged"] = converged
            # Embed grid geometry so dashboard endpoints (vector3d_bin,
            # vorticity3d_bin, …) can reconstruct the spatial mesh without
            # re-parsing config.yaml — the YAML fallback misses
            # mixin-expanded configs because `_read_box_size` reads the raw
            # YAML, not the expanded pipeline dict.
            grid_obj = get(result, :grid, nothing)
            if grid_obj !== nothing
                f["grid_box_size"] = collect(Float64, grid_obj.config.box_size)
                f["grid_n_points"] = collect(Int, grid_obj.config.n_points)
            end
            for (k, v) in env
                f["env/$k"] = v
            end
            _save_units_metadata!(f, data)
            _save_analyzer_results!(f, result)
        end
        _move_scratch_to_final(tmp_file, psi_file)
    catch err
        isfile(tmp_file) && rm(tmp_file; force=true)
        rethrow(err)
    end

    isdir(ckpt_dir) && rm(ckpt_dir; recursive=true, force=true)
    verbose && @printf("    E=%.4f conv=%s\n", energy, converged)
end

"""
    run_status(run_dir) → NamedTuple

Report the progress of a run directory:

  - `completed`: number of `point_*.jld2` files written
  - `expected`:  number of points the YAML scan block plans (Int) or
                 `nothing` for a single-point (no scan) run / unknown
  - `latest_mtime_s`: epoch-seconds mtime of newest point file (NaN if none)
  - `eta_s`:    naive linear ETA based on the gap between the first and
                last completed points (NaN if <2 points)
"""
function run_status(run_dir::String)
    isdir(run_dir) ||
        return (exists=false, completed=0, expected=nothing,
            latest_mtime_s=NaN, eta_s=NaN)
    files = filter(f -> startswith(f, "point_") && endswith(f, ".jld2"),
        readdir(run_dir))
    completed = length(files)
    expected = _expected_scan_points(joinpath(run_dir, "config.yaml"))
    latest_mtime_s = NaN
    eta_s = NaN
    if !isempty(files)
        mtimes = [mtime(joinpath(run_dir, f)) for f in files]
        latest_mtime_s = maximum(mtimes)
        if completed >= 2 && expected isa Int && expected > completed
            elapsed = latest_mtime_s - minimum(mtimes)
            per_point = elapsed / max(completed - 1, 1)
            eta_s = per_point * (expected - completed)
        end
    end
    (exists=true, completed=completed, expected=expected,
        latest_mtime_s=latest_mtime_s, eta_s=eta_s)
end

function _expected_scan_points(cfg_path::String)
    isfile(cfg_path) || return nothing
    data = try
        YAML.load_file(cfg_path)
    catch
        return nothing
    end
    scan = get(data, "scan", nothing)
    scan isa Dict || return nothing
    pts = try
        expand_scan_points(scan)
    catch
        return nothing
    end
    n_pts = length(pts)
    n_pts == 0 && return nothing
    comparison = get(scan, "comparison_runs", nothing)
    n_recipes = (comparison isa Vector && !isempty(comparison)) ? length(comparison) : 1
    n_pts * n_recipes
end

function list_runs(base_dir::String="runs")
    isdir(base_dir) || return String[]
    dirs = filter(d -> isdir(joinpath(base_dir, d)) && isfile(joinpath(base_dir, d, "config.yaml")),
        readdir(base_dir))
    sort(dirs)
end
