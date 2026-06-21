export spin_rotation_matrix, rotate_quantization_axis
export dipolar_field, apply_edh_rotation, apply_fl_alignment, column_density
export apply_rf_pulse, rf_tomography

"""
    spin_rotation_matrix(F, theta_x, theta_y, theta_z) → Matrix{ComplexF64}

(2F+1)×(2F+1) rotation matrix for rotating the quantization axis.

U = exp(-i(θ_x S_x + θ_y S_y + θ_z S_z))

where S_i are spin-F matrices. The rotation is applied in spinor space:
ψ'_m = Σ_m' U_{mm'} ψ_{m'}.
"""
function spin_rotation_matrix(F::Int, theta_x::Float64, theta_y::Float64, theta_z::Float64)
    sm = spin_matrices(F)
    D = 2F + 1
    H = theta_x .* Matrix(sm.Fx) .+ theta_y .* Matrix(sm.Fy) .+ theta_z .* Matrix(sm.Fz)
    eig = eigen(Hermitian(H))
    eig.vectors * Diagonal(cis.(-eig.values)) * eig.vectors'
end

"""
    rotate_quantization_axis(psi, F, theta_x, theta_y[, theta_z]) → psi_rotated

Apply a global spin rotation to the wavefunction. Equivalent to changing
the quantization axis direction.

For observation along a tilted axis (e.g. -16° around y):
    psi_rot = rotate_quantization_axis(psi, F, 0.0, -16*π/180)

Returns a new array (does not mutate).
"""
function rotate_quantization_axis(
    psi::AbstractArray{<:Complex},
    F::Int,
    theta_x::Float64,
    theta_y::Float64,
    theta_z::Float64=0.0,
)
    D = 2F + 1
    U = spin_rotation_matrix(F, theta_x, theta_y, theta_z)
    M = div(length(psi), D)

    psi_rot = similar(psi)
    psi_flat = reshape(psi, M, D)
    psi_rot_flat = reshape(psi_rot, M, D)
    mul!(psi_rot_flat, psi_flat, transpose(U))
    psi_rot
end

"""
    dipolar_field(ws) → (Bx, By, Bz)

Compute the dipolar magnetic field from the current spin density.
Returns three real arrays proportional to B_dip(r).

The returned arrays are Φ_x, Φ_y, Φ_z from the DDI convolution,
which are proportional to the dipolar field:
    B_dip_i(r) = (C_dd) Σ_j Q_ij * F_j(r)  (convolution in k-space)
"""
function dipolar_field(ws)
    psi = ws.state.psi
    sm = ws.spin_matrices
    ddi = ws.ddi
    ddi_bufs = ws.ddi_bufs
    ddi === nothing && throw(ArgumentError("Workspace has no DDI"))

    D = sm.system.n_components
    N = length(ws.grid.config.n_points)
    n_pts = ntuple(d -> size(psi, d), N)

    _compute_spin_density!(
        ddi_bufs.Fx_r, ddi_bufs.Fy_r, ddi_bufs.Fz_r,
        psi, sm, Val(D), N, n_pts,
    )
    compute_ddi_potential!(ddi, ddi_bufs)

    (
        Bx=copy(Array(ddi_bufs.Phi_x)),
        By=copy(Array(ddi_bufs.Phi_y)),
        Bz=copy(Array(ddi_bufs.Phi_z)),
    )
end

"""
    apply_edh_rotation(psi, Bx, By, Bz, t_hold, F, sm) → psi_edh

Apply Einstein-de Haas rotation: at each grid point, rotate the spinor
by the local dipolar field for time t_hold.

    U_EdH(r) = exp(-i t_hold (Bx(r) Sx + By(r) Sy + Bz(r) Sz))

This reproduces the EdH phase calculation from the old MATLAB code.
Returns a new array.
"""
function apply_edh_rotation(
    psi::AbstractArray{<:Complex},
    Bx::AbstractArray{<:AbstractFloat},
    By::AbstractArray{<:AbstractFloat},
    Bz::AbstractArray{<:AbstractFloat},
    t_hold::Float64,
    F::Int,
    sm::SpinMatrices{D},
) where {D}
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    m_vals = SVector{D, Float64}(ntuple(c -> Float64(F - (c - 1)), Val(D)))

    psi_edh = similar(psi)

    @inbounds for I in CartesianIndices(n_pts)
        spinor = SVector{D, ComplexF64}(ntuple(c -> psi[I, c], Val(D)))
        rotated = _apply_euler_spin_rotation(
            spinor,
            Bx[I], By[I], Bz[I],
            t_hold,
            F, m_vals,
            sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals,
            sm, false,
        )
        for c in 1:D
            psi_edh[I, c] = rotated[c]
        end
    end
    psi_edh
end

"""
    apply_fl_alignment(psi, Bx, By, Bz, F, sm) → psi_fl

Align the spin at each grid point along the local dipolar field direction
(Flower/FL phase approximation).

At each point, rotates the fully-polarized m=+F state to point along B(r).
Returns a new array.
"""
function apply_fl_alignment(
    psi::AbstractArray{<:Complex},
    Bx::AbstractArray{<:AbstractFloat},
    By::AbstractArray{<:AbstractFloat},
    Bz::AbstractArray{<:AbstractFloat},
    F::Int,
    sm::SpinMatrices{D},
) where {D}
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)

    psi_fl = similar(psi)

    @inbounds for I in CartesianIndices(n_pts)
        B_mag = sqrt(Bx[I]^2 + By[I]^2 + Bz[I]^2)
        if B_mag < 1e-30
            for c in 1:D
                psi_fl[I, c] = psi[I, c]
            end
            continue
        end

        beta = acos(clamp(Bz[I] / B_mag, -1.0, 1.0))
        alpha = atan(By[I], Bx[I])

        n = total_density(psi, ndim)
        amplitude = sqrt(abs(n[I]))

        for c in 1:D
            psi_fl[I, c] = zero(ComplexF64)
        end
        psi_fl[I, 1] = complex(amplitude)

        spinor = SVector{D, ComplexF64}(ntuple(c -> psi_fl[I, c], Val(D)))
        m_vals = SVector{D, Float64}(ntuple(c -> Float64(F - (c - 1)), Val(D)))
        # Send |m=+F⟩ (along +ẑ) to B̂ = (sinβcosα, sinβsinα, cosβ) via
        # U = R_z(α) R_y(β): tilt by β about ŷ, then rotate azimuth α about ẑ.
        rotated_y = _apply_euler_spin_rotation(
            spinor,
            0.0, 1.0, 0.0,
            beta,
            F, m_vals,
            sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals,
            sm, false,
        )
        rotated = _apply_euler_spin_rotation(
            rotated_y,
            0.0, 0.0, 1.0,
            alpha,
            F, m_vals,
            sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals,
            sm, false,
        )

        for c in 1:D
            psi_fl[I, c] = rotated[c]
        end
    end
    psi_fl
end

"""
    column_density(psi, ndim, component, axis) → Array

Column-integrated density of a single spinor component along the given axis.
For 3D psi, returns a 2D array. For 2D psi, returns a 1D array.
"""
function column_density(
    psi::AbstractArray{<:Complex},
    ndim::Int,
    component::Int,
    axis::Int,
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    idx = _component_slice(ndim, n_pts, component)
    ρ = abs2.(view(psi, idx...))
    _integrate_out_axis(ρ, axis)
end

# --- RF pulse + spin tomography ---
#
# A hard RF pulse is a uniform spin rotation about an in-plane axis n̂(φ) =
# (cos φ, sin φ, 0) by the pulse area θ = Ω_Rabi · τ: U = exp(-iθ n̂·F). It is the
# experimental knob that brings a transverse spin projection into the
# longitudinal (F_z) basis, so a Stern-Gerlach / population read-out can measure
# ⟨F_x⟩, ⟨F_y⟩ — not just ⟨F_z⟩. Built on `rotate_quantization_axis` (the same
# U); the only addition is the (θ, φ) → (θ_x, θ_y) parametrisation.

"""
    apply_rf_pulse(psi, F; theta, phi=0.0) -> psi_rotated

Hard RF pulse: rotate the spinor by area `theta` about the in-plane axis at
azimuth `phi` (`U = exp(-iθ(cosφ F_x + sinφ F_y))`). `phi=0` ⇒ about x̂,
`phi=π/2` ⇒ about ŷ. Non-mutating. `theta = Ω_Rabi · τ`.
"""
function apply_rf_pulse(psi::AbstractArray{<:Complex}, F::Int; theta::Real, phi::Real=0.0)
    rotate_quantization_axis(psi, F,
        Float64(theta) * cos(Float64(phi)), Float64(theta) * sin(Float64(phi)), 0.0)
end

# Local longitudinal magnetization density m_z(r) = Σ_c m_c |ψ_c(r)|² — what a
# population read-out (SG + count) measures.
function _longitudinal_spin_density(psi::AbstractArray{<:Complex}, sys::SpinSystem,
    ndim::Int)
    n_pts = ntuple(d -> size(psi, d), ndim)
    mz = zeros(Float64, n_pts)
    for (c, m) in enumerate(sys.m_values)
        comp = view(psi, _component_slice(ndim, n_pts, c)...)
        mc = Float64(m)
        @inbounds for I in CartesianIndices(n_pts)
            mz[I] += mc * abs2(comp[I])
        end
    end
    mz
end

"""
    rf_tomography(psi, sys, ndim) -> (fx, fy, fz)

Reconstruct the local spin density vector by the RF-rotation protocol: measure
the longitudinal magnetization with no pulse (⟨F_z⟩) and after two π/2 pulses
that map the transverse axes into the longitudinal one. For `U=exp(-iθn̂·F)` the
Heisenberg rotation gives `U†F_zU = -F_x` (π/2 about ŷ) and `+F_y` (π/2 about x̂),
so `fx = -m_z'[ŷ]`, `fy = +m_z'[x̂]`. The result equals
[`spin_density_vector`](@ref) exactly — this is the experimental readout chain
(populations only), validated against the direct operator.
"""
function rf_tomography(psi::AbstractArray{<:Complex}, sys::SpinSystem, ndim::Int)
    F = sys.F
    fz = _longitudinal_spin_density(psi, sys, ndim)
    fx = -_longitudinal_spin_density(apply_rf_pulse(psi, F; theta=π / 2, phi=π / 2),
        sys, ndim)
    fy = _longitudinal_spin_density(apply_rf_pulse(psi, F; theta=π / 2, phi=0.0),
        sys, ndim)
    (fx, fy, fz)
end
