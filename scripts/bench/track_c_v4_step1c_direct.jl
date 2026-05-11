# Track C v4 Step 1c — DIRECT discrete commutator [V_SM, [T, V_SM]]ψ.
#
# Step 1a verified the multiplicative decomposition (terms (i)+(iii)).
# Step 1b found that the analytical decomposition (i)+(ii)+(iii) is Hermitian
# in the CONTINUOUS limit but DOES NOT cancel its anti-Hermitian parts at the
# DISCRETE FFT level: ∂_α(Q_ρα) ≠ (m × ∇²m)_ρ due to product-mode aliasing
# (Leibniz rule fails for FFT-of-product).
#
# Direct form is automatically discrete-Hermitian since it's a commutator of
# two discrete-Hermitian operators V_SM (diagonal in r, Hermitian in spin)
# and T = -½∇² (Hermitian via anti-Herm D_α).
#
# Identity: [V, [T, V]] = 2 V T V − V V T − T V V
#
# Cost per substep: 3 applications of V_SM, 1 application of T (= 1 FFT pair).
#
# Run: julia --project=. scripts/bench/track_c_v4_step1c_direct.jl

using SpinorBEC
using LinearAlgebra
using Printf
using FFTW
using Random

const F_QUANT = 1
const D = 3
const N = 16

const SQ2 = sqrt(2.0)
const F_X = ComplexF64[0 SQ2/2 0; SQ2/2 0 SQ2/2; 0 SQ2/2 0]
const F_Y = ComplexF64[0 -im*SQ2/2 0; im*SQ2/2 0 -im*SQ2/2; 0 im*SQ2/2 0]
const F_Z = ComplexF64[1 0 0; 0 0 0; 0 0 -1.0]
const F_MATS = (F_X, F_Y, F_Z)

function spin_density_field(psi::Array{ComplexF64, 4}, n_pts::NTuple{3, Int})
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

"""
Apply V_SM(m̄_bg) ψ = c₁ Σ_μ m̄_μ(r) F_μ ψ for fixed background m̄_bg.
This is a linear operator in ψ.
"""
function apply_VSM_linearized!(
    out::Array{ComplexF64, 4},
    psi::Array{ComplexF64, 4},
    m_bg::Array{Float64, 4},
    c1::Float64,
)
    n_pts = size(psi)[1:3]
    fill!(out, zero(ComplexF64))
    @inbounds for I in CartesianIndices(n_pts)
        for a in 1:D
            val = ComplexF64(0)
            for μ in 1:3
                m_μ = m_bg[I, μ]
                if m_μ != 0
                    for b in 1:D
                        val += m_μ * F_MATS[μ][a, b] * psi[I, b]
                    end
                end
            end
            out[I, a] = c1 * val
        end
    end
    out
end

"""
Apply T ψ = -½ ∇² ψ via FFT.
"""
function apply_T!(
    out::Array{ComplexF64, 4},
    psi::Array{ComplexF64, 4},
    k_vecs::NTuple{3, Vector{Float64}},
)
    n_pts = size(psi)[1:3]
    buf = Array{ComplexF64}(undef, n_pts...)
    plan = plan_fft!(buf)
    plan_inv = plan_ifft!(buf)
    @inbounds for c in 1:D
        for I in CartesianIndices(n_pts)
            buf[I] = psi[I, c]
        end
        plan * buf
        for I in CartesianIndices(n_pts)
            ksq = k_vecs[1][I[1]]^2 + k_vecs[2][I[2]]^2 + k_vecs[3][I[3]]^2
            buf[I] = 0.5 * ksq * buf[I]   # T = +½ k² (real-space: -½ ∇²)
        end
        plan_inv * buf
        for I in CartesianIndices(n_pts)
            out[I, c] = buf[I]
        end
    end
    out
end

"""
Apply [V_SM, [T, V_SM]] ψ_test via direct commutator with linearized V_SM(m_bg).
Returns out = 2 V T V ψ - V V T ψ - T V V ψ.
This is automatically discrete-Hermitian since V_SM and T are discrete-Hermitian.
"""
function apply_v4_direct_F1!(
    out::Array{ComplexF64, 4},
    psi::Array{ComplexF64, 4},
    m_bg::Array{Float64, 4},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
    tmp1::Array{ComplexF64, 4},
    tmp2::Array{ComplexF64, 4},
    tmp3::Array{ComplexF64, 4},
)
    abs(c1) < 1e-30 && (fill!(out, 0); return out)

    # tmp1 = V ψ
    apply_VSM_linearized!(tmp1, psi, m_bg, c1)
    # tmp2 = T V ψ
    apply_T!(tmp2, tmp1, k_vecs)
    # tmp3 = V T V ψ
    apply_VSM_linearized!(tmp3, tmp2, m_bg, c1)
    # out = 2 V T V ψ
    out .= 2 .* tmp3

    # tmp2 = V V ψ
    apply_VSM_linearized!(tmp2, tmp1, m_bg, c1)
    # tmp3 = T V V ψ
    apply_T!(tmp3, tmp2, k_vecs)
    # out -= T V V ψ
    out .-= tmp3

    # tmp2 = V V T ψ  (need T ψ first)
    apply_T!(tmp1, psi, k_vecs)
    apply_VSM_linearized!(tmp2, tmp1, m_bg, c1)
    apply_VSM_linearized!(tmp3, tmp2, m_bg, c1)
    out .-= tmp3

    out
end

# ----- Test fixtures -----

function _make_k_vecs()
    L = 8.0
    dk = 2π / L
    n_half = N ÷ 2
    k = [ax <= n_half ? (ax - 1) * dk : (ax - 1 - N) * dk for ax in 1:N]
    (k, k, k)
end

function _make_psi_spin_wave()
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

function _make_psi_const_fm()
    psi = zeros(ComplexF64, N, N, N, D)
    psi[:, :, :, 1] .= 1.0 + 0im
    psi ./= sqrt(sum(abs2, psi))
    psi
end

function _make_psi_polar()
    psi = zeros(ComplexF64, N, N, N, D)
    center = N ÷ 2 + 1
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / 16)
        psi[i, j, k, 2] = g
    end
    psi ./= sqrt(sum(abs2, psi))
    psi
end

function _make_psi_random(seed::Int)
    Random.seed!(seed)
    psi = randn(ComplexF64, N, N, N, D)
    psi ./= sqrt(sum(abs2, psi))
    psi
end

# ----- Tests -----

@printf("=== Track C v4 Step 1c (direct [V_SM, [T, V_SM]] commutator) ===\n")

k_vecs = _make_k_vecs()
n_pts = (N, N, N)
out = zeros(ComplexF64, N, N, N, D)
tmp1 = zeros(ComplexF64, N, N, N, D)
tmp2 = zeros(ComplexF64, N, N, N, D)
tmp3 = zeros(ComplexF64, N, N, N, D)

# Background from spin-wave
psi_bg = _make_psi_spin_wave()
m_bg = spin_density_field(psi_bg, n_pts)

# Test 1: c₁ = 0 → out = 0
psi_sw = _make_psi_spin_wave()
apply_v4_direct_F1!(out, psi_sw, m_bg, k_vecs, 0.0, tmp1, tmp2, tmp3)
test_1_ok = maximum(abs, out) < 1e-15
@printf("[1] c₁ = 0:                max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_1_ok ? "✓ PASS" : "✗ FAIL")

# Test 2: constant FM background → m̄ const → ∇m̄ = 0
# But background m_bg from spin_wave is NOT constant. Use uniform background:
m_const = zeros(Float64, N, N, N, 3)
m_const[:, :, :, 3] .= 1.0   # uniform Fz
apply_v4_direct_F1!(out, psi_sw, m_const, k_vecs, 1.0, tmp1, tmp2, tmp3)
# For constant V (no spatial dependence), [V, [T, V]] = ? V T V - V V T = V[V, T]·...
# Actually [V, T] = V T - T V where V multiplies in spin space (matrix) and T is scalar in spin.
# Since V is matrix-valued (F_z scalar in space), V and T commute (T is scalar in spin, V is matrix in spin but multiplied by const m̄_z which is r-independent).
# So [V, T] = 0 → [V, [T, V]] = 0
test_2_ok = maximum(abs, out) < 1e-10
@printf("[2] Constant m̄ bg:         max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_2_ok ? "✓ PASS" : "✗ FAIL")

# Test 3: zero m̄ background (polar limit)
m_zero = zeros(Float64, N, N, N, 3)
apply_v4_direct_F1!(out, psi_sw, m_zero, k_vecs, 1.0, tmp1, tmp2, tmp3)
test_3_ok = maximum(abs, out) < 1e-15
@printf("[3] Zero m̄ (polar):        max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_3_ok ? "✓ PASS" : "✗ FAIL")

# Test 4: non-trivial spin-wave background → out ≠ 0
apply_v4_direct_F1!(out, psi_sw, m_bg, k_vecs, 1.0, tmp1, tmp2, tmp3)
test_4_ok = maximum(abs, out) > 1e-10
@printf("[4] Spin-wave bg:          max|Aψ| = %.4e   %s\n",
    maximum(abs, out), test_4_ok ? "✓ PASS" : "✗ FAIL")

# Test 5: HERMITICITY ⟨φ, A ψ⟩ = ⟨A φ, ψ⟩
psi_test = _make_psi_random(42)
phi_test = _make_psi_random(99)
A_psi = zeros(ComplexF64, N, N, N, D)
A_phi = zeros(ComplexF64, N, N, N, D)
apply_v4_direct_F1!(A_psi, psi_test, m_bg, k_vecs, 1.0, tmp1, tmp2, tmp3)
apply_v4_direct_F1!(A_phi, phi_test, m_bg, k_vecs, 1.0, tmp1, tmp2, tmp3)

lhs = sum(conj(phi_test[I, c]) * A_psi[I, c]
    for I in CartesianIndices(n_pts), c in 1:D)
rhs = sum(conj(A_phi[I, c]) * psi_test[I, c]
    for I in CartesianIndices(n_pts), c in 1:D)

herm_dev = abs(lhs - rhs)
herm_rel = herm_dev / max(abs(lhs), 1e-30)
test_5_ok = herm_rel < 1e-10
@printf("[5] Hermiticity ⟨φ,Aψ⟩=⟨Aφ,ψ⟩:\n")
@printf("    LHS = %s\n", lhs)
@printf("    RHS = %s\n", rhs)
@printf("    rel dev = %.3e   %s\n",
    herm_rel, test_5_ok ? "✓ PASS — A is Hermitian (machine precision)" : "✗ FAIL")

# Test 6: c₁² scaling at c₁=2
A_psi2 = zeros(ComplexF64, N, N, N, D)
apply_v4_direct_F1!(A_psi2, psi_test, m_bg, k_vecs, 2.0, tmp1, tmp2, tmp3)
ratio = maximum(abs, A_psi2) / maximum(abs, A_psi)
test_6_ok = abs(ratio - 4.0) < 0.01
@printf("[6] c₁² scaling (1→2):     ratio = %.3f (expect 4.0)   %s\n",
    ratio, test_6_ok ? "✓ PASS" : "✗ FAIL")

# Test 7: Anti-symmetric in test wavefunction substitution
# Self-consistency: apply A to spin-wave ψ_sw (with bg = m(ψ_sw))
psi_use = _make_psi_spin_wave()
m_self = spin_density_field(psi_use, n_pts)
apply_v4_direct_F1!(out, psi_use, m_self, k_vecs, 1.0, tmp1, tmp2, tmp3)
test_7_ok = maximum(abs, out) > 1e-12
@printf("[7] Self-applied on ψ_SW:  max|Aψ_SW| = %.4e   %s\n",
    maximum(abs, out), test_7_ok ? "✓ PASS" : "✗ FAIL")

# Test 8: Hermiticity AT SELF-APPLICATION level (Aψ with m(ψ) — nonlinear)
# For force-gradient correction in split step, we use m at the current step.
# Hermiticity test here uses different test/φ but same m_bg.
# Already covered by test 5.

# Summary
all_pass = test_1_ok && test_2_ok && test_3_ok && test_4_ok && test_5_ok && test_6_ok && test_7_ok
@printf("\n%s\n", "═"^60)
@printf("Step 1c verdict: %d/7 tests pass\n",
    sum([test_1_ok, test_2_ok, test_3_ok, test_4_ok, test_5_ok, test_6_ok, test_7_ok]))
if all_pass
    @printf("✓ ALL PASS — direct commutator is discrete-Hermitian to machine precision\n")
    @printf("           Use this as v4 substep kernel; decomposition reserved for analysis\n")
else
    @printf("✗ SOME FAIL — see above\n")
end
@printf("%s\n", "═"^60)
