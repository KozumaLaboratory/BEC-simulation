#!/usr/bin/env julia
#
# barnett_eu_window_gen.jl — Klaus/Barnett parameter window for Eu.
# Per anko's 2026-05-26 framing: deliver "適正パラメータ窓 identification",
# not "Barnett 効果の再現". Goal of this YAML set:
#
#   Show that Barnett spin response (Ω-induced ⟨F_z⟩ change) appears
#   in a parameter regime where (i) signal is non-trivial, (ii) sign
#   reverses with Ω → −Ω, (iii) DDI is the source (DDI=off control
#   should suppress the signal), (iv) the system stays stable
#   (no collapse, no vortex chaos, N conserved).
#
# Minimum matrix (anko's spec, 6 cells):
#   Ω ∈ {−0.5, 0, +0.5}  (sign-reversal control)
#   DDI ∈ {on, off}      (origin control)
#
# All other params: Matsui-like (near-isotropic trap, N=1e4 for fast
# scan, B = 2.6 nT, m=−F initial). This is the EXPERIMENTAL geometry,
# NOT the cigar stress test.
#
# Cost: CPU 32³ × 6 cells × ~6 min ≈ 36 min. GPU at 64³ later for
# anchor confirmation.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "barnett_eu_window")
mkpath(OUTDIR)

const T_EVOLUTION = 10.0      # ~14.5 ms; modest hold to see Barnett build-up
const SAVE_EVERY = 50
const N_ATOMS = 10_000
const OMEGA_REF = 2π * 110.0  # rad/s (Matsui ω_⊥)
const OMEGA_Z_RATIO = 130.0 / 110.0

function _config_text(Omega_rot::Float64, ddi_on::Bool)
    ddi_block = ddi_on ?
        """
      ddi:
        enabled: true
        secular: false
""" : """
      ddi:
        enabled: false
"""
    sign_label = Omega_rot > 0 ? "p" : (Omega_rot < 0 ? "m" : "z")
    omega_abs = abs(Omega_rot)
    return """
# Klaus/Barnett parameter window — auto-generated.
# Source: scripts/validation/barnett_eu_window_gen.jl
# Ω/ω_ref = $Omega_rot, DDI = $ddi_on

metadata:
  suite: barnett_eu_window
  ladder_level: 0
  rotating_frame_omega: $Omega_rot
  ddi_on: $ddi_on
  generator: scripts/validation/barnett_eu_window_gen.jl
  notes: |
    Eu-151 F=6 in near-isotropic Matsui-like trap.
    Rotation Ω applied in rotating frame; DDI on/off as origin control.
    Initial m=-F polarized. B = 2.6 nT (weak, post-quench Matsui value).
    Target observables: ⟨F_z⟩(t), ⟨L_z⟩(t), ⟨J_z⟩(t), peak density, N(t).

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: $(round(OMEGA_REF; digits=4))}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $(round(OMEGA_Z_RATIO; digits=6))]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: $(round(OMEGA_REF; digits=4))
        c1_ratio: 0.02778                        # Matsui best-fit
$(ddi_block)      lhy: {kind: none}
      B: {Bz: "-0.01 Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9

  - dynamics:
      duration: $T_EVOLUTION
      dt: 0.005
      rotating_frame_omega: $Omega_rot          # ← Barnett rotation
      B:
        Bz: {from: -0.01, to: -2.6e-5, duration: 0.0}
        theta: 0.0
        phi: 0.0
$(ddi_block)      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: $SAVE_EVERY
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

# 14-cell expanded scan: 9 DDI-on Ω points + 5 DDI-off controls.
# Sign-asymmetric Barnett response curve + origin verification.
for (Omega, ddi_on) in [
    # DDI on: full Ω curve including signs
    (-0.9, true), (-0.7, true), (-0.5, true), (-0.3, true),
    (0.0, true),
    (+0.3, true), (+0.5, true), (+0.7, true), (+0.9, true),
    # DDI off: control at key points
    (-0.7, false), (-0.5, false), (0.0, false),
    (+0.5, false), (+0.7, false),
]
    sign_lab = Omega > 0 ? "p" : (Omega < 0 ? "m" : "z")
    ddi_lab = ddi_on ? "DDIon" : "DDIoff"
    abs_lab = replace(string(abs(Omega)), "." => "p")
    name = "barnett_eu_om$(sign_lab)$(abs_lab)_$(ddi_lab).yaml"
    path = joinpath(OUTDIR, name)
    write(path, _config_text(Omega, ddi_on))
    println("wrote $name (Ω=$Omega, DDI=$ddi_on)")
end
