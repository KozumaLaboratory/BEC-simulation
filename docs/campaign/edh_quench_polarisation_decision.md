# Rotation-assisted EdH quench (Eu): field sign, polarisation convention, and what gets re-derived

**Scope.** Issue #343, which posed three things: (1) a **defect** in the config
corpus fixed on 2026-07-29 whose numbers were never re-derived, (2) a
**convention difference** in the rotation-assisted EdH quench series that is not a defect and was
never adjudicated, and (3) the fact that (1) was **not in the machine-readable
gate** the campaign claims to run.

(1) and (3) hold. **(2) does not, and the measurement replaced it with a
sharper problem**: the two EdH-quench families are not on opposite sides of anything
— they are on the *same* side, and it is the wrong side. What looked like a
convention split was an `m`-label comparison across two different field
parameterisations. §4.2.

This document is the single place the polarisation decision is written. The
thesis must not mix conventions; if a chapter needs the other one, it cites this
file and says which.

**Type labels** (`CAMPAIGN.md` §5): §1 is A (provenance/tooling). §2 is A (a sign
convention reproduced on current code). §3 and §4 are **B** — physics agreement
against a closed-form expectation and a symmetry, on one seed at 32³, **not** C:
nothing here is compared to a published measurement. Producing commit for every
number below: **`b2d746cc`**, CPU unless stated, tier: none (these are campaign
measurements, not tests).

---

## 0. Verdicts, up front

| # | Question | Verdict |
|---|---|---|
| 1 | Is `bce2068f` in the ancestor gate? | **Yes**, as `eu-config-field-sign`, and the gate now **executes** (`cli.jl campaign-gate`) instead of being prose |
| 2 | How many stored runs does the new row disqualify? | **0 marginally.** All 200 gateable runs were already disqualified by older refs; 3 more have no producing commit at all |
| 3 | Does the field sign move the load-bearing observables? | **Yes, by ×2.2 to ×5.0.** Peak P_{−5,−4} 0.244 → 0.530; peak \|L_z\| 0.020 → 0.101. Nothing depending on either is quotable without re-derivation. §3 |
| 3b | Does the *rotation enhancement* survive the corrected field sign? | **No.** +15.8 % pre-fix vs **−0.45 %** post-fix, with the Ω knob proved live at both. `\|Ω\|/ω_⊥ = 0.468 ± 0.003` is **superseded** — not re-derivable as posed. §3.4 |
| 7 | What replaces the **superseded** `\|Ω\|/ω_⊥ = 0.468 ± 0.003`? | **`\|Ω*\|/ω_⊥ = 0.68 ± 0.04`** at the anti-aligned preparation, +24.9 % over Ω=0. Two digits, not three. §9.1 |
| 8 | Is the enhancement chirality-matched, as the sheet says? | **No.** The response is **even in Ω** to ≤ 0.124 %; Ω=0 is the minimum and both senses enhance equally. §9.2 |
| 9 | Then what is the mechanism? | **Centrifugal, not Coriolis.** A *static* trap weakened to ω_eff = √(ω_⊥²−Ω²) reproduces the whole effect to **0.06 %** across the range. **Rotation is not needed** — weaken the radial trap to **0.71 ω_⊥**. §9.3, §10.1 |
| 10 | Is it density, or the radial confinement? | **Radial.** A density-matched weakening along **z** instead lands *below* the baseline (−36 % of the gain). Same ω̄, opposite sign. §10.4 |
| 11 | Does the prescription hold at the other two fields? | **No, and differently.** 1.3 nT: **no window at all** (+1.8 %, flat) — the old `0.3 @ 1.3 nT` has no replacement. 5.2 nT: **two branches**, resolved in §11. §10.2 |
| 14 | Is the 5.2 nT dip a resonance? | **No — the prediction was made and failed.** ω_eff,dip ∝ B predicts a dip near 0.325 at 2.6 nT; the measured tail rises monotonically through it. §11.4 withdrawn; the second branch has no mechanism. §12.3 |
| 15 | Was the observable right? | **Not at 10.4 nT.** The peak must be taken *inside the hold*; over the whole trajectory it read the pre-hold transient and 7 of 10 arms were blind. Re-extracted: **0.00 % change at 1.3 / 2.6 / 5.2 nT**, so §9–§11 stand. §12.1 |
| 16 | Does it survive LHY? | **Yes.** `full_bdg` moves the baseline +0.07 % and the optimum +2.18 %; the enhancement goes +24.9 % → **+27.5 %**. §12.4 |
| 18 | The field-rotation branch (`eu151_klaus_phi_phys`) | **Two code defects, no physics.** Its GPU path was dead (`spin_density_vector` allocated host arrays → scalar-indexing error); and it reported **`conv = true` having never been asked**, because the rotating-basis GS returns no convergence flag and the writer defaulted it to `true` — so every such run satisfied CAMPAIGN guard 7 by construction. Both fixed and gated. §14 |
| 17 | Does the static substitution hold at long time? | **Yes on the peak; the endpoint is a different question.** At 64³, 145 ms: peak **static 0.49081 > rotating 0.40102 > baseline 0.37973** (+29.3 % over no-intervention). At the endpoint the *rotating* arm is the persistent one (0.40013, 2.23× static) — the opposite of what §13 said. §13's numbers are **RETRACTED** (§15): they were 32³, which inverts both orderings. §17 |
| 19 | Is the observable still seed-deterministic at 145 ms? | **The peak is; the endpoint is not.** Two seeds at 64³ leave the static peak identical to five decimals and move its **endpoint by 34.2 %** — which swallows the 18.8 % static-vs-baseline endpoint gap, so that one row stays open. §17.1 |
| 13 | 5.2 nT, resolved at 20 points + 64³ | **Two branches**, global max at ω_eff ≈ 0.55 (+17.0 %), secondary at ≈ 0.77, dip at ≈ 0.65 that **survives 64³** with 93 % of its depth. No single optimum quoted (criterion D1). The old `[0.5, 0.6]` maps to ω_eff ∈ [0.80, 0.87] — a declining shoulder below both maxima, so it is **refuted**, not merely unresolved. §11 |
| 12 | How much of §9 is seed noise? | **None.** 5 seeds agree to 5 decimals, and the seed was *proved live* (state overlap 0.9999997, growing to 1.9e−5). The observable is deterministic here; grid/dt remain the real uncertainty (G3: 2.5 %). §10.3 |
| 4 | Align the rotation-assisted EdH quench series to m=−F? | **No — and stop saying it in `m`.** The measured criterion is *aligned vs anti-aligned with B*. the EdH quench needs the **anti-aligned (Zeeman-highest)** state; under the project's +B_z that is m=+F. §4 |
| 4b | Is `eu151_klaus_phi_phys` really "the one Eu arc on the other side"? | **No.** `p > 0` puts m=+F at the *bottom*, so it is aligned like everything else — and therefore on the wrong side for the EdH quench. #343 §2's premise was an m-label comparison across two field parameterisations. §4.2 |
| 5 | Is the stored `(init m × Ω)` "mirror" pair still a mirror? | **No — `bce2068f` broke it.** Repaired here, and the repair is confirmed by measurement to 5 digits (§3.6 arm G). §5 |
| 6 | Which numbers get re-derived? | Two items, both blocked on regenerating the corpus at the anti-aligned preparation. §6 |

---

## 1. The gate is now executed, not described

`docs/campaign/CAMPAIGN.md` §4 guard 1 has always called itself "mechanical, not
a judgement call". Until 2026-08-19 **no code ran it**: the only file in the tree
that opened `fix_list.toml` was `test_docs_live_set.jl`, which asserts the file
exists. So the list could contain a ref that had rotted out of the clone, or
omit a fix the prose leant on, and nothing would say so. Both had happened —
`bce2068f` was named by `docs/manuscript/klaus_protocol_sheet.md` as the reason
its three-significant-figure prescriptions are stale, and was absent from the
list.

What landed:

- `src/workflow/validation/campaign_gate.jl` — `campaign_fix_list`,
  `run_producing_commit`, `campaign_gate_verdict`, `campaign_gate_report`.
- `julia --project=. scripts/cli.jl campaign-gate [--head=R] [--runs=D] [--list]`.
- `test/test_campaign_fix_list_gate.jl` (fast tier) — every ref is a live
  ancestor; the two documents' counts cannot drift; **red is proved reachable**
  before any green is trusted; and every commit SHA cited in `docs/campaign/` or
  `docs/manuscript/` prose is either a fix-list ref or an explicitly-reasoned
  non-correction. That last clause is the #343 class, generalised.

**The verdict is three-valued.** `:pass` / `:disqualified` /
`:unknown_provenance`. The third is not a shrug and is never folded into either
other: "no producing commit" is the condition this whole campaign was opened
over, and a sweep that reported it as either a pass or a fail would be lying in
one direction or the other.

### 1.1 Result of running it

`campaign-gate --runs=<main checkout>/runs`, 2026-08-19, HEAD `b2d746cc`:

```
campaign-gate: 15 refs from docs/campaign/fix_list.toml
  runs found : 203
  pass       : 0
  disqualified: 200
  unknown provenance: 3   <- not a pass and not a fail
```

133 of the **200 disqualified** have an Eu / klaus_quench / Matsui / Barnett /
EdH name (a name match, not a config read — it scopes the damage, it does not
classify it). The producing
commits cluster hard: 137 runs at `15a9f1ee` (2026-05-26), 32 at `306ef71a`
(2026-05-21), 9 at `e8168dcb` (2026-05-23) — i.e. the corpus is a May snapshot,
and every June–July correction postdates all of it.

**The number of runs the new row disqualifies on its own is zero**, and saying
so is the honest report: no stored run passes the other fourteen either, so
`eu-config-field-sign` cannot be the reason any of them is out. Its value is
prospective — it binds every run from here — and diagnostic: the gate now
*names* the field-sign correction when it explains a disqualification, instead
of leaving a reader to find it in a manuscript footnote.

Nothing under `runs/` is committed (723 tracked files, exactly one `.jld2`), so
this sweep is only reproducible against a working checkout that holds the
outputs. That is a pre-existing condition, recorded in
`docs/validation/stored_results_vintage_audit.md`, not something #343 introduced.

---

## 2. The field-sign knob is live (positive control)

Before any sensitivity claim: a table of nulls is worthless if the knob is not
connected, and this repo has shipped that mistake
(`mistake_null_from_a_degenerate_knob_2026_07_31`). So the first measurement
reproduces `bce2068f`'s own, on **current** code.

16³ ¹⁵¹Eu ground state, DDI off, spin-coherent θ=π/2 seed so every m is free to
win, GPU, HEAD `b2d746cc`:

| B_z | ⟨F_z⟩ | argmax m |
|---|---|---|
| −0.01 G | **+6.0** | +6 |
| +0.01 G | **−6.0** | −6 |

Identical to the 2026-07-29 measurement in the commit body. **Type A.** The
convention `H = −p·F_z`, `p ≡ −g_F μ_B B` holds on today's tree, and a null
below is a fact about the observable rather than about the plumbing.

---

## 3. Sensitivity table (gate 2)

Four arms of the real `klaus_quench` protocol, differing only in the sign of B_z
(prep, ramp endpoints and hold together) and in Ω. **CPU**, 32³, `lhy: none`,
DDI on, one seed, HEAD `b2d746cc`. Configs: `klaus_quench_om0p0.yaml` and
`klaus_quench_omm0p5_keeprot.yaml`, unmodified except for those two knobs.

### 3.1 Three instrument corrections, each of which changed the answer

**(a) `result.jld2["psi"]` is not the endpoint.** For a multi-step pipeline it is
the state at the *start* of the dynamics — measured `|ψ − first snapshot| =
4e−9`, i.e. the ground state. Reading it gave P_{−5,−4} ≈ 1e−5 in **every** arm,
which reads exactly like "the phenomenon is gone" for a signal that reaches
**0.76**. Use the streamed snapshots (`psi_snapshots` / `spin_populations_trajectory`).

**(b) The peak, not the endpoint, is the quoted observable** — the sheet always
said "peak at t ≈ 20 ms". Located: in every arm the peak falls in frames 32–37
of 37, i.e. **inside `weak_field_hold`**, which is where the protocol says it
should be. Both peak and true endpoint are tabulated below.

**(c) GPU is not usable for the Ω arms.** The inspector emits
`feature_incompat: rotating_frame_omega + spinor + GPU: historically crashed`,
and it is right — the GPU run died with `CUDA error 999` on the fourth arm. The
two Ω=0 arms did complete on GPU and reproduce CPU to five significant figures,
so this is a path defect, not a physics disagreement. **The table is CPU.**

### 3.2 The table

Peak is over the streamed trajectory; "end" is the last streamed frame.

| arm | **peak P_{−5,−4}** (frame) | end P_{−5,−4} | peak P_exc | peak \|L_z\| |
|---|---:|---:|---:|---:|
| Ω = 0, **B_z > 0** (post-fix) | **0.24421** (32/37) | 0.20740 | 0.25497 | 2.04e−02 |
| Ω = 0, **B_z < 0** (pre-fix) | **0.52960** (35/37) | 0.46993 | 0.76099 | 1.01e−01 |
| Ω = −0.5, **B_z > 0** (post-fix) | **0.24311** (32/37) | 0.21043 | 0.25228 | 2.10e−02 |
| Ω = −0.5, **B_z < 0** (pre-fix) | **0.61349** (37/37) | 0.61349 | 0.69815 | 7.56e−02 |

**Knob liveness on both axes.** A null needs a control on the axis it is a null
*on*, and the first attempt at this got it wrong in an instructive way: it
compared `result.jld2["psi"]` between arms and reported a relative difference of
1.395 → "LIVE". But that ψ is the ground state (see (a)) and the configs set
`gauge_fix: false`, so two ITP runs land on **different global phases** — and
`|a − b| ≈ 1.4|a|` is precisely what a phase difference looks like. The probe
answered LIVE from two states that are physically identical. Redone on the last
snapshot with a phase-invariant distance:

| axis held / varied | overlap \|⟨a\|b⟩\| | verdict |
|---|---:|---|
| Ω varied at B_z > 0 | 0.9504 | LIVE |
| Ω varied at B_z < 0 | 0.2219 | LIVE |
| B_z varied at Ω = 0 | 0.2213 | LIVE |
| B_z varied at Ω = −0.5 | 0.2457 | LIVE |

Both knobs reach the propagator at both settings, so every null below is a fact
about the observable. Note the asymmetry already visible here: at B_z > 0 the
rotation moves the state by 5 % of overlap, at B_z < 0 by 78 %.

### 3.3 What moves

**Under the field-sign flip — everything, by factors of 2 to 5.**

| observable | Ω = 0 | Ω = −0.5 |
|---|---|---|
| peak P_{−5,−4} | 0.244 → 0.530 (**×2.17**) | 0.243 → 0.613 (**×2.52**) |
| peak P_exc | 0.255 → 0.761 (×2.98) | 0.252 → 0.698 (×2.77) |
| peak \|L_z\| | 0.0204 → 0.1011 (×4.96) | 0.0210 → 0.0756 (×3.60) |

Both load-bearing observables — the post-quench m = −5, −4 excitation and L_z —
are **strongly** field-sign sensitive. Gate 2's question is answered: **nothing
on the EdH-quench sheet that depends on either can be quoted without
re-derivation.** No row of this table gives permission to skip one.

### 3.4 The finding that matters more: the rotation enhancement is gone

The 0.468 prescription is not about the absolute size of P_{−5,−4}. It is about
its **enhancement by rotation**. Take the contrast at each field sign:

| field sign | peak P_{−5,−4} at Ω = 0 | at Ω = −0.5 | **contrast (peak)** | contrast (end) |
|---|---:|---:|---:|---:|
| B_z < 0 (pre-fix, what 2026-05 ran) | 0.52960 | 0.61349 | **+15.8 %** | +30.5 % |
| B_z > 0 (post-fix, what the tree says today) | 0.24421 | 0.24311 | **−0.45 %** | +1.5 % |

At the corrected field sign the rotation does **nothing** — under half a percent
on the peak, and of the wrong sign — while demonstrably acting on the state
(overlap 0.95, not 1). The mechanism the whole protocol is built on is absent at
the polarisation the repaired configs prepare.

**Consequence, and it is the operative one:** `|Ω|/ω_⊥ = 0.468 ± 0.003` (now
superseded, §9.1) is not
"a number that needs re-deriving". It is **not re-derivable as stated** — a
parabolic optimum cannot be refined out of a flat, slightly negative response.
Refining Ω at B_z > 0 would be twelve arms fitting a vertex to noise, which is
the exact shape of the 2026-08-02 incident the five gates in `CLAUDE.md` exist
to prevent.

### 3.5 Hypothesis, and the arm that tests it

The two field signs differ in something more physical than a sign: **whether the
prepared stretched state is the Zeeman ground state or the Zeeman-highest one.**

- post-fix, m = −F at B_z > 0 ⇒ p < 0 ⇒ `H = |p| F_z` ⇒ m = −6 is **lowest**.
  The cascade m = −6 → −5 is uphill; rotation has nothing to lower.
- pre-fix, m = −F at B_z < 0 ⇒ p > 0 ⇒ m = −6 is **highest**. The cascade is
  downhill, and rotation biases which orbital channel it runs through.

If that is the controlling variable rather than the sign of B_z as such, then
**m = +F at B_z > 0** — the Zeeman-highest state under the *corrected*
convention — must show the enhancement return. Arms E/F/G in §4 test exactly
that, and G doubles as a check of the §5 mirror repair.

### 3.6 The decisive arms — hypothesis confirmed

Three more CPU arms, same protocol, seed `m_plus_F`. **The observable is now
defined relative to the prepared state** — `P_adj` means "two rungs down the
cascade from where the atoms started". The first pass hard-coded it to
components (D−1, D−2), correct only for an m=−F seed, and duly reported
`P_adj = 0.00000, P_exc = 1.00000` for a perfectly good arm: a null manufactured
by the extractor, on the arm whose entire purpose was to test for a null.

| arm | B_z | Ω | seed | Zeeman position of seed | **peak P_adj** |
|---|---:|---:|---|---|---:|
| E | +0.01 | 0 | m=+F | **highest** | **0.52960** |
| F | +0.01 | −0.5 | m=+F | **highest** | **0.61698** |
| G | −0.01 | +0.5 | m=+F | lowest | **0.24311** |

Read against §3.2:

- **E ≡ (Ω=0, B_z<0, m=−F): 0.52960 vs 0.52960**, five digits. Those two arms are
  exact mirrors, and the code reproduces the symmetry.
- **G ≡ (Ω=−0.5, B_z>0, m=−F): 0.24311 vs 0.24311**, five digits. G *is* the
  repaired mirror partner of §5. **The repair is validated by measurement**, not
  only by the sign bookkeeping.
- **The enhancement returns at m=+F, B_z>0: 0.52960 → 0.61698 = +16.5 %**,
  against **−0.45 %** for m=−F at the same field.

So the controlling variable is not the sign of B_z. It is **which end of the
Zeeman ladder the prepared stretched state sits on**:

| prepared state | Zeeman position | cascade | rotation contrast |
|---|---|---|---|
| m=−F at B_z>0 · m=+F at B_z<0 | **lowest** | uphill | −0.45 % (none) |
| m=+F at B_z>0 · m=−F at B_z<0 | **highest** | downhill | +15.8 … +16.5 % |

**This is not a surprise once looked up, and it should have been looked up
first.** It is the standard Einstein-de Haas configuration: Kawaguchi-Saito-Ueda
(PRL 96, 080405) prepare the stretched state *anti-aligned* with B and let
dipolar relaxation convert spin into orbital angular momentum, at a field small
enough that the Zeeman barrier is below the dipolar energy. The sheet's own "two
field regimes" section describes exactly that quench. What the sheet never says
is **which end of the ladder step 1 must prepare** — it says "prepare a stretched
spinor state m = ±F", as if the two were interchangeable. They are not: they
differ by a factor 2.2 in the signal and by the entire existence of the rotation
enhancement.

---

## 4. The polarisation-convention decision

**Decision: do not align the rotation-assisted EdH quench series to m = −F, and do not state the
convention in terms of `m` at all.**

The criterion is measured (§3.6) and it is not about the m label:

> **The rotation-assisted EdH quench must prepare the stretched state ANTI-ALIGNED
> with B — the Zeeman-highest state. Every other Eu arc in this project (Matsui
> EdH reproduction, flower / chiral ground states, the #335 κ transition)
> prepares a GROUND state and is aligned. The two families are not in conflict;
> they ask different questions.**

Writing it as "the quench is m=+F, everything else is m=−F" would be the third
repetition of the mistake this issue is about, because **`m = +F` means the
opposite thing depending on the sign of B_z**, and every incident here came from
someone reading an m label without its field. State the relative orientation;
derive the label.

Under the project-wide convention — B_z > 0, g_F > 0, `H = −p·F_z` with
`p ≡ −g_F μ_B B` — the derived labels are:

| family | preparation | field | seed |
|---|---|---|---|
| rotation-assisted EdH quench / EdH cascade | anti-aligned (Zeeman-highest) | B_z > 0 | **m = +F** |
| everything else Eu | aligned (Zeeman ground) | B_z > 0 | **m = −F** |

so **B_z stays positive everywhere** — `bce2068f`'s discipline is kept intact —
and the EdH-quench family differs in its *seed*, which is the knob that carries the
physics.

### 4.1 What this implies about `bce2068f`

`bce2068f` was a correct **convention** repair: those configs' comments asserted
"NEGATIVE → m=−F lowest energy", which is false under `Units.bfield_to_p`, so
the file contradicted itself and something had to move. It moved the field.

Measured consequence: that choice moved the EdH-quench corpus from the anti-aligned
regime (where the protocol's phenomenon lives) into the aligned one (where it
does not). Each file became self-consistent and the corpus stopped studying the
effect it was built for. Whether the original author meant the anti-aligned
state or wrote the field sign by mistake is **not recoverable and not worth
arguing** — the physics requirement is now measured either way.

The repair is therefore not "revert `bce2068f`" (that would restore the wrong
convention along with the right physics). It is: **regenerate the rotation-assisted EdH quench
corpus as m = +F at B_z > 0**, keeping positive B_z, declaring the
anti-alignment in the file so the next reader and the next gate both see it.

### 4.2 Scope check on the field-rotation branch

`runs/eu151_klaus_phi_phys/config.yaml` — the config #343 §2 flagged as "the
only Eu arc on the m=+F side" — specifies `B: {p: 26700.0}` with
`init_m_idx: 1`. Since `H = −p·F_z`, **p > 0 puts m = +F at the BOTTOM** of the
ladder. So that config is *aligned*, i.e. it is on the same side as everything
else in the project and on the **wrong** side for the rotation-assisted EdH quench. The
apparent "opposite convention" was an artefact of comparing m labels across
different field parameterisations — precisely the failure the decision above is
worded to prevent.

Its `init_m_idx: 1` is also simply the schema default at p > 0
(`run_step_rotating/ground_state.jl:162`: `init_m_idx = p_z > 0 ? 1 : D`), so
nothing was ever chosen there.

**Action for that config: same as the quench family — it needs `init_m_idx: 13`
at p > 0 (or `p < 0` with `init_m_idx: 1`) to be anti-aligned.** Not done here:
it is a 32×32×16 GPU rotating-basis run with an 8-point scan, and it has no
result being quoted, so it is on the re-derivation list rather than in this PR.

<!-- DECISION -->

---

## 5. `bce2068f` broke the mirror pair — and nothing noticed

This was not in #343's list and is the sharpest thing here.

`docs/manuscript/klaus_protocol_sheet.md`'s validation chain records

> | (init m × Ω sign) reversal symmetry | 3-digit match in both branches  **PASS** |

The two arms are `klaus_quench_omm0p5_keeprot.yaml` and
`klaus_quench_omp0p5_keeprot_mFplus.yaml` — **renamed to
`klaus_quench_omp0p5_keeprot_mirror.yaml` by `e8dafe8e`** when the corpus was
retargeted, so the `mFplus` name below is the one valid at each commit discussed
and is NOT what to look for in the tree today. Reading them at `bce2068f~1` — the
tree the PASS was measured on — and at HEAD:

| | seed | B_z (prep → hold) | Ω/ω_⊥ | mirror? |
|---|---|---|---|---|
| **at `bce2068f~1`** `omm0p5_keeprot` | m=−F | −0.01 → −2.6e-5 G | −0.5 | ✅ all three flip |
| **at `bce2068f~1`** `omp0p5_keeprot_mFplus` | m=+F | +0.01 → +2.6e-5 G | +0.5 | |
| **after `bce2068f`** `omm0p5_keeprot` | m=−F | **+0.01 → +2.6e-5 G** | −0.5 | ❌ only m and Ω flip |
| **after `bce2068f`** `omp0p5_keeprot_mFplus` | m=+F | +0.01 → +2.6e-5 G | +0.5 | |
| **repaired here** `omm0p5_keeprot` | m=−F | +0.01 → +2.6e-5 G | −0.5 | ✅ all three flip |
| **repaired here** `omp0p5_keeprot_mFplus` | m=+F | **−0.01 → −2.6e-5 G** | +0.5 | |

Under the reflection that reverses chirality (take y → −y), **every axial vector
in the problem flips**: L_z → −L_z (so Ω → −Ω), F → mirrored (so m → −m), **and
B, which is also axial, so B_z → −B_z**. The pre-fix pair flips all three. It is
a genuine mirror pair, and its 3-digit agreement was a real test of the code.

`bce2068f` repaired each config **individually** — it flipped the field on the
211 that pinned m=−F, and deliberately left the m=+F ones alone because their
repair is ambiguous. Both are defensible per file. The pair is not: after the
fix both arms sit at **B_z = +0.01 G**, only two of the three axial quantities
flip, and the two arms are no longer mirror images. Re-running that acceptance
gate today compares an *uphill* Zeeman cascade against a *downhill* one, and
should be expected to fail.

**The rule, stated so it generalises past this instance:**

> A mirror arm is defined by the mirror operation, not by negating the knob you
> happen to be scanning. Flip **every** axial quantity — Ω, the spin projection,
> **and B** — or it is not a mirror. This is the same lesson #338 (Barnett)
> reached from the other side: `±Ω` alone is not a mirror there either, because
> `SinusoidalWaveform` is odd, so `B_y` must flip with it. Same rule; the
> `klaus_quench` series happens to have no `B_y`, and its missing partner is `B_z`.

**Corollary for per-file repairs.** A fix applied file-by-file can be right on
every file and still break a relationship that spans two of them. Nothing in the
tree recorded that these two configs were a pair, so nothing could warn. The
single-file gate does report both `mFplus` arms in its m=+F list, but as "seed
opposes field" — it reads one file at a time and cannot see a broken *pair*.

### 5.1 What was done about it

**The repair is determinate here, and `bce2068f`'s stated blocker does not
apply.** That commit left m=+F configs alone because "flip the field" and "flip
the seed" are both consistent and the intent is unrecoverable from the file. For
these two, the intent *is* recoverable: they exist only as the mirror arm of a
named partner, so the mirror role fixes which of the two moves. B_z flipped
negative on both `mFplus` files. Each is now self-consistent (m=+F wants B_z<0)
**and** each pair flips all three axial quantities again.

**Validated by measurement, not by sign bookkeeping**: arm G in §3.6 runs the
repaired `omp0p5_keeprot_mFplus` shape and reproduces its partner's peak
P_{−5,−4} = 0.24311 to five digits.

**And made mechanical.** All four files now carry `# mirror-pair: <partner>` in
the header, and `test/workflow/test_mirror_pairs_flip_every_axial_quantity.jl`
(fast tier) asserts the declaration is symmetric and that the seed, Ω **and**
B_z all flip with equal magnitude — with a canary that reconstructs the
post-`bce2068f` broken pair and requires the B_z clause to reject it, so an
all-green run is not the same string as a predicate that matches everything.

Note that both members of each repaired pair now sit at the **aligned** (Zeeman
ground) preparation, so the pair is mirror-correct and, per §3.4, in the regime
where the rotation enhancement does not exist. Fixing the mirror and fixing the
physics are separate jobs; §6 R1 is the second one.

---

## 6. The re-derivation list

The point of gate 2 is to shorten this, and it did — but not the way expected.
It did not find observables insensitive enough to skip; it found that the
headline prescription is **not re-derivable as posed** and has to be replaced by
a different measurement.

### 6.1 Re-derive — 2 items, **both discharged 2026-08-19**

| # | item | outcome |
|---|---|---|
| R1 | **The Ω operating window** (`\|Ω\|/ω_⊥ = 0.468 ± 0.003 @ 2.6 nT`) | **DONE — §9.1/9.2/9.3.** Not a refinement but a re-posing, and then a replacement; the old value is **superseded**, not refined: `\|Ω*\|/ω_⊥ = 0.68 ± 0.04`, +24.9 % over Ω=0. The response is **even in Ω**, so the chirality rule is void, and a **static** weakened trap reproduces the whole effect — the operative variable is ω_⊥,eff ≈ 0.73 ω_⊥, not Ω |
| R2 | **The 6 acceptance gates** in `klaus_quench_protocol_spec_2026_05_26.md` | **DONE — §9.4.** 5 of 6 pass on criteria fixed before launch. G6 (N=5×10⁴, P_exc rises) **fails**, for a reason R1 explains. G3 passes at 2.47 %, so the sheet's "4-digit match" is **refuted** by two orders of magnitude |

The `0.3 @ 1.3 nT` and `[0.5, 0.6] @ 5.2 nT` rows were **not** re-derived here
(both are **refuted** by the ω_eff scans — §10.2 and §11): they
are the same prescription at other fields, and §9.3 says the whole family is
parameterised by the wrong variable. They should be re-posed as a trap-frequency
scan at each field, not re-fitted in Ω.

### 6.2 Do NOT re-derive — with the reason, so nobody re-opens it

| item | reason |
|---|---|
| `phi_omega` scans | Already decided 2026-04-29 (scan the field, not `phi_omega`). §7. The prior is pre-fix, but R1 supersedes the question it was answering |
| Long-time vortex counts (145 ms / 510 ms rows) | They rest on the same absent mechanism as R1. Re-deriving them before R1 would be measuring the wrong preparation for 100× the cost |
| The 11× quadratic-Zeeman correction's effect here | Already **measured** not to apply in the nT band (`q/p = 2.3e-8`), `ed3be749` |
| Any run not cited by a live document | `stored_results_vintage_audit.md` + `doc_run_citation_inventory.md` already sort these. Nothing under `runs/` is committed, so there is nothing to compare against anyway |
| The K₃ calibration table in the spec | It is a **loss-rate** calibration against Matsui's N(40 ms)/N(0); it does not depend on the spin-cascade mechanism, and its own arc closed separately (`project_matsui_fig4b_reproduction`) |

### 6.3 Blocked, and named rather than left implicit

- **`runs/eu151_klaus_phi_phys/`** needs `init_m_idx: 13` at `p > 0` to be
  anti-aligned (§4.2). Not changed in this PR — it is a GPU rotating-basis
  8-point scan with no quoted result, so it is R1's dependency, not its own item.
- **A regenerated `klaus_quench` corpus** at m=+F / B_z>0 with
  `# anti-aligned-seed:` declared. 52 files, machine-generated originally
  (`scripts/validation/klaus_quench_gen.jl`, since archived), so this is a
  generator change, not 52 edits. Prerequisite for R1.
- Everything above is **one seed, 32³, `lhy: none`, one hold duration**. The
  factor-2.2 and the +16.5 % vs −0.45 % split are far outside any plausible
  seed scatter, but the *values* are not converged results and are not quotable
  as such.

### 6.4 Status — both discharged 2026-08-19

The corpus was retargeted (52 production arms to m=+F at B_z>0, 2 mirror arms to
m=−F at B_z<0, all declaring `# anti-aligned-seed:`) and R1/R2 then ran. Results
in §9. **R1 did not return a refined 0.468; it returned a different number and a
different mechanism.**

---

## 9. R1 / R2 — measured at the anti-aligned preparation

All CPU, 32³ unless stated, one seed, `lhy: none`. Observable is peak
P_{m_init∓1, m_init∓2} over the streamed trajectory, **relative to the prepared
state**. Configs are the committed ones, unmodified.

### 9.1 R1 — the Ω operating window

The 20 `*_holdonly_delay2ms_refine.yaml` cells — the same protocol, grid and
delay the 0.468 came from, so this is a re-derivation of the same quantity.

| Ω | peak P_adj | Ω | peak P_adj |
|---:|---:|---:|---:|
| −1.00 | 0.44063 | −0.42 | 0.58978 |
| −0.90 | 0.50132 | −0.38 | 0.58018 |
| −0.80 | 0.61730 | −0.34 | 0.56998 |
| **−0.70** | **0.65905** | −0.30 | 0.55964 |
| −0.66 | 0.65258 | −0.20 | 0.53616 |
| −0.62 | 0.64131 | −0.10 | 0.52902 |
| −0.58 | 0.63022 | **0.00** | **0.52748** |
| −0.54 | 0.62053 | +0.10 | 0.52940 |
| −0.50 | 0.61088 | +0.30 | 0.56027 |
| −0.46 | 0.59943 | +0.50 | 0.61164 |

Against the criteria fixed **before** launch:

| | criterion | measured | |
|---|---|---|---|
| C1 | interior maximum required | max at Ω = −0.70, falling to 0.441 at −1.00 | **PASS** |
| C2 | enhancement over Ω=0 > 5 % | 0.65905 / 0.52748 = **+24.9 %** | **PASS** |
| C3 | ≥5-pt parabolic fit, negative curvature, vertex inside window | \|Ω\| ∈ [0.58, 0.80], c₂ = −2.70, vertex 0.682, fit rms 4.7e−3 | **PASS** |
| C4 | digits limited by the fit | δ ≈ 0.042 ⇒ two digits, not three | **applied** |

> **|Ω*| / ω_⊥ = 0.68 ± 0.04 at B = 2.6 nT.**
> This **replaces** `0.468 ± 0.003`, which is **superseded**. The old value is
> not recovered, and its
> third significant figure is not supportable at one seed.

### 9.2 The response is EVEN in Ω — the stated mechanism is not what acts

| \|Ω\| | P_adj(+Ω) | P_adj(−Ω) | rel diff |
|---:|---:|---:|---:|
| 0.10 | 0.52940 | 0.52902 | **0.071 %** |
| 0.30 | 0.56027 | 0.55964 | **0.113 %** |
| 0.50 | 0.61164 | 0.61088 | **0.124 %** |

The sheet's **refuted** mechanism is **odd** in Ω — "matched chirality (Ω·sign(m_init) < 0)
lowers the mode energy", ΔE = −Ω·ℓ. An effect that is even in Ω to 0.12 % cannot
come from that term. Ω = 0 is the *minimum*; **both** senses of rotation enhance,
equally.

### 9.3 The decisive control: it is CENTRIFUGAL, not Coriolis

The rotating frame also carries −½Ω²ρ², which is even in Ω and weakens the radial
trap to ω_eff = √(ω_⊥² − Ω²). Test: replace rotation in the hold with a **static
trap already weakened to that ω_eff**, Ω = 0, everything else identical
(`potential` is a dynamics-step field, so this is clean).

| \|Ω\| | rotating | static ω_eff | rel diff | ω_eff |
|---:|---:|---:|---:|---:|
| 0.70 | 0.65905 | **0.65864** | **0.06 %** | 0.7141 |
| 0.50 | 0.61088 | **0.61205** | **0.19 %** | 0.8660 |

peak P_exc agrees too (0.72168 / 0.72073 and 0.75743 / 0.75829).

**A static, non-rotating trap reproduces the entire "rotation-assisted"
enhancement to 0.06–0.19 %.** The control carries its own positive control: had
the per-step `potential:` override been silently ignored, these arms would have
returned the Ω = 0 value 0.527, not 0.659.

**Consequences, and they are large:**

1. **Chirality is irrelevant to this observable.** "Rotate against the stretched-
   spin direction" is not a prescription — either sense works, identically.
2. **Rotation is not required at all.** The operative variable is the effective
   radial trap frequency. The optimum |Ω*| = 0.68 corresponds to
   **ω_⊥,eff ≈ 0.73 ω_⊥**, i.e. simply weaken the radial trap by ~27 %. That is a
   far easier laboratory prescription than mechanically rotating an anisotropic
   trap, and it removes the whole "sign-convention mapping from simulation Ω to
   lab rotation direction" caveat.
3. **The upper bound has a physical origin**: the cascade collapses as
   |Ω| → ω_⊥ = 1 (peak P_exc 0.76 → 0.49), which is where the effective radial
   trap vanishes. The window is bounded by the centrifugal limit, not by a
   resonance.

*Marked as hypothesis, not measured here:* the microscopic reason a softer radial
trap helps (larger cloud, lower kinetic cost for the ℓ ≠ 0 orbital modes the spin
flip must populate). The **variable** is established; the mechanism behind the
variable is not.

### 9.4 R2 — the acceptance gates

Criteria fixed before launch and **not** inherited from the sheet.

| gate | criterion | measured | verdict |
|---|---|---|---|
| G1 DDI off → 0 | < 0.005 | **0.00000** | PASS |
| G2 no B quench → 0 | < 0.005 | **0.00016** | PASS |
| G3 32³ ↔ 64³ | \|rel\| < 5 % | **+2.47 %** (0.61698 → 0.63223) | PASS |
| G4 mirror symmetry | \|rel\| < 1e−3 | 0.61698 vs 0.61698, **< 1e−5** | PASS |
| G5 dt/2 reproducibility | \|rel\| < 1 % | **0.029 %** | PASS |
| G6 N = 5×10⁴, P_exc rises | sign | 0.81531 vs 0.81613, **−0.10 %** | **FAIL** |

**G4** is the repaired pair from §5, now with both members anti-aligned; it
agrees to five decimals, which is a stronger result than the sheet's "3-digit".

**G6 fails as posed, and the reason is in R1.** Ω does not create excitation, it
*concentrates* it: peak P_exc is flat to |Ω| ≈ 0.6 while P_adj rises 24 %. At
N = 5×10⁴ the cascade is already saturated (P_exc = 0.816), so there is no room
for the +30 % the sheet claims. On the adjacent-pair observable the enhancement is
there: P_adj **+6.4 %** (0.36119 vs 0.33956). The sheet's own row carried
"(with metric caveat)"; the caveat was load-bearing.

**G3 passes the criterion, but the sheet's stated precision is refuted.** The sheet
claims a "4-digit match" between 32³ and 64³. Measured: **+2.47 %** on peak
P_adj (0.61698 → 0.63223) and +2.05 % on peak P_exc — a **2-digit** agreement,
two orders of magnitude looser than advertised. That is fine for a converged
result and is why the criterion here was set at 5 %, but "4-digit" was never a
credible resolution claim for a nonlinear cascade and should not be repeated.
The residual is one-signed (64³ higher on both observables), i.e. 32³ slightly
under-resolves the cascade rather than scattering about it.

**Cost note for whoever runs this next:** the 64³ arm took 3026 s against ~590 s
at 32³ on the same core — 5.1×, not the 8× the cell count suggests, because the
FFT work does not scale linearly and the run is partly memory-bound (3.0 GB RSS).

---

## 10. Scanning the variable that actually acts

§9.3 said the operative variable is ω_⊥,eff, not Ω. So scan **that**, with a
static trap and no rotation at all — which is also the correct re-posing of the
two rows §6.1 deliberately did not re-derive. 34 arms, CPU, 32³, holdonly + 2 ms
delay, anti-aligned.

### 10.1 The static scan reproduces the rotating one

At every ω_eff where the two scans sample the same point:

| ω_eff | static trap, Ω = 0 | rotating, from \|Ω\| = √(1−ω_eff²) | rel |
|---:|---:|---:|---:|
| 1.000 | 0.52748 | 0.52748 (Ω=0.00) | **0.00 %** |
| 0.750 | 0.65219 | 0.65258 (Ω=0.66) | **0.06 %** |
| 0.714 | 0.65864 | 0.65905 (Ω=0.70) | **0.06 %** |
| 0.600 | 0.61707 | 0.61730 (Ω=0.80) | **0.04 %** |

**Worst 0.06 %.** Rotation is fully substitutable by a static radial trap of the
same ω_eff, across the range — not just at the two points of §9.3.

Static optimum at 2.6 nT: **ω_eff = 0.714, +24.9 % over ω_eff = 1**, which is the
same optimum and the same enhancement the Ω scan gave.

### 10.2 The optimum IS field-dependent — and one field has no window at all

| field | best ω_eff | peak P_adj | enhancement | shape |
|---|---:|---:|---:|---|
| **1.3 nT** | 0.900 | 0.51386 | **+1.8 %** | flat: 0.505 → 0.514 over ω_eff ∈ [0.65, 1.0] |
| **2.6 nT** | **0.714** | 0.65864 | **+24.9 %** | clean single peak |
| **5.2 nT** | 0.550 | 0.51387 | +17.0 % | **non-monotonic**, with a dip at 0.650 |

Three different answers, and only one of them is a number:

- **1.3 nT — there is no operating window.** +1.8 % across a flat range is not an
  optimum; it is the absence of one. The sheet's `|Ω|/ω_⊥ ≈ 0.3 at B = 1.3 nT`
  therefore has **no replacement**, and that is the finding. Do not re-fit it.
- **2.6 nT — ω_⊥,eff / ω_⊥ = 0.71.** This is the prescription.
- **5.2 nT — unresolved at this sampling.** The best sampled point (0.550,
  0.51387) is only 2.6 % above ω_eff = 0.800 (0.5007) and there is a dip between
  them at 0.650. Seven points cannot distinguish one broad optimum from two
  narrow ones, so **no optimum is quoted**; the sheet's `[0.5, 0.6] at 5.2 nT`
  is neither confirmed nor replaced. Denser sampling would settle it.

### 10.3 The seed is live, and the observable is deterministic anyway

Five seeds at ω_eff = 1.000 and at 0.714 returned peak P_adj identical to five
decimals (sd = 0.00000). That is exactly what a dead knob looks like, so it was
checked rather than reported:

| | overlap between seed 101 and seed 202 | max rel density diff |
|---|---:|---:|
| frame 1 (just after the seeded step) | 0.999999702 | 2.3e−7 |
| frame 39 (end) | 0.999999881 | 1.9e−5 |

**The seed reaches the state**, and its influence *grows* by two orders over the
run — the cascade does amplify it — but it is still ~1e−5 at the end, far below
anything that moves peak P_adj. The `noise_seed` knob was also initially wired to
the wrong step (it is read only by the step carrying `seed_amplitude`), which
produced the same all-identical table for a different and wrong reason; that was
found and fixed before these numbers.

**Consequence:** the one-seed values in §9 are not one sample of a distribution.
On this protocol and duration the observable is deterministic, so the seed axis
carries no uncertainty to quote. **The grid, dt and box axes still do** — G3
measured 2.5 % between 32³ and 64³, which dwarfs everything here.

### 10.4 Why a softer *radial* trap: not density

Two candidates for the microscopic reason, and they are separable. Weaken **ω_z**
instead, chosen to give the *same* mean trap frequency ω̄ = (ω_x ω_y ω_z)^⅓ —
hence the same Thomas-Fermi density scaling — while leaving ω_⊥ at 1:

| arm | trap | peak P_adj |
|---|---|---:|
| baseline | (1.000, 1.000, 1.1818) | 0.52748 |
| radial | (0.714, 0.714, 1.1818) | **0.65864** |
| **z-weakened, same ω̄** | (1.000, 1.000, 0.6026) | **0.48073** |

The z-weakened arm does not merely fail to reproduce the gain — it lands
**below** the baseline, recovering **−36 %** of it. Same mean trap frequency,
same density scaling, opposite sign of effect.

> **The variable is the radial confinement specifically, not the density.**

That is consistent with the ℓ ≠ 0 orbital modes the spin flip must populate
having their cost set by ω_⊥ — but that reading is still an interpretation. What
is *measured* is that a density-matched change along z does not substitute for
it, which is what rules the density explanation out.

---

## 11. 5.2 nT resolved — two branches, and the old row is refuted

§10.2 left 5.2 nT open rather than quoting a number: seven points showed
non-monotonic structure that could not distinguish one broad optimum from two
narrow ones. Densified to 20 points, plus two 64³ arms.

### 11.1 The scan

| ω_eff | P_adj | ω_eff | P_adj |
|---:|---:|---:|---:|
| 0.420 | 0.44336 | 0.680 | 0.49410 |
| 0.450 | 0.46440 | 0.714 | 0.49960 |
| 0.480 | 0.48567 | 0.750 | 0.50245 |
| 0.500 | 0.49823 | **0.770** | **0.50252** |
| 0.520 | 0.50789 | 0.800 | 0.50070 |
| **0.550** | **0.51390** | 0.830 | 0.49666 |
| 0.570 | 0.51300 | 0.850 | 0.49290 |
| 0.600 | 0.50568 | 0.900 | 0.47910 |
| 0.620 | 0.49592 | 0.950 | 0.45968 |
| **0.650** | **0.48790** ← dip | 1.000 | 0.43930 |

Global maximum at ω_eff ≈ 0.55, **+17.0 %** over ω_eff = 1. Secondary maximum at
ω_eff ≈ 0.77. Dip between them at ω_eff ≈ 0.65, **5.06 %** below the global
maximum — about 170× the dt/2 reproducibility floor (0.029 %) and infinitely
above the seed floor (0.000 % over 5 live seeds).

### 11.2 D4 — the structure is not a grid artifact

Structure at 32³ is not structure until it survives 64³, so both the dip and the
adjacent peak were re-run:

| ω_eff | 32³ | 64³ | shift |
|---:|---:|---:|---:|
| 0.550 (peak) | 0.51390 | 0.52496 | **+2.15 %** |
| 0.650 (dip) | 0.48790 | 0.50031 | **+2.54 %** |

| | dip depth |
|---|---:|
| 32³ | 5.06 % |
| **64³** | **4.70 %** |

Both points move up by the same ~2.3 %, which is the one-signed offset G3 already
measured at 2.6 nT (+2.47 %). **The dip does not fill in** — it retains 93 % of
its depth. So the two-branch structure is physical at this resolution, and what
32³ gets wrong is a uniform offset, not the shape.

### 11.3 Verdict, against the criteria fixed before launch

| | criterion | outcome |
|---|---|---|
| D1 | two maxima separated by a dip > 1 % ⇒ report two branches, quote no single optimum | dip is **4.70 %** at 64³ ⇒ **TWO BRANCHES**, no single optimum quoted |
| D2 | vertex only from a ≥5-pt fit with negative curvature | **not applicable** — D1 fired first |
| D3 | digits from the fit | not applicable |
| D4 | structure must survive 64³ | **survives**, 93 % of depth retained |

### 11.4 And the old row is refuted, not merely unresolved

`[0.5, 0.6] at 5.2 nT` was written in Ω. In ω_eff that is
√(1−0.5²) … √(1−0.6²) = **[0.80, 0.87]** — which in this scan is a *declining*
shoulder (0.50070 → 0.49290), below **both** maxima. The global maximum sits at
ω_eff ≈ 0.55, i.e. |Ω| ≈ 0.84, well outside the old window.

So §10.2's "neither confirmed nor replaced" upgrades to **refuted**, and the
replacement is not a number but a shape: *two branches, global maximum at
ω_⊥,eff ≈ 0.55 ω_⊥*.

**Hypothesis, and it has a cheap test.** At 2.6 nT the curve is a clean single
peak with no dip; doubling the field introduces one. That is what a resonance
entering the sampled window looks like — plausibly between the Zeeman splitting
and the radial mode spacing, both of which the field and ω_⊥,eff set. The test
is one more field: if the dip is a resonance, its ω_eff position must move again
at 10.4 nT.

> **WITHDRAWN 2026-08-20 — the prediction was made and it failed.** §12.3. The
> informative half was 2.6 nT, where a dip was predicted near ω_eff ≈ 0.325 and
> the measured curve rises monotonically through it. The second branch at 5.2 nT
> is a measured structure **without** a mechanism; this paragraph is kept struck
> rather than deleted because a discarded hypothesis that was actually tested is
> worth more to the next reader than a clean page.

---

## 12. The resonance prediction fails, and the observable needed fixing first

### 12.1 An instrument correction that changed one field and no others

Every peak up to here was taken over the **whole** streamed trajectory. At 10.4 nT
four arms differing *only in the hold* returned peak P_adj = 0.26050 to five
decimals — impossible unless the maximum lies before the hold. It does: argmax at
frame 29, hold starts at frame 32.

So the observable was reading the pre-hold transient, and "no dip at 10.4 nT"
would have been a confirmed prediction read off a blind instrument. **The claim is
always about the hold, so the peak must be taken inside it.**

Re-extracted from cache — no recompute — across every arm measured so far:

| scan | arms | peak moved? |
|---|---:|---|
| 1.3 nT (§10.2) | 7 | **0.00 % on all** |
| 2.6 nT (§10.1, §11 tail) | 16 | **0.00 % on all** |
| 5.2 nT (§10.2, §11) | 20 | **0.00 % on all** |
| **10.4 nT** | 10 | **7 of 10 moved, by up to −23 %** |

**§9, §10 and §11 are unaffected** — that is measured, not assumed. Only 10.4 nT
is contaminated, and for a physical reason: it is the Zeeman-re-pinning regime the
sheet warns about, so the hold suppresses the cascade and the transient wins.

### 12.2 10.4 nT, read correctly: a clean single peak

| ω_eff | peak in hold | ω_eff | peak in hold |
|---:|---:|---:|---:|
| 1.000 | 0.20139 | 0.650 | **0.30101** |
| 0.900 | 0.22628 | 0.600 | 0.29316 |
| 0.800 | 0.24117 | 0.550 | 0.25721 |
| 0.750 | 0.25204 | 0.500 | 0.22104 |
| 0.700 | 0.27828 | 0.450 | 0.20178 |

Single maximum at **ω_eff = 0.650**, **+49.5 %** over ω_eff = 1 — the *largest
relative* enhancement of any field measured, on the *smallest absolute* transfer
(0.30 against 0.66 at 2.6 nT). Zeeman re-pinning is real — it costs a factor 2 in
absolute transfer — but it does not close the channel, and weakening the trap
helps proportionally more when it is nearly closed.

### 12.3 The resonance reading is refuted

§11.4 proposed that the 5.2 nT dip is a resonance, predicting ω_eff,dip ∝ B, and
that prediction was written down before the runs:

| field | predicted | observed | |
|---|---|---|---|
| 10.4 nT | dip at ω_eff ≈ 1.30 ⇒ none in range | no dip | consistent, but weakly — "no dip" is the easy half |
| **2.6 nT** | **dip near ω_eff ≈ 0.325** | **0.250→0.375 rises monotonically: 0.45976, 0.46412, 0.46681, 0.47068, 0.47682** | **FAILS** |

The informative arm fails. **The resonance reading is refuted** and §11.4 is
withdrawn. What produces the second branch at 5.2 nT is now unexplained — and the
honest position is that it is a measured structure without a mechanism, not a
mechanism awaiting confirmation.

Field dependence of the optimum, with everything read in the hold:

| field | optimum ω_eff | enhancement | shape |
|---|---:|---:|---|
| 1.3 nT | — | +1.8 % | flat, no window |
| 2.6 nT | 0.714 | +24.9 % | single peak |
| 5.2 nT | 0.55 | +17.0 % | **two branches** |
| 10.4 nT | 0.650 | **+49.5 %** | single peak |

Non-monotonic in every column. There is no one-line prescription across field.

### 12.4 LHY: the conclusion survives

Everything above is `lhy: none`. Repeated at 2.6 nT with `full_bdg` (the
general-spinor path; the closed forms assume an ansatz this state does not have):

| | ω_eff = 1.000 | ω_eff = 0.714 | enhancement |
|---|---:|---:|---:|
| `lhy: none` | 0.52748 | 0.65864 | **+24.9 %** |
| `lhy: full_bdg` | 0.52786 | 0.67297 | **+27.5 %** |

LHY moves the baseline by **+0.07 %** and the optimum by **+2.18 %**. The
enhancement does not merely survive, it grows slightly. **The `lhy: none` caveat
is discharged for this conclusion** — though not for absolute values at other
fields or densities, which were not re-run.

---

## 13. Long time (145 ms): the substitution is a short-time statement

> **RETRACTED 2026-08-20 — every ordering below flips sign at 64³. See §15.**
> The section is kept because the 32³ numbers are real and the retraction is
> about what they support, not about whether they were measured. Do not quote
> the endpoint comparison or the "sustained vs transient" reading.

`runs/klaus_quench_long_time/` was **missed by the corpus retarget** — it was
still `m_minus_F` at B_z > 0, i.e. aligned, until this branch. Retargeted (9
configs, seed-agreement gate green), then three arms at hold = 100 ω_ref⁻¹
(≈ 145 ms), 32³, CPU, peak taken inside the hold per §12.1:

| arm | hold-peak P_adj | hold-peak P_exc | **P_adj at the END** |
|---|---:|---:|---:|
| baseline (ω_eff = 1.000, Ω = 0) | 0.38532 | 0.79035 | 0.23127 |
| **static (ω_eff = 0.714, Ω = 0)** | 0.50790 (+31.8 %) | **0.88794** | **0.47517** |
| **rotating (Ω = −0.70, full trap)** | 0.52475 (+36.2 %) | 0.84341 | 0.21093 |

Two findings, and they point opposite ways.

**On the peak, the substitution degrades but survives.** Static and rotating
differ by **3.21 %** here against **0.06 %** on the short protocol. 3.21 % is
comparable to the 32³↔64³ resolution uncertainty (2.5 %, G3), so this is
*suggestive of divergence, not established* — it wants a 64³ point before anyone
leans on it.

**On the endpoint, they are qualitatively different, and that is not marginal.**
The rotating arm peaks and then collapses back to 0.21093 — *below* the baseline's
0.23127 — while the static arm holds 0.47517, i.e. ~~**2.25×**~~ the rotating one.
Rotation produces ~~a transient~~; the weakened static trap produces a
~~sustained transfer~~.
<!-- REFUTED 2026-08-20 (§15, claim `edh-longtime-static-sustains`): at 64³ the
     ratio is 0.68× and the arms swap roles. No replacement ordering exists. -->

> **REFUTED — §15.** At 64³ this ordering inverts: static ÷ rotating at the end is
> **0.68×**, and it is the *static* arm that decays while the rotating one is
> still climbing. Neither resolution establishes the long-time ordering.

So the §9.3 substitution ("rotation is fully replaceable by a static weakened
trap") is a **short-time statement**. At 145 ms the two agree on how high the
cascade climbs and disagree completely on whether it stays there — and the static
prescription is the better one on the observable an experiment would actually
integrate. *(That last clause is **refuted**; see §15.)*

The sheet's long-time rows (`P_exc(end) = 0.958 at 145 ms`) are not directly
comparable — different cell (`keep_rot`, Ω = −0.5, aligned corpus) — and are not
re-derived here. The *ordering* was claimed here as the load-bearing part —
~~static > rotating > baseline on sustained transfer~~ — and is **REFUTED** by §15.

---

## 14. The field-rotation branch: two code defects, no physics yet

`runs/eu151_klaus_phi_phys/` — the field-rotation branch, 32×32×16 rotating-basis
on GPU, 1 s steady stir × 8 scan points — had never been *run* since its seed was
corrected to the anti-aligned end (§4.2). Smoking it before committing GPU hours
(CLAUDE.md: render every path in ≈2 min first) found two defects and no physics.

### 14.1 The rotating-basis GPU path was dead

```
ERROR: Scalar indexing is disallowed.
  spin_density_vector → _compute_spin_density!
  run_step_rotating/dynamics.jl:252
```

`spin_density_vector` allocated its three outputs as `zeros(Float64, n_pts)` —
unconditionally **host**. On GPU that is a host destination with a device source,
so the `@.` writes fall to the CPU broadcast kernel and **error**. Not a slow
path: the whole rotating-basis dynamics path was unusable on GPU.

Fixed with `similar(psi, Float64, n_pts)`, which is correct for any backend and
leaves nothing to remember. The smoke then completes.

### 14.2 `E = NaN` with `conv = true` — and the second half is the serious one

The completed smoke reports `E=NaN conv=true`, with **ψ entirely finite**
(212992/212992). Discriminated across four arms — seed `init_m_idx` ∈ {1, 13} ×
ITP ∈ {100, 1500} — **all four give E = NaN with finite ψ**, so this is neither
the anti-aligned seed (§4.2 is exonerated) nor an under-converged smoke.

The cause is an absent key read through a default. The rotating-basis ground
state returns `mu` and **no** energy and **no** convergence flag, and
`run_registry.jl` read them as

```julia
energy    = get(result, :ground_state_energy,    NaN)
converged = get(result, :ground_state_converged, true)   # <-- 
```

`NaN` for a missing energy is at least loud. **`true` for a missing convergence
flag is not.** It collapses three states into one — converged, did-not-converge,
and *nobody checked* — and the third is real: `:ground_state_converged` is
already the discriminator for "did a ground state run at all"
(`model/complete.jl:222`).

> **Every rotating-basis run has been writing `converged = true` having never
> been asked, and satisfying CAMPAIGN.md §4 guard 7 ("`conv == false` ⇒
> disqualified") by construction.**

Fixed by writing nothing when there is nothing to report — every consumer already
handles absence — and gated by
`test/workflow/test_converged_absent_is_not_a_pass.jl`, which counts the writes
and the guarded writes and requires them equal, so a new unguarded write fails.

**The rotating-basis GS still reports no energy.** That is left open and named
rather than papered over: it needs the GS step to compute one, which is a change
to that solver, not to the writer.

### 14.3 Status

No physics from this branch. What it produced is two defects, one of which was
silently satisfying a campaign guard. The 8-point production scan is **not**
launched — it would now run, but on a path whose ground state reports no energy,
so there would be nothing to check the result against.

---

## 15. RETRACTION — 32³ is not converged for the long-time branch

§13 was published in PR #410 on the strength of three 32³ arms. The two arms its
conclusion rests on were then re-run at 64³, and **both orderings reverse**.

| | 32³ | 64³ |
|---|---:|---:|
| **hold-peak** static (ω_eff = 0.714) | 0.50790 | 0.49081 |
| **hold-peak** rotating (Ω = −0.70) | 0.52475 | 0.40358 |
| static vs rotating | **−3.2 %** | **+21.6 %** |
| **endpoint** static | 0.47517 | 0.27262 |
| **endpoint** rotating | 0.21093 | 0.40358 |
| static ÷ rotating at the end (the **refuted** 32³ figure vs 64³) | **2.25×** | **0.68×** |

Per-arm, 32³ → 64³: static peak −3.4 %, rotating peak −23.1 %, static endpoint
**−42.6 %**, rotating endpoint **+91.3 %**.

### 15.1 What is withdrawn

- **REFUTED — "Rotation gives a transient, the static trap a sustained transfer."**
  At 64³ it is the *static* arm that decays (0.49081 → 0.27262) and the
  *rotating* one that is still climbing at 145 ms (peak = end = 0.40358).
- **"The static prescription is the better one on the observable an experiment
  would integrate."** Withdrawn — at 64³ the rotating arm ends higher.
- **"Static and rotating differ by 3.21 %, suggestive of divergence."**
  Withdrawn. The correct reading is not a 3 % divergence but that **32³ does not
  resolve this branch at all.**

### 15.2 What replaces it

Only this, and it is deliberately thin:

> **At 145 ms, 32³ is not resolution-converged. Nothing about the long-time
> ordering of static vs rotating is established at either resolution**, because
> 64³ has n = 1 per point and its baseline arm was **not** run — so 64³ shows the
> 32³ answer is wrong without establishing the right one.

**Superseded in part on 2026-08-20** — both missing measurements were run. The
baseline arm and a second seed at 64³ **establish the PEAK ordering** (static >
rotating > baseline) and leave the **endpoint** ordering still unresolved between
static and baseline. §17.

### 15.3 The part that generalises: resolution adequacy is duration-dependent

The short protocol and the long one behave completely differently under the same
refinement:

| | shift under 32³ → 64³ |
|---|---|
| short (14.5 ω⁻¹), §11.2 | a **uniform** +2.3 %; the 5.2 nT dip kept **93 %** of its depth, so the *shape* survived |
| long (100 ω⁻¹), here | **−3.4 / −23.1 / −42.6 / +91.3 %** — not uniform, and orderings invert |

**So §9–§12 are unaffected** — their conclusions rest on shapes and orderings at
14.5 ω⁻¹, where the refinement was measured to be a uniform offset. It is only the
long-time branch that 32³ cannot carry. Grid adequacy is not a property of the
grid alone; it is a property of the grid *and the integration time*, and a
convergence check done at one duration does not transfer to another.

### 15.4 Why this was caught

Because §13 said its own key number sat inside the resolution uncertainty
(3.21 % against 2.5 %) and named the missing measurement instead of rounding it
away. The 64³ run was then the obvious next thing rather than something nobody
thought to do. **A stated uncertainty that overlaps the claim is a work item, and
writing it down is what makes it one.**

---

## 16. Correcting §14.2, and why ITP cannot prepare the anti-aligned state

§14.2 said the rotating-basis `E = NaN` and `conv = true` came from
`run_registry.jl` reading absent keys through defaults. **The `conv = true` half
of that is wrong**, and finding out why produced the sharpest result in this
document.

### 16.1 What §14.2 got wrong

The `E=NaN conv=true` I quoted was the runner's **stdout**, not the file. Reading
the file directly: `keys: psi, dynamics` — **`energy` and `converged` are ABSENT
entirely.** My probe used `get(fh, "energy", NaN)` and I read its own default back
as a diverged run.

The cause is a **third writer**. `save_rotating_basis_result!`
(`src/workflow/io/save_rotating_result.jl`) owns `result.jld2` for both
`kind: rotating_basis` *and* `kind: spinor`-with-dynamics (`runner.jl:294`), and
it wrote neither key. So `run_registry.jl`'s defaults — the thing §14.2 blamed —
were never reached on this path at all.

**Corrected statement.** The `converged = true` default was real and did print,
but no rotating-basis run ever *stored* it, so the guard-7 claim in §14.2
overstated: a guard reading the file finds nothing, which is `unknown`, not a
pass. The #410 fix to the default remains right; it was simply not the fix for
*this* path. Both writers now behave: absent stays absent, present gets written.

### 16.2 With the energy finally reported, the config was producing nothing

`ground_state.jl` now computes `total_energy(ws)` and a convergence flag from the
μ movement against `tol` — a key the schema accepted and **nobody read**, so
`tol: 1.0e-9` had been inert. Four arms, seed × ITP length:

| `init_m_idx` | ITP | E | conv | ‖ψ‖² | non-zero entries |
|---|---:|---:|---|---:|---|
| 1 (aligned) | 100 | −160177.62 | false | 4.096 | 212992/212992 |
| 1 (aligned) | 1500 | −160177.72 | **true** | 4.096 | 212992/212992 |
| **13 (anti-aligned)** | 100 | **0.0** | false | **0.0** | **0/212992** |
| **13 (anti-aligned)** | 1500 | **0.0** | false | **0.0** | **0/212992** |

**ψ is identically zero** — all 212992 entries — and the run completed and
returned it as a result.

### 16.3 §4.2's prescription is unrealisable, and structurally so

ITP applies `exp(−H dt)` with the Zeeman shift subtracting `min(E_m)`, so the
lowest m gets factor 1 and the highest gets `exp(−(E_max−E_min) dt)`. Here that
is `exp(−12·p·dt) = exp(−1602)`, which **underflows Float64 in one step**. The
`n_before > 0` guard then skipped renormalisation and the loop ran to completion
on zeros.

> **Imaginary time is a projector onto the LOWEST state. The anti-aligned
> preparation is the FURTHEST state from it. §4.2's `init_m_idx: 13` is not a
> configuration choice that was wrong — it is not expressible by ITP at all.**

The klaus_quench (spinor) corpus is unaffected and the reason is quantitative:
there `p ≈ 148`, so the per-step factor is `exp(−8.9)`, renormalised every step
and never underflowing. This only bites at the fast-Larmor `p = 26700`.

### 16.4 What changed

- `init_m_idx` reverted to `1` in `runs/eu151_klaus_phi_phys/config.yaml`, with
  the reason at the line. The config is **knowingly aligned**, i.e. on the wrong
  side for the EdH quench, and says so rather than claiming an anti-alignment it
  cannot have.
- **The underflow is now a hard error**, naming the mechanism and the remedy. A
  zero wavefunction is not a result and must not complete.
- The real repair is a **pipeline** change: relax the stretched state as the
  ground state of the *opposite* field sign, then reverse the field for the
  dynamics — which is also what an experiment does (pump, then reverse). Tracked
  as `edh-phi-phys-anti-aligned-needs-field-reversal`; **not implemented here.**

### 16.5 The pattern, third time in this document

§12.1 (peak read outside the hold), §15 (32³ read as converged), and this one all
have the same shape: **a quantity that was never measured being read through a
default.** `NaN` announced itself; `true` and `0.0` did not. The energy had been
missing for the entire life of this path and nothing said so — it took adding the
report to discover the config produced nothing at all.

---

## 17. The long-time branch at 64³, with the two pieces §15 said were missing

§15 refused to state a replacement ordering for two named reasons: no 64³
baseline, and n = 1 per point. Both are now run — the baseline, plus a second
seed on each of the two arms the ordering rests on.

| arm (64³, 100 ω_ref⁻¹) | hold-peak P_adj | endpoint P_adj |
|---|---:|---:|
| baseline (ω_eff = 1.000, Ω = 0) | 0.37973 | 0.15112 |
| **static** (ω_eff = 0.714) | **0.49081** | 0.17952 |
| **rotating** (Ω = −0.70) | 0.40102 | **0.40013** |

### 17.1 The seed is NOT inert at long time — §10.3 was a short-time statement

Two seeds at 64³, default vs 101:

| | peak | endpoint |
|---|---:|---:|
| static | **0.000 %** | **34.2 %** |
| rotating | 0.63 % | 0.85 % |

§10.3 measured five seeds agreeing to five decimals and proved the knob live, at
**14.5 ω⁻¹**. It also measured the perturbation *growing* two orders over that
run, and this is where that goes: after 100 ω⁻¹ the static arm's **endpoint moves
34 % between two seeds** while its **peak is still identical to five decimals.**

So "the observable is deterministic" was true of the peak and true of that
duration, and is false of the endpoint here. The same mistake shape as §15 —
a property measured at one duration, carried to another — caught this time
because §15 had just made it the thing to check.

### 17.2 What is now established, and what still is not

**Established — the PEAK ordering, at 64³:**

> **static (0.49081) > rotating (0.40102) > baseline (0.37973)**, i.e. the static
> weakened trap beats no-intervention by **+29.3 %** and beats rotation by
> **+22.4 %**. The static peak is seed-independent to five decimals, and the
> gaps are 10–100× the seed scatter on either arm.

**NOT established — the ENDPOINT ordering.** Rotating (0.40013) is 2.23× static
(0.17952), which is far outside the 34 % seed scatter and is safe. But
static-vs-baseline at the endpoint is 0.17952 against 0.15112 — **+18.8 %, inside
the 34.2 % seed scatter on the static arm.** Two seeds cannot separate them. That
row needs an ensemble, not another resolution.

**§13's original claim stays refuted** on its own terms: it asserted the static
arm *sustains* and the rotating one decays, and at 64³ the reverse holds — the
rotating arm is still climbing at 145 ms (peak ≈ endpoint) while the static one
falls from 0.49081 to 0.17952.

### 17.3 The reading

The static weakened trap produces the **larger cascade**; rotation produces a
**more persistent** one. Those are different questions and the 32³ data answered
neither — it inverted both. Which matters depends on what an experiment
integrates, and this document is not in a position to choose for it.

<!-- REDERIVE -->

---

## 7. Constraints that carry, unchanged

Restated here only because a re-derivation session will need them and they are
already decided elsewhere. Do not re-litigate:

- **ε = 1e-6 in the fast-Larmor regime.** At p ≥ 3000 the Y6 formula
  `dt = 0.1·(ε/T)^(1/6)` is too loose: `p=3000, ε=1e-3` produced a **spurious**
  thermal scramble (`0.997 → 0.106`) that `ε=1e-6` does not (`0.997 → 0.999`).
  The pipeline runner warns at `|p|·F·dt > π`; the rotating-basis runner hard-errors
  at `epsilon ≥ 1e-3` with `p·F·dt > π`.
- **Do not sweep `phi_omega`.** The 2026-04-29 record already decided this:
  scan the field (= p), not `phi_omega`, which is secondary at high p — 8 points
  showed only `Lz_max` scaling inversely with it (phi=1 → +1.61, phi=18 → +0.68;
  slower stir = more adiabatic following = more L_z). That record is itself
  pre-fix, so it is a prior to confirm from §3, not an independent result.
- **Do not re-derive uncited runs.** `docs/validation/stored_results_vintage_audit.md`
  and `docs/campaign/doc_run_citation_inventory.md` already sort them.

---

## 8. Reproducing §2 and §3

Everything here is `run_yaml` on the committed `runs/klaus_quench/*.yaml` with at
most three fields changed, so there is no bespoke solver to trust:

| arm set | template | changed |
|---|---|---|
| positive control (§2) | — | 16³, DDI off, `initial_state: spin_coherent`, `init_state_params: {init_theta: 1.5708}`, `Bz: ±0.01 Gauss` |
| §3.2 (4 arms) | `klaus_quench_om0p0.yaml`, `klaus_quench_omm0p5_keeprot.yaml` | sign of every `Bz` incl. both ramp endpoints; `backend` |
| §3.6 (3 arms) | `klaus_quench_om{m,p}0p5_keeprot_mirror.yaml` (called `*_mFplus.yaml` when §3.6 was run; renamed by `e8dafe8e`) | `initial_state`, `rotating_frame_omega`, sign of every `Bz` |

Observables, all from the library (no local reimplementation):
`spin_populations_trajectory` / `psi_snapshots` (`src/workflow/validation/run_observables.jl`)
and `orbital_angular_momentum` (`src/analysis/currents.jl`).

**Four traps this measurement fell into, in order — check each before trusting a
repeat:**

1. `result.jld2["psi"]` is the state at the **start** of the dynamics, not the
   end (§3.1a). It made every arm read as a null.
2. The quoted observable is a **peak**, and the run's last frame is far past it
   (§3.1b).
3. `gauge_fix: false` means two ITP runs differ by a **global phase**, so any
   raw `|a − b|` comparison of ground states reads ≈ 1.4|a| and looks like a
   live knob (§3.2). Use an overlap.
4. `P_adj` must be defined **relative to the prepared state**, not to component
   D. Hard-coding it produced `P_adj = 0.00000` on the one arm built to test for
   a null (§3.6).

All four print a clean, plausible number. None announces itself.
