function _analyze_skyrmion_detect(psi, grid, atom, params, ws_prev)
    # Locate skyrmion centres in 2D (or per z-slice in 3D) by finding
    # local maxima of the topological charge density q(r) = (1/4π)
    # n̂ · (∂_x n̂ × ∂_y n̂). Each maximum above `threshold` returns
    # (i, j[, k], local_charge_integral) — useful for tracking
    # individual skyrmions across snapshots.
    F = atom.F
    ndim = length(grid.config.n_points)
    ndim >= 2 || throw(ArgumentError("skyrmion_detect requires N >= 2"))
    n_pts = grid.config.n_points
    sm = spin_matrices(F)
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    threshold = Float64(get(params, "threshold", 0.05))
    radius = Int(get(params, "radius", 2))   # local-max search radius

    positions = Tuple[]
    if ndim == 2
        omega = berry_curvature(psi, grid, plans, sm)
        q_max = maximum(abs, omega)
        cutoff = threshold * q_max
        @inbounds for j in (1 + radius):(n_pts[2] - radius),
            i in (1 + radius):(n_pts[1] - radius)

            v = omega[i, j]
            abs(v) < cutoff && continue
            # Local max (or min) check
            is_extremum = true
            for dj in (-radius):radius, di in (-radius):radius
                di == 0 && dj == 0 && continue
                if abs(omega[i + di, j + dj]) > abs(v)
                    is_extremum = false
                    break
                end
            end
            is_extremum || continue
            # Approximate per-skyrmion charge: sum over a ±radius patch
            local_q = 0.0
            for dj in (-radius):radius, di in (-radius):radius
                local_q += omega[i + di, j + dj]
            end
            push!(positions, (i, j, local_q * cell_volume(grid)))
        end
        total_Q = sum(omega) * cell_volume(grid) / (4π)
        (skyrmion_count=length(positions),
            positions=positions,
            total_charge=total_Q,
            charge_density=omega)
    else
        # 3D: detect per z-slice
        omega_x, omega_y, omega_z = berry_curvature(psi, grid, plans, sm)
        q_max = maximum(abs, omega_z)
        cutoff = threshold * q_max
        @inbounds for k in 1:n_pts[3]
            slab = view(omega_z,:,:,k)
            for j in (1 + radius):(n_pts[2] - radius), i in (1 + radius):(n_pts[1] - radius)
                v = slab[i, j]
                abs(v) < cutoff && continue
                is_extremum = true
                for dj in (-radius):radius, di in (-radius):radius
                    di == 0 && dj == 0 && continue
                    if abs(slab[i + di, j + dj]) > abs(v)
                        is_extremum = false
                        break
                    end
                end
                is_extremum || continue
                local_q = 0.0
                for dj in (-radius):radius, di in (-radius):radius
                    local_q += slab[i + di, j + dj]
                end
                push!(positions, (i, j, k, local_q * cell_volume(grid)))
            end
        end
        total_Q_xy = sum(omega_z) * cell_volume(grid) / (4π)
        (skyrmion_count=length(positions),
            positions=positions,
            total_charge_xy=total_Q_xy)
    end
end
