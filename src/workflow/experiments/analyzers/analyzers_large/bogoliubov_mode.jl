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
    zeeman = if is_uniform(ws_prev.zeeman)
        ZeemanParams(linear_p(ws_prev.zeeman), quadratic_q(ws_prev.zeeman))
    else
        ZeemanParams(0.0, 0.0)
    end

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
    if is_active(c_dd_val)
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
