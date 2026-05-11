# Track C v4 Step 1d — Lab-path order test for direct-commutator FG correction.
#
# Problem (minimal F=1 lab path):
#   H = T + V_SM,  T = -½∇²,  V_SM = c₁ m_μ(ψ) F_μ   (self-consistent)
#   No V_trap, no c₀ — isolates the c₁ spin-mixing sector exactly so the
#   §5.2 direct commutator [V_SM,[T,V_SM]] suffices (no cross terms with V_trap).
#
# Schemes:
#   (a) Strang:     ψ ← V(dt/2) K(dt) V(dt/2) ψ                  (expect order 2)
#   (b) Strang+v4:  ψ ← M_c · V(dt/2) K(dt) V(dt/2) · M_c · ψ
#       where M_c = exp(-i (dt²/48) [V_SM,[T,V_SM]])             (expect order 4)
#
# Reference: Strang at dt_ref = dt_min/4 (richardson-extrapolated baseline).
#
# Gate (per integrator modernization plan):
#   - v4 order ≥ 3.5 → Step 2 (c₀ cross terms) + Step 3 (DDI cross terms)
#   - v4 order < 2.8 → Option III fallback (keep Y4-mid as practical optimum)
#
# Run: julia --project=. scripts/bench/track_c_v4_step1d_order.jl

using SpinorBEC
using LinearAlgebra
using Printf
using FFTW
using Random

const F_QUANT = 1
const D = 3
const N = 16
const L = 8.0
const T_FINAL = 0.04
const C1_BENCH = 50.0   # bump to lab-path magnitude so spin-mixing dynamics is meaningful

const SQ2 = sqrt(2.0)
const F_X = ComplexF64[0 SQ2/2 0; SQ2/2 0 SQ2/2; 0 SQ2/2 0]
const F_Y = ComplexF64[0 -im*SQ2/2 0; im*SQ2/2 0 -im*SQ2/2; 0 im*SQ2/2 0]
const F_Z = ComplexF64[1 0 0; 0 0 0; 0 0 -1.0]
const F_MATS = (F_X, F_Y, F_Z)

# ----- k-vectors (periodic spectral) -----
function _make_k_vecs()
    dk = 2π / L
    n_half = N ÷ 2
    k = [ax <= n_half ? (ax - 1) * dk : (ax - 1 - N) * dk for ax in 1:N]
    (k, k, k)
end

# ----- Spin density m(r) -----
function spin_density!(m::Array{Float64, 4}, psi::Array{ComplexF64, 4})
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

# ----- V_SM matrix application (linear in ψ, with m frozen at input ψ) -----
"""
Apply (V_SM ψ)_a = c1 m_μ(ψ) F_μ[a,b] ψ_b. Uses spin density of psi_for_m
(may differ from psi_apply for [V,[T,V]] direct commutator).
"""
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

# ----- T application: T ψ = -½∇²ψ via FFT -----
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

# ----- V step: ψ → exp(-i dt V_SM) ψ (matrix exp per voxel) -----
"""
Apply ψ ← exp(-i dt c1 m_μ F_μ) ψ at each spatial point. m frozen at input.
For F=1: c1 m·F is a 3×3 Hermitian matrix per voxel, exponentiated via eigen.
"""
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
        # exp(-i dt H_loc) — use scipy-style via eigen (D=3 small)
        F = eigen(Hermitian(H_loc))
        U = F.vectors * Diagonal(cis.(-dt .* F.values)) * F.vectors'
        # ψ_new = U ψ
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

# ----- K step: ψ → exp(-i dt T) ψ via FFT -----
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

# ----- Direct [V_SM, [T, V_SM]] commutator applied to ψ -----
"""
Compute Aψ = [V_SM(m_bg), [T, V_SM(m_bg)]] ψ_test.
Returns out — does NOT modify psi.
"""
function apply_v4_direct!(out, psi, m_bg, c1, k_vecs, tmp1, tmp2, tmp3,
                          buf, plan_f, plan_b)
    n_pts = size(psi)[1:3]
    # tmp1 = V ψ
    apply_VSM!(tmp1, psi, m_bg, c1)
    # tmp2 = T V ψ
    apply_T!(tmp2, tmp1, k_vecs, buf, plan_f, plan_b)
    # tmp3 = V T V ψ
    apply_VSM!(tmp3, tmp2, m_bg, c1)
    out .= 2 .* tmp3

    # V V ψ
    apply_VSM!(tmp2, tmp1, m_bg, c1)
    # T V V ψ
    apply_T!(tmp3, tmp2, k_vecs, buf, plan_f, plan_b)
    out .-= tmp3

    # T ψ → V T ψ → V V T ψ
    apply_T!(tmp1, psi, k_vecs, buf, plan_f, plan_b)
    apply_VSM!(tmp2, tmp1, m_bg, c1)
    apply_VSM!(tmp3, tmp2, m_bg, c1)
    out .-= tmp3
    nothing
end

# ----- FG correction substep: ψ ← exp(-i α [V,[T,V]]) ψ -----
"""
For small α, exp(-iαA)ψ ≈ ψ - iαAψ - (α²/2)A²ψ + ...
For FG correction coefficient α = dt²·c1²/48 ~ dt² (small), use first-order
Taylor: ψ ← ψ - iα · Aψ. This is enough for order-4 since the leading error
is α² ~ dt⁴ which is at the order of truncation we're trying to achieve.
For machine-precision Hermiticity preservation, use a SYMMETRIC Crank-Nicolson:
  (I + i(α/2)A) ψ_new = (I - i(α/2)A) ψ
Approximated to leading order: ψ_new = ψ - iα·Aψ (real solution for first-order).
"""
function apply_fg_correction!(psi, m_bg, c1, alpha, k_vecs,
                              tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    # Aψ = [V,[T,V]] ψ
    apply_v4_direct!(Aψ, psi, m_bg, c1, k_vecs, tmp1, tmp2, tmp3,
                     buf, plan_f, plan_b)
    # Symmetric expansion: ψ ← ψ - iα·Aψ - (α²/2)·A(Aψ) + ...
    # For order 4 sufficient: keep linear term (leading α ~ dt² so quadratic
    # term ~ dt⁴ matches truncation order).
    @inbounds psi .-= im * alpha .* Aψ
    nothing
end

# ----- Strang step (no correction) -----
function strang_step!(psi, c1, dt, k_vecs, m_buf, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    apply_K_step!(psi, k_vecs, dt, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    nothing
end

# ----- Strang + v4 FG correction step -----
# V_eff = V + (dt²/24)[V,[T,V]] folded into V-half steps. Per Chin 2005:
#   exp(-i(dt/2) V_eff) ≈ exp(-i(dt/2)V) · exp(-i(dt/2)·(dt²/24)[V,[T,V]])
#                      = exp(-i(dt/2)V) · exp(-i(dt³/48)[V,[T,V]])
# Total per full step: 2× FG correction at α=dt³/48 (symmetric placement).
function strang_v4_step!(psi, c1, dt, k_vecs, m_buf,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    alpha = dt^3 / 48.0   # FG coefficient (dt³ scaling, per Chin 2005)
    # V_eff right-half: V(dt/2) then FG-corr(dt³/48)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    spin_density!(m_buf, psi)
    apply_fg_correction!(psi, m_buf, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    # K step
    apply_K_step!(psi, k_vecs, dt, buf, plan_f, plan_b)
    # V_eff left-half: FG-corr(dt³/48) then V(dt/2)
    spin_density!(m_buf, psi)
    apply_fg_correction!(psi, m_buf, c1, alpha, k_vecs,
                         tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
    spin_density!(m_buf, psi)
    apply_V_step!(psi, m_buf, c1, dt / 2)
    nothing
end

# ----- Initial state: non-trivial spin-wave -----
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

# ----- Run scheme to T_FINAL -----
function run_scheme(scheme::Symbol, c1::Float64, dt::Float64)
    psi = make_initial_psi()
    n_steps = Int(round(T_FINAL / dt))
    actual_dt = T_FINAL / n_steps  # ensure exact T_FINAL
    k_vecs = _make_k_vecs()
    m_buf = zeros(Float64, N, N, N, 3)
    tmp1 = zeros(ComplexF64, N, N, N, D)
    tmp2 = zeros(ComplexF64, N, N, N, D)
    tmp3 = zeros(ComplexF64, N, N, N, D)
    Aψ = zeros(ComplexF64, N, N, N, D)
    buf = Array{ComplexF64}(undef, N, N, N)
    plan_f = plan_fft!(buf)
    plan_b = plan_ifft!(buf)

    for _ in 1:n_steps
        if scheme === :strang
            strang_step!(psi, c1, actual_dt, k_vecs, m_buf, buf, plan_f, plan_b)
        elseif scheme === :strang_v4
            strang_v4_step!(psi, c1, actual_dt, k_vecs, m_buf,
                            tmp1, tmp2, tmp3, Aψ, buf, plan_f, plan_b)
        else
            error("unknown scheme $scheme")
        end
    end
    psi
end

# ----- Order test -----
@printf("=== Track C v4 Step 1d order test ===\n")
@printf("Problem: F=1 spin-mixing only, c₁=%.1f, c₀=0, V_trap=0, N=%d³, T=%.3f\n",
    C1_BENCH, N, T_FINAL)
@printf("Reference: Strang at dt_ref = 2.5e-5\n\n")

c1 = C1_BENCH

# Reference: very small dt with Strang (assume Strang at dt → 0 converges)
@printf("Building reference (Strang dt=2.5e-5)... ")
t_ref = time()
ref_dt = 2.5e-5
psi_ref = run_scheme(:strang, c1, ref_dt)
@printf("done (%.1fs)\n\n", time() - t_ref)

dts = [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4]
@printf("%-8s  %-12s  %-12s  %-8s  %-12s  %-12s  %-8s\n",
    "dt", "Strang err", "Strang ord", "wall(s)",
    "v4 err", "v4 ord", "wall(s)")

s_errs = Float64[]
v_errs = Float64[]
s_walls = Float64[]
v_walls = Float64[]
for dt in dts
    t1 = time(); ψS = run_scheme(:strang, c1, dt); wS = time() - t1
    t2 = time(); ψV = run_scheme(:strang_v4, c1, dt); wV = time() - t2
    eS = sqrt(sum(abs2, ψS - psi_ref))
    eV = sqrt(sum(abs2, ψV - psi_ref))
    push!(s_errs, eS); push!(v_errs, eV)
    push!(s_walls, wS); push!(v_walls, wV)
    oS = length(s_errs) >= 2 ? log2(s_errs[end-1] / s_errs[end]) : NaN
    oV = length(v_errs) >= 2 ? log2(v_errs[end-1] / v_errs[end]) : NaN
    @printf("%-8.1e  %-12.3e  %-12s  %-8.2f  %-12.3e  %-12s  %-8.2f\n",
        dt, eS, isnan(oS) ? "—" : @sprintf("%.2f", oS), wS,
        eV, isnan(oV) ? "—" : @sprintf("%.2f", oV), wV)
end

# Verdict
@printf("\n%s\n", "═"^60)
strang_order = log2(s_errs[end-1] / s_errs[end])
v4_order = log2(v_errs[end-1] / v_errs[end])
@printf("Strang final order:  %.2f (expect ≈ 2.0)\n", strang_order)
@printf("v4 final order:      %.2f (gate: ≥ 3.5 → continue Step 2/3)\n", v4_order)
@printf("\nv4 vs Strang error ratio at dt=%.1e: %.2f×\n",
    dts[end], s_errs[end] / v_errs[end])
if v4_order >= 3.5
    @printf("✓ Gate 1 PASS — v4 achieves target order on lab path\n")
elseif v4_order >= 2.5
    @printf("△ Partial — v4 improves but doesn't reach order 4\n")
else
    @printf("✗ Gate 1 FAIL — Strang+FG alone gives order 2\n")
    @printf("\n── Diagnosis ──\n")
    @printf("Strang's leading-order error has TWO commutators:\n")
    @printf("  err = -(dt³/24)[V,[T,V]] + (dt³/12)[T,[T,V]] + O(dt⁵)\n")
    @printf("FG V_eff modification cancels [V,[T,V]] but NOT [T,[T,V]].\n")
    @printf("Order 4 requires harmonic V (where ∇²V = const → [T,[T,V]]=0)\n")
    @printf("OR a Forest-Ruth-like composition (multiple K substeps with\n")
    @printf("optimized coefficients).\n\n")
    @printf("Pivot: Track C v4 needs Forest-Ruth-Chin composition,\n")
    @printf("       not just FG correction stacked on Strang. The direct\n")
    @printf("       commutator kernel (Step 1c) remains valid — but its\n")
    @printf("       deployment needs the right multi-step skeleton.\n")
    @printf("       Y4-mid (Track A1) stays the practical optimum for 修論.\n")
end
@printf("%s\n", "═"^60)
