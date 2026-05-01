# --- ITP checkpoints: save / load / resume / refine ---

function _save_itp_checkpoint(dir, ws, step, n_steps, energy, dE, dpsi, converged, tol)
    psi_host = _to_host(ws.state.psi)
    fname = joinpath(dir, "itp_checkpoint.jld2")
    tmp = fname * ".tmp"
    try
        jldopen(tmp, "w") do f
            f["psi"] = psi_host
            f["step"] = step
            f["n_steps"] = n_steps
            f["energy"] = energy
            f["dE"] = isnan(dE) ? Inf : dE
            f["dpsi"] = isnan(dpsi) ? Inf : dpsi
            f["converged"] = converged
            f["dt"] = ws.sim_params.dt
            f["tol"] = tol
            f["atom_name"] = ws.atom.name
            f["grid_n_points"] = ws.grid.config.n_points
            f["grid_box_size"] = ws.grid.config.box_size
            f["c0"] = ws.interactions.c0
            f["c1"] = ws.interactions.c1
        end
        mv(tmp, fname; force=true)
    catch err
        isfile(tmp) && rm(tmp; force=true)
        @warn "Failed to save ITP checkpoint: $err"
    end
end

"""
    load_itp_checkpoint(path) -> ITPCheckpoint

Load an ITP checkpoint from a JLD2 file (or directory containing itp_checkpoint.jld2).
"""
function load_itp_checkpoint(path::String)
    fname = isdir(path) ? joinpath(path, "itp_checkpoint.jld2") : path
    isfile(fname) || throw(ArgumentError("Checkpoint not found: $fname"))
    d = JLD2.load(fname)
    ITPCheckpoint(
        d["psi"],
        d["step"],
        d["n_steps"],
        d["energy"],
        get(d, "dE", NaN),
        get(d, "dpsi", NaN),
        get(d, "converged", false),
        d["dt"],
        get(d, "tol", 1e-10),
    )
end

"""
    resume_ground_state(checkpoint; grid, atom, interactions, kwargs...) -> NamedTuple

Resume ITP from a checkpoint. The checkpoint can be:
- An `ITPCheckpoint` (from `load_itp_checkpoint`)
- A file path or directory containing `itp_checkpoint.jld2`

Requires the same `grid`, `atom`, `interactions` (and other workspace params)
as the original run. `n_steps`, `tol`, `dt` default to the checkpoint values.
"""
function resume_ground_state(checkpoint::ITPCheckpoint;
    n_steps::Int=checkpoint.n_steps,
    tol::Float64=checkpoint.tol,
    dt::Float64=checkpoint.dt,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    kwargs...,
)
    checkpoint.converged &&
        @warn "Checkpoint already converged (dE=$(checkpoint.dE)). Use refine_ground_state to continue with tighter tol."

    remaining = n_steps - checkpoint.step
    remaining <= 0 && return (
        workspace=nothing,
        converged=checkpoint.converged,
        energy=checkpoint.energy,
        dE=checkpoint.dE,
        dpsi=checkpoint.dpsi,
        interrupted=false,
        last_step=checkpoint.step,
    )

    find_ground_state(;
        psi_init=copy(checkpoint.psi),
        dt, n_steps, tol,
        _start_step=checkpoint.step,
        _checkpoint_dir=checkpoint_dir,
        _checkpoint_every=checkpoint_every,
        kwargs...,
    )
end

function resume_ground_state(path::String; kwargs...)
    resume_ground_state(load_itp_checkpoint(path); kwargs...)
end

"""
    refine_ground_state(result; tol, dt, n_steps, kwargs...) -> NamedTuple

Take an existing ground state result and continue ITP with tighter parameters.
The `result` should be a NamedTuple from `find_ground_state` (must have `.workspace`).

Typical usage: converged at tol=1e-8, refine to tol=1e-10.
"""
function refine_ground_state(result::NamedTuple;
    tol::Float64=result.workspace.sim_params.imaginary_time ? 1e-12 : 1e-10,
    dt::Float64=result.workspace.sim_params.dt,
    n_steps::Int=result.workspace.sim_params.n_steps,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    on_step::Union{Nothing, Function}=nothing,
    target_magnetization::Union{Nothing, Float64}=nothing,
)
    ws = result.workspace
    println(
        "  Refining: E=$(round(result.energy; sigdigits=8)), dE=$(result.dE), tol_new=$tol, dt=$dt"
    )
    flush(stdout)

    ws_new = if dt != ws.sim_params.dt
        _rebuild_workspace_with_dt(ws, dt)
    else
        ws
    end

    _run_itp_loop!(ws_new, n_steps, tol, on_step, target_magnetization;
        start_step=0,
        checkpoint_dir,
        checkpoint_every,
    )
end

