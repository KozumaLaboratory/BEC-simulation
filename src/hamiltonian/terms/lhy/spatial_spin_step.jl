# spatial_spin_step.jl
# =================================================================
# The spin half of the spatially-varying LHY, as a propagator substep.
#
# `SpatialLHY` has ε = n^(5/2) e₁(p) with p = |⟨F⟩|/F, so ψ enters through the
# POLARISATION as well as the density:
#
#     δε/δψ̄ = (5/2) n^(3/2) e₁(p) ψ  +  c [ (ŝ·F)ψ/F − p ψ ],
#     c = n^(3/2) e₁′(p),   ŝ = ⟨F⟩/|⟨F⟩|
#
# The first term is `_lhy_V(n, p, lhy)` and the diagonal step applies it. The
# second is a SPIN operator — a diagonal step has nowhere to put it — so before
# this file the propagator simply omitted it while the LBFGS gradient carried it
# (issue #131). Measured on a random F=6 spinor with the ~20 % e₁(p) variation
# `spatial.jl` reports at F=6, the omission was 2.3 % of the gradient norm, and
# it is the physically interesting part: the force driving the spinor toward the
# polarisation that minimises e₁, i.e. the reason to make the LHY spatial.
#
# It costs no new machinery, because the operator is a rotation:
#
#     A = (c/F)(ŝ·F) − c p
#     exp(−dt·A) = exp(+dt·c·p) · exp(−dt·(φ·F)),     φ = (c/F)·ŝ
#
# a per-voxel scalar times a per-voxel spin rotation about the local ⟨F⟩ axis —
# exactly the Euler 5-stage `_apply_ddi_rotation!` already performs for the DDI,
# on CPU and GPU alike. Its convention was verified rather than read off:
# real time it applies exp(−i·dt·(φ·F)), imaginary time exp(−dt·(φ·F)).

export apply_spatial_lhy_spin_step!

"""
    apply_spatial_lhy_spin_step!(psi, lhy::SpatialLHY, sm, dt_frac, ndim;
                                 imaginary_time=false, psi_mf=psi)

Apply `exp(∓dt·A)` with `A = (c/F)(ŝ·F) − c·p`, the piece of `δε_LHY/δψ̄` the
diagonal step cannot carry. See the file header for the derivation.

`psi_mf` supplies the mean field (density, ⟨F⟩) — the same frozen-coefficient
convention every other nonlinear substep here uses, so a Strang sandwich stays
second order. Voxels with no density, no polarisation, or a flat `e₁` on their
interval contribute nothing and are skipped.
"""
function apply_spatial_lhy_spin_step!(
    psi::AbstractArray{<:Complex},
    lhy::SpatialLHY,
    sm::SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
    psi_mf::AbstractArray{<:Complex}=psi,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    Ns = prod(n_pts)
    F = lhy.F
    fp = lhy.fp_coeffs
    RT = real(eltype(psi))

    P = reshape(psi_mf, Ns, D)
    phi_x = zeros(RT, n_pts...)
    phi_y = zeros(RT, n_pts...)
    phi_z = zeros(RT, n_pts...)
    shift = zeros(RT, n_pts...)
    fx = reshape(phi_x, Ns)
    fy = reshape(phi_y, Ns)
    fz = reshape(phi_z, Ns)
    sh = reshape(shift, Ns)

    any_active = false
    @inbounds for i in 1:Ns
        n = 0.0
        szl = 0.0
        for c in 1:D
            a = abs2(P[i, c])
            n += a
            szl += (F - (c - 1)) * a
        end
        n < COUPLING_TOL && continue
        sp = zero(ComplexF64)
        for c in 2:D
            sp += fp[c] * conj(P[i, c - 1]) * P[i, c]
        end
        smag = sqrt(abs2(sp) + szl * szl)
        smag < COUPLING_TOL && continue
        p = smag / (n * F)
        de1 = _lhy_de1_dp(lhy, clamp(p, 0.0, 1.0))
        de1 == 0.0 && continue
        c_coef = n * sqrt(n) * de1
        # φ = (c/F)·ŝ, with ŝ = (Re S₊, Im S₊, S_z)/|S| — the same component
        # convention `_local_polarisation` uses to build |S| in the first place.
        g = c_coef / (F * smag)
        fx[i] = RT(g * real(sp))
        fy[i] = RT(g * imag(sp))
        fz[i] = RT(g * szl)
        sh[i] = RT(c_coef * p)
        any_active = true
    end
    any_active || return nothing

    _apply_ddi_rotation!(psi, phi_x, phi_y, phi_z, sm, dt_frac, ndim; imaginary_time)

    # The `−c·p` half of A: spin-independent, so a per-voxel scalar. Sign is
    # `+dt·c·p` in the exponent because A carries it with a minus.
    dt_t = RT(dt_frac)
    idx = ntuple(_ -> Colon(), ndim)
    scale = wick_phase(shift .* dt_t, imaginary_time)
    for c in 1:D
        view(psi, idx..., c) .*= scale
    end
    nothing
end

# Every other LHY has no spin dependence, so the substep is a no-op they never
# pay for — `_lhy_needs_spin` is the compile-time trait that decides.
apply_spatial_lhy_spin_step!(::AbstractArray, ::Any, ::SpinMatrices, ::Float64,
    ::Int; kwargs...) = nothing
