# V_LHY(r) for tabulated LHY on the device.
#
# The fused GPU diagonal kernel only accepts the scalar LHY forms, so every
# `TabulatedLHY` falls back to the generic broadcast propagator. That path
# materialises V_LHY as an array via `_lhy_potential_field`, whose CPU method
# broadcasts `_lhy_V` — and `_lhy_V(::TabulatedLHY)` closes over host `Vector`s
# it cannot read from a device kernel.
#
# Before the CPU-side fix this never surfaced, because the generic path had
# collapsed every table to `c_lhy = 0.0` and silently dropped the LHY
# altogether. So a GPU run with `polar_contact` / `fm_contact` / `icosahedral`
# / `polar_dipolar` / `fm_dipolar` / `polar_two_channel` / `full_bdg` was
# running with no LHY at all and reporting nothing.
#
# The density grid is `range(0, n_max; length=n_points)` — uniform — so the
# lookup is index arithmetic, no search, and the whole thing is one broadcast
# over two cached device vectors.

@inline function _lhy_interp_uniform(n::T, x0::T, dx::T, ys, m::Int) where {T}
    n <= x0 && return @inbounds ys[1]
    q = (n - x0) / dx
    i = unsafe_trunc(Int32, q) + Int32(1)
    i >= m && return @inbounds ys[m]
    i < 1 && return @inbounds ys[1]
    t = q - (i - 1)
    @inbounds ys[i] + t * (ys[i + 1] - ys[i])
end

const _LHY_TABLE_CACHE = Dict{Tuple{UInt64, DataType}, Any}()

function _device_lhy_table(l::SpinorBEC.TabulatedLHY, ::Type{RT},
    proto::CUDA.CuArray) where {RT}
    key = (objectid(l), RT)
    get!(_LHY_TABLE_CACHE, key) do
        CUDA.CuArray(RT.(l.potential_values))
    end::CUDA.CuArray{RT, 1}
end

function SpinorBEC._lhy_potential_field(l::SpinorBEC.TabulatedLHY,
    density_buf::CUDA.CuArray{RT}, ::Type{RT2}) where {RT, RT2}
    xs = l.densities
    m = length(xs)
    m >= 2 || return fill!(similar(density_buf), zero(RT))
    dx = RT(xs[2] - xs[1])
    x0 = RT(xs[1])
    # Uniformity is what makes the device lookup O(1); the tabulators all build
    # `range(0, n_max; length=n_points)`, and a non-uniform table would be
    # silently mis-indexed, so it is checked rather than assumed.
    all(k -> abs((xs[k + 1] - xs[k]) - (xs[2] - xs[1])) <=
             1e-9 * max(abs(xs[2] - xs[1]), 1.0), 1:(m - 1)) ||
        throw(ArgumentError(
            "GPU LHY lookup needs a uniform density grid; got a non-uniform one " *
            "with $m nodes. Build the table with `range(0, n_max; length=n)`."))
    ys = _device_lhy_table(l, RT, density_buf)
    out = similar(density_buf)
    out .= _lhy_interp_uniform.(density_buf, x0, dx, Ref(ys), m)
    out
end

# --- SpatialLHY -------------------------------------------------------------
#
# `SpatialLHY` is NOT a `TabulatedLHY`: it tabulates `e₁` against the local
# POLARISATION, so it arrives at the four-argument `(density, polarisation)`
# form of `_lhy_potential_field` and the method above never sees it. Without a
# device method here the generic CPU broadcast is what runs, closing over host
# `Vector`s from a device kernel — the same failure mode this file exists to
# fix, one level up the type tree.
#
# The nodes are the centres of the OCCUPIED bins (`_bin_local_spinors` drops
# empty ones), so unlike every density table they are NOT uniformly spaced and
# the O(1) index arithmetic above does not apply. The scan below reproduces
# `_interpolate_1d`'s `searchsortedlast` exactly instead; with at most `n_bins`
# nodes (12 by default) a linear scan is cheaper than a search anyway, and
# being exact is what keeps GPU and CPU bit-identical.
@inline function _lhy_interp_scan(x::Float64, xs, ys, m::Int)
    @inbounds x <= xs[1] && return @inbounds ys[1]
    @inbounds x >= xs[m] && return @inbounds ys[m]
    i = 1
    @inbounds for k in 1:m
        xs[k] <= x && (i = k)
    end
    @inbounds ys[i] + ((x - xs[i]) / (xs[i + 1] - xs[i])) * (ys[i + 1] - ys[i])
end

# Same expression as `_lhy_V(n, p, ::SpatialLHY)`, in the same order, so the
# two paths agree to the last bit rather than to a tolerance.
@inline function _spatial_lhy_V(n::Float64, p::Float64, xs, ys, m::Int)
    n < 1e-30 && return 0.0
    e1 = _lhy_interp_scan(clamp(p, 0.0, 1.0), xs, ys, m)
    2.5 * e1 * n * sqrt(n)
end

const _SPATIAL_LHY_CACHE = Dict{UInt64, Any}()

function _device_spatial_table(l::SpinorBEC.SpatialLHY)
    get!(_SPATIAL_LHY_CACHE, objectid(l)) do
        (CUDA.CuArray(l.polarisations), CUDA.CuArray(l.e1_values))
    end::Tuple{CUDA.CuArray{Float64, 1}, CUDA.CuArray{Float64, 1}}
end

function SpinorBEC._lhy_potential_field(l::SpinorBEC.SpatialLHY,
    density_buf::CUDA.CuArray{RT}, p_buf::CUDA.CuArray,
    ::Type{RT2}) where {RT, RT2}
    xs, ys = _device_spatial_table(l)
    m = length(l.polarisations)
    out = similar(density_buf)
    # Float64 throughout, like the CPU method — the conversions fuse into this
    # one broadcast, so an F32 grid still costs no extra array.
    out .= RT2.(_spatial_lhy_V.(Float64.(density_buf), Float64.(p_buf),
        Ref(xs), Ref(ys), m))
    out
end
