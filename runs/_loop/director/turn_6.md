# Turn 6 — Director Report

## 1. Project state snapshot

- **Active work zone (T0–T5)**: T0–T4 all `modify_code` on
  `force_gradient.jl` / Lemma 1 manuscript work — code semantics
  largely unchanged, manuscript extended one F row. T5 broke the
  implementer streak: first researcher dispatch in loop history
  (`runs/_loop/research/turn_5.md`, 205 lines, last_judge=
  `RESEARCHER_ONLY`). Phase 2 D2 axis (researcher path) now
  exercised — loop infra check is satisfied through T5.
- **T5 substantive output**: literature on LHY-on-unstable-GS
  consolidated (Lima-Pelster 2011/2012, Petrov 2015, Bisset 2016,
  UKU 2010, Zhang 2023). **Confidence pattern**: 2 RESOLVED (Q1, Q2)
  + 3 PARTIAL (Q3, Q4, Q5). T5 also identified an exact code line
  (`src/hamiltonian/interactions/lhy/dispatch.jl:230-231`,
  `omega = real(ev); omega > 1e-10 || continue`) and proposed a
  **Nambu-pair mechanism** for the 3000× bug, plus a 5-step
  implementer directive.
- **Hard environment constraint THIS session** (seed.md, light-mode):
  Anko's Klaus phi-magnetostir Julia sweep is running 4 processes
  (~18 GB RAM). Director **MUST NOT** dispatch any subagent that
  spawns julia. T5's recommended next step (implementer adds gate
  to `dispatch.jl` + julia regression test) is **exactly the
  forbidden shape** — must be deferred post-sweep. seed.md lists
  julia-safe alternatives: extend lit audit, critic-audit T5's
  Nambu mechanism, theorize phi_1_reg properties, noop.
- **Manuscript pulse (unchanged)**: Paper #1 LaTeX-ready. Paper #3
  Lemma 1 reach F=3-14 (T4 branch `auto/turn_4_lemma1-f14-extension`
  commit `be6a472` still UNMERGED). Paper #2/#4/#6 raw; Paper #4
  (TWA chaos / F=6) blocked by FullBdG bug.
- **Blocker inventory (no change from T5)**: F=6 polar FullBdGLHY
  3000× spurious (T5 mechanism: PARTIAL confidence, NOT verified);
  TwoChannelLHY F=6 30-70% off (design boundary); Klaus 2022
  magnetostir reproduction in progress on anko's sweep; DDI
  conventions vs Stuttgart never benchmarked; v4 spinor FG code
  blocked; TDHFB Phase 3+ pending.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T3 | `compute_sympy` infra E2E on 3 trivial identities | PASS | Commit `6352726`: validated compute_sympy directive path. Infra value real, physics zero. | Yes (infra unlock). |
| T4 | Lemma 1 General-S F=14 O:A_1 (compute_sympy) | PASS | Branch `be6a472`: Paper #3 +1 row, S=20 exact-zero footnote, falsification CONFIRMED. **Branch NOT MERGED to main.** | Yes — first non-cosmetic manuscript-extending turn; exploited compute_sympy at non-trivial weight. |
| T5 | FullBdGLHY F=6 polar literature audit (researcher) | RESEARCHER_ONLY | `runs/_loop/research/turn_5.md`: 8 refs (5 DOIs + 3 arXivs), convention table, Nambu-pair mechanism hypothesis, 5-step next directive. Q1/Q2 high confidence; Q3/Q4/Q5 partial / paywalled. | Yes — Phase 2 D2 axis exercised, sets up T6+ implementer/theorist, but the mechanism claim needs validation before being cashed into code. |

**Trajectory check (§B4)**: T0/T1/T2/T3/T4 were all implementer-shape
or theorist→implementer; T5 was researcher (rotation). T6 should
NOT default back to researcher (that's now a second consecutive
researcher if dispatched); per §B4 "no more than 2 same-subagent
in a row" in seed.md stop conditions. Also not implementer-julia
(julia-forbidden this session). Open routes: theorist (Read/Web
only), implementer-text-only, implementer-compute_sympy, critic
(Read only), noop.

## 3. Bottleneck analysis

Top candidates by (project value × p(this turn moves it) / cost),
filtered to julia-safe moves:

- **B-1: T5's Nambu-pair mechanism claim is load-bearing AND
  unverified.**
  *Issue*: T5 §"Sanity check against F=6 polar 3000× observation"
  asserts that "complex eigenvalues of the physical BdG become real
  eigenvalues of the Nambu matrix — this is a standard property of
  the Nambu structure." That claim drives the recommended fix
  (count imaginary modes of the upper-D **physical** block, not
  the Nambu eigenvalues). **If the claim is wrong, the fix is
  wrong.** T5 confidence on Q4 was `medium`; the Nambu-doubling
  property statement specifically had no citation. T5 also offers
  an inconsistent alternative ("paired ±λ from imaginary branch")
  in §"Code findings (pre-literature)" — these are not the same
  mathematical statement. Resolving the inconsistency before the
  julia-implementer turn lands prevents shipping the wrong fix.
  *Category*: verification gap (load-bearing claim audit) +
  physics gap (correct Nambu instability spectrum).
  *Leverage*: **5**. Saves a wasted implementer turn post-sweep;
  one Read-only turn audits a paper-scale claim before it cascades.
  *What moves it*: **critic** (1 turn) — Read T5 + dispatch.jl +
  Lima-Pelster / Petrov refs (already cached in T5); challenge
  the Nambu-doubling claim; produce a corrected mechanism statement
  OR ratify T5's. critic dispatch is also untouched in loop history
  (Phase 2 critic-axis gap).

- **B-2: Theorize phi_1_reg(t≤-1) saturation as the canonical
  analytic continuation; produce a design spec for FullBdGLHY fix.**
  *Issue*: T5 §"Q5" identified that `PolarContactLHY` (which works)
  uses `phi_1_reg(t)` that saturates at `t=-1` to the Petrov plateau
  (0.3177). This is the closed-form analytic continuation for
  modes that would go imaginary. The FullBdGLHY numerical path
  has no analog — it just thresholds on `real(ev) > 1e-10`. A
  theorist turn that crystalizes "the canonical replacement for
  the threshold is the phi_1_reg analytic continuation applied
  per Nambu eigenvalue" gives a publishable Paper #4 contribution
  AND a clean spec for the post-sweep implementer turn.
  *Category*: physics gap (correct LHY treatment) + manuscript
  gap (Paper #4 contribution).
  *Leverage*: **4**. High value (turns the FullBdG bug into a
  Paper #4 result rather than a tech-debt fix), but multi-turn
  (needs sympy or even algebraic work). This turn delivers a
  PROBLEM SETUP / DESIGN SPEC, not a result.
  *What moves it*: **theorist** — Read + Write only, no code/julia.
  Falsifiable: theorist produces an explicit candidate formula
  for the per-mode replacement contribution.

- **B-3: Merge T4 `auto/turn_4_lemma1-f14-extension` to main.**
  *Issue*: F=14 Lemma 1 extension on branch but not landed; T5
  research happens on the new tip but doesn't reference T4's
  unmerged state.
  *Category*: infra / housekeeping.
  *Leverage*: **1**. Mechanical; not director-shaped (orchestrator
  / anko handles merge).

- **B-4: Extend T5's lit audit on the spinor-LHY-on-unstable-GS
  question — Yi-Pu / Kawaguchi-Ueda / Saito-Li explicit equations.**
  *Issue*: T5 left Q3/Q4/Q5 PARTIAL because of paywall / lack of
  explicit equation extraction. Another researcher turn could
  close those — but seed §"Stop conditions" includes
  "no more than 2 same-subagent in a row", and T5 was researcher.
  Doable but rotation rule disfavors.
  *Category*: verification gap.
  *Leverage*: **3**. Diminishing returns vs T5; the remaining
  open questions are mostly paywalled, low p(close-this-turn).

- **B-5: Critic-audit the unmerged T4 F=14 Lemma 1 derivation.**
  *Issue*: T4 commit `be6a472` is one S=0 channel via the singlet
  identity (low risk, leverages 26-channel rational closed form).
  *Category*: docs gap audit.
  *Leverage*: **2**. Low risk to begin with (S=0 singlet identity
  is a rigorous one-line proof in Paper #3 v2 BdG signs doc),
  plus the branch is not on main. Not the place to spend a critic
  turn.

- **B-6: noop.**
  Quota OK (T4 burned 1.74M effective, T5 was researcher (likely
  ≤1.5M)). julia constraint binds, but B-1/B-2 are both julia-
  free and cheap. noop is not justified.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | Critic audits T5's Nambu-pair mechanism (load-bearing claim that determines the post-sweep fix shape) | **critic** | NOW (cheap, gates next post-sweep dispatch) | ≤ 1.2M effective, ≤ 10 min |
| 2 | Theorist crystallizes phi_1_reg analytic-continuation as design spec for FullBdG fix | theorist | possible NOW, more naturally AFTER critic ratifies T5 mechanism | ≤ 1.8M, ≤ 20 min |
| 3 | Extend T5 lit audit (Yi-Pu / Saito-Li / Kawaguchi-Ueda exact eqs) | researcher | rotation rule disfavors | ≤ 1.5M, ≤ 15 min |
| 4 | Implementer-text-only: convert T5 research brief into a `docs/design/fullbdg_F6_polar_fix_spec.md` design doc | implementer (text-only) | possible NOW; lower physics rigor than critic/theorist | ≤ 1.0M, ≤ 10 min |
| 5 | noop | n/a | not justified (cheap moves available) | 0 |

**Pick: Option 1 (critic → audit T5's Nambu mechanism).**

Why:
- **§B3 critic routing rule applies**: "Dispatch when the last N
  turns may have agreed on a wrong answer because they share
  priors. Costly; only invoke when a load-bearing claim from
  prior 3 turns is paper-scale." T5's Nambu-doubling mechanism IS
  load-bearing (drives the fix to be applied post-sweep) AND
  paper-scale (it would appear as the technical justification in
  any Paper #4 / FullBdGLHY note). T5 is exactly one prior turn
  with that claim; the priors are anchored by the lit-search
  pattern (Petrov + Lima-Pelster both handle DIPOLAR phonon
  instability; T5 transposes to SPINOR mean-field instability
  via the "Nambu doubling" bridge — that bridge step is the audit
  target).
- **§B4 rotation rule applies**: T5 was researcher; T0-T4 were
  implementer-shape. Critic has **never been dispatched** in loop
  history (state.json: no critic agent_hash usage). T6 is exactly
  the right place to exercise the Phase 2 critic axis (parallels
  the T5 researcher-axis exercise).
- **§A5 value test**: hits (b) verification-gap closure AND (d)
  bug blast-radius reduction. Without this audit, the post-sweep
  implementer turn risks landing a fix on the WRONG mechanism,
  burning a julia turn AND creating a regression that has to be
  reverted.
- **julia constraint satisfied**: critic uses Read only per
  seed.md. No julia, no python, no compute.
- **§B5 seed acknowledgment**: seed.md explicitly lists "critic-
  audit T5's Nambu-doubling mechanism explanation" as one of three
  director-safe options. This is option 2 of the three.
- **Cost-bounded**: critic reads 1 sim/research file + 1 source
  file + 2 papers (T5 already cached); no derivation work, no
  literature scan. Expected ≤ 1.2M effective tokens, comparable to
  T5 researcher burn.

Why NOT theorist (Option 2) today:
- Theorist's value is conditional on the critic ratifying T5's
  mechanism. If T5 is wrong (Nambu eigenvalues don't actually go
  large-positive-real for imaginary physical modes — the correct
  statement might be that they go imaginary too, and the
  threshold is silently filtering them via `real(ev) ≤ 1e-10`),
  then the theorist's design spec built on T5's mechanism would
  be wrong-direction. Critic first, theorist next turn.

Why NOT researcher (Option 3) today:
- §B4 explicit ("no more than 2 same-subagent in a row" per seed.md
  stop conditions); T5 was researcher. Also the open questions
  (Yi-Pu / paywalled equations) are low p(close-this-turn). Marginal.

Why NOT implementer-text-only design doc (Option 4):
- Strictly weaker than the critic audit: a design doc that
  uncritically encodes T5's PARTIAL-confidence mechanism would
  propagate the (possibly wrong) claim into a docs artifact,
  increasing blast radius rather than reducing it. The critic
  output IS the de-facto design doc precursor.

Why NOT noop:
- §F2 noop test fails: quota healthy (T5 was researcher; rolling
  burn well under cap), cheap bottleneck available (B-1 is one
  read-only audit), seed.md explicitly enumerates this exact move
  as director-safe.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness | **at risk** | F=6 polar FullBdGLHY 3000× now mechanism-hypothesized (T5) but not VERIFIED. TwoChannelLHY F=6 30-70% (design boundary). Klaus 2022 — anko's sweep running, not loop-driven. No physics effects added T0-T5. |
| Verification depth | **on track** (slight improvement) | T5 closed the literature side of D2-axis verification for LHY-on-unstable-GS (2 RESOLVED + 3 PARTIAL refs cached). FG sign 18/18 regression solid. DDI vs Stuttgart still untouched. **T6 critic-audit would close the technical-mechanism side**, leaving only "post-sweep implementer cashes the fix" as the residual gap. |
| Manuscript | **on track for Paper #1, #3** | Paper #1 LaTeX-ready. Paper #3 Lemma 1 +1 row T4 (branch, unmerged). Paper #2/#4/#6 raw. Paper #4 specifically is the one that would benefit from this turn's critic audit (the audit's output is publishable as a §Method footnote in Paper #4). |
| Reproducibility | **on track** | YAML schema, lab-units, resumable. No regression T0-T5. |
| Loop infrastructure | **partial → improving** | T5 exercised researcher axis (first time). T6 (this dispatch) would exercise critic axis (first time). Two of four directive shapes still untouched after T6: `run_experiment` (forbidden anyway this session), `compute_sympy` exercised T3 + T4. |

**Mark**: Verification depth is the wheel turning this session.
T5 closed lit-side; T6 closes mechanism-side. Post-sweep T7 lands
the fix. Each turn cashes the prior turn's deliverable. This is
exactly the layered routing the protocol design wants.

## 6. Dispatch decision

```json
{
  "subagent_type": "critic",
  "rationale": "T5 (RESEARCHER_ONLY, runs/_loop/research/turn_5.md) introduced a load-bearing technical claim that drives the post-sweep fix: 'complex eigenvalues of the physical BdG become real eigenvalues of the Nambu matrix — standard property of the Nambu structure' (§Sanity check, no citation, confidence-medium). The claim is paper-scale because (a) it would appear as the technical justification in any Paper #4 / FullBdGLHY method note; (b) it dictates whether the fix counts imaginary modes of the upper-D physical block (T5's recommendation) vs of the 2D Nambu matrix (the current code's effective behavior). T5 also offers an inconsistent alternative formulation ('paired ±λ from imaginary branch' in §Code findings) — these are mathematically distinct statements. Per §B3 critic routing rule: invoke when 'a load-bearing claim from prior 3 turns is paper-scale.' Per §B4 rotation: T0-T4 implementer-shape, T5 researcher; critic has NEVER been dispatched (state.json no critic hash usage). Per seed.md julia-safe constraint: critic uses Read only — no julia process spawn, no risk to anko's parallel sweep. Per seed.md director-safe option list: 'critic-audit T5's Nambu-doubling mechanism explanation' is explicitly enumerated.",
  "brief": "Goal: audit the load-bearing technical claim in `runs/_loop/research/turn_5.md` that drives the post-sweep FullBdGLHY F=6 polar fix. Determine whether T5's proposed mechanism for the 3000× spurious offset is internally consistent and consistent with the Nambu / Bogoliubov literature already cached by T5. **Output is a critic report at `runs/_loop/critic/turn_6.md`** (create the directory if absent). NO code edits, NO julia execution, NO new literature scan beyond verifying T5's citations.\n\n## Context to read (in order)\n\n1. `runs/_loop/research/turn_5.md` — full T5 brief. Pay specific attention to:\n   - §Code findings (pre-literature), 2nd paragraph: 'the Nambu structure means paired eigenvalues come in ±λ — the *positive* member of a pair from an imaginary branch is actually a large positive real number from the Nambu doubling, not zero.'\n   - §Sanity check, point 2: 'Each imaginary mode of the physical BdG enters the Nambu 2D×2D matrix as a pair (+iΩ, -iΩ). When diagonalized, the Nambu matrix eigenvalues are *real* (the complex eigenvalues of the physical BdG become real eigenvalues of the Nambu matrix — this is a standard property of the Nambu structure).'\n   - §Next-turn directive, point 1: 'count the fraction of the upper-D eigenvalues (particle sector) that are imaginary'.\n2. `src/hamiltonian/interactions/lhy/dispatch.jl` lines 200-242 (the `_compute_lhy_at_density` BdG diagonalization). Note specifically: line 214-218 builds a 2D × 2D matrix from L (upper-left), M (upper-right), -conj(M) (lower-left), -conj(L) (lower-right). This is a **non-Hermitian** matrix (Bose Bogoliubov with the η = diag(I, -I) metric, NOT the bosonic standard η·H = M·R diagonalization). Line 225 calls `eigen(H_bdg)` — standard LAPACK eigendecomposition without symplectic structure handling.\n3. The 2 high-confidence refs T5 cited inline: Petrov 2015 (PDF link in T5 §Q2) and the Bose-Bogoliubov standard treatment. Confirm what the Nambu eigenstructure looks like for a bosonic system with imaginary physical Bogoliubov modes.\n4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/full_bdg_F6_polar_broken.md` for the original empirical observation (3000× offset).\n\n## Audit questions (priority-ordered)\n\nC1 (load-bearing, decides fix shape). **Is T5's Nambu-doubling claim correct?** Specifically: when the physical Bose Bogoliubov spectrum has eigenvalues ω ∈ {iΩ, -iΩ} (purely imaginary pair, dynamical instability), does the 2D × 2D Nambu matrix `[[L, M]; [-M*, -L*]]` diagonalized via standard `eigen()` produce (i) a real ±|Ω| pair (T5's claim), or (ii) the same iΩ, -iΩ imaginary pair, or (iii) four eigenvalues from a quadruple structure ±Ω, ±iΩ (the well-known 'instability quartet' of non-Hermitian systems), or (iv) something else?\n\nC2. T5's §Code findings paragraph and §Sanity check paragraph make two DIFFERENT statements about the Nambu pair: (a) '±λ where positive member is large positive real' versus (b) 'complex eigenvalues become real eigenvalues — this is a standard property.' Are these consistent? Which (if either) is supported by Bose-Bogoliubov literature?\n\nC3. **Threshold mechanism**: the current code at line 230-231 takes `real(ev)` and filters `> 1e-10`. T5 claims this filter does NOT catch the spurious modes because they pass through. Under each of the three possible C1 spectra (T5's, instability-quartet, or pair-preserved imaginary), what does the current filter actually retain? Trace the logic and report.\n\nC4. **UV subtraction**: line 236 computes `mu_b = ek + n0*real(h_total[c_star,c_star]) - mu + zee[c_star]` using `c_star = argmax(abs2.(u_part))` from the upper-D block of the eigenvector. For modes that are spurious-instability (whatever their spectral form is per C1), is `c_star` even meaningful? T5 claims the UV subtraction is miscalibrated; verify that diagnosis at the level of: 'the dominant component of an unstable-mode eigenvector is not a well-defined particle-asymptote label.'\n\nC5. **Fix shape implication**: depending on C1's answer, which of these implementer fixes is correct:\n  - F-α (T5's): diagonalize the upper-D physical block separately; count imaginary modes; gate at 10% imaginary.\n  - F-β: diagonalize the Nambu matrix as currently done, but use the symplectic / `η·H` structure to identify quasi-particle vs quasi-hole sectors and apply a sign-corrected threshold.\n  - F-γ: switch to a different LHY mode entirely (e.g., dispatch to PolarContactLHY automatically when GS purity > threshold) — bypass the bug rather than fix it.\n\n## Deliverables (write to `runs/_loop/critic/turn_6.md`)\n\n1. **§Verdict on T5's mechanism**: one of {RATIFIED, RATIFIED-WITH-CORRECTIONS, REJECTED, INDETERMINATE}. Falsifiable.\n2. **§Corrected mechanism statement** (1 paragraph) — the technical sentence that should appear in any Paper #4 / FullBdGLHY method note. If RATIFIED, restate T5's; if corrected, give the right version with the standard Bose-Bogoliubov instability spectrum citation.\n3. **§Code-level prediction**: what does line 230-231 filter actually retain when the GS is mean-field unstable (F=6 polar)? Quantitative: 'N out of 2D eigenvalues, with spectral shape X.'\n4. **§Recommended fix shape**: pick F-α, F-β, F-γ, or 'critic cannot decide without theorist derivation, escalate'.\n5. **§Citations** referenced (use T5's already-cached set; add at most 1-2 new only if directly load-bearing).\n6. **§Confidence**: per-claim {high, medium, low}.\n\n## Falsification / out-of-scope\n\n- If C1 cannot be answered from the cached refs alone and would require a full theorist derivation, say so in §Recommended fix shape: 'escalate to theorist' — do NOT invent the answer.\n- If T5's mechanism is REJECTED but the alternative is also unclear, report INDETERMINATE — do NOT silently reframe.\n- Out-of-scope: writing code, running julia, fetching new refs beyond verifying T5's, deriving new identities.\n\n## Cost\n\n- Token budget: ≤ 1.2M effective tokens. Critic should Read T5 + dispatch.jl + memory + at most 2 cached refs.\n- Wall-clock: ≤ 10 min.\n- No code edits, no julia execution, no python execution. Read-only.\n- Output: `runs/_loop/critic/turn_6.md` per loop schema (and orchestrator records `critic` agent_hash in state.json — first critic dispatch in loop history).",
  "expected_outcome": "(1) `runs/_loop/critic/turn_6.md` exists with §Verdict (one of RATIFIED / RATIFIED-WITH-CORRECTIONS / REJECTED / INDETERMINATE), §Corrected mechanism (1 paragraph + citation), §Code-level prediction (quantitative: spectrum shape at imaginary BdG), §Recommended fix shape (F-α / F-β / F-γ / escalate), §Citations, §Confidence. (2) Judge status PASS (critic is read-only, no code regression). (3) state.json T6 history entry records critic agent_hash for first time — exercises the Phase 2 critic-axis loop infra. (4) Sets up T7 (post-Julia-sweep) implementer dispatch with a verified fix shape, avoiding a wasted julia turn on the wrong mechanism.",
  "expected_cost": "≤ 10 min wall-clock, ≤ 1.2M effective tokens. Read-only protocol; no JIT cost, no python startup, no WebFetch beyond verifying ≤2 of T5's cached refs.",
  "if_fails_next_step": "If critic returns INDETERMINATE ('cannot decide from cached refs'), T7 dispatches theorist (julia-safe; Read/Write only) to derive the Bose-Bogoliubov instability quartet structure from first principles using sympy if needed. If critic returns REJECTED with a clear alternative mechanism, T7 (post-sweep) dispatches implementer-julia with the corrected fix shape per critic §Recommended-fix-shape. If critic returns RATIFIED, T7 dispatches implementer-julia with T5's original directive — but now with a critic-ratified justification for the Paper #4 method note.",
  "consumed_seed_md": true
}
```

`consumed_seed_md`: **true**. seed.md (2026-05-15 morning,
light-mode) enumerates three director-safe alternatives when the
T5 implementer-julia recommendation must be deferred: extend lit
audit, critic-audit T5's Nambu mechanism, theorize phi_1_reg
properties. This dispatch picks option 2 (critic-audit T5
mechanism), exercises the Phase 2 critic-axis infra (first time),
and sets up a verified-mechanism handoff for the post-sweep
implementer turn. The other two seed options remain available for
T7 if critic-audit doesn't close.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=6, last_judge=
      RESEARCHER_ONLY, T5 researcher dispatch recorded, no critic
      agent_hash yet in history).
- [x] Read `runs/_loop/seed.md` (2026-05-15 morning, light-mode,
      julia hard constraint, explicit director-safe options).
- [x] Read `runs/_loop/director/turn_5.md` (T5 rationale +
      researcher dispatch shape; understands the brief landed at
      T5).
- [x] Read `runs/_loop/director/turn_4.md` (T4 Lemma 1 F=14 still
      unmerged at branch `auto/turn_4_lemma1-f14-extension`).
- [x] Read `runs/_loop/research/turn_5.md` (the most recent loop
      output; identified two distinct mechanism statements at
      §Code findings vs §Sanity check that need critic
      reconciliation).
- [x] Read T4 judge (`runs/_loop/judge/turn_4.json`, PASS,
      compute_results 3/3 OK).
- [x] Read ≥1 memory: `full_bdg_F6_polar_broken.md` (stale-2-days
      flag noted),`lhy_refactor_2026_05_12.md` (post-refactor LHY
      state, `@warn maxlog=1` guard at F=6 polar).
- [x] Verified source line citations: `src/hamiltonian/interactions/
      lhy/dispatch.jl` lines 115-128 (`@warn` guard), 200-242
      (BdG body), 214-218 (Nambu matrix construction), 225
      (`eigen(H_bdg)`), 230-231 (T5's identified threshold),
      236 (UV subtraction).
- [x] Considered NOT dispatching critic — challenged with theorist
      (Option 2, conditional on critic ratifying) and researcher
      (Option 3, rotation-rule disfavored). Critic wins on §B3 +
      §B4 + cost.
- [x] §6 brief is specific: file paths, T5 paragraph references
      (verbatim quotes for the mechanism statements being audited),
      5 priority-ordered C-questions, 3 candidate fix shapes
      (F-α / F-β / F-γ), 6-section deliverable schema,
      falsification criteria (INDETERMINATE allowed), cost cap.
      Critic does not need clarifying questions.
- [x] Justified why THIS turn — the T7 (post-sweep) implementer
      dispatch needs a verified mechanism; doing critic NOW means
      the mechanism is ratified before the julia-blocked window
      reopens.
- [x] `consumed_seed_md: true` — seed enumerates this exact move
      as option 2 of three director-safe alternatives.
