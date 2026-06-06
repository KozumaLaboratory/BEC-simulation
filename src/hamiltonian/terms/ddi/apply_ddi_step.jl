# --- DDI substep entry point ---
#
# `apply_ddi_step!` ties the 3 sub-systems together (extracted 2026-05-02
# into `ddi/qtensor.jl`, `ddi/convolution.jl`, `ddi/rotation.jl`):
#   1. compute spin density via `_compute_spin_density!`
#   2. convolve in k-space via `_compute_and_convolve_ddi!`
#   3. apply Euler 5-stage rotation via `_apply_ddi_rotation!`
# Quasi-2D dispatch + cached rotation lookups handled inside each helper.

export apply_ddi_step!

"""
Full DDI sub-step: compute spin density, rfft convolve, apply Euler spin rotation.
"""
function apply_ddi_step!(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ddi::DDIParams{N},
    bufs::DDIBuffers,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {D, N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf

    @timeit_debug TIMER "ddi_convolve" _compute_and_convolve_ddi!(
        psi_mf_eff,
        sm,
        ddi,
        bufs,
        Val(D),
        ndim,
        n_pts,
    )

    @timeit_debug TIMER "ddi_rotation" _apply_ddi_rotation!(
        psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, dt_frac, ndim;
        imaginary_time,
    )
    nothing
end
