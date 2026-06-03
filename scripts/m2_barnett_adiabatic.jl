#!/usr/bin/env julia
# scripts/m2_barnett_adiabatic.jl
#
# M2 Fig4 anchor: lab-frame stir in the PROPERLY ADIABATIC regime
# (Ω_d ≪ ω_L) so the Barnett polarization sign is unambiguous and not
# masked by above-resonance Rabi mixing.
#
# Setup: Bz_static = 10 nT → p_lab = 1.63 ω_ref (Larmor 1.63 rad/ω_ref).
# Ω_d = 0.05 (much less than Larmor → adiabatic regime).
# B_perp = 0.5 nT → p_perp/p_lab = 0.05 (perturbative).
#
# Post-2026-06-04 transverse-Zeeman sign fix is in place, so the
# observable should follow the user-spec convention: in the rotating
# frame at +Ω_d, p_eff = p_lab + Ω_d > 0, so ⟨F_z⟩ drifts toward +F.
#
# Compares +Ω_d vs −Ω_d to verify the sign-flip asymmetry. Long T
# (80 ω_ref⁻¹) so the rectified drift dominates over transient Rabi.

import CUDA
using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const BZ_STATIC_NT = 10.0       # strong Bz for clear Larmor
const B_PERP_NT = 0.5            # perturbative transverse
const OMEGA_D_GRID = [+0.05, -0.05]  # adiabatic: Ω_d ≪ ω_L
const T_EVOLVE = 80.0
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))
const SAMPLE_EVERY = 100
const N_ITP_PHASE1 = 500
const OUTPUT_JLD2 = "runs/m2_barnett_adiabatic_2026_06_04.jld2"

sin_freq(omega_d) = omega_d / (2π)

function spin_sum(psi_cpu, sm, dV)
    fx, fy, fz = spin_density_vector(psi_cpu, sm, 3)
    return sum(fx) * dV, sum(fy) * dV, sum(fz) * dV
end

function run_one(omega_d::Float64, psi_phase1_cpu, sm, dV)
    println("\n--- Phase 2 stir at Ω_d = $omega_d ---")
    p_static = BZ_STATIC_NT * TW.p_per_nT
    p_perp = B_PERP_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(p_static), ConstantWaveform(0.0),
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(omega_d), phase=π/2),
        SinusoidalWaveform(; amplitude=p_perp, frequency=sin_freq(omega_d), phase=0.0),
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
    fz_t = Float64[]
    Lz_t = Float64[]
    fx0, fy0, fz0 = spin_sum(psi_phase1_cpu, sm, dV)
    push!(fz_t, fz0)
    push!(Lz_t, orbital_angular_momentum(psi_phase1_cpu, ws.grid, ws.fft_plans))

    t0 = time()
    for step in 1:N_STEPS
        SpinorBEC.split_step!(ws)
        if step % SAMPLE_EVERY == 0
            psi_cpu = Array(ws.state.psi)
            _, _, fz = spin_sum(psi_cpu, sm, dV)
            Lz = orbital_angular_momentum(psi_cpu, ws.grid, ws.fft_plans)
            push!(times, step * DT)
            push!(fz_t, fz)
            push!(Lz_t, Lz)
            if step % (SAMPLE_EVERY * 20) == 0
                @printf "  t=%6.2f  ⟨F_z⟩=%+.4f  ⟨L_z⟩=%+.4f\n" (step * DT) fz Lz
                flush(stdout)
            end
        end
    end
    @printf "  Phase-2 wall: %.1fs\n" (time() - t0)
    CUDA.reclaim()
    return (times=times, fz_t=fz_t, Lz_t=Lz_t, psi_final=Array(ws.state.psi))
end

function main()
    println("=== M2 Barnett ADIABATIC stir ===")
    @printf "Bz_static = %.1f nT (p_lab = %.3f, T_Larmor = %.2f ω⁻¹)\n" BZ_STATIC_NT (BZ_STATIC_NT * TW.p_per_nT) (
        2π / (BZ_STATIC_NT * TW.p_per_nT)
    )
    @printf "B_perp    = %.2f nT (B_perp/Bz = %.3f, perturbative)\n" B_PERP_NT (B_PERP_NT / BZ_STATIC_NT)
    @printf "Ω_d       = %s (adiabatic ratio Ω_d/ω_L = %.4f)\n" string(OMEGA_D_GRID) (
        OMEGA_D_GRID[1] / (BZ_STATIC_NT * TW.p_per_nT)
    )
    @printf "T_evolve  = %.1f ω⁻¹ = %.0f ms physical\n\n" T_EVOLVE (T_EVOLVE * 1000 / TW.omega_ref)

    p_static = BZ_STATIC_NT * TW.p_per_nT
    zeeman_phase1 = TimeDependentZeeman(
        ConstantWaveform(p_static), ConstantWaveform(0.0),
        ConstantWaveform(0.0), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)
    println("--- Phase 1: ITP equilibrate at Ω=0, static Bz ---")
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_phase1, potential=TW.potential,
        dt=DT, n_steps=N_ITP_PHASE1, tol=1e-7,
        initial_state=:m_plus_F, verbose=false,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=0.0, backend=CUDABackend(),
    )
    sm = r_itp.workspace.spin_matrices
    psi_phase1_cpu = Array(r_itp.workspace.state.psi)
    fx0, fy0, fz0 = spin_sum(psi_phase1_cpu, sm, dV)
    @printf "  E=%.4f  ⟨F_z⟩=%+.3f (FM_z seed at +Bz: expect ≈ +F)\n\n" r_itp.energy fz0

    results = Dict{Float64, Any}()
    for omega_d in OMEGA_D_GRID
        results[omega_d] = run_one(omega_d, psi_phase1_cpu, sm, dV)
    end

    println("\n=== Time-averaged late-window (adiabatic) ===")
    @printf "%10s  %14s  %14s\n" "Ω_d" "⟨⟨F_z⟩⟩" "⟨⟨L_z⟩⟩"
    println("-"^50)
    fz_results = Dict{Float64, Float64}()
    for omega_d in OMEGA_D_GRID
        r = results[omega_d]
        n = length(r.fz_t)
        half = n ÷ 2
        fz_avg = sum(r.fz_t[half:end]) / (n - half + 1)
        Lz_avg = sum(r.Lz_t[half:end]) / (n - half + 1)
        fz_results[omega_d] = fz_avg
        @printf "%+10.3f  %+.4f       %+.4f\n" omega_d fz_avg Lz_avg
    end

    println("\n=== Barnett sign asymmetry ===")
    f_pos = fz_results[+0.05]
    f_neg = fz_results[-0.05]
    Δf = f_pos - f_neg
    @printf "Δ⟨F_z⟩(+Ω - -Ω) = %+.4f\n" Δf
    if abs(Δf) > 0.05
        if Δf > 0
            println("✓ Barnett asymmetry observed: +Ω → more positive ⟨F_z⟩")
            println("  Per audited convention p_eff = p_lab + Ω, +Ω strengthens +z bias.")
        else
            println("✗ Reversed: −Ω → more positive ⟨F_z⟩ — investigate")
        end
    else
        println("≈ Asymmetry below detection — increase T_evolve or B_perp/Bz")
    end

    JLD2.jldsave(OUTPUT_JLD2; results, OMEGA_D_GRID, BZ_STATIC_NT, B_PERP_NT,
        T_EVOLVE, DT,
        timestamp=string(time()),
        note="Adiabatic-regime Barnett asymmetry, post-transverse-Zeeman fix.")
    @printf "\nWrote %s\n" OUTPUT_JLD2
end

main()
