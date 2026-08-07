# PipelineStep dispatch for the rotating_basis kind. Both methods are
# kept `@noinline` to maintain the type-stability boundary documented in
# CLAUDE.md / memory `pitfall_pipeline_inference.md`: abstract dispatch
# on PipelineStep would otherwise propagate Dict{Symbol,Any} eltypes
# into make_workspace inference. (Handlers run on the standard path; the
# RotatingBasisWS engine was retired 2026-06-21.)

@noinline function _run_step(
    step::RotatingBasisGroundStateStep,
    psi_prev, grid_prev, atom_prev, ws_prev;
    verbose=true, checkpoint_dir=nothing,
)
    return _run_rotating_basis_ground_state_step(step.params; verbose=verbose)
end

@noinline function _run_step(
    step::RotatingBasisDynamicsStep,
    psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
    live_status_path::Union{Nothing, String}=nothing,
)
    grid !== nothing || throw(
        ArgumentError(
            "rotating_basis dynamics step requires grid from preceding ground_state step"),
    )
    pipeline_results !== nothing || throw(ArgumentError(
        "rotating_basis dynamics step requires preceding ground_state results"))
    return _run_rotating_basis_dynamics_inner(step.params, grid, pipeline_results;
        verbose=verbose, live_status_path=live_status_path)
end
