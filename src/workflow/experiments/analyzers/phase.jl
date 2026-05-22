# --- Phase-classifier analyzers ---
#
# Order-parameter / phase-detection analyzers: the threshold-cascade
# `classify_phase_detailed` (used by both `phase_classify` and
# `energy_decomposition`), the reference-distance variant for F ≥ 6
# where thresholds saturate, plus multipole-spectrum and Steinhardt-
# icosahedral (Q₆) order parameters.

function _analyze_phase_classify(psi, grid, atom, params, ws_prev)
    F = atom.F
    sm = spin_matrices(F)
    classify_phase_detailed(psi, F, grid, sm)
end

# `:energy_decomposition` was a separate analyzer name but always called
# the exact same `classify_phase_detailed` path as `:phase_classify`.
# Aliased to the canonical name; the dispatch table maps both Symbols
# to this single implementation.
const _analyze_energy_decomposition = _analyze_phase_classify

function _analyze_phase_classify_distance(psi, grid, atom, params, ws_prev)
    # Reference-distance classifier — primarily useful for F >= 6 where
    # the threshold-cascade `_label_phase` saturates. Returns the
    # detailed feature vector plus the distance ranking.
    F = atom.F
    sm = spin_matrices(F)
    details = classify_phase_detailed(psi, F, grid, sm)
    threshold = Float64(get(params, "threshold", 0.4))
    ranking = classify_phase_distance(details, F; threshold=threshold)
    merge(
        details,
        (
            phase_distance=ranking.phase,
            distance=ranking.distance,
            ranking=ranking.scores,
        ),
    )
end

function _analyze_multipole_order(psi, grid, atom, params, ws_prev)
    F = atom.F
    ranks = let v = get(params, "ranks", nothing)
        v === nothing ? collect(0:2:2F) : Int.(v)
    end
    spectrum = multipole_spectrum(psi, F, grid)
    selected = Dict{Int, Float64}(k => get(spectrum, k, 0.0) for k in ranks)
    (multipole_spectrum=selected, ranks=ranks)
end

function _analyze_majorana_order(psi, grid, atom, params, ws_prev)
    # Per-point Steinhardt Q₆ icosahedral order parameter from the
    # Majorana stars decomposition (only meaningful for F >= 6).
    # Returns the spatially-averaged Q₆ weighted by density and a
    # field of point-group symbols at sampled points.
    F = atom.F
    if F < 6
        # 2026-05-22 verification suite (L1 yaml 04 spin-2 cyclic) listed
        # `majorana_order` as an analyzer step. Q₆ is icosahedral and only
        # meaningful for F ≥ 6; lower F should skip gracefully rather than
        # crash the whole pipeline.
        @warn "majorana_order skipped: F=$F < 6 (Q₆ icosahedral order requires F ≥ 6)"
        return (q6_avg=NaN, q6_max=NaN, q6_field=Float64[], sampling=NaN,
            skipped=true, reason="F=$F below F=6 threshold")
    end
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
end
