# --- Standalone dynamics under an arbitrary B(r) field ---
#
# Evolve a cloud under a spatially-varying Zeeman field while reusing the
# full audited split-step (kinetic + trap + interactions + uniform Zeeman).
# The spatial field enters as an outer Strang sandwich around `split_step!`,
# so the whole step stays 2nd-order. This is the dynamics-only counterpart
# of `simulate_tof_*`; the production-pipeline (ground state / YAML) path is
# Phase B's `SpatialZeemanTerm` HamTerm.

export simulate_field_dynamics

"""
    simulate_field_dynamics(ws_source; field, t_total, n_steps,
                            save_every=max(1, n_steps÷10),
                            drop_trap=false, drop_interactions=false) -> NamedTuple

Real-time evolution of `ws_source`'s wavefunction under the spatially-varying
`field::SpatialZeemanField`, on top of the source's kinetic + trap +
interactions + uniform Zeeman. Each step is
`field(dt/2) · split_step!(dt) · field(dt/2)` (2nd-order Strang). Set
`drop_trap=true` for a free-expansion / TOF run, `drop_interactions=true`
for the non-interacting limit.

Returns `(times, norms, magnetizations, psi_snapshots)` with one entry per
`save_every` steps (plus the initial and final states). CPU-only (the
per-voxel spatial field indexes the spin axis with scalar indices).
"""
function simulate_field_dynamics(
    ws_source::Workspace{N};
    field::SpatialZeemanField{N},
    t_total::Float64,
    n_steps::Int,
    save_every::Int=max(1, n_steps ÷ 10),
    drop_trap::Bool=false,
    drop_interactions::Bool=false,
) where {N}
    ws_source.backend isa CPUBackend ||
        error(
            "simulate_field_dynamics is CPU-only (per-voxel spatial Zeeman); " *
            "got backend $(typeof(ws_source.backend))",
        )
    size(field.bz) == ws_source.grid.config.n_points ||
        throw(
            ArgumentError(
                "field shape $(size(field.bz)) ≠ grid " *
                "$(ws_source.grid.config.n_points)",
            ),
        )
    t_total >= 0 || throw(ArgumentError("t_total must be non-negative"))
    n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
    save_every > 0 || throw(ArgumentError("save_every must be positive"))

    dt = t_total / n_steps
    sp = SimParams(; dt, n_steps, imaginary_time=false, normalize_every=0, save_every)
    ip = drop_interactions ? InteractionParams(Dict{Int, Float64}()) : ws_source.interactions
    pot = drop_trap ? NoPotential() : ws_source.potential

    ws = make_workspace(;
        grid=ws_source.grid,
        atom=ws_source.atom,
        interactions=ip,
        zeeman=ws_source.zeeman,
        potential=pot,
        sim_params=sp,
        psi_init=ws_source.state.psi,
        backend=ws_source.backend,
    )

    sm = ws.spin_matrices
    sys = sm.system
    psi = ws.state.psi

    times = Float64[]
    norms = Float64[]
    mags = Float64[]
    snaps = Array{ComplexF64}[]
    _push_field_obs!(times, norms, mags, snaps, 0.0, psi, ws.grid, sys)

    for step in 1:n_steps
        apply_spatial_zeeman_step!(psi, field, sm, dt / 2, false)
        split_step!(ws)
        apply_spatial_zeeman_step!(psi, field, sm, dt / 2, false)
        if step % save_every == 0 || step == n_steps
            _push_field_obs!(times, norms, mags, snaps, step * dt, psi, ws.grid, sys)
        end
    end

    (times=times, norms=norms, magnetizations=mags, psi_snapshots=snaps)
end

function _push_field_obs!(times, norms, mags, snaps, t, psi, grid, sys)
    push!(times, t)
    push!(norms, total_norm(psi, grid))
    push!(mags, magnetization(psi, grid, sys))
    push!(snaps, Array(psi))
    nothing
end
