# --- Bogoliubov instability scan: direction-grid sweep + supersolid prediction ---

function _default_directions()
    raw = [
        (1.0, 0.0, 0.0),
        (0.0, 1.0, 0.0),
        (0.0, 0.0, 1.0),
        (1.0, 1.0, 0.0),
        (1.0, 0.0, 1.0),
        (0.0, 1.0, 1.0),
        (1.0, -1.0, 0.0),
        (1.0, 0.0, -1.0),
        (0.0, 1.0, -1.0),
        (1.0, 1.0, 1.0),
        (1.0, 1.0, -1.0),
        (1.0, -1.0, 1.0),
        (-1.0, 1.0, 1.0),
    ]
    map(raw) do d
        n = sqrt(d[1]^2 + d[2]^2 + d[3]^2)
        (d[1] / n, d[2] / n, d[3] / n)
    end
end

"""
    fibonacci_sphere_directions(n::Int) → Vector{NTuple{3,Float64}}

Generate `n` approximately uniform directions on the upper hemisphere (z ≥ 0)
using the Fibonacci spiral method. Exploits Q(k̂) = Q(-k̂) symmetry to scan
only the upper hemisphere.
"""
function fibonacci_sphere_directions(n::Int)
    n >= 1 || throw(ArgumentError("n must be >= 1, got $n"))
    golden_ratio = (1.0 + sqrt(5.0)) / 2.0
    dirs = NTuple{3, Float64}[]
    for i in 0:(2n - 1)
        theta = acos(1.0 - (2.0 * i + 1.0) / (2n))
        phi = 2.0 * Float64(π) * i / golden_ratio
        x = sin(theta) * cos(phi)
        y = sin(theta) * sin(phi)
        z = cos(theta)
        z >= 0 && push!(dirs, (x, y, z))
    end
    dirs
end

"""
    bogoliubov_instability_scan(; spinor, n0, F, interactions, zeeman, c_dd,
                                  k_max, n_k, directions, n_directions)

Scan Bogoliubov instabilities across multiple k-directions.

Returns `InstabilityMap` with growth rates for each (k, direction) pair,
identifying the most unstable mode and predicting the density-wave wavelength.

`directions` can be:
- `:auto` — 13 unique axis/edge/body-diagonal directions
- `:dense` — `n_directions` Fibonacci-spiral directions on upper hemisphere
- a `Vector{NTuple{3,Float64}}` of custom directions
"""
function bogoliubov_instability_scan(;
    spinor::Vector{ComplexF64},
    n0::Float64,
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    k_max::Float64=10.0,
    n_k::Int=200,
    directions::Union{Symbol, Vector{NTuple{3, Float64}}}=:auto,
    n_directions::Int=100,
)
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    dirs = if directions === :auto
        _default_directions()
    elseif directions === :dense
        fibonacci_sphere_directions(n_directions)
    elseif directions === :planar
        _planar_directions(n_directions)
    else
        directions
    end
    n_dir = length(dirs)

    h_contact, M_contact, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    has_ddi = abs(c_dd) > 1e-30
    sm = has_ddi ? spin_matrices(F) : nothing

    growth_rates = zeros(Float64, n_k, n_dir)
    k_values = collect(range(0, k_max; length=n_k))

    # Per-direction BdG diagonalisation is embarrassingly parallel: each
    # direction builds its own h_ddi/M_ddi (when DDI is on) and runs an
    # independent _bdg_k_scan that allocates its own (omega, k_values)
    # buffers. Across n_dir × n_k = O(20000) eigvals(26×26) calls for
    # F=6 dense scans this is the bottleneck (round-3 review item 2.4).
    # Use `:static` so threadid() ∈ 1:nthreads() (default :dynamic can
    # produce threadid() up to maxthreadid() in 1.10+, breaking per-thread
    # buffer arrays sized by nthreads()).
    n_thr = Threads.maxthreadid()
    per_thr_max = zeros(Float64, n_thr)
    per_thr_k = zeros(Float64, n_thr)
    per_thr_dir = [dirs[1] for _ in 1:n_thr]

    Threads.@threads :static for id in 1:n_dir
        tid = Threads.threadid()
        dir = dirs[id]
        if has_ddi
            k_hat = collect(dir)
            k_norm = norm(k_hat)
            k_norm > 0 && (k_hat ./= k_norm)
            Q_ab = _q_tensor_direction(k_hat)
            h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
            h_mf = h_contact .+ h_ddi
            M_anom = M_contact .+ M_ddi
        else
            h_mf = h_contact
            M_anom = M_contact
        end

        _, omega, _ = _bdg_k_scan(h_mf, M_anom, zee, n0, D, spinor, k_max, n_k)

        for ik in 1:n_k
            max_g = 0.0
            for ie in 1:2D
                g = imag(omega[ie, ik])
                g > max_g && (max_g = g)
            end
            growth_rates[ik, id] = max_g
            if max_g > per_thr_max[tid]
                per_thr_max[tid] = max_g
                per_thr_k[tid] = k_values[ik]
                per_thr_dir[tid] = dir
            end
        end
    end

    # Reduce per-thread maxima into the global best.
    global_max = 0.0
    best_k = 0.0
    best_dir = dirs[1]
    @inbounds for t in 1:n_thr
        if per_thr_max[t] > global_max
            global_max = per_thr_max[t]
            best_k = per_thr_k[t]
            best_dir = per_thr_dir[t]
        end
    end

    unstable = global_max > 1e-10

    k_lo = Inf
    k_hi = -Inf
    if unstable
        for id in 1:n_dir, ik in 1:n_k
            if growth_rates[ik, id] > 1e-10
                k = k_values[ik]
                k < k_lo && (k_lo = k)
                k > k_hi && (k_hi = k)
            end
        end
    else
        k_lo = 0.0
        k_hi = 0.0
    end

    wavelength = unstable && best_k > 0 ? 2π / best_k : Inf

    angular_map = [maximum(view(growth_rates, :, id)) for id in 1:n_dir]

    InstabilityMap(
        k_values,
        dirs,
        growth_rates,
        global_max,
        unstable,
        best_k,
        best_dir,
        (k_lo, k_hi),
        wavelength,
        angular_map,
    )
end

"""
    suggest_grid_params(imap; ndim=2, margin=2.0)

Suggest grid parameters that resolve the instability found in `imap`.

Returns `(; n_points::NTuple{N,Int}, box_size::NTuple{N,Float64})` or
`nothing` if the system is stable.
"""
function suggest_grid_params(imap::InstabilityMap; ndim::Int=2, margin::Float64=2.0)
    imap.unstable || return nothing

    k_lo, k_hi = imap.k_unstable_range
    k_min = max(k_lo, 1e-10)

    box_L = margin * 2π / k_min
    k_nyquist_needed = margin * k_hi
    n_raw = ceil(Int, 2 * box_L * k_nyquist_needed / (2π))
    n_pts = n_raw + (n_raw % 2)

    box_size = ntuple(_ -> box_L, ndim)
    n_points = ntuple(_ -> n_pts, ndim)
    (; n_points, box_size)
end

function _planar_directions(n::Int)
    n >= 1 || throw(ArgumentError("n must be >= 1"))
    dirs = NTuple{3, Float64}[]
    for i in 0:(n - 1)
        theta = Float64(π) * i / n
        push!(dirs, (cos(theta), sin(theta), 0.0))
    end
    dirs
end

"""
    predict_supersolid_params(imap::InstabilityMap) → SupersolidPrediction

Predict supersolid pattern parameters from an instability map.
"""
function predict_supersolid_params(imap::InstabilityMap)
    !imap.unstable && return SupersolidPrediction(Inf, :none, 0.0, 0.0)

    wavelength = imap.predicted_wavelength
    k_roton = imap.most_unstable_k

    amap = imap.angular_growth_map
    max_g = maximum(amap)
    pos_vals = filter(x -> x > 1e-10, amap)
    min_g = isempty(pos_vals) ? max_g : minimum(pos_vals)
    anisotropy = max_g > 1e-10 ? max_g / max(min_g, 1e-30) : 0.0

    pattern = if anisotropy > 3.0
        :stripe
    elseif anisotropy > 1.5
        :triangular
    else
        :isotropic
    end

    SupersolidPrediction(wavelength, pattern, k_roton, anisotropy)
end
