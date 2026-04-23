using JSON

# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, atom, params; ws_prev = nothing,
                        pipeline_results::Dict{Symbol,Any} = Dict{Symbol,Any}())
    # Analyzers perform reductions over psi and are not GPU-safe in general.
    # Move to host once here; no-op on CPU.
    psi = _to_host(psi)
    F = atom.F
    if name == :tomography
        spin_tomography(psi, grid, F;
            rotation_axis = Symbol(get(params, "axis", "y")),
            n_angles = Int(get(params, "n_angles", 19)),
            theta_min = Float64(get(params, "theta_min", 0.0)),
            theta_max = Float64(get(params, "theta_max", Float64(π))),
            reference_m = let v = get(params, "reference_m", nothing); v === nothing ? nothing : Int(v) end,
            tof_params = let td = get(params, "tof", Dict())
                TOFParams(Float64(get(td, "t_tof", 11.0)),
                         Float64(get(td, "gradient", 0.0)),
                         Int(get(td, "imaging_axis", 3)))
            end,
        )
    elseif name == :faraday
        faraday_image(psi, grid, F;
            params = FaradayParams(;
                probe_axis = Int(get(params, "probe_axis", get(params, "axis", 3))),
                detuning = Float64(get(params, "detuning", -64.0)),
                polarization = Symbol(get(params, "polarization", "linear_x")),
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
        sp = SimParams(; dt = 0.0001, n_steps = 1, save_every = 1)
        ws = make_workspace(;
            grid, atom,
            interactions = InteractionParams(0.0, 0.0),
            potential = HarmonicTrap(ntuple(_ -> 1.0, ndim)),
            sim_params = sp,
            psi_init = psi,
        )
        perturbation = Float64(get(params, "perturbation", 1e-4))
        n_steps_stab = Int(get(params, "n_steps", 1000))
        sample_every = Int(get(params, "sample_every", 10))
        analyze_stability(ws; perturbation, n_steps = n_steps_stab, sample_every)
    elseif name == :bogoliubov
        _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    elseif name == :multipole_order
        F = atom.F
        ndim = length(grid.config.n_points)
        ranks = let v = get(params, "ranks", nothing)
            v === nothing ? collect(0:2:2F) : Int.(v)
        end
        spectrum = multipole_spectrum(psi, F, grid)
        selected = Dict{Int,Float64}(k => get(spectrum, k, 0.0) for k in ranks)
        (multipole_spectrum = selected, ranks = ranks)
    elseif name == :winding_map
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
        Lz_total = orbital_angular_momentum(psi, grid, plans)
        Mz = magnetization(psi, grid, SpinSystem(F))
        j = probability_current(psi, grid, plans)
        j_mag = sqrt.(sum(ji .^ 2 for ji in j))
        (Lz = Lz_total, Mz = Mz, Jz = Lz_total + Mz, max_current = maximum(j_mag))
    elseif name == :absorption_image
        F = atom.F
        ndim = length(grid.config.n_points)
        axis = Int(get(params, "axis", ndim))
        psf_sigma = Float64(get(params, "psf_sigma", 0.0))
        n = total_density(psi, ndim)
        col = dropdims(sum(n; dims = axis); dims = axis) .* cell_volume(grid)^(1.0 / ndim)
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
        (column_density = col, axis = axis)
    elseif name == :sg_tof
        F = atom.F
        sys = SpinSystem(F)
        gradient = Float64(get(params, "gradient", 0.1))
        t_tof = Float64(get(params, "t_tof", 10.0))
        imaging_axis = Int(get(params, "imaging_axis", length(grid.config.n_points)))
        tof_params = TOFParams(t_tof, gradient, imaging_axis)
        result = simulate_tof(psi, grid, sys, tof_params)
        populations = Dict{Int,Float64}()
        for (m, dens) in result
            populations[m] = sum(dens)
        end
        (tof_images = result, populations = populations)
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
        (domain_walls = domain_count, mean_spin_magnitude = f_mag_avg)
    elseif name == :skyrmion_density
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        sm = spin_matrices(F)
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
        if ndim == 2
            Q = spin_texture_charge(psi, grid, plans, sm)
            omega = berry_curvature(psi, grid, plans, sm)
            (charge = Q, berry_curvature = omega)
        elseif ndim == 3
            omega_x, omega_y, omega_z = berry_curvature(psi, grid, plans, sm)
            dV = cell_volume(grid)
            Q_xy = sum(omega_z) * dV / (4π)
            (charge_xy = Q_xy, berry_curvature = (omega_x, omega_y, omega_z))
        else
            (charge = 0.0,)
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
        (phase_signal = phase_signal, column_density_plus = col_plus, column_density_minus = col_minus, axis = axis)
    elseif name == :momentum_distribution
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
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
        (momentum_density = nk,)
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
        # Phase winding detection via discrete curl of phase gradient
        phase_field = angle.(psi_c)
        vortex_count = 0
        for i in 2:(n_pts[1]-1), j in 2:(n_pts[2]-1)
            n_c[i, j] < threshold * n_max && continue
            # Plaquette phase winding
            dp = _phase_diff(phase_field[i+1, j], phase_field[i, j]) +
                 _phase_diff(phase_field[i+1, j+1], phase_field[i+1, j]) +
                 _phase_diff(phase_field[i, j+1], phase_field[i+1, j+1]) +
                 _phase_diff(phase_field[i, j], phase_field[i, j+1])
            if abs(dp) > π
                vortex_count += 1
            end
        end
        (vortex_count = vortex_count, component = component)
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
        (correlation_length = xi, correlation = corr, direction = direction)
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
            for i in 2:(n_pts[1]-1), j in 2:(n_pts[2]-1)
                n[i, j] < threshold && continue
                dp = _phase_diff(phase_field[i+1, j], phase_field[i, j]) +
                     _phase_diff(phase_field[i+1, j+1], phase_field[i+1, j]) +
                     _phase_diff(phase_field[i, j+1], phase_field[i+1, j+1]) +
                     _phase_diff(phase_field[i, j], phase_field[i, j+1])
                abs(dp) > π && (defect_count += 1)
            end
        end
        volume = prod(grid.config.box_size)
        (defect_count = defect_count, defect_density = defect_count / volume, defect_type = defect_type)
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
        (defect_count = defect_count, defect_density = defect_count / volume, n_samples = 1)
    elseif name == :bragg_spectroscopy
        F = atom.F
        ndim = length(grid.config.n_points)
        n_pts = grid.config.n_points
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
        D = 2F + 1
        # Static structure factor S(k) from density fluctuations
        n_total = total_density(psi, ndim)
        n_mean = sum(n_total) * cell_volume(grid)
        delta_n = n_total .- (n_mean / prod(grid.config.box_size))
        delta_nk = similar(delta_n, ComplexF64)
        delta_nk .= delta_n
        plans.forward * delta_nk
        Sk = abs2.(delta_nk) .* cell_volume(grid)^2
        (structure_factor = Sk,)
    elseif name == :column_density_movie
        # Column-integrated total density for every snapshot from the preceding
        # dynamics step, written as PNG frames. Requires prior dynamics step
        # with save_every > 0 (produces psi_snapshots).
        dynres = get(pipeline_results, :dynamics_result, nothing)
        dynres === nothing && throw(ArgumentError(
            "column_density_movie requires a preceding dynamics step with save_every > 0"))
        ndim = length(grid.config.n_points)
        ndim == 3 || throw(ArgumentError(
            "column_density_movie currently supports 3D only (got $(ndim)D)"))
        axis = Int(get(params, "axis", 3))
        output_dir = String(get(params, "output_dir", "frames"))
        mkpath(output_dir)
        colorscale = String(get(params, "colorscale", "Viridis"))
        width = Int(get(params, "width", 600))
        height = Int(get(params, "height", 500))
        title_fmt = get(params, "title_fmt", nothing)

        snaps = dynres.psi_snapshots
        times = dynres.times
        frames = String[]
        for (i, psi_s) in enumerate(snaps)
            n_total = total_density(psi_s, ndim)
            col = dropdims(sum(n_total; dims = axis); dims = axis)
            title = title_fmt === nothing ?
                "t = $(round(times[i], digits=3))" : string(title_fmt)
            png_path = joinpath(output_dir, "col_$(lpad(i, 4, '0')).png")
            save_column_density_png(grid, col, axis, png_path;
                title = title, colorscale = colorscale, width = width, height = height)
            push!(frames, png_path)
        end
        (output_dir = output_dir, n_frames = length(frames),
         frame_paths = frames, axis = axis)

    elseif name == :summary_json
        # Dump the accumulated pipeline_results plus QC metadata to a JSON file.
        output_path = String(get(params, "path", "summary.json"))
        extras = get(params, "extras", Dict{String,Any}())
        summary = Dict{String,Any}()
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
        (path = output_path, n_fields = length(summary))

    else
        _known = "tomography, faraday, energy_decomposition, phase_classify, stability, bogoliubov, " *
                 "multipole_order, winding_map, absorption_image, sg_tof, domain_analysis, skyrmion_density, " *
                 "phase_contrast_image, momentum_distribution, vortex_detect, correlation_length, " *
                 "defect_density, kibble_zurek_stats, bragg_spectroscopy, column_density_movie, summary_json"
        throw(ArgumentError("Unknown analyzer: $name. Supported: $_known"))
    end
end

function _phase_diff(a::Float64, b::Float64)
    d = a - b
    d > π ? d - 2π : d < -π ? d + 2π : d
end

"""
Extract the local spinor ζ at the density peak and run `bogoliubov_instability_scan`
using the physical couplings (c₀, c₁, c_k, c_dd) from the preceding ground-state step.

Returns a NamedTuple with `max_growth`, `unstable`, `k_peak`, `wavelength`,
`best_direction`, `pattern`, `anisotropy`, suitable for JLD2 persistence.
"""
function _run_bogoliubov_analyzer(psi, grid, atom, params, ws_prev)
    ws_prev === nothing &&
        throw(ArgumentError("bogoliubov analyzer requires a preceding ground_state step (ws_prev is nothing)"))

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
        spinor, n0, F, interactions, zeeman, c_dd = c_dd_val,
        k_max, n_k,
        directions = directions_arg,
        n_directions = n_dirs,
    )
    pred = predict_supersolid_params(imap)

    (
        n0 = n0,
        max_growth = imap.max_growth_rate,
        unstable = imap.unstable,
        k_peak = imap.most_unstable_k,
        wavelength = imap.predicted_wavelength,
        best_direction = imap.most_unstable_direction,
        pattern = pred.pattern_type,
        anisotropy = pred.angular_anisotropy,
    )
end
