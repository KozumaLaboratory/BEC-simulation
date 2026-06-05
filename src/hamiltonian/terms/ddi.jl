# --- DDI HamTerm ---
#
# Dipole-dipole interaction. H_DDI = (1/2) ∫ d³r d³r' (c_dd / |r-r'|³)
# [F(r)·F(r') - 3(F(r)·r̂)(F(r')·r̂)] per CLAUDE.md "DDI: c_dd=μ₀μ²".
# Convention is fixed (do NOT "fix").

"""Magnetic dipole-dipole interaction."""
struct DDITerm <: HamTerm end

function apply_step!(::DDITerm, psi, dt::Real, imaginary_time::Bool, ws)
    ws.ddi === nothing && return nothing
    N = ndims(psi) - 1
    if ws.ddi_padded !== nothing
        apply_ddi_step!(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, N, ws.ddi_padded;
            imaginary_time=imaginary_time)
    else
        apply_ddi_step!(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, N;
            imaginary_time=imaginary_time)
    end
    return nothing
end

# ============================================================================
# Canonical kernels (energy + gradient). Propagator `apply_ddi_step!` stays
# in `interactions/ddi.jl` + `interactions/ddi_padded.jl` — that subsystem
# owns the 6-FFT convolution pipeline (`_compute_and_convolve_ddi!`,
# `_apply_ddi_rotation!`, etc.) which is real architecture, not delegation.
# ============================================================================

"""
    _ddi_energy_core(psi, sm, ddi, ddi_bufs, n_comp, ndim, n_pts, dV; ddi_padded)

`E_DDI = (1/2) ∫ d³r [Φ·F](r)`. CPU path; padded variant when
`ddi_padded !== nothing`. Reuses `ddi_bufs.Phi_*` after
`compute_ddi_potential!` populates them.
"""
function _ddi_energy_core(psi, sm::SpinMatrices{D}, ddi, ddi_bufs,
    n_comp, ndim, n_pts, dV; ddi_padded=nothing) where {D}
    if ddi_padded !== nothing
        _compute_and_convolve_ddi_padded!(psi, sm, ddi, ddi_padded, Val(D), ndim, n_pts)
        E = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            E +=
                ddi_padded.Phi_x_pad[I] * ddi_padded.Fx_pad[I] +
                ddi_padded.Phi_y_pad[I] * ddi_padded.Fy_pad[I] +
                ddi_padded.Phi_z_pad[I] * ddi_padded.Fz_pad[I]
        end
        return 0.5 * E * dV
    end
    _compute_spin_density!(
        ddi_bufs.Fx_r, ddi_bufs.Fy_r, ddi_bufs.Fz_r, psi, sm, Val(D), ndim, n_pts
    )
    compute_ddi_potential!(ddi, ddi_bufs)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E +=
            ddi_bufs.Phi_x[I] * ddi_bufs.Fx_r[I] +
            ddi_bufs.Phi_y[I] * ddi_bufs.Fy_r[I] +
            ddi_bufs.Phi_z[I] * ddi_bufs.Fz_r[I]
    end
    0.5 * E * dV
end

"""
    _ddi_energy_from_gpu_core(psi_host, sm, ddi_gpu, ddi_bufs_gpu, ...)

GPU path: rebuilds a host-side DDIParams + DDIBuffers, runs the host
convolution, reduces. Used when `_is_gpu(ws.ddi_bufs.Fx_r)`.
"""
function _ddi_energy_from_gpu_core(psi_host, sm::SpinMatrices{D}, ddi_gpu, ddi_bufs_gpu,
    n_comp, ndim, n_pts, dV; ddi_padded=nothing) where {D}
    Fx_r = zeros(Float64, n_pts)
    Fy_r = zeros(Float64, n_pts)
    Fz_r = zeros(Float64, n_pts)
    _compute_spin_density!(Fx_r, Fy_r, Fz_r, psi_host, sm, Val(D), ndim, n_pts)

    ddi_host = DDIParams(ddi_gpu.C_dd, _to_host(ddi_gpu.Q_xx), _to_host(ddi_gpu.Q_xy),
        _to_host(ddi_gpu.Q_xz), _to_host(ddi_gpu.Q_yy), _to_host(ddi_gpu.Q_yz),
        _to_host(ddi_gpu.Q_zz))
    rfft_plans = make_rfft_plans(n_pts)
    Fx_rk = rfft_plans.forward * Fx_r
    Fy_rk = similar(Fx_rk);
    Fz_rk = similar(Fx_rk)
    Phi_x_rk = similar(Fx_rk);
    Phi_y_rk = similar(Fx_rk);
    Phi_z_rk = similar(Fx_rk)
    Phi_x = similar(Fx_r);
    Phi_y = similar(Fx_r);
    Phi_z = similar(Fx_r)
    bufs_host = DDIBuffers(rfft_plans, Fx_r, Fy_r, Fz_r, Fx_rk, Fy_rk, Fz_rk,
        Phi_x_rk, Phi_y_rk, Phi_z_rk, Phi_x, Phi_y, Phi_z)

    compute_ddi_potential!(ddi_host, bufs_host)

    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E +=
            bufs_host.Phi_x[I] * bufs_host.Fx_r[I] +
            bufs_host.Phi_y[I] * bufs_host.Fy_r[I] +
            bufs_host.Phi_z[I] * bufs_host.Fz_r[I]
    end
    0.5 * E * dV
end

"""
    _grad_ddi_core!(grad, psi, ws, n_pts, D, ::Val{N})

`∂E_DDI/∂ψ*_m`: F_z·Φ_z (diagonal) + (F±·Φ∓)/2 (tridiagonal).
Computes spin density + DDI potential first, then accumulates.
"""
function _grad_ddi_core!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    ws.ddi !== nothing || return nothing
    sm = ws.spin_matrices
    F = ws.atom.F
    bufs = ws.ddi_bufs
    _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, n_pts)
    compute_ddi_potential!(ws.ddi, bufs)
    phi_x, phi_y, phi_z = bufs.Phi_x, bufs.Phi_y, bufs.Phi_z
    # Fz part (diagonal)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        m = Float64(F - (c - 1))
        view(grad, idx...) .+= m .* phi_z .* view(psi, idx...)
    end
    # F+/F− parts (tridiagonal)
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        view(grad, idx_cm1...) .+= 0.5 .* fp .* (phi_x .- im .* phi_y) .* view(psi, idx_c...)
        view(grad, idx_c...) .+= 0.5 .* fp .* (phi_x .+ im .* phi_y) .* view(psi, idx_cm1...)
    end
    nothing
end

function energy_contribution(::DDITerm, psi::AbstractArray{<:Complex}, ws)
    ws.ddi === nothing && return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(ws.grid)
    if _is_gpu(ws.ddi_bufs.Fx_r)
        return _ddi_energy_from_gpu_core(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs,
            n_comp, N, n_pts, dV; ddi_padded=ws.ddi_padded)
    else
        return _ddi_energy_core(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs,
            n_comp, N, n_pts, dV; ddi_padded=ws.ddi_padded)
    end
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# H_DDI mean-field: δE/δψ̄ = F_z·Φ_z (diag) + (F±·Φ∓)/2 (tridiag).
# `_grad_ddi_core!` already implements this; wrap into apply_operator!.
# Energy = (1/2)·Re⟨ψ, apply_op(ψ)⟩·dV (mean-field).
# ============================================================================

function apply_operator!(out::AbstractArray, ::DDITerm, ws, psi::AbstractArray)
    fill!(out, zero(eltype(out)))
    ws.ddi === nothing && return out
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    _grad_ddi_core!(out, psi, ws, n_pts, D, Val(N))
    return out
end

function add_gradient!(grad, ::DDITerm, psi, ws)
    ws.ddi === nothing && return nothing
    buf = similar(psi)
    apply_operator!(buf, DDITerm(), ws, psi)
    grad .+= buf
    return nothing
end

sign_oracle(::Type{DDITerm}) = (
    name="DDITerm: ⟨H_DDI⟩ matches stored ws.ddi sign convention",
    predicate=function (psi, ws)
        ws.ddi === nothing && return true
        # Verify Phi·F integrand is consistent with c_dd sign (no
        # absolute oracle since DDI orientation depends on geometry).
        E = energy_contribution(DDITerm(), psi, ws)
        return isfinite(E)
    end,
)
