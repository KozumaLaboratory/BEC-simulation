#!/usr/bin/env julia
# scripts/m2_stir_analyze.jl
#
# Decompose the M2 lab-frame stir smoke output into:
#   * time-averaged ⟨F_z⟩ and ⟨L_z⟩ (the Barnett rectified drift)
#   * oscillation amplitude at Ω_d (the Larmor / Rabi component)
#   * EdH oracle on the TIME-AVERAGED quantities (not the instantaneous
#     final snapshot — instantaneous catches whatever oscillation phase)
#
# The smoke's final-snapshot ⟨F_z⟩·⟨L_z⟩ < 0 caught the oscillation
# phase at t=40, not the drift. The relevant Barnett signature is the
# slowly-varying (period-averaged) component.

using JLD2
using Printf
using Statistics

const INPUT_JLD2 = "runs/m2_klaus_stir_smoke_postfix_2026_06_04.jld2"

function main()
    isfile(INPUT_JLD2) || error("Missing $INPUT_JLD2 — run stir smoke first.")
    d = JLD2.load(INPUT_JLD2)
    t = d["times"]
    fz = d["fz_t"]
    fx = d["fx_t"]
    fy = d["fy_t"]
    Lz = d["Lz_t"]
    Ω_d = d["OMEGA_DRIVE"]
    Bz_static = d["BZ_STATIC_NT"]
    B_perp = d["B_PERP_NT"]

    println("=== M2 lab-frame stir — time-domain decomposition ===")
    @printf "Stir params: Bz_static=%.2f nT  B_perp=%.2f nT  Ω_d=%.2f ω_ref⁻¹\n\n" Bz_static B_perp Ω_d

    # Take only second-half samples (post-transient).
    n = length(t)
    half = n ÷ 2
    t_late = t[half:end]
    fz_late = fz[half:end]
    Lz_late = Lz[half:end]
    fx_late = fx[half:end]
    fy_late = fy[half:end]

    fz_avg = mean(fz_late)
    fz_std = std(fz_late)
    Lz_avg = mean(Lz_late)
    Lz_std = std(Lz_late)
    fx_avg = mean(fx_late)
    fy_avg = mean(fy_late)

    @printf "Window: t ∈ [%.1f, %.1f] (post-transient half)\n\n" t_late[1] t_late[end]
    @printf "Time-averaged (Barnett rectified drift):\n"
    @printf "  ⟨⟨F_x⟩⟩ = %+.4f ± %+.4f   (osc amp / mean)\n" fx_avg std(fx_late)
    @printf "  ⟨⟨F_y⟩⟩ = %+.4f ± %+.4f\n" fy_avg std(fy_late)
    @printf "  ⟨⟨F_z⟩⟩ = %+.4f ± %+.4f\n" fz_avg fz_std
    @printf "  ⟨⟨L_z⟩⟩ = %+.4f ± %+.4f\n\n" Lz_avg Lz_std

    @printf "EdH oracle on time-averaged: ⟨⟨F_z⟩⟩·⟨⟨L_z⟩⟩ = %+.4e\n" fz_avg * Lz_avg
    if fz_avg * Lz_avg > 0
        println("✓ Time-averaged ⟨F_z⟩ and ⟨L_z⟩ co-aligned (Barnett-direction drift).")
    elseif abs(fz_avg) < 0.05 || abs(Lz_avg) < 0.05
        println("≈ Near-zero on one of the averages — not enough drift to test EdH.")
    else
        println("✗ Time-averaged ⟨F_z⟩ and ⟨L_z⟩ opposite signs — investigate.")
    end
    println()

    # Predict the rotating-frame effective Bz_eff per the audited
    # convention (`_shift_zeeman_for_rotating_frame`: p_eff = p_lab + Ω,
    # equivalently `H_rot = H_lab − Ω·(L_z + F_z)` makes the descent on
    # `−Ω·F_z` prefer m=+F). For a B_perp rotating CCW at +Ω_d, the
    # frame that makes B_perp static is the +Ω_d rotating frame:
    #   p_eff = p_lab + Ω_d
    # Effective field STRENGTHENS m=+F bias (sum, NOT difference).
    p_per_nT_eu = 0.163
    omega_L = Bz_static * p_per_nT_eu
    p_eff = omega_L + Ω_d
    @printf "Larmor freq ω_L = p_lab = %.4f (at Bz=%.1f nT)\n" omega_L Bz_static
    @printf "Rotating-frame p_eff = p_lab + Ω_d = %+.4f\n" p_eff
    if p_eff > 0
        println("Prediction: p_eff > 0 → ⟨⟨F_z⟩⟩ should drift POSITIVE toward +F=+6 (m=+F preferred).")
    elseif p_eff < 0
        println("Prediction: p_eff < 0 → ⟨⟨F_z⟩⟩ should drift NEGATIVE toward −F=−6 (m=−F preferred).")
    else
        println("Prediction: p_eff ≈ 0 → no rotating-frame bias.")
    end
    println()

    consistent_with_pred = sign(fz_avg) == sign(p_eff)
    if abs(fz_avg) < 0.05
        println("Drift sign UNDETERMINED at current params (too close to zero).")
    elseif consistent_with_pred
        println("✓ Drift direction matches the rotating-frame prediction.")
    else
        println("✗ Drift direction OPPOSITE to rotating-frame prediction — investigate.")
    end

    @printf "\nNote: ⟨F_z⟩ at t=40 = %+.3f; saturation target +F = +6.\n" fz[end]
    @printf "Drift still ramping — equilibration NOT reached at T=%.1f.\n" t[end]
    @printf "Quantitative τ_pump fit requires longer T (and resolution of M0 anomaly).\n"
end

main()
