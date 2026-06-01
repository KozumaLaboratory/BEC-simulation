#!/usr/bin/env julia
# scripts/fisher_sprint4_aS_basis_transform.jl
#
# Translates the Item A Fisher precision in {c_n} basis into the physical
# {a_S} (scattering length per S channel) basis that the experiment / lab
# literature speaks. For F=6 ¹⁵¹Eu there are 7 even-S channels
# (S = 0, 2, 4, 6, 8, 10, 12); a_12 is fixed at 110 a_B by the polarised-pair
# measurement; the other 6 are unknown.
#
# Transformation:
#   g_S(c) = c_0 + c_1·λ_S + Σ_{k ∈ {2,4,6}} (2k+1)·{F F k; F F S}·c_k
#           where λ_S = (S(S+1) - 2F(F+1))/2
# This is realised by the codebase's `c_to_g(F, InteractionParams)`.
#
# Jacobian M[S, n] = ∂g_S/∂c_n is computed by central FD on c_to_g; the
# covariance pushes as Cov_g = M · Cov_c · M^T (5 free c → 7 g_S).
#
# Run:   julia --project=. scripts/fisher_sprint4_aS_basis_transform.jl
# Expected wall-clock: < 1 second (pure linear algebra, uses Item A Fisher
# as fixed input).

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]
const S_VALUES = collect(0:2:(2 * F))
const A_BOHR = 5.29177210903e-11   # m
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))

# Item A polar Bogoliubov Fisher matrix in {c_0, c_1, c_2, c_4, c_6} basis.
# Reconstructed from the eigendecomposition reported in
# scripts/fisher_sprint4_itemA_bogoliubov.jl. Eigenvalues + eigenvectors:
const ITEM_A_EIGVALS = [93.9, 2740.0, 12400.0, 15300.0, 5.4e7]
const ITEM_A_EIGVECS = [
    1.000 -0.003 -0.011 +0.012 +0.008
    0.008 -0.001 +0.002 +0.000 -1.000
    0.017 +0.385 +0.651 -0.654 +0.001
    0.004 -0.899 +0.103 -0.426 +0.001
    0.000 -0.210 +0.752 +0.625 +0.002
]

"""Re-assemble the Fisher matrix from its eigendecomposition."""
function fisher_from_eigen(evals, evecs)
    Symmetric(evecs * Diagonal(evals) * evecs')
end

"""Jacobian M[S_idx, c_idx] = ∂g_S / ∂c_n via FD on c_to_g."""
function compute_jacobian_c_to_g(c_nominal::Vector{Float64})
    n_c = length(c_nominal)
    n_S = length(S_VALUES)
    M = zeros(Float64, n_S, n_c)
    δ = 1e-3
    for j in 1:n_c
        c_plus = copy(c_nominal);
        c_plus[j] += δ
        c_minus = copy(c_nominal);
        c_minus[j] -= δ
        c_keys = [0, 1, 2, 4, 6]
        ip_p = InteractionParams(Dict{Int, Float64}(c_keys[k] => c_plus[k]
                                                    for k in 1:n_c))
        ip_m = InteractionParams(Dict{Int, Float64}(c_keys[k] => c_minus[k]
                                                    for k in 1:n_c))
        g_p = SpinorBEC.c_to_g(F, ip_p)
        g_m = SpinorBEC.c_to_g(F, ip_m)
        for (i, S) in enumerate(S_VALUES)
            M[i, j] = (g_p[S] - g_m[S]) / (2δ)
        end
    end
    M
end

function main()
    println("=== a_S basis transform of Item A Fisher ===")
    @printf "Atom: %s, N=%d, a_ho = %.3e m\n" ATOM.name N_ATOMS A_HO
    println("Channels: S = $S_VALUES")
    println()

    # Reconstruct Item A Fisher matrix
    I_c = fisher_from_eigen(ITEM_A_EIGVALS, ITEM_A_EIGVECS)
    println("Item A Fisher (in c_n basis), eigvals:")
    for (i, λ) in enumerate(ITEM_A_EIGVALS)
        @printf "  λ_%d = %.3e (σ_c = %.3e)\n" i λ (1 / sqrt(λ))
    end
    println()

    # c_nominal for Jacobian evaluation
    C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
    c0 = C_TOTAL / (1 + F^2 / 36.0)
    c1 = c0 / 36.0
    c_nominal = [c0, c1, 0.05 * c0, 0.02 * c0, 0.005 * c0]
    @printf "c_nominal = (%.3e, %.3e, %.3e, %.3e, %.3e)\n" c_nominal...
    println()

    M = compute_jacobian_c_to_g(c_nominal)
    println("Jacobian M[S, c_n] = ∂g_S/∂c_n (rows S=0,2,...,12, cols c_0,c_1,c_2,c_4,c_6):")
    for (i, S) in enumerate(S_VALUES)
        row = M[i, :]
        @printf "  g_S=%2d :  %+.3e  %+.3e  %+.3e  %+.3e  %+.3e\n" S row[1] row[2] row[3] row[4] row[5]
    end
    println()

    # Covariance transforms: Cov_g = M · Cov_c · M^T
    # Cov_c = I_c^{-1} (in c-basis), 5×5
    Cov_c = inv(Matrix(I_c))
    Cov_g = M * Cov_c * M'

    println("Per-channel g_S precision σ_g = √diag(Cov_g):")
    for (i, S) in enumerate(S_VALUES)
        σg = sqrt(max(Cov_g[i, i], 0))
        @printf "  σ(g_%2d) = %.3e (dimensionless)\n" S σg
    end
    println()

    # Convert g_S → a_S: a_S = g_S · M_red / (4π · ℏ²) · ?  in dimensionless units
    # In dimensionless (ω_ref=ℏ=m=1, a_ho units), a_S = g_S × a_ho / (4π · N)
    # so σ(a_S) [in a_ho units] = σ(g_S) × a_ho / (4π · N) [dimensionless]
    # And in a_B: σ(a_S)[a_B] = σ(a_S)[a_ho] × a_ho/a_B
    println("Per-channel a_S precision (in a_Bohr units):")
    @printf "%5s  %-16s  %-16s\n" "S" "σ(a_S) (a_B)" "comparison"
    println("  " * "-"^40)
    for (i, S) in enumerate(S_VALUES)
        σg = sqrt(max(Cov_g[i, i], 0))
        # a_S[a_ho] = g_S / (4π · N)
        σa_ho = σg / (4π * N_ATOMS)
        σa_B = σa_ho * A_HO / A_BOHR
        marker = if S == 2F
            "← a_12 = 110 a_B (prior-fixed; ignore Bogoliubov σ)"
        elseif σa_B < 5.0
            "← excellent precision"
        elseif σa_B < 50.0
            "← lab-relevant precision"
        else
            ""
        end
        @printf "  %2d  %.3e         %s\n" S σa_B marker
    end
    println()

    println("--- Interpretation ---")
    println("Item A Bogoliubov spectroscopy translates to per-channel a_S precision")
    println("(F=6 Eu has 6 unknown a_S; a_12=110 a_B is the prior-fixed one).")
    println("This is the experimentally-actionable precision: what the lab gets if")
    println("they execute the Item A protocol (polar GS pinned by q<0 + collective")
    println("mode spectroscopy at k≈0.5 ω_ref ω_ref⁻¹·a_ho).")
    println()
    println("=== Done ===")
end

main()
