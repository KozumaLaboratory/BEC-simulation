# --- Spatially-varying Zeeman field B(r) ---
#
# Phase A (standalone): the data type + field builders + the per-voxel
# propagator kernel for an arbitrary magnetic field B(r) coupling as
#   H(r) = -(bx(r)·F_x + by(r)·F_y + bz(r)·F_z) + q(r)·F_z²
# (same sign convention as the uniform `ZeemanTerm`; `bz ≡ p = -g_F μ_B B_z`
# in internal units). A spatially-curved field — e.g. a ∇·B=0 quadrupole —
# is what bends a Stern-Gerlach cloud into the "smile"; a uniform field is
# the constant-array special case and reproduces `ZeemanTerm` exactly.
#
# The kernel reuses `_apply_euler_spin_rotation` (the audited per-voxel
# Euler-angle rotation, IT overflow shift built in), so the physics is
# automatically identical to the uniform path in the constant limit.
#
# CPU-only: the per-voxel loop indexes the spin axis with scalar indices.
# Phase B will wrap this kernel as a `SpatialZeemanTerm <: HamTerm`.

export SpatialZeemanField, spatial_zeeman_field, quadrupole_field, ioffe_pritchard_field
export apply_spatial_zeeman_step!

"""
Per-voxel magnetic field arrays in internal (p-like) units, sharing the
grid shape. `bz ≡ p = -g_F μ_B B_z` — identical convention to `static_zeeman`.
"""
struct SpatialZeemanField{N}
    bx::Array{Float64, N}
    by::Array{Float64, N}
    bz::Array{Float64, N}
    q::Array{Float64, N}

    function SpatialZeemanField(
        bx::Array{Float64, N}, by::Array{Float64, N},
        bz::Array{Float64, N}, q::Array{Float64, N},
    ) where {N}
        size(bx) == size(by) == size(bz) == size(q) ||
            throw(ArgumentError("SpatialZeemanField arrays must share shape; got " *
                                "$(size(bx)), $(size(by)), $(size(bz)), $(size(q))"))
        new{N}(bx, by, bz, q)
    end
end

# Materialize a field spec into an Array over the grid. A spec is a scalar
# (constant), an array (checked against the grid), or a function of the
# spatial coordinates `(x, y, …) -> value`.
_materialize_field(v::Number, grid::Grid{N}) where {N} = fill(Float64(v), grid.config.n_points)

function _materialize_field(v::AbstractArray, grid::Grid{N}) where {N}
    size(v) == grid.config.n_points ||
        throw(ArgumentError("field array shape $(size(v)) ≠ grid $(grid.config.n_points)"))
    convert(Array{Float64, N}, v)
end

function _materialize_field(f, grid::Grid{N}) where {N}
    n_pts = grid.config.n_points
    out = Array{Float64, N}(undef, n_pts)
    @inbounds for I in CartesianIndices(n_pts)
        coords = ntuple(d -> grid.x[d][I[d]], Val(N))
        out[I] = Float64(f(coords...))
    end
    out
end

"""
    spatial_zeeman_field(grid; bz=0.0, bx=0.0, by=0.0, q=0.0) -> SpatialZeemanField

Build a `SpatialZeemanField` from per-component specs. Each of `bz/bx/by/q`
is a scalar (constant), an array matching the grid, or a function of the
spatial coordinates `(x, y, …) -> value`. Values are in internal (p-like)
units (`bz ≡ p = -g_F μ_B B_z`), the same convention as `static_zeeman`.
"""
function spatial_zeeman_field(grid::Grid{N}; bz=0.0, bx=0.0, by=0.0, q=0.0) where {N}
    SpatialZeemanField(
        _materialize_field(bx, grid),
        _materialize_field(by, grid),
        _materialize_field(bz, grid),
        _materialize_field(q, grid),
    )
end

"""
    quadrupole_field(grid; gradient, bias=0.0, center=origin) -> SpatialZeemanField

Axially-symmetric magnetic quadrupole `B(r) = gradient·(x, y, -2z)` about
`center`, plus an optional `bias` added to `bz` (∇·B = 0, ∇×B = 0). On an
N<3 grid the field is the z=0 (or y=0) slice of the 3-D quadrupole — |B|
still grows radially, which is what bends the Stern-Gerlach cloud. `gradient`
and `bias` are in internal (p-like) units.
"""
function quadrupole_field(grid::Grid{N}; gradient::Real, bias::Real=0.0,
    center::NTuple{N, <:Real}=ntuple(_ -> 0.0, Val(N))) where {N}
    g = Float64(gradient)
    bx = _materialize_field((c...) -> g * (c[1] - center[1]), grid)
    by = _materialize_field(N >= 2 ? (c...) -> g * (c[2] - center[2]) : 0.0, grid)
    bz = _materialize_field(N >= 3 ? (c...) -> bias - 2g * (c[3] - center[3]) : Float64(bias), grid)
    SpatialZeemanField(bx, by, bz, fill(0.0, grid.config.n_points))
end

"""
    ioffe_pritchard_field(grid; gradient, curvature=0.0, bias=0.0, center=origin)
        -> SpatialZeemanField

Ioffe-Pritchard field (∇·B = 0):

    Bx = gradient·x - (curvature/2)·x·z
    By = -gradient·y - (curvature/2)·y·z
    Bz = bias + (curvature/2)·(z² - (x²+y²)/2)

On an N<3 grid the `z` coordinate is taken as 0. All parameters in internal
(p-like) units.
"""
function ioffe_pritchard_field(grid::Grid{N}; gradient::Real, curvature::Real=0.0,
    bias::Real=0.0, center::NTuple{N, <:Real}=ntuple(_ -> 0.0, Val(N))) where {N}
    g = Float64(gradient)
    cv = Float64(curvature)
    b0 = Float64(bias)
    _x(c) = c[1] - center[1]
    _y(c) = N >= 2 ? c[2] - center[2] : 0.0
    _z(c) = N >= 3 ? c[3] - center[3] : 0.0
    bx = _materialize_field((c...) -> g * _x(c) - 0.5cv * _x(c) * _z(c), grid)
    by = _materialize_field((c...) -> -g * _y(c) - 0.5cv * _y(c) * _z(c), grid)
    bz = _materialize_field(
        (c...) -> b0 + 0.5cv * (_z(c)^2 - 0.5 * (_x(c)^2 + _y(c)^2)), grid)
    SpatialZeemanField(bx, by, bz, fill(0.0, grid.config.n_points))
end

# ---------------------------------------------------------------------------
# Per-voxel propagator: exp(-i·dt·H(r)) (RT) / exp(-dt·H(r)) (IT)
# ---------------------------------------------------------------------------

"""
    apply_spatial_zeeman_step!(psi, field, sm, dt, imaginary_time=false)

Propagate `psi` one step under the spatially-varying field:
`qphase(dt/2) · exp(-i·dt·B(r)·F) · qphase(dt/2)` per voxel. The `B(r)·F`
rotation reuses `_apply_euler_spin_rotation` (so it matches the uniform
Zeeman in the constant limit); `qphase` is the per-voxel `q(r)·F_z²` diagonal
factor (skipped when `q ≡ 0`, in which case the step is exact rather than
2nd-order-split). CPU-only.
"""
function apply_spatial_zeeman_step!(
    psi::AbstractArray{<:Complex}, field::SpatialZeemanField{N},
    sm::SpinMatrices{D}, dt::Real, imaginary_time::Bool=false,
) where {N, D}
    psi isa Array || error(
        "apply_spatial_zeeman_step! is CPU-only (per-voxel scalar indexing); " *
        "got psi::$(typeof(psi))")
    F = sm.system.F
    m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))
    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals
    n_pts = ntuple(d -> size(psi, d), Val(N))
    bx, by, bz, q = field.bx, field.by, field.bz, field.q
    dtf = Float64(dt)
    has_q = any(!=(0.0), q)

    has_q && _spatial_q_halfstep!(psi, q, m_vals, dtf / 2, imaginary_time, n_pts, Val(D))

    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            spinor = _get_spinor(psi, I, Val(D))
            rotated = _apply_euler_spin_rotation(
                spinor, -bx[I], -by[I], -bz[I], dtf, F, m_vals,
                V_Fy, Vt_Fy, λ_Fy, sm, imaginary_time)
            _set_spinor!(psi, I, rotated, Val(D))
        end
    end

    has_q && _spatial_q_halfstep!(psi, q, m_vals, dtf / 2, imaginary_time, n_pts, Val(D))
    nothing
end

# Per-voxel diagonal q(r)·F_z² factor. IT subtracts the per-voxel min over m
# to prevent overflow (removed by the subsequent normalization), mirroring
# the uniform ZeemanTerm "ITP Zeeman shift".
function _spatial_q_halfstep!(
    psi, q, m_vals::SVector{D, Float64}, dtf::Float64,
    imaginary_time::Bool, n_pts, ::Val{D},
) where {D}
    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            qI = q[I]
            qI == 0.0 && continue
            if imaginary_time
                shift = qI * m_vals[1]^2
                for c in 2:D
                    e = qI * m_vals[c]^2
                    e < shift && (shift = e)
                end
                for c in 1:D
                    psi[I, c] *= exp(-(qI * m_vals[c]^2 - shift) * dtf)
                end
            else
                for c in 1:D
                    psi[I, c] *= cis(-qI * m_vals[c]^2 * dtf)
                end
            end
        end
    end
    nothing
end
