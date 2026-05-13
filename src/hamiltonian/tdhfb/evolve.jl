# TDHFB unified evolution loop — dispatch over Strang / Yoshida-4 schemes,
# precompute k² grid once, per-step callback hook, history snapshots.
# Symmetric to the `run_simulation!(ws::Workspace; ...)` UX on the lab-path side.

export tdhfb_evolve!

"""
    tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
                  scheme=:strang, k_squared=nothing, hfb_mode=:full_hfb,
                  on_step=nothing, save_every=0,
                  picard_iters=1, picard_tol=1e-10) -> (state, history)

Run `n_steps` TDHFB integration steps under a chosen integrator scheme.

Drop-in replacement for the manual loop pattern:

```julia
for step in 1:n_steps
    tdhfb_strang_step!(state, F, g_S, V_ext, dt; ...)
end
```

…adding scheme dispatch, precomputed `k_squared` (vs rebuilt every step in
the raw API), an optional per-step callback, and a history vector of
snapshots.

# Schemes
- `:strang` (default): `tdhfb_strang_step!` — order 2, symmetric.
- `:y4_midpoint`: `tdhfb_y4_midpoint_step!` — formal Y4 composition. The
  underlying TDHFB Strang substep is not yet palindromic at O(dt²) so this
  empirically remains order 2 (with a worse prefactor at small dt). See
  `tdhfb_y4_midpoint_step!` docstring for the route to a palindromic substep.

# Keyword arguments
- `k_squared`: precomputed `|k|²` grid. If `nothing`, built once and
  reused across all steps (the raw `tdhfb_strang_step!` API rebuilds it
  on every call).
- `hfb_mode::Symbol = :full_hfb`: `:full_hfb` or `:popov`. Forwarded
  to the step function (φ subupdate generator).
- `on_step`: optional `f(state, step::Int)` callback fired after each
  step (e.g., for energy tracing).
- `save_every::Int = 0`: if positive, push a copy of (φ, ρ, κ, t, step)
  to the history every N steps. `0` = no snapshots, returns empty vector.
- `picard_iters`, `picard_tol`: forwarded to `:y4_midpoint` only.

# Returns
`(state, history)` where `state` is the mutated input and `history` is
a (possibly empty) `Vector{NamedTuple}` of saved snapshots.
"""
function tdhfb_evolve!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64,
    n_steps::Int;
    scheme::Symbol=:strang,
    k_squared=nothing,
    hfb_mode::Symbol=:full_hfb,
    on_step=nothing,
    save_every::Int=0,
    picard_iters::Int=1,
    picard_tol::Real=1e-10,
) where {N}
    # Precompute |k|² once per call (vs once per Strang step in the raw API).
    spatial = size(state.phi)[1:(end - 1)]
    ksq = k_squared === nothing ? _default_tdhfb_k_squared(spatial) : k_squared

    history = NamedTuple[]

    for step in 1:n_steps
        if scheme === :strang
            tdhfb_strang_step!(state, F, g_S, V_ext, dt;
                k_squared=ksq, hfb_mode=hfb_mode)
        elseif scheme === :y4_midpoint
            tdhfb_y4_midpoint_step!(state, F, g_S, V_ext, dt;
                k_squared=ksq, hfb_mode=hfb_mode,
                picard_iters=picard_iters, picard_tol=picard_tol)
        else
            error("tdhfb_evolve!: unknown scheme $scheme. " *
                  "Valid: :strang, :y4_midpoint")
        end

        on_step === nothing || on_step(state, step)

        if save_every > 0 && step % save_every == 0
            push!(
                history,
                (
                    t=state.t,
                    step=state.step,
                    phi=copy(state.phi),
                    rho=copy(state.rho),
                    kappa=copy(state.kappa),
                ),
            )
        end
    end

    return state, history
end
