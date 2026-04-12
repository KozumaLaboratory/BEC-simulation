# --- Phase Scan Utilities ---
#
# OverrideScan iteration is shared with run_registry.jl: each scan point is
# an override map applied to the raw YAML dict, re-parsed into a typed
# config, and run. ConstrainedJzScan uses its own bisection loop because
# Jz targets are resolved by bisection on Ω, not by config patching.

function _open_csv(dir, filename)
    open(joinpath(dir, filename), "w")
end

function _write_csv(io, values)
    row = join(values, ",")
    if io !== nothing
        println(io, row)
        flush(io)
    end
    row
end

# --- OverrideScan dispatch (in-memory via pipeline; no JLD2, returns Vector) ---

function _run_scan(
    config::UnifiedConfig{ScanExperiment{OverrideScan}},
    grid,
    atom,
    sm,
    potential,
    ndim;
    verbose::Bool = true,
)
    scan = config.spec.scan
    has_comparison = !isempty(scan.comparison_runs)
    n_points = length(scan.points)
    verbose && println("  override scan: $n_points points" *
                       (has_comparison ? " × $(length(scan.comparison_runs)) runs" : ""))

    results = NamedTuple[]

    for (i, point_override) in enumerate(scan.points)
        runs = has_comparison ? scan.comparison_runs : [("", Dict{String,Any}())]
        for (run_name, cmp_override) in runs
            override = merge(point_override, cmp_override)

            # Apply override to raw YAML, strip scan, run as pipeline or single config
            raw = apply_overrides(config.raw_data, override)
            raw_inner = get(raw, "experiment", raw)
            raw_single = copy(raw_inner)
            delete!(raw_single, "scan")
            delete!(raw_single, "stability")

            point_config = _parse_config(Dict("experiment" => raw_single))
            point_result = run_config(point_config; verbose = false)

            psi = if haskey(point_result, :psi)
                point_result.psi
            else
                zeros(ComplexF64, 1)
            end
            energy = get(point_result, :ground_state_energy, NaN)
            converged = get(point_result, :ground_state_converged, true)

            info = classify_phase_detailed(psi, atom.F, grid, sm;
                sampling = config.observables.spatial_sampling)

            verbose && println("  [$i] $run_name E=$(round(energy; sigdigits=6)) phase=$(info.phase)")

            push!(results, (
                index = i, run_name = run_name, override = override,
                energy = energy, converged = converged,
                phase_info = info, psi = psi,
                mz_actual = NaN, mz_target = NaN,
            ))
        end
    end

    results
end

# --- ConstrainedJzScan dispatch ---

function _run_scan(
    config::UnifiedConfig{ScanExperiment{ConstrainedJzScan}},
    grid,
    atom,
    sm,
    potential,
    ndim;
    verbose::Bool = true,
)
    scan = config.spec.scan
    verbose && println("  Jz scan: $(length(scan.target_values)) targets")

    io = config.output.csv ? _open_csv(config.output.dir, "scan_jz.csv") : nothing
    cols = [
        :target_Jz,
        :actual_Jz,
        :omega,
        :energy,
        :phase,
        :point_group,
        :spin_order,
        :converged,
    ]
    header = _write_csv(io, cols)
    verbose && println(header)

    gs = config.ground_state
    sys = config.system
    c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd

    results = NamedTuple[]

    for jz_target in scan.target_values
        r = find_ground_state(;
            grid,
            atom,
            interactions = sys.interactions,
            zeeman = gs.zeeman,
            potential,
            dt = gs.dt,
            n_steps = gs.n_steps,
            tol = gs.tol,
            initial_state = gs.initial_state,
            enable_ddi = something(gs.enable_ddi, sys.ddi.enabled),
            c_dd = c_dd_val,
            secular_ddi = sys.ddi.secular,
            quasi_2d_ddi = sys.ddi.quasi_2d,
            l_z_ddi = sys.ddi.l_z,
            fft_flags = FFTW.ESTIMATE,
            target_magnetization = gs.target_magnetization,
            rotating_frame_omega = gs.rotating_frame_omega,
            target_Jz = jz_target,
            Jz_tol = scan.tolerance,
            Jz_max_iter = scan.max_iter,
            Jz_omega_range = scan.omega_range,
        )

        psi = r.workspace.state.psi
        info = classify_phase_detailed(
            psi,
            atom.F,
            grid,
            sm;
            sampling = config.observables.spatial_sampling,
        )

        row_vals = Any[
            round(jz_target; digits = 2),
            round(r.Jz; digits = 4),
            round(r.omega; sigdigits = 4),
            round(r.energy; sigdigits = 8),
            info.phase,
            info.point_group,
            round(info.spin_order; sigdigits = 4),
            r.converged,
        ]
        row = _write_csv(io, row_vals)
        verbose && println(row)

        push!(
            results,
            (
                target_Jz = jz_target,
                actual_Jz = r.Jz,
                omega = r.omega,
                energy = r.energy,
                converged = r.converged,
                phase_info = info,
            ),
        )

        if config.output.save_psi
            JLD2.jldsave(
                joinpath(config.output.dir, "psi_jz_$(round(jz_target; digits=2)).jld2");
                psi = copy(psi),
            )
        end
    end

    io !== nothing && close(io)
    results
end
