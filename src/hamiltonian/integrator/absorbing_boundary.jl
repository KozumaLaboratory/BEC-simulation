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

function apply_absorbing_boundary!(
    psi::AbstractArray{<:Complex}, mask, n_components::Int, ndim::Int
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    @inbounds for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        psi_view .*= mask
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
        @timeit_debug TIMER "absorbing" apply_absorbing_boundary!(
            ws.state.psi, ws.absorbing_mask, n_comp, N
        )
    end
    nothing
end
