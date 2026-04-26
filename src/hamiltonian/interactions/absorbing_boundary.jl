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
