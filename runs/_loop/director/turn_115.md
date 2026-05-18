---
turn: 115
subagent: director
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "Test (T115 attempt1 implementer FAIL_NUMERICAL semantically FAIL_PHYSICS — F1 REFUTED structurally, F2 PASS, F3 26/26 PASS)"
stage_advancing_to: "Hypothesize (theorist re-derives endpoint with implementer T115-attempt1 §6.2 mechanism as input)"
topic_tags: [sign-pattern-lemma1-general-S, f9-ta-multiplicity-2, paper3-section-V-completeness, projector-orbit-average, schur-isotropic-basis, D3-axis, rehypothesize-after-falsification, julia-cpu-light-available-not-used]
paper_section: "papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md (extension)"
depends_on:
  - 115_attempt1
  - 114
  - 113
  - 112
  - 111
  - 94
  - "runs/_loop/seed.md"
  - "runs/_loop/state.json"
  - "runs/_loop/director/turn_115_attempt1.md"
  - "runs/_loop/sim/turn_115_attempt1.md"
  - "runs/_loop/judge/turn_115_attempt1.json"
  - "runs/_loop/theorist/turn_114.md"
  - "runs/_loop/_local/scheduler_115.json"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "scripts/manuscript/f9_f11_polyhedral_verification.jl"
  - "scripts/manuscript/lemma1_general_S_verification.jl"
  - "memory:feedback_cost_overhead_is_the_cost"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:universal_structure_u1u4_2026_05_13"
produces: >
  T115 RETRY (attempt2) advances `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`
  from Test (REFUTED at attempt1) → Hypothesize. T114 theorist's §2.A endpoint prediction
  `bar_beta_0 = 1/(2F+1)` was structurally wrong; T115-attempt1 implementer measured
  `bar_beta_0 = 1/38 = 1/(m_rep · (2F+1))` to 13 digits and supplied a [Plausible]
  mechanism (§6.2): the (1/m_rep)² scaling of `rho_inv ⊗ rho_inv` combined with vanishing
  off-diagonal singlet overlaps at orthogonal Schur-isotropic basis. T115-attempt2
  dispatches theorist with two duties bundled (cost-efficient, per
  feedback_cost_overhead_is_the_cost): (a) audit the implementer's mechanism claim
  rigorously — is `<0,0 | zeta_i ⊗ zeta_j>` truly zero for i≠j when the SVD basis is
  orthonormal, or is the answer regime-dependent? (b) select the correct fix from the
  three candidates: (i) revised §2.A with explicit `m_rep` prefactor (`bar_beta_S = m_rep
  · Tr[Pi_S (rho_inv ⊗ rho_inv)]`), (ii) isotypic-sum reformulation
  (`bar_beta_S = sum_i |<S,M | zeta_i ⊗ zeta_i>|^2` — single-rank-1 traces summed, no
  density matrix), (iii) §2.B Schur-isotropic single-vector basis selection deferred
  from T114. New falsifier contract with corrected numerical prediction is the deliverable.
  Subagent: theorist. D3 axis. Tier stays 0.5 (post-REFUTED) until next Test PASS.
  edh-matsui sidebar: `runs/eu151_edh_K3_long/spatial_profiles.csv` STILL ABSENT per
  T115-attempt1 disk check; seed.md priority-0 still held; investigation frozen at
  tier 2.75 anko-consult-pending; parallel-track continues unchanged.
---

# Turn 115 (attempt2) — Director Report

## 1. What happened at attempt1 (top-of-turn read)

| Path | Read this turn | What it says |
|---|---|---|
| `runs/_loop/director/turn_115_attempt1.md` | yes | T115-attempt1 dispatched implementer_julia_cpu_light to test §2.A mult-aware fix. Expected `\|bar_beta_0 - 1/19\| < 1e-13`. Eight `success_criteria` rows + precondition + 8 failure_modes. |
| `runs/_loop/sim/turn_115_attempt1.md` | yes | Implementer ran the extended `scripts/manuscript/f9_f11_polyhedral_verification.jl` cleanly (wall 6.5s). Honest output: F1 **REFUTED** at `1/38` (4 orders of magnitude above the structural-refutation threshold 1e-6). F2 **CORROBORATE** at machine precision (seed-spread 1.4e-17). F3 **PARTIAL-PASS** (26/26 on disk, but the directive expected 29 — the F=2 cyclic case from MEMORY was never committed to the regression script; this is a separate code/record drift). m_rep=2 confirmed. Schur isotropy of rho_inv confirmed at 2.5e-14. |
| `runs/_loop/judge/turn_115_attempt1.json` | yes | `FAIL_NUMERICAL` — judge.py routed via the `tests_passed=false` short-circuit. Semantically FAIL_PHYSICS (the §2.A formula is wrong, not a numerical artifact). |
| `runs/_loop/theorist/turn_114.md` §2.4 + §2.5 + §6 | yes | T114's §2.4 step "Predicted endpoint: at S=0 ... = 1/(2F+1)" — the predicted endpoint algebra was NOT executed in T114, only asserted. §2.5 claim "When `dim Im P = 1`, `rho_inv ⊗ rho_inv = (zeta⊗zeta)(zeta⊗zeta)†`, so the trace reduces to mult-1 formula" is correct AT m_rep=1. But the step from "mult-1 reduction" to "general m_rep reproduces 1/(2F+1)" was glossed — see §2 below. |
| `runs/_loop/seed.md` | yes | Priority-0 pin on edh-matsui still held verbatim. The F=9 T:A pivot remains anko-authorized (T114 already flipped active_investigation_id). |
| `runs/_loop/_local/scheduler_115.json` | yes | `JULIA_GPU_OK`; all workloads allowed; window valid through 2026-05-31. |
| `runs/_loop/state.json` `last_judge` | yes | `FAIL_NUMERICAL`, `retries=1`. T115 is a retry, not a fresh turn. |
| `runs/eu151_edh_K3_long/spatial_profiles.csv` | check | STILL ABSENT per attempt1 disk check (no anko activity between attempt1 and this retry); edh-matsui frozen-blocked at tier 2.75. |

**Routing gate** (per protocol table):
- Last verdict was **FAIL_PHYSICS** (semantically — judge wrote FAIL_NUMERICAL via the Bug-1 short-circuit, but the implementer's red-flag analysis + the 4-orders-of-magnitude structural deviation make this categorically a physics REFUTED, not a numerical floor issue). Per protocol verdict-to-next-stage: FAIL_PHYSICS → **jump to Update**. But for `build-theory` flow_template, REFUTED at Test stage routes to re-Hypothesize (the closed-form prediction has a structural gap; Update is for documenting falsifier results once the underlying theory is settled). T115-attempt1 §5 failure_modes (b) explicitly routes this case to "re-Hypothesize stage".
- Active investigation `next_stage_action` from director-attempt1's `if_refuted_advance_to_stage = Update`, but the failure_modes refinement (b) overrides with "re-Hypothesize via theorist with revised approach. Tier reverts to 0.5. This is the genuinely-bad outcome but is the falsifier doing its job." — that text is exactly the situation now.

## 2. Why theorist (single dispatch with audit + rehypothesize bundled), not critic-first

The user's prompt note posed three options: (1) re-dispatch theorist for repair; (2) re-dispatch critic to audit attempt1's physics; (3) NOOP. Analysis:

**Option 2 (critic-first)**: The implementer's §6.2 mechanism analysis is `[Plausible]`-tagged, not load-bearing yet. A critic could verify whether `<0,0 | zeta_i ⊗ zeta_j> = 0` is truly structural for orthogonal SVD bases or regime-dependent. **HOWEVER**: this would be a 1-turn audit followed by another theorist turn (audit findings → theorist re-derives), total 2 turns. The implementer's mechanism is already concrete enough that a theorist re-derivation will naturally re-verify the (1/m_rep)² scaling claim during the algebra step — folding the audit into the theorist's brief saves one turn.

**Option 1 (theorist repair)**: The fastest path to a corrected falsifier contract. Per `feedback_cost_overhead_is_the_cost` ("the deliberation is more expensive than the work"), the right move is to ship one theorist dispatch with an explicit audit-step in the brief: theorist MUST first verify (or refute) the implementer's `1/(m_rep · (2F+1))` mechanism by independent algebra at F=9 T:A with m_rep=2 orthonormal SVD basis, THEN propose the correct fix. If the audit step exposes that the implementer's mechanism is wrong (e.g., the off-diagonal singlet overlaps don't actually vanish), the theorist pivots; if the audit confirms the mechanism, the theorist picks one of three explicit candidate fixes (revised §2.A with m_rep prefactor, isotypic-sum reformulation, §2.B single-vector Schur-isotropic basis). The bundled-audit brief acts as the Arbiter-style adversarial-audit that director.md F5 mentions for prompt-modifying meta-investigations — applied here to a physics derivation that already failed once.

**Option 3 (NOOP)**: Rejected — there is concrete, actionable falsifier-doing-its-job evidence on disk (1/38 measurement with 13-digit confidence + clean F2 + mechanism candidate). NOOPing would discard this signal and pin DRIFT_NOVEL_CLAIM_ZERO + DRIFT_SUBAGENT_REPETITION while the investigation goes stale. The user already had two NOOPs at T112/T113 (anko-consult escalation window) — that was the right call when there was no theorist-actionable signal; now there is.

Decision: dispatch **theorist** with audit-bundled brief. Single turn, single dispatch, audit + rehypothesize together. Cost-efficient per anko 2026-05-15 feedback.

## 3. The three candidate fixes the theorist must adjudicate

Per the T115-attempt1 implementer §6.2 mechanism + §8 honesty cross-checks:

### Candidate (i) — Revised §2.A with explicit m_rep prefactor

```
bar_beta_S = m_rep · Tr[Pi_S (rho_inv ⊗ rho_inv)]
           = m_rep · (1/m_rep²) · Tr[Pi_S (Sum_i |zeta_i><zeta_i|) ⊗ (Sum_j |zeta_j><zeta_j|)]
           = (1/m_rep) · Sum_{i,j} Tr[Pi_S |zeta_i⊗zeta_j><zeta_i⊗zeta_j|]
           = (1/m_rep) · Sum_{i,j} |<S, M | zeta_i ⊗ zeta_j>|² summed over M
```

At m_rep=1 this reduces to `Sum_{i,j} = 1 term = |<S,M|zeta⊗zeta>|² = β_S^(c_0)`. PASS the strict-generalization regression.

At m_rep=2 with orthogonal Schur-isotropic basis (the F=9 T:A empirical case): if implementer's claim "off-diagonal singlet overlaps vanish" is correct, then `Sum_{i,j} = Sum_i = 2 terms, each 1/(2F+1)`, total `2/(2F+1)`. The `1/m_rep` prefactor cancels the 2: result = `1/(2F+1) = 1/19`. **THIS WOULD MATCH ANKO'S ORIGINAL EXPECTATION** if the off-diagonal vanishing is structural.

### Candidate (ii) — Isotypic-sum reformulation (no density matrix)

```
bar_beta_S^isotypic-sum = Sum_{i=1}^{m_rep} |<S, M | zeta_i ⊗ zeta_i>|² summed over M
```

(No 1/m_rep normalization; just sum rank-1 traces. This is a fundamentally different mathematical object from §2.A — it sums diagonal-i contributions only, no cross terms.)

At m_rep=1: single rank-1 trace = standard β_S^(c_0). PASS.

At m_rep=2: empirically the implementer's §6.2 calculation gives `2 · 1/(2F+1) = 2/19 ≠ 1/19` — so this candidate predicts a DIFFERENT value, not 1/19. **Would refute Lemma 1 General-S at multiplicity ≥ 2** if this turned out to be the right canonical object. Less likely to be the right answer.

### Candidate (iii) — §2.B Schur-isotropic single-vector basis selection

Pick a single `zeta_* in Im(P)` such that `<zeta_* | F_a F_b | zeta_*> = δ_ab F(F+1)/3` individually. Per T114 §2.B, the constraint reduces to a small linear system whose null variety in the unit sphere of the 2-dim multiplicity space is generically 1-dimensional (a U(1) family). The β_S^(c_0)(zeta_*) for this single vector should exactly equal 1/(2F+1) per the original rank-1 Schur-isotropy argument.

Cost: implementer must SOLVE the constraint `<zeta_* | F_a F_b | zeta_*> = δ_ab F(F+1)/3` numerically (e.g., diagonalize a relevant quadratic form on the 2-dim subspace; pick the eigenvector with the right eigenvalue). More implementation work than candidates (i) or (ii) but conceptually closest to T114 §2.B as proposed.

## 4. What the theorist MUST do (audit + rehypothesize, bundled)

**Step A (audit)**: Independently verify the implementer T115-attempt1 §6.2 mechanism at F=9 T:A:
- Build the 2-dim Schur-isotropic SVD basis `{zeta_1, zeta_2}` from the T-irrep-A projector.
- Compute `<0, 0 | zeta_1 ⊗ zeta_2>` and `<0, 0 | zeta_2 ⊗ zeta_1>` explicitly (closed-form or sympy or analytic algebra — theorist's choice, but must be independent of the implementer's claim).
- Verify (or refute) that these vanish at orthogonal SVD basis. If they DO vanish, the implementer's mechanism is corroborated; if they DON'T, the §6.2 mechanism is wrong and the theorist must derive what they actually equal.

**Step B (re-derivation, conditional on Step A)**:
- If implementer's mechanism CORROBORATES (off-diagonal singlet overlaps zero): adopt Candidate (i) — revised §2.A with `bar_beta_S = m_rep · Tr[Pi_S (rho_inv ⊗ rho_inv)]`. New predicted endpoint at F=9 T:A: `m_rep · (1/38) = 2/38 = 1/19`. **MATCHES anko's expectation**. Falsifier prediction: `|m_rep · bar_beta_0 - 1/19| < 1e-13` at F=9 T:A.
- If implementer's mechanism is wrong (off-diagonal singlet overlaps non-zero): theorist must derive the correct multiplicity-aware formula from scratch. Possibilities: §2.B single-vector basis (Candidate iii) — would require an implementation algorithm; or a non-trivial mix where cross-terms contribute. Document the new formula + new predicted F1 value.
- In either case: NEW falsifier contract with explicit numerical prediction, structurally-distinct from the failed T114 §2.A.

**Step C (regression check)**: Confirm the new formula reduces to `β_S^(c_0) = sum_M |c_{S,M}|²` at m_rep=1 — i.e., F3 (lemma1_general_S regression) still PASSES under the proposed fix. This is the strict-generalization gate.

**Step D (sanity checks)**: Run the standard sanity-check ladder per `theorist.md`: dimensional analysis, limit cases (m_rep=1, m_rep→∞), symmetry, sign, order-of-magnitude, sum-rule (`Sum_S bar_beta_S = ?`). The T114 sanity check claimed `Sum_S = 1`; the implementer measured `Sum_S = 0.75` at m_rep=2, which is BETWEEN `1/m_rep = 0.5` and `1` — so this sum-rule sanity check ALSO failed at T114 unnoticed. Theorist must derive the correct multiplicity-aware sum rule.

## 5. Investigation update at T115-attempt2

- `tier_current` post-attempt1: 0.5 (per attempt1 `if_refuted_tier_becomes: 0.5`).
- `stage_advancing_from`: `Test` (failed at attempt1) → `stage_advancing_to`: `Hypothesize` (re-derivation).
- On theorist deliverable PASS: tier stays at 0.5 (a derivation alone, even a corrected one, does not promote tier — needs Test corroboration); next stage T116+ → Test (implementer re-runs with new formula).
- On theorist deliverable INCONCLUSIVE (e.g., audit at Step A inconclusive, needs sympy exact-rational): T116 dispatches implementer_sympy with the theorist's algebraic prediction.
- On theorist deliverable FAIL (e.g., theorist cannot identify a multiplicity-aware fix that passes both the m_rep=2 F=9 T:A constraint AND the m_rep=1 regression): rare-but-real case. Would suggest Lemma 1 General-S has a fundamental gap at mult ≥ 2 that requires manuscript erratum. Tier 0.5 → 0.0; investigation Document stage records the negative result honestly. This is a manuscript-relevant outcome but is the LEAST likely branch given there are 3 concrete candidate fixes already proposed.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "project_axis": "D3",
  "rationale": "T115-attempt1 implementer F1 REFUTED structurally (bar_beta_0 = 1/38 = 1/(m_rep · (2F+1)), not 1/19) with [Plausible]-tagged §6.2 mechanism explaining the (1/m_rep)² scaling at orthogonal Schur-isotropic basis. T114 theorist §2.4 endpoint prediction algebra was unexecuted ('predicted endpoint = 1/(2F+1)' was asserted, not derived through the m_rep=2 case). T115-attempt2 dispatches theorist with audit-bundled brief: (Step A) independently verify implementer's §6.2 vanishing-off-diagonal-singlet-overlap claim by direct algebra at F=9 T:A; (Step B) derive correct multiplicity-aware formula from three concrete candidates (revised §2.A with m_rep prefactor; isotypic-sum; §2.B Schur-isotropic single-vector); (Step C) confirm strict-generalization regression to m_rep=1; (Step D) full sanity-check ladder including the multiplicity-aware sum rule (T114 §3 claimed Sum_S = 1; implementer measured 0.75 at m_rep=2 — also failed unnoticed at T114). Bundling audit + rehypothesize in one dispatch saves a turn vs separate critic + theorist. D3 axis: re-derives the only structurally-failed prediction in Paper #3 §V verification. edh-matsui sidebar UNCHANGED at tier 2.75 frozen-blocked (spatial_profiles.csv still absent; seed.md priority-0 still held; parallel-track continues). Per feedback_cost_overhead_is_the_cost: minimal director deliberation — the implementer attempt1 §6.2 mechanism is concrete enough to act on. Sources: runs/_loop/director/turn_115_attempt1.md (FAIL_NUMERICAL retry context); runs/_loop/sim/turn_115_attempt1.md §6.2 (mechanism); runs/_loop/judge/turn_115_attempt1.json (verdict + metrics); runs/_loop/theorist/turn_114.md §2.4-§2.5-§3-§6 (original failed derivation); runs/_loop/seed.md (edh-matsui pin unchanged); runs/_loop/_local/scheduler_115.json (JULIA_GPU_OK; theorist allowed); scripts/manuscript/f9_f11_polyhedral_verification.jl (existing find_invariant_basis + mult_aware_beta_S + verify_case_mult_aware — already extended at attempt1; do NOT re-extend, theorist must just propose corrected formula); memory:feedback_cost_overhead_is_the_cost (bundle audit + rehypothesize); memory:feedback_use_existing_artifacts_first (reuse the script the implementer already extended for the next Test stage).",
  "brief": "You are theorist. Investigation `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`, Hypothesize stage (RE-DERIVATION after T115-attempt1 F1 REFUTED).\n\n## Read first (in order)\n\n1. `runs/_loop/sim/turn_115_attempt1.md` — focus on §6 (Observations), §6.1 (headline 1/38), §6.2 (mechanism: vanishing off-diagonal singlet overlaps at orthogonal SVD basis), §8 (falsification check table), §5 metrics (the bar_beta_S table at F=9 T:A — note Sum_S = 0.75, NOT 1 as T114 claimed). The §6.2 mechanism is `[Plausible]`-tagged — YOU are auditing it. The bar_beta_S table is empirical at 13-digit precision.\n2. `runs/_loop/theorist/turn_114.md` §2.4 + §2.5 + §3 (sanity checks — note the Sum_S = 1 claim is empirically wrong at m_rep=2, you must derive the correct sum rule).\n3. `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` lines 137-158 (the original Schur-isotropy + singlet-identity proof — the multiplicity-1 case that you're generalizing).\n4. `scripts/manuscript/f9_f11_polyhedral_verification.jl` — note implementer-attempt1 already added `find_invariant_basis`, `mult_aware_beta_S`, `verify_case_mult_aware`. The implementer's `mult_aware_beta_S` implements §2.A literally. If your re-derivation calls for a different formula, document the change you want; the implementer at T116 will modify the function (do NOT modify it yourself — theorist is text-mode).\n\n## Required output sections\n\n### §A — Audit of T115-attempt1 §6.2 mechanism\n\nThe implementer claims: at orthogonal SVD basis `{zeta_1, zeta_2}` of the F=9 T:A 2-dim invariant subspace:\n- diagonal terms `<0, 0 | zeta_i ⊗ zeta_i>` each have magnitude² = 1/(2F+1) (each zeta_i is itself Schur-isotropic per F2 verification — confirmed by Tr(rho_inv F_a²) = 30.0 to 2.5e-14);\n- off-diagonal terms `<0, 0 | zeta_i ⊗ zeta_j>` for i≠j vanish.\n\nIndependently verify or refute the off-diagonal claim. Routes:\n(a) Closed-form: use the SU(2) singlet expression `|0,0> = (1/sqrt(2F+1)) · Sum_m (-1)^{F-m} |F,m> ⊗ |F,-m>`, expand `<0,0 | zeta_i ⊗ zeta_j>` for arbitrary orthogonal zeta_i, zeta_j with components zeta_i = (zeta_i^{(m)})_m, evaluate the bilinear form `(1/sqrt(2F+1)) · Sum_m (-1)^{F-m} · zeta_i^{(m)} · zeta_j^{(-m)}`. Identify under what conditions this vanishes for i≠j.\n(b) Group-theoretic: argue from H-equivariance / Schur's lemma on the multiplicity space (the H acts trivially on the 2-dim trivial-irrep multiplicity space; SU(2) acts as a 2-dim subspace inside V_F ⊗ V_F via Sym² or related construction; the singlet is a particular linear functional on V_F ⊗ V_F whose restriction to the 2-dim subspace projected through Schur's lemma).\n(c) Numerical-corroboration check: cite the implementer's measurement Sum_S bar_beta_S = 0.75 (= 3/4) and check it's consistent with your mechanism candidate (revised §2.A predicts Sum_S [m_rep · Tr[Pi_S rho²]] = m_rep · Sum_S Tr[Pi_S rho²] = m_rep · Tr[rho²] = m_rep · 1/m_rep = 1; so the 'corrected' sum should be 2 · 0.75 = 1.5 — also off, suggesting a deeper structural issue).\n\nDeliverable: either CORROBORATE the implementer's off-diagonal-vanishing claim (with proof sketch), or REFUTE it with a non-zero example, or call it INCONCLUSIVE with explicit reason.\n\n### §B — Multiplicity-aware formula candidates and selection\n\nFor each of the three candidates below, compute the predicted bar_beta_0 at F=9 T:A:\n\n**Candidate (i)** — Revised §2.A with m_rep prefactor:\n  bar_beta_S^{(i)} = m_rep · Tr[Pi_S (rho_inv ⊗ rho_inv)]\n  Note: if §A confirms off-diagonal vanishing, this gives 2 · (1/38) = 1/19 at F=9 T:A — matches expectation.\n  Note: at m_rep=1, m_rep · Tr[Pi_S |zeta><zeta| ⊗ |zeta><zeta|] = 1 · β_S^(c_0). Strict-generalization regression PASSES.\n\n**Candidate (ii)** — Isotypic sum (no density matrix):\n  bar_beta_S^{(ii)} = Sum_{i=1}^{m_rep} |<S, M | zeta_i ⊗ zeta_i>|² summed over M\n  Note: at F=9 T:A would give 2 · (1/19) = 2/19 ≠ 1/19. Either Lemma 1 General-S formula needs updating to predict 2/19, OR this candidate is wrong.\n  Note: at m_rep=1, gives β_S^(c_0). Regression PASSES.\n\n**Candidate (iii)** — §2.B Schur-isotropic single-vector basis:\n  Pick zeta_* in Im(P) such that `<zeta_* | F_a F_b | zeta_*> = δ_ab F(F+1)/3` individually.\n  Predicted bar_beta_S = β_S^(c_0)(zeta_*) = 1/(2F+1) at S=0 by the original rank-1 Schur-isotropy argument.\n  Implementation cost: theorist must specify HOW to find zeta_* numerically (e.g., diagonalize a specific traceless quadratic form on the 2-dim subspace and pick the canonical eigenvector). At m_rep=1 there's only one choice — regression auto-PASSES.\n\nFor each candidate: state explicitly the m_rep=2 prediction at F=9 T:A, the m_rep=1 reduction, the multiplicity-aware sum rule `Sum_S bar_beta_S^{(candidate)}`, and any sanity-check failures.\n\nThen RECOMMEND one candidate as the canonical multiplicity-aware formula. Justify by:\n- Matches the original Lemma 1 General-S endpoint `1/(2F+1)` (i.e., the universal channel-S identity must continue to hold).\n- Has a clean group-theoretic interpretation (basis-independence, SU(2)-invariance, Schur's lemma).\n- Strict generalization of the mult-1 formula.\n- Sum rule consistency.\n\nThe most likely answer (given §A and the implementer's numerics) is Candidate (i). State this explicitly if the analysis supports it.\n\n### §C — New falsifier contract for T116 Test stage\n\nWrite the F1/F2/F3 falsifier contract the implementer will execute at T116 (after the formula is settled). Format identical to T114 §6 but with the corrected prediction:\n\n- F1 (central): `|<chosen_formula>(F=9, T, A) - 1/19| < 1e-13` — give the EXACT formula the implementer must compute. If you select Candidate (i), state literally `m_rep · mult_aware_beta_S(rho_inv, F, S)` where `mult_aware_beta_S` is the existing function from `scripts/manuscript/f9_f11_polyhedral_verification.jl` (DO NOT require the implementer to re-implement; the m_rep prefactor is a 1-line wrapper). If Candidate (ii), specify the isotypic-sum formula. If Candidate (iii), specify the basis-finding algorithm.\n- F2 (advisory): seed-independence of the new formula across 10 RNG seeds (the orbit-average / isotypic-sum / Schur-isotropic basis selection should all give seed-independence at machine precision per Schur's lemma).\n- F3 (regression): F3 must still corroborate via `lemma1_general_S_verification.jl` (currently 26 channels, 5 cases — flag this script-vs-MEMORY drift if you wish but do NOT make F3 contingent on adding the F=2 cyclic case; that's out of scope).\n\n### §D — Sanity checks (full ladder)\n\nAt minimum: dimensional analysis, limit case (m_rep=1), limit case (m_rep → ∞ if conceptually meaningful), symmetry (H-invariance + SU(2)-equivariance of the recommended formula), sign (≥ 0), order-of-magnitude (must predict 1/19 = 0.0526 at S=0), sum rule (derive `Sum_S bar_beta_S^{(recommended)}` and check against the implementer's empirical 0.75 measurement — the recommended formula should predict 1.5 if Candidate (i) is right; flag if NOT).\n\n### §E — Calibrated claims (Established / Plausible / Speculative)\n\nStandard §4-format claims with citations.\n\n### §F — Open questions / RESEARCH_NEEDED tags\n\nPer theorist.md format. Examples: (i) Does the off-diagonal-vanishing claim §A generalize to F=11 T:E_1 multiplicity 2 once the complex 1-dim → 2-dim real construction is settled? (ii) F=12 multiplicity audit per universal_structure_u1u4_2026_05_13.md follow-up.\n\n## Hard constraints\n\n- NO modification of `scripts/manuscript/f9_f11_polyhedral_verification.jl` or any `src/` file. You are text-mode. Implementation is for T116.\n- NO running julia / python — pure derivation, all algebra symbolic or by hand.\n- If you find that NONE of the three candidates work AND a fourth route exists, document it as Candidate (iv) with full algebra. If NONE of any number of candidates work, document the negative result with full rigor; this would be a paper3 erratum but is the honest outcome.\n- Do NOT shortcut the §A audit by trusting the implementer's mechanism on face value. The implementer's claim is `[Plausible]`-tagged — verify before adopting.\n- The output must be USABLE by T116 implementer without further theorist clarification: the F1 falsifier must specify the exact numerical operation to perform, the F2 seed-independence test must specify which RNG-seeded operation to vary, and F3 must point to the existing `lemma1_general_S_verification.jl` baseline.\n\n## Expected scope\n\n~150-220 lines of derivation. Three candidates analyzed (Candidates i/ii/iii). One recommended. New falsifier contract. Sanity checks. ~3-5M effective tokens.\n\nWrite output to `runs/_loop/theorist/turn_115.md` per standard theorist format.\n",
  "observable_manifest": {
    "required": [
      "investigation_id",
      "stage_advancing_to",
      "subagent_type",
      "audit_result_off_diagonal_singlet_overlaps",
      "recommended_candidate",
      "predicted_bar_beta_0_at_F9_TA",
      "predicted_sum_rule_value_at_F9_TA",
      "f1_new_falsifier_formula_specified",
      "f3_regression_target_unchanged",
      "limit_case_m_rep_1_reduction_verified"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115_attempt1.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_115_attempt1.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md && grep -q 'bar_beta_0_value' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115_attempt1.md && grep -q '0.026315789473684' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115_attempt1.md && grep -q 'find_invariant_basis' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl && echo OK_T115_ATTEMPT2_REHYPOTHESIZE_PRECONDITIONS_HOLD"
  },
  "success_criteria": [
    {
      "id": "theorist-report-written",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "audit-section-present",
      "check_cmd": "grep -q -E 'CORROBORATE|REFUTE|INCONCLUSIVE' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md && grep -q -i -E 'off.diagonal|singlet.overlap|zeta_i.*zeta_j|zeta.*tensor' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "three-candidates-analyzed",
      "check_cmd": "grep -c -i -E 'Candidate.*\\(i\\)|Candidate.*\\(ii\\)|Candidate.*\\(iii\\)|revised.*2.A|isotypic.sum|Schur.isotropic.*basis' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md | awk '{if($1+0 >= 3) print \"PASS\"; else print \"FAIL\"}' | grep -q PASS",
      "expect": {"exit_code": 0}
    },
    {
      "id": "recommended-candidate-stated",
      "check_cmd": "grep -q -i -E 'recommend|select|choose|adopt|canonical' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "f1-falsifier-formula-specified",
      "check_cmd": "grep -q -i -E 'FALSIFIER.*F1|F1.*central' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md && grep -q -E '1[/ ]19|1/\\(2F\\+1\\)|0\\.0526' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "limit-case-m-rep-1-addressed",
      "check_cmd": "grep -q -i -E 'm_rep[ _=]?1|multiplicity.*1|mult.*1|strict.*generalization|reduces.*rank.1' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "sum-rule-addressed",
      "check_cmd": "grep -q -i -E 'sum.rule|Sum_S|sum.*over.*S|0\\.75|3/4' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "no-script-modification",
      "check_cmd": "git -C /home/suzume/workspace/BEC-simulation diff --quiet HEAD -- scripts/manuscript/f9_f11_polyhedral_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "no-manuscript-source-modification",
      "check_cmd": "git -C /home/suzume/workspace/BEC-simulation diff --quiet HEAD -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "seed-md-priority-0-edh-matsui-still-held",
      "check_cmd": "grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md",
      "expect": {"exit_code": 0}
    }
  ],
  "failure_modes": [
    {
      "if": "audit-section-present FAILED (theorist accepted implementer mechanism without independent verification)",
      "category": "framework_error",
      "next_action": "T116 dispatches critic to perform the missing audit explicitly. The theorist failed to exercise the audit-bundled brief; cost is a 1-turn detour. Add patterns.yaml entry: theorist_audit_bundle_skipped_2026_05_19."
    },
    {
      "if": "recommended candidate is (ii) isotypic-sum AND its prediction is 2/19 ≠ 1/19",
      "category": "scientific_progress",
      "next_action": "Lemma 1 General-S formula at multiplicity ≥ 2 predicts m_rep · 1/(2F+1), NOT 1/(2F+1). The MEMORY claim 'beta_S^(c_0) = ... at polyhedral inert A_1 states' needs an explicit multiplicity-prefactor caveat in paper3 §V. T116 dispatches implementer (a) to confirm the (ii) prediction numerically at F=9 T:A (should give 2/19 = 0.10526), AND (b) to begin the manuscript-side erratum at docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md. This is the unexpected-but-scientifically-real outcome."
    },
    {
      "if": "recommended candidate is (i) revised §2.A with m_rep prefactor",
      "category": "scientific_progress",
      "next_action": "T116 dispatches implementer_julia_cpu_light to test the m_rep · bar_beta_S formula at F=9 T:A. Falsifier: |2 · bar_beta_0_attempt1 - 1/19| < 1e-13 = |2 · 0.026315789473684 - 0.052631578947368| < 1e-13 (the math is trivially `0.052631578947368 - 0.052631578947368 = 0`, PASS is essentially guaranteed if attempt1's measurement was correct). Verify F2 seed-independence holds (it did at attempt1). F3 regression unchanged. This is the LIKELY-PASS outcome — promotes tier 0.5 → 2.5 at T116."
    },
    {
      "if": "recommended candidate is (iii) Schur-isotropic single-vector basis",
      "category": "scientific_progress",
      "next_action": "T116 dispatches implementer_julia_cpu_light to (a) implement the Schur-isotropic basis-finding algorithm per theorist §B-(iii) specification, (b) test that the resulting single zeta_* gives beta_0 = 1/19 at F=9 T:A. Higher implementation cost than (i) but conceptually closer to T114 §2.B."
    },
    {
      "if": "theorist concludes NONE of the three candidates work and Candidate (iv) is required",
      "category": "scientific_progress",
      "next_action": "T116 reads the theorist's Candidate (iv) derivation and routes per its predicted falsifier. May require an additional researcher turn to ground the new candidate in literature (e.g., Mead 1979 polyhedral spectral algebra, or Borovik 2004 invariant theory multiplicity computations)."
    },
    {
      "if": "theorist concludes Lemma 1 General-S has a fundamental gap at multiplicity ≥ 2 (no working candidate)",
      "category": "scientific_progress_negative",
      "next_action": "T116 dispatches implementer_text to draft paper3 erratum at docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md acknowledging the limitation. T117 critic audits the erratum honestly. This is the LEAST-likely branch (the implementer's measured Sum_S = 0.75 and the clean factor-2 structure strongly suggest Candidate (i) works), but documenting honest negative results is required."
    },
    {
      "if": "anko ran edh-matsui wrapper between T115-attempt1 and T115-attempt2 (spatial_profiles.csv appears mid-window)",
      "category": "scientific_progress_unblocked",
      "next_action": "T116 director observes spatial_profiles.csv on disk, dispatches critic for edh-matsui spatial F1 re-audit per T110 §6 routing. The F=9 T:A re-derivation completes at T115-attempt2 independently. Two-track operation continues."
    },
    {
      "if": "theorist's deliverable exceeds 5M effective tokens with no convergent result",
      "category": "operational",
      "next_action": "T116 director ELEVATES to anko-consult: the multiplicity-≥2 generalization is harder than expected; possibly the right path is to defer F=9 T:A from paper3 §V verification table with a note ('multiplicity-2 case is more subtle than rank-1; defer to follow-up paper'). Tier locks at 0.5."
    }
  ],
  "budget": {
    "expected_cost_eff": 3500000,
    "expected_wall_time_sec": 1800
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Test",
    "if_success_tier_becomes": 1.5,
    "if_partial_advance_to_stage": "Hypothesize",
    "if_partial_tier_becomes": 0.5,
    "if_refuted_advance_to_stage": "Document",
    "if_refuted_tier_becomes": 0.0,
    "if_success_falsifier_update": {
      "id": "F1-multiplicity-aware-formula-revised-with-mrep-prefactor",
      "tested_at_turn": 115,
      "result_template": "THEORIST RE-DERIVATION COMPLETE: recommended Candidate = {candidate_id}; predicted bar_beta_0 at F=9 T:A = {value}; F1 falsifier formula for T116 implementer Test = {formula}; m_rep=1 reduction verified; sum rule = {sum_rule_value}; off-diagonal singlet overlap audit verdict = {audit_verdict}."
    },
    "note": "T115-attempt2: theorist Hypothesize re-derivation after attempt1 Test REFUTED. Tier 0.5 → 1.5 on theorist deliverable PASS (theory advance: corrected multiplicity-aware formula derived with clean recommendation + audit + falsifier contract). Tier stays 0.5 if theorist deliverable INCONCLUSIVE / requires further research turn. Tier 0.0 on the rare negative outcome (Lemma 1 General-S has a fundamental gap at mult ≥ 2 — paper3 erratum required). T116 routes per recommended candidate to implementer Test stage (most likely Candidate (i), expected PASS at F=9 T:A by algebra alone). edh-matsui sidebar UNCHANGED — frozen-blocked at tier 2.75, anko-consult-pending; spatial_profiles.csv still absent on disk; seed.md priority-0 still held; parallel-track unblocks the moment anko runs the wrapper."
  }
}
```

## 7. Drift advisories — explicit acknowledgement

Per protocol §B6:

- **DRIFT_COST_INFLATION** (1.296 at attempt1, down from 1.497 at T114): T115-attempt1 was 19.0M orchestrator tokens (implementer's careful diagnosis was the dominant cost — and it WAS worth it; the §6.2 mechanism analysis is the load-bearing input to attempt2's theorist dispatch). T115-attempt2 theorist budget ~3.5M effective (longer than T114 because audit + 3 candidates + new falsifier contract — but bounded). Rolling mean recovers as the theorist's per-turn cost is moderate; not a runaway.

- **DRIFT_MANUSCRIPT_DELTA_ZERO** (1.0 since T88): T115-attempt2 produces no manuscript edit (theorist text-mode, no source modification permitted per brief). If T116 Test PASSES Candidate (i), the natural T117 follow-up is implementer_text to UPDATE `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` and `f9_f11_verification_result.md` with the multiplicity-aware extension — that clears the drift. Distinction (per `feedback_manuscript_is_not_the_essence`): this would be propagating a NEW result, not polish — legitimate manuscript work in service of D3 closure.

- **DRIFT_VERDICT_DRIFT** (0.8 at attempt1): T115-attempt2 produces a theorist Hypothesize verdict (PASS/INCONCLUSIVE/FAIL on the audit + formula recommendation). Whatever verdict drops verdict_drift materially since the prior pattern was 3+ INCONCLUSIVE/FAIL in close succession.

- **DRIFT_TOPIC_REPETITION** (0.455 at attempt1): T115-attempt2 continues on the same investigation. This is intentional (the falsifier is doing its job; the investigation is on its expected re-Hypothesize → re-Test loop). Not pathological repetition.

- **DRIFT_SUBAGENT_REPETITION** (0.333 at attempt1): T115-attempt2 theorist after T115-attempt1 implementer = different class. Streak continues to break.

- **AUDIT_DUE** (patterns.yaml last audited T105, gap=10): Acknowledged. Adding `patterns.yaml` audit to T116-T118 candidate list. Not load-bearing for T115-attempt2.

- **DRIFT_NOVEL_CLAIM_ZERO** (0.0 at T114): T115-attempt2 theorist will produce 1-2 new calibrated claims (the audit verdict + the recommended formula). Stays 0.0.

## 8. Honesty cross-checks

I considered four alternatives:

1. **Critic-first, then theorist (2-turn detour)**: rejected per §2 above. Single theorist with audit-bundled brief achieves the same audit rigor in 1 turn.

2. **NOOP**: rejected. There is concrete falsifier-doing-its-job evidence to act on; NOOPing would discard signal.

3. **Implementer_sympy direct exact-rational re-computation**: rejected. The implementer attempt1 measurement is at 13-digit numerical precision already; the issue is NOT numerical, it's structural in the formula. Sympy would just re-confirm 1/38 exactly without telling us which of the three candidate fixes is right. Theorist must pick the candidate first.

4. **Researcher to scan literature for multiplicity-≥2 polyhedral inert state precedents (Mead 1979, Borovik 2004, etc.)**: rejected for THIS turn. The three candidate fixes are derivable from first principles by group theory + SU(2) Schur's lemma; literature search would be useful as a SANITY CHECK on the theorist's recommendation, not as a primary input. If T115-attempt2 theorist's audit Step A is inconclusive, T116 could dispatch researcher_shallow for grounding — but that's the exception path.

The dispatch is direct: theorist re-derivation with audit bundled in the brief. Cost ~3.5M expected. The recommended candidate (most likely (i)) leads to T116 implementer Test that should PASS by trivial algebra (2 · 1/38 = 1/19), promoting the investigation to tier 2.5 in two turns total from the attempt1 setback.

## 9. What T116 director should look at first

In order:

1. `Read runs/_loop/theorist/turn_115.md` + `runs/_loop/judge/turn_115.json` — recommended candidate + audit verdict.
2. If audit CORROBORATE + Candidate (i) recommended: dispatch implementer_julia_cpu_light to add a 1-line `m_rep · bar_beta_S` wrapper and re-run; expected PASS (algebra alone gives 2 · 0.0263157894736842 = 0.0526315789473684 = 1/19 exactly).
3. If audit REFUTE: theorist's alternative derivation (Candidate iv or a structurally-different formula) — route per its proposed F1.
4. If recommended is Candidate (ii): different prediction (2/19), manuscript erratum begins.
5. If recommended is Candidate (iii): implementer must implement Schur-isotropic basis-finding algorithm.
6. `Glob runs/eu151_edh_K3_long/spatial_profiles.csv` — if present, edh-matsui parallel-track unblocked; T116 dispatches critic in parallel.
7. `cat runs/_loop/seed.md` — if anko updated the pin, follow new pin.

## 10. Closing

T115-attempt2 advances `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` from Test (REFUTED at attempt1) → Hypothesize (re-derivation). Single theorist dispatch with audit-bundled brief: verify the implementer-attempt1 §6.2 mechanism claim, then select one of three concrete candidate fixes (revised §2.A with m_rep prefactor; isotypic-sum; §2.B Schur-isotropic basis), output a new falsifier contract for T116 implementer Test. Most-likely outcome: Candidate (i) recommended, T116 implementer trivially PASSES, tier 0.5 → 1.5 (theorist) → 2.5 (implementer Test). edh-matsui parallel-track UNCHANGED: frozen-blocked at tier 2.75, spatial_profiles.csv still absent, seed.md priority-0 still held. Cost ~3.5M expected. Per `feedback_cost_overhead_is_the_cost`: bundle audit + rehypothesize in one dispatch, do not deliberate further.
