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

function _run_yaml_status(verbose::Bool, msg::AbstractString; comment::Bool=false)
    verbose || return nothing
    prefix = comment ? "# [run_yaml] " : "[run_yaml] "
    println(prefix, msg)
    flush(stdout)
    ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
    return nothing
end

function _pipeline_step_summary(data::Dict)
    pipe = get(data, "pipeline", Any[])
    pipe isa AbstractVector || return "pipeline: unavailable"
    names = String[]
    for step in pipe
        if step isa AbstractDict && length(step) == 1
            push!(names, string(first(keys(step))))
        else
            push!(names, "<?>")
        end
    end
    isempty(names) && return "pipeline: 0 steps"
    return "pipeline: $(length(names)) step(s): " * join(names, " -> ")
end

function _short_preview(x; maxchars::Int=180)
    s = replace(sprint(show, x), '\n' => ' ')
    length(s) <= maxchars && return s
    return first(s, maxchars) * "..."
end

function _pipeline_step_kind(data::Dict, idx0::Int)
    pipe = get(data, "pipeline", Any[])
    pipe isa AbstractVector || return nothing
    idx = idx0 + 1
    1 <= idx <= length(pipe) || return nothing
    step = pipe[idx]
    step isa AbstractDict && length(step) == 1 || return nothing
    return string(first(keys(step)))
end

function _get_unwrapped_path(data::Dict, path::AbstractString)
    parts = split(path, '.')
    cursor::Any = data
    for part in parts
        key = String(part)
        if cursor isa AbstractVector
            idx0 = tryparse(Int, key)
            idx0 === nothing && return nothing
            idx = idx0 + 1
            1 <= idx <= length(cursor) || return nothing
            elem = cursor[idx]
            cursor = elem isa AbstractDict && length(elem) == 1 ? first(values(elem)) : elem
        elseif cursor isa AbstractDict
            haskey(cursor, key) || return nothing
            cursor = cursor[key]
        else
            return nothing
        end
    end
    return cursor
end

function _override_path_warning(data::Dict, path::AbstractString)
    parts = split(path, '.')
    length(parts) >= 4 || return nothing
    parts[1] == "pipeline" || return nothing
    idx0 = tryparse(Int, parts[2])
    idx0 === nothing && return nothing
    kind = _pipeline_step_kind(data, idx0)
    kind === nothing && return nothing
    parts[3] == kind || return nothing
    corrected = join(["pipeline", parts[2], parts[4:end]...], ".")
    return "WARNING: path includes step kind '$kind' after pipeline index; " *
           "pipeline steps are auto-unwrapped. Use '$corrected'."
end

function _scan_preview_lines(data::Dict)
    scan_dict = get(data, "scan", nothing)
    scan_dict isa AbstractDict || return String[]
    runs = get(scan_dict, "comparison_runs", nothing)
    runs isa AbstractVector && !isempty(runs) || return String[]

    lines = String["# Scan comparison preview:"]
    push!(lines, "#   comparison_runs: $(length(runs))")
    for r in runs
        r isa AbstractDict || continue
        name = string(get(r, "name", "<unnamed>"))
        override = parse_override_map(get(r, "override", Dict()))
        push!(lines, "#   - $name: $(length(override)) override(s)")
        patched = apply_overrides(data, override)
        for (path, value) in sort(collect(override); by=first)
            push!(lines, "#       $path = $(_short_preview(value))")
            warn = _override_path_warning(data, path)
            warn === nothing || push!(lines, "#         $warn")
        end
        pipe = get(patched, "pipeline", Any[])
        if pipe isa AbstractVector
            for (i, step) in enumerate(pipe)
                step isa AbstractDict && length(step) == 1 || continue
                kind = string(first(keys(step)))
                params = first(values(step))
                if params isa AbstractDict && haskey(params, kind)
                    push!(lines,
                        "#         WARNING: nested key pipeline.$(i - 1).$kind.$kind exists after overrides",
                    )
                end
            end
        end
        loss = _get_unwrapped_path(patched, "pipeline.2.loss")
        loss === nothing ||
            push!(lines, "#       effective pipeline.2.loss = $(_short_preview(loss))")
    end
    push!(lines, "#")
    return lines
end

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
    dry_run::Bool=false, audit::Bool=true)
    _run_yaml_status(verbose, "starting run_yaml: $yaml_path"; comment=dry_run)
    return Base.invokelatest(_run_yaml_impl,
        yaml_path, base_dir, verbose, dry_run, audit)
end

@noinline function _run_yaml_impl(
    yaml_path::String, base_dir::String, verbose::Bool, dry_run::Bool, audit::Bool
)
    data = Base.invokelatest(_run_yaml_prepare, yaml_path, verbose, dry_run)::Dict
    # Audit hook: run inspector on normalised data; abort on :error severity
    # before any sim work hits the cluster. SPINORBEC_AUDIT=0 disables;
    # callers can also pass audit=false.
    if audit && lowercase(get(ENV, "SPINORBEC_AUDIT", "1")) ∉ ("0", "false", "off")
        Base.invokelatest(_run_yaml_audit, data, verbose)
    end
    if dry_run
        return Base.invokelatest(_run_yaml_dry_run_output, data, yaml_path, verbose)
    end
    return Base.invokelatest(_run_yaml_execute, data, yaml_path, base_dir, verbose)
end

@noinline function _run_yaml_audit(data::Dict, verbose::Bool)
    warnings = try
        audit_loaded_data(data)
    catch e
        # Parse failure here is a bug in the inspector or a config that
        # somehow passed validate_pipeline! but not parse_pipeline. Surface
        # the error but do not abort — the actual run will fail with the
        # canonical message a moment later.
        verbose && println(stderr,
            "[audit] inspector failed to run: ", sprint(showerror, e))
        return nothing
    end
    isempty(warnings) && return nothing
    blockers = ConfigWarning[]
    for w in warnings
        # Suppress :info from stderr — keeps the audit chatter quiet
        # during sweep dispatches. Full findings remain in the
        # ConfigInspection / dashboard panel.
        if w.severity !== :info
            println(stderr, terse_warning_line(w))
        end
        w.severity === :block && push!(blockers, w)
    end
    flush(stderr)
    if !isempty(blockers)
        # Surface the first blocker's full message + suggestion. The terse
        # line above already lists every blocker tag-by-tag.
        e = first(blockers)
        throw(
            ArgumentError(
                "audit blocked run_yaml: $(e.title)\n" *
                "  $(e.message)\n" *
                "  → $(e.suggestion)\n" *
                "  ($(length(blockers)) :block severity warning(s); " *
                "see [audit] lines above for the full list. " *
                "Pass `audit=false` or set SPINORBEC_AUDIT=0 to override.)",
            ),
        )
    end
    return nothing
end

@noinline function _run_yaml_prepare(yaml_path::String, verbose::Bool, dry_run::Bool)
    _run_yaml_status(verbose, "loading config: $yaml_path"; comment=dry_run)
    data = YAML.load_file(yaml_path)
    _run_yaml_status(verbose, "checking required top-level keys"; comment=dry_run)
    haskey(data, "pipeline") || throw(ArgumentError(
        "YAML must have a 'pipeline:' key. Got keys: $(collect(keys(data)))"))

    # Auto-apply Orszag 2/3 dealias settings. Pop the optional top-level
    # `dealias:` block so schema validation (strict=true) doesn't reject
    # it as unknown; the prepare/execute pair stashes the previous Ref
    # snapshot on the dict so execute can restore in a `finally`.
    if haskey(data, "dealias")
        _run_yaml_status(verbose, "applying dealias block"; comment=dry_run)
        snapshot = apply_dealias_block!(data)
        # Module-level Ref instead of `data["_dealias_snapshot"]` — strict
        # schema validation rejects unknown top-level keys, so we cannot
        # stash the snapshot inside the YAML dict.
        _DEALIAS_PENDING_SNAPSHOT[] = snapshot
        if verbose && DEALIAS_2_3_ENABLED[]
            println("  dealias: enabled=$(DEALIAS_2_3_ENABLED[]), " *
                    "k_cut=$(DEALIAS_K_CUTOFF[])")
        end
    end

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
        _run_yaml_status(verbose, "applying calibration block"; comment=dry_run)
        calib = _calibration_from_dict(pop!(data, "calibration"))
        verbose && println("  applying calibration epoch=$(calib.epoch) date=$(calib.date)")
        apply_calibration!(data, calib)
    elseif haskey(data, "calibration_history")
        _run_yaml_status(verbose, "applying calibration history"; comment=dry_run)
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
    _run_yaml_status(verbose, "expanding templates and mixins"; comment=dry_run)
    apply_templates_and_mixins!(data)

    # Auto-inject schema-level block defaults (e.g. `ground_state.ddi: {}`
    # so the parser auto-derives c_dd from atom + N_atoms + ω_ref). Must
    # run after templates/mixins so the steps it walks are fully expanded;
    # before unit/B/noise normalisation so those see consistent shape.
    _run_yaml_status(verbose, "injecting schema defaults"; comment=dry_run)
    apply_schema_defaults!(data)

    # Apply opt-in `units:` block AFTER calibration + templates (template
    # output may already be in Quantity strings; `units:` rewrite only
    # touches bare Reals).
    _run_yaml_status(verbose, "applying units block"; comment=dry_run)
    apply_units_block!(data)

    # Top-level `accuracy:` and `auto_grid:` shortcuts → physics-first
    # defaults seeded into pipeline steps where missing.
    _run_yaml_status(verbose, "applying accuracy and auto-grid defaults"; comment=dry_run)
    apply_auto_defaults!(data)

    # Unified `B:` block → split into internal magnitude + direction
    # dicts for the runner. Validates Cartesian/spherical mutual exclusion.
    _run_yaml_status(verbose, "normalizing B blocks"; comment=dry_run)
    apply_B_block_normalize!(data)

    # Unified `noise:` block → temperature_ratio / twa / sgpe / etc.
    # Validates `initial.thermal` ⊕ `twa` mutex.
    _run_yaml_status(verbose, "normalizing noise blocks"; comment=dry_run)
    apply_noise_block_normalize!(data)

    # Schema validation: catch typos and invalid values before starting.
    # strict=true fails the run on unknown keys; this is the production
    # default so silent-drop bugs (2026-04-27 `trap:` incident) cannot
    # repeat.
    _run_yaml_status(verbose, "validating schema"; comment=dry_run)
    validate_pipeline!(data; strict=true)
    _run_yaml_status(verbose, _pipeline_step_summary(data); comment=dry_run)
    return data
end

@noinline function _run_yaml_dry_run_output(data::Dict, yaml_path::String, verbose::Bool)
    # Dry-run: print the calibration-applied + units-applied + validated
    # YAML and exit without touching the GPU / building any workspace.
    # Useful for checking that lab-unit YAML expanded as expected before
    # committing to a long compute.
    _run_yaml_status(verbose, "dry-run complete; printing normalized YAML"; comment=true)
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
    for line in _scan_preview_lines(data)
        println(buf, line)
    end
    YAML.write(buf, data)
    out = String(take!(buf))
    print(out)
    return out
end

@noinline function _run_yaml_execute(
    data::Dict, yaml_path::String, base_dir::String, verbose::Bool
)
    # If the YAML is already runs/foo/config.yaml, use runs/foo/ as the run dir
    # (user manages directory names). Otherwise compute a hash-based dir.
    run_dir = if basename(yaml_path) == "config.yaml" && isdir(dirname(yaml_path))
        dirname(yaml_path)
    else
        compute_run_dir(yaml_path; base_dir)
    end
    _run_yaml_status(verbose, "using run directory: $run_dir")
    mkpath(run_dir)

    config_snapshot = joinpath(run_dir, "config.yaml")
    if abspath(yaml_path) != abspath(config_snapshot)
        _run_yaml_status(verbose, "snapshotting config: $config_snapshot")
        isfile(config_snapshot) || cp(yaml_path, config_snapshot)
    end

    _run_yaml_status(verbose, "collecting environment metadata")
    env = _env_metadata()

    # Make relative paths inside the YAML (e.g. `csv: beams.csv`) resolve
    # against the YAML's own directory, not the caller's cwd.
    prev_yaml_dir = get(ENV, "SPINORBEC_YAML_DIR", nothing)
    ENV["SPINORBEC_YAML_DIR"] = dirname(abspath(yaml_path))

    # Snapshot the dealias Refs so they can be restored after the run —
    # avoids state leakage when the same Julia session runs multiple
    # YAMLs back-to-back with different dealias settings.
    dealias_snapshot = _DEALIAS_PENDING_SNAPSHOT[]
    _DEALIAS_PENDING_SNAPSHOT[] = nothing

    try
        # Expand scan points (if any)
        scan_dict = get(data, "scan", nothing)
        if scan_dict !== nothing
            _run_yaml_status(verbose, "expanding scan points")
            scan = _parse_override_scan(scan_dict)
            _run_yaml_scan(data, scan, run_dir, env; verbose)
        else
            # Single-shot pipeline: one point
            _run_yaml_status(verbose, "starting single pipeline run")
            _run_yaml_single(data, run_dir, env, 1, ""; verbose)
        end
    finally
        if prev_yaml_dir === nothing
            delete!(ENV, "SPINORBEC_YAML_DIR")
        else
            (ENV["SPINORBEC_YAML_DIR"] = prev_yaml_dir)
        end
        if dealias_snapshot !== nothing
            (was_enabled, was_k_cut) = dealias_snapshot
            restore_dealias_refs!(was_enabled, was_k_cut)
        end
    end

    verbose && println("Done: $run_dir")
    run_dir
end

function _run_yaml_scan(data::Dict, scan::OverrideScan, run_dir, env; verbose=true)
    has_comparison = !isempty(scan.comparison_runs)
    n_recipes = has_comparison ? length(scan.comparison_runs) : 1
    _run_yaml_status(verbose,
        "scan: $(length(scan.points)) point(s), $n_recipes run recipe(s)")
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
            _run_yaml_status(verbose, "applying overrides for $(basename(psi_file))")
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

            _run_yaml_status(verbose, "parsing pipeline for $(basename(psi_file))")
            config = parse_pipeline(patched)
            ckpt_dir = joinpath(run_dir, ".checkpoints", basename(psi_file))
            live_path = joinpath(run_dir, "_live_status.json")
            _run_yaml_status(verbose, "running pipeline for $(basename(psi_file))")
            result = run_pipeline(config; verbose=verbose, psi_init=psi_prev,
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
                _run_yaml_status(verbose, "writing result: $(basename(psi_file))")
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
Callback returning whether CUDA is loaded *and* a working device is
visible. Default returns `false` (CPU-only build); the CUDA extension
overrides to `() -> CUDA.functional()` at `__init__`. This lets
`make_workspace` auto-pick `CUDABackend()` for large grids without
the core module having to `import CUDA` (which would force the dep).
"""
const _cuda_functional_callback = Ref{Function}(() -> false)
cuda_functional() = _cuda_functional_callback[]()::Bool

"""
Callback returning a vector of formatted lines describing the active
CUDA device — name, total memory, available memory, compute capability.
Default returns a single-line "CUDA not loaded" notice; the CUDA
extension overrides at `__init__`.
"""
const _cuda_state_lines_callback = Ref{Function}(
    () -> ["CUDA not loaded (using HTTP / using CUDA before `using SpinorBEC` to enable)"]
)
cuda_state_lines() = _cuda_state_lines_callback[]()::Vector{String}

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

    _run_yaml_status(verbose, "parsing pipeline for $(basename(psi_file))")
    config = parse_pipeline(data)
    ckpt_dir = joinpath(run_dir, ".checkpoints", basename(psi_file))
    live_path = joinpath(run_dir, "_live_status.json")
    _run_yaml_status(verbose, "running pipeline for $(basename(psi_file))")
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
        _run_yaml_status(verbose, "writing result: $(basename(psi_file))")
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
