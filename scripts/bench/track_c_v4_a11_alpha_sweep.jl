# Track C v4 A1.1 — α-sweep diagnostic.
#
# Q: Chin 4A in autonomous limit shows order 2. Why?
#   - Wrong FG coefficient (need to discover by sweep)
#   - Wrong FG sign (try ±α)
#   - Bare composition's [T,[T,V]] residual ≠ 0 (then no α can save it)
#
# Diagnostic: vary alpha ∈ {0, ±dt³/144, ±dt³/72, ±dt³/48, ±dt³/24} and
# measure the order across dt = {4e-3, 2e-3, 1e-3}. Whichever α brings
# Chin 4A to order ~4 is the correct coefficient (or none of them, in
# which case bare's [T,[T,V]] residual is the bottleneck).
#
# Problem: AUTONOMOUS frozen V_SM = c₁·m̄_global·F (linear) so that the
# only error source is the bare composition + FG. NO GP nonlinearity.
#
# Run: julia --project=. scripts/bench/track_c_v4_a11_alpha_sweep.jl

using LinearAlgebra
using Printf
using FFTW

const D = 3
const N = 16
const L = 8.0
const T_FINAL = 0.04
const C1_BENCH = 50.0

const SQ2 = sqrt(2.0)
const F_X = ComplexF64[0 SQ2/2 0; SQ2/2 0 SQ2/2; 0 SQ2/2 0]
const F_Y = ComplexF64[0 -im*SQ2/2 0; im*SQ2/2 0 -im*SQ2/2; 0 im*SQ2/2 0]
const F_Z = ComplexF64[1 0 0; 0 0 0; 0 0 -1.0]
const F_MATS = (F_X, F_Y, F_Z)

function _make_k_vecs()
    dk = 2π / L
    n_half = N ÷ 2
    k = [ax <= n_half ? (ax - 1) * dk : (ax - 1 - N) * dk for ax in 1:N]
    (k, k, k)
end

function spin_density!(m::Array{Float64,4}, psi::Array{ComplexF64,4})
    n_pts = size(psi)[1:3]
    fill!(m, 0.0)
    @inbounds for I in CartesianIndices(n_pts)
        for μ in 1:3
            val = 0.0im
            for a in 1:3, b in 1:3
                val += conj(psi[I, a]) * F_MATS[μ][a, b] * psi[I, b]
            end
            m[I, μ] = real(val)
        end
    end
    nothing
end

function apply_VSM!(out, psi_apply, m, c1)
    n_pts = size(psi_apply)[1:3]
    fill!(out, 0)
    @inbounds for I in CartesianIndices(n_pts)
        for a in 1:D
            v = ComplexF64(0)
            for μ in 1:3
                mμ = m[I, μ]
                if mμ != 0
                    for b in 1:D
                        v += mμ * F_MATS[μ][a, b] * psi_apply[I, b]
                    end
                end
            end
            out[I, a] = c1 * v
        end
    end
    nothing
end

function apply_T!(out, psi, k_vecs, buf, plan_f, plan_b)
    n_pts = size(psi)[1:3]
    @inbounds for c in 1:D
        for I in CartesianIndices(n_pts)
            buf[I] = psi[I, c]
        end
        plan_f * buf
        for I in CartesianIndices(n_pts)
            ksq = k_vecs[1][I[1]]^2 + k_vecs[2][I[2]]^2 + k_vecs[3][I[3]]^2
            buf[I] = 0.5 * ksq * buf[I]
        end
        plan_b * buf
        for I in CartesianIndices(n_pts)
            out[I, c] = buf[I]
        end
    end
    nothing
end

function apply_V_step!(psi, m, c1, dt)
    n_pts = size(psi)[1:3]
    H_loc = zeros(ComplexF64, D, D)
    @inbounds for I in CartesianIndices(n_pts)
        fill!(H_loc, 0)
        for μ in 1:3
            mμ = m[I, μ]
            if mμ != 0
                for a in 1:D, b in 1:D
                    H_loc[a, b] += c1 * mμ * F_MATS[μ][a, b]
                end
            end
        end
        F = eigen(Hermitian(H_loc))
        U = F.vectors * Diagonal(cis.(-dt .* F.values)) * F.vectors'
        ψ_loc = (psi[I, 1], psi[I, 2], psi[I, 3])
        for a in 1:D
            v = ComplexF64(0)
            for b in 1:D
                v += U[a, b] * ψ_loc[b]
            end
            psi[I, a] = v
        end
    end
    nothing
end

function apply_K_step!(psi, k_vecs, dt, buf, plan_f, plan_b)
    n_pts = size(psi)[1:3]
    @inbounds for c in 1:D
        for I in CartesianIndices(n_pts)
            buf[I] = psi[I, c]
        end
        plan_f * buf
        for I in CartesianIndices(n_pts)
            ksq = k_vecs[1][I[1]]^2 + k_vecs[2][I[2]]^2 + k_vecs[3][I[3]]^2
            buf[I] *= cis(-dt * 0.5 * ksq)
        end
        plan_b * buf
        for I in CartesianIndices(n_pts)
            psi[I, c] = buf[I]
        end
    end
    nothing
end

function apply_v4_direct!(out, psi, m_bg, c1, k_vecs, tmp1, tmp2, tmp3,
                          buf, plan_f, plan_b)
    apply_VSM!(tmp1, psi, m_bg, c1)
    apply_T!(tmp2, tmp1, k_vecs, buf, plan_f, plan_b)
    apply_VSM!(tmp3, tmp2, m_bg, c1)
    out .= 2 .* tmp3
    apply_VSM!(tmp2, tmp1, m_bg, c1)
    apply_T!(tmp3, tmp2, k_vecs, buf, plan_f, plan_b)
    out .-= tmp3
    apply_T!(tmp1, psi, k_vecs, buf, plan_f, plan_b)
    apply_VSM!(tmp2, tmp1, m_bg, c1)
    apply_VSM!(tmp3, tmp2, m_bg, c1)
    out .-= tmp3
    nothing
end

function apply_fg_correction!(psi, m_bg, c1, alpha, k_vecs,
                              tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    alpha == 0 && return nothing
    apply_v4_direct!(Aψ, psi, m_bg, c1, k_vecs, tmp1, tmp2, tmp3,
                     buf, plan_f, plan_b)
    @inbounds psi .-= im * alpha .* Aψ
    nothing
end

function chin4A_auto_step!(psi, c1, dt, k_vecs, m_global, alpha_val,
                           tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 6)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 3)
    apply_fg_correction!(psi, m_global, c1, alpha_val, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 3)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 6)
    nothing
end

function make_initial_psi()
    psi = zeros(ComplexF64, N, N, N, D)
    center = N ÷ 2 + 1
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / 16)
        phase = 0.6 * (i - center)
        psi[i, j, k, 1] = g * cis(phase) / sqrt(2)
        psi[i, j, k, 2] = g / sqrt(2)
    end
    psi ./= sqrt(sum(abs2, psi))
    psi
end

# Forest-Ruth as reference (order 4)
function forest_ruth_frozen_step!(psi, c1, dt, k_vecs, m_global, buf, plan_f, plan_b)
    γ₁ = 1.0 / (2 - 2^(1/3))
    γ₂ = -2^(1/3) / (2 - 2^(1/3))
    apply_V_step!(psi, m_global, c1, γ₁ * dt / 2)
    apply_K_step!(psi, k_vecs, γ₁ * dt, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, (γ₁ + γ₂) * dt / 2)
    apply_K_step!(psi, k_vecs, γ₂ * dt, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, (γ₁ + γ₂) * dt / 2)
    apply_K_step!(psi, k_vecs, γ₁ * dt, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, γ₁ * dt / 2)
    nothing
end

function run_chin4A_auto(c1, dt, alpha_factor)
    psi = make_initial_psi()
    m_global = zeros(Float64, N, N, N, 3)
    spin_density!(m_global, psi)
    k_vecs = _make_k_vecs()
    tmp1 = zeros(ComplexF64, N, N, N, D)
    tmp2 = zeros(ComplexF64, N, N, N, D)
    tmp3 = zeros(ComplexF64, N, N, N, D)
    Aψ = zeros(ComplexF64, N, N, N, D)
    buf = Array{ComplexF64}(undef, N, N, N)
    plan_f = plan_fft!(buf)
    plan_b = plan_ifft!(buf)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    for _ in 1:n_steps
        alpha_val = alpha_factor * actual_dt^3
        chin4A_auto_step!(psi, c1, actual_dt, k_vecs, m_global, alpha_val,
                          tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    end
    psi
end

function run_fr_auto(c1, dt)
    psi = make_initial_psi()
    m_global = zeros(Float64, N, N, N, 3)
    spin_density!(m_global, psi)
    k_vecs = _make_k_vecs()
    buf = Array{ComplexF64}(undef, N, N, N)
    plan_f = plan_fft!(buf)
    plan_b = plan_ifft!(buf)
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    for _ in 1:n_steps
        forest_ruth_frozen_step!(psi, c1, actual_dt, k_vecs, m_global, buf, plan_f, plan_b)
    end
    psi
end

# ----- Run -----
@printf("=== α-sweep diagnostic for Chin 4A autonomous ===\n")
@printf("Problem: F=1, c₁=%.1f, N=%d³, autonomous V_SM (frozen m̄_global), T=%.3f\n",
    C1_BENCH, N, T_FINAL)
@printf("Reference: Forest-Ruth autonomous at dt=5e-5\n\n")

@printf("Building reference... ")
flush(stdout)
t_ref = time()
psi_ref = run_fr_auto(C1_BENCH, 5.0e-5)
@printf("done (%.1fs)\n\n", time() - t_ref)

dts = [4.0e-3, 2.0e-3, 1.0e-3]
alpha_factors = [0.0, 1/144, 1/72, 1/48, 1/24, -1/144, -1/72, -1/48, -1/24]
alpha_labels = ("α=0 (bare)", "+1/144", "+1/72", "+1/48", "+1/24",
                "-1/144", "-1/72", "-1/48", "-1/24")

@printf("%-15s ", "α / dt³")
for dt in dts
    @printf("%-15s ", @sprintf("err@dt=%.0e", dt))
end
@printf("%-12s %-12s\n", "ord(4e-3→2e-3)", "ord(2e-3→1e-3)")

for (af, al) in zip(alpha_factors, alpha_labels)
    errs = Float64[]
    for dt in dts
        ψ = run_chin4A_auto(C1_BENCH, dt, af)
        push!(errs, sqrt(sum(abs2, ψ - psi_ref)))
    end
    ord1 = log2(errs[1] / errs[2])
    ord2 = log2(errs[2] / errs[3])
    @printf("%-15s ", al)
    for e in errs
        @printf("%-15s ", @sprintf("%.3e", e))
    end
    @printf("%-12.2f %-12.2f\n", ord1, ord2)
end

@printf("\nExpected order-4 behavior: errs ~ dt^4 → 16× reduction per dt halving → log2(16) = 4.0\n")
@printf("Read: which α gives order ~4 in both columns? That's the correct CK FG coefficient.\n")
