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
