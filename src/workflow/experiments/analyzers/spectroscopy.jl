# --- Domain / correlation / spectroscopy / droplet analyzers ---
#
# Statistical-defect counters (domain walls, Kibble-Zurek defects),
# spin-correlation lengths, structure-factor S(k) for Bragg
# spectroscopy, and droplet-shape diagnostics (peak density, FWHM,
# RMS, surface sharpness).

function _analyze_domain_analysis(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    threshold = Float64(get(params, "threshold", 0.05)) * n_max
    domain_count = _count_domain_walls(fz, n, threshold, grid.config.n_points)
    f_mag_avg = sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) .* n) / sum(n)
    (domain_walls=domain_count, mean_spin_magnitude=f_mag_avg)
end

function _analyze_correlation_length(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    direction = Int(get(params, "direction", 1))
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    threshold = 0.05 * n_max
    center = ntuple(d -> (grid.config.n_points[d] + 1) ÷ 2, ndim)
    n_along = grid.config.n_points[direction]
    fz_line = zeros(Float64, n_along)
    for i in 1:n_along
        idx = ntuple(d -> d == direction ? i : center[d], ndim)
        fz_line[i] = n[idx...] > threshold ? fz[idx...] / max(n[idx...], 1e-30) : 0.0
    end
    dx = grid.config.box_size[direction] / n_along
    corr = zeros(Float64, n_along ÷ 2)
    fz_mean = sum(fz_line) / n_along
    fz_var = sum((fz_line .- fz_mean) .^ 2) / n_along
    if fz_var > 1e-30
        for lag in 0:(n_along ÷ 2 - 1)
            c = 0.0
            for i in 1:(n_along - lag)
                c += (fz_line[i] - fz_mean) * (fz_line[i + lag] - fz_mean)
            end
            corr[lag + 1] = c / ((n_along - lag) * fz_var)
        end
    end
    xi = 0.0
    for i in 2:length(corr)
        if corr[i] < exp(-1.0)
            xi = (i - 1) * dx
            break
        end
    end
    xi == 0.0 && (xi = length(corr) * dx)
    (correlation_length=xi, correlation=corr, direction=direction)
end

function _analyze_defect_density(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    threshold = Float64(get(params, "threshold", 0.1)) * n_max
    defect_type = Symbol(get(params, "defect_type", "domain_wall"))
    n_pts = grid.config.n_points
    defect_count = 0
    if defect_type == :domain_wall
        defect_count = _count_domain_walls(fz, n, threshold, n_pts)
    elseif defect_type == :vortex && ndim >= 2
        phase_field = angle.(view(psi, _component_slice(ndim, n_pts, 1)...))
        if ndim == 2
            for j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
                n[i, j] < threshold && continue
                dp =
                    _phase_diff(phase_field[i + 1, j], phase_field[i, j]) +
                    _phase_diff(phase_field[i + 1, j + 1], phase_field[i + 1, j]) +
                    _phase_diff(phase_field[i, j + 1], phase_field[i + 1, j + 1]) +
                    _phase_diff(phase_field[i, j], phase_field[i, j + 1])
                abs(dp) > π && (defect_count += 1)
            end
        else
            for k in 1:n_pts[3], j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
                n[i, j, k] < threshold && continue
                dp =
                    _phase_diff(phase_field[i + 1, j, k], phase_field[i, j, k]) +
                    _phase_diff(phase_field[i + 1, j + 1, k], phase_field[i + 1, j, k]) +
                    _phase_diff(phase_field[i, j + 1, k], phase_field[i + 1, j + 1, k]) +
                    _phase_diff(phase_field[i, j, k], phase_field[i, j + 1, k])
                abs(dp) > π && (defect_count += 1)
            end
        end
    end
    volume = prod(grid.config.box_size)
    (defect_count=defect_count, defect_density=defect_count / volume, defect_type=defect_type)
end

function _analyze_kibble_zurek_stats(psi, grid, atom, params, ws_prev)
    # Single-psi fallback for Kibble-Zurek statistics — full ensemble
    # support needs TWA traces. Reports the same domain-wall count
    # as defect_density(:domain_wall) plus volume-normalised density.
    F = atom.F
    ndim = length(grid.config.n_points)
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    threshold = Float64(get(params, "threshold", 0.1)) * n_max
    defect_count = _count_domain_walls(fz, n, threshold, grid.config.n_points)
    volume = prod(grid.config.box_size)
    (defect_count=defect_count, defect_density=defect_count / volume, n_samples=1)
end

function _analyze_bragg_spectroscopy(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    n_pts = grid.config.n_points
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    n_total = total_density(psi, ndim)
    n_mean = sum(n_total) * cell_volume(grid)
    delta_n = n_total .- (n_mean / prod(grid.config.box_size))
    delta_nk = similar(delta_n, ComplexF64)
    delta_nk .= delta_n
    plans.forward * delta_nk
    Sk = abs2.(delta_nk) .* cell_volume(grid)^2
    (structure_factor=Sk,)
end

function _analyze_droplet_profile(psi, grid, atom, params, ws_prev)
    ndim = length(grid.config.n_points)
    n = total_density(psi, ndim)
    dV = cell_volume(grid)
    n_peak = maximum(n)
    N_atoms = sum(n) * dV
    peak_idx = Tuple(argmax(n))
    fwhm = zeros(Float64, ndim)
    sigma = zeros(Float64, ndim)
    for d in 1:ndim
        line = _line_through_peak(n, peak_idx, d)
        fwhm[d] = _fwhm_1d(line, grid.dx[d])
        sigma[d] = _rms_width_1d(line, grid.dx[d], grid.x[d])
    end
    max_grad = 0.0
    for d in 1:ndim
        dxd = grid.dx[d]
        gmax = _max_forward_grad(n, d, dxd)
        max_grad = max(max_grad, gmax)
    end
    sharpness = n_peak > 0 ? max_grad / n_peak : 0.0
    (n_peak=n_peak, N_atoms=N_atoms,
        fwhm=fwhm, sigma=sigma,
        surface_sharpness=sharpness,
        peak_index=collect(peak_idx))
end
