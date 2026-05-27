# Track C v4 Step 1a smoke — multiplicative terms (i) + (iii), F=1, no DDI.
#
# From docs/design/integrator_track_c_derivation.md §5.2:
#
#   [V_SM, [T, V_SM]] = c_1² [
#     (i)   -i/2 F_ρ (m × ∇²m)_ρ            ← multiplicative
#     (ii)  -i F_ρ (m × ∇m)_ρ · ∇           ← derivative on ∇ψ (DEFER to Step 1b)
#     (iii) -1/2 {F_μ, F_ν}(∇m_μ)(∇m_ν)    ← multiplicative
#   ]
#
# Step 1a scope: compute (i) + (iii) only, F=1 (D=3).
#
# Goals:
#   1. Implement `_compute_v4_mult_F1!(W_buf, psi, grid, c1, spin_matrices)`
#      → returns matrix-valued correction W(r) of shape (Nx, Ny, Nz, 3, 3)
#   2. Verify limits:
#      - c1 = 0  → W ≡ 0 (all terms vanish)
#      - const m → ∇m = 0, ∇²m = 0 → W ≡ 0
#   3. Round-trip palindromic check (NOT integrated into split step yet)
#   4. Smoke test on simple ψ with non-trivial ⟨F⟩(r)
#
# Step 1b (NEXT, blocked on Step 1a pass): derivative term (ii)
# Step 1c (after 1b): integrate (i)+(ii)+(iii) into split_step_forcegrad_v4!
# Step 1d (after 1c): order verification on lab path
#
# Run: julia --project=. scripts/bench/track_c_v4_step1a_smoke.jl

using SpinorBEC
using LinearAlgebra
using Printf
using FFTW

const F_QUANT = 1
const D = 3
const N = 16

# F=1 spin matrices (m=+1, 0, -1 basis)
const SQ2 = sqrt(2.0)
const F_X = ComplexF64[0 SQ2/2 0; SQ2/2 0 SQ2/2; 0 SQ2/2 0]
const F_Y = ComplexF64[0 -im*SQ2/2 0; im*SQ2/2 0 -im*SQ2/2; 0 im*SQ2/2 0]
const F_Z = ComplexF64[1 0 0; 0 0 0; 0 0 -1.0]
const F_MATS = (F_X, F_Y, F_Z)

"""
Compute ⟨F_μ⟩(r) = ψ†F_μψ for each spatial point.
Returns (Nx, Ny, Nz, 3) Real array.
"""
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
FFT spectral derivative: returns ∂_α m_μ for α=1,2,3 axes.
Output: (Nx, Ny, Nz, 3, 3) where last 2 dims are (axis, μ).
"""
function gradient_spectral(m::Array{Float64, 4}, k_vecs::NTuple{3, Vector{Float64}})
    n_pts = size(m)[1:3]
    grad_m = zeros(Float64, n_pts..., 3, 3)  # [r, axis, μ]
    buf = Array{ComplexF64}(undef, n_pts...)
    plan = plan_fft!(buf)
    plan_inv = plan_ifft!(buf)
    for μ in 1:3
        # FFT of m_μ
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = complex(m[I, μ])
        end
        plan * buf  # in-place forward FFT
        m_k = copy(buf)  # save k-space
        for ax in 1:3
            k = k_vecs[ax]
            # ∂/∂x_ax in k-space: multiply by i k_ax
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
            plan_inv * buf  # in-place inverse FFT
            @inbounds for I in CartesianIndices(n_pts)
                grad_m[I, ax, μ] = real(buf[I])
            end
        end
    end
    grad_m
end

"""
FFT spectral Laplacian: returns ∇²m_μ for each μ.
Output: (Nx, Ny, Nz, 3).
"""
function laplacian_spectral(m::Array{Float64, 4}, k_vecs::NTuple{3, Vector{Float64}})
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

"""
Compute v4 multiplicative correction terms (i) + (iii) for F=1.

Returns W(r) of shape (Nx, Ny, Nz, 3, 3), complex matrix per voxel.

Term (i):   -i/2 c_1² F_ρ (m × ∇²m)_ρ          ← Hermitian × i = anti-Hermitian × F_ρ
Term (iii): -1/2 c_1²   {F_μ, F_ν}(∇m_μ)(∇m_ν)  ← Hermitian (symmetric in μ↔ν)

Note: term (i) coefficient is -i/2 which gives a Hermitian operator (since F_ρ is
Hermitian and (m × ∇²m) is real).
"""
function compute_v4_mult_F1!(
    W::Array{ComplexF64, 5},
    psi::Array{ComplexF64, 4},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
)
    n_pts = size(psi)[1:3]
    @assert size(W) == (n_pts..., D, D)
    @assert size(psi)[4] == D

    fill!(W, zero(ComplexF64))
    abs(c1) < 1e-30 && return W  # c1=0 short-circuit

    # 1. ⟨F_μ⟩(r)
    m = spin_density_field(psi, n_pts)

    # 2. ∇m_μ, ∇²m_μ (FFT spectral)
    grad_m = gradient_spectral(m, k_vecs)   # [r, axis, μ]
    lap_m = laplacian_spectral(m, k_vecs)   # [r, μ]

    c1_sq = c1^2

    # 3. Per-voxel matrix assembly
    @inbounds for I in CartesianIndices(n_pts)
        # Term (i): m × ∇²m  ← real 3-vector
        m_vec = (m[I, 1], m[I, 2], m[I, 3])
        lap_vec = (lap_m[I, 1], lap_m[I, 2], lap_m[I, 3])
        cross_i = (
            m_vec[2] * lap_vec[3] - m_vec[3] * lap_vec[2],
            m_vec[3] * lap_vec[1] - m_vec[1] * lap_vec[3],
            m_vec[1] * lap_vec[2] - m_vec[2] * lap_vec[1],
        )
        # -i/2 c_1² Σ_ρ (m×∇²m)_ρ F_ρ
        # Term (iii): -1/2 c_1² Σ_{μν} {F_μ, F_ν}(∇m_μ)(∇m_ν) summed over spatial axes
        for a in 1:D, b in 1:D
            val_i = ComplexF64(0)
            for ρ in 1:3
                val_i += cross_i[ρ] * F_MATS[ρ][a, b]
            end
            val_i *= -im / 2 * c1_sq

            val_iii = ComplexF64(0)
            for μ in 1:3, ν in 1:3
                # {F_μ, F_ν} = F_μ F_ν + F_ν F_μ
                anticomm_ab = (F_MATS[μ] * F_MATS[ν] + F_MATS[ν] * F_MATS[μ])[a, b]
                # Σ over spatial axes ax of (∂_ax m_μ)(∂_ax m_ν)
                grad_dot = 0.0
                for ax in 1:3
                    grad_dot += grad_m[I, ax, μ] * grad_m[I, ax, ν]
                end
                val_iii += anticomm_ab * grad_dot
            end
            val_iii *= -0.5 * c1_sq

            W[I, a, b] = val_i + val_iii
        end
    end
    W
end

# ----- Limit tests -----

function _make_test_psi(state_type::Symbol)
    psi = zeros(ComplexF64, N, N, N, D)
    center = N ÷ 2 + 1
    @inbounds for i in 1:N, j in 1:N, k in 1:N
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / 16)
        if state_type === :polar
            psi[i, j, k, 2] = g
        elseif state_type === :fm_z
            psi[i, j, k, 1] = g
        elseif state_type === :spin_wave
            # Spatially-varying ⟨F⟩(r): position-dependent FM-polar mix.
            # ψ_+1 = g cis(kx)/√2, ψ_0 = g/√2, ψ_-1 = 0
            # → ⟨F_x⟩ = (g²/√2) cos(kx), ⟨F_y⟩ = (g²/√2) sin(kx) — both vary ✓
            phase = 0.6 * (i - center)
            psi[i, j, k, 1] = g * cis(phase) / sqrt(2)
            psi[i, j, k, 2] = g / sqrt(2)
        elseif state_type === :const_fm
            # FM uniform → constant ⟨F⟩ = (0, 0, 1) → ∇m = 0, ∇²m = 0 → W = 0
            psi[i, j, k, 1] = 1.0 + 0im
        end
    end
    psi ./= sqrt(sum(abs2, psi))
    psi
end

function _make_k_vecs()
    L = 8.0
    dk = 2π / L
    n_half = N ÷ 2
    k = [ax <= n_half ? (ax - 1) * dk : (ax - 1 - N) * dk for ax in 1:N]
    (k, k, k)
end

@printf("=== Track C v4 Step 1a smoke (F=1, %d³, mult terms only) ===\n", N)

k_vecs = _make_k_vecs()
W = zeros(ComplexF64, N, N, N, D, D)

# Test 1: c1 = 0 → W ≡ 0
psi = _make_test_psi(:spin_wave)
compute_v4_mult_F1!(W, psi, k_vecs, 0.0)
test_1_ok = maximum(abs, W) < 1e-15
@printf("[1] c₁ = 0 limit:           max|W| = %.2e   %s\n",
    maximum(abs, W), test_1_ok ? "✓ PASS" : "✗ FAIL")

# Test 2: const FM (uniform ⟨F⟩) → W ≡ 0
psi = _make_test_psi(:const_fm)
compute_v4_mult_F1!(W, psi, k_vecs, 1.0)
test_2_ok = maximum(abs, W) < 1e-10
@printf("[2] Constant m̄ limit:       max|W| = %.2e   %s\n",
    maximum(abs, W), test_2_ok ? "✓ PASS" : "✗ FAIL")

# Test 3: polar state (uniform ⟨F⟩ = 0) → W ≡ 0
psi = _make_test_psi(:polar)
compute_v4_mult_F1!(W, psi, k_vecs, 1.0)
test_3_ok = maximum(abs, W) < 1e-10
@printf("[3] Polar (⟨F⟩=0) limit:    max|W| = %.2e   %s\n",
    maximum(abs, W), test_3_ok ? "✓ PASS" : "✗ FAIL")

# Test 4: spin wave (non-trivial ⟨F⟩(r)) → W ≠ 0
# Threshold: >> machine precision, accounting for normalization
# (|ψ|² ~ 1/N³, m ~ |ψ|², ∇²m ~ k²m → W ~ c1² m·∇²m ~ 1e-8 expected magnitude)
psi = _make_test_psi(:spin_wave)
compute_v4_mult_F1!(W, psi, k_vecs, 1.0)
test_4_ok = maximum(abs, W) > 1e-10
@printf("[4] Spin-wave (non-trivial): max|W| = %.4e   %s\n",
    maximum(abs, W), test_4_ok ? "✓ PASS (W generated)" : "✗ FAIL")

# Test 5: Symmetry structure of W = W_(i) + W_(iii)
#   Term (i):   -i/2 c_1² F_ρ (m × ∇²m)_ρ      ← anti-Hermitian alone
#   Term (iii): -1/2 c_1² {F_μ,F_ν}(∇m_μ∇m_ν)  ← Hermitian alone
# Full [V,[T,V]] (with (ii)) is Hermitian; the imaginary "anti-Hermitian"
# part of mult-only W is canceled by the boundary/IBP of term (ii)·∇ψ.
# Step 1a verifies BOTH parts have non-zero contributions.
function _split_herm_antiherm(W::Array{ComplexF64, 5})
    h_max = 0.0
    ah_max = 0.0
    @inbounds for I in CartesianIndices((size(W, 1), size(W, 2), size(W, 3)))
        for a in 1:D, b in a:D
            Wab = W[I, a, b]
            Wba = W[I, b, a]
            h_part = 0.5 * (Wab + conj(Wba))   # Hermitian
            ah_part = 0.5 * (Wab - conj(Wba))  # anti-Hermitian
            h_max = max(h_max, abs(h_part))
            ah_max = max(ah_max, abs(ah_part))
        end
    end
    (h_max, ah_max)
end
h_max, ah_max = _split_herm_antiherm(W)
# Expect both nonzero (term (iii) ↔ Hermitian, term (i) ↔ anti-Hermitian)
test_5_ok = h_max > 1e-12 && ah_max > 1e-12
@printf("[5] Symmetry structure (Step 1a): herm=%.2e, anti-herm=%.2e   %s\n",
    h_max, ah_max, test_5_ok ? "✓ PASS (both nonzero)" : "✗ FAIL")
@printf("    Note: full [V,[T,V]] becomes Hermitian only after Step 1b adds term (ii)\n")

# Test 6: c₁² scaling (W ∝ c_1²)
W1 = copy(W)
psi = _make_test_psi(:spin_wave)
compute_v4_mult_F1!(W, psi, k_vecs, 2.0)
ratio_observed = maximum(abs, W) / maximum(abs, W1)
ratio_expected = 4.0  # c_1 → 2c_1, c_1² → 4 c_1²
test_6_ok = abs(ratio_observed - ratio_expected) < 0.01
@printf("[6] c₁² scaling (c₁: 1 → 2): ratio = %.3f (expect 4.000)   %s\n",
    ratio_observed, test_6_ok ? "✓ PASS" : "✗ FAIL")

# Test 7: Round-trip palindromic check
# For Step 1a (mult only), the substep ψ ← exp(-i dt² c W) ψ should satisfy
# substep(dt) · substep(-dt) · ψ ≈ ψ (= dt² coefficient sign-flip symmetry).
# We test the operator W is dt-independent (which it is by construction).
# True palindromic test requires Step 1b (deriv term) too — defer to that step.
@printf("[7] Round-trip palindromic: DEFERRED to Step 1b (full ∇ψ included)\n")

# Summary
all_pass = test_1_ok && test_2_ok && test_3_ok && test_4_ok && test_5_ok && test_6_ok
@printf("\n%s\n", "═"^60)
@printf("Step 1a verdict: %d/6 explicit tests, palindromic deferred to 1b\n",
    sum([test_1_ok, test_2_ok, test_3_ok, test_4_ok, test_5_ok, test_6_ok]))
if all_pass
    @printf("✓ ALL PASS — Step 1a kernel OK, proceed to Step 1b (∇ψ deriv term)\n")
else
    @printf("✗ SOME FAIL — debug kernel before Step 1b\n")
end
@printf("%s\n", "═"^60)
