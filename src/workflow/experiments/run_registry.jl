# --- Run Registry: resumable YAML-driven experiments ---
#
# Single-file-per-run design: 1 config.yaml ↔ 1 results.jld2.
# All results, metadata, and the YAML source itself live in one JLD2 file.
# Re-running the same YAML skips already-completed scan points.
#
# Key functions:
#   run_yaml(yaml_path)  — run or resume the experiment defined by the YAML
#   run_status(run_file) — report progress of an existing run
#   list_runs(base_dir)  — enumerate all runs under a directory
#
# File layout inside run_file (JLD2):
#   config_yaml           String   raw YAML content
#   yaml_hash             String   sha256 of canonical content
#   yaml_basename         String   yaml file basename without extension
#   metadata/...          Dict     git hash, julia version, timestamps, etc.
#   points/<key>/...      Groups   one group per (scan_point × comparison_run)
#     psi, energy, dE, dpsi, converged, scan_value, run_name, ...

"""
    compute_run_file(yaml_path; base_dir="output/runs") → String

Deterministically map a YAML file to its result file path. Two YAML files with
identical content produce the same run_file, enabling transparent resume.
"""
function compute_run_file(yaml_path::String; base_dir::String = "output/runs")
    isfile(yaml_path) || throw(ArgumentError("YAML file not found: $yaml_path"))
    content = read(yaml_path, String)
    hash_full = bytes2hex(sha256(content))
    hash8 = hash_full[1:8]
    basename_no_ext = splitext(basename(yaml_path))[1]
    joinpath(base_dir, "$(basename_no_ext)_$(hash8).jld2")
end

"""
    _env_metadata() → Dict{String,Any}

Collect environment metadata (git hash, julia version, hostname, etc).
"""
function _env_metadata()
    git_hash = try
        readchomp(`git rev-parse --short HEAD`)
    catch
        "unknown"
    end
    git_dirty = try
        !isempty(readchomp(`git status --porcelain`))
    catch
        false
    end
    Dict{String,Any}(
        "git_hash" => git_hash,
        "git_dirty" => git_dirty,
        "julia_version" => string(VERSION),
        "julia_threads" => Threads.nthreads(),
        "hostname" => gethostname(),
        "platform" => Sys.KERNEL |> string,
    )
end

_now_iso() = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")

"""
    _point_group_path(i, comparison_run_name) → String

Compute the JLD2 group path for a scan point × optional comparison run.
"""
function _point_group_path(i::Int, comparison_run_name::String = "")
    base = "points/point_$(lpad(i, 3, '0'))"
    isempty(comparison_run_name) ? base : "$(base)/$(comparison_run_name)"
end

"""
    _expand_scan_points(config) → Vector{NamedTuple}

Enumerate all scan points × comparison runs that should be computed.
For GroundStateExperiment, returns a single "ground_state" entry.
"""
function _expand_scan_points(config::UnifiedConfig)
    if config.spec isa GroundStateExperiment
        return [(index = 1, scan_value = NaN, run_name = "", is_comparison = false)]
    elseif config.spec isa ScanExperiment{ParameterScan}
        scan = config.spec.scan
        axis = scan.axes[1]
        values = collect(_sweep_values(axis.values))
        comparison_runs = scan.comparison_runs
        points = NamedTuple[]
        for (i, val) in enumerate(values)
            if isempty(comparison_runs)
                push!(
                    points,
                    (
                        index = i,
                        scan_value = val,
                        run_name = "",
                        is_comparison = false,
                    ),
                )
            else
                for run in comparison_runs
                    push!(
                        points,
                        (
                            index = i,
                            scan_value = val,
                            run_name = run.name,
                            is_comparison = true,
                        ),
                    )
                end
            end
        end
        return points
    else
        throw(ArgumentError("run_yaml does not yet support $(typeof(config.spec))"))
    end
end

"""
    run_yaml(yaml_path; base_dir="output/runs", verbose=true) → String

Run or resume the experiment defined by `yaml_path`. Returns the run_file path.

Behavior:
- Computes run_file = base_dir/{yaml_basename}_{hash8}.jld2
- If the file exists, reads completed point groups and skips them
- For each missing point, computes it and writes the group atomically
- Updates metadata (last_update) after each point

Resume happens automatically: call `run_yaml` on the same YAML a second time
and it picks up where it left off. To force a recompute, delete the run_file
or the specific point group inside it.
"""
function run_yaml(yaml_path::String; base_dir::String = "output/runs", verbose::Bool = true)
    config = load_config(yaml_path)
    run_file = compute_run_file(yaml_path; base_dir)
    mkpath(dirname(run_file))

    expected = _expand_scan_points(config)
    n_expected = length(expected)

    verbose && println("Run file: $run_file")
    verbose && println("Expected points: $n_expected")

    # First-time setup: write YAML content and metadata
    if !isfile(run_file)
        jldopen(run_file, "w") do f
            f["config_yaml"] = read(yaml_path, String)
            content = read(yaml_path, String)
            f["yaml_hash"] = bytes2hex(sha256(content))
            f["yaml_basename"] = splitext(basename(yaml_path))[1]
            f["metadata/started_at"] = _now_iso()
            f["metadata/last_update"] = _now_iso()
            for (k, v) in _env_metadata()
                f["metadata/$k"] = v
            end
        end
    end

    grid, atom, ndim = _setup_grid(config)
    potential = _build_potential(config.ground_state.potential, ndim)
    sys = SpinSystem(atom.F)
    sm = spin_matrices(atom.F)

    # Main loop: skip existing groups, compute missing ones
    for point in expected
        group_path = _point_group_path(point.index, point.run_name)

        # Check if this point is already done
        already_done = jldopen(run_file, "r") do f
            haskey(f, "$group_path/energy")
        end

        if already_done
            verbose && println("  ✓ $group_path (cached)")
            continue
        end

        verbose && println("  → computing $group_path (scan_value=$(point.scan_value))")
        started_at = _now_iso()
        t_start = time()

        result = _compute_single_point(
            config,
            grid,
            atom,
            sys,
            sm,
            potential,
            point,
        )

        finished_at = _now_iso()
        duration = time() - t_start

        # Atomic write: open in append mode, write all fields, close.
        # If the process is killed mid-write, the group may be partial;
        # the next run detects the missing "energy" key and retries.
        jldopen(run_file, "a+") do f
            f["$group_path/psi"] = result.psi
            f["$group_path/scan_value"] = point.scan_value
            f["$group_path/scan_index"] = point.index
            f["$group_path/run_name"] = point.run_name
            f["$group_path/started_at"] = started_at
            f["$group_path/finished_at"] = finished_at
            f["$group_path/duration_seconds"] = duration
            f["$group_path/energy"] = result.energy
            f["$group_path/dE"] = result.dE
            f["$group_path/dpsi"] = result.dpsi
            f["$group_path/converged"] = result.converged
            if haskey(result, :mz_actual)
                f["$group_path/mz_actual"] = result.mz_actual
            end
            if haskey(result, :mz_target)
                f["$group_path/mz_target"] = result.mz_target
            end

            # Update metadata
            delete!(f, "metadata/last_update")
            f["metadata/last_update"] = _now_iso()
        end

        verbose && @printf("    E=%.4f dE=%.3g conv=%s\n",
                           result.energy, result.dE, result.converged)
    end

    # Mark run as completed
    jldopen(run_file, "a+") do f
        if haskey(f, "metadata/status")
            delete!(f, "metadata/status")
        end
        f["metadata/status"] = "completed"
        if haskey(f, "metadata/finished_at")
            delete!(f, "metadata/finished_at")
        end
        f["metadata/finished_at"] = _now_iso()
    end

    verbose && println("Done: $run_file")
    run_file
end

"""
    _compute_single_point(config, grid, atom, sys, sm, potential, point) → NamedTuple

Dispatch to the appropriate ground-state computation for one scan point.
Returns a NamedTuple with at least: psi, energy, dE, dpsi, converged.
May also include: mz_actual, mz_target.
"""
function _compute_single_point(config, grid, atom, sys, sm, potential, point)
    gs = config.ground_state
    sys_cfg = config.system
    c_dd_val = sys_cfg.ddi.c_dd === nothing ? NaN : sys_cfg.ddi.c_dd
    backend = _resolve_backend(gs.backend)

    # Resolve parameters per scan point
    interactions_use = sys_cfg.interactions
    target_mz = gs.target_magnetization
    initial_state = gs.initial_state
    init_state_params = gs.init_state_params

    if config.spec isa ScanExperiment{ParameterScan}
        scan = config.spec.scan
        axis = scan.axes[1]
        # Apply the scan axis to the state
        F = atom.F
        ip = sys_cfg.interactions
        c_total = ip.c0 + F^2 * ip.c1
        base_state = (
            interactions = sys_cfg.interactions,
            zeeman = gs.zeeman,
            c_dd_override = nothing,
            rotating_frame_omega = gs.rotating_frame_omega,
            target_magnetization_override = nothing,
        )
        state = _apply_sweep_param(
            base_state, axis.parameter, Float64(point.scan_value);
            c_total, F, quasi_2d = false, l_z = 0.0,
        )
        interactions_use = state.interactions
        if state.target_magnetization_override !== nothing
            target_mz = state.target_magnetization_override
        end
        if state.c_dd_override !== nothing
            c_dd_val = state.c_dd_override
        end

        # Comparison run override
        if point.is_comparison
            run = scan.comparison_runs[findfirst(
                r -> r.name == point.run_name, scan.comparison_runs,
            )]
            initial_state = run.initial_state
            init_state_params = run.init_state_params
            if run.target_magnetization !== nothing
                target_mz = run.target_magnetization
            end
        end
    end

    gs_result = find_ground_state(;
        grid, atom,
        interactions = interactions_use,
        zeeman = gs.zeeman,
        potential,
        dt = gs.dt,
        n_steps = gs.n_steps,
        tol = gs.tol,
        initial_state = initial_state,
        init_state_params = init_state_params,
        enable_ddi = something(gs.enable_ddi, sys_cfg.ddi.enabled),
        c_dd = c_dd_val,
        secular_ddi = sys_cfg.ddi.secular,
        quasi_2d_ddi = sys_cfg.ddi.quasi_2d,
        l_z_ddi = sys_cfg.ddi.l_z,
        target_magnetization = target_mz,
        rotating_frame_omega = gs.rotating_frame_omega,
        backend = backend,
    )

    psi_host = _to_host(gs_result.workspace.state.psi)
    mz_actual = if target_mz !== nothing
        magnetization(psi_host, grid, sys)
    else
        NaN
    end

    (
        psi = psi_host,
        energy = gs_result.energy,
        dE = gs_result.dE,
        dpsi = gs_result.dpsi,
        converged = gs_result.converged,
        mz_actual = mz_actual,
        mz_target = target_mz === nothing ? NaN : target_mz,
    )
end

"""
    run_status(run_file) → NamedTuple

Report the progress of an existing run file. Returns a NamedTuple with:
  total, done, percent, status, last_update
"""
function run_status(run_file::String)
    isfile(run_file) || return (total = 0, done = 0, percent = 0.0,
                                status = :missing, last_update = "")
    config_yaml = jldopen(run_file, "r") do f
        haskey(f, "config_yaml") ? f["config_yaml"] : ""
    end
    isempty(config_yaml) && return (total = 0, done = 0, percent = 0.0,
                                     status = :invalid, last_update = "")

    # Parse the embedded YAML to determine expected points
    config = load_config_from_string(config_yaml)
    expected = _expand_scan_points(config)

    done, last_update, status = jldopen(run_file, "r") do f
        done_count = 0
        for point in expected
            group_path = _point_group_path(point.index, point.run_name)
            haskey(f, "$group_path/energy") && (done_count += 1)
        end
        lu = haskey(f, "metadata/last_update") ? f["metadata/last_update"] : ""
        st = haskey(f, "metadata/status") ? Symbol(f["metadata/status"]) : :running
        (done_count, lu, st)
    end

    total = length(expected)
    (
        total = total,
        done = done,
        percent = round(100 * done / max(total, 1); digits = 1),
        status = status,
        last_update = last_update,
    )
end

"""
    list_runs(base_dir="output/runs") → Vector{NamedTuple}

Enumerate all run files under `base_dir` and report their status.
"""
function list_runs(base_dir::String = "output/runs")
    isdir(base_dir) || return NamedTuple[]
    files = filter(f -> endswith(f, ".jld2"), readdir(base_dir; join = true))
    result = NamedTuple[]
    for f in files
        try
            st = run_status(f)
            push!(result, (file = f, status = st))
        catch err
            push!(result, (file = f, status = (error = sprint(showerror, err),)))
        end
    end
    result
end

