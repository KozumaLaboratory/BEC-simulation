# Success criteria — mechanical Barnett (rotating in-plane field → vortices → DDI → spin)

¹⁵¹Eu F=6 dipolar BEC. Living checklist: tick each item as runs close it.
Status: ✓ done · ~ partial / wrong-regime · ☐ todo.

## ⚠️ Corrected signal definition (read first)

The naive "one signal" — *M_z rises and reverses with CW/CCW* — is **not**
sufficient. Measured directly (DDI-off, transverse start, Ω=0.5):

| condition | peak \|F_z\| | \|F\| | vortices L_z |
|---|---|---|---|
| **DDI-off (single-particle)** | **5.62** | **6.000 (const)** | **0.000** |
| DDI-on (many-body) | 3.63 | depolarises | 1.13 |

A rotating in-plane field, via the rotating-frame effective axial field
(≈Ω/γ), **adiabatically tips the spin toward z single-particle** — full M_z,
|F| conserved, ZERO vortices, ZERO DDI — and it is already chiral
(M_z(CW)=−M_z(CCW)). So raw M_z (and its CW/CCW sign) is dominated by trivial
Larmor following, not the vortex-mediated Barnett.

**The many-body / vortex signal is the DDI-dependent excess:**
1. **Depolarisation** |⟨F⟩| < 6 — single-particle keeps |F|=6 exactly.
2. **Vortices** L_z ≠ 0 — single-particle keeps L_z=0 exactly.
3. **ΔM_z ≡ M_z(DDI-on) − M_z(DDI-off)** — M_z above the single-particle baseline.

Take CW/CCW differences of **these**, not of raw M_z.

## ⚠️ Operating-point requirement

To suppress the single-particle contamination, run at **Ω ≪ γB_⊥** (strong
in-plane field, slow rotation): the rotating-frame effective field is then
mostly in-plane, the spin locks in-plane (single-particle M_z ~ Ω/γB_⊥ → 0),
and any M_z that appears is vortex/DDI-mediated. Current runs sit at
Ω=0.5 ≳ γB_⊥=0.35 — the **contaminated** regime. The "elongated cloud lags →
vortex → spin" mechanism lives in the adiabatic-spin-lock regime.

## ⚠️ Open protocol decision

Two distinct mechanisms; pick before scaling runs:
- **(A) Spin-driven (forward-EdH-in-dynamics)**: field tips spin → DDI converts
  to orbital. Current runs show this — **F_z leads L_z** (t25 1.7 vs 3.7).
- **(B) Mechanical Barnett (your intended)**: magnetostriction-elongated cloud
  lags the rotating field → vortices → DDI → spin. Needs Ω ≪ γB_⊥ (spin locked)
  and expects **L_z to lead F_z**. Not yet realised.

Decide (A) vs (B); the checklist below assumes (B) is the target.

---

## 1. Main result — the chiral many-body signal  ~
- ☐ **ΔM_z(t) = M_z(CCW) − M_z(CW)** in regime (B); significant, time-growing,
  **after subtracting the DDI-off single-particle baseline**.
- ~ N_m(t) per-m transfer, CW vs CCW — have per-m data (`traj_ddioff.csv` cols
  `pop_m*`, `Lz_m*`) but in regime (A)/contaminated.
- ☐ CW−CCW difference figure as the headline (systematics cancel).

## 2. Angular-momentum budget — is it really Barnett?  ~
- ☐ Injected J_z from field torque `∫(M×B)_z dt` = ΔL_z + ΔS_z. Torque integral
  not yet computed. (Confirmed the rotating field **does pump J_z** — J_z is
  NOT conserved, mirror-antisymmetric — so this accounting is the right one.)
- ☐ Orbital/spin partition ratio (= Barnett conversion efficiency) vs time.
- ✓/reversed **Causal order**: measured **F_z leads L_z** in current runs
  (regime A). For (B) we require L_z to lead — open.

## 3. Vortex dynamics — the "by vortices" content  ~
- ~ core count / sign(winding) / position / onset time — `traj_ddioff.csv` has a
  vortex census + `Lz_m*`; winding count is edge-noisy (use L_z / density holes).
- ☐ total circulation vs M_z quantitative correlation.
- ~ which m carries the vortex: EdH baseline shows ℓ_m = F−m (quantised); check
  the rotating case is the reverse.
- ☐ **critical Ω_c**: Ω<Ω_c no vortex → Barnett small; Ω>Ω_c vortices → Barnett
  grows. Threshold scan.

## 4. Mechanism ID — controls (do these FIRST)  ~
- ✓ **DDI off** → decisive, but the result flips the premise: DDI-off M_z is
  *larger* (single-particle). The right DDI-off test is in regime (B): there
  DDI-off should give M_z≈0 (spin locked in-plane). Re-run at Ω≪γB_⊥.
- ✓ **static field (no rotation)** → no chiral asymmetry (Ω=0 control flat).
- ✓ **exact mirror**: seed-free M_z(CW) = −M_z(CCW) to residual 0 (verified).
- ☐ **q / spin-mixing leak**: confirm no z-magnetisation leak via q F_z² with
  DDI off + rotation, before interpreting the real run.

## 5. Parameter dependence — find the operating point  ~
- ~ **Ω-dependence**: dense sweep done (`optimization_scaling.png`), but at
  Ω≳γB_⊥ (contaminated). Redo at Ω≪γB_⊥; expect M_z ∝ B_B=Ω/γ in linear
  response → read effective γ from the slope.
- ☐ **field size / q resonance** (the centrepiece): transfer peaks when the
  Larmor/q detuning matches ℏω_orbital. A resonance was seen in the *z-bias*
  protocol (`resonance_onesided.png`, `cone_angle_scan.png`); whether the
  *in-plane* protocol has the analogous resonance is untested. This sets the
  experimental field.
- ☐ DDI-strength scan → conversion efficiency vs DDI.
- ☐ initial state: m=0 / transverse / Flower vs stretched m=±6.
- ☐ trap aspect ratio (magnetostriction axis vs vortex entry).

## 6. Experiment-facing observables  ☐
- ~ Stern-Gerlach N_m(t) time series (have per-m populations).
- ☐ **robustness to spatial averaging**: TOF column density / integrated
  N_m asymmetry survives without interference fringes (the "high-confidence,
  Flower-interference-independent" argument).
- ☐ signal vs detection floor: ΔN/N > imaging noise (~few %); target ≥5–10% in
  the difference at the chosen Ω, field.
- ☐ timescales within atom lifetime & achievable field-rotation rate.

## 7. Numerical health  ~
- ~ norm / energy (minus external-field work) / total-AM conservation per run.
- ☐ **dt/dx convergence WITH rotation** — ⚠️ `split_step!` is **1st-order in
  time with DDI** (mean field frozen at V(dt/2) boundaries; the rotating field
  changes spin texture mid-step). Use `split_step_midpoint!` (Picard) or verify
  order on the actual rotating config; static/EdH convergence does NOT transfer.
- ☐ spurious (discretisation) vs real (DDI) vortices.
- ☐ spin-mixing dynamical instability not burying the signal.
- ☐ box size / absorbing boundary: no rebound of the elongated / ejected cloud.

## 8. Deeper  ☐
- ☐ rotating-frame ground state (−ΩL_z imaginary time) → M_z^eq(Ω); does the
  real-time dynamics asymptote to it? (equilibrium vs dynamical Barnett).
- ~ **EdH reciprocity**: forward (spin→orbital, `edh_baseline.png`) vs reverse
  (orbital→spin) with the SAME conversion coefficient — strong cross-check,
  EdH data already in hand.
- ☐ phase-diagram position: sweep c1,c2,…,c_dd; is Barnett response enhanced
  near the Flower phase → position Barnett as a **Flower-phase probe** (thesis
  through-line).

---

## Priority order
1 (regime-B signal) → 4 (DDI-off + q control, in regime B) → 2 (torque budget +
causal order) → 5 (q / field resonance). Everything hinges first on moving to
**Ω ≪ γB_⊥** and subtracting the single-particle baseline.
