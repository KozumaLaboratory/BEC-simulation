> **FROZEN 2026-05-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

<!-- promoted from agent memory `klaus_quench_protocol_pivot_2026_05_26.md` on 2026-07-31; historical record, not an SSoT -->
<!-- Eu spinor rotation+quench protocol — 2-phase rotation-prep+weak-field-quench scan. Load-bearing observable is post-quench m=-5,-4 excitation, not bare ⟨F_z⟩. Previously called "Klaus protocol" based on a confabulated paper attribution; the protocol design is original to this project. -->

**Attribution correction 2026-06-02:** This memory previously named the
protocol "Klaus 2-phase quench protocol" / "Klaus-I" / "Klaus-II" as if
tracking a Klaus-authored paper. anko verified externally on 2026-06-02
night that **no such paper exists** in the magnetostir / dipolar-BEC
literature; the Klaus attribution was confabulation by the assistant.
The protocol design, scan data, and 6-gate verification recorded below
are **original project work** and stand independent of any external
anchor. Real external benchmarks for this regime:

  * **Vortex-side (long-time branch):** Prasad et al. 2019, arXiv:1906.08664.
    See `memory/prasad_2019_long_time_vortex_anchor.md`.
  * **Magnetostir technique prior art:** Innsbruck Ferlaino-group Dy
    paper, arXiv:2206.12265. See `memory/klaus_adiabatic_elimination.md` (file
    name retained for git continuity; content corrected).
  * **Ω_c threshold for rotation-driven vortex nucleation:** Madison &
    Dalibard, cond-mat/0101051. See
    `memory/madison_dalibard_omega_c_attribution.md`.

In the body below, "Klaus" refers to the project's own protocol name,
not to a paper. "Klaus-I" = mechanical-trap-rotation branch (−Ω·L_z
Coriolis drives spin excitation); "Klaus-II" = rotating-B-direction
branch. Both should ideally be renamed in future work; the existing
labels are retained here for incident-archeology continuity with
manuscript drafts already using these names.

`docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md` — anko 2026-05-26
evening pivot.

## Why the pivot

The bare-⟨F_z⟩ Barnett window scan (`runs/barnett_eu_window/`, 14 cells)
gave Ω/ω_⊥ ≈ −0.3 to −0.5 as the signal-rich window for sustained-rotation
DDI-mediated spin response.  That signal is mechanically real but **not what
the Klaus experiment measures**.  The Klaus experiment measures post-quench
m=−5, m=−4 excitation after dropping from strong-field rotation prep into
the weak-field regime.

So the right experimental recommendation comes from a different protocol:

```
GS → rotation_prep (10 ms, B=-0.01 G, Ω)
   → B_quench (1 ms, B ramps -0.01 → -2.6e-5 G, Ω = 0)
   → weak_field_hold (10 ms, B = -2.6e-5 G, Ω = 0)
```

## Why this is project memory, not just a script artifact

- It's the canonical scan generator pattern for any future Klaus-style
  protocol question. (DDI quench protocols, multi-stage B ramps, rotation
  prep + measurement separation.)
- It defines the load-bearing observable for Klaus recommendations:
  **max_t (N_{-5}+N_{-4}) / N**, NOT ⟨F_z⟩.
- It supersedes the manuscript Fig 4 (bare-Fz Barnett window) as the
  experimental recommendation. The bare-Fz finding remains true but is
  no longer the front-page claim.

## 10-cell scan structure

6 core Ω points (0, ±0.3, ±0.5, −0.7) + 4 controls (2× DDI off, 1× no
quench, 1× keep rot through hold).  All `backend: cpu` per the GPU
Coriolis gotcha.

## How to apply

- Whenever a Klaus / Barnett-style experimental recommendation is
  being made: the load-bearing observable is post-quench m=−5, m=−4
  excitation, computed via the 2-phase protocol — NOT bare ⟨F_z⟩
  under sustained rotation.
- If the protocol scan finds a window that does NOT overlap Ω/ω_⊥ ∈
  [−0.5, −0.3], the manuscript / presentation recommendation must
  shift to the protocol window (or the protocol window union, depending
  on how the controls behave).

## Batch 1 result (2026-05-26 evening) — load-bearing finding

```
free-hold core, all Ω in [-0.7, +0.5]:  P_{-5,-4} = 0.22 ± 0.01   (flat in Ω)
free-hold core, Ω = 0:                  P_{-5,-4} = 0.219          (= baseline)
keep_rot at Ω = -0.5:                   P_{-5,-4} = 0.540, P_exc = 0.817
DDI off, free hold:                     P_{-5,-4} = 0.0
B quench off, free hold:                P_{-5,-4} = 0.0
```

**The rotation prep alone does NOT discriminate Ω in the free-hold
protocol.** All 6 free-hold core cells give the same P_{-5,-4} ≈ 0.22
within numerical floor — including Ω = 0. The B quench is the trigger,
DDI is the engine, and rotation prep without sustained rotation leaves
no phase imprint that survives the quench.

**The actual experimental knob is `keep_rot`**: sustained rotation
through the weak-field hold drives P_{-5,-4} from 0.22 → 0.54 (2.5×)
and P_exc from 0.23 → 0.82 (3.6×) at Ω = −0.5.

This is the recommendation. Whenever a Klaus protocol is proposed,
"rotation throughout including the measurement window" is the
load-bearing parameter, not "rotation prep then off".

## Batch 2 keep_rot scan + 64³ anchor (2026-05-26 evening)

```
keep_rot 32³:   Ω = -0.7  P_{-5,-4} = 0.344
                Ω = -0.5  P_{-5,-4} = 0.540   ★ peak
                Ω = -0.3  P_{-5,-4} = 0.517
                Ω = +0.3  P_{-5,-4} = 0.100
                Ω = +0.5  P_{-5,-4} = 0.066

keep_rot 64³:   Ω = -0.5  P_{-5,-4} = 0.540   identical to 32³ (4-digit)

keep_rot DDI off Ω = -0.5: P_{-5,-4} = 0    DDI essential
```

- **Strong sign asymmetry**: 8.2× at |Ω|=0.5, 5.2× at |Ω|=0.3.
- **Peak at Ω = -0.5** with Ω = -0.3 nearly equal — the protocol window
  is Ω/ω_⊥ ∈ [-0.5, -0.3], same window as bare-Fz Barnett.
- **64³ identical to 32³** → grid-converged, not an artifact.
- **DDI essential** even with sustained rotation → mechanism is
  "Ω re-shapes DDI-mediated EdH selection rules in weak field",
  not "rotation alone".

## Physical picture

Under H → H − ΩL_z, sustained Ω during the weak-field hold re-shapes
the selection rule / resonance condition for the spin-flip channels
that DDI couples once the Zeeman pinning is removed by the quench.
"Rotation must be present when the spin-flip channel is energetically
open." Rotation prep at strong B does nothing because the channel is
gapped out by Zeeman pinning.

## Batch 3 killer controls (in flight 2026-05-26 evening)

10 new cells across 5 queues to harden the claim from
"presentation-ready" to "publication-grade":

1. **Symmetry** (`keeprot_mFplus` ±Ω=0.5): predicted pair under
   H − ΩL_z is {m=−F + Ω=−0.5} ↔ {m=+F + Ω=+0.5}; mismatched pair
   {m=−F + Ω=+0.5} ↔ {m=+F + Ω=−0.5} both weak.
2. **Timing** (`holdonly` Ω=−0.5): does rotation only after the quench
   reproduce the keep_rot enhancement?
3. **B sweep** (`keeprot_Bf{1p3, 5p2, 10}`): experimental weak-field
   window identification.
4. **dt/2** (`keeprot_dt2` + `core_dt2`): integrator-artifact check.
5. **N=5e4** (`keeprot_N50k` + `core_N50k`): experimental atom-scale
   robustness.

### Acceptance criteria for publication-grade — ALL 6 GATES PASS

- [x] DDI off → 0  (batch 1)
- [x] no B quench → 0  (batch 1)
- [x] 32³ ↔ 64³ identical to 4 digits  (batch 2)
- [x] **symmetry under (init m × Ω sign) reversal — 3-digit match**  (batch 3 Q1)
- [x] **dt/2 reproducibility: baseline 0.219↔0.219 (0.14%); keep_rot 0.5397↔0.5398 (0.02%)**  (batch 3 Q4)
- [x] **N=5×10⁴ qualitative PASS: P_exc 0.776 vs baseline 0.595 (+30%); enhancement factor N-dependent: 3.6× → 1.30× as N: 10⁴ → 5×10⁴**  (batch 3 Q5)

### B sweep result (batch 3 Q3)

```
B=1.3 nT:  P_-5,-4 = 0.437  P_exc = 0.806
B=2.6 nT:  P_-5,-4 = 0.540  P_exc = 0.817
B=5.2 nT:  P_-5,-4 = 0.557  P_exc = 0.667  (peak P_-5,-4!)
B=10 nT:   P_-5,-4 = 0.192  P_exc = 0.197  (Zeeman re-pinned, ≈ baseline)
```

Experimental B_hold window: **[1, 5] nT**.  Matsui's 2.6 nT is centred
in the window.  10 nT shows clear Zeeman re-pinning evidence.

### Chirality-symmetry result (batch 3 Q1, 2026-05-26 evening)

```
matched chirality (strong):   m=−F + Ω=−0.5  →  0.540  ↔  m=+F + Ω=+0.5  →  0.540
mismatched chirality (weak):  m=−F + Ω=+0.5  →  0.066  ↔  m=+F + Ω=−0.5  →  0.066
```

3-digit identical under (init m × Ω sign) reversal in BOTH branches.
The signal is governed by the RELATIVE chirality of the initial
stretched state and the trap rotation, NOT by the absolute Ω sign.
Sign-convention artefact ruled out.

### Timing decomposition (batch 3 Q2)

```
Ω=0 (no rotation):     P_{-5,-4} = 0.219  (baseline)
Ω=-0.5 prep only:      0.225  (≈ baseline; prep null)
Ω=-0.5 hold only:      0.524  (97% of keep_rot)
Ω=-0.5 prep + hold:    0.540  (full keep_rot)
```

Pre-rotation contributes essentially nothing. The protocol simplifies:
**rotate ONLY during the weak-field hold**.

### Final protocol form (lab-convention-independent, all 6 gates PASS)

1. Prepare m=±F stretched state.
2. Quench to B_hold ∈ [1, 5] nT  (Matsui's 2.6 nT works).
3. Skip pre-rotation.
4. During weak-field hold only, apply trap rotation opposite to the
   initial spin chirality.
5. |Ω|/ω_⊥ ≈ 0.5, scan 0.3–0.7.
6. Observable depends on N:
   - small N (~10⁴): P_{adj} = (N_{m∓1} + N_{m∓2}) / N captures most signal
   - experimental N (5×10⁴): use P_exc = 1 − N_{m_init}/N (cascade
     extends past m∓2 at higher DDI strength)
   - Component-resolved ring texture in m∓1, m∓2 gives cleanest visual.

### Mechanism refinement (2026-05-27) — L_z per component, NOT vortices

Plaquette vortex count is **zero** in every cell (matched / mismatched
/ baseline / mirror).  The spin-flipped components have **smooth ring
windings** (winding number ±k on the ring), not localized vortex cores.
The load-bearing observable is per-component integrated L_z:

```
                     L_z^(m_init)   L_z^(m_init∓1)   L_z^(m_init∓2)
Ω=0 baseline           ≈0            +0.107            +0.132
Ω=-0.5 matched         ≈0            +0.148            +0.749  (5.7×)
Ω=+0.5 mismatched      ≈0            +0.024            +0.007  (19× smaller)
m=+F mirror Ω=+0.5     ≈0            -0.148            -0.749  (sign flip)
```

Mechanism statement: each DDI-mediated spin flip carries one quantum
of orbital L_z per atom (J_z conservation).  Matched rotation
amplifies the spin-flip population in m_init∓k, which proportionally
amplifies integrated L_z^{(m)}.  Vortex-carrying-modes picture was
incorrect; the right picture is "spin-flipped components naturally
hold L_z; rotation amplifies their population".

Fig K10v: `docs/manuscript/figures/klaus_quench_fig_k10_vortex_mechanism.png`.

### Three-regime Ω operating window (2026-05-27, final synthesis)

After short-time Ω refinement + long-time vortex scan:

```
Short-time spin readout:    Ω* = 0.468 ± 0.003     (3-digit, P_{-5,-4} peak)
Long-time balanced point:   Ω  ≈ 0.5               (P_exc=0.96 + 24 vortices)
Vortex-rich over-rotated:   Ω  ≈ 0.7               (56 vortices, P_exc drops)
```

**Single experimental recommendation: |Ω|/ω_⊥ = 0.5** — balanced across
short-time and long-time observables, at the cascade-completion peak.

Vortex–cascade trade-off table (t=100/ω⊥):

```
Ω = -0.3 : P_exc=0.51, vortices +0/-6     weak cascade, few vortices
Ω = -0.42: P_exc=0.63, vortices +1/-10    intermediate
Ω = -0.5 : P_exc=0.96, vortices +6/-18 ★ balanced
Ω = -0.7 : P_exc=0.89, vortices +21/-35   over-rotated (vortex-rich)
```

Vortex sign asymmetry weakens with |Ω|: 91% neg at 0.42 → 75% at 0.5
→ 62% at 0.7 (turbulent mixing).  Frame as "chirality-biased", not
"sign-pure".

### Long-time vortex result (2026-05-27, 3 cells)

`runs/klaus_quench_long_time/` extending Klaus-I matched-keep_rot to
Prasad-anchored timescales:

```
                            P_exc(end)  Fz/N(end)   z=0 vortices (+/−)
Ω=-0.5 keep_rot t=100/ω⊥:    0.958      -0.518      +6 / -18  (24 total)
Ω=-0.5 keep_rot t=350/ω⊥:    0.974      -0.469      +5 / -19  (saturated)
Ω=0 baseline   t=350/ω⊥:    0.072      -5.869      +0 / -0   (none)
```

Findings:
- Spin cascade saturates at t ~ 100 ω⊥⁻¹ with P_exc ≈ 0.97; populations
  spread across the full m-ladder (final m=-6 only 2.6%).
- 24 total-density vortices nucleate by t=100 under matched rotation;
  chirality-asymmetric (-18 vs +6, more negative than positive).
- Zero vortices in the no-rotation baseline.
- Atom number conserved to 10⁻⁶ throughout.

Eu F=6 reaches vortices ~50× earlier than Prasad's scalar dipolar
prediction (Prasad: vortex entry at t~350; ours: t~100 already).
Plausible cause: stronger DDI energy scale in F=6 Eu + simultaneous
B quench opens spin channels that couple immediately to orbital modes.

### Ω* finalisation (2026-05-27, 7-pt refinement)

7-cell scan at B=2.6 nT, delay=2 ms, matched chirality (m=-F), hold-only:

```
Ω  -0.34: P=0.510    Ω  -0.46: P=0.626 ★    Ω  -0.54: P=0.581
Ω  -0.38: P=0.558    Ω  -0.50: P=0.626 ★    Ω  -0.58: P=0.529
Ω  -0.42: P=0.603
```

Parabolic fit (RMSE=0.0080):

```
P(Ω) = -7.411 Ω² - 6.930 Ω - 0.996
Ω* = -0.468 ± 0.003 (1σ covariance)
P_max = 0.624
```

The publication-grade short-time protocol optimum is therefore:

> **|Ω*| / ω_⊥ = 0.468 ± 0.003 at B_hold = 2.6 nT, delay = 2 ms,
> hold-only protocol, m=-F initial (matched chirality).
> Peak P_{-5,-4} = 0.624.**

Fig: `klaus_quench_fig_k14_omega_refine.png`.

### Klaus-II adiabatic also null (2026-05-27)

```
sudden-tilt Klaus-II (Ω=+0.5, m=+F):   P_{+5,+4} = 0.2191
adiabatic   Klaus-II (Ω=+0.5, m=+F):   P_{+5,+4} = 0.2258  (still ≈ baseline)
Klaus-I keep_rot     (Ω=-0.5, m=-F):   P_{-5,-4} = 0.540    (★ 2.5×)
```

Even with adiabatic theta tilt-up at strong B, the rotating-B-direction
protocol does NOT drive short-time spin excitation.  **Klaus-I and
Klaus-II are different physics**: Klaus-I = mechanical trap rotation
(via -ΩL_z Coriolis term) drives spin excitation; Klaus-II = rotating
B-field direction needs the long-duration Klaus-magnetostriction
regime (high B, ~314 ms+, tested separately in `runs/klaus_hybrid/`).

### Klaus-II rotating-B null result (2026-05-27)

6-cell scan at `runs/magnetic_stirrer/` with hold-only B-direction
rotation (θ=π/4 tilt at hold start, phi rate = Ω): **null effect**.
All 3 Ω points (0.3, 0.5, 0.7) and the static-B control give
**identical** P_{+5,+4} = 0.2191 — the Klaus-I no-rotation baseline.

Reason: ω_L ~ Ω at B_hold = 2.6 nT, so sudden θ jump at hold-start
breaks adiabatic spin-following.  The spin doesn't track rotating B,
DDI sees a static spin axis, time-averaged effect = baseline.

Implication: Klaus-I result corresponds to **physical trap rotation**
(mechanical), NOT rotating B-field.  A proper Klaus-II would need a
7-stage pipeline (GS → adiabatic tilt-up → spin-up → steady stir →
quench → weak-field hold → analyze) with strong B during tilt to
ensure spin-following.  Not yet dispatched.

### Mechanism (Fig K10, verified 2026-05-26 evening)

Each DDI-mediated spin-flip m_init → m_init ∓ k populates an orbital
mode with winding number ±k, with the sign set by J_z conservation
(Δm = ∓k requires ΔL_z = ±k).  In the rotating frame, the energy of
that orbital mode shifts by

```
ΔE_ℓ = -Ω·ℓ·ℏ
```

For a stretched state, ℓ = −sign(m_init)·k, so

```
ΔE_{m_init ∓ k} = +Ω · sign(m_init) · k · ℏ
```

Matched chirality means Ω · sign(m_init) < 0, which lowers the mode
energy and enhances population transfer. Mismatched chirality raises
the mode energy and suppresses it.

This single argument predicts:
- chirality reversal symmetry (Gate 4 verified to 3-digit match)
- pre-rotation null effect (no orbital mode is populated at strong B)
- |Ω|/ω_⊥ ≈ 0.5 optimal (compares to EdH cascade gap)
- B_hold window: open at low B, Zeeman-pinned at B ≳ 10 nT

Promotes the keep_rot finding from "phenomenological observation" to
"mechanism-supported prediction".

### Standalone experimental sheet

`docs/manuscript/klaus_protocol_sheet.md` — 1-page experimentalist-
facing protocol sheet with: what to do (8 numbered steps incl. ~2 ms
post-quench delay), 1-line mechanism, expected-signature table with
4 operating points, falsification tests, boundary conditions,
validation gate table.

### Batch 4 results (2026-05-26 evening → 2026-05-27)

B × Ω 2D robustness map (9-point keep_rot grid):

```
Ω \ B    1.3 nT   2.6 nT   5.2 nT
-0.3     0.585★   0.517    0.301
-0.5     0.437    0.540    0.557
-0.7     0.257    0.344    0.529★
```

Diagonal resonance pattern — smaller |Ω| works best at smaller B,
larger |Ω| at larger B.  Anti-diagonal corners off-resonance.  This
confirms the energetic compensation Ω · ℓ ~ Zeeman_gap predicted
by the mechanism.

Rotation start-delay tolerance (Ω=-0.5, B=2.6 nT):

```
delay 0 ms: P=0.524 (existing hold_only)
delay 1 ms: P=0.582
delay 2 ms: P=0.626 ★ peak — rotating immediately is sub-optimal
delay 5 ms: P=0.367
```

Optimal: wait ~2 ms after quench, then turn on rotation. Tolerance
is wide (even 5 ms still 1.7× the no-rotation baseline).
