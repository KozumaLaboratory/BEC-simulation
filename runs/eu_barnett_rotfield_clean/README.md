# Rotating field → vortices + Barnett spin excitation (direction-controlled)

> **Vintage: 2026-07-23. Archived record, not current evidence.** Two specific
> things were found wrong after these runs were produced, and both touch the
> headline:
>
> - **The ±Ω arms were not mirror images.** `SinusoidalWaveform` is `sin`, and
>   the sign check below assumed `cos`, so the +Ω arm starts anti-aligned to the
>   ground-state spin. The *rotation senses* here are right; the *chirality
>   magnitude* is confounded. The mirror arm is built by negating `By`. Corrected
>   in #141 (`redo/barnett-rotating-field`), which is the version to quote.
> - **The scalar LHY coefficient was short by π·(a_s/a_ho)·√N** until #108
>   (2026-07-27). Every run here used `lhy: {kind: scalar}`, so the LHY term was
>   7–12× too weak.
>
> Also predating these runs' successors: #125 (tabulated LHY dropped on the GPU
> broadcast path), #143 (dealias `k_cut` assumed L=12 on every axis). See
> `docs/validation/stored_results_vintage_audit.md` for the general statement.
>
> What survives unconditionally is the **tooling** — the runners, the TSUBAME
> NVMe-scratch guards, the analysis scripts, and the J_z-ledger diagnostics —
> which is most of what this directory is for.
>
> **The five `edh_*.yaml` configs here were sign-corrected before landing**, so
> they no longer reproduce the archived numbers. They had `Bz: "-0.01 Gauss"` in
> the ground state against `from: 0.01` in the dynamics ramp — the field flipped
> sign at t=0 — and the negative ground-state value selects m=+F under current
> code anyway (measured; see the Zeeman-convention gate). Leaving them as-is
> would have preserved the archive at the cost of shipping five configs that are
> wrong to re-run, which is the worse trade.

¹⁵¹Eu (F=6) dipolar BEC, 32³, N=30000, a_s=110a₀ (ε_dd<1, no collapse),
full DDI (non-secular), scalar LHY, GPU, unitary (no loss). All angular
momenta in ℏ/atom.

## Results

### 1. Einstein-de Haas: real vortices + real spin excitation (`figures/edh_baseline.png`)
`edh_baseline.yaml`: m=+6 GS → step-quench Bz (strong→weak) → DDI drives
spin relaxation.
- ⟨F_z⟩ +6 → +1.5 (m-ladder cascade, reaches negative m) = spin excitation.
- ⟨L_z⟩ 0 → +4.5; **J_z = F_z+L_z ≈ 6 conserved** (spin→orbital transfer).
- Real vortex in transferred m=+4: density ring + central hole + 2π winding.
- Chirality here is set by the initial spin (J_z=+6), NOT rotation.

### 2. Direction control needs J_z=0 start (`figures/barnett_direction_definitive.png`)
`run_transverse_barnett.jl`: GS with **B along +x** → transverse spin,
⟨F_z⟩=0, J_z=0 → quench + field **rotating around z** at Ω∈{+0.5,0,−0.5}.
- **Ω=0 control: ⟨F_z⟩=⟨L_z⟩=0 for all time** — rotation is the cause.
- **⟨L_z⟩(+Ω) = −⟨L_z⟩(−Ω) exactly** (mirror residual 0%); vortices reverse.
- **⟨F_z⟩(+Ω) = −⟨F_z⟩(−Ω) exactly** — Barnett magnetization, direction-set.
- Vortex chirality: +Ω → net winding −2, −Ω → +2 (real density cores).
- Exact mirror because the setup is symmetric under Ω→−Ω combined with z→−z.

**Preferred left/right figure — `figures/barnett_direction_lines.png`** (line-based,
no density heatmaps), run at the **optimal Ω=0.30** (dense-scan vortex peak),
`run_direction_compare.jl` → `plot_direction_lines.py`:
- (a) ⟨L_z⟩(t), (b) ⟨F_z⟩(t): +Ω (CCW) and −Ω (CW) are **exact mirror
  images** (residual 0.0e+00 — the seed-free run is symmetric under
  Ω→−Ω, y→−y, so the −Ω run *is* the y-reflection of +Ω); Ω=0 flat.
- (c) J_z = F_z+L_z is **pumped by the drive** (mirror-antisymmetric),
  NOT conserved — the rotating field exerts a torque about z. (Contrast the
  field-quench EdH baseline where J_z *is* conserved.)
- (d) transverse spin (⟨F_x⟩,⟨F_y⟩) winds **CCW for +Ω, CW for −Ω** — the
  rotation sense read straight off the spin, no heatmap needed.
- (e) |⟨F⟩| falls from 6 for all three (incl. Ω=0) — genuine DDI-driven
  depolarisation, not frozen Larmor. The Ω=0 control depolarises but keeps
  L_z=F_z=0, isolating rotation as the sole source of the axial signal.

### Why a naive m=+F rotating-field run does NOT show clean direction dependence
`run_rotfield_dyn.jl` (m=+6 start): the EdH from the initial spin (J_z=+6)
dominates; ±Ω only modulate it ~20–30% (oscillatory, sign-consistency≈0).
The J_z=0 start removes that bias so rotation alone sets the chirality.

### 2b. One-sided (chiral) excitation via magnetic resonance (`figures/resonance_onesided.png`)
The transverse J_z=0 setup gives an *exact ±Ω mirror* — both senses excite
equally, opposite sign. To instead get **one sense that excites and one that
does nothing**, break the mirror with a static bias. `run_resonance_compare.jl`:
start fully polarised at the **top of the ladder** (m=+F, ⟨F_z⟩≈+5.85) with a
**static B_z** (Bz=−3.07e-5 G → p=+0.5, so m=+F is the *ground* state, stable;
q=0 keeps the ladder harmonic). A transverse field rotating at **Ω=ω_L=0.5**:
- **−Ω co-rotating = RESONANT**: drags the whole ladder down —
  ⟨F_z⟩ 5.85→1.2 (Δ=4.6), |⟨F⟩| 5.85→2.2 (depolarised), peak ⟨L_z⟩=−2.5
  (EdH vortices).
- **+Ω counter-rotating = off-resonant** (detuned by 2ω_L=1.0): ⟨F_z⟩ 5.85→5.7
  (Δ=0.17), |F| unchanged, ⟨L_z⟩≈0 — **nothing happens**.
- **no drive**: ⟨F_z⟩ Δ=0.05 — confirms the top state is stable with the field
  on (the off-resonant drive sits just above this floor).
- **Selectivity ΔF_z ratio ≈ 28×.** Reverse the field's rotation sense and the
  *same* atoms either fully excite or stay frozen. Standard rotating-wave /
  co-vs-counter-rotating resonance selection, now with EdH vortices on the
  resonant side. Line-based figure (no density heatmaps).

### 2c. Field-UP metastable variant + relaxation time (`figures/fieldup_onesided.png`)
Same idea but with the field applied **UP** (+z), so the top state m=+F is the
**metastable EXCITED** state (a "field-applied, finite-lifetime" preparation).
`run_field_test.jl`. Key regime finding:
- At ω_L=0.5 the field-up m=+F is **dynamically unstable** (τ≈4): it fully
  relaxes on its own regardless of drive — no selectivity.
- Raising the Zeeman gap **above the DDI energy scale** (ω_L=5, Bz=+3.07e-4 G)
  **Zeeman-suppresses** the spontaneous m→m−1 relaxation (τ≈20). Then only the
  resonant **+Ω** co-rotating drive excites: it coherently **Rabi-flops** the
  spin +5.8↔−5.5 (ΔF_z=11.3, t₅₀=1.6, |F| kept high); **−Ω** counter-rotating
  ≈ the slow no-drive relaxation baseline. One-sided, field-up, finite lifetime.
- **Tradeoff**: the large-gap resonant drive is a *coherent* flip with **few
  vortices** (L_z≈0.5); the EdH vortices live in the *slow relaxation* channel
  (L_z≈1.3).

### 2d. Best field tilt (cone) angle (`figures/cone_angle_scan.png`)
`run_angle_scan.jl`: single tilted field of fixed magnitude (γB=5.1) precessed
about z at cone angle θ — B∥=B cosθ sets the gap ω_L=5.1 cosθ (=resonant Ω),
B⊥=B sinθ sets the Rabi rate Ω_R=5.1 sinθ. Scanned θ∈{12,25,40,55}°, +Ω vs −Ω:
- The **resonant flip is full (swing≈11.3) at every θ** — only the *rate*
  changes (Ω_R∝sinθ, so larger θ flips faster).
- **One-sidedness degrades with θ**: selectivity (res/off swing) 5.4× (12°) →
  4.8× (25°) → 3.4× (40°) → 1.9× (55°), because as θ grows ω_L shrinks — the
  counter-rotating term stops being detuned and spontaneous relaxation returns.
- **Vortices grow with θ** (resonant peak |L_z|: 0.65→1.18→1.21→0.39; the
  off-resonant/relaxation channel reaches 2.6 at 40°).
- **Recommended θ ≈ 25°** — near-maximal selectivity (4.8×, clean one-sided)
  while ~doubling the resonant vortex content vs the small-angle limit. Small θ
  (~12°) if pure one-sidedness matters most; θ ≳ 40° trades it away for vortices.
Requires the **large field** (ω_L ≳ 5) so the metastable relaxation stays slow;
at small ω_L the state relaxes before any angle helps.

### 3. Optimization: response vs rotation Ω and field strength (`figures/optimization_scaling.png`)
Transverse start, converged box=18 GS, peak amplitudes over the drive.
**Densely resolved** — 41 points in Ω, 30 in B_perp (GS-shared `from_jld2`
runs, `run_dense_sweep.jl`); the earlier 6-point scan aliased the peaks.
- **vs Ω** (rotation rate): the vortex ⟨L_z⟩ and Barnett ⟨F_z⟩ optima are
  **distinct**, which the dense scan resolves and the sparse one did not:
  vortex peaks **sharply at Ω≈0.30** (‖L_z‖≈1.55), Barnett peaks **broadly
  at Ω≈0.40** (‖F_z‖≈3.73). Both rise from 0 at Ω=0 and fall as Ω→ω_⊥=1
  (centrifugal deconfinement).
- **vs B_perp** (rotating-field amplitude, Ω=0.5): Barnett peaks at
  **B_perp≈3.7e-5 G** (‖F_z‖≈4.03); the vortex ⟨L_z⟩ is non-monotonic —
  a first shoulder near ≈3e-5 G, a dip, then a **global peak at ≈9.8e-5 G**
  (‖L_z‖≈2.43) before the spin locks to the field at large B. This
  two-scale vortex structure is only visible with the dense sampling.
- **vs B_z** (static bias) — panel (c), and the **2D Ω×B_perp heatmap**
  (`figures/optimization_2d.png`): the joint optimum surface.

### 4. Animation (`vortex_animation.mp4` / `.html`)
+Ω / Ω=0 / −Ω side by side, vortex-host density + current streamlines,
24 fps (temporally interpolated), fixed layout, live ⟨L_z⟩/⟨F_z⟩ readout.
mp4 is pausable/scrubbable in any player / PowerPoint; the `.html` wraps it
with browser play/pause controls.

### 5. Two-stage mechanical Barnett: vortex orbital AM → net axial spin
(`figures/fig1_conversion.png`, `figures/fig2_robustness.png`)
Healthy polarised start (γB=15 magnetostriction GS) → Klaus stir (Ω=0.74) → quench
B→0. The released vortex orbital AM **converts** to a real net axial magnetisation:
**L_z 10.9 → 5.7, F_z 0.18 → +2.14** (F_z/|F| = 0.99, fully axial). Box/grid/dt
robust: settled F_z = +2.09 / +1.89 / +1.77 across box±10 / box±14 / dt2e-4 — not
a numerical artefact. (Needs the clean box±10; the ±6 box overflows and *inverts*
the physics — see SUCCESS_CRITERIA.)

### 5b. Chirality: rotation-driven (sign follows Ω), mirror broken by F=6 depolarisation
(`figures/fig3_chirality_3pt.png`, `figures/chirality.png`)
Same transverse (F_z=0) start, stir rotation sense flipped via `RB_STIR_BXPHASE`:
**+Ω → F_z +2.09, Ω=0 → +0.02, −Ω → −0.52.** The sign is set by the rotation and
Ω=0 does nothing → the two-stage Barnett is genuinely rotation-driven. The ±Ω
magnitude does **not** mirror (−Ω nucleates weaker vortices, L_z −4.8 vs +12.1)
because the CW stir depolarises the F=6 state more (|F| 5.0 vs 6.0) — a real F=6
chiral effect, so the claim is "direction-controlled", not "±Ω-symmetric".

### 5c. Residual J_z is numerical, not dissipation (`figures/dtcheck.png`)
box±14, +Ω, dt4e-4 vs dt2e-4: the F_z conversion is dt-robust (+1.85 vs +1.77)
while the residual J_z moves with dt (+6.48 → +7.77) → the leak is a
grid/time-discretisation effect, not a physical dissipation channel.

### 5d. m=−6 floor rectification — vortex chirality read off at the spin floor
(`figures/fig_m6_ladder.png`)
Imprint an orbital vortex ℓ=+1 / 0 / −1 on the F_z=−6 floor, quench B→0.
**ℓ=−1 pins ~30 % at m=−6; ℓ=+1 cascades up (peak m=−3, ~5 % at m=−6)**; ℓ=0 is
the field-free baseline. The orbital-vortex sign rectifies against the spin floor.

## Scripts
- `edh_baseline.yaml`, `run_rotfield_dyn.jl`, `run_transverse_barnett.jl`
- `analyze_barnett.jl <result.jld2> <Omega> <out.csv> <snapdir>` —
  recomputes L_z/F_z/J_z + winding vortex-census + per-m from psi
  snapshots (the lab-frame spinor save path stores F_z but not L_z).
- `plot_edh_baseline.py`, `plot_definitive.py`
- **Two-stage (§5):** `run_rebuild.jl` (GS→stir→quench; env knobs `RB_STIR_BXPHASE`
  = ±Ω sense, `RB_OMEGA`, `RB_STIR_AMP`=0 for the Larmor-free control, `RB_BOX`
  `RB_N` `RB_DT` `RB_TAG`), `run_quench_dtcheck.jl` (residual-J_z dt sweep),
  `run_m6_imprint.jl` + `run_m6_ensemble.jl` (m=−6 floor rectification).
  Plotters: `fig1_conversion.py`, `fig2_robustness.py`, `fig3_chirality_3pt.py`,
  `plot_chirality.py`, `plot_dtcheck.py`, `fig_m6*.py`.
  TSUBAME submit templates: `tsubame_{chirality,dtcheck,efficiency,m6,m6ens,omega0}.sh`.

## Data quality / convergence (solid-data audit)

- **Grid + dt converged.** EdH baseline final ⟨F_z⟩,⟨L_z⟩ agree at 32³ vs
  48³ and at dt=0.005 vs 0.0025 (both to <0.3%). The production runs use a
  bigger box ([18]³) which is what the ⟨L_z⟩ measurement needs.
- **Direction dependence is EXACT.** On the converged-GS, box=18 data:
  `max|⟨L_z⟩(+Ω)+⟨L_z⟩(−Ω)| = 1e-6`, `max|⟨F_z⟩(+Ω)+⟨F_z⟩(−Ω)| = 2e-6`.
- **DDI-off control is EXACT.** `|⟨F⟩| = 6.0000` (constant), `⟨L_z⟩ = 0`
  (machine zero) — forced Larmor precession, no vortices, no depolarisation.
- **Vortices are quantised.** Per-m orbital charge `ℓ_m = ⟨L_z⟩_m/n_m`
  lands on the Einstein-de Haas law `ℓ = F − m` (edh_baseline panel c) —
  the trustworthy vortex measure (the raw plaquette winding count is
  edge-noisy and is not used).
- **J_z conservation is box-limited, not a dynamics error.** The ~4% J_z
  "drift" at box=12 is a boundary artifact of the spectral
  `⟨L_z⟩ = ∫ x(-i∂_y)ψ` measurement (small edge amplitude × large |x|); it
  drops to 2.6% at box=18 and is dt/grid-independent. True J_z is conserved.
- Optimization scans (`figures/optimization_scaling.png`) use the converged box=18
  transverse GS (`from_jld2`, GS-shared), 41 Ω-points + 30 B-points. The
  dense sampling separates the vortex optimum (Ω≈0.30) from the Barnett
  optimum (Ω≈0.40) — the 6-point scan had aliased both to Ω≈0.4.

## Verification notes (honest)
- Trust ⟨L_z⟩ + J_z conservation + visual density holes for vortices.
- The raw plaquette winding COUNT is noisy at the cloud edge (masked at
  0.15·peak); use it only for the sign/chirality, not exact counts.
- rotating-frame ground-state (`rotframe_gs.yaml`) does NOT give clean
  vortices (subcritical→none, supercritical→turbulent/deconfined); the
  dynamical EdH quench is the reliable vortex mechanism.
