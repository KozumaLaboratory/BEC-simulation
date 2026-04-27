# --- Experiment utility functions ---

function scale_interactions_quasi_2d(ip::InteractionParams, l_z::Float64)
    factor = 1.0 / (sqrt(2π) * l_z)
    if ip.c_lhy != 0.0
        @warn "c_lhy scaling under quasi-2D is approximate; 2D LHY requires logarithmic treatment"
    end
    InteractionParams(
        ip.c0 * factor,
        ip.c1 * factor,
        ip.c_lhy * factor,
        isempty(ip.c_extra) ? Float64[] : ip.c_extra .* factor,
    )
end

function _normalize_grid(n_raw, box_raw)
    n_pts = n_raw isa Vector ? Int.(n_raw) : Int[Int(n_raw)]
    box_size = box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    length(n_pts) == length(box_size) ||
        throw(ArgumentError("grid n and box must have the same length"))
    (n_pts, box_size)
end

function _add_noise!(psi, amplitude, n_components, ndim, grid)
    n_pts = ntuple(d -> size(psi, d), ndim)
    dV = cell_volume(grid)
    dominant = argmax([
        sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) for c in 1:n_components
    ])
    for c in 1:n_components
        c == dominant && continue
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .+= amplitude .* randn(ComplexF64, n_pts)
    end
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
end

function seed_noise(
    psi_gs,
    n_components::Int,
    ndim::Int,
    grid::Grid;
    amplitude::Float64=0.001,
    seed::Int=42,
)
    psi = copy(psi_gs)
    Random.seed!(seed)
    _add_noise!(psi, amplitude, n_components, ndim, grid)
    psi
end

"""Save unit metadata to a JLD2 file for reproducibility."""
function _save_units_metadata!(f, data::Dict)
    gs = nothing
    pipeline = get(data, "pipeline", [])
    for step in pipeline
        step isa Dict || continue
        if haskey(step, "ground_state")
            gs = step["ground_state"]
            break
        end
    end
    gs === nothing && return nothing

    inter = get(gs, "interactions", Dict())
    omega_ref_raw = get(inter, "omega_ref", nothing)
    omega_ref_raw === nothing && return nothing
    omega_ref = Float64(omega_ref_raw)

    atom_name = get(gs, "atom", nothing)
    atom_name === nothing && return nothing
    atom = resolve_atom(Symbol(atom_name))

    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    f["units/system"] = "dimensionless"
    f["units/omega_ref_hz"] = omega_ref / (2π)
    f["units/omega_ref_rad_s"] = omega_ref
    f["units/a_ho_m"] = a_ho
    f["units/time_unit_s"] = 1.0 / omega_ref
    f["units/energy_unit_J"] = Units.HBAR * omega_ref
    f["units/atom"] = String(atom_name)
    N_raw = get(inter, "N_atoms", nothing)
    N_raw !== nothing && (f["units/N_atoms"] = Int(N_raw))
end

"""
Persist pipeline analyzer outputs under `analyze/<name>/<field>` so phase
diagrams can be reconstructed from disk without re-running simulations.

Silently skips unknown analyzer keys (e.g. pipeline-internal entries
`:ground_state_energy`, `:dynamics_result`, `:dynamics_workspace`). Only
fields that JLD2 can persist losslessly are written; Dict/NamedTuple/
Number/String/Symbol/Vector-of-these are supported.
"""
function _save_analyzer_results!(f, result)
    analyzer_names = (:tomography, :faraday, :energy_decomposition, :phase_classify,
        :stability, :bogoliubov, :bogoliubov_mode, :bogoliubov_dispersion,
        :non_abelian_homotopy, :monopole_charge, :winding_field,
        :droplet_profile, :synthetic_dim, :skyrmion_detect)
    for name in analyzer_names
        haskey(result, name) || continue
        val = result[name]
        _write_jld2_value!(f, "analyze/$(name)", val)
    end
    _save_dynamics_timeseries!(f, result)
end

"""
Save dynamics time series (times, energies, magnetizations, component populations)
from `dynamics_result` so Mz(t) and E(t) can be analysed from disk.

Per-component populations are computed from psi_snapshots (13 floats per snapshot).

Full psi snapshots are persisted only when the run was invoked with
`save_psi_snapshots: true` (the caller stashes this as
`result[:save_psi_snapshots]`). When saved they are downcast to ComplexF32
and packed into one 5D array `dynamics/psi_snapshots` of shape
`(n_pts..., n_comp, n_snaps)` — halves the disk footprint vs ComplexF64
and keeps numerical precision fine for visualisation.
"""
function _save_dynamics_timeseries!(f, result)
    haskey(result, :dynamics_result) || return nothing
    dr = result[:dynamics_result]
    hasproperty(dr, :times) || return nothing

    # If the pipeline ran multiple dynamics steps, walk
    # `result[:dynamics_history]` to concatenate every step's time series
    # into one continuous timeline starting at GS (t=0). Without this
    # only the LAST step's snapshots / times survive on disk — the
    # dashboard then shows the steady-state stir alone instead of the
    # full GS → tilt → chirp → stir animation. Caught 2026-04-27 on
    # Klaus 2022.
    history = get(result, :dynamics_history, nothing)
    if history !== nothing && length(history) > 1 &&
            all(h -> hasproperty(h.dynamics_result, :times), history)
        return _save_dynamics_timeseries_multi!(f, history, result)
    end

    f["dynamics/times"] = collect(Float64, dr.times)
    f["dynamics/energies"] = collect(Float64, dr.energies)
    f["dynamics/norms"] = collect(Float64, dr.norms)
    f["dynamics/magnetizations"] = collect(Float64, dr.magnetizations)

    # Snapshots arrive via two paths now:
    #   (A) Streamed: the dynamics step wrote ComplexF32 frames to a
    #       scratch JLD2 file on the fly (keeps peak host RAM at one
    #       frame), and :snapshot_tmp_path + :snapshot_count are set.
    #       We copy those frames into the main file and delete the
    #       scratch. Component populations are derived from the F32
    #       buffers as we stream them — one pass, no double-load.
    #   (B) Legacy in-memory: `dr.psi_snapshots` is populated and we
    #       do the old write-at-end (still streamed into the final
    #       file, but the source vector holds all 154×ComplexF64 in
    #       host RAM).
    tmp_path = get(result, :snapshot_tmp_path, nothing)
    save_psi = get(result, :save_psi_snapshots, false)

    if save_psi && tmp_path !== nothing && isfile(tmp_path)
        jldopen(tmp_path, "r") do src
            n_snaps = Int(src["n_snapshots"])
            n_pts_v = Int.(src["spatial_shape"])
            D = Int(src["n_components"])
            ndim = length(n_pts_v)

            pops = zeros(Float64, n_snaps, D)
            f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_snaps
            f["dynamics/psi_snapshots_streamed/spatial_shape"] = n_pts_v
            f["dynamics/psi_snapshots_streamed/n_components"] = D

            for s in 1:n_snaps
                skey = "frame_" * lpad(string(s), 5, '0')
                frame = src[skey]::Array{ComplexF32}
                f["dynamics/psi_snapshots_streamed/" * skey] = frame
                total = sum(abs2, frame)
                for c in 1:D
                    idx = ntuple(d -> d <= ndim ? (1:n_pts_v[d]) : c, ndim + 1)
                    pops[s, c] = sum(abs2, view(frame, idx...)) / max(total, 1e-30)
                end
            end
            f["dynamics/component_populations"] = pops
        end
        rm(tmp_path; force=true)
    elseif hasproperty(dr, :psi_snapshots) && !isempty(dr.psi_snapshots)
        # Legacy in-memory path. `pops` is computed first from F64
        # buffers, then each frame is copied to disk as F32 one at a
        # time — no intermediate 5D array.
        psi1 = dr.psi_snapshots[1]
        D = size(psi1)[end]
        ndim = ndims(psi1) - 1
        n_pts = ntuple(d -> size(psi1, d), ndim)
        n_snaps = length(dr.psi_snapshots)
        pops = zeros(Float64, n_snaps, D)
        for (s, psi) in enumerate(dr.psi_snapshots)
            total = sum(abs2, psi)
            for c in 1:D
                idx = ntuple(d -> d <= ndim ? (1:n_pts[d]) : c, ndim + 1)
                pops[s, c] = sum(abs2, view(psi, idx...)) / max(total, 1e-30)
            end
        end
        f["dynamics/component_populations"] = pops

        if save_psi
            f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_snaps
            f["dynamics/psi_snapshots_streamed/spatial_shape"] = collect(n_pts)
            f["dynamics/psi_snapshots_streamed/n_components"] = D
            buf = Array{ComplexF32}(undef, n_pts..., D)
            for (s, psi) in enumerate(dr.psi_snapshots)
                buf .= ComplexF32.(psi)
                key = "dynamics/psi_snapshots_streamed/frame_" *
                      lpad(string(s), 5, '0')
                f[key] = buf
            end
        end
    end
end

"""
Multi-step variant of `_save_dynamics_timeseries!`. Concatenates every
dynamics step's time series + ψ snapshots into one continuous record:

  - `dynamics/times`     — Step1.times ∪ Step2.times[2:end] ∪ … with
                           cumulative time offset, so frame_NNNNN aligns
                           with `times[NNNNN+1]` (GS at times[1]=0).
  - `dynamics/energies`, `dynamics/norms`, `dynamics/magnetizations`
                         — same concatenation as times.
  - `dynamics/psi_snapshots_streamed/frame_NNNNN`
                         — globally indexed across all steps that opted
                           in via `save_psi_snapshots: true`. Steps that
                           opted out skip frame contribution but their
                           times/energies still join the timeline.
  - `dynamics/component_populations` — (n_global_frames × D) populations.
"""
function _save_dynamics_timeseries_multi!(f, history, result)
    # --- Concatenate time-series across all dynamics steps -----------
    n_steps = length(history)
    n_pts_v_ref = nothing
    D_ref = nothing

    times = Float64[]
    energies = Float64[]
    norms = Float64[]
    mags = Float64[]
    t_offset = 0.0
    for (i, h) in enumerate(history)
        dr = h.dynamics_result
        local_times = collect(Float64, dr.times)
        local_E = collect(Float64, dr.energies)
        local_N = collect(Float64, dr.norms)
        local_M = collect(Float64, dr.magnetizations)
        # Skip the leading t=0 of every step except the first to avoid
        # duplicating the boundary point shared with the previous step.
        start = i == 1 ? 1 : 2
        append!(times, local_times[start:end] .+ t_offset)
        append!(energies, local_E[start:end])
        append!(norms, local_N[start:end])
        append!(mags, local_M[start:end])
        t_offset += local_times[end]
    end
    f["dynamics/times"] = times
    f["dynamics/energies"] = energies
    f["dynamics/norms"] = norms
    f["dynamics/magnetizations"] = mags

    # --- Walk per-step scratch JLD2s and copy frames into one group ---
    n_global = 0
    pops_rows = Vector{Vector{Float64}}()
    for h in history
        h.save_psi_snapshots || continue
        tmp_path = h.snapshot_tmp_path
        (tmp_path === nothing || !isfile(tmp_path)) && continue
        jldopen(tmp_path, "r") do src
            n_local = Int(src["n_snapshots"])
            n_pts_v = Int.(src["spatial_shape"])
            D = Int(src["n_components"])
            if n_pts_v_ref === nothing
                n_pts_v_ref = n_pts_v
                D_ref = D
                f["dynamics/psi_snapshots_streamed/spatial_shape"] = n_pts_v
                f["dynamics/psi_snapshots_streamed/n_components"] = D
            else
                (n_pts_v == n_pts_v_ref && D == D_ref) ||
                    error("snapshot shape changed across steps: " *
                          "$(n_pts_v_ref)/$(D_ref) → $(n_pts_v)/$D")
            end
            ndim = length(n_pts_v)
            for s in 1:n_local
                n_global += 1
                src_key = "frame_" * lpad(string(s), 5, '0')
                dst_key = "dynamics/psi_snapshots_streamed/frame_" *
                          lpad(string(n_global), 5, '0')
                frame = src[src_key]::Array{ComplexF32}
                f[dst_key] = frame
                total = sum(abs2, frame)
                row = Vector{Float64}(undef, D)
                for c in 1:D
                    idx = ntuple(d -> d <= ndim ? (1:n_pts_v[d]) : c, ndim + 1)
                    row[c] = sum(abs2, view(frame, idx...)) / max(total, 1e-30)
                end
                push!(pops_rows, row)
            end
        end
        rm(tmp_path; force=true)
    end

    if n_global > 0
        f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_global
        D = D_ref::Int
        pops = Matrix{Float64}(undef, n_global, D)
        for (i, row) in enumerate(pops_rows)
            pops[i, :] .= row
        end
        f["dynamics/component_populations"] = pops
    end
    return nothing
end

function _write_jld2_value!(f, prefix::String, v::NamedTuple)
    for (k, x) in pairs(v)
        _write_jld2_value!(f, "$(prefix)/$(k)", x)
    end
end

function _write_jld2_value!(f, prefix::String, v::Dict)
    for (k, x) in v
        _write_jld2_value!(f, "$(prefix)/$(k)", x)
    end
end

function _write_jld2_value!(f, key::String, v::Union{Number, String, Bool, Symbol})
    f[key] = v isa Symbol ? String(v) : v
end

function _write_jld2_value!(f, key::String, v::Tuple)
    f[key] = collect(v)
end

function _write_jld2_value!(f, key::String, v::AbstractArray)
    eltype_ok = eltype(v) <: Union{Number, String, Bool}
    eltype_ok && (f[key] = Array(v))
end

_write_jld2_value!(::Any, ::String, ::Any) = nothing  # silently skip unsupported

"""Print ground state summary with populations."""
function _print_gs_summary(psi, grid, atom, gs)
    F = atom.F
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = grid.config.n_points
    ndim = length(n_pts)
    pops = [sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) * dV for c in 1:D]
    total = sum(pops)
    pops ./= total
    sorted_idx = sortperm(pops; rev=true)
    top = [(F - (i-1), pops[i]) for i in sorted_idx[1:min(3, D)]]
    pop_str = join(["m=$(m): $(round(p*100; digits=1))%" for (m, p) in top], ", ")
    mz = sum((F - (c-1)) * pops[c] for c in 1:D)
    println(
        "  E=$(round(gs.energy; sigdigits=6)) conv=$(gs.converged) Mz=$(round(mz; digits=2)) [$pop_str]"
    )
end
