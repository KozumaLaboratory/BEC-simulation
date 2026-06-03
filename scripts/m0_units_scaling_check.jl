#!/usr/bin/env julia
# scripts/m0_units_scaling_check.jl
#
# Priority B per user 2026-06-04: after CPU/GPU propagator parity came
# back CLEAN (priority A ruled out missing-term bug), check whether the
# M0 5–10× time-constant anomaly is a units / time-scaling issue.
#
# Approach: pick an analytic scale that the M0 dynamics MUST follow,
# compute it from M0 parameters, and compare to the observed rate.
#
# Two cheap analytic anchors:
#
#   A1. Larmor frequency at Phase-2 Bz (the slowest scale that DOES
#       enter the dynamics): ω_L = g_F μ_B B / ℏ. M0 EdH used
#       Bz = 2.6 nT, so ω_L = 1.163 × (9.274e-24 J/T) × (2.6e-9 T) / ℏ
#       = 2π × (42.3 Hz). Period T_L = 23.6 ms physical = 16.3 ω_ref⁻¹
#       (at ω_ref = 2π × 100 Hz).
#       Sub-Larmor dynamics CAN happen but Larmor sets the slowest scale
#       for spin-only processes.
#
#   A2. DDI cascade rate at peak density. Off-diagonal MDDI matrix
#       element drives Δm = ±1 transitions at rate
#         Γ_DDI ~ c_dd · n_peak · ⟨Q_off⟩
#       where ⟨Q_off⟩ ~ 1/2 for oblate aspect. With c_dd_dimensionless
#       and the CORRECTED n_peak per memo errata E2
#       (n_peak ≈ 258 µm⁻³, not the original 61.6), the predicted
#       τ_ring band shifts from [5.7, 57] ms → [1.4, 14] ms.
#       Matsui experimental ~5 ms sits mid-band.
#
# Compare simulated τ_ring (from M0 EdH baseline at canonical params)
# to A2's [1.4, 14] ms band. If sim τ is inside the band, the "5–10×
# anomaly" claim was based on the pre-correction prediction (would
# need re-derivation). If sim τ is outside, real physics question.
#
# Run M0 EdH baseline at canonical Matsui parameters:
#   N=30000, ω_ref = 2π × 100 Hz, isotropic; a_s=110 a_B, mu=6.977 μ_B
#   Grid 24³, box=12 a_ho
#   Bz_dynamics = 2.6 nT
#   T_evolve = 30 ω_ref⁻¹ ≈ 48 ms physical
#
# Observable: max_t (N_{-5} + N_{-4}) / N — the post-quench spin excitation load-bearing
# observable per memory `klaus_quench_protocol_pivot_2026_05_26`. Track
# the time at which it first exceeds 0.05 (5% threshold from F1
# falsifier); compare to Matsui experimental ring at ~5 ms.

import CUDA
using SpinorBEC
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 30000
const OMEGA_REF = 2π * 100.0                         # rad/s
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS

# Matsui dynamics Bz = 2.6 nT  →  p_dimless = g_F μ_B B / (ℏ ω_ref)
const P_PER_NT = (1.163 * SpinorBEC.Units.MU_BOHR / SpinorBEC.Units.HBAR) * 1e-9 / OMEGA_REF
const P_DYNAMICS = 2.6 * P_PER_NT
const BZ_NT = 2.6

const GRID = make_grid(GridConfig{3}((24, 24, 24), (12.0, 12.0, 12.0)))
const POTENTIAL = HarmonicTrap{3}((1.0, 1.0, 1.0))
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const INTERACTIONS = InteractionParams(Dict{Int, Float64}(
    0 => C_TOTAL,
    1 => 0.0,            # FM with c1=0 for simplicity (M0 baseline)
))

const T_EVOLVE = 30.0
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))
const SAMPLE_EVERY = 100
const F1_THRESHOLD = 0.05            # 5% cascade-product threshold

function main()
    println("=== M0 units scaling check ===\n")
    @printf "N=%d  ω_ref/2π = %.1f Hz  Bz=%.2f nT  T=%.1f ω⁻¹ (%.0f ms physical)\n" N_ATOMS (
        OMEGA_REF / (2π)
    ) BZ_NT T_EVOLVE (1000 * T_EVOLVE / OMEGA_REF)
    @printf "Grid: 24³  box=12 a_ho   a_ho=%.3e m\n" A_HO
    @printf "c_dd_dimless=%.2f  C_TOTAL=%.1f\n\n" C_DD_DIMLESS C_TOTAL

    # Analytic anchor (A1) Larmor
    omega_L_rad_per_s = 1.163 * SpinorBEC.Units.MU_BOHR / SpinorBEC.Units.HBAR * 2.6e-9
    T_L_ms = 1000 * 2π / omega_L_rad_per_s
    T_L_dimless = 2π / P_DYNAMICS
    @printf "(A1) Larmor T_L = %.2f ms physical = %.2f ω_ref⁻¹\n\n" T_L_ms T_L_dimless

    # --- Run M0 baseline dynamics ---
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    zeeman = ZeemanParams(P_DYNAMICS, 0.0)
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=SAMPLE_EVERY)
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=INTERACTIONS,
        zeeman=zeeman, potential=POTENTIAL, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        backend=CUDABackend(),
    )
    dV = SpinorBEC.cell_volume(GRID)
    times = Float64[0.0]
    pop_cascade_t = Float64[0.0]       # N_{-5}/N + N_{-4}/N
    pop_m_minus_F_t = Float64[1.0]     # N_{-F}/N (should start at 1)

    function read_obs(ws)
        psi_cpu = Array(ws.state.psi)
        N_m = [sum(abs2, view(psi_cpu,:,:,:,c)) * dV for c in 1:(2 * F + 1)]
        total = sum(N_m)
        casc = (N_m[2 * F] + N_m[2 * F - 1]) / total       # m=-F+1 and -F+2
        nF = N_m[2 * F + 1] / total                         # m=-F
        return casc, nF
    end

    println("--- Running M0 baseline ---")
    t0 = time()
    for step in 1:N_STEPS
        SpinorBEC.split_step!(ws)
        if step % SAMPLE_EVERY == 0
            t_now = step * DT
            casc, nF = read_obs(ws)
            push!(times, t_now)
            push!(pop_cascade_t, casc)
            push!(pop_m_minus_F_t, nF)
            if step % (SAMPLE_EVERY * 10) == 0
                @printf "  t=%6.2f  N_{-F}=%.4f  N_{-5}+N_{-4}=%.4f\n" t_now nF casc
                flush(stdout)
            end
        end
    end
    @printf "  Wall: %.1fs\n\n" (time() - t0)
    CUDA.reclaim()

    # Find first time cascade > 5%
    idx_5pct = findfirst(>(F1_THRESHOLD), pop_cascade_t)
    t_5pct_dimless = idx_5pct === nothing ? NaN : times[idx_5pct]
    t_5pct_ms = t_5pct_dimless * 1000 / OMEGA_REF

    println("=== Result ===")
    @printf "First t at which (N_{-5}+N_{-4})/N exceeds %.1f%%:\n" 100 * F1_THRESHOLD
    if idx_5pct === nothing
        @printf "  Did not reach %.0f%% in T=%.1f ω⁻¹ (%.0f ms physical).\n" 100 * F1_THRESHOLD T_EVOLVE (
            1000 * T_EVOLVE / OMEGA_REF
        )
    else
        @printf "  t = %.2f ω_ref⁻¹ = %.2f ms physical\n" t_5pct_dimless t_5pct_ms
    end
    @printf "\nMatsui experimental t_ring ≈ 5 ms\n"
    @printf "n_peak-corrected theory band (memo E2): [1.4, 14] ms\n"

    if idx_5pct !== nothing
        if t_5pct_ms < 1.4
            println("\n→ Simulated cascade is FASTER than corrected theory band.")
            println("  Possible: over-driven (N or c_dd too large) OR our `n_peak`")
            println("  estimate was still off OR DDI off-diagonal is overestimated.")
        elseif t_5pct_ms <= 14.0
            println("\n→ Simulated cascade is INSIDE the n_peak-corrected theory band.")
            println("  → The '5–10× anomaly' claim was based on the PRE-CORRECTION")
            println("    n_peak prediction. After correction, sim and experiment agree.")
            println("  → No deep M0 sprint required; the anomaly was bookkeeping.")
        else
            @printf "\n→ Simulated cascade STILL slow (%.1f ms vs band [1.4, 14] ms).\n" t_5pct_ms
            println("  → Real physics question — sprint needed.")
            println("  → Candidates: N too small; thermal-state initialization; ")
            println("              loss-channel coupling; grid resolution at high-k spin")
        end
    end
end

main()
