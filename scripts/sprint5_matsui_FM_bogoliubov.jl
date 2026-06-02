#!/usr/bin/env julia
# scripts/sprint5_matsui_FM_bogoliubov.jl
#
# Bogoliubov stability of the m=-F (FM polarized) state at Matsui digital
# twin parameters. This is the LINEAR theory of Matsui's EdH cascade
# initial-state dynamics: starting from m=-6 fully polarized, which
# Bogoliubov modes are unstable, and what m-channels do they grow into?
#
# Compare predicted unstable mode m-content to Matsui's measured m=-5/-4
# cascade population — direct experimental validation of digital twin.
#
# Parameters: Matsui digital twin (N=5×10⁴, aspect 1.1818, dynamics B_z = 2.6 nT).
# Use the local-density approximation at TF peak density.
#
# Run: julia --project=. scripts/sprint5_matsui_FM_bogoliubov.jl

using SpinorBEC
using LinearAlgebra
using Printf

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const F = TW.F          # convenience local binding (preserves original symbol)
const D = TW.D

# Matsui dynamics Bz = 2.6 nT = 2.6e-5 Gauss = 2.6e-9 T
# Zeeman p = g_F μ_B B in Hz, then dimensionless by ω_ref
const G_F_EU = 1.163
const MU_B_HZ_PER_T = 1.3996e10   # Bohr magneton in Hz/T
const BZ_DYNAMICS_T = 2.6e-9
const P_HZ = G_F_EU * MU_B_HZ_PER_T * BZ_DYNAMICS_T   # Hz per m
const P_DIMLESS = P_HZ * 2π / TW.omega_ref             # ω/ω_ref
const Q_DIMLESS = 0.0                                   # neglect quadratic Zeeman for now

# TF peak density estimate
const G_EFF = TW.c0
const MU_TF = (15 * TW.n_atoms * G_EFF / (16π))^(2/5)
const N_PEAK = MU_TF / G_EFF

# m=-F state: ζ_m = δ_{m,-F}
function mF_spinor()
    ζ = zeros(ComplexF64, D)
    ζ[D] = 1.0   # c=D corresponds to m=-F
    ζ
end

function fibonacci_directions(n::Int)
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

function bdg_at_dir(ζ, n0, ip, zee, c_dd, k_dir, k_max, n_k)
    # Direct call to bogoliubov_spectrum + extract eigenvectors at k where growth is max
    res = bogoliubov_spectrum(;
        spinor=ζ, n0=n0, F=F, interactions=ip,
        zeeman=zee, c_dd=c_dd,
        k_max=k_max, n_k=n_k, k_direction=k_dir)
    res
end

function extract_mode_at_max_growth(ζ, n0, ip, zee, c_dd, k_dir, k_val)
    # Build BdG manually at given (k_dir, k_val), diagonalize, return imag eigenvector
    h_mf, M_anom, zee_vec, _ = SpinorBEC._bdg_contact_matrices(ζ, F, ip, zee)
    sm = spin_matrices(F)
    Q_ab = SpinorBEC._q_tensor_direction(collect(k_dir))
    h_ddi, M_ddi = SpinorBEC._bdg_ddi_matrices(ζ, F, D, sm, c_dd, Q_ab)
    h_mf .+= h_ddi
    M_anom .+= M_ddi
    H_mu = Diagonal(zee_vec) .+ n0 .* h_mf
    mu = real(dot(ζ, H_mu * ζ))
    ek = k_val^2 / 2
    L = 2n0 .* h_mf
    for i in 1:D
        L[i, i] += ek - mu + zee_vec[i]
    end
    M_sc = n0 .* M_anom
    H_bdg = zeros(ComplexF64, 2D, 2D)
    H_bdg[1:D, 1:D] .= L
    H_bdg[1:D, (D + 1):2D] .= M_sc
    H_bdg[(D + 1):2D, 1:D] .= .-conj.(M_sc)
    H_bdg[(D + 1):2D, (D + 1):2D] .= .-conj.(L)
    evals, evecs = eigen(H_bdg)
    worst_idx = argmax([abs(imag(ev)) for ev in evals])
    return evals[worst_idx], evecs[:, worst_idx]
end

function scan_m_minus_F(label::String, zee::ZeemanParams; n_dirs::Int=32, n_k::Int=200)
    ζ = mF_spinor()
    ip = TW.interactions
    @printf "\n--- m=-F FM stability: %s ---\n" label
    @printf "  Zeeman p = %.4f (=%.1f Hz), q = %.4f (=%.1f Hz)\n" zee.p (zee.p * TW.omega_ref / (2π)) zee.q (
        zee.q * TW.omega_ref / (2π)
    )
    @printf "  n0 (TF peak) = %.4f, c_0·n0 = %.1f, c_1·n0 = %.1f, c_dd·n0 = %.1f\n" N_PEAK (
        TW.c0*N_PEAK
    ) (TW.c1*N_PEAK) (TW.c_dd*N_PEAK)
    flush(stdout)

    dirs = fibonacci_directions(n_dirs)
    worst_growth = 0.0
    worst_dir = (0.0, 0.0, 0.0)
    worst_k = 0.0
    for dir in dirs
        res = bdg_at_dir(ζ, N_PEAK, ip, zee, TW.c_dd, dir, 5.0, n_k)
        if res.max_growth_rate > worst_growth
            worst_growth = res.max_growth_rate
            worst_dir = dir
            # find k at which growth is max
            for ik in 1:size(res.omega, 2)
                for ib in 1:size(res.omega, 1)
                    if abs(imag(res.omega[ib, ik]) - res.max_growth_rate) < 1e-10
                        worst_k = res.k_values[ik]
                        break
                    end
                end
            end
        end
    end
    if worst_growth > 1e-8
        # Extract eigenvector at worst direction
        ev, evec = extract_mode_at_max_growth(ζ, N_PEAK, ip, zee, TW.c_dd, worst_dir, worst_k)
        u = evec[1:D]
        v_part = evec[(D + 1):2D]
        @printf "  → UNSTABLE: max growth = %.4e at k_dir=(%.2f, %.2f, %.2f), k=%.3f\n" worst_growth worst_dir... worst_k
        # Timescale
        tau_s = 1.0 / (worst_growth * TW.omega_ref)
        @printf "  → τ_inst = %.3e s = %.4f ms\n" tau_s (tau_s*1000)
        # m-content of unstable mode
        @printf "  → Unstable mode m-content (|u|²+|v|²):\n"
        weights = [(F - c + 1, abs2(u[c]) + abs2(v_part[c])) for c in 1:D]
        total = sum(w[2] for w in weights)
        sort!(weights; by=x -> -x[2])
        for (m, w) in weights
            if w / total > 1e-4
                @printf "      m=%+d  weight = %.4f  (%.1f%%)\n" m (w/total) (100*w/total)
            end
        end
        return worst_growth, worst_dir, worst_k, weights
    else
        @printf "  → STABLE: max growth = %.2e (numerical noise)\n" worst_growth
        return worst_growth, worst_dir, worst_k, nothing
    end
end

function main()
    println("=== Bogoliubov stability of m=-F FM at Matsui digital twin ===\n")
    @printf "Atom: %s, F=%d, N=%d, ω_ref=%.1f rad/s\n" TW.atom.name F TW.n_atoms TW.omega_ref
    @printf "c_0=%.4e c_1=%.4e c_dd=%.4e (c_dd/c_0=%.4f)\n" TW.c0 TW.c1 TW.c_dd (TW.c_dd/TW.c0)

    # Test 1: zero Zeeman (FM pure GS, sanity)
    zee0 = ZeemanParams(0.0, 0.0)
    g0, d0, k0, w0 = scan_m_minus_F("B_z = 0 (sanity)", zee0; n_dirs=24)

    # Test 2: Matsui dynamics Bz = 2.6 nT
    zee_dyn = ZeemanParams(P_DIMLESS, Q_DIMLESS)
    g_dyn, d_dyn, k_dyn, w_dyn = scan_m_minus_F("Matsui dynamics B_z=2.6 nT", zee_dyn; n_dirs=24)

    # Test 3: Matsui GS Bz = 1 μT (10x larger)
    p_gs = G_F_EU * MU_B_HZ_PER_T * 1e-6 * 2π / TW.omega_ref
    zee_gs = ZeemanParams(p_gs, 0.0)
    g_gs, d_gs, k_gs, w_gs = scan_m_minus_F("Matsui GS B_z=1 μT (10× dynamics)", zee_gs; n_dirs=16)

    println("\n\n=== Comparison to Matsui observation ===\n")
    println("Matsui experiment (Science 2026):")
    println("  Initial state: m=-6 fully polarised at B_z=1 μT GS prep")
    println("  Dynamics: B_z quenched to 2.6 nT (≈10× smaller)")
    println("  Observed cascade: m=-6 → m=-5 (first) → m=-4 (second) within ~5 ms")
    println("  At 40 ms: substantial m=-5/-4 populations + loss")
    println()
    println("Prediction from dynamics-B_z Bogoliubov (m-content of unstable mode):")
    if w_dyn !== nothing
        # Top 3 m-channels
        sorted_w = sort(w_dyn; by=x -> -x[2])
        total = sum(x[2] for x in sorted_w)
        for (i, (m, w)) in enumerate(sorted_w[1:min(5, end)])
            @printf "  rank %d: m=%+d  weight=%.3f (%.1f%%)\n" i m (w/total) (100*w/total)
        end
        # Check match: m=-5 dominant?
        top_m = sorted_w[1][1]
        if top_m == -5
            println("\n→ PREDICTION MATCHES MATSUI: m=-5 dominant first growth channel.")
        elseif top_m == -4
            println(
                "\n→ Prediction: m=-4 dominant — Matsui sees m=-5 first; check if both grow simultaneously.",
            )
        else
            @printf "\n→ Prediction: m=%+d dominant. Compare to Matsui m=-5 expected.\n" top_m
        end
    end

    println("\n=== Done ===")
end

main()
