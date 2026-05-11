# Track C v4 Step 1b smoke — derivative term (ii) + full Hermiticity check.
#
# From docs/design/integrator_track_c_derivation.md §5.2:
#
#   [V_SM, [T, V_SM]] = c_1² [
#     (i)   -i/2 F_ρ (m × ∇²m)_ρ            ← multiplicative (anti-Hermitian alone)
#     (ii)  -i F_ρ (m × ∇m)_ρ · ∇           ← derivative on ∇ψ (NEW)
#     (iii) -1/2 {F_μ, F_ν}(∇m_μ)(∇m_ν)    ← multiplicative (Hermitian alone)
#   ]
#
# Step 1a verified (i)+(iii) limits + structure. Step 1b adds (ii) and verifies
# the COMBINED operator A = (i)+(ii)+(iii) is Hermitian via ⟨φ, Aψ⟩ = ⟨Aφ, ψ⟩.
#
# Gate: Hermiticity violation / |Aψ| < 1e-10 → proceed to Step 1c.
#
# Run: julia --project=. scripts/bench/track_c_v4_step1b_smoke.jl

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

# ----- Field utilities (re-used from Step 1a) -----

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

function gradient_spectral(m::Array{Float64, 4}, k_vecs::NTuple{3, Vector{Float64}})
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
                kc = (ax == 1) ? k[I[1]] : (ax == 2) ? k[I[2]] : k[I[3]]
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
Compute (∂_α ψ_β)(r) for each axis α and component β via FFT spectral.
Output: [r, axis, comp] complex array (Nx, Ny, Nz, 3, D).
"""
function gradient_psi_spectral(psi::Array{ComplexF64, 4}, k_vecs::NTuple{3, Vector{Float64}})
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
                kc = (ax == 1) ? k[I[1]] : (ax == 2) ? k[I[2]] : k[I[3]]
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

# ----- Step 1a multiplicative kernel (Hermitian + anti-Hermitian pieces) -----

function compute_v4_mult_F1!(
    W::Array{ComplexF64, 5},
    psi::Array{ComplexF64, 4},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
)
    n_pts = size(psi)[1:3]
    fill!(W, zero(ComplexF64))
    abs(c1) < 1e-30 && return W

    m = spin_density_field(psi, n_pts)
    grad_m = gradient_spectral(m, k_vecs)
    lap_m = laplacian_spectral(m, k_vecs)
    c1_sq = c1^2

    @inbounds for I in CartesianIndices(n_pts)
        m_vec = (m[I, 1], m[I, 2], m[I, 3])
        lap_vec = (lap_m[I, 1], lap_m[I, 2], lap_m[I, 3])
        cross_i = (
            m_vec[2] * lap_vec[3] - m_vec[3] * lap_vec[2],
            m_vec[3] * lap_vec[1] - m_vec[1] * lap_vec[3],
            m_vec[1] * lap_vec[2] - m_vec[2] * lap_vec[1],
        )
        for a in 1:D, b in 1:D
            val_i = ComplexF64(0)
            for ρ in 1:3
                val_i += cross_i[ρ] * F_MATS[ρ][a, b]
            end
            val_i *= -im / 2 * c1_sq

            val_iii = ComplexF64(0)
            for μ in 1:3, ν in 1:3
                anticomm_ab = (F_MATS[μ] * F_MATS[ν] + F_MATS[ν] * F_MATS[μ])[a, b]
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

# ----- Step 1b: derivative term (ii) -----

"""
Apply v4 derivative term (ii): out += -i c₁² F_ρ (m × ∇m)_ρ · ∇ψ.

(m × ∇m)_ρ_axis_α = ε_ρμν m_μ ∂_α m_ν is a 3-vector indexed by spatial axis α.
Term acts as: out[r, a] += -i c₁² Σ_ρ Σ_b Σ_α F_ρ[a,b] · (m×∇m)_ρ_α(r) · (∂_α ψ_b)(r).
"""
function apply_v4_term_ii_F1!(
    out::Array{ComplexF64, 4},
    psi::Array{ComplexF64, 4},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
)
    n_pts = size(psi)[1:3]
    @assert size(out) == size(psi)
    abs(c1) < 1e-30 && return out

    m = spin_density_field(psi, n_pts)
    grad_m = gradient_spectral(m, k_vecs)        # [r, axis, μ]
    grad_psi = gradient_psi_spectral(psi, k_vecs) # [r, axis, β]
    c1_sq = c1^2

    # Precompute (m × ∇m)_ρ_axis_α at each point: [r, axis, ρ]
    cross_mgm = zeros(Float64, n_pts..., 3, 3)
    @inbounds for I in CartesianIndices(n_pts)
        for ax in 1:3
            gx = (grad_m[I, ax, 1], grad_m[I, ax, 2], grad_m[I, ax, 3])
            mvec = (m[I, 1], m[I, 2], m[I, 3])
            cross_mgm[I, ax, 1] = mvec[2] * gx[3] - mvec[3] * gx[2]
            cross_mgm[I, ax, 2] = mvec[3] * gx[1] - mvec[1] * gx[3]
            cross_mgm[I, ax, 3] = mvec[1] * gx[2] - mvec[2] * gx[1]
        end
    end

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
            out[I, a] += -im * c1_sq * val
        end
    end
    out
end

"""
Apply FULL operator A = (i) + (ii) + (iii) to ψ.
A is matrix-form (i)+(iii) plus derivative-form (ii), Hermitian as combined operator.
"""
function apply_v4_full_F1!(
    out::Array{ComplexF64, 4},
    psi::Array{ComplexF64, 4},
    W_buf::Array{ComplexF64, 5},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
)
    n_pts = size(psi)[1:3]
    fill!(out, zero(ComplexF64))
    abs(c1) < 1e-30 && return out

    # Multiplicative (i)+(iii)
    compute_v4_mult_F1!(W_buf, psi, k_vecs, c1)
    @inbounds for I in CartesianIndices(n_pts)
        for a in 1:D
            val = ComplexF64(0)
            for b in 1:D
                val += W_buf[I, a, b] * psi[I, b]
            end
            out[I, a] = val
        end
    end
    # Derivative (ii)
    apply_v4_term_ii_F1!(out, psi, k_vecs, c1)
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
    # Smooth via low-pass to make ∇ well-defined
    psi ./= sqrt(sum(abs2, psi))
    psi
end

# ----- Tests -----

@printf("=== Track C v4 Step 1b smoke (F=1, %d³, full (i)+(ii)+(iii)) ===\n", N)

k_vecs = _make_k_vecs()
W = zeros(ComplexF64, N, N, N, D, D)
out = zeros(ComplexF64, N, N, N, D)

# Test 1: c₁ = 0 → out ≡ 0
psi_sw = _make_psi_spin_wave()
apply_v4_full_F1!(out, psi_sw, W, k_vecs, 0.0)
test_1_ok = maximum(abs, out) < 1e-15
@printf("[1] c₁ = 0:                max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_1_ok ? "✓ PASS" : "✗ FAIL")

# Test 2: const FM → ∇m=0, ∇²m=0 → out=0
psi_fm = _make_psi_const_fm()
apply_v4_full_F1!(out, psi_fm, W, k_vecs, 1.0)
test_2_ok = maximum(abs, out) < 1e-10
@printf("[2] Constant FM:           max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_2_ok ? "✓ PASS" : "✗ FAIL")

# Test 3: polar (⟨F⟩=0) → m=0 → out=0
psi_p = _make_psi_polar()
apply_v4_full_F1!(out, psi_p, W, k_vecs, 1.0)
test_3_ok = maximum(abs, out) < 1e-10
@printf("[3] Polar ⟨F⟩=0:           max|Aψ| = %.2e   %s\n",
    maximum(abs, out), test_3_ok ? "✓ PASS" : "✗ FAIL")

# Test 4: spin-wave → out ≠ 0
apply_v4_full_F1!(out, psi_sw, W, k_vecs, 1.0)
test_4_ok = maximum(abs, out) > 1e-10
@printf("[4] Spin-wave non-trivial: max|Aψ| = %.4e   %s\n",
    maximum(abs, out), test_4_ok ? "✓ PASS" : "✗ FAIL")

# Test 5: Hermiticity ⟨φ, Aψ⟩ = ⟨Aφ, ψ⟩
# A is real-linear in ψ but it depends on m(ψ), grad_m(ψ), grad_psi(ψ).
# CRITICAL: m, grad_m depend QUADRATICALLY on ψ — so A as defined here is a
# functional A[ψ] not a linear operator. For the Hermiticity check we must
# fix the "background" m(r) from a reference state and apply A_m as a linear
# operator on test wavefunctions.
function apply_v4_full_linearized_F1!(
    out::Array{ComplexF64, 4},
    psi_test::Array{ComplexF64, 4},
    m_bg::Array{Float64, 4},
    grad_m_bg::Array{Float64, 5},
    lap_m_bg::Array{Float64, 4},
    cross_mlapm_bg::Array{Float64, 4},
    cross_mgm_bg::Array{Float64, 5},
    k_vecs::NTuple{3, Vector{Float64}},
    c1::Float64,
)
    n_pts = size(psi_test)[1:3]
    fill!(out, zero(ComplexF64))
    abs(c1) < 1e-30 && return out
    c1_sq = c1^2

    # W_mult from background fields
    W_loc = zeros(ComplexF64, D, D)
    @inbounds for I in CartesianIndices(n_pts)
        # Term (i): cross_mlapm_bg precomputed
        # Term (iii): anticomm sums
        fill!(W_loc, zero(ComplexF64))
        for a in 1:D, b in 1:D
            v_i = ComplexF64(0)
            for ρ in 1:3
                v_i += cross_mlapm_bg[I, ρ] * F_MATS[ρ][a, b]
            end
            v_i *= -im / 2 * c1_sq

            v_iii = ComplexF64(0)
            for μ in 1:3, ν in 1:3
                anticomm_ab = (F_MATS[μ] * F_MATS[ν] + F_MATS[ν] * F_MATS[μ])[a, b]
                gd = 0.0
                for ax in 1:3
                    gd += grad_m_bg[I, ax, μ] * grad_m_bg[I, ax, ν]
                end
                v_iii += anticomm_ab * gd
            end
            v_iii *= -0.5 * c1_sq

            W_loc[a, b] = v_i + v_iii
        end
        for a in 1:D
            val = ComplexF64(0)
            for b in 1:D
                val += W_loc[a, b] * psi_test[I, b]
            end
            out[I, a] = val
        end
    end

    # (ii) derivative on test wavefunction with background (m × ∇m)
    grad_psi_t = gradient_psi_spectral(psi_test, k_vecs)
    @inbounds for I in CartesianIndices(n_pts)
        for a in 1:D
            val = ComplexF64(0)
            for ρ in 1:3, ax in 1:3
                coef = cross_mgm_bg[I, ax, ρ]
                if coef != 0
                    for b in 1:D
                        val += F_MATS[ρ][a, b] * coef * grad_psi_t[I, ax, b]
                    end
                end
            end
            out[I, a] += -im * c1_sq * val
        end
    end
    out
end

# Build background from a fixed state
psi_bg = _make_psi_spin_wave()
n_pts = (N, N, N)
m_bg = spin_density_field(psi_bg, n_pts)
grad_m_bg = gradient_spectral(m_bg, k_vecs)
lap_m_bg = laplacian_spectral(m_bg, k_vecs)
cross_mlapm_bg = zeros(Float64, n_pts..., 3)
@inbounds for I in CartesianIndices(n_pts)
    mv = (m_bg[I, 1], m_bg[I, 2], m_bg[I, 3])
    lv = (lap_m_bg[I, 1], lap_m_bg[I, 2], lap_m_bg[I, 3])
    cross_mlapm_bg[I, 1] = mv[2] * lv[3] - mv[3] * lv[2]
    cross_mlapm_bg[I, 2] = mv[3] * lv[1] - mv[1] * lv[3]
    cross_mlapm_bg[I, 3] = mv[1] * lv[2] - mv[2] * lv[1]
end
cross_mgm_bg = zeros(Float64, n_pts..., 3, 3)
@inbounds for I in CartesianIndices(n_pts)
    for ax in 1:3
        gx = (grad_m_bg[I, ax, 1], grad_m_bg[I, ax, 2], grad_m_bg[I, ax, 3])
        mv = (m_bg[I, 1], m_bg[I, 2], m_bg[I, 3])
        cross_mgm_bg[I, ax, 1] = mv[2] * gx[3] - mv[3] * gx[2]
        cross_mgm_bg[I, ax, 2] = mv[3] * gx[1] - mv[1] * gx[3]
        cross_mgm_bg[I, ax, 3] = mv[1] * gx[2] - mv[2] * gx[1]
    end
end

# Test 5: random test vectors φ, ψ → check ⟨φ, A_bg ψ⟩ = ⟨A_bg φ, ψ⟩
psi_test = _make_psi_random(42)
phi_test = _make_psi_random(99)
A_psi = zeros(ComplexF64, N, N, N, D)
A_phi = zeros(ComplexF64, N, N, N, D)
apply_v4_full_linearized_F1!(A_psi, psi_test, m_bg, grad_m_bg, lap_m_bg,
    cross_mlapm_bg, cross_mgm_bg, k_vecs, 1.0)
apply_v4_full_linearized_F1!(A_phi, phi_test, m_bg, grad_m_bg, lap_m_bg,
    cross_mlapm_bg, cross_mgm_bg, k_vecs, 1.0)

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
    herm_rel, test_5_ok ? "✓ PASS — A is Hermitian" : "✗ FAIL — anti-Herm part remains")

# Test 6: Hermiticity at c₁=2 (scaling check)
A_psi2 = zeros(ComplexF64, N, N, N, D)
A_phi2 = zeros(ComplexF64, N, N, N, D)
apply_v4_full_linearized_F1!(A_psi2, psi_test, m_bg, grad_m_bg, lap_m_bg,
    cross_mlapm_bg, cross_mgm_bg, k_vecs, 2.0)
apply_v4_full_linearized_F1!(A_phi2, phi_test, m_bg, grad_m_bg, lap_m_bg,
    cross_mlapm_bg, cross_mgm_bg, k_vecs, 2.0)
lhs2 = sum(conj(phi_test[I, c]) * A_psi2[I, c]
    for I in CartesianIndices(n_pts), c in 1:D)
rhs2 = sum(conj(A_phi2[I, c]) * psi_test[I, c]
    for I in CartesianIndices(n_pts), c in 1:D)
herm_dev2 = abs(lhs2 - rhs2)
herm_rel2 = herm_dev2 / max(abs(lhs2), 1e-30)
ratio_scale = abs(lhs2) / max(abs(lhs), 1e-30)
test_6_ok = herm_rel2 < 1e-10 && abs(ratio_scale - 4.0) < 0.01
@printf("[6] Hermiticity@c₁=2 + c₁² scale: dev=%.3e, scale_ratio=%.3f (expect 4.0)   %s\n",
    herm_rel2, ratio_scale, test_6_ok ? "✓ PASS" : "✗ FAIL")

# Test 7: Self-application check (Aψ ≠ 0 for spin-wave state itself)
apply_v4_full_F1!(out, psi_sw, W, k_vecs, 1.0)
test_7_ok = maximum(abs, out) > 1e-12
@printf("[7] Full A on actual ψ_SW: max|Aψ_SW| = %.4e   %s\n",
    maximum(abs, out), test_7_ok ? "✓ PASS" : "✗ FAIL")

# Summary
all_pass = test_1_ok && test_2_ok && test_3_ok && test_4_ok && test_5_ok && test_6_ok && test_7_ok
@printf("\n%s\n", "═"^60)
@printf("Step 1b verdict: %d/7 tests pass\n",
    sum([test_1_ok, test_2_ok, test_3_ok, test_4_ok, test_5_ok, test_6_ok, test_7_ok]))
if all_pass
    @printf("✓ ALL PASS — (i)+(ii)+(iii) is Hermitian, proceed to Step 1c\n")
    @printf("           (integrate into split_step_forcegrad_v4! in src/)\n")
else
    @printf("✗ SOME FAIL — debug term (ii) before Step 1c\n")
end
@printf("%s\n", "═"^60)
