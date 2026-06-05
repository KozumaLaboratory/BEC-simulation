#!/usr/bin/env julia
# scripts/m2_lab_frame_stir_smoke.jl
#
# M2 lab-frame stir smoke. Protocol per user's "Ω=0 static GS → stir on"
# framing:
#
#   Phase 1 (t < 0): equilibrate at Ω = 0 with static Bz = B_static.
#                    Bug-trivially-inactive — no `rotating_frame_omega`.
#
#   Phase 2 (t ≥ 0): turn on rotating transverse B field:
#                       B_x(t) = B_perp · cos(Ω_d · t)
#                       B_y(t) = B_perp · sin(Ω_d · t)
#                    Real-time evolution under H_lab(t) — uses the
#                    independently-audited split-step propagator. NO
#                    `energy_gradient!`, NO LBFGS, NO
#                    `rotating_frame_omega`. Outside today's bug's blast
#                    radius regardless of fix status.
#
# Observable: ⟨F_z⟩(t) — the dynamical Barnett pumping curve.
#
# Reference anchors (NOT a "Klaus" paper — that name was a confabulation):
#   * Experiment: Dy Innsbruck 2022 (arXiv:2206.12265) — rotating-B
#     spin pumping in a strongly dipolar BEC.
#   * Theory benchmark: Prasad 2019 (arXiv:1906.08664) — rotating-
#     polarisation scalar dipolar BEC long-time dynamics.
#
# Load-bearing in this smoke is QUALITATIVE ONLY:
#   ✓ sign of ⟨F_z⟩(t) drift (Barnett pumping in the predicted direction)
#   ✓ presence/absence of resonant pumping at Ω_d ≈ Larmor frequency
#   ✓ co-aligned ⟨L_z⟩ + ⟨F_z⟩ at saturation (EdH oracle)
# Absolute τ_pump and saturation rates are NOT load-bearing — the
# lab-frame RTP shares the M0 5–10× time-constant anomaly (still
# unresolved). Calibrate rates after M0 is closed.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m2_lab_frame_stir_smoke.jl
#
# Cost: 8000 steps × ~40 ms/step on 24³ Eu ≈ 5 min GPU.

import CUDA
using SpinorBEC
using Printf
using JLD2
const TW = eu151_preset()

const BZ_STATIC_NT = 1.0          # nT — weak static bias (above Earth, below trap)
const B_PERP_NT = 0.5             # nT — transverse rotating field amplitude
const OMEGA_DRIVE = 0.5           # ω_drive / ω_ref (matches rotating-frame Ω)
const T_PHASE2 = 40.0             # ω_ref⁻¹ (~60 ms)
const DT = 0.005
const N_PHASE2 = Int(round(T_PHASE2 / DT))
const SAMPLE_EVERY = 50
const N_ITP_PHASE1 = 500
const OUTPUT_JLD2 = "runs/m2_klaus_stir_smoke_postfix_2026_06_04.jld2"

# SinusoidalWaveform formula: v(t) = center + amplitude · sin(2π · f · t + phase).
# Want B_x(t) = B_perp · cos(Ω·t) = B_perp · sin(Ω·t + π/2).
# So set frequency f = Ω / (2π) so 2π·f·t = Ω·t.
sin_freq(omega_d) = omega_d / (2π)

function spin_density_sum(psi_cpu, sm, dV)
    fx, fy, fz = spin_density_vector(psi_cpu, sm, 3)
    fx_t = sum(fx) * dV
    fy_t = sum(fy) * dV
    fz_t = sum(fz) * dV
    return fx_t, fy_t, fz_t
end

function main()
    println("=== M2 lab-frame stir smoke ===")
    @printf "Bz_static = %.2f nT  B_perp_amp = %.2f nT  Ω_drive = %.2f ω_ref⁻¹\n" BZ_STATIC_NT B_PERP_NT OMEGA_DRIVE
    @printf "T_phase2  = %.1f ω_ref⁻¹  (N=%d steps, sample every %d)\n\n" T_PHASE2 N_PHASE2 SAMPLE_EVERY

    p_static = BZ_STATIC_NT * TW.p_per_nT
    p_perp = B_PERP_NT * TW.p_per_nT

    # --- Phase 1: equilibrate at Ω = 0, static Bz only.
    println("--- Phase 1: equilibrate at Ω=0, static Bz ---")
    zeeman_phase1 = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_static), ConstantWaveform(0.0),
    )
    t0 = time()
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_phase1, potential=TW.potential,
        dt=DT, n_steps=N_ITP_PHASE1, tol=1e-7,
        initial_state=:polar, verbose=false,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=0.0, backend=CUDABackend(),
    )
    sm = r_itp.workspace.spin_matrices
    psi_phase1_cpu = Array(r_itp.workspace.state.psi)
    dV = SpinorBEC.cell_volume(TW.grid)
    fx0, fy0, fz0 = spin_density_sum(psi_phase1_cpu, sm, dV)
    @printf "  Phase-1 wall: %.1fs   E = %.4f\n" (time() - t0) r_itp.energy
    @printf "  ⟨F_x⟩=%+.3e  ⟨F_y⟩=%+.3e  ⟨F_z⟩=%+.3e  (polar GS at weak Bz: ⟨F_z⟩≈0)\n\n" fx0 fy0 fz0

    # --- Phase 2: turn on rotating transverse B; real-time evolution.
    println("--- Phase 2: turn on rotating B_⊥; RT evolve ---")
    zeeman_phase2 = TimeDependentZeeman(
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(OMEGA_DRIVE), phase=π/2),
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(OMEGA_DRIVE), phase=0.0),
        ConstantWaveform(p_static), ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=DT, n_steps=N_PHASE2, imaginary_time=false,
        normalize_every=0, save_every=SAMPLE_EVERY)
    # rotating_frame_omega = 0.0 by default in SimParams — no kwarg needed.
    ws = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_phase2, potential=TW.potential, sim_params=sp,
        psi_init=psi_phase1_cpu,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend(),
    )

    times = Float64[0.0]
    fx_t = [fx0]
    fy_t = [fy0]
    fz_t = [fz0]
    Lz_t = [orbital_angular_momentum(psi_phase1_cpu, ws.grid, ws.fft_plans)]

    t0 = time()
    @printf "  %8s  %10s  %10s  %10s  %10s\n" "t" "⟨F_x⟩" "⟨F_y⟩" "⟨F_z⟩" "⟨L_z⟩"
    for step in 1:N_PHASE2
        SpinorBEC.split_step!(ws)
        if step % SAMPLE_EVERY == 0 || step == N_PHASE2
            t_now = step * DT
            psi_cpu = Array(ws.state.psi)
            fx, fy, fz = spin_density_sum(psi_cpu, sm, dV)
            Lz = orbital_angular_momentum(psi_cpu, ws.grid, ws.fft_plans)
            push!(times, t_now);
            push!(fx_t, fx);
            push!(fy_t, fy)
            push!(fz_t, fz);
            push!(Lz_t, Lz)
            if step % (SAMPLE_EVERY * 4) == 0 || step == N_PHASE2
                @printf "  %8.2f  %+.3e  %+.3e  %+.3e  %+.3e\n" t_now fx fy fz Lz
                flush(stdout)
            end
        end
    end
    @printf "\n  Phase-2 wall: %.1fs\n\n" (time() - t0)
    CUDA.reclaim()

    @printf "Final ⟨F_z⟩ = %+.4f   (Phase-1 start was %+.4f)\n" fz_t[end] fz_t[1]
    @printf "Δ⟨F_z⟩ = %+.4f over T = %.1f ω_ref⁻¹\n" (fz_t[end] - fz_t[1]) T_PHASE2
    @printf "Final ⟨L_z⟩ = %+.4f   (Phase-1 start was %+.4f)\n" Lz_t[end] Lz_t[1]
    @printf "Same-sign check (Barnett EdH): ⟨F_z⟩·⟨L_z⟩ = %+.3e\n" (fz_t[end] * Lz_t[end])

    JLD2.jldsave(OUTPUT_JLD2;
        times, fx_t, fy_t, fz_t, Lz_t,
        BZ_STATIC_NT, B_PERP_NT, OMEGA_DRIVE, T_PHASE2, DT,
        psi_phase1=psi_phase1_cpu,
        psi_final=Array(ws.state.psi),
        timestamp=string(time()),
        note="Lab-frame stir smoke (post-2026-06-04 GPU energy fix); single cell.",
    )
    @printf "Wrote %s\n" OUTPUT_JLD2
end

main()
