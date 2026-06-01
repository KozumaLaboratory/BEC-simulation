#!/usr/bin/env julia
# scripts/sprint5_bogoliubov_dB_sensitivity.jl
#
# Reality check on the Item A σ(a_S) ~ 0.05 a_Bohr headline. The result
# assumed σ_freq = 0.1 Hz per Bogoliubov mode, but the c-sensitive modes
# (Δm magnons at ω ≈ ±6.7 in my dimensionless units) inherit a Larmor
# slope dω/dB. At Matsui's 2.7 nT giving 45 Hz Larmor, dω/dB ≈ 17 Hz/nT;
# at the lab's residual σ_B ≈ 1 nT shot-to-shot jitter the mode frequency
# floor is ~17 Hz, NOT 0.1 Hz. σ(a_S) ∝ σ_freq, so realistic σ(a_S)
# degrades to ~ 8 a_Bohr — comparable to current state-of-the-art, NOT
# 2-3 orders better.
#
# This script computes the actual dω/dB per mode (via FD on Zeeman p),
# then re-does the σ(a_S) projection with realistic σ_freq = max(0.1 Hz,
# σ_B × dω/dB). It also identifies pairs of modes whose dω/dB are
# approximately equal — differences of such modes are magnetically
# insensitive while remaining c-sensitive.
#
# Run:   julia --project=. scripts/sprint5_bogoliubov_dB_sensitivity.jl
# Expected wall-clock: ~ 1 minute on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN_PIN = ZeemanParams(0.0, -2.0)
const ZEEMAN_STRETCHED = ZeemanParams(2.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8
const K_SAMPLE = 0.5

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# Lab assumptions:
const SIGMA_B_NT = 1.0                  # residual Bz jitter (nT, RMS)
const G_F = 1.163                       # Eu Landé g-factor
const SIGMA_FREQ_INTRINSIC = 0.1 / (OMEGA_REF / 2π)  # 0.1 Hz in dimensionless ω_ref units

# Compute polar GS spinor + Bogoliubov spectrum at given Zeeman p.
function bdg_at_p(p_value::Float64)
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => C0_NOMINAL, 1 => C1_NOMINAL,
            2 => C2_NOMINAL, 4 => C4_NOMINAL, 6 => C6_NOMINAL),
    )
    z_pin = ZeemanParams(p_value, ZEEMAN_PIN.q)
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=z_pin, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=:polar, verbose=false)
    psi = ws.state.psi
    D = 2F + 1
    n_total = SpinorBEC.total_density(psi, 1)
    peak_idx = argmax(n_total)
    spinor = ComplexF64[psi[peak_idx, c] for c in 1:D]
    n0 = sum(abs2, spinor)
    n0 > 1e-30 && (spinor ./= sqrt(n0))
    bdg = SpinorBEC.bogoliubov_spectrum(;
        spinor=spinor, n0=n0, F=F,
        interactions=ip, zeeman=z_pin, c_dd=C_DD_DIMLESS,
        k_max=K_SAMPLE, n_k=2,
        k_direction=(0.0, 0.0, 1.0))
    Float64[real(ω) for ω in bdg.omega[:, 2]]
end

function main()
    println("=== Bogoliubov dω/dB sensitivity check ===")
    @printf "Eu g_F=%.3f, ω_ref=%.1f rad/s, σ_B residual=%.1f nT\n" G_F OMEGA_REF SIGMA_B_NT
    println()

    # Convert 1 nT to dimensionless Zeeman p
    # p [dimensionless] = g_F · μ_B · Bz / (ℏ · ω_ref)
    μ_B = 9.2740100783e-24                 # J/T
    ℏ = 1.054571817e-34                    # J·s
    Δp_per_nT = G_F * μ_B * 1e-9 / (ℏ * OMEGA_REF)
    Δp_for_jitter = SIGMA_B_NT * Δp_per_nT
    @printf "Δp / nT = %.4e  (=> Δp at σ_B = %.1f nT is %.4e)\n" Δp_per_nT SIGMA_B_NT Δp_for_jitter
    println()

    print("Computing Bogoliubov at nominal p=0 ... ")
    t0 = time()
    ω0 = bdg_at_p(0.0)
    @printf "%.1f s\n" (time() - t0)
    print("Computing Bogoliubov at perturbed p ... ")
    t0 = time()
    ωplus = bdg_at_p(Δp_for_jitter)
    ωminus = bdg_at_p(-Δp_for_jitter)
    @printf "%.1f s\n" (time() - t0)
    println()

    # Central FD: dω/dp
    dω_dp = (ωplus .- ωminus) ./ (2 * Δp_for_jitter)
    # B-induced frequency uncertainty: dω/dB · σ_B in dimensionless units
    σ_freq_from_B = abs.(dω_dp) .* Δp_for_jitter
    σ_freq_eff = max.(σ_freq_from_B, SIGMA_FREQ_INTRINSIC)

    println("Mode sensitivity to B (per mode, polar GS, k=0.5):")
    @printf "  %-4s  %-10s  %-12s  %-10s  %-10s\n" "i" "ω₀" "dω/dp" "dω/dB[Hz/nT]" "σ_freq_eff"
    println("  " * "-"^58)
    for i in 1:length(ω0)
        # dω/dB [Hz/nT] = (dω/dp [dimensionless/dimensionless]) × Δp_per_nT × ω_ref/(2π)
        dωdB_Hz = abs(dω_dp[i]) * Δp_per_nT * OMEGA_REF / (2π)
        @printf "  %2d    %+8.3f   %+8.3e   %.2e    %.2e\n" i ω0[i] dω_dp[i] dωdB_Hz σ_freq_eff[i]
    end
    println()

    # Identify the c-sensitive modes (max|∂ω/∂c| was 3.67 for modes 11/12/15/16
    # per Item A polar). Check their σ_freq_eff.
    @printf "Headline c-sensitive modes (per Item A): 11, 12, 15, 16\n"
    for i in (11, 12, 15, 16)
        dωdB_Hz = abs(dω_dp[i]) * Δp_per_nT * OMEGA_REF / (2π)
        @printf "  mode %d: dω/dB = %.2f Hz/nT, σ_freq_eff = %.2e (dimensionless)\n" i dωdB_Hz σ_freq_eff[i]
    end
    println()

    # σ_freq_eff in dimensionless units; convert to Hz
    σ_freq_max_Hz = maximum(σ_freq_eff[[11, 12, 15, 16]]) * OMEGA_REF / (2π)
    @printf "Effective σ_freq for c-sensitive modes ≈ %.1f Hz (vs assumed 0.1 Hz)\n" σ_freq_max_Hz
    @printf "Degradation factor for σ(a_S) ≈ %.0fx → headline 0.05 a_B becomes ~%.0f a_B\n" (
        σ_freq_max_Hz / 0.1) (0.05 * σ_freq_max_Hz / 0.1)
    println()

    # Magnetically-insensitive combinations: pairs of modes with similar dω/dB
    # but different ∂ω/∂c. Search across all distinct pairs.
    println("--- Magnetically-insensitive mode-difference candidates ---")
    println("Looking for pairs (i, j) where |dω/dB|_i ≈ |dω/dB|_j (cancels in difference)")
    threshold_dωdB_ratio = 0.05
    candidates = Vector{Tuple{Int, Int, Float64, Float64}}()
    for i in 1:length(ω0), j in (i + 1):length(ω0)
        dB_i = abs(dω_dp[i])
        dB_j = abs(dω_dp[j])
        max_dB = max(dB_i, dB_j)
        if max_dB > 1e-3 &&
            abs(dB_i - dB_j) / max_dB < threshold_dωdB_ratio
            ω_diff_nominal = ω0[i] - ω0[j]
            push!(candidates, (i, j, ω0[i] - ω0[j], abs(dB_i - dB_j)))
        end
    end
    if isempty(candidates)
        println(
            "  No mode pairs with matched dω/dB within $threshold_dωdB_ratio relative tolerance."
        )
        println("  Generic single-mode spectroscopy is the only option, and is jitter-limited.")
    else
        println("  $(length(candidates)) candidate pairs:")
        for (i, j, ω_diff, residual) in candidates[1:min(end, 10)]
            @printf "  modes (%2d, %2d):  ω_i - ω_j = %+.3f,  residual |dω/dB|_i-|dω/dB|_j = %.2e\n" i j ω_diff residual
        end
    end
    println()
    # --- Stretched GS comparison ---
    println("=== Stretched GS comparison (no m → -m symmetry) ===")

    function bdg_stretched_at_p(p_value::Float64)
        ip = InteractionParams(
            Dict{Int, Float64}(
                0 => C0_NOMINAL, 1 => C1_NOMINAL,
                2 => C2_NOMINAL, 4 => C4_NOMINAL, 6 => C6_NOMINAL),
        )
        z_pin = ZeemanParams(p_value, ZEEMAN_STRETCHED.q)
        ws, conv, E, dE, last = find_ground_state(;
            grid=GRID, atom=ATOM, interactions=ip,
            zeeman=z_pin, potential=POT,
            dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
            initial_state=:m_plus_F, verbose=false)
        psi = ws.state.psi
        D = 2F + 1
        n_total = SpinorBEC.total_density(psi, 1)
        peak_idx = argmax(n_total)
        spinor = ComplexF64[psi[peak_idx, c] for c in 1:D]
        n0 = sum(abs2, spinor)
        n0 > 1e-30 && (spinor ./= sqrt(n0))
        bdg = SpinorBEC.bogoliubov_spectrum(;
            spinor=spinor, n0=n0, F=F,
            interactions=ip, zeeman=z_pin, c_dd=C_DD_DIMLESS,
            k_max=K_SAMPLE, n_k=2,
            k_direction=(0.0, 0.0, 1.0))
        Float64[real(ω) for ω in bdg.omega[:, 2]]
    end

    p_base = ZEEMAN_STRETCHED.p
    ω0_s = bdg_stretched_at_p(p_base)
    ωplus_s = bdg_stretched_at_p(p_base + Δp_for_jitter)
    ωminus_s = bdg_stretched_at_p(p_base - Δp_for_jitter)
    dω_dp_s = (ωplus_s .- ωminus_s) ./ (2 * Δp_for_jitter)

    println("Stretched mode dω/dB (top-10 by sensitivity):")
    sorted_by_sens = sortperm(abs.(dω_dp_s); rev=true)
    for k in 1:min(10, length(sorted_by_sens))
        i = sorted_by_sens[k]
        dωdB_Hz = abs(dω_dp_s[i]) * Δp_per_nT * OMEGA_REF / (2π)
        @printf "  mode %2d:  ω₀=%+.3f  dω/dB = %.2f Hz/nT\n" i ω0_s[i] dωdB_Hz
    end
    println()
    max_dωdB_Hz_polar = maximum(abs.(dω_dp)) * Δp_per_nT * OMEGA_REF / (2π)
    max_dωdB_Hz_stretched = maximum(abs.(dω_dp_s)) * Δp_per_nT * OMEGA_REF / (2π)
    @printf "Max dω/dB:  polar = %.2e Hz/nT,  stretched = %.2e Hz/nT\n" max_dωdB_Hz_polar max_dωdB_Hz_stretched
    if max_dωdB_Hz_polar < 0.1 && max_dωdB_Hz_stretched > 1.0
        println("→ Polar IS magnetically protected (m → -m symmetry); stretched is NOT.")
        println("  σ(a_S) ~ 0.05 a_B headline survives the σ_B jitter critique IF polar is used.")
    elseif max_dωdB_Hz_polar < 0.1 && max_dωdB_Hz_stretched < 0.1
        println("→ Both magnetically protected; surprising.")
    else
        println("→ Polar protection not as clean as expected; investigate further.")
    end
    println()
    println("=== Done ===")
end

main()
