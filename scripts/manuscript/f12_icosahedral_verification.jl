# F=12 icosahedral inert state: Universal Structure Theorem predictive test.
#
# Goal: verify paper3 main.md §IX.B Sign Pattern Systematic conjecture
# (S_bd ≈ 2F) at F=12 (where S_max = 2F = 24 channels available).
#
# Steps:
#   1. Build F=12 spin matrices Fx, Fy, Fz (25×25)
#   2. Build Wigner D matrix for rotations (eigendecomp of F_axis)
#   3. Generate icosahedral group I (60 elements) via closure of {C5z, C3}
#   4. Project onto I:A trivial irrep → I-invariant ζ
#   5. Verify ⟨F²⟩ = 156 (= F(F+1)) and Schur isotropy
#   6. For each g_S (S = 0,2,...,24), compute c0 and λspin via mean-field
#      + Goldstone theorem (no full BdG required)
#   7. Tabulate β_S^{λ_spin} sign pattern → confirm/falsify S_bd ≈ 2F = 24
#
# Run: julia --project=. scripts/manuscript/f12_icosahedral_verification.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 12
const D = 2F + 1   # 25
const Smax = 2F    # 24

# -- spin matrices for arbitrary F --
function spin_matrices_general(F::Int)
    D = 2F + 1
    Fz = Diagonal(ComplexF64[F - i for i in 0:D-1])
    Fp = zeros(ComplexF64, D, D)
    for i in 1:(D-1)
        m = F - i
        Fp[i, i+1] = sqrt(F * (F + 1) - m * (m + 1))
    end
    Fm = Fp'
    Fx = (Fp + Fm) / 2
    Fy = (Fp - Fm) / (2im)
    return Matrix(Fx), Matrix(Fy), Matrix(Fz)
end

# -- Wigner D matrix via eigendecomposition of F·n̂ --
function wigner_D(F::Int, axis::Vector{Float64}, angle::Float64)
    Fx, Fy, Fz = spin_matrices_general(F)
    Fn = axis[1] * Fx + axis[2] * Fy + axis[3] * Fz
    Fn = (Fn + Fn') / 2  # numerical Hermiticity
    ev = eigen(Fn)
    return ev.vectors * Diagonal(exp.(-1im * angle .* ev.values)) * ev.vectors'
end

# -- group closure via BFS --
function group_close(generators::Vector{<:AbstractMatrix}, tol::Float64=1e-7, max_size::Int=200)
    G = [Matrix{ComplexF64}(I, size(generators[1])...)]
    changed = true
    while changed && length(G) < max_size
        changed = false
        for g in copy(G)
            for h in generators
                gh = g * h
                already_present = any(norm(gh - x) < tol for x in G)
                if !already_present
                    push!(G, gh)
                    changed = true
                end
            end
        end
    end
    return G
end

@printf("=== F=12 Icosahedral Universal Theorem verification ===\n")
@printf("F = %d, D = %d, S_max = %d\n\n", F, D, Smax)

# -- Step 1: spin matrices --
Fx, Fy, Fz = spin_matrices_general(F)
@printf("Built F_a matrices (D=%d).\n", D)

# -- Step 2-3: generate icosahedral group I (60 elements) --
# 5-fold axis along z (vertex at z=1).
# Adjacent 3-fold axis = centroid of upper-ring triangle containing top vertex.
#   tilt = arccos((1+φ)/√(3(1+φ²))) ≈ 37.38° from z
#   azimuth = π/5 (= 36°, halfway between two upper-ring vertices)
phi_gold = (1 + sqrt(5)) / 2
theta_3fold = acos((1 + phi_gold) / sqrt(3 * (1 + phi_gold^2)))
azimuth_3fold = π / 5
n_3fold = [sin(theta_3fold) * cos(azimuth_3fold),
           sin(theta_3fold) * sin(azimuth_3fold),
           cos(theta_3fold)]

C5z = wigner_D(F, [0.0, 0.0, 1.0], 2π/5)
C3  = wigner_D(F, n_3fold, 2π/3)

@printf("Generators built. Closing group...\n")
I_grp = group_close([C5z, C3], 1e-6, 150)
@printf("Group I has %d elements (expected 60).\n", length(I_grp))
if length(I_grp) != 60
    @warn "Group closure did not produce |I|=60; tilting angle or tolerance may be off."
end

# -- Step 4: project onto I:A invariant subspace --
P_A = sum(I_grp) / length(I_grp)
@printf("Projector P_A built (||P_A - P_A²|| = %.2e).\n", norm(P_A * P_A - P_A))

# Find I-invariant vector via projection of a random vector
import Random
Random.seed!(42)
v_random = randn(ComplexF64, D)
ζ = P_A * v_random
ζ_norm = norm(ζ)
@printf("Projection onto I:A: ||P_A v|| = %.4e (must be > 0 for I:A multiplicity ≥ 1)\n", ζ_norm)
if ζ_norm < 1e-8
    error("I:A subspace is empty in this projection. Group closure or axis choice may be wrong.")
end
ζ = ζ / ζ_norm

# Verify I-invariance
max_err = maximum(norm(g * ζ - ζ) for g in I_grp)
@printf("I-invariance check: max ||g·ζ - ζ|| = %.2e\n", max_err)

@printf("\nSpinor ζ (non-zero components, |ζ_m| > 1e-6):\n")
for m in F:-1:-F
    i = F - m + 1
    if abs(ζ[i]) > 1e-6
        @printf("  m = %3d: %s\n", m, ζ[i])
    end
end

# -- Step 5: verify ⟨F²⟩ = F(F+1) and Schur isotropy --
F2_exp = real(ζ' * (Fx*Fx + Fy*Fy + Fz*Fz) * ζ)
@printf("\n⟨F²⟩ = %.6f (expected %.0f = F(F+1))\n", F2_exp, F * (F+1))

# Schur isotropy: ⟨F_x² + F_y² + F_z²⟩ split into 3 equal parts
Fx2 = real(ζ' * (Fx * Fx) * ζ)
Fy2 = real(ζ' * (Fy * Fy) * ζ)
Fz2 = real(ζ' * (Fz * Fz) * ζ)
@printf("⟨F_x²⟩ = %.6f, ⟨F_y²⟩ = %.6f, ⟨F_z²⟩ = %.6f  (Schur: should all equal %.6f)\n",
    Fx2, Fy2, Fz2, F2_exp / 3)
schur_dev = max(abs(Fx2 - F2_exp/3), abs(Fy2 - F2_exp/3), abs(Fz2 - F2_exp/3))
@printf("Schur isotropy deviation: %.2e\n", schur_dev)

# Magnetization
Fx_mean = real(ζ' * Fx * ζ)
Fy_mean = real(ζ' * Fy * ζ)
Fz_mean = real(ζ' * Fz * ζ)
@printf("⟨F⟩ = (%.2e, %.2e, %.2e) [should be 0 for I-invariant state]\n",
    Fx_mean, Fy_mean, Fz_mean)

# -- Step 6: c_0 and λ_spin per g_S channel --
# Mean-field energy density (n=1, V=1):
#   ε_int[ζ] = (1/2) Σ_S g_S c̃_S[ζ]
# where c̃_S[ζ] = ⟨ζ⊗ζ | P_S | ζ⊗ζ⟩ = Σ_M |⟨S M | ζ⊗ζ⟩|²
#   ⟨S M | ζ⊗ζ⟩ = Σ_{m1+m2=M} CG(F,m1,F,m2;S,M) ζ_{m1} ζ_{m2}
#
# c_0[ζ] = (∂ε_int/∂n) / n |_{n=1} = Σ_S g_S β_S^{c0},  β_S^{c0} = c̃_S[ζ]
#
# For λ_spin: use Goldstone formula at q=0. The spin Goldstone stiffness
# from BdG matches:
#   λ_spin · ||F_a ζ||² = ⟨F_a ζ| h - μI |F_a ζ⟩ - n ⟨F_a ζ⊗ζ | P_(symm)|F_a ζ⊗ζ⟩ ...
#
# Cleaner: use the BdG-derived identity (see KU 2012 Eq.308 for polar):
#   For ζ-rotation along F_a, the spin Goldstone dispersion is
#   ω² = ε_k(ε_k + 2n·X), X = λ_spin.
#
# X can be extracted from the imaginary-time linearized response.
#
# Practical numerical approach: build the BdG matrix at small k, identify
# 3 spin Goldstones (degenerate by Schur), extract ω from numerical
# eigenvalues, solve λ_spin = (ω² - ε_k²) / (2 n ε_k).

# Build h[ζ] (HF matrix) and M[ζ] (anomalous) from CG decomposition.
#
# Two-body interaction H_int = (1/2) Σ_S g_S Σ_M |S,M⟩⟨S,M|_2
# Hartree-Fock matrix h_{m1,m1'} = ∂²ε_int/∂ζ_m1^* ∂ζ_m1' / 1
#   = Σ_S g_S Σ_M Σ_{m2,m2'} ⟨F m1, F m2|S M⟩ ⟨S M|F m1', F m2'⟩ ζ_{m2'} ζ_{m2}^*
# Anomalous M_{m1,m1'} = Σ_S g_S Σ_M Σ_{m2,m2'} ⟨F m1, F m1'|S M⟩ ⟨S M|F m2, F m2'⟩ ζ_{m2}^* ζ_{m2'}^*

function build_hf_matrices(ζ::Vector{ComplexF64}, F::Int, g_S::Dict{Int, Float64})
    D = 2F + 1
    h = zeros(ComplexF64, D, D)
    M_anom = zeros(ComplexF64, D, D)
    for S in keys(g_S)
        gS = g_S[S]
        gS == 0.0 && continue
        for M_q in -S:S
            for m1 in -F:F, m1p in -F:F
                m2 = M_q - m1
                m2p = M_q - m1p
                (-F <= m2 <= F) || continue
                (-F <= m2p <= F) || continue
                # CG(F,m1,F,m2;S,M_q)
                cg1 = clebsch_gordan(F, m1, F, m2, S, M_q)
                cg2 = clebsch_gordan(F, m1p, F, m2p, S, M_q)
                cg1 == 0.0 && continue
                cg2 == 0.0 && continue
                i1 = F - m1 + 1
                i1p = F - m1p + 1
                i2 = F - m2 + 1
                i2p = F - m2p + 1
                # h: ⟨m1|h|m1p⟩ = Σ g_S Σ_{m2,m2'} CG·CG ζ_{m2'} ζ_{m2}^*
                h[i1, i1p] += gS * cg1 * cg2 * ζ[i2p] * conj(ζ[i2])
                # Anomalous: similar but pair on same side
                M_anom[i1, i1p] += gS * cg1 * cg2 * conj(ζ[i2]) * conj(ζ[i2p])
            end
        end
    end
    return h, M_anom
end

# Compute c_0 = ⟨ζ|h|ζ⟩
function compute_c0(ζ::Vector{ComplexF64}, F::Int, g_S::Dict{Int, Float64})
    h, _ = build_hf_matrices(ζ, F, g_S)
    return real(ζ' * h * ζ)
end

# Compute λ_spin via BdG at small k with Goldstone identification.
# Goldstones: ω(ε_k) ∝ √ε_k as ε_k → 0 (Bogoliubov form).
# Gapped modes: ω(ε_k) → const > 0 as ε_k → 0.
#
# Procedure: compute BdG at two values ε_k1 < ε_k2. Goldstones have
# ω(ε_k1)/ω(ε_k2) ≈ √(ε_k1/ε_k2). Pick the 3 lowest Bogoliubov-form modes.
function compute_lambda_spin(ζ::Vector{ComplexF64}, F::Int, g_S::Dict{Int, Float64};
                              n_density::Float64=1.0)
    function bdg_eigs(ε_k)
        h, M_anom = build_hf_matrices(ζ, F, g_S)
        μ = real(ζ' * h * ζ)
        D = 2F + 1
        L = (ε_k - μ * n_density) * Matrix{ComplexF64}(I, D, D) + 2 * n_density * h
        H_BdG = [L                       n_density * M_anom;
                 -n_density * conj.(M_anom)   -conj.(L)]
        σz = Diagonal(ComplexF64[ones(D); -ones(D)])
        eigvals_BdG = eigvals(σz * H_BdG)
        ω_pos = sort(real(eigvals_BdG[real.(eigvals_BdG) .> 1e-9]))
        return ω_pos
    end
    ε1 = 0.001
    ε2 = 0.0001
    ω1 = bdg_eigs(ε1)
    ω2 = bdg_eigs(ε2)
    # For each mode index, check if ω scales as √ε_k (Bogoliubov form)
    # bogoliubov: ω² = ε(ε + 2nλ), small ε: ω ≈ √(2nλε), so ω1/ω2 ≈ √(ε1/ε2) ≈ √10 ≈ 3.16
    # gapped: ω ≈ const, ω1/ω2 ≈ 1
    # phonon excluded by picking modes 2-4 (after phonon at index 1)
    n_modes = min(length(ω1), length(ω2))
    n_modes < 4 && return NaN, ω1[1:min(5,length(ω1))]
    is_bogoliubov = falses(n_modes)
    for i in 1:n_modes
        if ω1[i] > 1e-12 && ω2[i] > 1e-12
            ratio = ω1[i] / ω2[i]
            expected_bog = sqrt(ε1 / ε2)
            if abs(ratio - expected_bog) / expected_bog < 0.1
                is_bogoliubov[i] = true
            end
        end
    end
    bog_indices = findall(is_bogoliubov)
    length(bog_indices) < 4 && return NaN, ω1[1:min(5,length(ω1))]
    # Among Bogoliubov modes, sort by λ extracted from ω² = ε(ε + 2nλ)
    λ_values = Float64[]
    for i in bog_indices
        ω = ω1[i]
        λ = (ω^2 - ε1^2) / (2 * n_density * ε1)
        push!(λ_values, λ)
    end
    sort!(λ_values)
    # Phonon has λ = c_0 (often largest), spin Goldstones are 3 with smaller λ.
    # For polyhedral inert: 3 spin GMs are degenerate by Schur.
    # Strategy: cluster λ values, pick the 3-fold cluster.
    if length(λ_values) >= 4
        # Try the 3 smallest as spin Goldstones (phonon assumed largest)
        spin_3 = λ_values[1:3]
        max_dev = (maximum(spin_3) - minimum(spin_3)) / max(abs(sum(spin_3)/3), 1e-12)
        if max_dev < 0.1  # 3 are clustered
            return sum(spin_3) / 3, ω1[1:min(5,length(ω1))]
        end
        # Try modes 2-4 (skip lowest as phonon)
        if length(λ_values) >= 5
            spin_3b = λ_values[2:4]
            max_dev_b = (maximum(spin_3b) - minimum(spin_3b)) / max(abs(sum(spin_3b)/3), 1e-12)
            if max_dev_b < 0.1
                return sum(spin_3b) / 3, ω1[1:min(5,length(ω1))]
            end
        end
    end
    return NaN, ω1[1:min(5,length(ω1))]
end

# Scalar limit: g_S = g for all S → c_0 = g, λ_spin = 0
@printf("\n--- Scalar limit test (g_S = 1 for all S = 0,2,...,%d) ---\n", Smax)
g_scalar = Dict{Int, Float64}(S => 1.0 for S in 0:2:Smax)
c0_scalar = compute_c0(ζ, F, g_scalar)
λ_scalar, ω_spec = compute_lambda_spin(ζ, F, g_scalar)
@printf("c_0 (scalar) = %.6f (expected 1.0)\n", c0_scalar)
@printf("λ_spin (scalar) = %.6e (expected 0.0)\n", λ_scalar)
@printf("BdG spectrum (lowest 5): %s\n", ω_spec)

# Per-channel β_S coefficients
@printf("\n--- Per-channel coefficients β_S ---\n")
@printf("%-4s  %-12s  %-12s  %-7s\n", "S", "β_S^{c0}", "β_S^{λspin}", "λ_sign")
β_c0 = Float64[]
β_lambda = Float64[]
for S in 0:2:Smax
    g_one = Dict{Int, Float64}(S => 1.0)
    c0_S = compute_c0(ζ, F, g_one)
    λ_S, _ = compute_lambda_spin(ζ, F, g_one)
    push!(β_c0, c0_S)
    push!(β_lambda, λ_S)
    sign_str = λ_S > 1e-8 ? "+" : (λ_S < -1e-8 ? "−" : "0")
    @printf("%-4d  %-12.6f  %-12.6e  %-7s\n", S, c0_S, λ_S, sign_str)
end

# Selection rule (β_S^{c0} ≈ 0 → excluded by I_h harmonics)
@printf("\n--- Selection rule (β_S^{c0} threshold 1e-6) ---\n")
selection_excluded = Int[]
for (S, β) in zip(0:2:Smax, β_c0)
    if abs(β) < 1e-6
        push!(selection_excluded, S)
    end
end
@printf("Excluded S channels (I_h selection): %s\n", selection_excluded)

# Sign Pattern test
@printf("\n--- Sign Pattern Systematic test (S_bd predicted ≈ 2F = %d) ---\n", 2F)
sign_changes = Int[]
for i in 2:length(β_lambda)
    if sign(β_lambda[i]) != sign(β_lambda[i-1]) && abs(β_lambda[i]) > 1e-8 && abs(β_lambda[i-1]) > 1e-8
        S_below = 2 * (i - 2)
        S_above = 2 * (i - 1)
        push!(sign_changes, S_below)
        @printf("  Sign change between S=%d (β=%.3e) and S=%d (β=%.3e)\n",
            S_below, β_lambda[i-1], S_above, β_lambda[i])
    end
end
if !isempty(sign_changes)
    S_bd_observed = sign_changes[1]
    @printf("Observed S_bd = %d, S_bd/F = %.3f (predicted ~1.5F-2F)\n",
        S_bd_observed, S_bd_observed / F)
else
    @printf("No sign change detected. Could be all-same-sign or below threshold.\n")
end

@printf("\n=== F=12 verification complete ===\n")
