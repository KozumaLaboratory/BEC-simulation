---
turn: 9
subagent: director
topic_tags: [paper4-iv-critic-audit, fullbdg-methodology-note-verification, cascade-closure-quality-gate, julia-safe, drift-cost-inflation-response, subagent-rotation]
paper_section: docs/manuscript/papers/paper4_chaotic_dynamics/main.md
depends_on: [5, 6, 7, 8]
produces: A critic audit of T8's commit 2bceceb (auto/turn_8_paper4_iv_fullbdg_methodology_note) — the §IV.E + §IV.F text — against T7 theorist source (turn_7.md §0-§8) for (a) [Established]/[Plausible]/[Speculative] tier fidelity, (b) citation accuracy (Castin-Dum 1998 / Colpa 1978 / Blaizot-Ripka 1986 / Lieu 2018 / KU 2012 at theorem-statement level), (c) T5/T6 rejected-mechanism handling, (d) F-δ specification correctness. Output is text only (critic Read-only). Julia-safe. Decision: PASS = anko can merge 2bceceb to main with confidence; FAIL = director T10 dispatches implementer-text to revise.
---

# Turn 9 — Director Report

## 1. Project state snapshot

- **T5→T6→T7→T8 cascade is now four turns deep on the F=6 polar
  FullBdGLHY thread.** T8 (commit `2bceceb`, branch
  `auto/turn_8_paper4_iv_fullbdg_methodology_note`, judge PASS) wrote
  202 lines of new manuscript content (§IV.E pseudo-Hermitian failure
  mode + §IV.F F-δ signature test) + 8 references into Paper #4. **The
  branch is UNMERGED**; main's `docs/manuscript/papers/paper4_chaotic_
  dynamics/main.md` is still 330 lines with §IV ending at IV.D
  (verified by Grep — 0 matches for "FullBdG" / "Castin-Dum" /
  "pseudo-Hermitian" / "Colpa" / "Blaizot-Ripka" / "orbit-I" on main).

- **T7 (theorist) + T8 (implementer-text) operate on a [Plausible]-tier
  mechanism claim.** T7 §2.2 ratified hypothesis (i)+(iii) with a
  quantitative 3000× order-of-magnitude estimate — but the ratification
  was the theorist's own self-derivation. T6 critic only audited T5's
  Nambu-doubling claim and rejected it; **T6 did NOT positively endorse
  hypothesis (i)+(iii)**. T7 was published downstream and T8 cashed it
  into manuscript text. The cascade structure means a load-bearing
  [Plausible] mechanism claim went from theorist → implementer-text →
  manuscript without an independent audit pass. This is exactly the
  §B4 "3+ turns share priors" footgun the protocol warns about — the
  cascade was *designed* to be self-correcting at T6 (which worked for
  the T5 claim), but T7's replacement claim never went through the
  same gate.

- **T8 drift signals from state.json[history][-1]**:
  `topic_repetition=0.286`, `subagent_repetition=0.667`,
  `cost_inflation=1.284`, `verdict_drift=0.222`,
  advisory `DRIFT_COST_INFLATION`. The cost-inflation flag
  (1.284× recent average) is consistent with T8 doing
  a chunky manuscript composition (~1.55M effective). The
  subagent_repetition 0.667 reflects T5/T6/T7/T8 = researcher /
  critic / implementer-text-as-theorist / implementer-text-as-composer
  — four of last four turns drove forward by reading T5-T7 turn
  reports rather than reading the codebase or external literature.
  Per §B6: `DRIFT_COST_INFLATION` advisory → "pick a cheap route
  this turn." Critic Read-only fits this perfectly (~0.5-1M typical;
  T6 = 1.26M was atypically heavy because it ran the full BdG
  spectrum sanity check).

- **Anko's hard environment constraint UNCHANGED** (seed.md
  2026-05-15 light-mode): Klaus phi-magnetostir Julia sweep still
  running (4 procs, ~18 GB RAM, untracked configs in git status
  show `runs/eu151_klaus_phi_phys/phi_*/` configs + freshly
  generated `barnett_precursor.pdf` etc.). Director MUST NOT
  dispatch implementer with `julia` execution.

- **Other manuscript state**: Paper #1 LaTeX-ready (unchanged).
  Paper #3 F=14 branch `be6a472` from T4 still UNMERGED (deferred
  in T7/T8 director reports — anko-ratification). The 2bceceb
  branch from T8 is now joined to that pile of unmerged work.

- **Loop infrastructure status**: T0-T4 modify_code ×4; T5
  researcher; T6 critic; T7 modify_code (theorist work as
  text-implementer); T8 modify_code (manuscript composition).
  Effectively 6 of last 9 turns ran modify_code. Critic was
  exercised once (T6). The infrastructure has not been stress-
  tested on the "audit a downstream cash-in" pattern.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T6 | Critic audit of T5's Nambu-doubling mechanism claim | CRITIC_FAIL | `runs/_loop/judge/turn_6_critic_audit.md` rejected T5 with high confidence + 3 competing hypotheses + explicit theorist handoff. First non-PASS in loop. | Yes — exactly the layered-cascade audit the architecture was designed for. Saved a wasted implementer-julia turn. |
| T7 | Theorist derivation: bosonic BdG pseudo-Hermitian spectrum + mechanism resolution (i)+(iii) + sympy S1/S2 + 18-line docstring landed | PASS | `runs/_loop/theorist/turn_7.md` 670+ lines: §2.1 η H η = H† proof, §2.2 mechanism resolution, §2.3 5-ref citation table, §2.4 F-δ recommendation, §8 publishability assessment. Commit `6f92776` (UNMERGED). | Substantively yes — derivation is well-formed. But: **the replacement mechanism claim was theorist-self-audited only**, never went through a critic pass like T5's claim did. Asymmetric audit depth. |
| T8 | Implementer-text cash-in: T7 derivation → Paper #4 §IV.E + §IV.F + 8 refs | PASS | Commit `2bceceb` on branch `auto/turn_8_paper4_iv_fullbdg_methodology_note` (UNMERGED). 202 lines manuscript. T7 derivation now reachable in citable form. | Substantively yes (high faithfulness to T7 source per T8 §5 self-report) — but the source's [Plausible]-tier mechanism claim went into manuscript text without an independent audit. |

**Trajectory check (§B4)**: Four-turn topic concentration on F=6
polar FullBdGLHY. Different subagent shapes (researcher / critic /
theorist-via-impl / composer-via-impl) but same thread. T6
audited T5; T7 derived a replacement; T8 published the
replacement. The replacement was NEVER audited. This is a real
asymmetry — and `DRIFT_COST_INFLATION` advisory does NOT change
that finding. T9 should close the audit asymmetry before the
thread is declared closed.

## 3. Bottleneck analysis

Candidates ranked by leverage (value × p(this turn moves it) / cost),
filtered to julia-safe per seed.md, and weighed against §B6 drift
advisory `DRIFT_COST_INFLATION` (prefer cheap routes).

- **B-1: Critic audit of T8's `2bceceb` manuscript content against T7
  theorist source — closes the cascade audit-asymmetry.**
  *Issue*: Paper #4 §IV.E + §IV.F was composed from T7's [Plausible]-
  tier mechanism without an independent audit pass. The cascade design
  intends critics to gate publishable artifacts; T6 audited the
  *rejected* claim, but the *replacement* claim that ended up in
  manuscript text was never gated. Before anko merges branch
  2bceceb → main, an independent reading of (a) the §IV.E text vs
  T7 §2 source for [Established]/[Plausible] tier fidelity, (b) the
  citation chain (5 refs at theorem-statement level: are the cited
  theorems actually saying what §IV.E claims?), (c) the framing of
  the rejected T5 Nambu-doubling claim ("natural-but-wrong picture"),
  (d) the §IV.F F-δ specification correctness vs T7 §2.4 — would
  give anko a confidence signal for the merge decision.
  *Category*: verification gap (audit) + docs gap (gate manuscript
  before merge).
  *Leverage*: **5**. Closes the cascade audit asymmetry. Cheap
  (critic Read-only ~0.5-1M typical). Decision-relevant for anko's
  merge decision on `2bceceb` AND on the pending T4 `be6a472`
  branch (both unmerged manuscript artifacts share the "wrote
  downstream of a theorist claim that was self-audited" pattern).
  Julia-safe by construction (critic is Read-only). Responds to
  `DRIFT_COST_INFLATION` (cheap route).
  *What moves it*: **critic (Read-only audit, output to
  `runs/_loop/critic/turn_9.md`)**.

- **B-2: Cash-in Paper #4 §V Conclusions update — natural extension
  of T8.**
  *Issue*: Paper #4 §V (Discussion and Conclusions) already exists on
  main (lines 235-309) — it is NOT TBD; T8's §IV insertion was
  between §IV.D and §V. §V mentions the FullBdGLHY caveat zero
  times and still talks about LHY as a tool ("deterministic GP-LHY
  mean-field results ... are robust"). Some §V wording could be
  threaded to reference §IV.E.
  *Category*: docs gap (consistency).
  *Leverage*: **3**. Useful for editorial polish but NOT
  load-bearing — Paper #4's claims survive without it. Better
  served as a small wording edit done as part of the same merge
  pass.

- **B-3: Researcher cross-check — pull verbatim Eq 2.21 from
  Castin-Dum 1998 and the explicit Colpa 1978 Thm 3.1 statement, into
  a reference file under `docs/manuscript/shared/`, so the Paper #4
  §IV.E citations have backup verifiable text.**
  *Issue*: T7 §2.3 cited at theorem-statement level; T8 §IV.E cites
  the same depth. If a reviewer asks "show me Eq 2.21," the project
  has no archived copy.
  *Category*: docs gap.
  *Leverage*: **2**. Genuinely useful but redundant with B-1 — a
  critic audit will surface whether the citations are correctly
  applied, after which a researcher pull becomes a focused
  follow-up if needed. Better routed by B-1's output.

- **B-4: Theorist derives the F-δ Goldstone-counting + edge cases
  (T7 §5 open question).**
  *Issue*: T7 §5 deferred questions:
  Goldstone-counting under spinor symmetry breaking, exact mapping
  of Castin-Dum Eq 2.21 to LAPACK |u|²≈|v|² behavior.
  *Category*: physics gap.
  *Leverage*: **2**. §B4 trap — 5th derivation iteration on the
  same thread; would deepen the audit asymmetry rather than close
  it. Also `DRIFT_COST_INFLATION` says no to a chunky theorist run.

- **B-5: Standalone design doc `docs/design/fullbdg_F6_polar_fix_
  spec.md` for the F-δ fix shape (post-sweep implementer prep).**
  *Issue*: T8 §IV.F already captures F-δ at manuscript level;
  re-stating in a design doc is redundant.
  *Category*: docs gap.
  *Leverage*: **2**. Wait for B-1 output — if critic finds gaps in
  §IV.F's specification, a focused design doc fills them.

- **B-6: noop.**
  Quota healthy (last 3 turns 1.55M, 0.96M, 1.26M effective —
  under 3M cap). Cheap audit move available. noop fails §F2 test.

- **B-7: Merge `be6a472` (T4 Lemma 1 F=14 branch) and/or `2bceceb`
  (T8 Paper #4 §IV.E branch) to main.**
  *Issue*: Three unmerged manuscript-grade branches accumulating
  (T4 + T7 + T8). Mechanical, not director-shaped, and anko hasn't
  asked for ratification.
  *Category*: housekeeping.
  *Leverage*: **1**. Defer to anko.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | **Critic audits T8 commit `2bceceb` §IV.E + §IV.F vs T7 source** | **critic** | NOW — closes cascade audit-asymmetry, responds to `DRIFT_COST_INFLATION` (cheap), anko-merge-decision-relevant | ≤ 1.0M, ≤ 15 min |
| 2 | Researcher verbatim pull of Castin-Dum Eq 2.21 + Colpa Thm 3.1 | researcher | LATER — better routed by B-1 critic findings | ≤ 1.5M, ≤ 15 min |
| 3 | Theorist edge-cases for F-δ Goldstone count | theorist | DEFER — §B4 5th-derivation trap, `DRIFT_COST_INFLATION` veto | ≤ 2.0M, ≤ 25 min |
| 4 | §V Conclusions threading edit | implementer | LATER — minor editorial; bundle with merge | ≤ 0.5M, ≤ 10 min |
| 5 | Standalone F-δ design doc | implementer | LATER — wait on B-1 | ≤ 1.0M, ≤ 15 min |
| 6 | noop | n/a | not justified | 0 |

**Pick: Option 1 (critic, Read-only audit of T8 `2bceceb` content
against T7 source).**

Why:

- **§A5 value test**: hits (b) closes a verification gap (the
  cascade's audit-asymmetry; a [Plausible] claim went through
  manuscript composition without independent reading), (c) reduces
  bug blast radius (manuscript misstatement would propagate
  externally once Paper #4 is submitted). Two of four §A5 axes —
  sufficient for a cheap turn.

- **§B3 critic routing rule applies (verbatim)**: "Dispatch when
  the last N turns may have agreed on a wrong answer because they
  share priors. Costly; only invoke when a load-bearing claim from
  prior 3 turns is paper-scale." T8 §IV.E is paper-scale; T7's
  mechanism claim is load-bearing; T7 self-audited and T8 trusted
  T7; the priors are shared. This is the textbook case.

- **§B4 rotation rule applies (favorable)**: T5 researcher / T6
  critic / T7 impl-text-as-theorist / T8 impl-text-as-composer.
  Critic was last invoked at T6 (3 turns ago); it is the most
  rotation-fresh subagent. Dispatching it now improves rotation
  health rather than worsening it.

- **§B6 drift response (favorable)**: `DRIFT_COST_INFLATION`
  advisory → "pick a cheap route this turn." Critic Read-only
  typically runs 0.5-1M effective (T6 ran 1.26M due to
  matrix-spectrum sanity check; this turn the critic reads text
  + verifies citation-statements only, no matrix work). Fits the
  advisory.

- **Cascade closure narrative**: T5 lit scan → T6 critic
  rejection → T7 theorist replacement → T8 manuscript
  composition → **T9 critic audit of the composition**. After T9
  PASS, anko has a clean signal: "merge `2bceceb` to main." After
  T9 FAIL, T10 dispatches implementer-text to revise. Either way
  the cascade closes cleanly.

- **Julia constraint satisfied**: critic is Read-only by
  protocol; no julia execution possible.

- **Cost-bounded**: ~0.7-1.0M effective. Critic reads T7
  (~670 lines) + T8 diff at 2bceceb (~202 lines) + checks
  external claim depth for the 5 citations (no WebFetch needed
  if the citations are stated at theorem-statement level — the
  critic verifies internal consistency only). Comparable to T6's
  pre-spectrum-work baseline.

Why NOT Option 2 (researcher) primary: Verbatim citation pull is
only valuable AFTER an audit identifies which citations are at
risk; doing it now is fishing-without-target.

Why NOT Option 3 (theorist): §B4 5th-iteration trap on same
thread, `DRIFT_COST_INFLATION` veto. T7 §5 open questions are
genuinely deferrable.

Why NOT Option 4 (editorial §V threading) as primary: 30-line
wording tweaks are too small to be a director turn; bundle into
the eventual merge PR.

Why NOT noop: a cheap, leveraged, drift-compliant move exists.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness | **at risk** | F=6 polar FullBdGLHY mechanism diagnosed (T7) but fix still julia-blocked. No new physics this session. F-δ fix deferred to post-sweep. |
| Verification depth | **at risk → on track if T9 PASS** | T5→T6→T7→T8 closed mechanism question with derivation + citations + sympy + manuscript text — but T7's replacement mechanism claim was self-audited only. T9 critic closes that gap. |
| Manuscript | **on track for Paper #4** | T8 added §IV.E+§IV.F to a feature branch. After T9 PASS + merge, Paper #4 §IV is complete (was TBD on line 6); §V was already on main. Paper #1 LaTeX-ready, Paper #3 F=14 branch unmerged. |
| Reproducibility | **on track** | YAML schema, lab-units, resumable. T7 sympy traces archived. No regressions. |
| Loop infrastructure | **maturing**: 5 of 6 axes exercised (modify_code ×5, researcher ×1, critic ×1, theorist-via-impl ×1, compute_sympy ×2, run_experiment ❌ forbidden). T9 critic = 2nd critic invocation; tests "audit of downstream cash-in" pattern not yet exercised. |

**Mark**: Verification axis is at risk this session because the
cascade's audit gate landed only at T6 (catching T5's wrong claim)
and not at T8 (publishing T7's replacement claim). T9 closes that
gap with a cheap, drift-compliant move.

## 6. Dispatch decision

```json
{
  "subagent_type": "critic",
  "rationale": "T5→T6→T7→T8 cascade is four turns deep on the F=6 polar FullBdGLHY thread. T6 critic rejected T5's Nambu-doubling mechanism with high confidence (`runs/_loop/judge/turn_6_critic_audit.md`); T7 theorist (`runs/_loop/theorist/turn_7.md` §2.2) replaced it with a [Plausible]-tier hypothesis (i)+(iii) self-derived + self-audited; T8 (commit `2bceceb` on branch `auto/turn_8_paper4_iv_fullbdg_methodology_note`, judge PASS) cashed it into Paper #4 §IV.E + §IV.F (202 lines + 8 references). The replacement mechanism claim never went through the same independent-audit gate that caught the T5 claim — this is exactly the §B3 critic-routing case ('load-bearing claim from prior 3 turns is paper-scale; the priors are shared'). Branch 2bceceb is UNMERGED (verified by Grep on main: 0 matches for FullBdG/Castin-Dum/pseudo-Hermitian/Colpa/Blaizot-Ripka/orbit-I in paper4 main.md), so an audit before anko's merge decision is the precise moment of leverage. State.json[history][-1].drift_advisories=['DRIFT_COST_INFLATION'] → §B6 'pick a cheap route' satisfied by critic Read-only. §B4 rotation favorable (critic last invoked at T6, 3 turns ago, most rotation-fresh). Julia-safe by construction (critic is Read-only per protocol).",
  "brief": "## Goal\n\nAudit T8's manuscript content (Paper #4 §IV.E + §IV.F, on branch `auto/turn_8_paper4_iv_fullbdg_methodology_note` commit `2bceceb`) for fidelity to the T7 theorist source (`runs/_loop/theorist/turn_7.md`). Output a PASS / WEAK_PASS / FAIL verdict with reasons. NO julia execution. NO web fetch needed (citations are at theorem-statement level — verify internal consistency only). Critic is Read-only by protocol.\n\n## Why this audit matters\n\nT6 critic rejected T5's Nambu-doubling claim — the cascade's designed audit gate fired. T7 theorist self-derived a replacement mechanism (hypothesis i+iii) and self-audited via sympy S1/S2. T8 implementer composed Paper #4 §IV.E + §IV.F directly from T7's [Plausible]-tier mechanism. Anko is about to consider merging branch 2bceceb to main. The replacement mechanism claim never went through an independent reading — this audit closes that asymmetry before the manuscript text propagates externally.\n\n## Materials to read\n\nIn this order:\n\n1. `runs/_loop/theorist/turn_7.md` (~670 lines) — the source material. Pay attention to:\n   - §0 conventions (bosonic vs fermionic Nambu sign, L Hermitian / M symmetric, η = diag(I_D, -I_D)).\n   - §2.1 derivation of η H_bdg η = H_bdg^† and the (λ, -λ*) spectrum-pairing theorem.\n   - §2.2 mechanism resolution at F=6 polar — hypothesis (i)+(iii) with the quantitative 3000× order-of-magnitude estimate.\n   - §2.3 citation table (5 refs: Castin-Dum 1998 §II.B Eq 2.21 / Colpa 1978 Thm 3.1 / Blaizot-Ripka 1986 §3.6 / Lieu 2018 Tbl I / KU 2012).\n   - §2.4 recommended fix F-δ (signature test on H_S = η H_bdg).\n   - §4 calibrated claims (which are [Established] vs [Plausible]).\n   - §8 publishability assessment.\n\n2. `runs/_loop/judge/turn_6_critic_audit.md` — for the rejected T5 mechanism context (need to verify T8 framed it correctly in §IV.E as a 'natural-but-wrong picture').\n\n3. `runs/_loop/research/turn_5.md` (the convention chain section) — for the Lima-Pelster 'drop imaginary part' standard treatment that §IV.E.5 references.\n\n4. **The T8 diff itself**: `git show 2bceceb -- docs/manuscript/papers/paper4_chaotic_dynamics/main.md` — the 202 lines of new content (§IV.E and §IV.F). Note the file at HEAD on main is 330 lines; the branch version is 531 lines. You may also `git diff main..2bceceb -- docs/manuscript/papers/paper4_chaotic_dynamics/main.md`.\n\n5. `runs/_loop/sim/turn_8.md` §5 'Observations' — T8 implementer's own self-report on what it did (placement decision, claim-level adherence, T5 rejected-mechanism handling).\n\n6. `src/hamiltonian/interactions/lhy/dispatch.jl:115-128` — the 18-line docstring T7 inserted, which §IV.E.4 cross-references.\n\n## Audit checklist\n\nFor each item below, decide PASS / WEAK_PASS / FAIL and quote evidence. Be specific (line numbers in the T8 diff, paragraph indices in T7).\n\n### Audit-1: Claim-tier fidelity\n\n- Does the §IV.E text correctly mark [Established] vs [Plausible] claims at the same level as T7 §4?\n- Specifically: is the 3000× mechanism attribution framed as [Plausible] ('we propose' / 'order-of-magnitude consistent') rather than as proven?\n- Does §IV.E avoid introducing any new claim beyond T7's tier (no [Speculative] content)?\n- Verdict + 2-3 quoted sentences from §IV.E showing the tier framing.\n\n### Audit-2: Pseudo-Hermitian spectrum theorem (η H η = H†)\n\n- Does §IV.E correctly state the bosonic BdG η-pseudo-Hermiticity (L Hermitian, M symmetric, η = diag(I_D, -I_D))?\n- Is the spectrum-pairing (λ, -λ*) and the orbit classification {R, I, Q, Z} stated correctly?\n- Is the orbit-I (purely-imaginary pair ±iΩ stays imaginary) statement consistent with T7 §2.1's derivation?\n- Verdict + quote.\n\n### Audit-3: Mechanism (i)+(iii) and the 3000× estimate\n\n- §IV.E.3 should identify two contributing causes: (i) LAPACK condition-number noise pushing |Re(λ)| above 1e-10 filter, and (iii) zero symplectic norm making c* = argmax_c|u_c|² ill-defined.\n- Is the 3000× spurious offset attribution stated correctly (matching memory `full_bdg_F6_polar_broken.md`: GS energy -2.527e6 vs :scalar -880.5)?\n- Is the quantitative order-of-magnitude reasoning faithful to T7 §2.2 (without overclaiming)?\n- Verdict + quote.\n\n### Audit-4: T5 rejected-mechanism handling\n\n- §IV.E.2 (or wherever T8 placed it) should describe the T5 Nambu-doubling claim as 'tempting-but-wrong' with the orbit-I explanation.\n- Is the rejection framed as following from the pseudo-Hermitian theorem (orbit-I ±iΩ stays imaginary, NOT becoming real), not as ad-hoc dismissal?\n- Verdict + quote.\n\n### Audit-5: Citation accuracy at theorem-statement level\n\nFor each of the 5 T7 §2.3 references (Castin-Dum 1998 §II.B Eq 2.21, Colpa 1978 Thm 3.1, Blaizot-Ripka 1986 §3.6, Lieu 2018 Tbl I, KU 2012), verify:\n\n- Is the claim T8 attributes to the reference consistent with what T7 §2.3 stated the reference says?\n- T8 §IV.E.6 may include a 'Citation summary table' (5 rows) — check internal consistency with §IV.E body.\n- DO NOT WebFetch the actual papers — the audit is internal-consistency between T7 source and T8 manuscript text. If T7 misattributed something, that is a T7-level finding (note it but it's outside this audit's primary scope).\n- Verdict per citation, then overall.\n\n### Audit-6: F-δ specification correctness (§IV.F)\n\n- Does §IV.F (T8 placement; check whether it ended up as §IV.F or elsewhere) state the F-δ fix shape consistent with T7 §2.4?\n- Specifically: form H_S = η H_bdg, use `eigen(Hermitian(H_S))`, test signature (N_+, N_-) of H_S, compare to (D, D), with policy for the unstable case.\n- Is it correctly framed as 'future work / forward-looking infrastructure' rather than as already implemented?\n- Verdict + quote.\n\n### Audit-7: Placement coherence with Paper #4 §I-IV existing structure\n\n- T8 placed the content as §IV.E + §IV.F (not §IV.A as the directive suggested) to avoid renumbering existing §IV.A-D. Is the logical flow preserved (§IV.D → §IV.E transition coherent)?\n- Does the introductory sentence at the start of §IV.E adequately motivate the methodology disclosure within Paper #4's narrative (TWA-vs-LHY positioning)?\n- Verdict + quote.\n\n### Audit-8: Overall paper-scale soundness\n\n- Would an expert reader (e.g., a referee for PRR / PRX) accept §IV.E as written, or would they flag specific issues?\n- If FAIL: list the top 2-3 specific revisions needed (with line/paragraph pointers).\n- If WEAK_PASS: list the top 1-2 improvements anko should make pre-submission.\n- If PASS: state that anko can merge `2bceceb` → main with confidence.\n\n## Output format\n\nWrite to `runs/_loop/critic/turn_9.md` (path determined by orchestrator).\n\nStructure:\n\n1. **Verdict**: PASS / WEAK_PASS / FAIL with one-paragraph summary.\n2. **Audit-1 through Audit-8**: per-item verdict + 1-3 sentence justification + quoted evidence.\n3. **Specific findings**: numbered list of any concrete issues (revisions, missing nuance, overclaim, etc.). Empty list if no issues.\n4. **Merge recommendation**: explicit recommendation to anko regarding branch `auto/turn_8_paper4_iv_fullbdg_methodology_note` (commit `2bceceb`) merge to main.\n5. **Out-of-scope notes** (optional): any T7-level concerns (theorist source itself has issues) that go beyond this turn's scope.\n\n## Out-of-scope\n\n- DO NOT WebFetch the cited papers (Castin-Dum, Colpa, Blaizot-Ripka, Lieu, KU). Audit is internal-consistency between T7 turn report and T8 manuscript text.\n- DO NOT propose new physics claims or extend the derivation. This is an audit, not a derivation turn.\n- DO NOT modify any files. Critic is Read-only.\n- DO NOT execute julia. (And critic protocol forbids it anyway.)\n- DO NOT audit Paper #4 §I-IV.D (the pre-T8 content) — out of scope; only §IV.E + §IV.F are new.\n- DO NOT make the merge decision unilaterally — recommend, but anko ratifies.\n- If T8's commit content cannot be retrieved via `git show 2bceceb -- ...`, STOP and report (don't fall back to reconstructing it).",
  "expected_outcome": "(1) `runs/_loop/critic/turn_9.md` with explicit PASS / WEAK_PASS / FAIL verdict + Audit-1 through Audit-8 per-item assessments + numbered specific findings + merge recommendation for branch `auto/turn_8_paper4_iv_fullbdg_methodology_note`. (2) If PASS: anko has confidence signal to merge 2bceceb → main, closing the four-turn cascade T5→T6→T7→T8→T9 cleanly. (3) If WEAK_PASS: top 1-2 improvements listed for anko's pre-submission pass (manuscript still mergeable). (4) If FAIL: top 2-3 specific revisions identified for T10 implementer-text dispatch. (5) Cost stays under 1.0M effective (critic Read-only, no spectrum sanity work, no WebFetch). (6) No regression (Read-only). (7) Cascade audit asymmetry closed: T7's replacement mechanism claim now has the same gate-pass status as T5's rejected claim did.",
  "expected_cost": "≤ 15 min wall-clock, ≤ 1.0M effective tokens. Critic reads T7 turn report (~670 lines) + T8 sim report (~150 lines) + git show 2bceceb diff (~202 lines) + T5 research / T6 critic context (skim). No WebFetch, no julia, no sympy.",
  "if_fails_next_step": "If T9 returns FAIL with specific revision findings: T10 dispatches implementer-text to apply the revisions on branch `auto/turn_8_paper4_iv_fullbdg_methodology_note` (text-only, julia-safe). If T9 returns WEAK_PASS: T10 candidates are (a) §V Conclusions threading edit to reference §IV.E (small editorial); (b) researcher verbatim citation pull (B-3 in §3) if Audit-5 surfaced citation concerns; (c) defer to anko for merge ratification + revisions in a subsequent merge PR. If T9 returns PASS: T10 candidates shift toward unrelated bottlenecks — Paper #3 F=14 branch merge ratification request to anko, OR standalone F-δ design doc (B-5), OR Paper #1 forward progress, OR if anko's julia sweep has finished, the F-δ implementation julia turn finally unblocks. If T9 produces a CRITIC_FAIL-style verdict that surfaces issues at the T7 derivation level (out-of-scope notes), T11 may need a theorist re-pass — but that's two turns out, and §B4 5th-iteration trap consideration applies then. Worst case: T9 cannot retrieve commit 2bceceb (branch missing / git error) — T10 escalates to anko since the loop's own commit is the audit target.",
  "consumed_seed_md": true
}
```

`consumed_seed_md: true`. seed.md §"Director MAY dispatch"
explicitly enumerates "critic — Read only" as a permitted shape.
seed.md "T5 left a concrete next-turn pointer" notes the
julia-implementer path is forbidden this session and lists
alternatives including "critic-audit T5's Nambu-doubling mechanism
explanation" (T6 already did this), implying critic-audit of the
*next* cascade artifact (T8's manuscript text) is the natural
in-spirit continuation. The cascade audit-asymmetry argument in
§1-§3 above is the precise framing of "research progresses most"
goal from seed.md: a publishable [Plausible]-tier mechanism going
into manuscript text without an independent audit gate is the kind
of failure mode anko's goal explicitly warns against ("verify
implementation against papers" — here, verify our own derivation
against itself before externalizing).

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=9, history through T8,
      drift_advisories=['DRIFT_COST_INFLATION'], drift_signals
      topic_repetition=0.286, subagent_repetition=0.667,
      cost_inflation=1.284).
- [x] Read `runs/_loop/seed.md` (2026-05-15 light-mode, julia
      forbidden, critic Read-only permitted).
- [x] Read `runs/_loop/director/turn_8.md` (T8's own dispatch +
      §6 if_fails_next_step which named §V cash-in, design doc,
      and lemma1-f14 merge as T9 alternatives — none of those
      address the audit-asymmetry which is the actual highest-
      leverage move).
- [x] Read `runs/_loop/sim/turn_8.md` (T8 implementer self-report:
      placement was §IV.E+§IV.F not §IV.A; claim-tier adherence
      self-asserted; T5 rejected-mechanism explicitly addressed;
      8 refs added; commit 2bceceb on branch
      auto/turn_8_paper4_iv_fullbdg_methodology_note).
- [x] Read `runs/_loop/judge/turn_8.json` (PASS, info_warning re:
      --no-gpg-sign infrastructure issue, falsification CONFIRMED).
- [x] Read `runs/_loop/theorist/turn_7.md` §0 (conventions — bosonic
      Nambu sign, η = diag(I_D, -I_D), L=L†, M=M^T) and §2.1 first
      proof block (η H_bdg η = H_bdg^† derived).
- [x] Read `docs/manuscript/papers/paper4_chaotic_dynamics/main.md`
      (current main HEAD state — 330 lines, §IV.A-D, §V present,
      §IV TBD label on line 6, references TBD on line 314).
- [x] Verified via Grep that T8's content does NOT exist on main:
      0 matches for "FullBdG", "Castin-Dum", "pseudo-Hermitian",
      "Colpa", "Blaizot-Ripka", "orbit-I" in paper4 main.md on
      current main HEAD. So branch 2bceceb is genuinely unmerged.
- [x] Read ≥1 memory:
      `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/full_bdg_F6_polar_broken.md`
      (2-day-stale reminder; the 3000× offset and the @warn
      guidance match the T7 derivation and T8 manuscript content);
      `universal_theorem_status.md` (Paper #3 and F=14 branch
      context — separate work stream, unmerged be6a472 from T4
      still pending ratification, ratifies the broader "unmerged
      branches accumulating" observation).
- [x] Considered NOT dispatching critic — challenged with
      researcher (Option 2; better routed AFTER audit), theorist
      (Option 3; §B4 5th-iteration trap + DRIFT_COST_INFLATION
      veto), implementer-text §V edit (Option 4; too small for a
      director turn; bundle into merge), design doc (Option 5;
      wait for audit findings), noop (Option 6; cheap leveraged
      move exists). Critic wins on §B3 routing + §B4 rotation
      freshness + §B6 cost compliance.
- [x] §6 brief is specific: 6 files to read in order, 8 numbered
      audit checklist items, explicit out-of-scope list (no
      WebFetch, no julia, no file modification, no §I-IV.D
      audit), output structure (verdict / per-item / findings /
      merge recommendation / out-of-scope notes), output path
      `runs/_loop/critic/turn_9.md`. Critic does not need
      clarifying questions.
- [x] Justified why THIS turn — the cascade audit-asymmetry must
      close BEFORE anko's merge decision on 2bceceb propagates the
      [Plausible]-tier claim into main. Waiting one more turn
      means anko may merge in the interim. Critic NOW is the
      precise moment of leverage.
- [x] `consumed_seed_md: true` — seed.md's spirit (advance
      research, verify, julia-safe, prefer cheap routes) +
      explicit allowance of "critic — Read only" is satisfied.
      DRIFT_COST_INFLATION advisory directly honored.
