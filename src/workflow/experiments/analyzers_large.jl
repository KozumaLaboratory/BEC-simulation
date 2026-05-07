# --- Large analyzer implementations extracted from _run_analyzer ---
#
# 5 of the 31 analyzer kinds had bodies > 70 lines each, accounting for
# ~415 lines of the original 977-line `_run_analyzer` switch. Each is now
# a standalone `_analyze_<name>(psi, grid, atom, params, ws_prev) -> Any`
# helper. The dispatcher in pipeline_analyzers.jl delegates via 1-line
# `elseif` branches.

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

function _analyze_synthetic_dim(psi, grid, atom, params, ws_prev)
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
end

function _analyze_bogoliubov_mode(psi, grid, atom, params, ws_prev)
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
end

function _analyze_rosensweig_pattern(psi, grid, atom, params, ws_prev)
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
end

function _analyze_column_density_movie(psi, grid, atom, params, ws_prev)
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
end
