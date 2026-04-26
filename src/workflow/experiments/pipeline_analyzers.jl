using JSON

# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, atom, params; ws_prev=nothing,
    pipeline_results::Dict{Symbol, Any}=Dict{Symbol, Any}())
    # Analyzers perform reductions over psi and are not GPU-safe in general.
    # Move to host once here; no-op on CPU.
    psi = _to_host(psi)
    F = atom.F
    if name == :tomography
        spin_tomography(psi, grid, F;
            rotation_axis=Symbol(get(params, "axis", "y")),
            n_angles=Int(get(params, "n_angles", 19)),
            theta_min=Float64(get(params, "theta_min", 0.0)),
            theta_max=Float64(get(params, "theta_max", Float64(π))),
            reference_m=let v = get(params, "reference_m", nothing);
                v === nothing ? nothing : Int(v)
            end,
            tof_params=let td = get(params, "tof", Dict())
                TOFParams(Float64(get(td, "t_tof", 11.0)),
                    Float64(get(td, "gradient", 0.0)),
                    Int(get(td, "imaging_axis", 3)))
            end,
        )
    elseif name == :faraday
        faraday_image(psi, grid, F;
            params=FaradayParams(;
                probe_axis=Int(get(params, "probe_axis", get(params, "axis", 3))),
                detuning=Float64(get(params, "detuning", -64.0)),
                polarization=Symbol(get(params, "polarization", "linear_x")),
            ),
        )
    elseif name == :energy_decomposition
        sm = spin_matrices(F)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :phase_classify
        sm = spin_matrices(F)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :stability
        ndim = length(grid.config.n_points)
        sp = SimParams(; dt=0.0001, n_steps=1, save_every=1)
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(0.0, 0.0),
            potential=HarmonicTrap(ntuple(_ -> 1.0, ndim)),
            sim_params=sp,
            psi_init=psi,
        )
        perturbation = Float64(get(params, "perturbation", 1e-4))
        n_steps_stab = Int(get(params, "n_steps", 1000))
        sample_every = Int(get(params, "sample_every", 10))
        analyze_stability(ws; perturbation, n_steps=n_steps_stab, sample_every)
    elseif name == :bogoliubov
        _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    elseif name == :multipole_order
        F = atom.F
        ndim = length(grid.config.n_points)
        ranks = let v = get(params, "ranks", nothing)
            v === nothing ? collect(0:2:2F) : Int.(v)
        end
        spectrum = multipole_spectrum(psi, F, grid)
        selected = Dict{Int, Float64}(k => get(spectrum, k, 0.0) for k in ranks)
        (multipole_spectrum=selected, ranks=ranks)
    elseif name == :winding_map
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        Lz_total = orbital_angular_momentum(psi, grid, plans)
        Mz = magnetization(psi, grid, SpinSystem(F))
        j = probability_current(psi, grid, plans)
        j_mag = sqrt.(sum(ji .^ 2 for ji in j))
        (Lz=Lz_total, Mz=Mz, Jz=Lz_total + Mz, max_current=maximum(j_mag))
    elseif name == :absorption_image
        F = atom.F
        ndim = length(grid.config.n_points)
        axis = Int(get(params, "axis", ndim))
        psf_sigma = Float64(get(params, "psf_sigma", 0.0))
        n = total_density(psi, ndim)
        col = dropdims(sum(n; dims=axis); dims=axis) .* cell_volume(grid)^(1.0 / ndim)
        if psf_sigma > 0 && ndim >= 2
            # Simple Gaussian blur via FFT convolution
            remaining = [i for i in 1:ndim if i != axis]
            sz = size(col)
            col_c = Array{ComplexF64}(undef, sz)
            col_c .= col
            p_fwd = plan_fft!(col_c)
            p_inv = plan_ifft!(col_c)
            p_fwd * col_c
            for I in CartesianIndices(sz)
                ksq = sum(j -> (2π * I[j] / sz[j])^2, 1:length(sz))
                col_c[I] *= exp(-0.5 * psf_sigma^2 * ksq)
            end
            p_inv * col_c
            col = real.(col_c)
        end
        add_noise = Bool(get(params, "shot_noise", false))
        if add_noise
            rng = Random.MersenneTwister(Int(get(params, "seed", 42)))
            col .= max.(0.0, col .+ sqrt.(max.(0.0, col)) .* randn(rng, size(col)...))
        end
        (column_density=col, axis=axis)
    elseif name == :sg_tof
        F = atom.F
        sys = SpinSystem(F)
        gradient = Float64(get(params, "gradient", 0.1))
        t_tof = Float64(get(params, "t_tof", 10.0))
        imaging_axis = Int(get(params, "imaging_axis", length(grid.config.n_points)))
        tof_params = TOFParams(t_tof, gradient, imaging_axis)
        result = simulate_tof(psi, grid, sys, tof_params)
        populations = Dict{Int, Float64}()
        for (m, dens) in result
            populations[m] = sum(dens)
        end
        (tof_images=result, populations=populations)
    elseif name == :domain_analysis
        F = atom.F
        ndim = length(grid.config.n_points)
        sm = spin_matrices(F)
        fx, fy, fz = spin_density_vector(psi, sm, ndim)
        n = total_density(psi, ndim)
        n_max = maximum(n)
        threshold = Float64(get(params, "threshold", 0.05)) * n_max
        # Count domain structure: regions where fz changes sign
        n_pts = grid.config.n_points
        domain_count = 0
        prev_sign = 0
        for I in CartesianIndices(n_pts)
            n[I] > threshold || continue
            s = sign(fz[I])
            if s != 0 && s != prev_sign && prev_sign != 0
                domain_count += 1
            end
            if s != 0
                prev_sign = s
            end
        end
        f_mag_avg = sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) .* n) / sum(n)
        (domain_walls=domain_count, mean_spin_magnitude=f_mag_avg)
    elseif name == :skyrmion_density
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        sm = spin_matrices(F)
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        if ndim == 2
            Q = spin_texture_charge(psi, grid, plans, sm)
            omega = berry_curvature(psi, grid, plans, sm)
            (charge=Q, berry_curvature=omega)
        elseif ndim == 3
            omega_x, omega_y, omega_z = berry_curvature(psi, grid, plans, sm)
            dV = cell_volume(grid)
            Q_xy = sum(omega_z) * dV / (4π)
            (charge_xy=Q_xy, berry_curvature=(omega_x, omega_y, omega_z))
        else
            (charge=0.0,)
        end
    elseif name == :phase_contrast_image
        F = atom.F
        ndim = length(grid.config.n_points)
        axis = Int(get(params, "axis", ndim))
        detuning = Float64(get(params, "detuning", -64.0))
        sm = spin_matrices(F)
        fx, fy, fz = spin_density_vector(psi, sm, ndim)
        n = total_density(psi, ndim)
        # Phase contrast ∝ column-integrated (n ± fz) depending on probe polarization
        n_plus = n .+ fz
        n_minus = n .- fz
        col_plus = dropdims(sum(n_plus; dims=axis); dims=axis) .* cell_volume(grid)^(1.0 / ndim)
        col_minus = dropdims(sum(n_minus; dims=axis); dims=axis) .* cell_volume(grid)^(1.0 / ndim)
        phase_signal = col_plus .- col_minus
        (
            phase_signal=phase_signal,
            column_density_plus=col_plus,
            column_density_minus=col_minus,
            axis=axis,
        )
    elseif name == :momentum_distribution
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        D = 2F + 1
        nk = zeros(Float64, n_pts)
        for c in 1:D
            idx = _component_slice(ndim, n_pts, c)
            psi_c = copy(view(psi, idx...))
            psi_k = similar(psi_c, ComplexF64)
            psi_k .= psi_c
            plans.forward * psi_k
            nk .+= abs2.(psi_k)
        end
        # Normalize
        dV = cell_volume(grid)
        nk .*= dV^2
        (momentum_density=nk,)
    elseif name == :vortex_detect
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        ndim >= 2 || throw(ArgumentError("vortex_detect requires N >= 2"))
        component = Int(get(params, "component", 1))
        threshold = Float64(get(params, "threshold", 0.1))
        idx = _component_slice(ndim, n_pts, component)
        psi_c = view(psi, idx...)
        n_c = abs2.(psi_c)
        n_max = maximum(n_c)
        phase_field = angle.(psi_c)
        thresh = threshold * n_max
        vortex_count = 0
        # Per-vortex records: (i, j[, k], winding) for downstream maps / plots
        positions = Tuple[]
        if ndim == 2
            @inbounds for j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
                n_c[i, j] < thresh && continue
                dp =
                    _phase_diff(phase_field[i + 1, j], phase_field[i, j]) +
                    _phase_diff(phase_field[i + 1, j + 1], phase_field[i + 1, j]) +
                    _phase_diff(phase_field[i, j + 1], phase_field[i + 1, j + 1]) +
                    _phase_diff(phase_field[i, j], phase_field[i, j + 1])
                if abs(dp) > π
                    vortex_count += 1
                    push!(positions, (i, j, round(Int, dp / (2π))))
                end
            end
        else
            @inbounds for k in 1:n_pts[3], j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
                n_c[i, j, k] < thresh && continue
                dp =
                    _phase_diff(phase_field[i + 1, j, k], phase_field[i, j, k]) +
                    _phase_diff(phase_field[i + 1, j + 1, k], phase_field[i + 1, j, k]) +
                    _phase_diff(phase_field[i, j + 1, k], phase_field[i + 1, j + 1, k]) +
                    _phase_diff(phase_field[i, j, k], phase_field[i, j + 1, k])
                if abs(dp) > π
                    vortex_count += 1
                    push!(positions, (i, j, k, round(Int, dp / (2π))))
                end
            end
        end
        (vortex_count=vortex_count, positions=positions, component=component)
    elseif name == :correlation_length
        F = atom.F
        ndim = length(grid.config.n_points)
        direction = Int(get(params, "direction", 1))
        sm = spin_matrices(F)
        fx, fy, fz = spin_density_vector(psi, sm, ndim)
        n = total_density(psi, ndim)
        n_max = maximum(n)
        threshold = 0.05 * n_max
        # Extract 1D spin correlation along specified direction through center
        center = ntuple(d -> (grid.config.n_points[d] + 1) ÷ 2, ndim)
        n_along = grid.config.n_points[direction]
        fz_line = zeros(Float64, n_along)
        for i in 1:n_along
            idx = ntuple(d -> d == direction ? i : center[d], ndim)
            fz_line[i] = n[idx...] > threshold ? fz[idx...] / max(n[idx...], 1e-30) : 0.0
        end
        # Autocorrelation
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
        # Find 1/e decay length
        xi = 0.0
        for i in 2:length(corr)
            if corr[i] < exp(-1.0)
                xi = (i - 1) * dx
                break
            end
        end
        xi == 0.0 && (xi = length(corr) * dx)
        (correlation_length=xi, correlation=corr, direction=direction)
    elseif name == :defect_density
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
            prev_sign = 0
            for I in CartesianIndices(n_pts)
                n[I] > threshold || continue
                s = sign(fz[I])
                if s != 0 && s != prev_sign && prev_sign != 0
                    defect_count += 1
                end
                s != 0 && (prev_sign = s)
            end
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
                # 3D: sum vortex detections across all (x,y) plaquettes at every z
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
    elseif name == :kibble_zurek_stats
        # Requires ensemble data from TWA or repeated runs — reports summary stats
        # For single-psi fallback: count defects and report
        F = atom.F
        ndim = length(grid.config.n_points)
        sm = spin_matrices(F)
        fx, fy, fz = spin_density_vector(psi, sm, ndim)
        n = total_density(psi, ndim)
        n_max = maximum(n)
        threshold = Float64(get(params, "threshold", 0.1)) * n_max
        # Count domain walls
        prev_sign = 0
        defect_count = 0
        for I in CartesianIndices(grid.config.n_points)
            n[I] > threshold || continue
            s = sign(fz[I])
            if s != 0 && s != prev_sign && prev_sign != 0
                defect_count += 1
            end
            s != 0 && (prev_sign = s)
        end
        volume = prod(grid.config.box_size)
        (defect_count=defect_count, defect_density=defect_count / volume, n_samples=1)
    elseif name == :bragg_spectroscopy
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        D = 2F + 1
        # Static structure factor S(k) from density fluctuations
        n_total = total_density(psi, ndim)
        n_mean = sum(n_total) * cell_volume(grid)
        delta_n = n_total .- (n_mean / prod(grid.config.box_size))
        delta_nk = similar(delta_n, ComplexF64)
        delta_nk .= delta_n
        plans.forward * delta_nk
        Sk = abs2.(delta_nk) .* cell_volume(grid)^2
        (structure_factor=Sk,)
    elseif name == :droplet_profile
        ndim = length(grid.config.n_points)
        n = total_density(psi, ndim)
        dV = cell_volume(grid)
        n_peak = maximum(n)
        N_atoms = sum(n) * dV
        # FWHM along each axis through the density peak
        peak_idx = Tuple(argmax(n))
        fwhm = zeros(Float64, ndim)
        sigma = zeros(Float64, ndim)
        for d in 1:ndim
            line = _line_through_peak(n, peak_idx, d)
            fwhm[d] = _fwhm_1d(line, grid.dx[d])
            sigma[d] = _rms_width_1d(line, grid.dx[d], grid.x[d])
        end
        # Surface sharpness ≈ max |∇n| / n_peak (axis-aligned max)
        max_grad = 0.0
        for d in 1:ndim
            dxd = grid.dx[d]
            # forward difference max
            gmax = _max_forward_grad(n, d, dxd)
            max_grad = max(max_grad, gmax)
        end
        sharpness = n_peak > 0 ? max_grad / n_peak : 0.0
        (n_peak=n_peak, N_atoms=N_atoms,
            fwhm=fwhm, sigma=sigma,
            surface_sharpness=sharpness,
            peak_index=collect(peak_idx))

    elseif name == :bogoliubov_dispersion
        # Full ω(k) for every BdG band, returned as a (n_k, 2D) matrix.
        # Useful to plot the full dispersion (not just max growth)
        # — roton dips, gapped vs gapless modes, branch crossings.
        ws_prev === nothing && throw(ArgumentError(
            "bogoliubov_dispersion requires a preceding ground_state step"))
        F = atom.F
        D = 2F + 1
        ndim = length(grid.config.n_points)
        psi_host = _to_host(psi)
        n_total = total_density(psi_host, ndim)
        peak_idx = argmax(n_total)
        spinor = ComplexF64[psi_host[peak_idx, c] for c in 1:D]
        n0 = sum(abs2, spinor)
        n0 > 1e-30 && (spinor ./= sqrt(n0))
        interactions = ws_prev.interactions
        c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
        zeeman = ws_prev.zeeman isa ZeemanParams ? ws_prev.zeeman : ZeemanParams(0.0, 0.0)
        k_max = Float64(get(params, "k_max", 10.0))
        n_k = Int(get(params, "n_k", 200))
        k_dir_raw = get(params, "k_direction", [0.0, 0.0, 1.0])
        k_direction = NTuple{3, Float64}(Tuple(Float64.(k_dir_raw)))
        result = bogoliubov_spectrum(;
            spinor=spinor, n0=n0, F=F,
            interactions=interactions, zeeman=zeeman, c_dd=c_dd_val,
            k_max=k_max, n_k=n_k, k_direction=k_direction,
        )
        # Sort each k column by Re(ω) for plottable bands
        omega_sorted = similar(result.omega)
        for ik in 1:n_k
            col = result.omega[:, ik]
            perm = sortperm(real.(col))
            omega_sorted[:, ik] .= col[perm]
        end
        (k_values=result.k_values,
            omega_real=real.(omega_sorted),
            omega_imag=imag.(omega_sorted),
            max_growth=result.max_growth,
            direction=collect(k_direction))

    elseif name == :bogoliubov_mode
        # Like :bogoliubov but additionally returns the eigenvector (u, v)
        # of the most unstable BdG mode plus its per-spinor-component
        # weight |u_m|² + |v_m|². Useful to see WHICH spinor channel
        # carries the instability and at what spatial wavelength.
        ws_prev === nothing && throw(ArgumentError(
            "bogoliubov_mode requires a preceding ground_state step"))
        F = atom.F
        D = 2F + 1
        ndim = length(grid.config.n_points)

        psi_host = _to_host(psi)
        n_total = total_density(psi_host, ndim)
        peak_idx = argmax(n_total)
        spinor = ComplexF64[psi_host[peak_idx, c] for c in 1:D]
        n0 = sum(abs2, spinor)
        n0 > 1e-30 && (spinor ./= sqrt(n0))

        interactions = ws_prev.interactions
        c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
        zeeman = ws_prev.zeeman isa ZeemanParams ? ws_prev.zeeman : ZeemanParams(0.0, 0.0)

        # First locate the peak-growth k via the existing scan
        imap = bogoliubov_instability_scan(;
            spinor=spinor, n0=n0, F=F,
            interactions=interactions, zeeman=zeeman, c_dd=c_dd_val,
            k_max=Float64(get(params, "k_max", 10.0)),
            n_k=Int(get(params, "n_k", 200)),
        )
        k_peak = imap.most_unstable_k
        # Build BdG matrix at k_peak, k̂ = best_direction; diagonalize
        h_mf, M_anom, zee, _ = SpinorBEC._bdg_contact_matrices(spinor, F, interactions, zeeman)
        if abs(c_dd_val) > 1e-30
            sm_for_ddi = spin_matrices(F)
            k_hat = collect(imap.most_unstable_direction)
            kn = sqrt(sum(abs2, k_hat));
            kn > 0 && (k_hat ./= kn)
            Q_ab = SpinorBEC._q_tensor_direction(k_hat)
            h_ddi, M_ddi = SpinorBEC._bdg_ddi_matrices(spinor, F, D, sm_for_ddi, c_dd_val, Q_ab)
            h_mf = h_mf .+ h_ddi
            M_anom = M_anom .+ M_ddi
        end
        mu = real(sum(c -> (zee[c] + n0 * h_mf[c, c]) * abs2(spinor[c]), 1:D))
        ek = k_peak^2 / 2
        L = 2n0 .* h_mf
        for i in 1:D
            ;
            L[i, i] += ek - mu + zee[i];
        end
        M_sc = n0 .* M_anom
        H_bdg = zeros(ComplexF64, 2D, 2D)
        H_bdg[1:D, 1:D] .= L
        H_bdg[1:D, (D + 1):2D] .= M_sc
        H_bdg[(D + 1):2D, 1:D] .= .-conj.(M_sc)
        H_bdg[(D + 1):2D, (D + 1):2D] .= .-conj.(L)
        evals, evecs = eigen(H_bdg)
        # Pick the mode with the largest imaginary part (instability)
        igrow = argmax(imag.(evals))
        ω_mode = evals[igrow]
        uv = evecs[:, igrow]
        u = uv[1:D];
        v = uv[(D + 1):2D]
        weight_per_m = abs2.(u) .+ abs2.(v)
        weight_per_m ./= max(sum(weight_per_m), 1e-30)
        wavelength = k_peak > 1e-12 ? 2π / k_peak : Inf
        (k_peak=k_peak, omega=ω_mode,
            growth_rate=imag(ω_mode),
            u_mode=u, v_mode=v,
            weight_per_m=weight_per_m,
            dominant_m=F - (argmax(weight_per_m) - 1),
            wavelength=wavelength,
            direction=collect(imap.most_unstable_direction))

    elseif name == :skyrmion_detect
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

    elseif name == :synthetic_dim
        # Treat the spinor m-axis as a synthetic site index. Outputs:
        #   pop_per_m       — N_atoms[c] integrated over real space (length D)
        #   edge_density    — sum of |ψ|² at m = ±F (real-space integrated)
        #   bulk_density    — sum of |ψ|² over interior m (|m| < F)
        #   coherence_q1    — |Σ_m e^{−iq·m} ⟨ψ_m⟩|² for q = 2π/D (1st Brillouin)
        #
        # Intended for ladder / synthetic-dim observables when the m manifold
        # is being driven (Raman / RF) so populations move between m sites.
        F = atom.F
        ndim = length(grid.config.n_points)
        D = 2F + 1
        dV = cell_volume(grid)
        pop_per_m = zeros(Float64, D)
        coh_re = zeros(Float64, D)
        coh_im = zeros(Float64, D)
        n_pts = grid.config.n_points
        for c in 1:D
            idx = _component_slice(ndim, n_pts, c)
            psi_c = view(psi, idx...)
            pop_per_m[c] = real(sum(abs2, psi_c)) * dV
            # First-Brillouin coherence: integrate ψ_m over space, then
            # combine with phase exp(−i q m) for q = 2π/D.
            mean_psi = sum(psi_c) * dV / (length(psi_c) * dV)  # spatial mean ψ
            coh_re[c] = real(mean_psi)
            coh_im[c] = imag(mean_psi)
        end
        m_vals = Float64[F - (c - 1) for c in 1:D]
        q1 = 2π / D
        coh_q1_re = sum(
            coh_re[c] * cos(q1 * m_vals[c]) -
            coh_im[c] * sin(-q1 * m_vals[c]) for c in 1:D
        )
        coh_q1_im = sum(
            coh_re[c] * sin(-q1 * m_vals[c]) +
            coh_im[c] * cos(q1 * m_vals[c]) for c in 1:D
        )
        coherence_q1 = coh_q1_re^2 + coh_q1_im^2
        edge_density = pop_per_m[1] + pop_per_m[D]
        bulk_density = sum(pop_per_m) - edge_density
        # First moment along m (synthetic position)
        total = sum(pop_per_m)
        m_mean = total > 0 ? sum(pop_per_m[c] * m_vals[c] for c in 1:D) / total : 0.0
        m_var = total > 0 ?
                sum(pop_per_m[c] * (m_vals[c] - m_mean)^2 for c in 1:D) / total : 0.0
        # Synthetic-ladder bond currents J_m (length D-1) — proxy for
        # population flow under Raman / RF driving; see
        # src/analysis/synthetic_dimension.jl for the convention.
        currents = synthetic_axis_current(psi, grid)
        # Inverse participation ratio on the m ladder: 1 = fully
        # localised on a single Zeeman sublevel, D = uniformly spread.
        ipr_xi = synthetic_localization_length(psi, grid)
        # Optional 2D dispersion (k_real × k_synth) when an axis is
        # supplied — tomography-style band structure for SOC studies.
        spectrum_axis = let v = get(params, "dispersion_axis", nothing)
            v === nothing ? nothing : Int(v)
        end
        dispersion_block = if spectrum_axis !== nothing
            d = synthetic_dim_dispersion(psi, grid; axis=spectrum_axis)
            (spectrum=collect(d.spectrum),
                k_real=d.k_real,
                k_synth=d.k_synth,
                axis=spectrum_axis)
        else
            nothing
        end
        (pop_per_m=pop_per_m,
            m_values=m_vals,
            m_mean=m_mean,
            m_variance=m_var,
            edge_density=edge_density,
            bulk_density=bulk_density,
            coherence_q1=coherence_q1,
            synthetic_currents=currents,
            localization_length=ipr_xi,
            dispersion=dispersion_block)

    elseif name == :non_abelian_homotopy
        ndim = length(grid.config.n_points)
        ndim >= 2 || throw(ArgumentError("non_abelian_homotopy requires N >= 2"))
        loop_pts_raw = get(params, "loop_pts", nothing)
        loop_pts_raw === nothing && throw(ArgumentError(
            "non_abelian_homotopy requires loop_pts: [[i,j(,k)], ...]"))
        # Match loop dim to grid N (2D or 3D path)
        loop_pts = if ndim == 2
            NTuple{2, Int}[(Int(p[1]), Int(p[2])) for p in loop_pts_raw]
        else
            NTuple{3, Int}[(Int(p[1]), Int(p[2]), Int(p[3])) for p in loop_pts_raw]
        end
        component = let v = get(params, "component", nothing)
            v === nothing ? nothing : Int(v)
        end
        holonomy = non_abelian_holonomy(psi, grid, loop_pts; component=component)
        winding = round(Int, angle(holonomy) / (2π))
        (holonomy=holonomy, phase=angle(holonomy),
            winding=winding, loop_length=length(loop_pts))

    elseif name == :monopole_charge
        ndim = length(grid.config.n_points)
        ndim == 3 || throw(ArgumentError("monopole_charge requires 3D grid"))
        smooth = Bool(get(params, "smooth", false))
        q_field = monopole_charge_3d(psi, grid; smooth=smooth)
        total_charge = total_monopole_charge(q_field, grid)
        (monopole_charge_density=q_field,
            total_charge=total_charge,
            max_abs_density=maximum(abs, q_field))

    elseif name == :majorana_order
        # Per-point Steinhardt Q₆ icosahedral order parameter from the
        # Majorana stars decomposition (only meaningful for F >= 6).
        # Returns the spatially-averaged Q₆ weighted by density and a
        # field of point-group symbols at sampled points.
        F = atom.F
        F >= 6 || throw(ArgumentError(
            "majorana_order requires F >= 6 (got $F)"))
        sm = spin_matrices(F)
        sampling = Float64(get(params, "sampling", 1.0))
        density_cutoff = Float64(get(params, "density_cutoff", 1e-6))
        q6_field = icosahedral_order_parameter(psi, grid, sm;
            density_cutoff, sampling)
        ndim = length(grid.config.n_points)
        n = total_density(psi, ndim)
        n_total = sum(n) * cell_volume(grid)
        q6_avg = n_total > 0 ?
                 sum(@. q6_field * n) * cell_volume(grid) / n_total : 0.0
        (q6_avg=q6_avg,
            q6_max=maximum(q6_field),
            q6_field=q6_field,
            sampling=sampling)

    elseif name == :winding_field
        ndim = length(grid.config.n_points)
        ndim >= 2 || throw(ArgumentError("winding_field requires N >= 2"))
        component = let v = get(params, "component", nothing)
            v === nothing ? nothing : Int(v)
        end
        threshold = Float64(get(params, "threshold", 1e-6))
        w = winding_number_field(psi, grid; component=component, threshold=threshold)
        (winding_field=w,
            total_winding=sum(w),
            max_abs_winding=maximum(abs, w))

    elseif name == :rosensweig_pattern
        # Detect a hexagonal / striped DDI-driven Rosensweig pattern by
        # locating the dominant non-zero |k| peak in the column-density
        # (or in-plane) power spectrum. Returns:
        #   peak_k          — wavenumber of the dominant ring (1/a_ho)
        #   lambda_peak     — 2π / peak_k (a_ho)
        #   pattern_strength — peak_power / mean(non-low-k power);
        #                     >>1 means a sharp ring, ~1 means structureless
        #   n_petals        — angular fold count estimated from the
        #                     azimuthal FFT of the |k| ≈ peak_k ring
        # Works on 2D ψ directly or on the column density of a 3D ψ
        # (axis controls which spatial axis is integrated). `k_min` (a_ho⁻¹)
        # skips the long-wavelength bins where the trap-confined cloud
        # envelope smears spectral weight.
        ndim = length(grid.config.n_points)
        ndim >= 2 || throw(ArgumentError("rosensweig_pattern requires N >= 2"))
        n_total = total_density(psi, ndim)
        plane = if ndim == 3
            axis = Int(get(params, "axis", 3))
            dropdims(sum(n_total; dims=axis); dims=axis)
        else
            n_total
        end
        nx, ny = size(plane)
        # Center & FFT. Subtract the spatial mean so the DC bin doesn't
        # drown the peak; the envelope still leaks into the bottom few k
        # bins, which `k_min` filters out below.
        plane_c = plane .- (sum(plane) / length(plane))
        spec = abs2.(fft(plane_c))
        kvecs = grid.k
        kx = kvecs[1]
        ky = kvecs[2]
        n_bins = Int(get(params, "n_radial_bins", min(nx, ny) ÷ 2))
        k_max = max(maximum(abs, kx), maximum(abs, ky))
        bin_w = k_max / n_bins
        radial_power = zeros(Float64, n_bins)
        radial_count = zeros(Int, n_bins)
        for j in 1:ny, i in 1:nx
            kr = sqrt(kx[i]^2 + ky[j]^2)
            b = clamp(round(Int, kr / bin_w) + 1, 1, n_bins)
            radial_power[b] += spec[i, j]
            radial_count[b] += 1
        end
        for b in 1:n_bins
            radial_count[b] > 0 && (radial_power[b] /= radial_count[b])
        end
        # Skip the lowest k bins where the cloud envelope's finite size
        # smears spectral weight (default: k < 1.0/a_ho — a few bins on a
        # box ~ 16 a_ho). Caller can tune via `k_min`.
        k_min = Float64(get(params, "k_min", 1.0))
        b_lo = max(2, ceil(Int, k_min / bin_w) + 1)
        if b_lo >= n_bins
            return (peak_k=NaN, lambda_peak=Inf, pattern_strength=NaN,
                n_petals=0, radial_power=radial_power)
        end
        slice = @view radial_power[b_lo:end]
        peak_b = argmax(slice) + b_lo - 1
        peak_k = (peak_b - 1) * bin_w
        lambda_peak = peak_k > 0 ? 2π / peak_k : Inf
        # Strength = peak / mean of the searched band (excludes envelope
        # smear). Sharp ring → strength >> 1; flat spectrum → ≈ 1.
        band_mean = sum(slice) / length(slice)
        pattern_strength = band_mean > 0 ? radial_power[peak_b] / band_mean : NaN
        # Azimuthal FFT of the ring at |k|≈peak_k → angular fold count
        n_angular = Int(get(params, "n_angular", 64))
        ring = zeros(Float64, n_angular)
        for a in 1:n_angular
            θ = 2π * (a - 1) / n_angular
            kxv = peak_k * cos(θ)
            kyv = peak_k * sin(θ)
            i = argmin(abs.(kx .- kxv))
            j = argmin(abs.(ky .- kyv))
            ring[a] = spec[i, j]
        end
        ring_spec = abs.(fft(ring))
        m_max = length(ring_spec) ÷ 2
        peak_m = argmax(@view ring_spec[2:(m_max + 1)])
        n_petals = peak_m   # angular FFT mode number = rotational fold count
        (peak_k=peak_k,
            lambda_peak=lambda_peak,
            pattern_strength=pattern_strength,
            n_petals=n_petals,
            radial_power=radial_power,
            k_min=k_min)

    elseif name == :column_density_movie
        # Streams per-snapshot column densities into a single JLD2 archive
        # (`columns.jld2` with one Float32 2D array per frame, key
        # `frame_NNNNN`) and writes a JSON manifest with frame times + axis
        # metadata. The dashboard / external notebooks render frames; we no
        # longer ship PNGs (PlotlyJS dependency removed).
        #
        # Two snapshot sources supported, same as before:
        #   1. Streamed scratch JLD2 (preferred for long runs).
        #   2. Legacy in-memory `dynres.psi_snapshots`.
        # `multi_step: true` walks every preceding dynamics phase.
        ndim = length(grid.config.n_points)
        ndim == 3 || throw(ArgumentError(
            "column_density_movie currently supports 3D only (got $(ndim)D)"))
        axis = Int(get(params, "axis", 3))
        output_dir = String(get(params, "output_dir", "frames"))
        mkpath(output_dir)
        multi_step = Bool(get(params, "multi_step", false))

        history = get(pipeline_results, :dynamics_history, nothing)
        if multi_step
            history === nothing && throw(
                ArgumentError(
                    "column_density_movie multi_step=true requires preceding dynamics steps"),
            )
            sources = collect(history)
        else
            dynres = get(pipeline_results, :dynamics_result, nothing)
            dynres === nothing && throw(
                ArgumentError(
                    "column_density_movie requires a preceding dynamics step with save_every > 0"
                ),
            )
            sources = [(
                dynamics_result=dynres,
                snapshot_tmp_path=get(pipeline_results, :snapshot_tmp_path, nothing),
                save_psi_snapshots=get(pipeline_results, :save_psi_snapshots, false),
                snapshot_count=get(pipeline_results, :snapshot_count, 0),
            )]
        end

        archive_path = joinpath(output_dir, "columns.jld2")
        manifest_path = joinpath(output_dir, "manifest.json")
        frame_keys = String[]
        frame_times = Float64[]
        frame_phases = Int[]
        global_idx = 0
        t_offset = 0.0
        jldopen(archive_path, "w") do out
            for (phase_idx, src) in enumerate(sources)
                dr = src.dynamics_result
                dr === nothing && continue
                tmp = src.snapshot_tmp_path
                saved = src.save_psi_snapshots
                times = dr.times
                if saved && tmp !== nothing && isfile(tmp)
                    jldopen(tmp, "r") do jh
                        n_snaps = Int(jh["n_snapshots"])
                        t_max = min(length(times), n_snaps)
                        for i in 1:t_max
                            global_idx += 1
                            skey = "frame_" * lpad(string(i), 5, '0')
                            frame = jh[skey]
                            n_total = total_density(frame, ndim)
                            col = dropdims(sum(n_total; dims=axis); dims=axis)
                            okey = "frame_" * lpad(string(global_idx), 5, '0')
                            out[okey] = Float32.(col)
                            push!(frame_keys, okey)
                            push!(frame_times, times[i] + t_offset)
                            push!(frame_phases, phase_idx)
                        end
                    end
                elseif hasproperty(dr, :psi_snapshots)
                    for (i, psi_s) in enumerate(dr.psi_snapshots)
                        global_idx += 1
                        n_total = total_density(psi_s, ndim)
                        col = dropdims(sum(n_total; dims=axis); dims=axis)
                        okey = "frame_" * lpad(string(global_idx), 5, '0')
                        out[okey] = Float32.(col)
                        push!(frame_keys, okey)
                        push!(frame_times, times[i] + t_offset)
                        push!(frame_phases, phase_idx)
                    end
                end
                t_offset += isempty(times) ? 0.0 : times[end] - times[1]
            end
            out["n_frames"] = global_idx
            out["axis"] = axis
        end
        manifest = Dict{String, Any}(
            "n_frames" => global_idx,
            "axis" => axis,
            "n_phases" => multi_step ? length(sources) : 1,
            "frame_keys" => frame_keys,
            "times" => frame_times,
            "phase_indices" => frame_phases,
            "archive" => basename(archive_path),
        )
        open(manifest_path, "w") do io
            JSON.print(io, manifest)
        end
        (output_dir=output_dir, n_frames=global_idx,
            archive_path=archive_path, manifest_path=manifest_path,
            axis=axis, n_phases=multi_step ? length(sources) : 1)

    elseif name == :summary_json
        # Dump the accumulated pipeline_results plus QC metadata to a JSON file.
        output_path = String(get(params, "path", "summary.json"))
        extras = get(params, "extras", Dict{String, Any}())
        summary = Dict{String, Any}()
        for (k, v) in pipeline_results
            # Skip objects that aren't JSON-serializable (workspaces, arrays).
            if v isa Number || v isa AbstractString || v isa Bool || v === nothing
                summary[String(k)] = v
            end
        end
        if haskey(pipeline_results, :dynamics_result)
            dr = pipeline_results[:dynamics_result]
            summary["n_snapshots"] = length(dr.psi_snapshots)
            summary["t_initial"] = dr.times[1]
            summary["t_final"] = dr.times[end]
            if !isempty(dr.energies)
                summary["energy_initial"] = Float64(dr.energies[1])
                summary["energy_final"] = Float64(dr.energies[end])
                summary["norm_drift"] = Float64(abs(dr.norms[end] - dr.norms[1]))
            end
        end
        for (k, v) in extras
            summary[String(k)] = v
        end
        mkpath(dirname(output_path) == "" ? "." : dirname(output_path))
        open(output_path, "w") do io
            JSON.print(io, summary, 2)
        end
        (path=output_path, n_fields=length(summary))

    else
        _known =
            "tomography, faraday, energy_decomposition, phase_classify, stability, bogoliubov, " *
            "multipole_order, winding_map, absorption_image, sg_tof, domain_analysis, skyrmion_density, " *
            "phase_contrast_image, momentum_distribution, vortex_detect, correlation_length, " *
            "defect_density, kibble_zurek_stats, bragg_spectroscopy, non_abelian_homotopy, " *
            "monopole_charge, winding_field, droplet_profile, synthetic_dim, " *
            "skyrmion_detect, bogoliubov_mode, bogoliubov_dispersion, " *
            "column_density_movie, summary_json"
        throw(ArgumentError("Unknown analyzer: $name. Supported: $_known"))
    end
end

function _phase_diff(a::Float64, b::Float64)
    d = a - b
    if d > π
        d - 2π
    elseif d < -π
        d + 2π
    else
        d
    end
end

# --- droplet_profile helpers ---

"""Extract the 1D density line through `peak_idx` along dimension `d`."""
function _line_through_peak(n::AbstractArray, peak_idx::NTuple{D, Int}, d::Int) where {D}
    nd = size(n, d)
    line = Vector{Float64}(undef, nd)
    @inbounds for i in 1:nd
        idx = ntuple(k -> k == d ? i : peak_idx[k], D)
        line[i] = n[idx...]
    end
    line
end

"""
Full width at half maximum of a 1D profile with grid spacing `dx`.
Returns 0 if the profile never reaches half of its peak (degenerate).
Uses linear interpolation between adjacent grid points at the crossings.
"""
function _fwhm_1d(line::AbstractVector{Float64}, dx::Float64)
    pk = maximum(line)
    pk > 0 || return 0.0
    half = 0.5 * pk
    # Find first and last indices where line >= half
    i_lo = findfirst(x -> x >= half, line)
    i_hi = findlast(x -> x >= half, line)
    (i_lo === nothing || i_hi === nothing || i_hi <= i_lo) && return 0.0
    # Linear interpolation for sub-cell precision
    lo_frac = if i_lo > 1
        prev = line[i_lo - 1];
        curr = line[i_lo]
        curr > prev ? (half - prev) / (curr - prev) : 0.0
    else
        0.0
    end
    hi_frac = if i_hi < length(line)
        curr = line[i_hi];
        nxt = line[i_hi + 1]
        curr > nxt ? (curr - half) / (curr - nxt) : 1.0
    else
        1.0
    end
    (i_hi + hi_frac - (i_lo - (1.0 - lo_frac))) * dx
end

"""Density-weighted RMS width of a 1D profile along a coordinate axis."""
function _rms_width_1d(line::AbstractVector{Float64}, dx::Float64, x::AbstractVector)
    tot = sum(line) * dx
    tot > 0 || return 0.0
    x̄ = sum(line .* x) * dx / tot
    var = sum(line .* (x .- x̄) .^ 2) * dx / tot
    sqrt(max(var, 0.0))
end

"""Max absolute forward-difference derivative of density along axis `d`."""
function _max_forward_grad(n::AbstractArray{<:Real, D}, d::Int, dx::Float64) where {D}
    sz = size(n)
    gmax = 0.0
    @inbounds for I in CartesianIndices(ntuple(k -> k == d ? sz[k] - 1 : sz[k], D))
        Ip1 = CartesianIndex(ntuple(k -> k == d ? I[k] + 1 : I[k], D))
        g = abs(n[Ip1] - n[I]) / dx
        g > gmax && (gmax = g)
    end
    gmax
end

"""
Extract the local spinor ζ at the density peak and run `bogoliubov_instability_scan`
using the physical couplings (c₀, c₁, c_k, c_dd) from the preceding ground-state step.

Returns a NamedTuple with `max_growth`, `unstable`, `k_peak`, `wavelength`,
`best_direction`, `pattern`, `anisotropy`, suitable for JLD2 persistence.
"""
function _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    ws_prev === nothing &&
        throw(
            ArgumentError(
                "bogoliubov analyzer requires a preceding ground_state step (ws_prev is nothing)"
            ),
        )

    F = atom.F
    D = 2F + 1
    ndim = length(grid.config.n_points)

    psi_host = _to_host(psi)
    n_total = total_density(psi_host, ndim)
    peak_idx = argmax(n_total)

    spinor = Vector{ComplexF64}(undef, D)
    n0 = 0.0
    for c in 1:D
        spinor[c] = psi_host[peak_idx, c]
        n0 += abs2(spinor[c])
    end
    if n0 > 1e-30
        spinor ./= sqrt(n0)
    end

    interactions = ws_prev.interactions
    c_dd_val = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
    zeeman = ws_prev.zeeman isa ZeemanParams ? ws_prev.zeeman : ZeemanParams(0.0, 0.0)

    k_max = Float64(get(params, "k_max", 10.0))
    n_k = Int(get(params, "n_k", 200))
    dir_mode = Symbol(get(params, "directions", "auto"))
    n_dirs = Int(get(params, "n_directions", 50))
    directions_arg = dir_mode in (:auto, :dense, :planar) ? dir_mode : :auto

    imap = bogoliubov_instability_scan(;
        spinor, n0, F, interactions, zeeman, c_dd=c_dd_val,
        k_max, n_k,
        directions=directions_arg,
        n_directions=n_dirs,
    )
    pred = predict_supersolid_params(imap)

    (
        n0=n0,
        max_growth=imap.max_growth_rate,
        unstable=imap.unstable,
        k_peak=imap.most_unstable_k,
        wavelength=imap.predicted_wavelength,
        best_direction=imap.most_unstable_direction,
        pattern=pred.pattern_type,
        anisotropy=pred.angular_anisotropy,
    )
end
