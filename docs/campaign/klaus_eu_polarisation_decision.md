# Klaus-Eu: field sign, polarisation convention, and what gets re-derived

**Scope.** Issue #343, which posed three things: (1) a **defect** in the config
corpus fixed on 2026-07-29 whose numbers were never re-derived, (2) a
**convention difference** in the Klaus-Eu series that is not a defect and was
never adjudicated, and (3) the fact that (1) was **not in the machine-readable
gate** the campaign claims to run.

(1) and (3) hold. **(2) does not, and the measurement replaced it with a
sharper problem**: the two Klaus families are not on opposite sides of anything
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
| 3b | Does the *rotation enhancement* survive the corrected field sign? | **No.** +15.8 % pre-fix vs **−0.45 %** post-fix, with the Ω knob proved live at both. `\|Ω\|/ω_⊥ = 0.468 ± 0.003` is not re-derivable as posed. §3.4 |
| 4 | Align the Klaus-Eu series to m=−F? | **No — and stop saying it in `m`.** The measured criterion is *aligned vs anti-aligned with B*. Klaus/EdH needs the **anti-aligned (Zeeman-highest)** state; under the project's +B_z that is m=+F. §4 |
| 4b | Is `eu151_klaus_phi_phys` really "the one Eu arc on the other side"? | **No.** `p > 0` puts m=+F at the *bottom*, so it is aligned like everything else — and therefore on the wrong side for Klaus. #343 §2's premise was an m-label comparison across two field parameterisations. §4.2 |
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

133 of the 203 have an Eu / Klaus / Matsui / Barnett / EdH name. The producing
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
on the Klaus-Eu sheet that depends on either can be quoted without
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

**Consequence, and it is the operative one:** `|Ω|/ω_⊥ = 0.468 ± 0.003` is not
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

**Decision: do not align the Klaus-Eu series to m = −F, and do not state the
convention in terms of `m` at all.**

The criterion is measured (§3.6) and it is not about the m label:

> **The Klaus-Eu / EdH protocol must prepare the stretched state ANTI-ALIGNED
> with B — the Zeeman-highest state. Every other Eu arc in this project (Matsui
> EdH reproduction, flower / chiral ground states, the #335 κ transition)
> prepares a GROUND state and is aligned. The two families are not in conflict;
> they ask different questions.**

Writing it as "Klaus is m=+F, everything else is m=−F" would be the third
repetition of the mistake this issue is about, because **`m = +F` means the
opposite thing depending on the sign of B_z**, and every incident here came from
someone reading an m label without its field. State the relative orientation;
derive the label.

Under the project-wide convention — B_z > 0, g_F > 0, `H = −p·F_z` with
`p ≡ −g_F μ_B B` — the derived labels are:

| family | preparation | field | seed |
|---|---|---|---|
| Klaus-Eu / EdH cascade | anti-aligned (Zeeman-highest) | B_z > 0 | **m = +F** |
| everything else Eu | aligned (Zeeman ground) | B_z > 0 | **m = −F** |

so **B_z stays positive everywhere** — `bce2068f`'s discipline is kept intact —
and the Klaus family differs in its *seed*, which is the knob that carries the
physics.

### 4.1 What this implies about `bce2068f`

`bce2068f` was a correct **convention** repair: those configs' comments asserted
"NEGATIVE → m=−F lowest energy", which is false under `Units.bfield_to_p`, so
the file contradicted itself and something had to move. It moved the field.

Measured consequence: that choice moved the Klaus corpus from the anti-aligned
regime (where the protocol's phenomenon lives) into the aligned one (where it
does not). Each file became self-consistent and the corpus stopped studying the
effect it was built for. Whether the original author meant the anti-aligned
state or wrote the field sign by mistake is **not recoverable and not worth
arguing** — the physics requirement is now measured either way.

The repair is therefore not "revert `bce2068f`" (that would restore the wrong
convention along with the right physics). It is: **regenerate the Klaus-Eu
corpus as m = +F at B_z > 0**, keeping positive B_z, declaring the
anti-alignment in the file so the next reader and the next gate both see it.

### 4.2 Scope check on the other Klaus family

`runs/eu151_klaus_phi_phys/config.yaml` — the config #343 §2 flagged as "the
only Eu arc on the m=+F side" — specifies `B: {p: 26700.0}` with
`init_m_idx: 1`. Since `H = −p·F_z`, **p > 0 puts m = +F at the BOTTOM** of the
ladder. So that config is *aligned*, i.e. it is on the same side as everything
else in the project and on the **wrong** side for the Klaus protocol. The
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
`klaus_quench_omp0p5_keeprot_mFplus.yaml`. Reading them at `bce2068f~1` — the
tree the PASS was measured on — and at HEAD:

| | seed | B_z (prep → hold) | Ω/ω_⊥ |
|---|---|---|---|
| **pre-fix** `omm0p5_keeprot` | m=−F | −0.01 → −2.6e-5 G | −0.5 |
| **pre-fix** `omp0p5_keeprot_mFplus` | m=+F | +0.01 → +2.6e-5 G | +0.5 |
| **HEAD** `omm0p5_keeprot` | m=−F | **+0.01 → +2.6e-5 G** | −0.5 |
| **HEAD** `omp0p5_keeprot_mFplus` | m=+F | +0.01 → +2.6e-5 G | +0.5 |

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
> Klaus-quench series happens to have no `B_y`, and its missing partner is `B_z`.

**Corollary for per-file repairs.** A fix applied file-by-file can be right on
every file and still break a relationship that spans two of them. Nothing in the
tree recorded that these two configs were a pair, so nothing could warn. Where a
pair of configs *is* a mirror pair, say so in both files.

`test/workflow/test_config_zeeman_seed_agreement.jl` reports both `mFplus` arms
in its m=+F warning list, so the inconsistency is visible today — but it is
reported as "seed opposes field", not as "the mirror relationship is broken",
because the gate reads one file at a time.

---

## 6. The re-derivation list

The point of gate 2 is to shorten this, and it did — but not the way expected.
It did not find observables insensitive enough to skip; it found that the
headline prescription is **not re-derivable as posed** and has to be replaced by
a different measurement.

### 6.1 Re-derive — 2 items

| # | item | why, and what changes |
|---|---|---|
| R1 | **The Ω operating window** (`\|Ω\|/ω_⊥ = 0.468 ± 0.003 @ 2.6 nT`, and the `0.3 @ 1.3 nT` / `[0.5,0.6] @ 5.2 nT` rows with it) | **Not a refinement — a re-posing.** At the aligned preparation there is no optimum (−0.45 %). Re-derive at the **anti-aligned** preparation (m=+F, B_z>0), where the enhancement is +16.5 %. Until then the sheet's three-significant-figure window has no measured basis on current code and must not go to the lab |
| R2 | **The 6 acceptance gates** in `klaus_quench_protocol_spec_2026_05_26.md` | The `(init m × Ω)` reversal-symmetry gate is now *measured* to hold to 5 digits (§3.6, arms E and G), so it re-derives green — but only against the **repaired** pair (§5). The other five have not been re-run |

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

<!-- REDERIVE -->

---

## 7. Constraints that carry, unchanged

Restated here only because a re-derivation session will need them and they are
already decided elsewhere. Do not re-litigate:

- **ε = 1e-6 in the Klaus regime.** At p ≥ 3000 the Y6 formula
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
| §3.6 (3 arms) | `klaus_quench_om{m,p}0p5_keeprot_mFplus.yaml` | `initial_state`, `rotating_frame_omega`, sign of every `Bz` |

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
