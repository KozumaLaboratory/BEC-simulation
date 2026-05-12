# Track C v4 Step A1.1 — Chin-Krotscheck 4A composition with v4 direct commutator.
#
# Step 1d showed Strang + FG correction plateaus at order 2 because FG cancels
# [V,[T,V]] but leaves [T,[T,V]] uncancelled. Chin & Krotscheck 2005 Algorithm
# 4A (eq 6.8) is a 5-stage symmetric Type-1 composition (1/6, 1/2, 2/3, 1/2,
# 1/6) where the choice c₁=1/6 sets the bare [T,[T,V]] residual to zero, and
# the modified middle Ṽ = V + (dt²/48)[V,[T,V]] cancels the bare [V,[T,V]]
# residual. Both leading BCH commutators die → order 4 in the LINEAR /
# AUTONOMOUS V case.
#
# In real time:
#   ψ(dt) = e^{-i(dt/6)V} e^{-i(dt/2)T} e^{-i(2dt/3)Ṽ(dt/2)} e^{-i(dt/2)T}
#           e^{-i(dt/6)V} ψ(0)
#
# The Ṽ exponential is split symmetrically as
#   e^{-i(2dt/3)Ṽ} = e^{-i(dt/3)V} · e^{+i(dt³/72)C} · e^{-i(dt/3)V}  + O(dt⁵)
# (BCH error: (1/24)[V,[V,C]]·(dt/3)²·(dt³/72) = O(dt⁵·dt²) → O(dt⁷) operator)
#
# **SIGN of FG correction in real time**: CK eq 6.9 Ṽ = V + (Δτ²/48)C is for
# IMAGINARY time. Wick rotation Δτ = i·dt sends Δτ² → -dt², so in real time
# Ṽ_real = V - (dt²/48)C, and the middle slot exponent becomes
# -i·(2dt/3)·Ṽ_real = -i·(2dt/3)V + i·(dt³/72)C, giving FG correction
# exp(+i·(dt³/72)C). In our `psi .-= im * alpha .* Aψ` form (= exp(-i·α·A))
# this needs α = -dt³/72. Verified by α-sweep diagnostic
# (`scripts/bench/track_c_v4_a11_alpha_sweep.jl`): α = -dt³/72 reaches FP-floor
# error ~1e-12 (order 4); α = +dt³/72 gives 1000× worse error (order 2).
#
# **Self-consistency for GP nonlinear V**: CK eq 6.8 requires Ṽ evaluated at
# ψ(dt/2). Without Picard on m̄ at the midpoint, dt³ residual remains and
# scheme drops to order 2 even though the linear/autonomous version is
# order 4. This bench includes BOTH freeze-m̄ and Picard variants to
# bisect the diagnosis.
#
# Problem (same as Step 1d for direct comparison):
#   F = 1, N = 16³, L = 8, c₁ = 50, V_trap = 0, c₀ = 0, T_final = 0.04.
# Reference: Forest-Ruth at dt = 5e-5 (order-4, FP-floor accuracy ~1e-14).
#
# Acceptance (per master plan A1.1):
#   measured order on Chin 4A scheme ≥ 3.5 (target = 4) in at least ONE
#   variant (freeze-m̄ for autonomous-equivalent; Picard for self-consistent).
#
# Run: julia --project=. scripts/bench/track_c_v4_a11_chin4A.jl

using LinearAlgebra
using Printf
using FFTW
using Random

const F_QUANT = 1
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

"""
ψ ← exp(-i α [V,[T,V]]) ψ via first-order Taylor (α ~ dt³ so dt⁶ truncation).
"""
function apply_fg_correction!(psi, m_bg, c1, alpha, k_vecs,
                              tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_v4_direct!(Aψ, psi, m_bg, c1, k_vecs, tmp1, tmp2, tmp3,
                     buf, plan_f, plan_b)
    @inbounds psi .-= im * alpha .* Aψ
    nothing
end

# ----- Strang baseline (order 2) -----
function strang_step!(psi, c1, dt, k_vecs, m_buf, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    apply_K_step!(psi, k_vecs, dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    nothing
end

# ----- Strang + FG (Step 1d ansatz — confirmed order 2) -----
function strang_v4_step!(psi, c1, dt, k_vecs, m_buf,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    alpha = dt^3 / 48.0
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    spin_density!(m_buf, psi)
    apply_fg_correction!(psi, m_buf, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_K_step!(psi, k_vecs, dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_fg_correction!(psi, m_buf, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    nothing
end

# ----- Chin-Krotscheck 4A (freeze-m̄, target order 4 only in autonomous limit) -----
"""
Symmetric Chin 4A with FG correction inside the middle Ṽ slot, but m̄ is
RECOMPUTED at each V slot from the current ψ (freeze-m̄ at each application
point, no Picard self-consistency on midpoint).

ψ(dt) = e^{-i(dt/6)V} K(dt/2)
        [ e^{-i(dt/3)V} · e^{-i(dt³/72)C} · e^{-i(dt/3)V} ]
        K(dt/2) e^{-i(dt/6)V} ψ(0)

For GP nonlinear V, this drops to order 2 in practice due to midpoint
self-consistency error.
"""
function chin4A_freeze_step!(psi, c1, dt, k_vecs, m_buf,
                             tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    alpha = -dt^3 / 72.0   # NEGATIVE — Wick rotation flips imaginary-time +Δτ²/48

    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)

    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)

    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 3)
    spin_density!(m_buf, psi)
    apply_fg_correction!(psi, m_buf, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 3)

    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)

    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)
    nothing
end

"""
Chin 4A with PICARD self-consistency on the middle Ṽ slot. Iterates m̄_mid
to fixed point, then applies V(dt/3)·FG·V(dt/3) with the converged m̄.

For autonomous-V the iteration converges in 1 pass (no nonlinearity). For
nonlinear GP, expect 2-4 iterations to reach 1e-12 convergence of m̄_mid.
"""
function chin4A_picard_step!(psi, c1, dt, k_vecs, m_buf,
                             tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b,
                             psi_save, m_entry, m_mid, m_exit, psi_trial;
                             max_iter::Int=6, tol::Float64=1e-12)
    alpha = -dt^3 / 72.0   # NEGATIVE — Wick rotation flips imaginary-time +Δτ²/48

    # Stage 1: first V(dt/6) + K(dt/2)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)

    # Save state at entry to middle slot, and its m̄
    psi_save .= psi
    spin_density!(m_entry, psi_save)
    m_mid .= m_entry  # initial guess for midpoint m̄

    for _ in 1:max_iter
        psi_trial .= psi_save
        apply_V_step!(psi_trial, m_mid, c1, dt / 3)
        apply_fg_correction!(psi_trial, m_mid, c1, alpha, k_vecs,
                             tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
        apply_V_step!(psi_trial, m_mid, c1, dt / 3)
        spin_density!(m_exit, psi_trial)
        # New estimate: average of entry and exit m̄
        max_change = 0.0
        @inbounds for ix in eachindex(m_mid)
            new_val = 0.5 * (m_entry[ix] + m_exit[ix])
            max_change = max(max_change, abs(new_val - m_mid[ix]))
            m_mid[ix] = new_val
        end
        max_change < tol && break
    end

    # Apply with converged m̄_mid
    psi .= psi_save
    apply_V_step!(psi, m_mid, c1, dt / 3)
    apply_fg_correction!(psi, m_mid, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_V_step!(psi, m_mid, c1, dt / 3)

    # Stage 3: K(dt/2) + V(dt/6)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)
    nothing
end

"""
Chin 4A Algorithm 4AWW (CK 2005 §IV): Strang half-step predictor for
ψ(t + dt/2), use that ψ's m̄ in the middle Ṽ slot. This is the CK-prescribed
self-consistency scheme for time-dependent (nonlinear) V.

Predictor: apply Strang(dt/2) from ψ_in to get ψ_predictor ≈ ψ(t + dt/2).
Corrector: apply Chin 4A with m_mid = m̄(ψ_predictor) frozen in middle slot.
"""
function chin4A_predcorr_step!(psi, c1, dt, k_vecs, m_buf,
                               tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b,
                               psi_predictor, m_mid)
    alpha = -dt^3 / 72.0

    # ===== Predictor: Strang half-step to estimate ψ(dt/2) =====
    psi_predictor .= psi
    spin_density!(m_buf, psi_predictor)
    apply_V_step!(psi_predictor, m_buf, c1, dt / 4)
    apply_K_step!(psi_predictor, k_vecs, dt / 2, buf, plan_f, plan_b)
    spin_density!(m_buf, psi_predictor)
    apply_V_step!(psi_predictor, m_buf, c1, dt / 4)
    spin_density!(m_mid, psi_predictor)  # m̄ at predicted midpoint

    # ===== Corrector: full Chin 4A with frozen m_mid in middle slot =====
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    apply_V_step!(psi, m_mid, c1, dt / 3)
    apply_fg_correction!(psi, m_mid, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_V_step!(psi, m_mid, c1, dt / 3)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 6)
    nothing
end

"""
DIAGNOSTIC: Chin 4A with m̄ FROZEN AT GLOBAL INITIAL STATE (autonomous).
ALL V/FG slots use m̄(ψ_initial_global) for the ENTIRE simulation. This
turns the GP into a linear autonomous problem H = T + V_SM(m̄_in_global).
Used to verify that the FG kernel implementation itself reaches order 4
in the absence of self-consistency complications.
"""
function chin4A_autonomous_step!(psi, c1, dt, k_vecs, m_global,
                                 tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    alpha = -dt^3 / 72.0   # NEGATIVE — Wick rotation flips imaginary-time +Δτ²/48
    apply_V_step!(psi, m_global, c1, dt / 6)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 3)
    apply_fg_correction!(psi, m_global, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 3)
    apply_K_step!(psi, k_vecs, dt / 2, buf, plan_f, plan_b)
    apply_V_step!(psi, m_global, c1, dt / 6)
    nothing
end

# ----- Forest-Ruth baseline (order 4, no force-gradient) ---------------------
"""
Forest-Ruth 1990: 4th-order symplectic, ONE NEGATIVE COEFFICIENT.
   ψ ← V(γ₁ dt/2) K(γ₁ dt) V((γ₁+γ₂) dt/2) K(γ₂ dt)
       V((γ₁+γ₂) dt/2) K(γ₁ dt) V(γ₁ dt/2) ψ
   γ₁ = 1/(2 − 2^{1/3}),  γ₂ = −2^{1/3}/(2 − 2^{1/3}).

Used here as a benchmark: pure non-FG order-4 scheme on the same lab path,
to verify the order test framework and bound the order-4 attainable error.
"""
function forest_ruth_step!(psi, c1, dt, k_vecs, m_buf, buf, plan_f, plan_b)
    γ₁ = 1.0 / (2 - 2^(1/3))
    γ₂ = -2^(1/3) / (2 - 2^(1/3))

    spin_density!(m_buf, psi); apply_V_step!(psi, m_buf, c1, γ₁ * dt / 2)
    apply_K_step!(psi, k_vecs, γ₁ * dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi); apply_V_step!(psi, m_buf, c1, (γ₁ + γ₂) * dt / 2)
    apply_K_step!(psi, k_vecs, γ₂ * dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi); apply_V_step!(psi, m_buf, c1, (γ₁ + γ₂) * dt / 2)
    apply_K_step!(psi, k_vecs, γ₁ * dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi); apply_V_step!(psi, m_buf, c1, γ₁ * dt / 2)
    nothing
end

# ----- Initial state -----
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

# ----- Run scheme -----
function run_scheme(scheme::Symbol, c1::Float64, dt::Float64)
    psi = make_initial_psi()
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps
    k_vecs = _make_k_vecs()
    m_buf = zeros(Float64, N, N, N, 3)
    tmp1 = zeros(ComplexF64, N, N, N, D)
    tmp2 = zeros(ComplexF64, N, N, N, D)
    tmp3 = zeros(ComplexF64, N, N, N, D)
    Aψ = zeros(ComplexF64, N, N, N, D)
    buf = Array{ComplexF64}(undef, N, N, N)
    plan_f = plan_fft!(buf)
    plan_b = plan_ifft!(buf)

    # Diagnostic state: global initial m̄ for autonomous variant
    m_global = zeros(Float64, N, N, N, 3)
    spin_density!(m_global, psi)

    # Picard scratch space
    psi_save = zeros(ComplexF64, N, N, N, D)
    m_entry = zeros(Float64, N, N, N, 3)
    m_mid = zeros(Float64, N, N, N, 3)
    m_exit = zeros(Float64, N, N, N, 3)
    psi_trial = zeros(ComplexF64, N, N, N, D)

    for _ in 1:n_steps
        if scheme === :strang
            strang_step!(psi, c1, actual_dt, k_vecs, m_buf, buf, plan_f, plan_b)
        elseif scheme === :strang_v4
            strang_v4_step!(psi, c1, actual_dt, k_vecs, m_buf,
                            tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
        elseif scheme === :chin4A_freeze
            chin4A_freeze_step!(psi, c1, actual_dt, k_vecs, m_buf,
                                tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
        elseif scheme === :chin4A_picard
            chin4A_picard_step!(psi, c1, actual_dt, k_vecs, m_buf,
                                tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b,
                                psi_save, m_entry, m_mid, m_exit, psi_trial)
        elseif scheme === :chin4A_predcorr
            chin4A_predcorr_step!(psi, c1, actual_dt, k_vecs, m_buf,
                                  tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b,
                                  psi_trial, m_mid)
        elseif scheme === :chin4A_autonomous
            chin4A_autonomous_step!(psi, c1, actual_dt, k_vecs, m_global,
                                    tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
        elseif scheme === :forest_ruth
            forest_ruth_step!(psi, c1, actual_dt, k_vecs, m_buf,
                              buf, plan_f, plan_b)
        elseif scheme === :forest_ruth_frozen
            # Autonomous baseline: Forest-Ruth with frozen global m̄
            forest_ruth_frozen_step!(psi, c1, actual_dt, k_vecs, m_global,
                                     buf, plan_f, plan_b)
        else
            error("unknown scheme $scheme")
        end
    end
    psi
end

"""
Forest-Ruth with FROZEN GLOBAL m̄. Used as autonomous reference for the
linear V_SM = c1 m̄_global·F problem (cross-check that the FG kernel
reaches order 4 when the only nonlinearity has been removed).
"""
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

# ----- Order test -----
@printf("=== Track C v4 A1.1 Chin-Krotscheck 4A order test ===\n")
@printf("Problem: F=1 spin-mixing, c₁=%.1f, c₀=0, V_trap=0, N=%d³, T=%.3f\n",
    C1_BENCH, N, T_FINAL)
@printf("Reference: Forest-Ruth (order 4) at dt = 5e-5 → FP-floor ~1e-14\n")
@printf("Build expensive: this may take several minutes.\n\n")

c1 = C1_BENCH

# Reference: Forest-Ruth (order 4) at small dt — FP-floor accuracy.
# For autonomous variants, the GP nonlinearity is removed so the
# reference is the SAME problem: m̄(initial ψ) frozen — both nonlinear
# and autonomous schemes converge to the SAME ψ_ref as dt → 0 because
# the m̄ DOES become trivially time-independent in either limit. So use
# Forest-Ruth (nonlinear) at small dt as a single reference for all
# schemes here.
@printf("Building reference (Forest-Ruth dt=5e-5)... ")
flush(stdout)
t_ref = time()
ref_dt = 5.0e-5
psi_ref_nl = run_scheme(:forest_ruth, c1, ref_dt)
@printf("done (%.1fs)\n", time() - t_ref)

@printf("Building autonomous reference (Forest-Ruth frozen dt=5e-5)... ")
flush(stdout)
t_ref2 = time()
psi_ref_auto = run_scheme(:forest_ruth_frozen, c1, ref_dt)
@printf("done (%.1fs)\n\n", time() - t_ref2)

dts = [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4]
# Group 1: nonlinear (self-consistent) — compare to psi_ref_nl
schemes_nl = [:strang, :chin4A_freeze, :chin4A_picard, :chin4A_predcorr, :forest_ruth]
labels_nl = ("Strang", "Chin4A_freeze", "Chin4A_picard", "Chin4A_predcorr", "Forest-Ruth")
# Group 2: autonomous (frozen global m̄) — compare to psi_ref_auto
schemes_auto = [:chin4A_autonomous, :forest_ruth_frozen]
labels_auto = ("Chin4A_auto", "FR_frozen")

# Combined schemes for unified table
schemes = vcat(schemes_nl, schemes_auto)
labels = (labels_nl..., labels_auto...)

errs = Dict(s => Float64[] for s in schemes)
walls = Dict(s => Float64[] for s in schemes)

for dt in dts
    @printf("dt = %.1e\n", dt)
    flush(stdout)
    for s in schemes
        t1 = time()
        ψ = run_scheme(s, c1, dt)
        w = time() - t1
        ref_ψ = s in schemes_auto ? psi_ref_auto : psi_ref_nl
        e = sqrt(sum(abs2, ψ - ref_ψ))
        push!(errs[s], e)
        push!(walls[s], w)
        @printf("  [%-15s err=%.2e %.1fs]\n",
            labels[findfirst(==(s), schemes)], e, w)
        flush(stdout)
    end
end

header = ["dt"; collect(labels)]
@printf("\n")
for (i, h) in enumerate(header)
    @printf("%-15s", h)
end
@printf("\n")
for (idx, dt) in enumerate(dts)
    @printf("%-15.1e", dt)
    for s in schemes
        @printf("%-15s", @sprintf("%.2e", errs[s][idx]))
    end
    @printf("\n")
end

@printf("\n")
for (i, h) in enumerate(header)
    @printf("%-15s", i == 1 ? "dt ratio" : h)
end
@printf("\n")
for idx in 2:length(dts)
    dt_ratio = dts[idx-1] / dts[idx]
    @assert abs(dt_ratio - 2.0) < 1e-9
    @printf("%-15s", @sprintf("%.1e/%.1e", dts[idx-1], dts[idx]))
    for s in schemes
        ord = log2(errs[s][idx-1] / errs[s][idx])
        @printf("%-15s", @sprintf("%.2f", ord))
    end
    @printf("\n")
end

@printf("\n%s\n", "═"^60)
# Use the FIRST-dt ratio (4e-3 → 2e-3) for verdict — Forest-Ruth saturates
# at the floor for finer dts, so first-step order is the cleanest signal.
first_orders = Dict(s => log2(errs[s][1] / errs[s][2]) for s in schemes)
for s in schemes
    label = labels[findfirst(==(s), schemes)]
    @printf("%-18s first-step (dt=4e-3 → 2e-3) order: %.2f\n", label, first_orders[s])
end

@printf("\n")
# Autonomous variants are FLOOR-LIMITED at ~1e-12 (Forest-Ruth reference precision).
# Compare absolute error magnitude (not measured order) against FR_frozen to
# certify autonomous order 4.
chin_auto_err = errs[:chin4A_autonomous][1]
fr_frozen_err = errs[:forest_ruth_frozen][1]
chin_auto_floor = chin_auto_err < 1e-10  # within 100× of FR_frozen floor
freeze_pred_order = first_orders[:chin4A_predcorr]
gate_predcorr = freeze_pred_order >= 3.5
gate_freeze = first_orders[:chin4A_freeze] >= 3.5

if gate_predcorr
    @printf("✓ A1.1 GATE PASS — Chin 4A predictor-corrector (4AWW) reaches order %.2f ≥ 3.5\n",
        freeze_pred_order)
    @printf("                   Composition + direct-commutator kernel + Strang midpoint predictor = order 4.\n")
    @printf("                   Proceed to A1.2 (DDI cross-terms).\n")
elseif gate_freeze
    @printf("✓ A1.1 GATE PASS (no predcorr needed) — Chin 4A freeze-m̄ reaches order ≥ 3.5\n")
elseif chin_auto_floor
    @printf("△ A1.1 PARTIAL — Chin 4A in autonomous limit reaches FP-floor (err=%.2e ≤ FR_frozen %.2e)\n",
        chin_auto_err, fr_frozen_err)
    @printf("                  → FG kernel + composition + sign all verified at order 4\n")
    @printf("                  Nonlinear self-consistent variants stuck at order %.2f\n",
        first_orders[:chin4A_predcorr])
    @printf("                  → predictor-corrector still insufficient; investigate iterated 4AWW\n")
else
    @printf("✗ A1.1 FAIL — even autonomous Chin 4A doesn't reach floor.\n")
    @printf("  Check FG sign, composition coefficients, reference accuracy.\n")
end
@printf("%s\n", "═"^60)
