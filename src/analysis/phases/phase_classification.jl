"""
    classify_phase(psi, F, grid, sm) → NamedTuple

Compute order parameters and classify the spinor phase.

Returns `(spin_order, nematic_order, channel_weights, phase, magnetization_density)`.
"""
function classify_phase(
    psi::AbstractArray{<:Complex},
    F::Int,
    grid::Grid{N},
    sm::SpinMatrices,
) where {N}
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)
    sys = sm.system

    n_total = total_density(psi, N)
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(n_total .^ 2) * dV
    n_sum < 1e-30 && return (
        spin_order=0.0,
        nematic_order=0.0,
        channel_weights=Dict{Int, Float64}(),
        phase=:vacuum,
        magnetization_density=0.0,
    )

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int, Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)

    Mz = magnetization(psi, grid, sys) / n_sum

    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    (
        spin_order=spin_order,
        nematic_order=nematic_order,
        channel_weights=cw_norm,
        phase=phase,
        magnetization_density=Mz,
    )
end

function _density_weighted_mean(field, density, dV)
    w = density .^ 2
    w_sum = sum(w) * dV
    w_sum < 1e-30 && return 0.0
    sum(field .* w) * dV / w_sum
end

function _majorana_star_entropy(spinor::AbstractVector{ComplexF64}, F::Int)
    F < 1 && return 0.0
    stars = majorana_stars(spinor, F)
    points = [_stereo_to_sphere(z) for z in stars]
    n_stars = length(points)
    n_stars == 0 && return 0.0

    n_bins = max(6, n_stars)
    cos_edges = range(-1.0, 1.0; length=n_bins + 1)
    counts = zeros(Float64, n_bins)
    for p in points
        cos_theta = clamp(p[3], -1.0, 1.0)
        bin = min(searchsortedlast(cos_edges, cos_theta), n_bins)
        bin = max(bin, 1)
        counts[bin] += 1.0
    end
    counts ./= n_stars
    S = 0.0
    for p in counts
        p > 0 && (S -= p * log(p))
    end
    S / log(n_bins)
end

function _mean_majorana_entropy(
    psi,
    F::Int,
    ndim::Int,
    n_total,
    dV;
    density_cutoff::Float64=1e-10,
    sampling::Float64=1.0,
)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    all_indices = vec(collect(CartesianIndices(n_pts)))
    indices = if sampling < 1.0
        rng = Random.MersenneTwister(0)
        n_sample = max(1, round(Int, length(all_indices) * sampling))
        perm = Random.randperm(rng, length(all_indices))
        all_indices[perm[1:n_sample]]
    else
        all_indices
    end
    w_sum = 0.0
    s_sum = 0.0
    @inbounds for I in indices
        ni = n_total[I]
        ni > density_cutoff || continue
        spinor = Vector{ComplexF64}(undef, D)
        norm_sq = 0.0
        for c in 1:D
            spinor[c] = psi[I, c]
            norm_sq += abs2(psi[I, c])
        end
        inv_norm = 1.0 / sqrt(norm_sq)
        spinor .*= inv_norm
        w = ni^2
        s_sum += w * _majorana_star_entropy(spinor, F)
        w_sum += w
    end
    w_sum < 1e-30 && return 0.0
    s_sum / w_sum
end

function _label_phase(spin_order, nematic_order, channel_weights, F)
    if spin_order > 0.9
        :ferromagnetic
    elseif nematic_order > 0.9
        F == 1 ? :polar : :nematic
    elseif get(channel_weights, 2F, 0.0) > 0.5
        :cyclic
    else
        :mixed
    end
end

"""
    PhaseReference

Reference feature vector for one canonical spinor phase, used by
`classify_phase_distance` to assign a label by minimum Euclidean
distance instead of the threshold cascade in `_label_phase`. Each
field carries a target value in `[0, 1]` (or `nothing` to skip the
component when computing distance — useful when a feature isn't
characterised for a phase, e.g. Q₆ is meaningless for F < 6).
"""
struct PhaseReference
    name::Symbol
    F::Int                         # spin manifold this reference applies to
    spin_order::Union{Nothing, Float64}
    nematic_order::Union{Nothing, Float64}
    biaxiality::Union{Nothing, Float64}
    Q6::Union{Nothing, Float64}
    dom_channel_S::Union{Nothing, Int}
    dom_channel_weight::Union{Nothing, Float64}
end

PhaseReference(name, F; spin_order=nothing, nematic_order=nothing,
biaxiality=nothing, Q6=nothing, dom_channel_S=nothing,
dom_channel_weight=nothing) = PhaseReference(name, F, spin_order,
    nematic_order, biaxiality, Q6, dom_channel_S, dom_channel_weight)

"""
    DEFAULT_PHASE_REFERENCES

Hand-curated reference table covering the canonical KU phases for
F=1, 2, and 6. Entries are conservative (only the most diagnostic
features per phase are populated), and `classify_phase_distance`
falls back to `:unknown` when no reference is within the user-supplied
distance threshold. New phase candidates can be appended at any time
via the `references` kwarg without editing this constant.
"""
const DEFAULT_PHASE_REFERENCES = PhaseReference[
    # F = 1
    PhaseReference(:ferromagnetic, 1; spin_order=1.0, nematic_order=0.0),
    PhaseReference(:polar, 1; spin_order=0.0, nematic_order=1.0),
    # F = 2
    PhaseReference(:ferromagnetic, 2; spin_order=1.0, nematic_order=0.0),
    PhaseReference(:uniaxial_nematic, 2; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0),
    PhaseReference(:biaxial_nematic, 2; spin_order=0.0, nematic_order=0.5,
        biaxiality=1.0),
    PhaseReference(:cyclic, 2; spin_order=0.0, nematic_order=0.0,
        dom_channel_S=4, dom_channel_weight=1.0),
    # F = 6 (Eu151) — KU §7.5 candidate phases. Q6 is the icosahedral
    # Steinhardt order (0 for axial / cyclic, ~1 for the icosahedral
    # state). Reference values are best-guess analytic limits;
    # appending data-driven references is encouraged.
    PhaseReference(:ferromagnetic, 6; spin_order=1.0, nematic_order=0.0,
        Q6=0.0),
    PhaseReference(:polar, 6; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0, Q6=0.0),
    PhaseReference(:cyclic, 6; spin_order=0.0, nematic_order=0.0,
        dom_channel_S=12, dom_channel_weight=1.0),
    PhaseReference(:biaxial_nematic, 6; spin_order=0.0, biaxiality=1.0,
        Q6=0.0),
    PhaseReference(:icosahedral, 6; spin_order=0.0, nematic_order=0.0,
        Q6=1.0),
]

"""
    classify_phase_distance(features::NamedTuple, F::Int;
                            references=DEFAULT_PHASE_REFERENCES,
                            threshold=0.4) → NamedTuple

Multi-feature reference-distance phase classifier. `features` is a
`NamedTuple` produced by `classify_phase_detailed` (or any subset
containing the fields listed in `PhaseReference`). For each reference
matching the supplied `F`, compute the Euclidean distance over every
feature that is non-`nothing` in the reference, then return the
nearest match — or `:unknown` when the minimum exceeds `threshold`,
which is the hint that a new / unmodelled phase has been reached.

Returns `(phase, distance, scores::Vector{NamedTuple})` where each
`score` is `(name, distance, n_features_compared)` so callers can
plot the relative distances and tune `threshold` from data.
"""
function classify_phase_distance(features::NamedTuple, F::Int;
    references::Vector{PhaseReference}=DEFAULT_PHASE_REFERENCES,
    threshold::Float64=0.4)
    scores = NamedTuple[]
    for ref in references
        ref.F == F || continue
        d_sq = 0.0
        n_used = 0
        if ref.spin_order !== nothing && haskey(features, :spin_order)
            d_sq += (features.spin_order - ref.spin_order)^2
            n_used += 1
        end
        if ref.nematic_order !== nothing && haskey(features, :nematic_order)
            d_sq += (features.nematic_order - ref.nematic_order)^2
            n_used += 1
        end
        if ref.biaxiality !== nothing && haskey(features, :biaxiality)
            d_sq += (features.biaxiality - ref.biaxiality)^2
            n_used += 1
        end
        if ref.Q6 !== nothing && haskey(features, :Q6)
            d_sq += (features.Q6 - ref.Q6)^2
            n_used += 1
        end
        if ref.dom_channel_S !== nothing && ref.dom_channel_weight !== nothing &&
            haskey(features, :channel_weights)
            cw = features.channel_weights
            obs_w = get(cw, ref.dom_channel_S, 0.0)
            d_sq += (obs_w - ref.dom_channel_weight)^2
            n_used += 1
        end
        n_used > 0 || continue
        d = sqrt(d_sq / n_used)
        push!(scores, (name=ref.name, distance=d, n_features_compared=n_used))
    end
    isempty(scores) && return (phase=:unknown, distance=Inf, scores=scores)
    sort!(scores; by=s -> s.distance)
    best = scores[1]
    phase = best.distance <= threshold ? best.name : :unknown
    (phase=phase, distance=best.distance, scores=scores)
end

"""
    classify_phase_detailed(psi, F, grid, sm) → NamedTuple

Extended phase classification with continuous order parameters.

Returns `(spin_order, nematic_order, biaxiality, Q6, star_entropy,
          channel_weights, magnetization_density, phase)`.
"""
function classify_phase_detailed(
    psi::AbstractArray{<:Complex},
    F::Int,
    grid::Grid{N},
    sm::SpinMatrices;
    sampling::Float64=1.0,
) where {N}
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)

    n_total = total_density(psi, N)
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(n_total .^ 2) * dV
    if n_sum < 1e-30
        return (
            spin_order=0.0,
            nematic_order=0.0,
            biaxiality=0.0,
            Q6=0.0,
            star_entropy=0.0,
            channel_weights=Dict{Int, Float64}(),
            magnetization_density=0.0,
            phase=:vacuum,
            point_group=:trivial,
        )
    end

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int, Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)

    l1, l2, l3 = nematic_tensor_eigenvalues(psi, sm, N)
    biax = biaxiality_parameter(l1, l2, l3)
    mean_biax = _density_weighted_mean(biax, n_total, dV)

    Q6_field = icosahedral_order_parameter(psi, grid, sm; sampling)
    mean_Q6 = _density_weighted_mean(Q6_field, n_total, dV)

    star_entropy = _mean_majorana_entropy(psi, F, N, n_total, dV; sampling)

    sys = sm.system
    Mz = magnetization(psi, grid, sys) / n_sum

    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    pg = _peak_point_group(psi, F, N, n_total, dV)

    (
        spin_order=spin_order,
        nematic_order=nematic_order,
        biaxiality=mean_biax,
        Q6=mean_Q6,
        star_entropy=star_entropy,
        channel_weights=cw_norm,
        magnetization_density=Mz,
        phase=phase,
        point_group=pg,
    )
end
