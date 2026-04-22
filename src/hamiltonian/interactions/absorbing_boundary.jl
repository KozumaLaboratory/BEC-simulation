function compute_absorbing_mask(grid::Grid{N}, ab::AbsorbingBoundary, dt::Float64, backend) where {N}
    mask = ones(Float64, grid.config.n_points)
    w = ab.width
    pow = ab.power

    @inbounds for I in CartesianIndices(grid.config.n_points)
        alpha = 0.0
        for d in 1:N
            L_half = grid.config.box_size[d] / 2
            x_start = L_half - w
            xd = abs(grid.x[d][I[d]])
            if xd > x_start
                alpha += ((xd - x_start) / w)^pow
            end
        end
        if alpha > 0
            mask[I] = exp(-ab.strength * alpha * dt)
        end
    end

    _to_device(backend, mask)
end

function apply_absorbing_boundary!(psi::AbstractArray{ComplexF64}, mask, n_components::Int, ndim::Int)
    n_pts = ntuple(d -> size(psi, d), ndim)
    @inbounds for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        psi_view .*= mask
    end
    nothing
end
