# Track C v4 Step 1b — analytical (i)+(ii)+(iii) Strang split + palindromic gate.
#
# Tests whether the analytical decomposition from §5.2 can be implemented as
# a palindromic Strang split:
#   σ(dt) = mult(dt/2) · deriv(dt) · mult(dt/2)
# where
#   mult(α) ψ = exp(-i α W_mult(r)) ψ   with W_mult = (i) + (iii)
#   deriv(α) ψ ≈ (I - i α A) ψ           with A = F_ρ (m × ∇m)_ρ · ∇
#
# Palindromic gate: σ(dt) · σ(-dt) · ψ ≈ ψ, expected residual ≤ O(dt⁵).
#
# Predicted outcome (from Step 1c analysis): FAIL at O(dt²) palindromic error,
# because W_mult has anti-Hermitian part (term i alone) → exp(-i α W_mult) is
# non-unitary at discrete level. The IBP cancellation between terms (i) and
# (ii) at continuum level does not survive FFT-product aliasing in the
# discrete spectral derivative of (m × ∇m).
#
# This script DOCUMENTS that the analytical decomposition Step 1b fails its
# palindromic gate at the discrete level, motivating the Step 1c pivot to the
# direct commutator [V_SM, [T, V_SM]] = 2VTV − VVT − TVV (automatically
# discrete-Hermitian).
#
# Run: julia --project=. scripts/bench/track_c_v4_step1b_palindrome.jl

using SpinorBEC
using LinearAlgebra
using Printf
using FFTW

const F_QUANT = 1
const D = 3
const N = 16

const SQ2 = sqrt(2.0)
const F_X = ComplexF64[0 SQ2/2 0; SQ2/2 0 SQ2/2; 0 SQ2/2 0]
const F_Y = ComplexF64[0 -im*SQ2/2 0; im*SQ2/2 0 -im*SQ2/2; 0 im*SQ2/2 0]
const F_Z = ComplexF64[1 0 0; 0 0 0; 0 0 -1.0]
const F_MATS = (F_X, F_Y, F_Z)

# ----- Field utilities -----
function spin_density_field(psi, n_pts)
    m = zeros(Float64, n_pts..., 3)
    @inbounds for I in CartesianIndices(n_pts)
        for μ in 1:3
            val = 0.0im
            for a in 1:3, b in 1:3
                val += conj(psi[I, a]) * F_MATS[μ][a, b] * psi[I, b]
            end
            m[I, μ] = real(val)
        end
    end
    m
end

function gradient_spectral(m, k_vecs)
    n_pts = size(m)[1:3]
    grad_m = zeros(Float64, n_pts..., 3, 3)
    buf = Array{ComplexF64}(undef, n_pts...)
    plan = plan_fft!(buf)
    plan_inv = plan_ifft!(buf)
    for μ in 1:3
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = complex(m[I, μ])
        end
        plan * buf
        m_k = copy(buf)
        for ax in 1:3
            k = k_vecs[ax]
            @inbounds for I in CartesianIndices(n_pts)
                kc = if (ax == 1)
                    k[I[1]]
                elseif (ax == 2)
                    k[I[2]]
                else
                    k[I[3]]
                end
                buf[I] = im * kc * m_k[I]
            end
            plan_inv * buf
            @inbounds for I in CartesianIndices(n_pts)
                grad_m[I, ax, μ] = real(buf[I])
            end
        end
    end
    grad_m
end

function laplacian_spectral(m, k_vecs)
    n_pts = size(m)[1:3]
    lap_m = zeros(Float64, n_pts..., 3)
    buf = Array{ComplexF64}(undef, n_pts...)
    plan = plan_fft!(buf)
    plan_inv = plan_ifft!(buf)
    for μ in 1:3
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = complex(m[I, μ])
        end
        plan * buf
        @inbounds for I in CartesianIndices(n_pts)
            ksq = k_vecs[1][I[1]]^2 + k_vecs[2][I[2]]^2 + k_vecs[3][I[3]]^2
            buf[I] = -ksq * buf[I]
        end
        plan_inv * buf
        @inbounds for I in CartesianIndices(n_pts)
            lap_m[I, μ] = real(buf[I])
        end
    end
    lap_m
end

function gradient_psi_spectral(psi, k_vecs)
    n_pts = size(psi)[1:3]
    grad_psi = zeros(ComplexF64, n_pts..., 3, D)
    buf = Array{ComplexF64}(undef, n_pts...)
    plan = plan_fft!(buf)
    plan_inv = plan_ifft!(buf)
    for β in 1:D
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = psi[I, β]
        end
        plan * buf
        psi_k = copy(buf)
        for ax in 1:3
            k = k_vecs[ax]
            @inbounds for I in CartesianIndices(n_pts)
                kc = if (ax == 1)
                    k[I[1]]
                elseif (ax == 2)
                    k[I[2]]
                else
                    k[I[3]]
                end
                buf[I] = im * kc * psi_k[I]
            end
            plan_inv * buf
            @inbounds for I in CartesianIndices(n_pts)
                grad_psi[I, ax, β] = buf[I]
            end
        end
    end
    grad_psi
end

# ----- Build W_mult per voxel (terms i + iii) -----
function build_W_mult(psi, k_vecs, c1)
    n_pts = size(psi)[1:3]
    W = zeros(ComplexF64, n_pts..., D, D)
    abs(c1) < 1e-30 && return W
    m = spin_density_field(psi, n_pts)
    grad_m = gradient_spectral(m, k_vecs)
    lap_m = laplacian_spectral(m, k_vecs)
    c1_sq = c1^2
    @inbounds for I in CartesianIndices(n_pts)
        mv = (m[I, 1], m[I, 2], m[I, 3])
        lv = (lap_m[I, 1], lap_m[I, 2], lap_m[I, 3])
        cross_i = (mv[2]*lv[3]-mv[3]*lv[2], mv[3]*lv[1]-mv[1]*lv[3], mv[1]*lv[2]-mv[2]*lv[1])
        for a in 1:D, b in 1:D
            v_i = ComplexF64(0);
            v_iii = ComplexF64(0)
            for ρ in 1:3
                v_i += cross_i[ρ] * F_MATS[ρ][a, b]
            end
            v_i *= -im/2 * c1_sq
            for μ in 1:3, ν in 1:3
                anti = (F_MATS[μ] * F_MATS[ν] + F_MATS[ν] * F_MATS[μ])[a, b]
                gd = 0.0
                for ax in 1:3
                    gd += grad_m[I, ax, μ] * grad_m[I, ax, ν]
                end
                v_iii += anti * gd
            end
            v_iii *= -0.5 * c1_sq
            W[I, a, b] = v_i + v_iii
        end
    end
    W
end

# Apply mult substep: ψ ← exp(-i α W_mult) ψ (matrix exp per voxel)
function apply_mult!(psi, W_mult, alpha)
    n_pts = size(psi)[1:3]
    @inbounds for I in CartesianIndices(n_pts)
        H_loc = zeros(ComplexF64, D, D)
        for a in 1:D, b in 1:D
            H_loc[a, b] = alpha * W_mult[I, a, b]
        end
        # exp(-i H_loc)
        M = exp(-1im * H_loc)
        psi_loc = (psi[I, 1], psi[I, 2], psi[I, 3])
        for a in 1:D
            val = ComplexF64(0)
            for b in 1:D
                val += M[a, b] * psi_loc[b]
            end
            psi[I, a] = val
        end
    end
end

# Apply deriv substep: ψ ← (I - i α A) ψ  where A = F_ρ (m × ∇m)_ρ · ∇
# (linear approximation valid for α = O(dt²), error O(dt⁴))
function apply_deriv!(psi, m, grad_m, k_vecs, alpha, c1)
    n_pts = size(psi)[1:3]
    c1_sq = c1^2
    grad_psi = gradient_psi_spectral(psi, k_vecs)
    cross_mgm = zeros(Float64, n_pts..., 3, 3)
    @inbounds for I in CartesianIndices(n_pts)
        for ax in 1:3
            gx = (grad_m[I, ax, 1], grad_m[I, ax, 2], grad_m[I, ax, 3])
            mv = (m[I, 1], m[I, 2], m[I, 3])
            cross_mgm[I, ax, 1] = mv[2]*gx[3] - mv[3]*gx[2]
            cross_mgm[I, ax, 2] = mv[3]*gx[1] - mv[1]*gx[3]
            cross_mgm[I, ax, 3] = mv[1]*gx[2] - mv[2]*gx[1]
        end
    end
    # A ψ_a = -i c₁² F_ρ[a,b] (m × ∇m)_ρ_α (∂_α ψ_b)
    # apply ψ -= i α A ψ
    @inbounds for I in CartesianIndices(n_pts)
        for a in 1:D
            val = ComplexF64(0)
            for ρ in 1:3, ax in 1:3
                coef = cross_mgm[I, ax, ρ]
                if coef != 0
                    for b in 1:D
                        val += F_MATS[ρ][a, b] * coef * grad_psi[I, ax, b]
                    end
                end
            end
            # A ψ_a (without the -i c1² overall factor)
            # Total A_op coefficient: -i c1² · (cross) · grad_psi
            # apply: ψ ← ψ - i α · A_op ψ = ψ - i α · (-i c1²) · F (m × ∇m) ∇ψ
            #                            = ψ - α c1² F (m × ∇m) ∇ψ
            psi[I, a] -= alpha * c1_sq * val
        end
    end
end

# ----- Symmetric Strang sub-step: mult(α/2) · deriv(α) · mult(α/2) -----
function strang_substep!(psi, k_vecs, c1, dt)
    # m, grad_m from CURRENT psi (frozen for the whole substep)
    n_pts = size(psi)[1:3]
    m = spin_density_field(psi, n_pts)
    grad_m = gradient_spectral(m, k_vecs)
    W_mult = build_W_mult(psi, k_vecs, c1)

    apply_mult!(psi, W_mult, dt/2)
    apply_deriv!(psi, m, grad_m, k_vecs, dt, c1)
    apply_mult!(psi, W_mult, dt/2)
end

# ----- Palindromic gate test: σ(dt) σ(-dt) ψ ≈ ψ -----
function _make_k_vecs()
    L = 8.0
    dk = 2π / L
    n_half = N ÷ 2
    k = [ax <= n_half ? (ax-1)*dk : (ax-1-N)*dk for ax in 1:N]
    (k, k, k)
end

function _make_psi_spin_wave()
    psi = zeros(ComplexF64, N, N, N, D)
    center = N ÷ 2 + 1
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        r2 = (i-center)^2 + (j-center)^2 + (k-center)^2
        g = exp(-r2 / 16)
        phase = 0.6 * (i - center)
        psi[i, j, k, 1] = g * cis(phase) / sqrt(2)
        psi[i, j, k, 2] = g / sqrt(2)
    end
    psi ./= sqrt(sum(abs2, psi))
    psi
end

@printf("=== Track C v4 Step 1b palindromic gate test ===\n")
@printf("Strang split σ(dt) = mult(dt/2) · deriv(dt) · mult(dt/2)\n")
@printf("Palindromic residual: ‖σ(dt)·σ(-dt) ψ − ψ‖ / ‖ψ‖\n")
@printf("Expected for palindromic (Strang of Hermitian pieces): O(dt⁵)\n")
@printf("Expected for non-Hermitian pieces (term i anti-Herm at discrete): ≥ O(dt²)\n\n")

k_vecs = _make_k_vecs()
c1 = 50.0
@printf("%-8s  %-12s  %-8s  %-8s\n", "dt", "palind_res", "order", "α²·dt²")
prev_res = NaN
for dt in [0.04, 0.02, 0.01, 0.005, 0.0025]
    psi0 = _make_psi_spin_wave()
    psi = copy(psi0)
    strang_substep!(psi, k_vecs, c1, dt)
    strang_substep!(psi, k_vecs, c1, -dt)
    res = norm(psi .- psi0) / norm(psi0)
    ord = isnan(prev_res) ? NaN : log2(prev_res / res)
    α = c1^2 * dt^3 / 48
    @printf("%-8.4f  %-12.4e  %-8s  %.2e\n",
        dt, res, isnan(ord) ? "—" : @sprintf("%.2f", ord), α^2 * dt^2)
    global prev_res = res
end

@printf("\n── Verdict ──\n")
@printf("Order 5+ → palindromic (Strang of Hermitian pieces)\n")
@printf("Order 2-3 → non-Hermitian piece breaks palindrome (Step 1c pivot needed)\n")
@printf("Order 1 → fundamental bug\n")
