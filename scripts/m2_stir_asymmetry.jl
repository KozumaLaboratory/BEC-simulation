#!/usr/bin/env julia
# scripts/m2_stir_asymmetry.jl
#
# Clean Barnett-regime stir comparison: +Ω_d vs −Ω_d at perturbative
# B_perp/Bz = 0.1. Goal: demonstrate the Barnett sign asymmetry — the
# rotation direction selects the polarization direction.
#
# Convention check (per audited `_shift_zeeman_for_rotating_frame`):
#   p_eff_rot = p_lab + Ω_d (NOT minus)
#
# For Bz=2 nT, p_lab = 0.326. With Ω_d = +0.5: p_eff = +0.826 (strong +F).
# With Ω_d = −0.5: p_eff = −0.174 (weak −F). Asymmetric magnitudes are
# expected — the lab-frame asymmetry is the whole point.
#
# Output: two ⟨F_z⟩(t) traces + an asymmetry plot. Compares
# ⟨⟨F_z⟩⟩_late(+Ω) vs ⟨⟨F_z⟩⟩_late(−Ω) — the rectified-drift sign flip
# is the load-bearing qualitative observation.

import CUDA
using SpinorBEC
using Printf
using JLD2
const TW = eu151_preset()
const BZ_STATIC_NT = 2.0
const B_PERP_NT = 0.2
const OMEGA_D_GRID = [+0.5, -0.5]
const T_EVOLVE = 60.0
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))
const SAMPLE_EVERY = 50
const N_ITP_PHASE1 = 500
const OUTPUT_JLD2 = "runs/m2_stir_asymmetry_2026_06_04.jld2"

sin_freq(omega_d) = omega_d / (2π)

function spin_density_sum(psi_cpu, sm, dV)
    fx, fy, fz = spin_density_vector(psi_cpu, sm, 3)
    return sum(fx) * dV, sum(fy) * dV, sum(fz) * dV
end

function run_one(omega_d::Float64, psi_phase1_cpu, sm, dV)
    println("\n--- Phase 2 stir at Ω_d = $omega_d ---")
    p_static = BZ_STATIC_NT * TW.p_per_nT
    p_perp = B_PERP_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(omega_d), phase=π/2),
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(omega_d), phase=0.0),
        ConstantWaveform(p_static), ConstantWaveform(0.0),
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=SAMPLE_EVERY)
    ws = make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential, sim_params=sp,
        psi_init=psi_phase1_cpu,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend(),
    )

    times = Float64[0.0]
    fx_t = Float64[]
    fy_t = Float64[]
    fz_t = Float64[]
    Lz_t = Float64[]
    fx0, fy0, fz0 = spin_density_sum(psi_phase1_cpu, sm, dV)
    push!(fx_t, fx0);
    push!(fy_t, fy0);
    push!(fz_t, fz0)
    push!(Lz_t, orbital_angular_momentum(psi_phase1_cpu, ws.grid, ws.fft_plans))

    t0 = time()
    for step in 1:N_STEPS
        SpinorBEC.split_step!(ws)
        if step % SAMPLE_EVERY == 0
            t_now = step * DT
            psi_cpu = Array(ws.state.psi)
            fx, fy, fz = spin_density_sum(psi_cpu, sm, dV)
            Lz = orbital_angular_momentum(psi_cpu, ws.grid, ws.fft_plans)
            push!(times, t_now);
            push!(fx_t, fx);
            push!(fy_t, fy)
            push!(fz_t, fz);
            push!(Lz_t, Lz)
            if step % (SAMPLE_EVERY * 10) == 0
                @printf "  t=%6.2f  ⟨F_z⟩=%+.4f  ⟨L_z⟩=%+.4f\n" t_now fz Lz
                flush(stdout)
            end
        end
    end
    @printf "  Phase-2 wall: %.1fs\n" (time() - t0)
    CUDA.reclaim()
    return (times=times, fx_t=fx_t, fy_t=fy_t, fz_t=fz_t, Lz_t=Lz_t,
        psi_final=Array(ws.state.psi))
end

function main()
    println("=== M2 lab-frame stir Barnett asymmetry ===")
    @printf "Bz_static=%.1f nT  B_perp=%.2f nT  B_perp/Bz=%.2f\n" BZ_STATIC_NT B_PERP_NT B_PERP_NT/BZ_STATIC_NT
    @printf "Ω_d grid: %s   T_evolve=%.1f ω_ref⁻¹\n\n" string(OMEGA_D_GRID) T_EVOLVE

    p_static = BZ_STATIC_NT * TW.p_per_nT
    zeeman_phase1 = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_static), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)
    println("--- Phase 1: equilibrate at Ω=0, static Bz=$BZ_STATIC_NT nT ---")
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
    fx0, fy0, fz0 = spin_density_sum(psi_phase1_cpu, sm, dV)
    @printf "  E_phase1=%.4f  ⟨F_z⟩=%+.4e  Phase-1 wall=%.1fs\n" r_itp.energy fz0 (time() - t0)
    @printf "  Larmor freq ω_L = p_lab = %.4f\n\n" (BZ_STATIC_NT * TW.p_per_nT)

    results = Dict{Float64, Any}()
    for omega_d in OMEGA_D_GRID
        results[omega_d] = run_one(omega_d, psi_phase1_cpu, sm, dV)
    end

    println("\n=== Time-averaged Barnett asymmetry (late-time window) ===")
    @printf "%10s  %14s  %14s  %14s  %14s\n" "Ω_d" "p_eff" "⟨⟨F_z⟩⟩_late" "⟨⟨L_z⟩⟩_late" "Final ⟨F_z⟩"
    println("-"^80)
    avg_fz = Dict{Float64, Float64}()
    for omega_d in OMEGA_D_GRID
        r = results[omega_d]
        n = length(r.fz_t)
        half = n ÷ 2
        fz_avg = sum(r.fz_t[half:end]) / (n - half + 1)
        Lz_avg = sum(r.Lz_t[half:end]) / (n - half + 1)
        p_eff = BZ_STATIC_NT * TW.p_per_nT + omega_d
        avg_fz[omega_d] = fz_avg
        @printf "%+10.2f  %+.4f       %+.4f         %+.4f         %+.4f\n" omega_d p_eff fz_avg Lz_avg r.fz_t[end]
    end

    println("\n=== Barnett sign-flip oracle ===")
    fz_pos = avg_fz[+0.5]
    fz_neg = avg_fz[-0.5]
    if fz_pos > 0 && fz_neg < 0
        @printf "✓ Barnett sign-flip observed: +Ω→⟨F_z⟩=%+.3f, −Ω→⟨F_z⟩=%+.3f\n" fz_pos fz_neg
    elseif sign(fz_pos) == sign(fz_neg)
        @printf "✗ Same-sign drift in both directions (+Ω→%+.3f, −Ω→%+.3f) — investigate\n" fz_pos fz_neg
    else
        @printf "≈ Mixed: +Ω→%+.3f, −Ω→%+.3f\n" fz_pos fz_neg
    end

    JLD2.jldsave(OUTPUT_JLD2;
        results, OMEGA_D_GRID, BZ_STATIC_NT, B_PERP_NT, T_EVOLVE, DT,
        psi_phase1=psi_phase1_cpu,
        timestamp=string(time()),
        note="Lab-frame stir asymmetry comparison +Ω vs −Ω (post-2026-06-04 fix).",
    )
    @printf "\nWrote %s\n" OUTPUT_JLD2
end

main()
