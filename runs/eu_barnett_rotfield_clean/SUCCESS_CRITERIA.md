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

## FEASIBILITY GATE — is the window open? (RESULT: **OPEN**, `run_bdd.jl`)

The single-stage window opens iff the max achievable signal fraction — the
transverse (spin-tipping) dipolar field over the adiabaticity-floor external
field — exceeds the imaging floor: **γB_dd/ω_⊥ = Φ_z ≳ floor (~0.03)**. Because
H_DDI = −Φ·F, the dipolar field Φ (ω_ref units) *is* γB_dd, so Φ_z is read
directly off a realistic Eu state (`run_bdd.jl`, magnetostriction GS, N=30000):

| quantity | ω_ref units | (μG, g_F=1.163) |
|---|---|---|
| \|Φ\| total (along magnetisation, ~c_dd·n) | 0.61 | ~38 |
| Φ_∥ (along B_ext=x) rms | 0.68 | ~42 |
| **Φ_z (transverse, spin-tipping) rms** | **0.121** | ~7.4 |
| Φ_z max | 0.40 | ~24 |

**Pass-1 (GS RMS): Φ_z(rms)=0.121 → looked OPEN (12 %).** But RMS is an
UPPER bound — it is not what drives the *net* M_z.

**Pass-2 (`run_bdd_vortex.jl`, P1-stirred vortex states) overturns the
optimism** — measured on the Ω=0.74 and 0.85 stir states:

| Φ_z | Ω=0.74 | Ω=0.85 |
|---|---|---|
| **NET (density-wtd mean, drives net M_z)** | **0.0005 (0.03 µG)** | **0.010 (0.6 µG)** |
| RMS (local) | 0.21 (13 µG) | 0.28 (17 µG) |
| at vortex cores | 0.21 (13 µG) | 0.30 (19 µG) |

The transverse dipolar field is large *locally* (13–19 µG) but the **NET
(cloud-averaged) field is ~30× smaller, below the floor** — because a straight
penetrating vortex line in the z-symmetric pancake has a **z-odd Φ_z that
cancels in the z-average** (the pancake-vs-Saito-torus geometry difference,
now quantified). The Fz seen in P1 (~0.6 at Ω=0.85) is the **single-particle
−Ω/γ tilt** (Ω/√(p⊥²+Ω²)·|F|≈0.34 at γB=15), *not* the DDI Barnett (which the
net Φ_z would put at ~0.004).

**Revised verdict: single-stage pancake net M_z is SUPPRESSED by z-cancellation
— likely NOT feasible.** The z-cancellation is geometric, so it re-elevates the
**two-stage quench** (release the spin → it relaxes into a flux-closure /
z-asymmetric texture that carries net M_z, Saito-scale) from backup to the
**necessary** path. Decisive test = **P2 regime-B with DDI-off subtraction**
(does a net M_z above the single-particle background actually develop?) + the
two-stage m-redistribution check.
- Φ ∝ N (density); recompute for the experiment's N.
- Caveat: pass-2 is on the strong-field *locked* state (no spin feedback); the
  regime-B self-consistent net could differ — P2 settles it.

## RESOLVED DECISION — two-stage (single-stage is dead)

**P2 regime-B settled it (`run_p2_regimeb.jl`, γB=4, Ω=0.85, DDI on/off):**

| | DDI-off (single-particle) | DDI-on |
|---|---|---|
| Fz(end) | 2.42 | 0.74 |
| \|F\|min | 5.997 (const) | 4.869 (depolarised) |
| peak L_z | 0 | 1.79 (vortices) |
| Fz/\|F\| | 0.40 | 0.15 |

The DDI's many-body effect is **depolarisation (|F| 6→4.87) + vortices**, but it
**does NOT enhance the axial M_z** — DDI-on Fz (0.74) is *below* the
single-particle −Ω/γ tilt (2.42); the vortex dynamics scramble the coherent
tilt rather than converting orbital→axial-spin. Net axial M_z is not built.
Worse, the depolarisation is Ω-EVEN (same for CW/CCW) so it cancels in the
direction-controlled CW−CCW difference. **Single-stage pancake gives no clean
chiral net-M_z Barnett.**

## P2 COMPLETION — Task 1: the failure mechanism is NOT z-cancellation

`analyze_p2_fz_crosssection.jl` on the SAVED P2 end states (`figures/p2_crosssection.png`)
settles *why* the net M_z vanishes — the two-stage design input:

| end-state (γB=4, Ω=0.85) | DDI-off | DDI-on |
|---|---|---|
| Fz | 2.42 | 0.74 |
| \|F\|_cloud | 5.997 | 4.869 |
| **local \|F\| = \|f\|/n** (density-wtd) | **6.00** | **5.05** |
| **z-cancellation frac** (col ∫f_z dxdy) | **0.00** | **0.00** |
| Fz / \|F\|_cloud | 0.40 | 0.15 |

**The pass-2 z-odd hypothesis is REFUTED dynamically.** The column integral
∫f_z dx dy is **same-sign at every z** (cancellation frac = 0.00) — there is no
z-odd f_z texture that cancels in the z-average. Nor is it pure depolarisation:
local \|F\| only drops 6.00→5.05 (~16 %), far too little to explain Fz dropping
3.3×. The dominant killer is **in-plane DDI pinning**: the dipolar mean field
lies along the in-plane magnetisation (Φ_∥ ~ 42 µG ≫ the axial fields), pinning
the spin *harder* in-plane and suppressing the coherent −Ω/γ axial tilt
(Fz/\|F\| collapses 0.40→0.15 while \|F\|_cloud stays large). Mild depolarisation
(near vortex cores) is a secondary effect.

**Consequence for two-stage — bet on flux-closure, not post-quench B_z bias.**
Single-stage fails because B_ext + Φ_∥ pin the spin in-plane, not because of
geometric z-cancellation. Quenching B→~0 removes *exactly* that pinning, so the
released spin is free to relax into a z-asymmetric flux-closure texture. The
mechanism to design for is Saito flux-closure relaxation; a residual static B_z
bias would merely restore single-particle pinning and should be nulled.

⇒ **Two-stage quench is the necessary path** (nucleate vortices at healthy B →
quench B→~0 → the released spin relaxes into a flux-closure / z-asymmetric
texture that carries net M_z, Saito-scale). This is the thesis-novel geometry
step. The remaining risk — does the quench redistribute the single-component
vortex into the m-texture so ⟨f_z⟩ rises? — is the next decisive test.

**Still open before two-stage (Tasks 2–3):** multi-Ω ΔFz (Klaus Ω_c kink on the
M_z side?) and the CW−CCW double difference (is single-stage truly dead, or
"small but separable"?).

--- (historical: the single-stage analysis below is retained for context) ---

- **Single-stage** (Klaus geometry + Ω/ω_⊥, sweep field strength): honest Klaus
  reproduction; max signal fraction ~12 % (above floor). Still small enough that
  confound subtraction (§ error budget) is the real gate, not window closure.
- **Two-stage** (strong-B Klaus nucleation → quench B→~0 → spin released →
  topologically-conserved residual vortices relax to their B_dd → Barnett at the
  large Saito scale): larger signal *and* removes the adiabaticity floor (the
  vortices are already frozen in, so no stirring-adiabaticity requirement during
  read-out). Take it if the confound budget (below) squeezes single-stage.
  Its own risk — does the quench redistribute the single-component vortex into
  the m-texture so ⟨f_z⟩ rises? — is the core mechanism-ID, verify before use.

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

## Experimental feasibility layer (error budget → go/no-go)

The experiment has two weapons: the **CW−CCW difference** and the **Ω_c
threshold** (signal turns on *with* the vortices). Split every error by Ω-parity:

- **Ω-even** (mean cancels in CW−CCW): residual B_z, θ-calibration (cosθ
  projection), static trap anisotropy. Averages out — **but shot-to-shot
  fluctuations do not** (CW and CCW are separate shots, so σ(B_z) leaks).
- **Ω-odd** (survives CW−CCW): the −Ω/γ single-particle tilt (smooth in Ω, no
  threshold) and the true Barnett (turns on at Ω_c *with* the vortices). These
  two are **not** separable by CW−CCW; only their **Ω-shape** distinguishes them
  (smooth vs kink-at-Ω_c). DDI on/off is a sim-only knob (can't switch DDI in the
  lab) → the experimental discriminant is **"M_z excess that turns on at Ω_c,
  correlated with vortex number"** = the Klaus signature.

**Protocol** (two-step): CW−CCW kills static confounds → the Ω_c kink + vortex
correlation peels the true Barnett off the single-particle −Ω/γ background.

**Dominant confound + the B_⊥-independent critical condition.** Shot-to-shot
residual-B_z fluctuation shifts the single-particle M_z directly:
signal M_z/|F| ~ B_dd/B_⊥; sensitivity ∂M_z^sp/∂B_z ~ |F|/B_⊥. In SNR ~
ΔM_z/[sensitivity·σ(B_z)] the B_⊥ cancels →

> **σ(B_z)_shot-to-shot ≲ B_dd** — an absolute (B_⊥-independent) requirement,
> ~μG-scale = **the EdH-grade shielding the lab hit last year [ref 50]**. This
> is the real "can we do it with what we have?" question.

**Confound vs degrader** (different failure definitions):
- **Confounds** (systematic bias, "false M_z beats true M_z"): σ(B_z), δθ, δΩ
  (Ω_c miss). The go/no-go axes.
- **Degraders** (noise breaks the floor): a_s/ε_dd uncertainty (Klaus 111(9)a₀
  = ±8 %, moves amplitude *and* the Flower ground phase — needs eGPE ε_dd sweep),
  N fluctuation, T/thermal fraction (seed needed but excess buries signal),
  imaging floor (ΔN/N ~2–5 %/shot, /√n_shot), lifetime (Barnett rise < 3-body &
  vortex lifetime).

**Two-layer simulation** (all-eGPE MC would be fatal):
- **Surrogate (for the MC sweeps)**: single-particle M_z is analytic —
  adiabatic follow of B_eff = B_⊥(in-plane) + (−Ω/γ + B_z,res)ẑ,
  M_z^sp=|F|·B_eff,z/|B_eff|. Closes the −Ω/γ tilt and the B_z confound cheaply.
  Represent the vortex-DDI term M_z^Barnett(·) by a response surface fit to a
  **coarse eGPE grid** (Ω, ε_dd, B_⊥). MC the Klaus-Methods error distributions
  through the surrogate → M_z distribution → SNR.
- **Full eGPE (verify + nonlinear)**: a few points near Ω_c (nonlinear vortex
  nucleation), near the ε_dd phase boundary, and the two-stage m-redistribution
  (the mechanism-ID core).

**Four figures** (feasibility deliverable):
1. **Tornado** — SNR drop per 1σ of each error, ranked; B_z σ should be longest.
2. **1D degradation** — SNR (or ΔM_z) vs each error, with the **critical
   crossing** (SNR=3 / floor) and the **achieved lab value** (Klaus-Methods σ)
   as two vertical lines: is the achieved value safely left of critical?
3. **2D go/no-go** — σ(B_z) × B_⊥ plane, detectable region shaded, operating
   point plotted **with its ±σ error box**; does the box sit inside "go"?
4. **B_⊥ window** — three lines vs B_⊥: adiabaticity floor (ω_⊥/γ), visibility
   ceiling (B_dd/floor), σ(B_z) shielding requirement; is the window open and
   does the single-stage operating point fall in it (else justify two-stage).

Order: **F1 (B_dd, done → OPEN)** → surrogate + coarse eGPE grid → F4 window →
F3 go/no-go → F1/F2 breakdown. F4 is the conclusion; F3 the with-error verdict.

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
