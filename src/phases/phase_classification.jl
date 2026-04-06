"""
    classify_phase(psi, F, grid, sm) → NamedTuple

Compute order parameters and classify the spinor phase.

Returns `(spin_order, nematic_order, channel_weights, phase, magnetization_density)`.
"""
function classify_phase(
    psi::AbstractArray{ComplexF64},
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
        spin_order = 0.0,
        nematic_order = 0.0,
        channel_weights = Dict{Int,Float64}(),
        phase = :vacuum,
        magnetization_density = 0.0,
    )

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int,Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)

    Mz = magnetization(psi, grid, sys) / n_sum

    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    (
        spin_order = spin_order,
        nematic_order = nematic_order,
        channel_weights = cw_norm,
        phase = phase,
        magnetization_density = Mz,
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
    cos_edges = range(-1.0, 1.0, length = n_bins + 1)
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
    density_cutoff::Float64 = 1e-10,
    sampling::Float64 = 1.0,
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
        for c = 1:D
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
    classify_phase_detailed(psi, F, grid, sm) → NamedTuple

Extended phase classification with continuous order parameters.

Returns `(spin_order, nematic_order, biaxiality, Q6, star_entropy,
          channel_weights, magnetization_density, phase)`.
"""
function classify_phase_detailed(
    psi::AbstractArray{ComplexF64},
    F::Int,
    grid::Grid{N},
    sm::SpinMatrices;
    sampling::Float64 = 1.0,
) where {N}
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)

    n_total = total_density(psi, N)
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(n_total .^ 2) * dV
    if n_sum < 1e-30
        return (
            spin_order = 0.0,
            nematic_order = 0.0,
            biaxiality = 0.0,
            Q6 = 0.0,
            star_entropy = 0.0,
            channel_weights = Dict{Int,Float64}(),
            magnetization_density = 0.0,
            phase = :vacuum,
            point_group = :trivial,
        )
    end

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int,Float64}()
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
        spin_order = spin_order,
        nematic_order = nematic_order,
        biaxiality = mean_biax,
        Q6 = mean_Q6,
        star_entropy = star_entropy,
        channel_weights = cw_norm,
        magnetization_density = Mz,
        phase = phase,
        point_group = pg,
    )
end
