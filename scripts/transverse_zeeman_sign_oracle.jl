#!/usr/bin/env julia
# scripts/transverse_zeeman_sign_oracle.jl
#
# Static EdH oracle test: with a STATIC transverse B field at +Bx and
# no other fields, the spinor GS must satisfy ⟨F_x⟩ ≈ +F (the spin
# aligns WITH the magnetic field per the standard Zeeman convention
# H = −μ·B = −γ·B·F, low energy when F is parallel to B).
#
# In SpinorBEC convention:
#   * z-Zeeman: H_z = −p·F_z (zeeman.jl:6 docstring, energy.jl:165 verified).
#     For +p (positive Bz), GS has ⟨F_z⟩ ≈ +F. Consistent: tested daily.
#   * Transverse Zeeman: code applies +bx·F_x + by·F_y
#     (combined_spin_step.jl:78 comment + line 95-96 implementation).
#     If bx = positive Bx (user-facing convention), this puts +F_x term
#     in H — REPELS spin from +x → predicts ⟨F_x⟩ ≈ −F.
#
# This script runs the test and checks which sign actually wins. If
# ⟨F_x⟩ → −F, the transverse Zeeman has the OPPOSITE convention from z,
# and the user-facing API silently flips Bx vs Bz signs — load-bearing
# for the Barnett asymmetry M2 work.

import CUDA
using SpinorBEC
using Printf
const TW = eu151_preset()
const BX_NT = 5.0           # +5 nT in +x direction
const N_ITP = 1000

function main()
    println("=== Transverse Zeeman sign EdH oracle ===")
    @printf "Static Bx = +%.1f nT (Bz = By = 0); ITP for %d steps\n\n" BX_NT N_ITP
    @printf "z-Zeeman convention (zeeman.jl): H_z = -p·F_z → +p gives ⟨F_z⟩ ≈ +F\n"
    @printf "Transverse (combined_spin_step.jl:78,95): H_trans = +bx·F_x + by·F_y\n"
    @printf "  → If consistent with z (H = -μ·B), should be -bx·F_x ...\n"
    @printf "  → Code uses +bx → predicts ⟨F_x⟩ ≈ -F (REVERSED)\n\n"

    p_x = BX_NT * TW.p_per_nT       # interpret amplitude as if "p"-scaled like z
    zeeman = TimeDependentZeeman(
        ConstantWaveform(p_x), ConstantWaveform(0.0),   # bx = p_x, by = 0
        ConstantWaveform(0.0), ConstantWaveform(0.0),   # p_z = 0, q = 0
    )
    sys = SpinSystem(TW.F)
    psi_init = init_psi(TW.grid, sys; state=:polar)
    add_white_noise!(psi_init, 0.01, 1, TW.grid)

    r = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP, tol=1e-8,
        initial_state=:polar, verbose=false, psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=0.0, backend=CUDABackend(),
    )
    psi_cpu = Array(r.workspace.state.psi)
    sm = r.workspace.spin_matrices
    dV = SpinorBEC.cell_volume(TW.grid)
    fx, fy, fz = spin_density_vector(psi_cpu, sm, 3)
    Fx_tot = sum(fx) * dV
    Fy_tot = sum(fy) * dV
    Fz_tot = sum(fz) * dV
    norm² = sum(abs2, psi_cpu) * dV

    @printf "Result after %d ITP steps (E=%.4f, ‖ψ‖²=%.6f):\n" N_ITP r.energy norm²
    @printf "  ⟨F_x⟩ = %+.4f\n" Fx_tot
    @printf "  ⟨F_y⟩ = %+.4f\n" Fy_tot
    @printf "  ⟨F_z⟩ = %+.4f\n\n" Fz_tot

    println("=== Verdict ===")
    if Fx_tot > 1.0
        @printf "✓ ⟨F_x⟩ = +%.2f > 0 → spin aligns WITH +Bx as standard Zeeman demands.\n" Fx_tot
        println("  Transverse and longitudinal Zeeman conventions AGREE.")
    elseif Fx_tot < -1.0
        @printf "✗ ⟨F_x⟩ = %+.2f < 0 → spin aligns AGAINST +Bx.\n" Fx_tot
        println("  Transverse Zeeman has OPPOSITE sign convention from longitudinal.")
        println("  Real sign bug: combined_spin_step.jl line 95-96 should be `.- bx` not `.+ bx`")
        println("  (or, equivalently, the user-facing bx/by amplitude convention is FLIPPED).")
        println("\n  This is the same bug class as the Coriolis sign + GPU energy missing-term.")
        println("  Causes the lab-frame stir to pump ⟨F_z⟩ in the OPPOSITE direction from")
        println("  what the EdH oracle predicts (CCW rotation → spin should align +z, but")
        println("  we observed it pumped to −z in the asymmetry smoke).")
    else
        @printf "≈ ⟨F_x⟩ = %+.2f — sub-saturated. Increase Bx or N_ITP to disambiguate.\n" Fx_tot
    end
end

main()
