export classify_phase, classify_phase_detailed, classify_phase_distance
export PhaseReference, DEFAULT_PHASE_REFERENCES

# Phase classification — two complementary axes
# ==============================================
#
# Spinor BEC ground-state phases are classified along two complementary
# axes that are both populated by `classify_phase_detailed`:
#
# 1. **Magnetic-order / channel-weight axis** (`phase` field):
#    KU-style coarse labels — :ferromagnetic / :polar / :nematic /
#    :cyclic / :mixed / :vacuum. Derived from continuous order
#    parameters (spin_order, nematic_order, channel_weights). Decision
#    cascade lives in `_label_phase`. This axis is robust for F = 1, 2
#    where the standard KU classification covers all candidate ground
#    states.
#
# 2. **Point-group axis** (`point_group` field):
#    `:I_h / :O_h / :T_d / :D_nh / :trivial / :unknown` from peak-density
#    Majorana-star geometry via `detect_point_group`. Identifies
#    polyhedral inert states relevant for F ≥ 2 (see Paper #3
#    "Universal Structure Theorem for LHY Corrections in Spinor BECs",
#    `docs/manuscript/papers/paper3_universal_theorem/main.md`).
#
# Paper #3 § V verification list and corresponding code support
# (post-U2 stereo fix + F=8 / F=10 extension):
#
#   F  Phase                     Point group   detect_point_group
#   -- ------------------------- ------------- ----------------------
#   2  cyclic                    T_d           ✓ (4 stars → :T_d)
#   3  octahedral (O:A_2)        O / O_h       ✓ (6 stars → :O_h, A_1/A_2
#                                                rep distinction is
#                                                rep-theoretic only)
#   4  cube                      O_h           ✓ (8 stars → :O_h)
#   6  icosahedral (I_h)         I_h           ✓ (12 stars → :I_h)
#   8  cube-like octahedral      O / O_h       ✓ (16 stars → :O_h)
#   10 dodecahedral              I_h           ✓ (20 stars → :I_h)
#   12 icosahedral I:A           I_h           ✓ (24 stars → :I_h)
#
# All regression tests in `test/hamiltonian/test_majorana.jl` pin
# each case against the canonical Paper #3 inert state spinor.
#
# The Sign Pattern Theorem (Paper #3 §VI; β_S coefficients with
# closed-form sign-change boundary S_bd(F) = √(2F(F+1))) is exposed
# at runtime via U3 (separate task).

# Shared magnetic-order / channel-weight axis computed by both
# `classify_phase` and `classify_phase_detailed`. Returns the order
# parameters plus the density field and `dV` the detailed extensions
# reuse, and `is_vacuum` so each caller can emit its own (different-arity)
# vacuum NamedTuple.
function _order_parameters_core(
    psi::AbstractArray{<:Complex},
    F::Int,
    grid::Grid{N},
    sm::SpinMatrices,
) where {N}
    D = 2F + 1
    dV = cell_volume(grid)

    n_total = total_density(psi, N)
    # `sum(n_total .^ 2)` allocates an n_pts-shape temp; `sum(x->x*x, n)`
    # reduces in-place.
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(x -> x * x, n_total) * dV
    if n_sum < COUPLING_TOL
        return (
            spin_order=0.0,
            nematic_order=0.0,
            channel_weights=Dict{Int, Float64}(),
            magnetization_density=0.0,
            phase=:vacuum,
            n_total=n_total,
            dV=dV,
            is_vacuum=true,
        )
    end

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        f_mag_sq_sum += fx[i]^2 + fy[i]^2 + fz[i]^2
    end
    f_mag_sq_sum *= dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int, Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)
    Mz = magnetization(psi, grid, sm.system) / n_sum
    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    (
        spin_order=spin_order,
        nematic_order=nematic_order,
        channel_weights=cw_norm,
        magnetization_density=Mz,
        phase=phase,
        n_total=n_total,
        dV=dV,
        is_vacuum=false,
    )
end

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
    core = _order_parameters_core(psi, F, grid, sm)
    (
        spin_order=core.spin_order,
        nematic_order=core.nematic_order,
        channel_weights=core.channel_weights,
        phase=core.phase,
        magnetization_density=core.magnetization_density,
    )
end

function _density_weighted_mean(field, density, dV)
    # Manual fused reduction: `density.^2` and `field .* w` were both
    # n_pts-shape temporaries.
    w_sum = 0.0
    fw_sum = 0.0
    @inbounds for i in eachindex(field, density)
        wi = density[i]^2
        w_sum += wi
        fw_sum += field[i] * wi
    end
    w_sum < COUPLING_TOL && return 0.0
    fw_sum / w_sum
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
    w_sum < COUPLING_TOL && return 0.0
    s_sum / w_sum
end

function _label_phase(spin_order, nematic_order, channel_weights, F)
    if spin_order > 0.9
        :ferromagnetic
    elseif nematic_order > 0.9
        # NOT GENERALIZABLE: F=1 reports `:polar`, F≥2 reports `:nematic` for same observable.
        # Reason: physics (terminology, not algorithm)
        # Why: at F=1 the ζ_α = δ_{α,0} state is conventionally *polar* (Kawaguchi-
        #   Ueda §3.1, Stamper-Kurn 2013); at F≥2 the same m=0-dominant inert state
        #   is *nematic* (Yip, Mäkelä-Suominen 2007). Identical spinor structure;
        #   split is community convention, not a physics flip.
        # See: CLAUDE.md §"Phase nomenclature"
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

The `point_group` field is categorical (a `Symbol` from `_peak_point_group`
e.g. `:T_d`, `:O_h`, `:I_h`, `:trivial`); a mismatch contributes a fixed
unit penalty to the distance instead of a Euclidean component. This is
the only discriminator between polar (m=0 only, point_group ≠ polyhedral)
and the Paper #3 polyhedral inert states, since the Lemma 1 identity
β_0 = 1/(2F+1) forces `nematic_order = 1` on both.
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
    point_group::Union{Nothing, Symbol}
end

PhaseReference(name, F; spin_order=nothing, nematic_order=nothing,
    biaxiality=nothing, Q6=nothing, dom_channel_S=nothing,
    dom_channel_weight=nothing, point_group=nothing) = PhaseReference(name, F,
    spin_order, nematic_order, biaxiality, Q6, dom_channel_S,
    dom_channel_weight, point_group)

"""
    DEFAULT_PHASE_REFERENCES

Hand-curated reference table covering the canonical KU phases plus the
seven Paper #3 §V polyhedral inert states. Entries are conservative
(only the most diagnostic features per phase are populated), and
`classify_phase_distance` falls back to `:unknown` when no reference is
within the user-supplied distance threshold. New phase candidates can
be appended at any time via the `references` kwarg without editing
this constant.

Cross-reference (Paper #3 verification list, §V; canonical ζ vectors
live in `canonical_polyhedral_states.jl`):

| F  | Section | Point group | Phase symbol            |
|----|---------|-------------|-------------------------|
| 2  | §V.A    | T_d         | `:cyclic`               |
| 3  | §V.B    | O (A_2)     | `:octahedral`           |
| 4  | §V.C    | O_h (A_1)   | `:cubic`                |
| 6  | §V.D    | I_h         | `:icosahedral`          |
| 8  | §V.E    | O_h (A_1)   | `:cube_octahedral`      |
| 10 | §V.F    | I_h         | `:dodecahedral`         |

All polyhedral inert states have `spin_order = 0` (Schur singlet identity,
Paper #3 Sign Pattern Lemma 1). The `:icosahedral` / `:dodecahedral`
references additionally fingerprint via `Q6 = 1` (perfect Steinhardt
icosahedral order); `:octahedral` / `:cubic` / `:cube_octahedral` use
`Q6 = 0` to discriminate from icosahedral neighbours when both apply
(F ≥ 6 only).
"""
const DEFAULT_PHASE_REFERENCES = PhaseReference[
    # F = 1 (no polyhedral inert state — Paper #3 §VI.B "F=1 exception")
    PhaseReference(:ferromagnetic, 1; spin_order=1.0, nematic_order=0.0),
    PhaseReference(:polar, 1; spin_order=0.0, nematic_order=1.0),
    # F = 2 (KU 2000 / Ciobanu-Yip-Ho 2000; cyclic → Paper #3 §V.A T_d)
    PhaseReference(:ferromagnetic, 2; spin_order=1.0, nematic_order=0.0),
    PhaseReference(:uniaxial_nematic, 2; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0),
    PhaseReference(:biaxial_nematic, 2; spin_order=0.0, nematic_order=0.5,
        biaxiality=1.0),  # D_4 axial (Paper #3 §VII.A)
    PhaseReference(:cyclic, 2; spin_order=0.0, nematic_order=0.0,
        dom_channel_S=4, dom_channel_weight=1.0,
        point_group=:T_d),
    # F = 3 — Paper #3 §V.B octahedral (O:A_2)
    PhaseReference(:ferromagnetic, 3; spin_order=1.0, nematic_order=0.0,
        point_group=:trivial),
    PhaseReference(:polar, 3; spin_order=0.0, nematic_order=1.0,
        point_group=:trivial),
    PhaseReference(:octahedral, 3; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0, point_group=:O_h),  # Lemma 1 β_0=1/(2F+1) → nem=1
    # F = 4 — Paper #3 §V.C cube (O_h:A_1)
    PhaseReference(:ferromagnetic, 4; spin_order=1.0, nematic_order=0.0,
        point_group=:trivial),
    PhaseReference(:polar, 4; spin_order=0.0, nematic_order=1.0,
        point_group=:trivial),
    PhaseReference(:cubic, 4; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.89, point_group=:O_h),
    # F = 6 (Eu151) — KU §7.5 + Paper #3 §V.D candidate phases.
    # Note: all polyhedral inert states satisfy Lemma 1 β_0 = 1/(2F+1),
    # which implies nematic_order = 1 (not 0). `point_group` is the
    # primary discriminator between polar and polyhedral.
    PhaseReference(:ferromagnetic, 6; spin_order=1.0, nematic_order=0.0,
        point_group=:trivial),
    PhaseReference(:polar, 6; spin_order=0.0, nematic_order=1.0,
        point_group=:trivial),
    PhaseReference(:cyclic, 6; spin_order=0.0, nematic_order=0.0,
        dom_channel_S=12, dom_channel_weight=1.0),
    PhaseReference(:biaxial_nematic, 6; spin_order=0.0, biaxiality=1.0,
        point_group=:trivial),  # axial (Paper #3 §VII)
    PhaseReference(:icosahedral, 6; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0, Q6=1.0, point_group=:I_h),  # Paper #3 §V.D
    # F = 8 (Dy relevance) — Paper #3 §V.E cube-like octahedral (O_h:A_1)
    PhaseReference(:ferromagnetic, 8; spin_order=1.0, nematic_order=0.0,
        point_group=:trivial),
    PhaseReference(:polar, 8; spin_order=0.0, nematic_order=1.0,
        point_group=:trivial),
    PhaseReference(:cube_octahedral, 8; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.0, point_group=:O_h),  # 16 stars on cube + octa orbits
    # F = 10 — Paper #3 §V.F dodecahedral (I_h)
    PhaseReference(:ferromagnetic, 10; spin_order=1.0, nematic_order=0.0,
        point_group=:trivial),
    PhaseReference(:polar, 10; spin_order=0.0, nematic_order=1.0,
        point_group=:trivial),
    PhaseReference(:dodecahedral, 10; spin_order=0.0, nematic_order=1.0,
        biaxiality=0.97, point_group=:I_h),  # ZETA_F10_IH_DODEC
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
        if ref.point_group !== nothing && haskey(features, :point_group)
            d_sq += features.point_group === ref.point_group ? 0.0 : 1.0
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
    core = _order_parameters_core(psi, F, grid, sm)
    if core.is_vacuum
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

    n_total = core.n_total
    dV = core.dV

    l1, l2, l3 = nematic_tensor_eigenvalues(psi, sm, N)
    biax = biaxiality_parameter(l1, l2, l3)
    mean_biax = _density_weighted_mean(biax, n_total, dV)

    Q6_field = icosahedral_order_parameter(psi, grid, sm; sampling)
    mean_Q6 = _density_weighted_mean(Q6_field, n_total, dV)

    star_entropy = _mean_majorana_entropy(psi, F, N, n_total, dV; sampling)

    pg = _peak_point_group(psi, F, N, n_total, dV)

    (
        spin_order=core.spin_order,
        nematic_order=core.nematic_order,
        biaxiality=mean_biax,
        Q6=mean_Q6,
        star_entropy=star_entropy,
        channel_weights=core.channel_weights,
        magnetization_density=core.magnetization_density,
        phase=core.phase,
        point_group=pg,
    )
end
