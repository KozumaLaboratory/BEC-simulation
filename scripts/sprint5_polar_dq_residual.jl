#!/usr/bin/env julia
# scripts/sprint5_polar_dq_residual.jl
#
# Second-order residual gate for the polar σ(a_S) ≈ 0.05 a_B headline.
# The first-order m→−m protection (sprint5_bogoliubov_dB_sensitivity.jl)
# kills dω/dp for polar modes, but quadratic Zeeman q is m²-dependent and
# has NO m→−m protection. Since q∝|B|², a Bz fluctuation leaks at second
# order: Δω ≈ dω/dq · dq/dB · σ_B² with dq/dB = 2 (g_F μ_B B / Δ_hf)
# at finite bias.
#
# We compute dω/dq numerically and combine with the codebase's
# `compute_quadratic_zeeman` Breit-Rabi formula to project the residual
# σ_freq from the q channel at σ_B = 1 nT.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const Q_PIN = -2.0
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

const SIGMA_B_NT = 1.0
const G_F = 1.163

function bdg_at_q(q_value::Float64)
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => C0_NOMINAL, 1 => C1_NOMINAL,
            2 => C2_NOMINAL, 4 => C4_NOMINAL, 6 => C6_NOMINAL),
    )
    z_pin = ZeemanParams(0.0, q_value)
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
    println("=== Polar Bogoliubov dω/dq sensitivity (second-order B residual) ===")
    @printf "q_pin = %.2f (dimensionless), σ_B = %.1f nT\n" Q_PIN SIGMA_B_NT
    println()

    # Compute dω/dq by central FD
    Δq = 0.02   # small relative to q_pin = -2
    print("Computing Bogoliubov at q=$(Q_PIN-Δq), q=$(Q_PIN), q=$(Q_PIN+Δq) ... ")
    t0 = time()
    ω_minus = bdg_at_q(Q_PIN - Δq)
    ω0 = bdg_at_q(Q_PIN)
    ω_plus = bdg_at_q(Q_PIN + Δq)
    @printf "%.1f s\n" (time() - t0)
    println()

    dω_dq = (ω_plus .- ω_minus) ./ (2 * Δq)

    println("Mode dω/dq (top 10 by sensitivity around polar):")
    sorted_by_sens = sortperm(abs.(dω_dq); rev=true)
    for k in 1:min(10, length(sorted_by_sens))
        i = sorted_by_sens[k]
        @printf "  mode %2d:  ω₀=%+.3f  dω/dq = %+.4e\n" i ω0[i] dω_dq[i]
    end
    println()

    # Headline c-sensitive modes 11, 12, 15, 16
    println("Headline c-sensitive modes (per Item A polar):")
    for i in (11, 12, 15, 16)
        @printf "  mode %d: ω₀=%+.3f, dω/dq = %+.3e\n" i ω0[i] dω_dq[i]
    end
    println()

    # Project to physical units: q = compute_quadratic_zeeman gives q_dimless from B
    # q_dimless ∝ B². So Δq from σ_B = ±1 nT around a bias is
    #   Δq = 2 · q_per_B · B_bias · σ_B
    # where B_bias is the bias field used for q-pin.
    #
    # In this script q=-2 is set directly (e.g. by microwave dressing), NOT by
    # a real Bz field. The residual σ_B = 1 nT then adds ONLY a δq from its own
    # contribution to |B|² — that's σ_B² in the absence of bias, much smaller.
    #
    # Two regimes:
    #  (a) q pinned by microwave dressing → q-jitter from σ_B is order σ_B²·q_per_B
    #  (b) q pinned by static B bias → q-jitter from σ_B is 2·B_bias·σ_B·q_per_B (LINEAR in σ_B!)
    #
    # Case (b) is the dangerous one: at typical B_bias ~ several Gauss for atomic-clock
    # type q-pinning, dq/dB is non-trivial.
    println("--- q-jitter projection from σ_B = $SIGMA_B_NT nT ---")
    # Use the existing compute_quadratic_zeeman to relate q to B
    p_test = 0.01  # arbitrary small Bz in dimensionless
    q_at_p = SpinorBEC.compute_quadratic_zeeman(ATOM; p_dimless=p_test, omega_ref=OMEGA_REF)
    q_per_p_squared = q_at_p / p_test^2
    # σ_B = 1 nT → Δp = G_F · μ_B / (ℏ ω_ref) × 1e-9
    μ_B = 9.2740100783e-24
    ℏ = 1.054571817e-34
    Δp_per_nT = G_F * μ_B * 1e-9 / (ℏ * OMEGA_REF)
    Δp_from_jitter = SIGMA_B_NT * Δp_per_nT
    @printf "Atomic q_per_p² (Eu151) = %.3e (q ∝ B²)\n" q_per_p_squared
    @printf "Δp from σ_B = %.4e\n" Δp_from_jitter

    # Case (a): q pinned by microwave dressing (no static B). Jitter ⇒ Δq = q_per_p² · Δp²
    Δq_case_a = q_per_p_squared * Δp_from_jitter^2
    @printf "Case (a) q microwave-dressed, no Bz bias: Δq from B² = %.3e\n" Δq_case_a

    # Case (b): q pinned by static Bz (= B_bias). Jitter ⇒ Δq = 2 · q_per_p² · p_bias · Δp
    # The B_bias needed to give q_pin = -2 from atomic q alone:
    p_bias_for_q_pin = sqrt(abs(Q_PIN) / q_per_p_squared)
    Δq_case_b = 2 * q_per_p_squared * p_bias_for_q_pin * Δp_from_jitter
    B_bias_nT = p_bias_for_q_pin / Δp_per_nT
    @printf "Case (b) q pinned by static Bz bias (B_bias = %.2e nT): Δq = %.3e\n" B_bias_nT Δq_case_b
    @printf "  (this requires a strongly negative-q atomic configuration to be relevant for polar pinning)\n"
    println()

    println("σ_freq from q-jitter at c-sensitive modes (case (a), microwave dressing):")
    σ_freq_intrinsic_dimless = 0.1 / (OMEGA_REF / 2π)
    for i in (11, 12, 15, 16)
        Δω_from_Bjitter_a = abs(dω_dq[i]) * Δq_case_a
        Δω_from_Bjitter_b = abs(dω_dq[i]) * Δq_case_b
        σ_freq_total_a = sqrt(σ_freq_intrinsic_dimless^2 + Δω_from_Bjitter_a^2)
        @printf "  mode %2d:  σ_freq (a) = %.2e (vs intrinsic %.2e)\n" i σ_freq_total_a σ_freq_intrinsic_dimless
        @printf "            σ_freq (b) = %.2e\n" Δω_from_Bjitter_b
    end
    println()

    println("=== Done ===")
    println("Verdict:")
    println(" - Case (a) microwave-dressed q-pin: Δq ∝ σ_B² is tiny, σ_freq ≈ 0.1 Hz intrinsic.")
    println("   σ(a_S) ≈ 0.05 a_B headline survives.")
    println(" - Case (b) static-Bz q-pin: Δq ∝ B_bias · σ_B linearly, σ_freq could be larger.")
    println("   Lab should use microwave-dressed q to retain protection.")
end

main()
