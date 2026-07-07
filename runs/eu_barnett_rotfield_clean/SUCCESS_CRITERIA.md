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

## TWO-STAGE PASS-0 — lock release confirmed (#1), but passive relaxation depolarises (2026-07-07)

Before investing in full two-stage, a gate: is the in-plane spin lock held by the
external field (#1, quench frees it) or by the DDI's own field (#2, quench can't
free it)? Two legs, both on the saved P2 on end state (`figures/p2_quench.png`).

**Leg 1 — B_dd decomposition (`analyze_p2_bdd_endstate.jl`):** the DDI's own
in-plane field is small vs B_ext:

| field on P2 end state | ω_ref | µG |
|---|---|---|
| γB_ext (removed by quench) | 4.00 | 246 |
| **B_dd in-plane rms** (residual pinning) | **0.41** | **25** |
| B_dd axial (z) rms | 0.20 | 12 |
| **residual in-plane pinning after B→0** | **0.092** | — |

⇒ **#1 external-field lock.** The quench removes ~91 % of the in-plane pinning;
B_dd self-lock (#2) is ruled out. Bonus: the residual DDI field's axial component
(12 µG) is half its in-plane part (25 µG) — a real z-component to drive reorientation.

**Leg 2 — mini-quench dynamics (`run_p2_quench.jl`, B→0, DDI on vs off, t=15):**

| | t=0 | t=15 |
|---|---|---|
| DDI-on: \|⟨F⟩\| | 5.01 | **3.18** |
| DDI-on: F_perp | 4.96 | 3.18 |
| DDI-on: **F_z** | 0.71 | **−0.06** |
| DDI-off control (all) | frozen | frozen |

The DDI-off control is frozen (no field, no torque) → any DDI-on change is
DDI-driven. DDI-on: the state **does evolve** (36 % drop) — confirming the lock is
released (#1). **BUT the released spin DEPOLARISES** (|F| 5→3.2, F_z pinned ~0) —
it does **not** spontaneously form a net-M_z flux-closure.

**Pass-0 verdict (nuanced):** the two-stage *premise* holds — quenching B→0 frees
the spin (#1, not #2). But **naive "quench → passively relax → net M_z" FAILS**:
the released spin disorders (depolarises) rather than cohering into a net axial
magnetisation. Caveats: (a) started from the already-depolarised regime-B end
state (|F|=5), not a healthy fully-polarised vortex state; (b) t=15 ≪ Saito
flux-closure scale (~100/ω⊥); (c) a pancake flux-closure may be z-even (net F_z=0
by geometry). Full two-stage therefore needs a **healthy polarised start** and
likely an **explicit z-symmetry-breaking** element — not passive relaxation.
DECISION POINT before full two-stage build.

## PASS-0 follow-up — HEALTHY polarised start: vortex AM is LOST, not converted (2026-07-07)

The mini-quench above started from the depolarised regime-B state. This tests the
biggest caveat: quench from a HEALTHY polarised vortex state — the P1 Ω_c stir
state (`runs/p1_O0.74_db0e3dfb`, γB=15, |F|=5.85, 11 vortices) → B→0, DDI on, t=50
(`run_p2_quench.jl` with QSRC/QTAG/QDUR; `figures/p2_quench_compare.png`).
**Pre-committed lines** (fixed before the run, no post-hoc loosening): |F|
retention 5.85→≥5.0 = degraded-start cause / ≤3.5 = intrinsic / 4.0–5.0 = defer to
cross-section; F_z "stands" = time-mean F_z/|F| > 3 % imaging floor AND stable.

**Result (read cross-section first — integral F_z cannot separate the branches):**

| healthy end (t=50) | value |
|---|---|
| \|F\|_cloud | 1.56 (looks like collapse) |
| **local \|F\|=\|f\|/n** | **4.1 (HELD)** → SPATIAL texture, NOT local depol |
| z-cancellation frac | 0.00 → net F_z real, z-odd |
| ⟨F_z⟩ time-mean (t≥33) | −0.44 ± 0.06 (stable, F_z/\|F\|_cloud=0.28 > floor) |
| **J_z = L_z+F_z** | **1.28 → −0.5 (NOT conserved)** |

**Cross-section reverses the naive read:** cloud \|F\|→1.56 looks like Option-3
depolarisation, but local \|F\|=4.1 is HELD → the spin forms a **texture** (74 %
spatial cancellation), not local depolarisation. z-cancel=0 rules out Option-2
z-even. By the pre-committed lines that is the Branch-1 signature (texture + real
z-odd net F_z). **BUT the intended two-stage mechanism FAILS:** L_z collapses
1.16→0.08 in t<2 (half a trap period) *without* transferring to F_z (J_z 1.28→0.27
instantly) — the **vortex orbital AM is LOST, not converted to spin**. The later
F_z=−0.44 develops at t>10 *after* the vortices are gone, so it is a secondary DDI
texturing effect, NOT the Saito orbital→spin Barnett. Its sign (−) is not tied to
the +Ω stir chirality.

**GATING ANOMALY — J_z not conserved.** B=0 + isotropic in-plane trap + non-secular
DDI should conserve J_z, and norm (6e−11) + energy (2.5e−7) ARE conserved — yet
J_z drifts 1.28→−0.5. Likely a numerical L_z leak (Orszag-2/3 dealias filter is not
rotationally symmetric on a cubic grid) or 48³ under-resolving the fine texture.
Until resolved (grid/dt convergence + dealias off), the weak F_z=−0.44 cannot be
trusted as physical, and "vortex AM is lost" cannot be cleanly called physical vs
numerical. **This is the next gate before any two-stage conclusion.**

## REBUILD RESULT — clean box OVERTURNS box-12: two-stage Barnett WORKS (2026-07-08)

`run_rebuild.jl` on TSUBAME (H100, ~38 min): full two-stage at **box±10/n80**
(dx=0.25 kept) — GS(γB=15) → Klaus stir → quench B→0, monitoring J_z + edge.
`figures/rebuild_boxfix.png`. **The box-overflow artifact had INVERTED the physics:**

| quench end | F_z | L_z (start→end) | \|F\| end | edge |
|---|---|---|---|---|
| box±6 (overflow) | **−0.44** | 1.16 → −0.07 (collapse) | 1.56 | 8 % |
| **box±10 (clean)** | **+2.08** | **10.9 → 5.7 (converts)** | 2.18 | 0.3 % |

In the clean box the **two-stage Barnett WORKS**: the quench releases the spin and
**vortex orbital AM converts to a real net axial magnetisation** — F_z grows
0.18 → **+2.08** (stable t=20–50), L_z drops 10.9 → 5.7, and the residual spin is
**~fully axial** (F_z/\|F\|≈0.99). This is the Saito orbital→spin mechanism. The
box-12 conclusion ("AM lost, F_z=−0.44, no conversion") was a box-overflow artifact
that suppressed the conversion — edge-fraction 8 % vs 0.3 %.

**Caveat to close (honest):** J_z still drifts in the quench (11.1 → 7.8; loss
= ΔL_z+ΔF_z = −5.2+2.0 = −3.2) *despite* edge≈0, so it is NOT the same overflow.
The **direction** (conversion happens, net M_z develops) is robust; the exact
conversion efficiency needs the residual closed. Also pending: chirality
(−Ω → −F_z?) and the deferred L_z-collapse re-read (here L_z does NOT collapse — it
smoothly converts, another box-12-artifact reversal).

## RESIDUAL J_z — NOT box, it is grid/dt resolution (2026-07-08)

box±14/n80 (dx=0.35) vs box±10/n80 (dx=0.25) quench, both TSUBAME:

| | J_z drift | ⟨F_z⟩ | L_z(→) | edge_max |
|---|---|---|---|---|
| box±10 (dx0.25) | +3.26 | +2.08 | 10.9→5.7 | 0.003 |
| box±14 (dx0.35) | **+5.16** | +1.87 | 10.9→3.9 | **0.000** |

**The residual is NOT box-overflow** — box±14 has edge_max = 0.000 (fully contained)
yet the drift *grew* (3.26→5.16). It grew because the box±14/n80 grid is **coarser**
(dx 0.35 vs 0.25): the residual J_z leak is a **grid/time-discretization effect on
the fine conversion dynamics** (decaying vortices + spin texture), worse at coarser
dx — NOT the periodic boundary. Closing it needs **finer dx/dt, not a bigger box**.
**The conversion is box/grid-robust**: F_z→+1.9…2.1, L_z drops, across both. So
"two-stage Barnett works, net M_z via orbital→spin" is **confirmed robust**; only
the exact efficiency (how much of ΔL_z reaches F_z vs numerical leak) awaits a
grid-convergence run (box±14/n112 dx0.25 + dt-check). **Status: headline CONFIRMED;
conversion efficiency = grid-convergence pending.**

TSUBAME infra (all fixed + `tsubame_rebuild_template.sh` + gotchas): explicit julia
path, JULIAUP+package shared depot, NVMe scratch (mmap; RB_SAVE_EVERY to fit big
grids — Lustre SIGBUSes), reap runs/rb_* + group quota, ssh ControlMaster socket.

## GATE — the two-stage J_z leak is a BOX-OVERFLOW artifact (2026-07-07)

The healthy-start quench's J_z non-conservation (1.28→−0.5, while norm/energy
conserved) invalidates BOTH "vortex AM lost" and "F_z=−0.44 real" — a broken
conservation law contaminates every J_z-dependent claim. Diagnosis (all cheap,
one-factor-at-a-time; tools `run_jz_check.jl`, `verify_lz_operator.jl`,
`run_box_toy.jl`):

1. **dt-independent** (dt 4e−4 ≡ 2e−4 bit-identical) → structural *spatial*
   non-conservation, not time-integration.
2. Dealias filter: default OFF; turning ON mildly *worsens* → not aliasing.
3. DDI `trunc_radius`: default disabled → not kernel asymmetry.
4. **L_z operator EXACT**: (x+iy)^m·G eigenstate test → measured L_z = m to 1e−14
   for contained states; drifts only at box-overflow → measurement sound.
5. **DDI-off still leaks L_z (0.8)**, spin frozen → **orbital**, not DDI-coupled.
6. Density extent: **RMS r_xy=3.95 in a ±6 box, 8 % of density at the edge**
   (|x,y|>5.5) → **overflow**.
7. **Toy confirmation** (analytic orbital vortex): leak scales with edge-fraction
   (σ2.8/2.7 %→0.004, σ4.0/9.9 %→0.17, σ7/20 %→0.32); and the *same* σ=4 cloud
   **leaks 0.17 at box-12 but conserves (0.0002) at box-20**. Bigger box is the fix.

**Root cause: the ±6 box is too small for this cloud.** Split-step Fourier is
periodic; density at the edge couples to its images and breaks L_z conservation
(norm/energy survive). The Barnett cloud (RMS 3.95, elongated) overflows.

**Consequence: every two-stage physics conclusion is provisional** — "AM lost",
"F_z=−0.44", the L_z collapse — all ride on the contaminated J_z ledger and must be
re-derived in a bigger box. Caveat: the transient toy caps at leak ~0.3 while
production leaks 0.8 (sustained overflow + high-k texture from 11 vortices add
more), so the rebuild uses **box≈20 (n≈80, dx=0.25 kept)** and *checks* J_z closes;
if a residual remains, finer grid is the follow-up. See gotcha
`box_overflow_breaks_lz_jz_conservation`.

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

## P2 COMPLETION — Tasks 2–3: single-stage confirmed dead; a real chiral instability found

`run_p2_sweep.jl` (+ `analyze_p2_timeavg.py`, `figures/p2_sweep.png`).
**All observables are TIME-MEANS over t≥20** — the endpoint Fz is a single-phase
snapshot of a fast Larmor oscillation (period ~1.6 at γB=4; the sudden 90° field
turn-on, GS along +x vs rotating field starting at +y, excites a large nutation).
Endpoint-based numbers (ΔFz~−1.7, double-diff~+2.0) were oscillation-phase noise.

**Task 2 — multi-Ω ΔFz (DDI-off is the single-particle baseline, shared DDI-on GS):**

| Ω | 0.50 | 0.65 | 0.74 | 0.80 | 0.85 |
|---|---|---|---|---|---|
| ΔFz = ⟨Fz⟩on − ⟨Fz⟩off | −0.06 | −0.11 | −0.16 | −0.20 | −0.17 |
| ⟨Fz⟩off ± osc | 0.70±0.5 | 0.92±0.7 | 1.06±0.8 | 1.15±0.8 | 1.23±0.9 |
| ⟨Lz⟩ on | 0.59 | 0.65 | 1.10 | 0.94 | 0.99 |

ΔFz is a **weak NEGATIVE** DDI suppression (grows mildly with Ω, correlates with
vortex Lz onset) that sits **within the single-particle oscillation band**. DDI
suppresses the axial tilt, does not enhance it; no sharp Ω_c kink. Confirms Task-1.

**Task 3 — CW−CCW double difference at Ω_c=0.74 (time-mean):**

| | CCW (+Ω) | CW (−Ω) |
|---|---|---|
| ⟨Fz⟩ off | 1.06±0.76 | 1.06±0.76 → **d_off = 0.00 (Ω-EVEN)** |
| ⟨Fz⟩ on | 0.90±0.11 | 0.30±1.25 → d_on = 0.60 |
| \|⟨F⟩\| on (end) | 5.12 | **2.26 (runaway)** |

- **Single-particle Fz is Ω-even** → d_off = 0. No chiral net-M_z from the
  single-particle path (the nutation is set by the shared +y turn-on, not sign(Ω)).
- **DDI-on CW depolarises catastrophically**: \|⟨F⟩\| runs away 6→2.3, still
  dropping at t=30. **dt-CONVERGED** (`run_p2_dtcheck.jl`: dt=2e-4 vs 4e-4
  bit-identical, |F| and Fz to 3 digits at all t) ⇒ this is a **PHYSICAL chiral
  instability** (counter-rotating drive resonantly pumps spin excitations), NOT a
  `split_step!` 1st-order-DDI artifact.
- But the chiral effect is **loss of \|F\|**, not a clean chiral magnetisation:
  the 0.60 double difference is buried under the CW run's Fz std (1.25) on a
  non-stationary collapsing-|F| background.

⇒ **Single-stage gives no clean separable chiral net-M_z Barnett — confirmed
dead.** The one genuine chiral effect (CW depolarisation instability) is not the
observable we want. Two-stage remains the necessary path (Task-1 mechanism).

**Design note for two-stage / any future single-stage run:** start the rotating
field ALIGNED with the GS field (B(0)=+x̂, i.e. Bx phase 0 / By phase ∓π/2) to
kill the 90° turn-on nutation (the ±0.8 single-particle oscillation). Currently
Bx phase ±π/2 ⇒ B(0)=+ŷ, a sudden 90° jump.

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
