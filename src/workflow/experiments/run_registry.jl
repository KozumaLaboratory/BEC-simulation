# --- Run Registry: resumable YAML-driven experiments ---
#
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
function compute_run_dir(yaml_path::String; base_dir::String = "runs")
    isfile(yaml_path) || throw(ArgumentError("YAML file not found: $yaml_path"))
    content = read(yaml_path, String)
    hash8 = bytes2hex(sha256(content))[1:8]
    basename_no_ext = splitext(basename(yaml_path))[1]
    joinpath(base_dir, "$(basename_no_ext)_$(hash8)")
end

function _env_metadata()
    git_hash = try readchomp(`git rev-parse --short HEAD`) catch; "unknown" end
    git_dirty = try !isempty(readchomp(`git status --porcelain`)) catch; false end
    Dict{String,Any}(
        "git_hash" => git_hash,
        "git_dirty" => git_dirty,
        "julia_version" => string(VERSION),
        "julia_threads" => Threads.nthreads(),
        "hostname" => gethostname(),
        "platform" => string(Sys.KERNEL),
    )
end

_now_iso() = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")

function _point_filename(i::Int, run_name::String = "")
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
function run_yaml(yaml_path::String; base_dir::String = "runs", verbose::Bool = true)
    data = YAML.load_file(yaml_path)
    haskey(data, "pipeline") || throw(ArgumentError(
        "YAML must have a 'pipeline:' key. Got keys: $(collect(keys(data)))"))

    # Schema validation: catch typos and invalid values before starting
    validate_pipeline!(data)

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

    # Expand scan points (if any)
    scan_dict = get(data, "scan", nothing)
    if scan_dict !== nothing
        scan = _parse_override_scan(scan_dict)
        _run_yaml_scan(data, scan, run_dir, env; verbose)
    else
        # Single-shot pipeline: one point
        _run_yaml_single(data, run_dir, env, 1, ""; verbose)
    end

    verbose && println("Done: $run_dir")
    run_dir
end

function _run_yaml_scan(data::Dict, scan::OverrideScan, run_dir, env; verbose=true)
    has_comparison = !isempty(scan.comparison_runs)
    chain_state = Dict{String,Any}()  # run_name → (psi, mz_actual)

    pause_file = joinpath(run_dir, ".pause")

    for (i, point_override) in enumerate(scan.points)
        # Check for pause signal
        if isfile(pause_file)
            verbose && println("  Paused: detected $pause_file ($(i-1)/$(length(scan.points)) points completed)")
            verbose && println("  Remove .pause file and re-run to continue.")
            return
        end

        runs = has_comparison ? scan.comparison_runs : [("", Dict{String,Any}())]
        for (run_name, cmp_override) in runs
            psi_file = joinpath(run_dir, _point_filename(i, run_name))

            if isfile(psi_file)
                verbose && println("  ✓ $(basename(psi_file)) (cached)")
                if scan.continuation
                    d = JLD2.load(psi_file)
                    chain_state[run_name] = (psi = d["psi"], mz_actual = get(d, "mz_actual", NaN))
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
            result = run_pipeline(config; verbose = false, psi_init = psi_prev, checkpoint_dir = ckpt_dir)

            finished_at = _now_iso()
            duration = time() - t_start

            psi_host = _to_host(result.psi)
            energy = get(result, :ground_state_energy, NaN)
            converged = get(result, :ground_state_converged, true)

            # Mz measurement
            grid = result.grid
            sys = SpinSystem(result.atom.F)
            mz_actual = haskey(result, :ground_state_energy) ?
                        magnetization(psi_host, grid, sys) : NaN

            tmp_file = psi_file * ".tmp"
            try
                jldopen(tmp_file, "w") do f
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
                    for (k, v) in env
                        f["env/$k"] = v
                    end
                    _save_units_metadata!(f, patched)
                end
                mv(tmp_file, psi_file; force = true)
            catch err
                isfile(tmp_file) && rm(tmp_file; force = true)
                rethrow(err)
            end

            # Clean up checkpoint (point completed successfully)
            isdir(ckpt_dir) && rm(ckpt_dir; recursive = true, force = true)

            if scan.continuation
                chain_state[run_name] = (psi = psi_host, mz_actual = mz_actual)
            end

            verbose && @printf("    E=%.4f conv=%s (%.1fs)\n", energy, converged, duration)
        end
    end
end

function _run_yaml_single(data::Dict, run_dir, env, index, run_name; verbose=true)
    psi_file = joinpath(run_dir, _point_filename(index, run_name))

    if isfile(psi_file)
        verbose && println("  ✓ $(basename(psi_file)) (cached)")
        return
    end

    started_at = _now_iso()
    t_start = time()

    config = parse_pipeline(data)
    ckpt_dir = joinpath(run_dir, ".checkpoints", basename(psi_file))
    result = run_pipeline(config; verbose, checkpoint_dir = ckpt_dir)

    finished_at = _now_iso()
    duration = time() - t_start

    psi_host = _to_host(result.psi)
    energy = get(result, :ground_state_energy, NaN)
    converged = get(result, :ground_state_converged, true)

    tmp_file = psi_file * ".tmp"
    try
        jldopen(tmp_file, "w") do f
            f["psi"] = psi_host
            f["scan_index"] = index
            f["run_name"] = run_name
            f["started_at"] = started_at
            f["finished_at"] = finished_at
            f["duration_seconds"] = duration
            f["energy"] = energy
            f["converged"] = converged
            for (k, v) in env
                f["env/$k"] = v
            end
            _save_units_metadata!(f, data)
        end
        mv(tmp_file, psi_file; force = false)
    catch err
        isfile(tmp_file) && rm(tmp_file; force = true)
        rethrow(err)
    end

    isdir(ckpt_dir) && rm(ckpt_dir; recursive = true, force = true)
    verbose && @printf("    E=%.4f conv=%s\n", energy, converged)
end

"""
    run_status(run_dir) → NamedTuple

Report the progress of a run directory by counting per-point .jld2 files.
"""
function run_status(run_dir::String)
    isdir(run_dir) || return (exists = false, total = 0, completed = 0)
    files = filter(f -> startswith(f, "point_") && endswith(f, ".jld2"), readdir(run_dir))
    (exists = true, total = length(files), completed = length(files))
end

function list_runs(base_dir::String = "runs")
    isdir(base_dir) || return String[]
    dirs = filter(d -> isdir(joinpath(base_dir, d)) && isfile(joinpath(base_dir, d, "config.yaml")),
                  readdir(base_dir))
    sort(dirs)
end
