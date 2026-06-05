# --- Split-step low-level kernels ---
#
# Pure helpers used by the Strang/Yoshida composers. Coriolis (rotating-frame
# L_z), 1D-shear FFT building block, host-device dispatch wrappers, and the
# GPU DDI step. Extracted from split_step.jl 2026-05-01 for readability —
# behaviour is bit-identical to the prior in-line versions.

"""
Apply diagonal phase `psi .*= imaginary_time ? exp.(arg) : cis.(arg)` where
`arg = factor * coord_vals[I[coord_dim]] * k_vals[I[fft_dim]]`. CPU uses the
direct scalar loop (cache-friendly); GPU uses reshape/broadcast (the scalar
loop scalar-indexes a CuArray and crashes — see gotcha memo).
"""
function _shear_phase!(psi, coord_vals, k_vals, fft_dim::Int, coord_dim::Int,
    factor::Float64, imaginary_time::Bool)
    if psi isa Array
        @inbounds for I in CartesianIndices(size(psi))
            arg = factor * coord_vals[I[coord_dim]] * k_vals[I[fft_dim]]
            psi[I] *= imaginary_time ? exp(arg) : cis(arg)
        end
    else
        coord_r = _axis_broadcast(psi, coord_vals, coord_dim)
        k_r = _axis_broadcast(psi, k_vals, fft_dim)
        if imaginary_time
            psi .*= exp.(factor .* coord_r .* k_r)
        else
            psi .*= cis.(factor .* coord_r .* k_r)
        end
    end
    nothing
end

function _apply_1d_shear_batch!(
    psi::AbstractArray{<:Complex},
    coord_vals::Vector{Float64},
    k_vals::Vector{Float64},
    fft_dim::Int,
    coord_dim::Int,
    factor::Float64,
    imaginary_time::Bool,
)
    abs(factor) < 1e-30 && return nothing

    psi_k = fft(psi, fft_dim)
    _shear_phase!(psi_k, coord_vals, k_vals, fft_dim, coord_dim, factor, imaginary_time)
    psi .= ifft(psi_k, fft_dim)
    nothing
end

function _apply_1d_shear_batch!(
    psi::AbstractArray{<:Complex},
    coord_vals::Vector{Float64},
    k_vals::Vector{Float64},
    fft_dim::Int,
    coord_dim::Int,
    factor::Float64,
    imaginary_time::Bool,
    fwd_plan,
    inv_plan,
)
    abs(factor) < 1e-30 && return nothing

    fwd_plan * psi
    _shear_phase!(psi, coord_vals, k_vals, fft_dim, coord_dim, factor, imaginary_time)
    inv_plan * psi
    nothing
end

# --- Split-step core ---

function _run_on_host!(f, psi::Array)
    f(psi)
end

function _run_on_host!(f, psi::AbstractArray)
    psi_host = Array(psi)
    f(psi_host)
    copyto!(psi, psi_host)
end

"""
GPU DDI step: convolve + rotation all on GPU using broadcast operations.

`psi_mf` (optional) — when supplied, the mean-field Φ_DDI is computed from
`psi_mf` rather than `ws.state.psi`. Rotation is still applied to `ws.state.psi`.
Used by the Track A1 midpoint predictor-corrector V step.
"""
function _apply_ddi_step_gpu!(ws, dt_half, ndim, imaginary_time;
    psi_mf::Union{Nothing, AbstractArray}=nothing)
    D = ws.spin_matrices.system.n_components
    N = ndims(ws.state.psi) - 1
    n_pts = ntuple(d -> size(ws.state.psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? ws.state.psi : psi_mf

    if ws.ddi_padded !== nothing
        @timeit_debug TIMER "ddi_convolve_padded" _compute_and_convolve_ddi_padded!(
            psi_mf_eff, ws.spin_matrices, ws.ddi, ws.ddi_padded,
            Val(D), ndim, n_pts,
        )
        phi_x = ws.ddi_padded.Phi_x_pad
        phi_y = ws.ddi_padded.Phi_y_pad
        phi_z = ws.ddi_padded.Phi_z_pad
    else
        @timeit_debug TIMER "ddi_convolve" _compute_and_convolve_ddi!(
            psi_mf_eff, ws.spin_matrices, ws.ddi, ws.ddi_bufs,
            Val(D), ndim, n_pts,
        )
        phi_x = ws.ddi_bufs.Phi_x
        phi_y = ws.ddi_bufs.Phi_y
        phi_z = ws.ddi_bufs.Phi_z
    end

    @timeit_debug TIMER "ddi_rotation" _apply_ddi_rotation!(
        ws.state.psi, phi_x, phi_y, phi_z,
        ws.spin_matrices, dt_half, ndim;
        imaginary_time,
    )
end
