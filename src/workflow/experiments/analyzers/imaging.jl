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
