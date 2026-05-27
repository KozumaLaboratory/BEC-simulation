#!/usr/bin/env julia
#
# klaus_magnetic_stirrer_gen.jl — Klaus-II branch (rotating B-field /
# rotating DDI anisotropy).  Distinct from the 34-cell Klaus-I scan
# (uniform rotating-frame bias H − Ω L_z).  Klaus-II is closer to the
# actual experimental "magnetic stirrer": the bias-field direction
# B̂(t) rotates in time, driving the DDI kernel
#   V_dd(r) ∝ (1 − 3(B̂ · r̂)^2) / r^3
# to rotate with it, which produces a rotating DDI ellipticity in the
# cloud and orbital mass flow.  After the B quench to weak field, that
# mass flow couples into the EdH spin-transfer channel.
#
# Implementation: replace klaus_quench's `rotating_frame_omega: Ω`
# (Klaus-I) with a time-dependent B direction in the same dynamics step:
#   B: {Bz: "−2.6e-5 Gauss", theta: π/4, phi: {rate: Ω}}
# The B magnitude stays |B| = 2.6e-5 G during the hold; theta is held
# at π/4 (45° tilt from z); phi rotates at rate Ω.
#
# Pipeline mirrors Klaus-I `hold_only` so the comparison is clean:
#   GS                z-aligned strong B (m=-F)
#   rotation_prep     z-aligned strong B (no rotation, no tilt)  10 ms
#   B_quench          B magnitude drops 0.01 → 2.6×10⁻⁵ G       1 ms
#   weak_field_hold   B tilted to π/4 and rotated at Ω         10 ms
#
# 6 cells minimum: 3 Ω points + 3 controls.  All 32³ CPU.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "magnetic_stirrer")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504
const T_ROT_MS = 10.0
const T_QUENCH_MS = 1.0
const T_HOLD_MS = 10.0
const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF
const T_HOLD = T_HOLD_MS * 1e-3 * OMEGA_REF
const C1_RATIO = 0.02778
const B_MAG_ROT = 0.01        # Gauss spherical magnitude, strong field for prep
const B_MAG_FINAL = 2.6e-5    # Gauss spherical magnitude, weak field
const THETA_TILT = 0.7854     # rad ≈ π/4 (45° from +z)
const N_ATOMS = 10_000

# Note: switching to m=+F initial state with B along +z (theta=0). This makes
# the spherical magnitude + tilt geometry clean. By the verified chirality
# symmetry (Klaus-I Gate 4), {m=+F, Ω=+0.5} is the matched chirality —
# direct mirror of {m=-F, Ω=-0.5} used in Klaus-I. So Klaus-II Ω-scan uses
# POSITIVE Ω values.

struct StirrerCell
    name::String
    omega::Float64         # phi rotation rate during hold (Ω/ω_⊥)
    ddi_on::Bool
    do_quench::Bool
    static_B::Bool         # if true: tilt but no rotation in hold
end

const CELLS = [
    # 3 Ω scan points — POSITIVE Ω (matched chirality with m=+F initial).
    StirrerCell("magnetic_stirrer_omega_p0p3",    +0.3, true,  true, false),
    StirrerCell("magnetic_stirrer_omega_p0p5",    +0.5, true,  true, false),
    StirrerCell("magnetic_stirrer_omega_p0p7",    +0.7, true,  true, false),
    # Controls (at Ω=+0.5 reference).
    StirrerCell("magnetic_stirrer_staticB_control",   +0.5, true,  true,  true),
    StirrerCell("magnetic_stirrer_DDIoff_control",    +0.5, false, true,  false),
    StirrerCell("magnetic_stirrer_noquench_control",  +0.5, true,  false, false),
]

_ddi(on, sec) = "{enabled: $(on), secular: $(sec)}"

function _config_text(c::StirrerCell)
    rate = c.static_B ? 0.0 : c.omega
    hold_B_mag = c.do_quench ? B_MAG_FINAL : B_MAG_ROT
    quench_B = c.do_quench ?
        "{B_mag: {from: $(B_MAG_ROT), to: $(B_MAG_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}" :
        "{B_mag: \"$(B_MAG_ROT) Gauss\", theta: 0.0, phi: 0.0}"
    hold_B = "{B_mag: \"$(hold_B_mag) Gauss\", theta: $(THETA_TILT), phi: {rate: $(rate)}}"

    return """
# Klaus-II magnetic-stirrer protocol — auto-generated.
# Source: scripts/validation/klaus_magnetic_stirrer_gen.jl
#
# Cell : $(c.name)
#   phi rotation rate during hold : Ω/ω_⊥ = $(rate)
#   DDI in dynamics               : $(c.ddi_on)
#   B quench applied              : $(c.do_quench)
#   static B (no rotation)        : $(c.static_B)
#   theta tilt during hold        : $(THETA_TILT) rad ≈ π/4
#   B magnitude during hold       : $(hold_B_mag) G

metadata:
  suite: magnetic_stirrer
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  ddi_on_dynamics: $(c.ddi_on)
  do_B_quench: $(c.do_quench)
  static_B: $(c.static_B)
  theta_tilt: $(THETA_TILT)
  generator: scripts/validation/klaus_magnetic_stirrer_gen.jl
  protocol_summary: |
    Klaus-II rotating-B / DDI-anisotropy stirrer. m=+F GS in +z-aligned
    strong B, then rotation_prep with no rotation, then B quench to weak
    field, then weak-field hold with B tilted at π/4 and phi rotated at Ω.
    Matched-chirality for m=+F init is Ω > 0 (Klaus-I Gate 4 verified).

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: $OMEGA_REF}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.181818]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: $OMEGA_REF
        c1_ratio: $C1_RATIO
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      B: {B_mag: "$(B_MAG_ROT) Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_plus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # rotation_prep (z-aligned, no rotation)
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      B: {B_mag: "$(B_MAG_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(c.ddi_on, false))
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 100
        psi: true
        precision: f64

  - dynamics:   # B_quench (magnitude drop, direction still z-aligned)
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      B: $quench_B
      ddi: $(_ddi(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak_field_hold WITH rotating B direction (Klaus-II hallmark)
      duration: $(round(T_HOLD; digits=5))
      dt: 0.005
      B: $hold_B
      ddi: $(_ddi(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: 100
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    println("Generating klaus_magnetic_stirrer configs in $OUTDIR")
    for c in CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(c))
        println("  wrote $name  (Ω=$(c.omega), DDI=$(c.ddi_on), quench=$(c.do_quench), static_B=$(c.static_B))")
    end
    println("Done — $(length(CELLS)) cells.")
end

main()
