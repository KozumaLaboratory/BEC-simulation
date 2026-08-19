# Rotation-assisted EdH quench — experimentalist sheet

> **FROZEN 2026-05-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

> **Renamed 2026-08-19 (issue #344).** The protocol on this sheet is **this
> project's own**, not Klaus et al. 2022's. The two branches are named by what
> rotates: **trap-rotation branch** (mechanical trap rotation, −Ω·L_z Coriolis)
> and **field-rotation branch** (rotating B̂ / magnetic stirrer). Authority:
> `docs/conventions/klaus_name_disambiguation.md`.

> ## Vintage — read before using any number on this sheet
>
> Every number here was produced **before 2026-07-29**, when `bce2068f`
> ("211 Eu configs pinned m=-F under a field that prefers m=+F") reverted the
> field sign across the Eu config corpus. The prescriptions below — including
> `|Ω| / ω_⊥ = 0.468 ± 0.003 at B = 2.6 nT`, quoted to three significant
> figures — have **not** been re-derived since. Treat them as the best estimate
> of 2026-05-26, not as a current recommendation, and re-run before setting a
> knob in the lab.
>
> What does **not** apply, measured rather than assumed: the 11x
> quadratic-Zeeman geometry-factor correction (`q_geometry` 35/144 → 455/20592)
> cannot move this sheet. At 2.6 nT, `q/h = 9.6e-7 Hz` against `p/h = 42.3 Hz`
> — a ratio of 2.3e-8, so an 11x error on it is still 1e-5 Hz (`ed3be749`,
> 2026-07-30). That correction disqualifies the gauss-band scans, not this one.
>
> "Publication-grade, all 6 acceptance gates PASS" below is a statement about
> **2026-05-26's gates and 2026-05-26's field convention**. It is left as
> written because it is what the record said; it is not a claim about today.

**Status (2026-05-26):** publication-grade.  All 6 acceptance gates
PASS; mechanism (Fig K10) verified to be Jz-conservation-driven
orbital mode selection under H − ΩL_z.  See
`docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md` for the
full record.

## Three-regime Ω operating window (2026-05-27)

After completing both the short-time Ω refinement and the long-time
vortex-nucleation scan, the recommended Ω splits by purpose:

| Regime                           | Ω/ω_⊥           | Optimised for                               |
|----------------------------------|-----------------|---------------------------------------------|
| **Short-time spin readout**      | **0.468 ± 0.003** | P_{-5,-4} peak at t ≈ 20 ms (3-digit refined) |
| **Long-time balanced point**     | **≈ 0.5**         | P_exc ≈ 0.96 + 24 vortices @ t = 145 ms     |
| **Vortex-rich (turbulent)**      | **≈ 0.7**         | 56 vortices, but P_exc drops to 0.89        |

The simplest single experimental recommendation is **|Ω|/ω_⊥ = 0.5**.
It is balanced across both short-time and long-time observables and
sits at the cascade-completion peak.

## Optimal-Ω caveat (2026-05-27)

The sampled point |Ω|/ω_⊥ = 0.5 gave the highest P_{adj} = 0.540 at
B = 2.6 nT in the original 3-point Ω scan {0.3, 0.5, 0.7}, but a
parabolic interpolation through those three points has its vertex at
**|Ω*|/ω_⊥ ≈ 0.42** with predicted P_max ≈ 0.558 — slightly above the
sampled best.  Therefore "0.5 is the best sampled point" is correct,
but **"0.5 is the operational optimum"** would overstate the
precision.

Honest statement of the recommendation:

> **Operating window:** |Ω| / ω_⊥ = 0.468 ± 0.003 at B = 2.6 nT (7-pt parabolic fit),
> with the precise optimum awaiting a local 7-point refinement
> (dispatched).  Literature on rotating dipolar BECs
> (O'Dell–Eberlein, Cai–Yuan–Rosenkranz–Pu–Bao, Halder et al.)
> shows the critical / optimal rotation rate depends on DDI
> strength, contact interaction, polarisation angle, trap shape,
> and rotation protocol — there is no universal Ω_opt.  Our
> Eu-specific Ω* will be reported with a parabolic-fit
> uncertainty once the 7-point refinement completes.

## Time-scale clarification (2026-05-27)

The protocol below targets the **short-time branch** (hold ≲ 14 ms ≈
10 ω⊥⁻¹), where the load-bearing observable is **spin excitation**
(P_{adj}, P_exc) and the orbital angular momentum manifests as
per-component L_z^{(m)} (no localised vortex cores yet).

For the **long-time branch** (hold ≳ 145 ms ≈ 100 ω⊥⁻¹), existing
dipolar-BEC theory (Prasad *et al.*, arXiv:1906.08664) predicts
vortex entry at t ≈ 350 ω⊥⁻¹ ≈ 510 ms and Abrikosov-lattice
formation at t ≈ 5000 ω⊥⁻¹ ≈ 7 s.  Our long-time probe
(`runs/klaus_quench_long_time/`) is dispatched to test whether the
trap-rotation branch protocol with mechanical trap rotation enters that regime;
results to be added when the simulation completes.

If both branches reproduce — short-time spin excitation + long-time
vortex nucleation — the protocol becomes a **dual signature** that
the experimentalist can use to identify the rotation-assisted
dipolar dynamics unambiguously.

### Long-time results (2026-05-27, dispatched and extracted)

Three cells confirm the dual-signature picture:

| protocol                         | P_exc(end) | Fz/N(end) | z=0 vortices (+/−) |
|----------------------------------|-----------:|----------:|--------------------|
| Ω = −0.5 keep_rot, t = 145 ms    | **0.958**  | −0.518    | **+6 / −18**       |
| Ω = −0.5 keep_rot, t = 510 ms    | **0.974**  | −0.469    | **+5 / −19**       |
| Ω = 0 baseline,     t = 510 ms   |  0.072     | −5.869    |  +0 / −0           |

So the long-time signature is observable.  Atom number is conserved
to 10⁻⁶ throughout; no atom loss is needed to see this.

## Implementation note (2026-05-27)

The validated protocol below uses **physical rotation of the trap
potential** (= the −Ω L_z Coriolis term in the rotating frame).
In an Eu BEC experiment this is implemented by rotating an
anisotropic optical trap mechanically.

A separate "magnetic stirrer" picture (rotating B-field direction
→ rotating DDI anisotropy) was tested in a 6-cell scan with an
instantaneous B tilt at the hold start and gave a **null result** —
no Ω dependence at all.  In the ω_L ~ Ω regime at B_hold = 2.6 nT,
the spin polarisation does not adiabatically follow the rotating B,
so DDI sees a static spin axis.  A proper field-rotation branch protocol would
need an adiabatic tilt-up stage at strong B before the quench
(7-stage pipeline; not yet dispatched).  Below assumes the
physical-trap-rotation implementation.

## Two field regimes — the load-bearing distinction

Treat the protocol as **two physically separate field regimes**:

```
preparation regime (strong B, ~G to ~mG):
  Zeeman energy ≫ DDI energy → spin manifold gapped, EdH frozen
  use this regime for: stretched-state preparation, calibration,
  Feshbach tuning, optical pumping
  rotation here is null for spin excitation (trap-rotation branch prep_only verified:
  P_{-5,-4} = 0.225 ≈ 0.219 baseline)

EdH-active regime (weak B, ~1–5 nT = 10⁻⁵ G):
  Zeeman energy ~ DDI energy → spin-flip channels OPEN
  this is where the protocol's spin excitation and vortex
  nucleation happen
  rotation here drives the cascade (P_{-5,-4} → 0.54, P_exc → 0.97
  at long time)
```

**The rotation belongs in the weak-field regime, not the prep regime.**
Crossing from strong B to weak B (the B quench) is what opens the
EdH channels that rotation can then act on.

## What to do

```
1. Prepare a stretched spinor state  m = ±F  in Eu-151 (F = 6) at
   convenient laboratory B (~G to ~mG range is fine for the
   preparation phase — Zeeman pinning here is desirable, not a
   problem).

2. Quench the bias field DOWN to the EdH-active regime:
                                  B_hold ∈ [1, 5] nT = [10⁻⁵, 5×10⁻⁵] G
   Default target:                B_hold = 2.6 nT = 2.6×10⁻⁵ G (Matsui-like)
   Optional sharper peak:         B_hold = 1.3 nT, |Ω|/ω_⊥ ≈ 0.3

3. NO pre-rotation needed.        Skip rotation at the strong-B prep.

4. WAIT 1–2 ms after the quench   (let the EdH channel fully open;
   ends.                           rotating earlier loses ~15% of signal).

5. Turn on trap rotation with chirality opposite to the initial spin
   polarisation (counter-rotating with the stretched-spin direction).

6. Rotation frequency, tied to B (3-pt parabolic fit; awaiting 7-pt
   refinement):
                                   |Ω| / ω_⊥ ≈ 0.3      at B = 1.3 nT
                                   |Ω| / ω_⊥ = 0.468 ± 0.003 at B = 2.6 nT (7-pt parabolic fit)  (default)
                                   |Ω| / ω_⊥ ∈ [0.5, 0.6] at B = 5.2 nT
   Off-diagonal (small B + large |Ω| or large B + small |Ω|) is
   sub-optimal.

7. Keep rotation on for           ≥ 8 ms after rotation onset.

8. Observe:
     - small N (~10⁴):
         P_adj = (N_{m_init ∓ 1} + N_{m_init ∓ 2}) / N    (peak ≈ 0.63)
     - Matsui-scale N ≈ 5×10⁴:
         P_exc = 1 − N_{m_init} / N                       (≈ 0.78)
     - Component-resolved imaging:
         m_init ∓ 1 component shows a ring with one phase winding;
         m_init ∓ 2 shows a larger ring with two phase windings.
```

## Mechanism (1-line)

Each DDI-mediated spin flip m_init → m_init ∓ 1 carries one quantum
of orbital angular momentum (winding number ±1, sign set by J_z
conservation).  Sustained rotation H − ΩL_z shifts the energy of
that orbital mode by ΔE = −Ω · ℓ; matched chirality (Ω · sign(m_init)
< 0) lowers the mode energy and enhances the spin-flip transition.

## Expected signature

| observable                                  | Ω=0 baseline | matched chirality, |Ω|/ω_⊥ = 0.5 | best (B=1.3, Ω=−0.3) | best (delay = 2 ms) |
|---------------------------------------------|-------------:|-----------------------------------:|----------------------:|---------------------:|
| P_adj  (N=10⁴)                              | 0.22         | 0.54                               | 0.585                 | 0.626                |
| P_exc  (N=10⁴)                              | 0.23         | 0.82                               | 0.78                  | 0.83                 |
| P_exc  (N=5×10⁴)                            | 0.60         | 0.78                               | —                     | —                    |
| ⟨F_z⟩/N drift                               | 0.30         | 1.86                               | 1.68                  | 1.83                 |
| ring-pattern visibility in m_init ∓ 1 (z=0) | weak         | strong                             | strong                | strong               |

## Falsification tests (if signal is absent / wrong)

| symptom                              | interpretation                                                    |
|--------------------------------------|-------------------------------------------------------------------|
| signal absent at any |Ω|/ω_⊥          | DDI not active — increase atom density / verify ε_dd               |
| signal absent at all B_hold           | B quench not opening the channel — check post-quench B value       |
| signal absent with rotation kept on  | rotation chirality may be wrong — try the opposite trap rotation   |
| signal at Ω > 0 for m = −F initial   | rotation chirality is *reversed* in lab convention vs simulation; the protocol still works, just with the opposite sign |
| signal at high B (>10 nT)            | Zeeman should re-pin; if not, weak-field-only mechanism not active |

## Boundary conditions where this protocol breaks

- N ≪ 10³: DDI too weak, EdH cascade absent.
- N ≫ 10⁵: cascade extends well past m_init ∓ 2, so the simple
  P_adj observable saturates; switch to P_exc.
- B_hold > ~10 nT: Zeeman re-pinning closes the spin-flip channel.
- B_hold = 0: spin axis is ill-defined; mechanism still operates but
  the observable definition needs care.

## Validation chain (this simulation)

| gate                                     | result                                  |
|------------------------------------------|-----------------------------------------|
| DDI off → 0                              | 0.000          PASS                     |
| no B quench → 0                          | 0.000          PASS                     |
| 32³ ↔ 64³ grid convergence               | 4-digit match  PASS                     |
| (init m × Ω sign) reversal symmetry      | 3-digit match in both branches  PASS    |
| dt/2 numerical reproducibility           | 0.02–0.14% deviation  PASS              |
| N = 5×10⁴ qualitative reproducibility    | P_exc +30% over baseline  PASS (with metric caveat) |
| chirality timing decomposition           | hold_only = 97% of keep_rot  (pre-rotation null) |
| B_hold sweep, [1.3, 5.2] nT              | broad sweet spot                        |
| B_hold = 10 nT                           | Zeeman re-pinning (signal → baseline)   |
| (B × Ω) 2D map (9 points)                | diagonal resonance pattern, peak 0.585 at (B=1.3 nT, Ω=−0.3) |
| rotation start-delay tolerance           | optimal ~2 ms after quench, peak 0.626  |
| mechanism: orbital winding = ±k per Δm = ∓k flip | verified at machine precision (winding 0, ±1, ±2) Fig K10 |

## Caveats

- Effective LHY closure not active in these runs (`lhy: none`).  If
  high-density LHY effects are physically relevant in the target Eu
  experiment, the protocol should be re-tested with polar / icosahedral
  LHY closures (existing infrastructure).
- The protocol simulation models trap rotation by the rotating-frame
  Coriolis term `rotating_frame_omega` in the code; the lab experiment
  uses physical rotation of the optical trap at frequency Ω/2π.
  Sign-convention mapping from simulation Ω to lab rotation direction
  should be verified once per experimental setup, but the **chirality
  rule** ("rotate against the stretched-spin direction") is
  convention-independent.
- 32³ box [12, 12, 12] a_ho, dt = 0.005 ω_ref⁻¹.  At N = 5×10⁴ the
  effective μ approaches the Zeeman gap at B_hold = 10 nT, which is
  the regime where Zeeman re-pinning kicks in.

## Source files

- spec: `docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md`
- figures: `docs/manuscript/figures/klaus_quench_fig_k{1..10}.png`
- data: `runs/klaus_quench/summary.json`
- run YAMLs: `runs/klaus_quench/*.yaml`  (27 cells across 4 batches)
- analysis scripts: `scripts/validation/klaus_quench_{summary,density_slices,mode_extract}.jl`
- plotters: `scripts/validation/make_klaus_quench_figures.py`,
  `scripts/validation/make_klaus_quench_fig_k10.py`
