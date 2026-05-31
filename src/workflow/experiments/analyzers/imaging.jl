# --- Imaging analyzers ---
#
# Camera-side observables: spin-tomography stacks, Faraday-rotation
# images, absorption / phase-contrast imaging, Stern-Gerlach time-of-
# flight separation, and the bare momentum-space density |ψ̃(k)|².
# Each analyzer returns a NamedTuple ready for JLD2 persistence.

function _analyze_tomography(psi, grid, atom, params, ws_prev)
    F = atom.F
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
end

function _analyze_faraday(psi, grid, atom, params, ws_prev)
    F = atom.F
    faraday_image(psi, grid, F;
        params=FaradayParams(;
            probe_axis=Int(get(params, "probe_axis", get(params, "axis", 3))),
            detuning=Float64(get(params, "detuning", -64.0)),
            polarization=Symbol(get(params, "polarization", "linear_x")),
        ),
    )
end

function _analyze_absorption_image(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    axis = Int(get(params, "axis", ndim))
    psf_sigma = Float64(get(params, "psf_sigma", 0.0))
    n = total_density(psi, ndim)
    col = dropdims(sum(n; dims=axis); dims=axis) .* cell_volume(grid)^(1.0 / ndim)
    if psf_sigma > 0 && ndim >= 2
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
end

function _analyze_phase_contrast_image(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    axis = Int(get(params, "axis", ndim))
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    n = total_density(psi, ndim)
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
end

function _analyze_sg_tof(psi, grid, atom, params, ws_prev)
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
end

function _analyze_forward_image(psi, grid, atom, params, ws_prev)
    F = atom.F
    sys = SpinSystem(F)

    # 1. SG/TOF: per-m column densities, σ_eff(m) optical pumping table.
    sg_tof = TOFParams(Float64(get(params, "t_tof", 10.0)),
        Float64(get(params, "sg_gradient", 0.1)),
        Int(get(params, "imaging_axis", min(3, length(grid.config.n_points)))))
    tof_dict = simulate_tof(psi, grid, sys, sg_tof)
    opp = OpticalPumpingParams(; F_ground=F,
        polarization=Symbol(get(params, "polarization", "sigma_plus")),
        saturation=Float64(get(params, "saturation", 0.1)),
        detuning_over_gamma=Float64(get(params, "detuning_over_gamma", 0.0)),
        t_pulse_gamma=Float64(get(params, "t_pulse_gamma", 1.0)))
    sigma_eff_vec = build_sigma_eff_table(opp)
    imaging = ImagingParams(;
        view_geometry=Symbol(get(params, "view_geometry", "face_on")),
        sg_tof=sg_tof,
        sigma_eff=sigma_eff_vec,
        sigma_sg_pixels=Float64(get(params, "sigma_sg_pixels", 0.0)),
        psf_sigma_pixels=Float64(get(params, "psf_sigma_pixels", 0.0)),
        photons_per_pixel=Float64(get(params, "photons_per_pixel", 0.0)),
        read_noise_sigma=Float64(get(params, "read_noise_sigma", 0.0)),
        n_shots_avg=Int(get(params, "n_shots_avg", 1)))

    # 2. σ_eff weighted overlap composition (G2).
    sigma_eff_map = Dict{Int, Float64}(m => sigma_eff_vec[m + F + 1] for m in (-F):F)
    od_clean = apply_sg_overlap(tof_dict, imaging.sigma_sg_pixels;
        sigma_eff=sigma_eff_map)

    # 3. Camera-side noise + 116-shot ensemble (G3).
    seed = get(params, "seed", nothing)
    seed_int = seed === nothing ? nothing : Int(seed)
    ensemble = synthesise_image_ensemble(od_clean, grid;
        sigma_pixels=imaging.psf_sigma_pixels,
        photons_per_unit=imaging.photons_per_pixel,
        read_noise_sigma=imaging.read_noise_sigma,
        n_shots=imaging.n_shots_avg,
        seed=seed_int)

    # 4. Summary statistics (v0 minimal — extended in §2).
    populations = Dict{Int, Float64}(m => sum(dens) for (m, dens) in tof_dict)
    total_od = sum(ensemble.mean)

    # 5. Per-pixel Gaussian log-likelihood closure (diagonal Σ for v0; fringe
    # covariance to be added once basis is calibrated against experiment).
    # `log_likelihood_kernel` is NOT persisted to JLD2 (Function fallback in
    # `_write_jld2_value!` silently skips it); it lives in the returned
    # NamedTuple for direct call from Fisher/SBI Julia drivers.
    mean_img = ensemble.mean
    var_floor = max(1e-12, 1e-6 * (total_od / length(mean_img))^2)
    sigma_per_pixel = sqrt.(ensemble.var .+ var_floor)
    log_likelihood_kernel = function (image_exp::AbstractMatrix)
        size(image_exp) == size(mean_img) || throw(
            DimensionMismatch(
                "image_exp size $(size(image_exp)) ≠ sim mean size $(size(mean_img))"),
        )
        s = 0.0
        @inbounds for i in eachindex(mean_img)
            r = (Float64(image_exp[i]) - mean_img[i]) / sigma_per_pixel[i]
            s += r * r
        end
        -0.5 * s
    end

    (
        od_image=Float32.(mean_img),
        od_var=Float32.(ensemble.var),
        populations=populations,
        total_od=total_od,
        view_geometry=imaging.view_geometry,
        sigma_eff_table=sigma_eff_vec,
        log_likelihood_kernel=log_likelihood_kernel,
    )
end

function _analyze_momentum_distribution(psi, grid, atom, params, ws_prev)
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
    dV = cell_volume(grid)
    nk .*= dV^2
    (momentum_density=nk,)
end
