export majorana_stars, icosahedral_order_parameter, detect_point_group

"""
Majorana polynomial coefficients for a spin-F spinor.
P(z) = Σ_{k=0}^{2F} (-1)^k √C(2F,k) ψ_{F-k} z^k
where ψ_{F-k} is the component with m = F-k (index k+1).
"""
function _majorana_polynomial(spinor::AbstractVector{ComplexF64}, F::Int)
    n = 2F + 1
    coeffs = Vector{ComplexF64}(undef, n)
    for k in 0:2F
        coeffs[k + 1] = (-1)^k * sqrt(binomial(2F, k)) * spinor[k + 1]
    end
    coeffs
end

"""
Find 2F Majorana stars (roots of the Majorana polynomial) via companion matrix.
Returns `Vector{ComplexF64}` of length 2F.
Roots at infinity (when leading coefficients vanish) are represented as `complex(Inf)`.
"""
function majorana_stars(spinor::AbstractVector{ComplexF64}, F::Int)
    n = 2F
    n == 0 && return ComplexF64[]
    coeffs = _majorana_polynomial(spinor, F)

    deg = n
    while deg >= 1 && abs(coeffs[deg + 1]) < 1e-14
        deg -= 1
    end
    deg == 0 && return fill(complex(Inf), n)

    if deg == 1
        roots = [-coeffs[1] / coeffs[2]]
    else
        c = coeffs[1:(deg + 1)]
        companion = zeros(ComplexF64, deg, deg)
        for i in 1:(deg - 1)
            companion[i + 1, i] = 1.0
        end
        for i in 1:deg
            companion[i, deg] = -c[i] / c[deg + 1]
        end
        roots = eigvals(companion)
    end

    n_inf = n - deg
    if n_inf > 0
        append!(roots, fill(complex(Inf), n_inf))
    end
    roots
end

"""
Stereographic projection: complex plane → unit sphere.
z → (2Re(z), 2Im(z), |z|²-1) / (|z|²+1)
- z = 0   maps to south pole (0, 0, -1)
- z = ∞   maps to north pole (0, 0, +1)   ← limit of the formula

(Bug fix 2026-05-12, U2: pre-fix code mapped both z=0 AND z=∞ to the
south pole, causing two distinct Majorana roots to collide on the
same sphere point. This broke point-group detection for any spinor
with a vanishing m=+F component — e.g. ZETA_F6_IH where the m=+F=6
component is 0 produces a root at infinity that the bug folded onto
the south pole alongside the z=0 root, masking the I_h icosahedron
pattern.)
"""
function _stereo_to_sphere(z::ComplexF64)
    if !isfinite(z)
        return (0.0, 0.0, 1.0)
    end
    r2 = abs2(z)
    inv_denom = 1.0 / (r2 + 1.0)
    (2.0 * real(z) * inv_denom, 2.0 * imag(z) * inv_denom, (r2 - 1.0) * inv_denom)
end

"""
Legendre polynomial P₆(x) = (231x⁶ - 315x⁴ + 105x² - 5) / 16.
"""
function _legendre_p6(x::Float64)
    x2 = x * x
    x4 = x2 * x2
    x6 = x4 * x2
    (231.0 * x6 - 315.0 * x4 + 105.0 * x2 - 5.0) / 16.0
end

"""
Steinhardt Q₆ bond-orientational order parameter, normalized so Q₆ = 1
for a perfect icosahedron.

Q₆_raw = √(4π/13 · (1/N²) Σ_{i,j} P₆(n̂_i · n̂_j))
Normalized: Q₆ = Q₆_raw / Q₆_icosa where Q₆_icosa ≈ 0.6633.
Q₆_icosa is computed from 12 vertices of a regular icosahedron (Steinhardt Table I).

Ref: Steinhardt, Nelson, Ronchetti, Phys. Rev. B 28, 784 (1983), Table I.
"""
function _steinhardt_q6(points::Vector{NTuple{3, Float64}})
    N = length(points)
    N == 0 && return 0.0

    s = 0.0
    @inbounds for i in 1:N
        for j in 1:N
            costh =
                points[i][1] * points[j][1] +
                points[i][2] * points[j][2] +
                points[i][3] * points[j][3]
            costh = clamp(costh, -1.0, 1.0)
            s += _legendre_p6(costh)
        end
    end

    q6_raw = sqrt(4π / 13.0 * s / N^2)
    q6_raw / 0.6633
end

# --- Point group detection from Majorana star geometry ---

function _pairwise_distance_spectrum(points::Vector{NTuple{3, Float64}})
    n = length(points)
    dists = Float64[]
    for i in 1:n
        for j in (i + 1):n
            costh = clamp(
                points[i][1]*points[j][1] +
                points[i][2]*points[j][2] +
                points[i][3]*points[j][3],
                -1.0,
                1.0,
            )
            push!(dists, acos(costh))
        end
    end
    sort!(dists)
    dists
end

function _spectrum_rms(a::Vector{Float64}, b::Vector{Float64})
    length(a) != length(b) && return Inf
    isempty(a) && return 0.0
    sqrt(sum((a[i] - b[i])^2 for i in eachindex(a)) / length(a))
end

function _make_icosahedron_vertices()
    phi = (1.0 + sqrt(5.0)) / 2.0
    raw = NTuple{3, Float64}[]
    for s1 in (-1.0, 1.0), s2 in (-1.0, 1.0)
        push!(raw, (0.0, s1, s2 * phi))
        push!(raw, (s1, s2 * phi, 0.0))
        push!(raw, (s2 * phi, 0.0, s1))
    end
    map(p -> let r = sqrt(p[1]^2 + p[2]^2 + p[3]^2);
            (p[1]/r, p[2]/r, p[3]/r)
        end, raw)
end

function _make_octahedron_vertices()
    verts = NTuple{3, Float64}[]
    for d in 1:3, s in (-1.0, 1.0)
        v = ntuple(i -> i == d ? s : 0.0, 3)
        push!(verts, v)
    end
    verts
end

function _make_cube_vertices()
    verts = NTuple{3, Float64}[]
    inv_sqrt3 = 1.0 / sqrt(3.0)
    for sx in (-1.0, 1.0), sy in (-1.0, 1.0), sz in (-1.0, 1.0)
        push!(verts, (sx * inv_sqrt3, sy * inv_sqrt3, sz * inv_sqrt3))
    end
    verts
end

function _make_tetrahedron_vertices()
    [
        (1.0, 1.0, 1.0) ./ sqrt(3.0),
        (1.0, -1.0, -1.0) ./ sqrt(3.0),
        (-1.0, 1.0, -1.0) ./ sqrt(3.0),
        (-1.0, -1.0, 1.0) ./ sqrt(3.0),
    ]
end

const _REF_ICOSAHEDRON = _pairwise_distance_spectrum(_make_icosahedron_vertices())
const _REF_OCTAHEDRON = _pairwise_distance_spectrum(_make_octahedron_vertices())
const _REF_CUBE = _pairwise_distance_spectrum(_make_cube_vertices())
const _REF_TETRAHEDRON = _pairwise_distance_spectrum(_make_tetrahedron_vertices())

# --- Paper #3 §V.E / §V.F reference spectra for F=8, F=10 inert states ---
#
# For F=8 cube-like octahedral (O:A_1) and F=10 dodecahedral (I_h), the
# Majorana stars form orbit-unions of the respective point groups that
# don't correspond to a single named "vertex polyhedron". We compute the
# reference spectra DIRECTLY from the canonical paper #3 state spinors
# at module-load time. See `docs/manuscript/papers/paper3_universal_theorem/main.md`
# §V.E (Eq. V.E.1) and §V.F (Eq. V.F.1) for derivation.

function _make_F8_octa_A1_stars()
    # Paper #3 §V.E.1: ζ = √390/48 (|+8⟩+|−8⟩) + √42/24 (|+4⟩+|−4⟩) + √33/8 |0⟩
    # Component order: m=+8, +7, ..., -8.
    zeta = zeros(ComplexF64, 17)
    zeta[1]  = sqrt(390) / 48      # m=+8
    zeta[5]  = sqrt(42) / 24       # m=+4
    zeta[9]  = sqrt(33) / 8        # m=0
    zeta[13] = sqrt(42) / 24       # m=-4
    zeta[17] = sqrt(390) / 48      # m=-8
    stars = majorana_stars(zeta, 8)
    [_stereo_to_sphere(z) for z in stars]
end

function _make_F10_dodec_stars()
    # Paper #3 §V.F.1: ζ = √561/75(|+10⟩+|−10⟩) + √209/25(|+5⟩−|−5⟩) + √741/75|0⟩
    zeta = zeros(ComplexF64, 21)
    zeta[1]  = sqrt(561) / 75      # m=+10
    zeta[6]  = sqrt(209) / 25      # m=+5
    zeta[11] = sqrt(741) / 75      # m=0
    zeta[16] = -sqrt(209) / 25     # m=-5
    zeta[21] = sqrt(561) / 75      # m=-10
    stars = majorana_stars(zeta, 10)
    [_stereo_to_sphere(z) for z in stars]
end

const _REF_F8_OCTA_A1 = _pairwise_distance_spectrum(_make_F8_octa_A1_stars())
const _REF_F10_DODEC = _pairwise_distance_spectrum(_make_F10_dodec_stars())

"""
    detect_point_group(spinor, F; tol=0.15) → Symbol

Detect the point group symmetry of a spinor from its Majorana star geometry.

Computes 2F Majorana stars, projects to the unit sphere, and compares the sorted
pairwise angular distance spectrum against reference polyhedra.

Returns `:I_h` (icosahedral), `:O_h` (octahedral/cubic), `:T_d` (tetrahedral),
`:D_nh` (dihedral), `:trivial` (all stars clustered), or `:unknown`.

Coverage (vs Paper #3 §V verification list, see
`docs/manuscript/papers/paper3_universal_theorem/main.md`):

- F=2 cyclic (T_d, §V.A): ✓ `:T_d` (4 Majorana stars on tetrahedron).
- F=3 octahedral (O:A_2, §V.B): ✓ `:O_h` (6 stars on octahedron). The
  A_2 sign-rep vs A_1 trivial-rep distinction is representation-
  theoretic — not surfaced by Majorana geometry alone.
- F=4 cube (O_h, §V.C): ✓ `:O_h` (8 stars on cube).
- F=6 icosahedral (I_h, §V.D): ✓ `:I_h` (12 stars on icosahedron, post
  stereo-bug fix in commit a9a3d95).
- F=8 cube-like octahedral (O:A_1, §V.E): ✓ `:O_h` (16 stars; reference
  spectrum computed from the canonical paper-#3 spinor at module-load
  time — see `_make_F8_octa_A1_stars`). Dy^164 relevance.
- F=10 dodecahedral (I_h, §V.F): ✓ `:I_h` (20 stars; reference from
  canonical paper-#3 spinor via `_make_F10_dodec_stars`).
- F=12 (§V.G): ✗ not yet implemented (24 stars). Follow-up commit.

Regression tests in `test/hamiltonian/test_majorana.jl` pin each
case against the paper #3 canonical state spinor.
"""
function detect_point_group(spinor::AbstractVector{ComplexF64}, F::Int; tol::Float64=0.15)
    n_stars = 2F
    n_stars == 0 && return :trivial

    stars = majorana_stars(spinor, F)
    points = [_stereo_to_sphere(z) for z in stars]

    n_inf = count(!isfinite, stars)
    n_inf == n_stars && return :trivial

    finite_pts = [_stereo_to_sphere(z) for z in stars if isfinite(z)]
    if length(finite_pts) <= 1
        return :trivial
    end

    max_spread = 0.0
    for i in eachindex(finite_pts), j in (i + 1):length(finite_pts)
        costh = clamp(
            finite_pts[i][1]*finite_pts[j][1] +
            finite_pts[i][2]*finite_pts[j][2] +
            finite_pts[i][3]*finite_pts[j][3],
            -1.0,
            1.0,
        )
        max_spread = max(max_spread, acos(costh))
    end
    max_spread < 0.1 && return :trivial

    spec = _pairwise_distance_spectrum(points)

    best_sym = :unknown
    best_rms = Inf

    if n_stars == 12
        rms = _spectrum_rms(spec, _REF_ICOSAHEDRON)
        if rms < best_rms
            best_rms = rms
            best_sym = :I_h
        end
    end

    if n_stars == 6
        rms = _spectrum_rms(spec, _REF_OCTAHEDRON)
        if rms < best_rms
            best_rms = rms
            best_sym = :O_h
        end
    end

    if n_stars == 8
        rms = _spectrum_rms(spec, _REF_CUBE)
        if rms < best_rms
            best_rms = rms
            best_sym = :O_h
        end
    end

    if n_stars == 4
        rms = _spectrum_rms(spec, _REF_TETRAHEDRON)
        if rms < best_rms
            best_rms = rms
            best_sym = :T_d
        end
    end

    # F=8 cube-like octahedral (Paper #3 §V.E, Dy relevance). 16 stars
    # form a union of octahedral orbits — reference computed from the
    # canonical paper #3 spinor.
    if n_stars == 16
        rms = _spectrum_rms(spec, _REF_F8_OCTA_A1)
        if rms < best_rms
            best_rms = rms
            best_sym = :O_h
        end
    end

    # F=10 dodecahedral I_h (Paper #3 §V.F). 20 stars form an icosahedral
    # orbit; reference from canonical paper #3 spinor.
    if n_stars == 20
        rms = _spectrum_rms(spec, _REF_F10_DODEC)
        if rms < best_rms
            best_rms = rms
            best_sym = :I_h
        end
    end

    best_rms < tol ? best_sym : :unknown
end

function _peak_point_group(psi, F::Int, ndim::Int, n_total, dV)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)

    max_n = 0.0
    max_I = first(CartesianIndices(n_pts))
    @inbounds for I in CartesianIndices(n_pts)
        if n_total[I] > max_n
            max_n = n_total[I]
            max_I = I
        end
    end

    max_n < 1e-30 && return :trivial

    spinor = Vector{ComplexF64}(undef, D)
    norm_sq = 0.0
    @inbounds for c in 1:D
        spinor[c] = psi[max_I, c]
        norm_sq += abs2(psi[max_I, c])
    end
    spinor ./= sqrt(norm_sq)

    detect_point_group(spinor, F)
end

"""
Local icosahedral order parameter at each spatial point.
At each point: spinor → Majorana stars → sphere points → Steinhardt Q₆.
Returns `Array{Float64,N}` (0 everywhere for F < 6).
"""
function icosahedral_order_parameter(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sm::SpinMatrices{D};
    density_cutoff::Float64=1e-10,
    sampling::Float64=1.0,
) where {D, N}
    F = sm.system.F
    n_comp = sm.system.n_components
    n_pts = ntuple(d -> size(psi, d), N)
    result = zeros(Float64, n_pts)
    F >= 6 || return result

    n = _total_density(psi, n_comp, N, n_pts)

    all_indices = vec(collect(CartesianIndices(n_pts)))
    indices = if sampling < 1.0
        rng = Random.MersenneTwister(0)
        n_sample = max(1, round(Int, length(all_indices) * sampling))
        perm = Random.randperm(rng, length(all_indices))
        all_indices[perm[1:n_sample]]
    else
        all_indices
    end

    @inbounds for I in indices
        n[I] > density_cutoff || continue
        spinor = _get_spinor(psi, I, Val(D))
        inv_norm = 1.0 / sqrt(real(dot(spinor, spinor)))
        spinor_normed = SVector{D, ComplexF64}(spinor .* inv_norm)

        stars = majorana_stars(Vector{ComplexF64}(spinor_normed), F)
        points = [_stereo_to_sphere(z) for z in stars]
        result[I] = _steinhardt_q6(points)
    end
    result
end
