export compute_absorbing_mask, apply_absorbing_boundary!, apply_rt_dissipation!

function compute_absorbing_mask(
    grid::Grid{N, T}, ab::AbsorbingBoundary, dt::Float64, backend;
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    mask = ones(U, grid.config.n_points)
    w = U(ab.width)
    pow = ab.power
    str = U(ab.strength)
    dt_u = U(dt)

    @inbounds for I in CartesianIndices(grid.config.n_points)
        alpha = zero(U)
        for d in 1:N
            L_half = U(grid.config.box_size[d] / 2)
            x_start = L_half - w
            xd = abs(U(grid.x[d][I[d]]))
            if xd > x_start
                alpha += ((xd - x_start) / w)^pow
            end
        end
        if alpha > 0
            mask[I] = exp(-str * alpha * dt_u)
        end
    end

    _to_device(backend, mask)
end

"""
    apply_absorbing_boundary!(psi, mask, n_components, ndim; dt_ratio=1.0)

Multiply each spinor component by the absorbing mask.

`dt_ratio` is `dt_actual / dt_the_mask_was_built_with`. The mask is
`exp(-strength·α(x)·dt)`, so a step of a different size wants
`mask^(dt_actual/dt_build)` — exact, not an approximation, because the
absorption is a pure exponential in dt.

It used to be applied verbatim at every step size. Fixed-dt drivers were right
by construction; the adaptive ones were not. Measured 2026-08-07 at 32 points,
width 2.0, strength 5.0, dt_build 1e-3 — absorbed fraction per step against the
correct value:

    dt/dt_build   0.25    0.5     2.0     5.0
    error        +299%   +100%   -50%    -80%

`dt_ratio == 1` takes the cached mask untouched, which is every fixed-dt run, so
the common path pays nothing.
"""
function apply_absorbing_boundary!(
    psi::AbstractArray{<:Complex}, mask, n_components::Int, ndim::Int;
    dt_ratio::Real=1.0,
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    m = isapprox(dt_ratio, 1.0; rtol=1.0e-12) ? mask : mask .^ dt_ratio
    @inbounds for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        psi_view .*= m
    end
    nothing
end

"""
    apply_rt_dissipation!(ws, dt, n_comp, N) → nothing

Real-time per-step dissipative epilogue: K3/L3 loss, then the absorbing
boundary mask. The two MUST stay co-located. They are NON-unitary
amputations of the wavefunction that every real-time step performs after
the unitary core; a driver loop that hand-writes one without the other
silently disables the missing channel. That is exactly what happened on
the leapfrog / Yoshida / adaptive paths — each applied loss but omitted
absorbing, so a production `dynamics: {absorbing_boundary: {...}}` built
the mask and threw it away (App. A epilogue audit, 2026-06-07). Routing
every step function and driver loop through this one helper makes
term-omission drift structurally impossible. Caller restricts to real
time (`!imaginary_time`); imaginary time has no physical dissipation.
"""
function apply_rt_dissipation!(ws, dt, n_comp::Int, N::Int)
    if ws.loss !== nothing
        @timeit_debug TIMER "loss" apply_loss_step!(
            ws.state.psi, ws.loss, ws.spin_matrices.system.F,
            dt, n_comp, N, ws.density_buf,
        )
    end
    if ws.absorbing_mask !== nothing
        # The mask is baked at `sim_params.dt` (`make_workspace.jl:442`), which
        # is the only dt available at build time. Adaptive drivers hand this
        # function their real `dt_step`, and it was thrown away.
        dt_build = ws.sim_params.dt
        @timeit_debug TIMER "absorbing" apply_absorbing_boundary!(
            ws.state.psi, ws.absorbing_mask, n_comp, N;
            dt_ratio=dt_build > 0 ? dt / dt_build : 1.0,
        )
    end
    nothing
end
