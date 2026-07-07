# Mechanical Barnett in ¹⁵¹Eu F=6 — success criteria & run checklist

Reverse Einstein–de Haas driven by **Klaus magnetostriction stirring**:
rotate an in-plane field → the dipole-elongated cloud lags → vortices nucleate
(orbital AM) → DDI converts orbital→spin → axial magnetisation ⟨F_z⟩ rises.

Agent-executable checklist. Status: ✓ done · ~ partial/wrong-regime · ☐ todo.
Internal units: ω_ref = ℏ = m = 1, trap ω_⊥ = 1, γB ≡ |p| = 16276·B[Gauss]
(Eu g_F=1.163, ω_ref=628.3).

## Premise (LOCKED): mechanism (B), not (A)

Choosing Klaus forces (B) — it is not a preference. Dy is scalar (spin-frozen),
so the *only* angular-momentum injection path is the magnetostriction-stirring
**orbital** instability; there is no term that drives spin directly. A faithful
Klaus reproduction therefore necessarily has **vortex first, spin only via DDI**
= the definition of (B).

The existing "F_z leads L_z" runs are mechanism **(A)** — the rotating-frame
effective axial field (≈ −Ω/γ) driving each spin single-particle. That path is
**un-Klaus** (absent in a scalar gas) and is exactly the lab's forward EdH
[Science 2026, ref 50]. Barnett = its reciprocal (orbital→spin), with Klaus
stirring supplying the orbital drive for free. So: **Barnett = reverse-EdH
driven by Klaus stirring**; forward EdH is the cross-check (§8).

## OPEN DECISION — single-stage vs two-stage quench

- **Single-stage** (Klaus geometry + Ω/ω_⊥, sweep field strength): the honest
  Klaus reproduction. Risk: the signal is intrinsically **small** — residual
  spin tilt ~ B_dd/B_ext ~ 1/(few) (see window tradeoff below) — and must
  survive noise + single-particle-baseline subtraction.
- **Two-stage** (strong-B Klaus nucleation → quench B→~0 → spin released →
  topologically-conserved residual vortices relax to their own B_dd → Barnett
  rises at the large Saito scale): both Klaus nucleation *and* a big signal.
  Risk: whether the quench correctly redistributes the single-component vortex
  into the m-texture so ⟨f_z⟩ actually rises is **nontrivial** — this is the
  core mechanism-ID and is worth checking *before* committing to single-stage.

Decide after Priority 1–2 give the single-stage signal size.

## Signal definition (corrected — physics, not artifact)

Raw ⟨F_z⟩ and its CW/CCW sign are **dominated by the single-particle** Barnett
(each spin responds independently to the rotating-frame −Ω/γ field). This is
real physics, distinct from Saito's many-body orbital→spin conversion, and in
**real Eu it is negligible** (γB_⊥ ~ MHz@1G ≫ Ω ~ ω_⊥ ~ 50 Hz, ratio ~10⁴).
It blows up in the current runs only because γB_⊥=0.35 ≈ Ω=0.5 (weak-B corner).

**Many-body / vortex signal = the DDI-dependent excess:**
1. **Depolarisation** |⟨F⟩| < 6 — single-particle keeps |F|=6 exactly.
2. **Vortices** L_z ≠ 0 — single-particle keeps L_z=0 exactly.
3. **ΔM_z ≡ ⟨F_z⟩(DDI-on) − ⟨F_z⟩(DDI-off)** — subtracts both the cos-projection
   and the −Ω/γ tilt, leaving the vortex-DDI term.

**Separation logic (triangulate):**
- **Primary discriminant = DDI on/off.** Chirality is NOT a discriminant — both
  the −Ω/γ tilt and the vortex circulation flip sign with Ω. CW/CCW only
  confirms the signal is *rotation-induced*.
- DDI-off also removes magnetostriction (no elongation → no vortices), so the
  m-distribution won't match the on-run: **first approximation only.**
- Cleaner third leg: **DDI-on but Ω < Ω_c (no vortex)** baseline — isolates the
  "vortex-free spin response" from the "vortex-derived" one.
- **Gold standard = double difference: ΔM_z(CW) − ΔM_z(CCW).**

## Operating point — the current runs are in the worst corner

Klaus reproduction needs two things at once:
- **vortex nucleation**: Ω ≈ 0.7–0.75 ω_⊥ (quadrupole surface mode Ω_c≈0.74,
  Klaus's heart).
- **single-particle suppression**: Ω ≪ γB_⊥.

Joint condition: **γB_⊥ ≫ ω_⊥ with Ω ≈ 0.74**. Concretely γB_⊥ ~ 3–5 (a few×ω_⊥)
→ **B_⊥ ~ 2–3×10⁻⁴ G (≈0.2–0.3 mG)**, Ω = 0.74. (Between Saito's μG and Klaus's
5.333 G; the Gauss field fully scalarises Eu and kills the spin signal, so keep
Klaus geometry + Ω/ω_⊥ but treat **field strength as the free parameter**.)
Current runs: γB_⊥=0.35 < Ω=0.5 — the exact opposite corner.

## The essential tradeoff (new, hard — the crux of the thesis novelty)

Magnetostriction stirring *requires* spin polarisation (the cloud elongates
along B because the dipoles align with B_ext). Two opposite demands on the same
DDI scale:
- **Polarisation** (needed for stirring): γB_ext ≫ DDI-spin scale. Below it the
  spin forms texture (Saito flux-closure side), the single B-following
  elongation axis disappears, and Klaus stirring fails.
- **Barnett visibility** (vortex B_dd must be able to tip spin toward z):
  γB_ext ≲ few × DDI scale, else B_dd is overwhelmed.

Window: **γB_ext ~ few × DDI scale.** Spin ~90% along B_ext, the residual free
DOF responds weakly to B_dd → single-stage signal ~ B_dd/B_ext ~ 1/(few). The
field-strength scan (Priority 5) maps this window empirically; if too thin,
switch to the two-stage quench.

## q (quadratic Zeeman) — demoted to a secondary knob

In (B) the primary resonance is the **orbital** Ω_c≈0.74 ω_⊥ (quadrupole surface
mode), not a spin q-resonance (that was the (A) centrepiece). Here q is a gate on
how freely the spin responds to B_dd — it may tune the window width. In-plane
q-resonance verification is correctly **deferred**.

---

## Priority tasks (agent-executable)

### P1 — Klaus orbital reproduction (spin-less bench)  ☐
- **Goal**: reproduce the pure magnetostriction-stirring vortex physics in Eu.
- **Knobs**: strong-B fully-polarised (scalar limit) or scalar eGPE; Klaus
  geometry (pancake, rotating elliptical deformation); **Ω = 0.7–0.75**.
- **Pass**: aspect-ratio growth→collapse, measured Ω_c ≈ 0.74 ω_⊥, vortex count
  vs Ω, stripe/lattice FT — matching Klaus 2022 qualitatively. Doubles as the
  strong-field numerical-health check.
- **Reuse**: `spinning_ellipse.yaml`, `rotbasis_magnetostir.yaml`.
- **Artifact**: `figures/klaus_orbital.png` (AR(t), Ω_c, N_vtx(Ω)).

### P2 — Barnett observation in regime B  ☐
- **Goal**: with vortices present, do |F|<6 / L_z≠0 / ΔM_z rise?
- **Knobs**: **B_⊥ ~ 2–3×10⁻⁴ G (γB~3–5), Ω=0.74**, DDI on, polarised start.
- **Baselines** (all three legs): DDI-off · DDI-on & Ω<Ω_c · CW vs CCW.
- **Pass**: ΔM_z(CW)−ΔM_z(CCW) significant and time-growing; |F| drops; L_z≠0.
  Record signal size for the single-vs-two-stage decision.
- **Artifact**: `figures/barnett_regimeB.png`.

### P3 — Causal order  ☐
- **Goal**: confirm **L_z leads F_z** (Klaus/(B) signature), and show the
  existing F_z-first is a wrong-regime artifact (re-run the old config at
  γB_⊥≫Ω and watch the ordering flip).
- **Pass**: t₂₅(L_z) < t₂₅(F_z) in regime B; opposite in the contaminated regime.

### P4 — Torque budget  ☐
- **Goal**: injected J_z = ∫(M×B)_z dt = ΔL_z + ΔS_z; conversion efficiency.
- **Pass**: budget closes to a few %; partition ratio (orbital vs spin) tracked
  in time. (Confirmed: the rotating field *pumps* J_z — not conserved,
  mirror-antisymmetric — so this is the correct accounting.)

### P5 — Field-strength scan (window mapping)  ☐
- **Goal**: map the polarisation↔Barnett window; sweep B_ext at fixed Klaus
  geometry + Ω/ω_⊥. q as a secondary knob on window width.
- **Pass**: locate γB_ext ~ few × DDI scale where |F| stays polarised (stirring
  works) yet ΔM_z is maximal. If single-stage window too thin → **two-stage
  quench** (strong-B nucleate → quench B→0 → measure ΔM_z at Saito scale;
  verify the single-component vortex redistributes into m-texture).
- **Artifact**: `figures/barnett_field_window.png`.

---

## Vortex dynamics & experiment observables (fold into P1–P5)
- Vortex census: count / sign(winding) / position / onset; which m carries the
  vortex (EdH baseline shows ℓ_m=F−m; check the reverse). Winding count is
  edge-noisy — use L_z / density holes.
- Critical Ω_c threshold: Ω<Ω_c no vortex → Barnett small; Ω>Ω_c → grows.
- Stern–Gerlach N_m(t) (what the experiment measures); **TOF column-density /
  integrated N_m asymmetry** must survive spatial averaging (the
  Flower-interference-independent, "high-confidence" argument).
- Signal vs detection floor: target ΔN/N ≥ 5–10 % in the CW−CCW difference.
- Timescales within atom lifetime & achievable field-rotation rate.

## Numerical health (every run)
- Norm / energy (minus external-field work) / total-AM conservation monitored.
- ⚠️ **dt/dx convergence WITH rotation**: `split_step!` is **1st-order in time
  with DDI** (mean field frozen at V(dt/2) boundaries; a rotating field changes
  the spin texture mid-step). Use `split_step_midpoint!` (Picard) or re-verify
  order on the actual rotating config — static/EdH convergence does NOT transfer.
- Spurious (discretisation) vs real (DDI) vortices; box/absorbing boundary — no
  rebound of the elongated or ejected cloud; spin-mixing dynamical instability
  not burying the signal.

## §8 — Deeper / novelty
- **Rotating-frame ground state** (−ΩL_z imaginary time) → M_z^eq(Ω); does the
  real-time dynamics asymptote to it (equilibrium vs dynamical Barnett)?
- **EdH reciprocity**: forward (spin→orbital, `figures/edh_baseline.png`) vs
  reverse (orbital→spin) with the *same* conversion coefficient — strong
  cross-check, EdH data already in hand.
- **Phase-diagram position**: sweep c1,c2,…,c_dd; is Barnett response enhanced
  near the Flower phase → position Barnett as a **Flower-phase probe** (thesis
  through-line).
- **Geometry & sign (untouched by either paper — where the novelty sits)**: ours
  is a pancake of penetrating vortex lines, Saito is a torus flux-closure. The
  conversion is general (per-atom AM conservation) but the magnitude and sign
  depend on which m component hosts the vortex; the ⟨F_z⟩ sign should tie to the
  stirring chirality.

## References
- Klaus 2022 — Dy magnetostriction stirring (scalar, orbital instability, Ω_c).
- Saito — many-body orbital→spin conversion, flux-closure torus geometry.
- Science 2026 [ref 50] — lab forward EdH (the (A) path; Barnett is its reverse).
