export save_rotating_basis_result!, summarize_rotating_basis_result,
    launch_experiment

"""
    summarize_rotating_basis_result(io, result; label="")

Print a short one-block summary of a `run_config` result containing a
rotating_basis dynamics phase. Reports Lz/Fz ranges over the final
phase, m=+F initial/final populations, and integrator metadata
(Larmor phase per step, dt). `label` is a free-form tag printed on
the header line — typically `"<batch>/<run_name>"`.
"""
function summarize_rotating_basis_result(
    io::IO, result; label::AbstractString=""
)
    dyn = if haskey(result, :rotating_basis_dynamics)
        result[:rotating_basis_dynamics]
    elseif haskey(result, :rotating_basis_history) &&
        !isempty(result[:rotating_basis_history])
        last(result[:rotating_basis_history])
    else
        throw(
            ArgumentError(
                "summarize_rotating_basis_result: result has no rotating_basis dynamics phase"
            ),
        )
    end

    pm_hist = get(dyn, :per_m_history, Any[])
    pm_init = isempty(pm_hist) ? nothing : pm_hist[1] / sum(pm_hist[1])
    pm_final = isempty(pm_hist) ? nothing : pm_hist[end] / sum(pm_hist[end])

    dyn_hist = get(result, :dynamics_history, nothing)
    n_phases = dyn_hist === nothing ? 1 : length(dyn_hist)

    header = isempty(label) ? "=== COMPLETED ===" : "=== $label COMPLETED ==="
    println(io, "\n", header)
    println(io, "  phases: $n_phases")
    if haskey(dyn, :Lz)
        println(io, "  Lz (final phase): [",
            round(minimum(dyn[:Lz]); digits=4), ", ",
            round(maximum(dyn[:Lz]); digits=4), "]")
    end
    if haskey(dyn, :Fz)
        println(io, "  Fz (final phase): [",
            round(minimum(dyn[:Fz]); digits=4), ", ",
            round(maximum(dyn[:Fz]); digits=4), "]")
    end
    if pm_init !== nothing
        println(io, "  m=+F: ",
            round(pm_init[1]; digits=6), " -> ",
            round(pm_final[1]; digits=6))
    end
    println(io, "  Larmor phase per step: ",
        round(get(dyn, :larmor_phase_per_step, NaN); sigdigits=4))
    println(io, "  dt_used: ", get(dyn, :dt_used, NaN))
    return nothing
end

summarize_rotating_basis_result(result; kwargs...) = summarize_rotating_basis_result(
    stdout, result; kwargs...
)

"""
    launch_experiment(run_name; batch="", verbose=true, io=stdout) -> result

Per-run launcher convention. Resolves the YAML to
`runs/<batch?>/<run_name>/config.yaml` (omits the `batch` segment when
empty), runs `load_config |> run_config`, prints a rotating_basis
summary, and persists the canonical dashboard layout via
`save_rotating_basis_result!`. Returns the `run_config` result so
callers can post-process.

`save_rotating_basis_result!` is also called automatically by
`run_pipeline` since 2026-04-29 — the explicit call here is idempotent
and ensures the canonical path is written even if the pipeline branch
hasn't run.
"""
function launch_experiment(
    run_name::AbstractString;
    batch::AbstractString="",
    verbose::Bool=true,
    io::IO=stdout,
)
    run_dir = if isempty(batch)
        joinpath("runs", String(run_name))
    else
        joinpath("runs", String(batch), String(run_name))
    end
    label = isempty(batch) ? String(run_name) :
            "$(batch)/$(run_name)"

    config = load_config(joinpath(run_dir, "config.yaml"))
    result = @time run_config(config; verbose=verbose)
    summarize_rotating_basis_result(io, result; label=label)
    out_path = save_rotating_basis_result!(run_dir, result)
    println(io, "Saved (dashboard-canonical) -> $out_path")
    return result
end

"""
Concatenate consecutive rotating_basis phases (GS → tilt ramp → chirp →
steady stir) into a single timeseries dict. Each phase's `:times` is
offset by the previous phase's end-time so the merged `t` axis is
strictly increasing. Snapshots, per-m history, Lz/Fz/Fx/Fy traces are
all concatenated; scalar metadata (`:dt_used`, `:integrator`,
`:p_zeeman`, `:F_atom`, `:phi_omega`, `:theta_const`) is taken from the
LAST phase so the dashboard's "what was the steady-stir frequency"
metadata stays correct.
"""
function _concat_rotating_phases(history::AbstractVector)
    isempty(history) && return Dict{Symbol, Any}()
    length(history) == 1 && return history[1]

    out = Dict{Symbol, Any}()
    out[:times] = Float64[]
    out[:norms] = Float64[]
    out[:Lz] = Float64[]
    out[:Fz] = Float64[]
    out[:Fx] = Float64[]
    out[:Fy] = Float64[]
    out[:per_m_history] = Vector{Float64}[]
    out[:psi_snapshots] = Any[]

    t_offset = 0.0
    for (pi, phase) in enumerate(history)
        phase_times = collect(Float64, get(phase, :times, Float64[]))
        # Drop the first sample (= prev phase's last sample, t=0 in phase-local
        # coords) for all phases except the first, to avoid duplicating the
        # boundary frame.
        keep = pi == 1 ? eachindex(phase_times) : 2:length(phase_times)
        for k in keep
            push!(out[:times], phase_times[k] + t_offset)
        end
        for sym in (:norms, :Lz, :Fz, :Fx, :Fy)
            v = get(phase, sym, nothing)
            v === nothing && continue
            for k in keep
                push!(out[sym], v[k])
            end
        end
        pm_v = get(phase, :per_m_history, nothing)
        if pm_v !== nothing
            for k in keep
                push!(out[:per_m_history], pm_v[k])
            end
        end
        snaps = get(phase, :psi_snapshots, nothing)
        if snaps !== nothing
            for k in keep
                push!(out[:psi_snapshots], snaps[k])
            end
        end
        t_offset += isempty(phase_times) ? 0.0 : phase_times[end]
    end

    # Last-phase metadata wins.
    last_phase = history[end]
    for sym in (:dt_used, :integrator, :epsilon_target, :p_zeeman, :F_atom,
        :larmor_phase_per_step, :theta_const, :phi_omega)
        haskey(last_phase, sym) && (out[sym] = last_phase[sym])
    end
    out
end

"""
Concatenate consecutive lab-frame (`kind: spinor`) dynamics phases into
the same dyn dict shape used by `_concat_rotating_phases`, so a single
JLD2 writer can serve both code paths.

The spinor pipeline stores each phase as a NamedTuple with:
  - `dynamics_result :: SimulationResult`  (times, norms, magnetizations, …)
  - `snapshot_tmp_path :: Union{Nothing, String}`  scratch JLD2 with
        per-frame `frame_NNNNN` datasets (see
        `_run_dynamics_with_optional_streaming!`)
  - `snapshot_count :: Int`

We pull `:Lz`, `:Fx`, `:Fy` from a per-step trace if present, and otherwise
emit only the fields the spinor SimulationResult guarantees (times,
norms, Fz). The dashboard's reader is tolerant of missing Lz/Fx/Fy and
can recompute them from the saved snapshots on demand.
"""
function _concat_dynamics_phases(history::AbstractVector)
    isempty(history) && return Dict{Symbol, Any}()

    out = Dict{Symbol, Any}()
    out[:times] = Float64[]
    out[:norms] = Float64[]
    out[:Fz] = Float64[]
    out[:psi_snapshots] = Any[]
    out[:ensembles] = Tuple{Int, Any}[]   # (phase_index, EnsembleResult) for TWA phases

    t_offset = 0.0
    for (pi, phase) in enumerate(history)
        dr = phase.dynamics_result
        dr === nothing && continue
        phase_times = collect(Float64, dr.times)
        keep = pi == 1 ? eachindex(phase_times) : 2:length(phase_times)
        for k in keep
            push!(out[:times], phase_times[k] + t_offset)
            push!(out[:norms], dr.norms[k])
            push!(out[:Fz], dr.magnetizations[k])
        end
        t_offset += isempty(phase_times) ? 0.0 : phase_times[end]

        # Pull snapshots from the scratch JLD2 if the phase streamed them
        # to disk; otherwise fall back to the in-memory Vector held by
        # `dr.psi_snapshots`. Apply the SAME boundary-skip rule as the
        # time-aligned scalar traces above: phase pi > 1 drops its first
        # snapshot because it is the same physical state as the previous
        # phase's last snapshot. Without this the times / snapshots counts
        # disagree (observed: eu151_edh_k3_compare had 17 times vs 18
        # snapshots, causing TimeScrubber layout shift at the last frame).
        snap_start = pi == 1 ? 1 : 2
        if phase.snapshot_tmp_path !== nothing && isfile(phase.snapshot_tmp_path)
            JLD2.jldopen(phase.snapshot_tmp_path, "r") do f
                n = phase.snapshot_count
                for s in snap_start:n
                    key = "frame_" * lpad(string(s), 5, '0')
                    haskey(f, key) || continue
                    push!(out[:psi_snapshots], f[key])
                end
            end
        elseif !isempty(dr.psi_snapshots)
            for s in snap_start:length(dr.psi_snapshots)
                push!(out[:psi_snapshots], dr.psi_snapshots[s])
            end
        end

        # TWA ensemble pass-through: record (phase_index, EnsembleResult) so
        # the JLD2 writer can persist `mean`, `variance`, and `n_trajectories`
        # per observable. Without this the per-phase ensemble info is lost
        # and downstream analysis only sees the last trajectory.
        if hasproperty(phase, :ensemble_result) && phase.ensemble_result !== nothing
            push!(out[:ensembles], (pi, phase.ensemble_result))
        end
    end
    out
end

"""
Canonical save layout for `kind: rotating_basis` (Option γ) dynamics
results.

Writes to `<run_dir>/result.jld2` in the streamed snapshot layout that
the dashboard's `dynamics/psi_snapshots_streamed/...` reader path
expects, plus — only when no point writer has claimed the name — a
`point_001.jld2` symlink so the run shows up in the dashboard's run list.

The canonical layout:
    psi                                          # GS / first snapshot (4D)
    dynamics/times                               # Vector{Float64}
    dynamics/norms                               # Vector{Float64}
    dynamics/Lz                                  # Vector{Float64}
    dynamics/Fz                                  # Vector{Float64}
    dynamics/Fx, dynamics/Fy                     # optional Vector{Float64}
    dynamics/per_m_history                       # Matrix (D × T)
    dynamics/component_populations               # Matrix (T × D), normalised
    dynamics/psi_snapshots_streamed/n_snapshots
    dynamics/psi_snapshots_streamed/spatial_shape
    dynamics/psi_snapshots_streamed/n_components
    dynamics/psi_snapshots_streamed/frame_00001  # ComplexF32 4D
    dynamics/psi_snapshots_streamed/frame_00002
    ...
    dynamics/integrator_meta/dt_used             # ε / dt / Larmor info
    dynamics/integrator_meta/integrator
    dynamics/integrator_meta/epsilon_target
    dynamics/integrator_meta/p_zeeman
    dynamics/integrator_meta/F_atom
    dynamics/integrator_meta/larmor_phase_per_step

Use this from any per-run launcher that consumes the `:rotating_basis_dynamics`
Dict produced by `run_config`. The compatibility
`launch_thesis_run.jl` / `launch_phi_omega_run.jl` saved a Vector of
4D arrays at the top level; that layout still works in the dashboard
via the compatibility fallback, but new code should write canonical here.
"""
function save_rotating_basis_result!(
    run_dir::String, result;
    snapshot_precision::Symbol=:f32,
    compress::Bool=true,
)
    # Accepts either AbstractDict (e.g. `run_pipeline`'s internal results
    # dict) or NamedTuple (`run_config(...)` return value). Both expose
    # `haskey` and `getindex`, so we don't constrain the type.
    #
    # Two pipeline paths produce dashboard-saveable dynamics results:
    #
    #   - `kind: rotating_basis` populates `:rotating_basis_history`
    #     (Vector{Dict}) — see RotatingBasisDynamicsStep dispatch.
    #   - `kind: spinor`         populates `:dynamics_history`
    #     (Vector{NamedTuple{(:dynamics_result, :snapshot_tmp_path, ...)}}) —
    #     see DynamicsStep dispatch.
    #
    # We dispatch here instead of in the caller so any auto-save hook
    # (pipeline_runner.jl) can call this function unconditionally.
    if haskey(result, :rotating_basis_history) ||
        haskey(result, :rotating_basis_dynamics)
        history = if haskey(result, :rotating_basis_history)
            result[:rotating_basis_history]
        else
            [result[:rotating_basis_dynamics]]
        end
        isempty(history) && throw(
            ArgumentError(
                "save_rotating_basis_result!: no rotating_basis dynamics phases in result"),
        )
        dyn = _concat_rotating_phases(history)
    elseif haskey(result, :dynamics_history)
        history = result[:dynamics_history]
        isempty(history) && throw(
            ArgumentError(
                "save_rotating_basis_result!: no spinor dynamics phases in result"),
        )
        dyn = _concat_dynamics_phases(history)
    else
        throw(
            ArgumentError(
                "save_rotating_basis_result!: result has neither :rotating_basis_dynamics " *
                "nor :dynamics_history (was the pipeline a ground-state-only run?)"),
        )
    end

    isdir(run_dir) || mkpath(run_dir)
    out_path = joinpath(run_dir, "result.jld2")
    # Cutover step 2. This was the ONE payload writer in the tree with no
    # tmp+rename at all: `jldopen(out_path, "w")` built a multi-GB file in place,
    # so a kill mid-write left a truncated `result.jld2` that `_has_result`
    # admitted. Same directory as the final path, so this `mv` is a real
    # `rename(2)` — unlike the point writers', which fall back to `cp` when
    # `SPINORBEC_SCRATCH_DIR` points at another filesystem.
    tmp_path = out_path * ".tmp." * string(getpid())

    snaps = get(dyn, :psi_snapshots, Any[])
    n_snaps = length(snaps)
    pm_hist = get(dyn, :per_m_history, Any[])
    pm_mat = isempty(pm_hist) ? zeros(Float64, 0, 0) : hcat(pm_hist...)

    # Convert snapshot precision once up front.
    snap_eltype = snapshot_precision === :f64 ? ComplexF64 : ComplexF32

    # Snapshot data is the bulk of the file (~tens of MB / frame at 48³ D=13).
    # Default to ZstdCompressor at the JLD2 default level — typical 30-50%
    # reduction on smooth-density data, ~5% CPU overhead per frame. Set
    # `compress=false` to opt out (e.g. when bypassing for performance bench).
    compressor = compress ? ZstdCompressor() : nothing

    try
        JLD2.jldopen(tmp_path, "w"; compress=compressor) do f
            # GS (or first snapshot) for the dashboard's volume renderer entry point.
            if n_snaps >= 1
                f["psi"] = Array{ComplexF64}(snaps[1])
            end

            # The ground-state provenance a campaign guard reads. This writer
            # owns `result.jld2` for BOTH `kind: rotating_basis` and
            # `kind: spinor`-with-dynamics (runner.jl:294), and until 2026-08-20
            # it wrote neither key — so `energy` and `converged` were simply
            # ABSENT from every dynamics run's result file, and a reader using
            # `get(f, "energy", NaN)` got its own default back and read it as a
            # diverged run. Written only when the pipeline actually produced
            # them: absent must keep meaning "no ground state ran", which is what
            # `model/complete.jl:222` uses it for.
            let e = get(result, :ground_state_energy, nothing)
                e === nothing || (f["energy"] = e)
            end
            let c = get(result, :ground_state_converged, nothing)
                c === nothing || (f["converged"] = c)
            end
            let g = get(result, :ground_state_grad_norm, nothing)
                g === nothing || (f["grad_norm"] = g)
            end

            f["dynamics/times"] = collect(Float64, dyn[:times])
            f["dynamics/norms"] = collect(Float64, dyn[:norms])
            # Lz / Fx / Fy are populated by the rotating_basis path but absent in
            # the lab-frame spinor path (only times/norms/Fz are guaranteed by
            # SimulationResult). Guard each write so spinor dynamics still saves.
            haskey(dyn, :Lz) && (f["dynamics/Lz"] = collect(Float64, dyn[:Lz]))
            haskey(dyn, :Fz) && (f["dynamics/Fz"] = collect(Float64, dyn[:Fz]))
            haskey(dyn, :Fx) && (f["dynamics/Fx"] = collect(Float64, dyn[:Fx]))
            haskey(dyn, :Fy) && (f["dynamics/Fy"] = collect(Float64, dyn[:Fy]))
            if !isempty(pm_mat)
                f["dynamics/per_m_history"] = pm_mat
            end

            # Per-frame populations (rows = time, cols = m component) for the
            # dashboard's spinor-population time-series tab.
            if n_snaps >= 1
                psi1 = snaps[1]
                D = size(psi1)[end]
                ndim = ndims(psi1) - 1
                n_pts = ntuple(d -> size(psi1, d), ndim)
                pops = zeros(Float64, n_snaps, D)
                for (s, psi) in enumerate(snaps)
                    total = sum(abs2, psi)
                    for c in 1:D
                        idx = ntuple(d -> d <= ndim ? Colon() : c, ndim + 1)
                        pops[s, c] = sum(abs2, view(psi, idx...)) / max(total, DENOM_FLOOR)
                    end
                end
                f["dynamics/component_populations"] = pops

                # Streamed snapshot layout (one HDF5 dataset per frame).
                f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_snaps
                f["dynamics/psi_snapshots_streamed/spatial_shape"] = collect(Int, n_pts)
                f["dynamics/psi_snapshots_streamed/n_components"] = D
                for (s, psi) in enumerate(snaps)
                    key = "dynamics/psi_snapshots_streamed/frame_" *
                          lpad(string(s), 5, '0')
                    f[key] = Array{snap_eltype}(psi)
                end
            end

            # Integrator metadata (added 2026-04-28 audit) — preserved if present.
            for (src_key, dst_key) in (
                (:dt_used, "dt_used"),
                (:integrator, "integrator"),
                (:epsilon_target, "epsilon_target"),
                (:p_zeeman, "p_zeeman"),
                (:F_atom, "F_atom"),
                (:larmor_phase_per_step, "larmor_phase_per_step"),
                (:theta_const, "theta_const"),
                (:phi_omega, "phi_omega"),
            )
                haskey(dyn, src_key) && (f["dynamics/integrator_meta/" * dst_key] = dyn[src_key])
            end

            # TWA ensemble persistence (added 2026-05-07): if any dynamics phase
            # ran as a Truncated Wigner ensemble, write per-phase mean / variance /
            # n_trajectories per observable. Without this only the last
            # trajectory's psi survived through `dr.psi_snapshots`, and the
            # ensemble statistics computed via Welford accumulation were lost
            # at save time.
            ensembles = get(dyn, :ensembles, Tuple{Int, Any}[])
            for (phase_idx, ens) in ensembles
                base = "dynamics/ensemble/phase_" * lpad(string(phase_idx), 2, '0')
                f[base * "/n_trajectories"] = ens.n_trajectories
                f[base * "/times"] = collect(Float64, ens.times)
                for (sym, mean_traj) in ens.mean
                    key = base * "/" * String(sym) * "/mean"
                    # Each entry is a Vector of T arrays (one per snapshot time).
                    # Stack into a higher-rank array so it's a single dataset.
                    isempty(mean_traj) && continue
                    shape = size(mean_traj[1])
                    stacked = zeros(Float64, shape..., length(mean_traj))
                    for (t, arr) in enumerate(mean_traj)
                        selectdim(stacked, ndims(stacked), t) .= arr
                    end
                    f[key] = stacked
                end
                for (sym, var_traj) in ens.var
                    key = base * "/" * String(sym) * "/variance"
                    isempty(var_traj) && continue
                    shape = size(var_traj[1])
                    stacked = zeros(Float64, shape..., length(var_traj))
                    for (t, arr) in enumerate(var_traj)
                        selectdim(stacked, ndims(stacked), t) .= arr
                    end
                    f[key] = stacked
                end
            end
        end
        mv(tmp_path, out_path; force=true)
    catch err
        isfile(tmp_path) && rm(tmp_path; force=true)
        rethrow(err)
    end

    # Dashboard's run-list filter requires a `point_NNN.jld2` file. Symlink
    # to the canonical result so we don't duplicate the multi-GB snapshot data.
    #
    # NEVER over a real file, and this is a data-integrity fix, not a tidy-up.
    # `run_pipeline` calls this once per scan point (`runner.jl:218-231`), and
    # the unconditional `rm` it replaces fired on every one of them: point 2's
    # save deleted the REAL `point_001.jld2` the scan writer had just produced
    # and re-pointed the name at point 2's `result.jld2`. Reading `point_001`
    # then returned the LAST point's data under point 1's name. Verified in the
    # store before the fix: 3 symlinked `point_001.jld2` under `runs/`, one of
    # them in `runs/eu151_edh_k3_compare`, a 3-point scan.
    #
    # `point_001.jld2` belongs to the point writer (`run_registry.jl`), which
    # writes it AFTER `run_pipeline` returns. This publishes the dashboard alias
    # only into a name that writer has not claimed — which is exactly the
    # single-run case the alias was added for.
    point_link = joinpath(run_dir, "point_001.jld2")
    if !islink(point_link) && !ispath(point_link)
        symlink("result.jld2", point_link)
    end

    # LAST, after the alias (cutover step 2, invariant 4). `result.jld2` is one
    # of the two names `Experiment`'s admission tests, so without a marker here
    # every dynamics run would stay arm-(b) forever. Only `result.jld2` is named:
    # `point_001.jld2` is either a symlink to it (and `filesize` follows symlinks,
    # so naming both would record the same bytes twice) or a real point payload
    # that `_finish_point!` marks for itself.
    #
    # `:interrupted` is threaded through `_step_dispatch!`; a killed RTP loop
    # returns normally with a final snapshot recorded, so this is the only thing
    # that distinguishes it from a finished run.
    if get(result, :interrupted, false) === true
        @warn "dynamics run was INTERRUPTED — tombstoning result.jld2 so it is " *
            "recomputed rather than served" run_dir
        try
            write_incomplete_marker(out_path, [out_path];
                kind="dynamics", reason="the run was INTERRUPTED mid-evolution")
        catch err
            @warn "tombstone write failed" out_path exception = err
        end
    else
        try
            # Same verdict as the point marker: a `result.jld2` produced by a
            # pipeline whose first step was a ground state inherits that solve's
            # opinion, and `Experiment` admits this name. A dynamics-only
            # pipeline gets `nothing`.
            write_complete_marker(out_path, [out_path]; kind="dynamics",
                verdict=gs_verdict(result))
        catch err
            @warn "completion marker write failed (non-fatal); result.jld2 will be " *
                "admitted as :unmarked" out_path exception = err
        end
    end

    out_path
end
