# --- SpatialZeemanTerm — arbitrary B(r) Zeeman coupling as a HamTerm ---
#
# The m-dependent counterpart of `MagneticGradientTerm` (which is a
# spin-INDEPENDENT tilt). Couples a spatially-varying field B(r,t) as
#   H(r,t) = -(bx(r,t)·F_x + by(r,t)·F_y + bz(r,t)·F_z) + q(r,t)·F_z²
# reading the non-uniform arm of the unified `ws.zeeman` (a `ZeemanField` whose
# per-voxel arrays come from `field_arrays_at(field, t)`). Data type, builders,
# and the per-voxel propagator kernel live in
# `foundation/types/spatial_zeeman.jl`; this file is the HamTerm trinity.
#
# CPU-only propagator (the kernel indexes the spin axis with scalar indices);
# `make_workspace` rejects a GPU backend or a spin-rotating frame with a
# spatial field. The energy / operator faces are host-side, so the GPU energy
# path (which copies ψ to host) still gets a `spatial_zeeman` slot.

"""
Arbitrary spatially-varying Zeeman field B(r,t) as one HamTerm. Reads the
non-uniform arm of `ws.zeeman` (a spatial `ZeemanField`); this struct is a
marker (like `MagneticGradientTerm`).
"""
struct SpatialZeemanTerm <: HamTerm end

# The spatial Zeeman field is the non-uniform arm of the unified ws.zeeman
# (nothing when the field is uniform — slot 3 ZeemanTerm carries it then).
@inline _spatial_zeeman(ws) = is_uniform(ws.zeeman) ? nothing : ws.zeeman

# ---------------------------------------------------------------------------
# Operator face (gradient): out .+= H(r)·ψ
# ---------------------------------------------------------------------------

function apply_operator!(out::AbstractArray, ::SpatialZeemanTerm, ws, psi::AbstractArray)
    field = _spatial_zeeman(ws)
    field === nothing && return out
    bx, by, bz, q = materialise_field_arrays(field, ws.state.t)
    _spatial_zeeman_apply!(out, psi, bx, by, bz, q, ws.spin_matrices)
    return out
end

# `D` from `SpinMatrices{D}`, `N` from the per-voxel array rank → `Val(D)`/`Val(N)`
# are type-stable. Reading `D = sm.system.n_components` as a runtime Int and then
# `Val(D)` would box the entire per-voxel loop (~28 MB/call at D=13).
function _spatial_zeeman_apply!(
    out::AbstractArray, psi::AbstractArray,
    bx, by, bz::AbstractArray{Float64, N}, q, sm::SpinMatrices{D}) where {N, D}
    F = sm.system.F
    n_pts = ntuple(d -> size(psi, d), Val(N))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp = ntuple(c -> c == 1 ? 0.0 :
                     sqrt(Float64(F * (F + 1)) - m_vals[c] * (m_vals[c] + 1.0)), Val(D))
    @inbounds for I in CartesianIndices(n_pts)
        # diagonal: (-bz·m + q·m²)
        bzI, qI = bz[I], q[I]
        for c in 1:D
            out[I, c] += (-bzI * m_vals[c] + qI * m_vals[c]^2) * psi[I, c]
        end
        # transverse: -(bx·F_x + by·F_y) via ladder (F± couple c-1 ↔ c)
        bxI, byI = bx[I], by[I]
        (bxI == 0.0 && byI == 0.0) && continue
        cl = -(bxI + im * byI) / 2   # acts at c reading psi at c-1
        cu = -(bxI - im * byI) / 2   # acts at c-1 reading psi at c
        for c in 2:D
            out[I, c] += cl * fp[c] * psi[I, c - 1]
            out[I, c - 1] += cu * fp[c] * psi[I, c]
        end
    end
    return out
end

# ---------------------------------------------------------------------------
# Energy face: ⟨ψ|H(r)|ψ⟩
# ---------------------------------------------------------------------------

function energy_contribution(::SpatialZeemanTerm, psi::AbstractArray{<:Complex}, ws)
    field = _spatial_zeeman(ws)
    field === nothing && return 0.0
    bx, by, bz, q = materialise_field_arrays(field, ws.state.t)
    return _spatial_zeeman_energy(psi, bx, by, bz, q, ws.spin_matrices, cell_volume(ws.grid))
end

"""
    _spatial_zeeman_energy(psi, bx, by, bz, q, sm, dV)

`E = ∫ [Σ_c (-bz(r)·m + q(r)·m²)|ψ_c|² - bx(r)·f_x(r) - by(r)·f_y(r)] dV`,
the per-voxel expectation of the spatially-varying Zeeman operator from four
per-voxel arrays (already sampled at the current time). Host-side; also used by
the GPU energy path (which copies ψ to host). `D` is taken from `SpinMatrices{D}`
and `N` from the per-voxel array rank so `Val(D)`/`Val(N)` are type-stable. A
`SpatialZeemanField` overload delegates here.
"""
function _spatial_zeeman_energy(
    psi::AbstractArray, bx, by, bz::AbstractArray{Float64, N}, q,
    sm::SpinMatrices{D}, dV) where {N, D}
    F = sm.system.F
    n_pts = ntuple(d -> size(psi, d), Val(N))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp = ntuple(c -> c == 1 ? 0.0 :
                     sqrt(Float64(F * (F + 1)) - m_vals[c] * (m_vals[c] + 1.0)), Val(D))
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        bzI, qI = bz[I], q[I]
        for c in 1:D
            E += (-bzI * m_vals[c] + qI * m_vals[c]^2) * abs2(psi[I, c])
        end
        bxI, byI = bx[I], by[I]
        (bxI == 0.0 && byI == 0.0) && continue
        # local f_x = Σ_c fp[c]·Re(conj ψ_{c-1} ψ_c), f_y = Σ_c fp[c]·Im(...)
        fxI = 0.0
        fyI = 0.0
        for c in 2:D
            pr = conj(psi[I, c - 1]) * psi[I, c]
            fxI += fp[c] * real(pr)
            fyI += fp[c] * imag(pr)
        end
        E += -bxI * fxI - byI * fyI
    end
    return E * dV
end

# Legacy SpatialZeemanField overload — delegates to the array form.
_spatial_zeeman_energy(psi, field::SpatialZeemanField, sm, dV) =
    _spatial_zeeman_energy(psi, field.bx, field.by, field.bz, field.q, sm, dV)

# ---------------------------------------------------------------------------
# Propagator face: exp(-i·dt·H(r)) (RT) / exp(-dt·H(r)) (IT)
# ---------------------------------------------------------------------------

function apply_step!(::SpatialZeemanTerm, psi::AbstractArray{<:Complex},
    dt::Real, imaginary_time::Bool, ws)
    field = _spatial_zeeman(ws)
    field === nothing && return nothing
    bx, by, bz, q = materialise_field_arrays(field, ws.state.t)
    apply_spatial_zeeman_step!(psi, bx, by, bz, q, ws.spin_matrices, dt, imaginary_time)
    return nothing
end

"""
Directional sign oracle for `SpatialZeemanTerm`. With a uniform `+bz` field
(constant array), ITP from `:m_plus_F` preserves ⟨F_z⟩ ≈ +F — identical to
the uniform ZeemanTerm oracle, in the constant-field limit.
"""
function sign_oracle(::Type{SpatialZeemanTerm})
    return (
        name="SpatialZeemanTerm: uniform +bz ⇒ ⟨F_z⟩ > 0",
        predicate=function (psi, ws)
            _spatial_zeeman(ws) === nothing && return true
            sm = ws.spin_matrices
            N = ndims(psi) - 1
            _, _, fz = spin_density_vector(psi, sm, N)
            return sum(fz) * cell_volume(ws.grid) > 0.5
        end,
    )
end
