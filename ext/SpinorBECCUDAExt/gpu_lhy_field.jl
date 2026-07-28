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
