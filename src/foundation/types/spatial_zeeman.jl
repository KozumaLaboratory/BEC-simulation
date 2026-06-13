# --- Spatially-varying Zeeman field B(r): data type + builders + kernel ---
#
# The field a `SpatialZeemanTerm` (hamiltonian/terms/spatial_zeeman.jl) couples
# to. Lives in foundation/types/ because `Workspace` carries it as a field.
# An arbitrary field B(r) couples as
#   H(r) = -(bx(r)·F_x + by(r)·F_y + bz(r)·F_z) + q(r)·F_z²
# (same sign convention as the uniform `ZeemanTerm`; `bz ≡ p = -g_F μ_B B_z`
# in internal units). A spatially-curved ∇·B=0 field is what bends a
# Stern-Gerlach cloud into the "smile"; a uniform field is the constant-array
# special case and reproduces `ZeemanTerm` exactly.
#
# `apply_spatial_zeeman_step!` reuses `_apply_euler_spin_rotation` (the audited
# per-voxel Euler rotation, IT overflow shift built in), so the physics is
# automatically identical to the uniform path in the constant limit. CPU-only:
# the per-voxel loop indexes the spin axis with scalar indices.

export SpatialZeemanField, spatial_zeeman_field, quadrupole_field, ioffe_pritchard_field
export apply_spatial_zeeman_step!

"""
Per-voxel magnetic field arrays in internal (p-like) units, sharing the
grid shape. `bz ≡ p = -g_F μ_B B_z` — identical convention to `static_zeeman`.
"""
struct SpatialZeemanField{N} <: AbstractZeemanField
    bx::Array{Float64, N}
    by::Array{Float64, N}
    bz::Array{Float64, N}
    q::Array{Float64, N}

    function SpatialZeemanField(
        bx::Array{Float64, N}, by::Array{Float64, N},
        bz::Array{Float64, N}, q::Array{Float64, N},
    ) where {N}
        size(bx) == size(by) == size(bz) == size(q) ||
            throw(
                ArgumentError(
                    "SpatialZeemanField arrays must share shape; got " *
                    "$(size(bx)), $(size(by)), $(size(bz)), $(size(q))",
                ),
            )
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

# ===========================================================================
# ZeemanField{P} — the unified Zeeman field B(r,t)
# ===========================================================================
#
# `H(r,t) = -(B(r,t)·F) + q(r,t)·F_z²`. One type for every case: uniform /
# spatial × static / time-dependent are all instances. Component order is
# `(bx, by, bz, q)`; `bz ≡ p = -g_F μ_B B_z` (same convention as everywhere).
#
# `P` (the profiles type) encodes uniformity at compile time, so the fast path
# is selected by dispatch with zero runtime cost — analogous to `Array{T,N}`
# being one type parameterised by shape:
#   P = Nothing                         → spatially uniform  → diagonal-exp +
#                                          uniform-rotation fast path (GPU-capable)
#   P = NTuple{4, Array{Float64, N}}    → spatial B(r)       → per-voxel Euler
#                                          (CPU-only)
# Time dependence is separable: each component carries an optional `Waveform`
# envelope, so `B_k(r,t) = profile_k(r) · waveform_k(t)` (or `scalar_k · wf_k(t)`
# when uniform). `field_at` samples the envelopes at `t`.

export ZeemanField,
    zeeman_field, spatiotemporal_zeeman_field, is_uniform,
    field_scalars_at, field_arrays_at

struct ZeemanField{P} <: AbstractZeemanField
    scalars::NTuple{4, Float64}                       # uniform baseline (bx,by,bz,q)
    profiles::P                                        # Nothing or NTuple{4,Array{Float64,N}}
    waveforms::NTuple{4, Union{Nothing, Waveform}}     # per-component time envelopes
end

# Uniform ⇔ no spatial profiles (compile-time).
is_uniform(::ZeemanField{Nothing}) = true
is_uniform(::ZeemanField) = false

# Time-envelope scale factors (bx,by,bz,q) at t; 1.0 where no waveform.
@inline function _zeeman_time_scales(f::ZeemanField, t::Real)
    ntuple(k -> f.waveforms[k] === nothing ? 1.0 : evaluate(f.waveforms[k], Float64(t)), Val(4))
end

"""
    field_scalars_at(f::ZeemanField{Nothing}, t) -> (bx, by, bz, q)

Uniform field sampled at time `t`: `scalars .* waveform(t)`.
"""
@inline function field_scalars_at(f::ZeemanField{Nothing}, t::Real=0.0)
    s = _zeeman_time_scales(f, t)
    (f.scalars[1] * s[1], f.scalars[2] * s[2], f.scalars[3] * s[3], f.scalars[4] * s[4])
end

# Uniform-arm Zeeman accessors — same contract as ZeemanParams /
# TimeDependentZeeman (functions defined in interactions_zeeman.jl, loaded
# first). The integrator/energy paths use these for the uniform fast path.
linear_p(f::ZeemanField{Nothing}, t::Real=0.0) = field_scalars_at(f, t)[3]   # bz ≡ p
quadratic_q(f::ZeemanField{Nothing}, t::Real=0.0) = field_scalars_at(f, t)[4]
function transverse_b(f::ZeemanField{Nothing}, t::Real=0.0)
    s = field_scalars_at(f, t)
    (s[1], s[2])
end
# Spatial arms carry no scalar field — neutral fallbacks. Callers that need the
# spatial field route through `field_arrays_at`, gated by `is_uniform`.
linear_p(::ZeemanField, ::Real=0.0) = 0.0
quadratic_q(::ZeemanField, ::Real=0.0) = 0.0
transverse_b(::ZeemanField, ::Real=0.0) = (0.0, 0.0)

# A uniform field that is also static (no waveforms) — the common case.
const _NO_WF = (nothing, nothing, nothing, nothing)

"""
    zeeman_field(; p=0.0, q=0.0, bx=0.0, by=0.0,
                 p_wf=nothing, q_wf=nothing, bx_wf=nothing, by_wf=nothing) -> ZeemanField{Nothing}

Uniform Zeeman field `B = (bx, by, bz=p)`, `q`, optionally modulated in time by
per-component waveforms. The unified replacement for `ZeemanParams` (static) and
`TimeDependentZeeman` (waveforms).
"""
function zeeman_field(; p::Real=0.0, q::Real=0.0, bx::Real=0.0, by::Real=0.0,
    p_wf=nothing, q_wf=nothing, bx_wf=nothing, by_wf=nothing)
    ZeemanField{Nothing}(
        (Float64(bx), Float64(by), Float64(p), Float64(q)),
        nothing,
        (bx_wf, by_wf, p_wf, q_wf),
    )
end

"""
    zeeman_field(grid; bz=0.0, bx=0.0, by=0.0, q=0.0,
                 bz_wf=nothing, bx_wf=nothing, by_wf=nothing, q_wf=nothing) -> ZeemanField

Spatial Zeeman field `B(r)` (each of `bz/bx/by/q` is a scalar, grid-shaped array,
or `(coords...) -> value`), optionally modulated in time per component
(`B_k(r,t) = profile_k(r)·wf_k(t)`). The unified replacement for
`SpatialZeemanField` (static) and its time-dependent extension `B(r,t)`.
"""
function zeeman_field(grid::Grid{N}; bz=0.0, bx=0.0, by=0.0, q=0.0,
    bz_wf=nothing, bx_wf=nothing, by_wf=nothing, q_wf=nothing) where {N}
    profiles = (
        _materialize_field(bx, grid),
        _materialize_field(by, grid),
        _materialize_field(bz, grid),
        _materialize_field(q, grid),
    )
    ZeemanField{typeof(profiles)}(
        (0.0, 0.0, 0.0, 0.0),
        profiles,
        (bx_wf, by_wf, bz_wf, q_wf),
    )
end

# General `B(r,t)` arm: the spatial SHAPE may vary with t (moving gradient).
# Each component is a function `(coords..., t) -> Float64`, stored as a
# type-erased `Function` field so the Workspace Union stays a closed concrete
# 3-arm Union (no extra type params). The functions are touched only in the
# cold per-step materialisation, which goes through a function barrier
# (`_fill_component!`) so the per-voxel loop is monomorphic.
struct SpatioTemporalProfiles{N}
    bx::Function
    by::Function
    bz::Function
    q::Function
    scratch::NTuple{4, Array{Float64, N}}        # materialisation buffers (reused)
    coords::NTuple{N, Vector{Float64}}           # grid axes (cached)
end

"""
    spatiotemporal_zeeman_field(grid; bz=zero, bx=zero, by=zero, q=zero) -> ZeemanField

General time-dependent spatial Zeeman field `B(r,t)`: each of `bz/bx/by/q` is a
function `(coords..., t) -> value` evaluated on the grid each step. Use when the
spatial shape itself varies with time (moving gradient / rotating quadrupole) —
for a fixed shape with a time envelope use `zeeman_field(grid; …, *_wf=…)`.
CPU-only (per-voxel Euler). `bz ≡ p = -g_F μ_B B_z`.
"""
function spatiotemporal_zeeman_field(grid::Grid{N};
    bz=((_...) -> 0.0), bx=((_...) -> 0.0), by=((_...) -> 0.0),
    q=((_...) -> 0.0)) where {N}
    n_pts = grid.config.n_points
    scratch = ntuple(_ -> zeros(Float64, n_pts), Val(4))
    coords = ntuple(d -> collect(Float64, grid.x[d]), Val(N))
    profiles = SpatioTemporalProfiles{N}(bx, by, bz, q, scratch, coords)
    ZeemanField{SpatioTemporalProfiles{N}}((0.0, 0.0, 0.0, 0.0), profiles, _NO_WF)
end

# Time dependence present? (any envelope, or the general functional arm).
@inline _has_time_dependence(f::ZeemanField) = any(w -> w !== nothing, f.waveforms)
_has_time_dependence(::ZeemanField{<:SpatioTemporalProfiles}) = true

# Materialise the general arm into its scratch via a function barrier so the
# inner loop's `f(...)` call is a direct (monomorphic) call.
@inline function _fill_component!(
    out::Array{Float64, N}, f::F, coords::NTuple{N, Vector{Float64}}, t::Float64
) where {N, F}
    @inbounds for I in CartesianIndices(out)
        out[I] = Float64(f(ntuple(d -> coords[d][I[d]], Val(N))..., t))
    end
    out
end

function _materialise_general!(p::SpatioTemporalProfiles{N}, t::Float64) where {N}
    _fill_component!(p.scratch[1], p.bx, p.coords, t)
    _fill_component!(p.scratch[2], p.by, p.coords, t)
    _fill_component!(p.scratch[3], p.bz, p.coords, t)
    _fill_component!(p.scratch[4], p.q, p.coords, t)
    p.scratch
end

"""
    field_arrays_at(field::ZeemanField, t) -> (bx, by, bz, q)

Per-voxel `(bx, by, bz, q)` arrays for a SPATIAL `ZeemanField` at time `t`,
feeding the shared per-voxel kernel. Separable arm scales cached profiles by the
time envelope (zero-cost when static); general arm materialises the functions.
Only defined for the spatial arms (the uniform arm uses the scalar fast path).
"""
function field_arrays_at(f::ZeemanField{<:NTuple{4, Array{Float64, N}}}, t::Real) where {N}
    s = _zeeman_time_scales(f, t)
    # Static (no envelope): return the profiles directly — zero alloc and
    # byte-identical to the legacy SpatialZeemanField path.
    (s[1] == 1.0 && s[2] == 1.0 && s[3] == 1.0 && s[4] == 1.0) && return f.profiles
    scratch = scratch_get!(:zeeman_field_arrays, (Float64, size(f.profiles[1]))) do
        ntuple(_ -> zeros(Float64, size(f.profiles[1])), Val(4))
    end
    ntuple(Val(4)) do k
        @. scratch[k] = f.profiles[k] * s[k]
        scratch[k]
    end
end

field_arrays_at(f::ZeemanField{<:SpatioTemporalProfiles}, t::Real) =
    _materialise_general!(f.profiles, Float64(t))

# ---------------------------------------------------------------------------
# Per-voxel propagator: exp(-i·dt·H(r)) (RT) / exp(-dt·H(r)) (IT)
# ---------------------------------------------------------------------------

"""
    apply_spatial_zeeman_step!(psi, bx, by, bz, q, sm, dt, imaginary_time=false)

Propagate `psi` one step under the spatially-varying field given as four
per-voxel arrays `(bx, by, bz, q)` (already sampled at the current time):
`qphase(dt/2) · exp(-i·dt·B(r)·F) · qphase(dt/2)` per voxel. The `B(r)·F`
rotation reuses `_apply_euler_spin_rotation` (so it matches the uniform
Zeeman in the constant limit); `qphase` is the per-voxel `q(r)·F_z²` diagonal
factor (skipped when `q ≡ 0`, in which case the step is exact rather than
2nd-order-split). CPU-only.

A `SpatialZeemanField` overload delegates to this array form, and the unified
`ZeemanField` spatial arms feed it via `field_arrays_at`.
"""
function apply_spatial_zeeman_step!(
    psi::AbstractArray{<:Complex},
    bx::AbstractArray{Float64, N}, by::AbstractArray{Float64, N},
    bz::AbstractArray{Float64, N}, q::AbstractArray{Float64, N},
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

# Legacy SpatialZeemanField overload — delegates to the array form.
@inline function apply_spatial_zeeman_step!(
    psi::AbstractArray{<:Complex}, field::SpatialZeemanField,
    sm::SpinMatrices, dt::Real, imaginary_time::Bool=false,
)
    apply_spatial_zeeman_step!(
        psi, field.bx, field.by, field.bz, field.q, sm, dt, imaginary_time)
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
