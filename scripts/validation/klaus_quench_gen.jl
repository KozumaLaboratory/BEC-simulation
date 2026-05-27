#!/usr/bin/env julia
#
# klaus_quench_gen.jl — anko 2026-05-26 evening pivot.
#
# 2-phase Klaus protocol scan: rotation prep at strong B → quench to weak
# B → free hold. Question is which Ω most efficiently excites m=−5, m=−4
# spin components when the system is dropped into the weak-field regime,
# not which Ω gives the largest bare ⟨F_z⟩ response (that was the prior
# Barnett scan).
#
# 10 cells × 32³ CPU. Pipeline per cell:
#   GS              :  B = -0.01 G, Ω = 0,   DDI on,  secular GS
#   rotation_prep   :  B = -0.01 G, Ω = Ωc,  DDI on,  full MDDI
#   B_quench        :  B ramps -0.01 → -2.6e-5 G over 1 ms, Ω = 0
#   weak_field_hold :  B = -2.6e-5 G,        Ω = 0,  DDI on, full MDDI
#
# Controls:
#   ddi_off            : DDI off in all dynamics steps (GS keeps DDI on)
#   no_B_quench        : B stays at -0.01 G; quench + hold steps run at B_rot
#   keep_rot           : Ω = Ωc maintained through quench + hold steps too
#
# All `backend: cpu` per the rotating_frame_omega + GPU scalar-indexing
# gotcha (memory `gotcha_rotating_frame_omega_gpu_scalar_indexing.md`).

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504          # 2π · 110 Hz (Matsui-like ω_⊥)
const T_ROT_MS = 10.0               # rotation prep
const T_QUENCH_MS = 1.0             # B ramp
const T_HOLD_MS = 10.0              # weak-field hold

const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF        # 6.9115 ω_ref⁻¹
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF  # 0.69115
const T_HOLD = T_HOLD_MS * 1e-3 * OMEGA_REF      # 6.9115

const N_ATOMS = 10_000
const C1_RATIO = 0.02778            # Matsui best fit
const B_ROT = -0.01                 # Gauss; strong field for rotation prep
const B_FINAL = -2.6e-5             # Gauss; weak field (Matsui post-quench)

struct Cell
    name::String
    omega::Float64
    ddi_on::Bool
    do_quench::Bool
    keep_rot::Bool
end

const CELLS = [
    # Core 6-point Ω scan (DDI on, full protocol with quench, rotation off in hold).
    Cell("klaus_quench_om0p0",     0.0, true, true, false),
    Cell("klaus_quench_omm0p3",   -0.3, true, true, false),
    Cell("klaus_quench_omm0p5",   -0.5, true, true, false),
    Cell("klaus_quench_omm0p7",   -0.7, true, true, false),
    Cell("klaus_quench_omp0p3",   +0.3, true, true, false),
    Cell("klaus_quench_omp0p5",   +0.5, true, true, false),
    # Controls.
    Cell("klaus_quench_omm0p3_DDIoff",   -0.3, false, true,  false),
    Cell("klaus_quench_omm0p5_DDIoff",   -0.5, false, true,  false),
    Cell("klaus_quench_omm0p5_noBquench", -0.5, true,  false, false),
    Cell("klaus_quench_omm0p5_keeprot",  -0.5, true,  true,  true),
]

_ddi_block(ddi_on, secular) = "{enabled: $(ddi_on), secular: $(secular)}"

function _config_text(c::Cell)
    rot_omega = c.omega
    quench_omega = c.keep_rot ? c.omega : 0.0
    hold_omega = c.keep_rot ? c.omega : 0.0

    # B in quench step: ramp if do_quench, else constant at B_ROT.
    quench_B = c.do_quench ?
        "{Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"
    # B in hold step: B_FINAL if do_quench, else B_ROT (no quench).
    hold_B = c.do_quench ?
        "{Bz: \"$(B_FINAL) Gauss\", theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"

    return """
# Klaus 2-phase quench protocol — auto-generated.
# Source: scripts/validation/klaus_quench_gen.jl
#
# Cell : $(c.name)
#   Ω/ω_⊥ rotation prep   : $(c.omega)
#   Ω/ω_⊥ quench + hold   : $(quench_omega) / $(hold_omega)
#   DDI in dynamics       : $(c.ddi_on)
#   B quench applied      : $(c.do_quench)
#   rotation kept in hold : $(c.keep_rot)
#
# Pipeline:
#   GS (Ω=0, B=$(B_ROT) G, DDI on)
#   → rotation_prep ($(T_ROT_MS) ms, B=$(B_ROT) G, Ω=$(rot_omega), DDI=$(c.ddi_on))
#   → B_quench ($(T_QUENCH_MS) ms, B ramp $(c.do_quench), Ω=$(quench_omega), DDI=$(c.ddi_on))
#   → weak_field_hold ($(T_HOLD_MS) ms, B=$(c.do_quench ? B_FINAL : B_ROT) G, Ω=$(hold_omega), DDI=$(c.ddi_on))

metadata:
  suite: klaus_quench
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  ddi_on_dynamics: $(c.ddi_on)
  do_B_quench: $(c.do_quench)
  rotation_kept_in_hold: $(c.keep_rot)
  generator: scripts/validation/klaus_quench_gen.jl
  protocol_summary: |
    Rotation preparation at strong B → quench to weak B → free hold.
    Observable: post-quench spin excitation in m=-5, m=-4 components.

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
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # rotation_prep
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: $(rot_omega)
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 100
        psi: true
        precision: f64

  - dynamics:   # B_quench
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      rotating_frame_omega: $(quench_omega)
      B: $quench_B
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak_field_hold
      duration: $(round(T_HOLD; digits=5))
      dt: 0.005
      rotating_frame_omega: $(hold_omega)
      B: $hold_B
      ddi: $(_ddi_block(c.ddi_on, false))
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
    println("Generating klaus_quench configs in $OUTDIR")
    for c in CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(c))
        println("  wrote $name (Ω=$(c.omega), DDI=$(c.ddi_on), quench=$(c.do_quench), keep_rot=$(c.keep_rot))")
    end
    println("Done — $(length(CELLS)) cells.")
end

main()
