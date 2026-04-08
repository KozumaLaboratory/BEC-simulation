# --- Run Registry: resumable YAML-driven experiments ---
#
# Directory-per-run design: 1 config.yaml ↔ 1 directory containing one
# self-contained JLD2 per scan point. Re-running the same YAML skips files
# that already exist; deleting a single jld2 forces that point to recompute.
#
# Key functions:
#   run_yaml(yaml_path)  — run or resume the experiment defined by the YAML
#   run_status(run_dir)  — report progress of an existing run
#   list_runs(base_dir)  — enumerate all runs under a directory
#
# Directory layout:
#   runs/{yaml_basename}_{hash8}/
#     config.yaml                              # input snapshot
#     point_001_{run_name}.jld2                # one per (scan point × run)
#     point_002_{run_name}.jld2
#     ...
#
# Each .jld2 contains: psi + scan/run identifiers + convergence metrics +
# environment metadata (git hash, julia version, timestamps).

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
        "platform" => string(Sys.KERNEL),
    )
end

_now_iso() = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")

"""
    _point_filename(i, run_name) → String

Compute the per-point JLD2 filename inside the run directory.
"""
function _point_filename(i::Int, run_name::String = "")
    base = "point_$(lpad(i, 3, '0'))"
    isempty(run_name) ? "$(base).jld2" : "$(base)_$(run_name).jld2"
end

"""
    _expand_scan_points(config) → Vector{NamedTuple}

Enumerate all scan points × comparison runs that should be computed.
Each entry carries an `override::Dict{String,Any}` (the merged scan-point
override + comparison override, applied to the raw YAML before re-parsing).
"""
function _expand_scan_points(config::UnifiedConfig)
    if config.spec isa GroundStateExperiment
        return [(
            index = 1,
            run_name = "",
            override = Dict{String,Any}(),
        )]
    elseif config.spec isa ScanExperiment{OverrideScan}
        scan = config.spec.scan
        points = NamedTuple[]
        for (i, point_override) in enumerate(scan.points)
            if isempty(scan.comparison_runs)
                push!(points, (
                    index = i,
                    run_name = "",
                    override = point_override,
                ))
            else
                for (name, cmp_override) in scan.comparison_runs
                    merged = merge(point_override, cmp_override)
                    push!(points, (
                        index = i,
                        run_name = name,
                        override = merged,
                    ))
                end
            end
        end
        return points
    else
        throw(ArgumentError("run_yaml does not yet support $(typeof(config.spec))"))
    end
end

"""
    run_yaml(yaml_path; base_dir="runs", verbose=true) → String

Run or resume the experiment defined by `yaml_path`. Returns the run directory.

Behavior:
- Resolves run_dir = base_dir/{yaml_basename}_{hash8}
- Copies the YAML into config.yaml the first time
- For each scan point × comparison run, applies its override to the raw
  YAML dict, re-parses to a typed config, and runs find_ground_state.
- Skips points whose .jld2 already exists (resume); writes new ones
  atomically (write to .tmp, rename).

Resume happens automatically: call `run_yaml` on the same YAML a second
time and it picks up where it left off. To force a recompute, delete the
corresponding .jld2 file.
"""
function run_yaml(yaml_path::String; base_dir::String = "runs", verbose::Bool = true)
    config = load_config(yaml_path)
    run_dir = compute_run_dir(yaml_path; base_dir)
    mkpath(run_dir)

    expected = _expand_scan_points(config)
    n_expected = length(expected)

    verbose && println("Run dir: $run_dir")
    verbose && println("Expected points: $n_expected")

    # Snapshot the YAML on first run
    config_snapshot = joinpath(run_dir, "config.yaml")
    if !isfile(config_snapshot)
        cp(yaml_path, config_snapshot)
    end

    env = _env_metadata()
    use_continuation = config.spec isa ScanExperiment{OverrideScan} &&
                       config.spec.scan.continuation
    auto_rotate = config.spec isa ScanExperiment{OverrideScan} &&
                  config.spec.scan.auto_rotate_on_mz

    # Continuation chain: one prev_psi per comparison run, or single chain.
    n_chains = if config.spec isa ScanExperiment{OverrideScan} &&
                  !isempty(config.spec.scan.comparison_runs)
        length(config.spec.scan.comparison_runs)
    else
        1
    end
    chain_state = Dict{String,Any}()  # run_name → (psi, mz_actual)

    for point in expected
        psi_file = joinpath(run_dir, _point_filename(point.index, point.run_name))

        if isfile(psi_file)
            verbose && println("  ✓ $(basename(psi_file)) (cached)")
            # Load psi to maintain continuation chain even on cached points.
            if use_continuation
                d = JLD2.load(psi_file)
                chain_state[point.run_name] =
                    (psi = d["psi"], mz_actual = get(d, "mz_actual", NaN))
            end
            continue
        end

        verbose && println("  → $(basename(psi_file)) override=$(point.override)")
        started_at = _now_iso()
        t_start = time()

        prev = use_continuation ? get(chain_state, point.run_name, nothing) : nothing
        result = _compute_single_point(
            config,
            point.override,
            prev,
            auto_rotate,
        )

        finished_at = _now_iso()
        duration = time() - t_start

        tmp_file = psi_file * ".tmp"
        try
            jldopen(tmp_file, "w") do f
                f["psi"] = result.psi
                f["scan_index"] = point.index
                f["run_name"] = point.run_name
                f["override"] = point.override
                f["started_at"] = started_at
                f["finished_at"] = finished_at
                f["duration_seconds"] = duration
                f["energy"] = result.energy
                f["dE"] = result.dE
                f["dpsi"] = result.dpsi
                f["converged"] = result.converged
                f["mz_actual"] = result.mz_actual
                f["mz_target"] = result.mz_target
                for (k, v) in env
                    f["env/$k"] = v
                end
            end
            mv(tmp_file, psi_file; force = false)
        catch err
            isfile(tmp_file) && rm(tmp_file; force = true)
            rethrow(err)
        end

        if use_continuation
            chain_state[point.run_name] =
                (psi = result.psi, mz_actual = result.mz_actual)
        end

        verbose && @printf("    E=%.4f dE=%.3g conv=%s\n",
                           result.energy, result.dE, result.converged)
    end

    verbose && println("Done: $run_dir")
    run_dir
end

"""
    _compute_single_point(base_config, override, prev, auto_rotate) → NamedTuple

Apply `override` to the base config's raw YAML dict, re-parse into a typed
config, build the grid/potential, and run find_ground_state. If `prev` is
non-nothing, its psi is used as initial condition (continuation), and if
`auto_rotate` is true and the target Mz changed, the carried psi is rotated
by Δα around y so the constraint normalization can redistribute populations.
"""
function _compute_single_point(base_config::UnifiedConfig, override::Dict{String,Any},
                               prev, auto_rotate::Bool)
    raw = apply_overrides(base_config.raw_data, override)
    config = _parse_config(raw)

    grid, atom, ndim = _setup_grid(config)
    potential = _build_potential(config.ground_state.potential, ndim)
    sys = SpinSystem(atom.F)

    gs = config.ground_state
    sys_cfg = config.system
    c_dd_val = sys_cfg.ddi.c_dd === nothing ? NaN : sys_cfg.ddi.c_dd
    backend = _resolve_backend(gs.backend)
    target_mz = gs.target_magnetization

    psi_init = nothing
    if prev !== nothing
        psi_init = copy(prev.psi)
        if auto_rotate && target_mz !== nothing && !isnan(prev.mz_actual)
            F = atom.F
            α_target = acos(clamp(-target_mz / F, -1.0, 1.0))
            α_prev = acos(clamp(-prev.mz_actual / F, -1.0, 1.0))
            Δα = α_target - α_prev
            if abs(Δα) > 1e-12
                psi_init = rotate_quantization_axis(psi_init, F, 0.0, Δα)
            end
        end
    end

    gs_result = find_ground_state(;
        grid, atom,
        interactions = sys_cfg.interactions,
        zeeman = gs.zeeman,
        potential,
        dt = gs.dt,
        n_steps = gs.n_steps,
        tol = gs.tol,
        initial_state = gs.initial_state,
        init_state_params = gs.init_state_params,
        psi_init = psi_init,
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
    mz_actual = target_mz !== nothing ? magnetization(psi_host, grid, sys) : NaN

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
    run_status(run_dir) → NamedTuple

Report the progress of a run directory by counting per-point .jld2 files.
"""
function run_status(run_dir::String)
    isdir(run_dir) && return _run_status_from_dir(run_dir)
    isfile(run_dir) && return _run_status_legacy_jld2(run_dir)
    return (total = 0, done = 0, percent = 0.0, status = :missing)
end

function _run_status_from_dir(run_dir::String)
    config_path = joinpath(run_dir, "config.yaml")
    isfile(config_path) || return (total = 0, done = 0, percent = 0.0,
                                    status = :invalid)

    config = load_config(config_path)
    expected = _expand_scan_points(config)
    total = length(expected)

    done = 0
    for point in expected
        psi_file = joinpath(run_dir, _point_filename(point.index, point.run_name))
        isfile(psi_file) && (done += 1)
    end

    status = done == total ? :completed : (done == 0 ? :pending : :running)
    (
        total = total,
        done = done,
        percent = round(100 * done / max(total, 1); digits = 1),
        status = status,
    )
end

# Backward-compat: handle the older single-jld2-per-run format if encountered.
function _run_status_legacy_jld2(run_file::String)
    return (total = 0, done = 0, percent = 0.0, status = :legacy)
end

"""
    list_runs(base_dir="runs") → Vector{NamedTuple}

Enumerate all run directories under `base_dir` and report their status.
"""
function list_runs(base_dir::String = "runs")
    isdir(base_dir) || return NamedTuple[]
    entries = filter(e -> isdir(joinpath(base_dir, e)), readdir(base_dir))
    result = NamedTuple[]
    for e in entries
        path = joinpath(base_dir, e)
        try
            st = run_status(path)
            push!(result, (run_dir = path, status = st))
        catch err
            push!(result, (run_dir = path, status = (error = sprint(showerror, err),)))
        end
    end
    result
end
