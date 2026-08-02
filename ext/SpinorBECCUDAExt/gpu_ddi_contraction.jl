# Fused GPU k-space DDI contraction.
#
# `Φ_α(k) = C · Q_αβ(k) · F_β(k)` is one pass over k-space, and the CPU arm of
# `_ddi_k_contraction_core!` already writes it that way. The GPU arm was three
# broadcasts, one per α, each re-reading all three `F_β` and writing one `Φ_α`:
#
#   3 broadcasts × (3 F reads + 3 Q reads + 1 Φ write)  = 9 F + 9 Q + 3 Φ
#   1 fused kernel × (3 F reads + 6 Q reads + 3 Φ writes) = 3 F + 6 Q + 3 Φ
#
# so it moved 21 arrays' worth of k-space where 12 suffice. Measured on an H100
# (bench/profile_ddi_convolve.jl), the contraction was 25 % of the padded
# convolution at 32³ and 31 % at 64³ — the largest item after the FFTs, which
# are already within ~3× of their bandwidth floor and cannot be reduced without
# changing the padded volume.
#
# Q is symmetric, so six components cover it: the sub-diagonal reads reuse
# `Q_xy`, `Q_xz`, `Q_yz`. Expressions and their evaluation order are exactly the
# CPU arm's, which is what makes the parity gate
# (test/gpu/test_gpu_ddi_contraction_parity.jl) a comparison of realizations
# rather than of formulas.

@inline function _ddi_contract_kernel!(
    Px, Py, Pz, Fx, Fy, Fz, Qxx, Qxy, Qxz, Qyy, Qyz, Qzz, Ct,
)
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > length(Px) && return nothing
    @inbounds begin
        fk_x = Fx[i]
        fk_y = Fy[i]
        fk_z = Fz[i]
        qxy = Qxy[i]
        qxz = Qxz[i]
        qyz = Qyz[i]
        Px[i] = Ct * (Qxx[i] * fk_x + qxy * fk_y + qxz * fk_z)
        Py[i] = Ct * (qxy * fk_x + Qyy[i] * fk_y + qyz * fk_z)
        Pz[i] = Ct * (qxz * fk_x + qyz * fk_y + Qzz[i] * fk_z)
    end
    return nothing
end

function SpinorBEC._ddi_k_contraction_core!(
    Phi_x_rk::CuArray, Phi_y_rk, Phi_z_rk,
    Fx_rk, Fy_rk, Fz_rk,
    Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz,
    C, rk_shape, is_cpu::Bool,
)
    Ct = convert(eltype(Q_xx), C)
    n = length(Phi_x_rk)
    threads = min(n, 256)
    blocks = cld(n, threads)
    CUDA.@cuda threads = threads blocks = blocks _ddi_contract_kernel!(
        vec(Phi_x_rk), vec(Phi_y_rk), vec(Phi_z_rk),
        vec(Fx_rk), vec(Fy_rk), vec(Fz_rk),
        vec(Q_xx), vec(Q_xy), vec(Q_xz), vec(Q_yy), vec(Q_yz), vec(Q_zz), Ct)
    nothing
end

# The three-broadcast form, kept as the parity target. This is what every GPU run
# took before the kernel above.
function _ddi_k_contraction_bcast!(
    Phi_x_rk, Phi_y_rk, Phi_z_rk, Fx_rk, Fy_rk, Fz_rk,
    Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, C,
)
    Ct = convert(eltype(Q_xx), C)
    @. Phi_x_rk = Ct * (Q_xx * Fx_rk + Q_xy * Fy_rk + Q_xz * Fz_rk)
    @. Phi_y_rk = Ct * (Q_xy * Fx_rk + Q_yy * Fy_rk + Q_yz * Fz_rk)
    @. Phi_z_rk = Ct * (Q_xz * Fx_rk + Q_yz * Fy_rk + Q_zz * Fz_rk)
    nothing
end
