"""
Majorana polynomial coefficients for a spin-F spinor.
P(z) = Σ_{k=0}^{2F} (-1)^k √C(2F,k) ψ_{F-k} z^k
where ψ_{F-k} is the component with m = F-k (index k+1).
"""
function _majorana_polynomial(spinor::AbstractVector{ComplexF64}, F::Int)
    n = 2F + 1
    coeffs = Vector{ComplexF64}(undef, n)
    for k in 0:2F
        coeffs[k+1] = (-1)^k * sqrt(binomial(2F, k)) * spinor[k+1]
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
    while deg >= 1 && abs(coeffs[deg+1]) < 1e-14
        deg -= 1
    end
    deg == 0 && return fill(complex(Inf), n)

    if deg == 1
        roots = [-coeffs[1] / coeffs[2]]
    else
        c = coeffs[1:deg+1]
        companion = zeros(ComplexF64, deg, deg)
        for i in 1:deg-1
            companion[i+1, i] = 1.0
        end
        for i in 1:deg
            companion[i, deg] = -c[i] / c[deg+1]
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
z = Inf maps to south pole (0, 0, -1).
"""
function _stereo_to_sphere(z::ComplexF64)
    if !isfinite(z)
        return (0.0, 0.0, -1.0)
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
function _steinhardt_q6(points::Vector{NTuple{3,Float64}})
    N = length(points)
    N == 0 && return 0.0

    s = 0.0
    @inbounds for i in 1:N
        for j in 1:N
            costh = points[i][1] * points[j][1] +
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

function _pairwise_distance_spectrum(points::Vector{NTuple{3,Float64}})
    n = length(points)
    dists = Float64[]
    for i in 1:n
        for j in (i+1):n
            costh = clamp(
                points[i][1]*points[j][1] + points[i][2]*points[j][2] + points[i][3]*points[j][3],
                -1.0, 1.0)
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
    raw = NTuple{3,Float64}[]
    for s1 in (-1.0, 1.0), s2 in (-1.0, 1.0)
        push!(raw, (0.0, s1, s2 * phi))
        push!(raw, (s1, s2 * phi, 0.0))
        push!(raw, (s2 * phi, 0.0, s1))
    end
    map(p -> let r = sqrt(p[1]^2 + p[2]^2 + p[3]^2); (p[1]/r, p[2]/r, p[3]/r) end, raw)
end

function _make_octahedron_vertices()
    verts = NTuple{3,Float64}[]
    for d in 1:3, s in (-1.0, 1.0)
        v = ntuple(i -> i == d ? s : 0.0, 3)
        push!(verts, v)
    end
    verts
end

function _make_cube_vertices()
    verts = NTuple{3,Float64}[]
    inv_sqrt3 = 1.0 / sqrt(3.0)
    for sx in (-1.0, 1.0), sy in (-1.0, 1.0), sz in (-1.0, 1.0)
        push!(verts, (sx * inv_sqrt3, sy * inv_sqrt3, sz * inv_sqrt3))
    end
    verts
end

function _make_tetrahedron_vertices()
    [(1.0, 1.0, 1.0) ./ sqrt(3.0),
     (1.0, -1.0, -1.0) ./ sqrt(3.0),
     (-1.0, 1.0, -1.0) ./ sqrt(3.0),
     (-1.0, -1.0, 1.0) ./ sqrt(3.0)]
end

const _REF_ICOSAHEDRON = _pairwise_distance_spectrum(_make_icosahedron_vertices())
const _REF_OCTAHEDRON = _pairwise_distance_spectrum(_make_octahedron_vertices())
const _REF_CUBE = _pairwise_distance_spectrum(_make_cube_vertices())
const _REF_TETRAHEDRON = _pairwise_distance_spectrum(_make_tetrahedron_vertices())

"""
    detect_point_group(spinor, F; tol=0.15) → Symbol

Detect the point group symmetry of a spinor from its Majorana star geometry.

Computes 2F Majorana stars, projects to the unit sphere, and compares the sorted
pairwise angular distance spectrum against reference polyhedra.

Returns `:I_h` (icosahedral), `:O_h` (octahedral/cubic), `:T_d` (tetrahedral),
`:D_nh` (dihedral), `:trivial` (all stars clustered), or `:unknown`.
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
    for i in eachindex(finite_pts), j in (i+1):length(finite_pts)
        costh = clamp(
            finite_pts[i][1]*finite_pts[j][1] + finite_pts[i][2]*finite_pts[j][2] + finite_pts[i][3]*finite_pts[j][3],
            -1.0, 1.0)
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
function icosahedral_order_parameter(psi::AbstractArray{ComplexF64}, grid::Grid{N},
                                     sm::SpinMatrices{D};
                                     density_cutoff::Float64=1e-10,
                                     sampling::Float64=1.0) where {D,N}
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
        spinor_normed = SVector{D,ComplexF64}(spinor .* inv_norm)

        stars = majorana_stars(Vector{ComplexF64}(spinor_normed), F)
        points = [_stereo_to_sphere(z) for z in stars]
        result[I] = _steinhardt_q6(points)
    end
    result
end
