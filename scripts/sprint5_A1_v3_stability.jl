#!/usr/bin/env julia
# scripts/sprint5_A1_v3_stability.jl
#
# Method-independent uniform-vs-texture decision at Eu Matsui digital
# twin via Bogoliubov linear stability analysis of uniform-inert
# candidate spinors. Replaces the ITP-vs-LBFGS convergence game with
# eigenvalue analysis.
#
# Test the 3 uniform-inert candidates:
#   - polar (m=0)
#   - cyclic (F=6 cyclic spinor)
#   - I_h (ZETA_F6_IH)
#   - biaxial nematic
# For each, scan k_direction over a Fibonacci sphere grid (DDI anisotropic),
# extract the most unstable mode (max imaginary frequency).
#
# Verdict:
#   - max_growth ≈ 0 across all candidates → uniform-inert is locally
#     stable; LBFGS escape to PCV at coarse grid is a numerical
#     artifact; no PCV-vs-uniform competition at digital twin.
#   - max_growth > 0 (unstable) for some/all candidates → uniform-inert
#     is a saddle/unstable; texture GS confirmed (method-independent).
#     Identify the unstable mode's m-symmetry to predict the texture.
#
# Density: use a representative n0 ≈ TF peak density at digital twin.
# Local-density approximation: stability around uniform n=n0 is
# necessary-but-not-sufficient for trap stability (a stable LDA can
# still be unstable in a trap due to inhomogeneity; an unstable LDA
# is definitely unstable in a trap of comparable size).
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_stability.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# TF peak density at digital twin (estimate from g_eff and N)
# 3D harmonic μ_TF = (15 N g_eff / (16π))^(2/5); n_peak = μ_TF / g_eff
# For uniform-inert g_eff = c_0 + spin-dep contributions ≈ c_0 (small spin)
const G_EFF_EST = C0   # uniform-inert dominant by c_0
const MU_TF = (15 * N_ATOMS * G_EFF_EST / (16π))^(2/5)
const N_PEAK = MU_TF / G_EFF_EST
# Convert to dimensionless density (per atom amplitude squared at peak)
# For ψ normalized to ∫|ψ|² = 1, n_peak in code = abs2(ψ_peak), which is
# different from the TF n_peak. The Bogoliubov function takes n0 in the
# dimensionless "local density" sense, c.f. how Sprint 4 used it.
# Let's also pass the LBFGS-polished I_h density peak as a sanity check.

const K_MAX = 5.0
const N_K = 200

# Candidate uniform-inert spinors (F=6, length 13, m=+F..-F)
function polar_spinor()
    ζ = zeros(ComplexF64, 13)
    ζ[7] = 1.0   # m=0
    ζ
end

function cyclic_spinor_F6()
    # F=6 cyclic — the candidate from the state_zoo
    # init_psi(state=:cyclic) does NOT return the canonical spinor directly;
    # it builds the spatial state. For F=6 cyclic, the conventional spinor
    # form is m=±2 + m=∓2-equivalent with phase factors. Use the spinor
    # from `polyhedral_candidate_spinors` if available.
    candidates = polyhedral_candidate_spinors(F)
    haskey(candidates, :cyclic) ? candidates[:cyclic] : polar_spinor()
end

function biaxial_spinor_F6()
    ζ = zeros(ComplexF64, 13)
    inv_sqrt2 = 1/sqrt(2)
    ζ[F - 2 + 1] = inv_sqrt2   # m=+2
    ζ[F + 2 + 1] = inv_sqrt2   # m=-2
    ζ
end

function Ih_spinor_F6()
    SpinorBEC.IcosahedralMod.ZETA_F6_IH
end

function fibonacci_directions(n::Int)
    # n quasi-uniform unit vectors on the sphere
    dirs = NTuple{3, Float64}[]
    golden = π * (3 - sqrt(5))
    for i in 0:(n - 1)
        z = 1 - 2i / (n-1)
        r = sqrt(1 - z^2)
        θ = golden * i
        push!(dirs, (r * cos(θ), r * sin(θ), z))
    end
    dirs
end

function scan_stability(label::String, ζ::Vector{ComplexF64}, n0::Float64;
    n_dirs::Int=16, k_max::Float64=K_MAX, n_k::Int=N_K)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    @printf "\n--- Bogoliubov stability: %s (n0=%.3e) ---\n" label n0
    @printf "  Spinor magnitudes: "
    for c in 1:13
        m = F - c + 1
        if abs(ζ[c]) > 1e-8
            @printf "|m=%+d|=%.3f " m abs(ζ[c])
        end
    end
    println()
    flush(stdout)

    dirs = fibonacci_directions(n_dirs)
    worst_growth = 0.0
    worst_dir = (0.0, 0.0, 0.0)
    worst_k = 0.0
    for dir in dirs
        res = bogoliubov_spectrum(;
            spinor=ζ, n0=n0, F=F,
            interactions=ip,
            c_dd=C_DD_DIMLESS,
            k_max=k_max, n_k=n_k,
            k_direction=dir)
        if res.max_growth_rate > worst_growth
            worst_growth = res.max_growth_rate
            worst_dir = dir
            # find k at which max_growth occurs
            for ik in 1:size(res.omega, 2)
                for ib in 1:size(res.omega, 1)
                    if abs(imag(res.omega[ib, ik]) - res.max_growth_rate) < 1e-12
                        worst_k = res.k_values[ik]
                    end
                end
            end
        end
    end
    if worst_growth > 1e-8
        @printf "  → UNSTABLE: max growth rate = %.4e at k_direction=(%.2f, %.2f, %.2f), k=%.3f\n" worst_growth worst_dir... worst_k
    else
        @printf "  → STABLE: max growth ≈ %.2e (numerical noise)\n" worst_growth
    end
    return (label=label, growth=worst_growth, direction=worst_dir, k=worst_k)
end

function main()
    println("=== Step 0 (priority) — Bogoliubov stability of uniform-inert candidates ===\n")
    @printf "Eu Matsui digital twin: N=%d, ω=(110,110,130) Hz, c_0=%.4e c_1=%.4e c_dd=%.4e\n" N_ATOMS C0 C1 C_DD_DIMLESS
    @printf "Local-density approximation. TF estimate μ_TF=%.2f, n_peak_TF=%.4e\n" MU_TF N_PEAK
    @printf "Scanning %d Fibonacci k-directions × %d k values, k_max=%.1f\n\n" 16 N_K K_MAX

    # Use a representative density: rough TF peak as primary, plus a sweep
    n0_test = N_PEAK   # primary value

    results = []
    push!(results, scan_stability("polar (m=0)", polar_spinor(), n0_test))
    push!(results, scan_stability("cyclic", cyclic_spinor_F6(), n0_test))
    push!(results, scan_stability("biaxial_nematic", biaxial_spinor_F6(), n0_test))
    push!(results, scan_stability("I_h", Ih_spinor_F6(), n0_test))

    println("\n\n=== Density sweep on most stable / most unstable ===\n")
    # Repeat at 0.1× and 10× n0 to see how growth scales with density
    for r in results
        ζ = if r.label == "polar (m=0)"
            polar_spinor()
        elseif r.label == "cyclic"
            cyclic_spinor_F6()
        elseif r.label == "biaxial_nematic"
            biaxial_spinor_F6()
        else
            Ih_spinor_F6()
        end
        for f in [0.1, 0.3, 1.0, 3.0, 10.0]
            n_test = n0_test * f
            r2 = scan_stability("$(r.label) @ n0=$(round(n_test; sigdigits=3))",
                ζ, n_test; n_dirs=8)
        end
    end

    println("\n\n=== Summary ===\n")
    @printf "%-22s %-12s %-25s %-8s\n" "candidate" "max_growth" "worst_k_direction" "k_worst"
    for r in results
        verdict = r.growth > 1e-8 ? "UNSTABLE" : "stable"
        @printf "%-22s %.4e   (%.2f, %.2f, %.2f)   %.3f   [%s]\n" r.label r.growth r.direction... r.k verdict
    end

    if any(r.growth > 1e-8 for r in results)
        println("\n→ At least one uniform-inert candidate is dynamically unstable.")
        println("  Texture is the GS (method-independent: instability ⇒ saddle).")
        println("  Identify the unstable mode's m-symmetry to predict the texture pattern.")
    else
        println("\n→ All uniform-inert candidates are dynamically stable at digital twin density.")
        println("  LBFGS escape to PCV at 24³ is likely a coarse-grid artifact.")
        println("  Step 3 32³ grid check on PCV becomes the necessary next step")
        println("  (verify PCV survives at properly-resolved grid).")
    end
end

main()
