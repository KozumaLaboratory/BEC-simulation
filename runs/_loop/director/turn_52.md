---
turn: 52
subagent: director
investigation_id: audit-class-scan-2026-05-18-T50
stage_advancing_from: Triage
stage_advancing_to: L3_critic_audit (sub-stage within Findings/Triage envelope per §F6 safety rail; Document deferred to T53)
topic_tags: [audit-class-scan, patterns-yaml, l3-critic-audit, coupling-skip-gate-inconsistency, topology-function-WHAT-comment-pattern, safety-rail-grounded-self-reflection, lp-1-empirical-anchor-zero-hits, lp-2-grep-quality-check]
paper_section: null
depends_on: [51, 50, "runs/_loop/director/turn_51.md", "runs/_loop/sim/turn_51.md", "runs/_loop/judge/turn_51.json", "runs/_loop/research/turn_50_audit_class_scan.md", "runs/_loop/patterns.yaml", "runs/_loop/_local/scheduler_52.json", "runs/_loop/state.json", "runs/_loop/seed.md", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_decision_style"]
produces: "critic audit report at runs/_loop/judge/turn_52_critic_audit.md evaluating LP-1 (coupling-skip-gate-inconsistency) and LP-2 (topology-function-WHAT-comment-pattern) against §F6 4-question safety rail; verdict per proposal (ACCEPT-TO-ACTIVE / REJECT-WITH-RATIONALE / REVISE-AND-RESUBMIT); empirical anchor verification (grep hit counts director pre-confirmed: LP-1 = 0 hits in src/ → fails 1-10000 rule; LP-2 = 5 hits in src/ but on different functions than original finding → grep quality check needed)."
---

# Turn 52 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `audit-class-scan-2026-05-18-T50` — flow_template `audit-class-scan` (§F6), kind=meta, priority=20.
- **Stage transition**: **Triage → L3_critic_audit** (sub-stage within §F6's "L3 analogical derivation" safety rail: "Critic audits each proposal" against 4 questions). The Triage stage's mechanical batch is done (T51 PASS). The L3 proposal queue (LP-1 + LP-2 in `patterns.yaml::proposed_classes`) must be gated by critic BEFORE the Document stage closes the cycle. Per §F6: "Critic-rejected proposals are logged in patterns.yaml proposed_classes with the rejection reason; NOT added to active catalog. This is the safety rail against ungrounded self-reflection."
- **Tier ladder**: meta-investigation tier 0.7 (T51 Triage done) → 0.85 (T52 L3 critic-audit done; proposals either ACCEPT-promoted to active catalog or REJECT-with-rationale logged) → 1.0 at T53 Document closure.
- **Other in-flight investigations** (not picked this turn, by priority):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED at Tier 3.0.
  - `yan-li-saito-2026-reproduction` (priority 1): Document terminal, `next_stage = null`, partial-REFUTE landed at tier 0.4. No T52 action; awaits anko priority signal on R4 revival path.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): dormant; blocked on theorist Hypothesize re-design (existing eu151_klaus_phi_phys/ is rotating_basis, not lab-frame; not 1-turn-able). T53/T54 candidate after audit-class-scan cycle closes.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - `meta-critic-placement-2026-05-17` (priority 50): defer.
  - `meta-stage-routing-2026-05-18` (priority 25): defer.
- **Scheduler** (`scheduler_52.json`): policy=JULIA_GPU_OK, all workloads allowed, window 1,188,610s left (~13.7 days), VRAM 12,964 MB free, foreign julia=0. Critic dispatch is a `critic` workload (lowest-cost class) — well within budget.
- **Drift signals from T51 PASS**: per `judge/turn_51.json` no drift advisories serialized; T51 cleanly PASSED all 13 criteria. The AUDIT_DUE advisory from T42-T49 was serviced by T50-T51 sweep + Triage. No drift to address this turn.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T50 | Observe (audit-class-scan §F6) | FAIL_NO_METRICS (judge format failure) / Observe substantively COMPLETE | Researcher swept all 9 patterns; 5 WHAT-comments in topology.jl + 126 instances of `1e-30` literal across 41 files; 2 L3 proposals (LP-1, LP-2) drafted. |
| T51 | Triage | PASS (13/13 criteria) | topology.jl 5-comment cleanup applied; patterns.yaml 9× last_scanned + 1× audit_history row + 2× proposed_classes queued; hardcoded-magic-number director re-triage to no-action-rationalized. |
| (this turn) T52 | L3_critic_audit (sub-stage of Findings/Triage envelope per §F6 safety rail) | (TBD per dispatch) | Critic evaluates LP-1, LP-2 against 4-question §F6 rule; promotes/rejects with rationale. |

**Director pre-flight empirical anchor check** (this turn, before dispatch):

- **LP-1 grep** (`abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+`) run against `/home/suzume/workspace/BEC-simulation/src/`: **0 hits**. **This fails the §F6 "1-10000 hits" empirical anchor rule.** LP-1's proposed external_anchor expected "30-50 hits, all density/tolerance contexts, 0 coupling-gate deviations" — but the actual count is 0, indicating the regex is too narrow (probably because most `abs(...)` calls in coupling-gate sites are written as `abs(c0) > 1e-30` literally, matching the negative lookahead exclusion). The proposal's premise — that LP-1 is the "sibling-violation detector if a non-1e-30 threshold ever creeps into the coupling-gate sites specifically" — is correct in spirit but the grep cannot find anything because there are no deviations TO find. **LP-1 is structurally a "zero-currently-but-watchdog-for-future" pattern.** Per §F6's rule that detector hit count must be in [1, 10000], LP-1 fails. Critic should evaluate whether (a) reject LP-1, (b) accept it as a forward-looking watchdog with explicit rationale (deviation from the §F6 rule, requires director note), or (c) request researcher REVISE the grep to broaden the catch surface (e.g., to include `abs(c0) < 1e-30` AND `abs(c0) > 1e-30` AND alternative wordings).

- **LP-2 grep** (`#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)`) run against `/home/suzume/workspace/BEC-simulation/src/`: **5 hits, but on DIFFERENT files than topology.jl**:
  - `src/hamiltonian/integrator/combined_spin_step.jl:62` ("Compute spin density into bufs...")
  - `src/workflow/experiments/schema/parsing_blocks.jl:290` ("Normalise to internal fields...")
  - `src/solvers/lbfgs/driver.jl:87`, `:126`, `:203` ("Gradient-coverage guard", "Gradient at current psi...", "Gradient at new psi")
  
  None of these are in topology.jl (T51 already cleaned topology.jl). All 5 hits are in OTHER files. The grep IS detecting things, and 4 of 5 appear to be WHAT-comments (Gradient-at-X is the WHAT; the WHY is the algorithmic context). 1 of 5 (`combined_spin_step.jl:62` — "Compute spin density into bufs..., then if DDI is...") is a multi-line WHY-comment continuation. **LP-2 has empirical anchor in 1-10000 range AND finds real candidates.** It passes the §F6 rule and is also actionable: the catalog entry would trigger a future audit cycle (or T53 sibling-fix in the same audit cycle if anko prioritizes).

These director observations are FOR the critic to verify and adjudicate; the critic should NOT take the director's word — the critic re-runs the greps independently and writes the verdict.

## 3. Flow template recall

- **Template**: `audit-class-scan` (§F6).
- **Stage**: L3_critic_audit (the safety-rail sub-stage embedded in Findings/Triage envelope per §F6 explicit text: "Critic audits each proposal against: (1) Has a runnable grep_patterns or detect block? (2) Empirical check: running the grep produces between 1 and ~10000 hits? (3) Is the analogy concrete (not just 'feels similar')? (4) Sharp differentiation from existing catalog entries?").
- **Role**: **critic** (independent context per §F6 + director.md §F1 critic role). Critic re-runs greps independently and writes verdicts.
- **Why this stage NOW (not Document yet)**:
  - §F6 explicitly requires critic audit BEFORE proposals move from `proposed_classes` to active `patterns:`. Skipping this would violate the safety rail anko added 2026-05-18 ("the safety rail against ungrounded self-reflection").
  - Document stage closes the audit cycle. Closing it before critic audit would leave LP-1/LP-2 stuck in `proposed_classes` indefinitely with no resolution.
  - LP-1 specifically has an empirical anchor failure (0 hits) that the critic SHOULD catch — if the loop ran Document next without critic audit, this defect would silently accumulate.
  - Per `feedback_decision_style` single commitment per turn: T52 = critic L3 audit. T53 = Document close + (likely) pivot to klaus-bch-leak or noop.

## 4. Research grounding (§A6)

External / prior references applicable to this critic L3 audit dispatch:

1. **director.md §F6 L3 safety rail spec**: 4-question critic audit criteria + "Critic-rejected proposals are logged in patterns.yaml proposed_classes with the rejection reason; NOT added to active catalog. This is the safety rail against ungrounded self-reflection." — verbatim the contract.
2. **`runs/_loop/patterns.yaml::proposed_classes` LP-1 and LP-2** — the proposals being audited (verbatim YAML available in `runs/_loop/patterns.yaml` lines 176-210).
3. **`runs/_loop/research/turn_50_audit_class_scan.md`** — original proposal source with researcher's rationale.
4. **`runs/_loop/director/turn_51.md` §2 director re-triage** — pattern of director-level evidence-driven re-evaluation; critic should apply the same evidence-driven rigor (independent grep run + actual hit count).
5. **Memory `feedback_fix_the_class_not_the_instance.md`**: this whole audit-class-scan flow services the principle that a class-level finding deserves a class-level fix. Critic L3 audit is the quality gate that ensures the "class" is genuine before it enters the active catalog.
6. **Memory `feedback_mechanical_vs_investigation_threshold.md`** (anko 2026-05-18 3-second test): apply per proposal — "Could you describe this anti-pattern in 1 sentence? Is the detector grep-testable? Would a senior engineer say 'this is a real class'?"
7. **Memory `feedback_decision_style.md`**: single commitment per turn (T52 = critic-audit; T53 = Document or pivot).
8. **§A6 research-first patterns** — the loop's own meta-pattern of running an external verification step before accepting a self-generated artifact. The critic role IS the loop's reflection mechanism (per director.md §G LATS Reflect+Backprop analogue).
9. **Sample of T51 director's own §2 inspection of 1e-30 call sites** — the same evidence-driven approach the critic should apply to LP-1: actually run the grep, examine actual hits, judge concretely (not abstractly).
10. **CLAUDE.md `## Known limitations` section** — items by-design that any catalog entry must not capture as findings. Critic should verify LP-1/LP-2 wouldn't generate false-positive findings against by-design CLAUDE.md exclusions.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D3 SECONDARY** (loop-architecture quality gate: properly closing the L3 derivation safety rail validates the audit-class-scan flow itself as a usable tool). **Not D1** (no physics verification). **Not D2** (no implementation optimization). Manuscript NOT in scope.
- **Tier**: meta-investigation 0.7 → 0.85 (L3 audit done) → 1.0 at T53 Document.
- **Cost frame**: critic dispatch is the cheapest workload class (~1.3M effective baseline per recent turns); well under per-turn cap (6M) and rolling cap (100M).
- **Loop-quality leverage**: if LP-1 is silently promoted to active catalog despite 0 hits, the next audit cycle wastes effort scanning a dead pattern AND future researchers may treat "0 hits = pattern dormant-clean" as a positive signal when actually the regex is broken. Catching this early (now) is exactly what the safety rail exists for.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "audit-class-scan-2026-05-18-T50",
  "stage_advancing_to": "L3_critic_audit",
  "subagent_type": "critic",
  "rationale": "T51 Triage PASSED cleanly; LP-1 and LP-2 are queued in patterns.yaml::proposed_classes with status pending_critic_audit. Per §F6 safety rail, critic must adjudicate each proposal against 4 questions (runnable detector / 1-10000 hits / concrete analogy / sharp differentiation) before they enter the active catalog. Director pre-flight greps reveal LP-1 has 0 hits in src/ (fails the 1-10000 rule — too narrow, or correctly zero-as-watchdog?) while LP-2 has 5 hits in OTHER files than the original topology.jl finding (passes rule + finds real candidates). Critic independently verifies and writes verdict per proposal. Per `feedback_decision_style` single commitment: T52 = critic L3 audit; T53 = Document close (or revisions) per critic verdict.",
  "brief": "## ROLE\n\nYou are the critic subagent. L3 critic-audit sub-stage of `audit-class-scan-2026-05-18-T50` per director.md §F6 safety rail. Independently audit the 2 L3 proposals currently queued in `runs/_loop/patterns.yaml::proposed_classes` (status: pending_critic_audit). Produce per-proposal verdict (ACCEPT-TO-ACTIVE / REJECT-WITH-RATIONALE / REVISE-AND-RESUBMIT) backed by independent empirical verification.\n\n## CONTEXT\n\nT50 audit-class-scan §F6 Observe sweep found:\n- 5 WHAT-comments in `src/analysis/topology.jl` (cargo-cult-comment, mechanical-fix-now) — applied at T51.\n- 126 instances of `1e-30` literal across 41 files (hardcoded-magic-number) — director re-triaged as no-action-rationalized at T51 (semantic heterogeneity).\n- 2 L3 analogical proposals queued for your audit.\n\nT51 PASSED cleanly (13/13 success criteria). The audit cycle is now at the §F6 critic-audit safety rail. Per §F6 verbatim: \"Critic audits each proposal against: (1) Has a runnable grep_patterns or detect block? (2) Empirical check: running the grep produces between 1 and ~10000 hits (else: too narrow or too noisy)? (3) Is the analogy concrete (not just 'feels similar')? (4) Sharp differentiation from existing catalog entries?\" — these are the 4 questions you must answer per proposal.\n\nDirector ran preliminary greps (you must re-run independently). Director's preliminary findings:\n- LP-1 (`coupling-skip-gate-inconsistency`): 0 hits in src/. Fails the 1-10000 rule prima facie. Options: REJECT, or ACCEPT as forward-looking watchdog (deviation from §F6 rule, requires explicit rationale).\n- LP-2 (`topology-function-WHAT-comment-pattern`): 5 hits in 3 files, NOT in topology.jl (which T51 cleaned). Passes 1-10000 rule. Candidates appear real.\n\nYou must INDEPENDENTLY re-verify these counts. Director numbers are FYI not gospel.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml` lines 176-210 (the LP-1 and LP-2 entries verbatim).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_50_audit_class_scan.md` §4 (researcher's original rationale for LP-1 and LP-2; treat as input, not authority).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_52.md` §2 (this director report's pre-flight empirical check — for context, not authority; you re-verify).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml` lines 16-157 (the 9 active patterns; you check LP-1 and LP-2 for sharp differentiation against these).\n5. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` `## Known limitations` + `## Conventions (do NOT \"fix\")` sections (you check that LP-1 and LP-2 would NOT generate false-positives against documented by-design items).\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_mechanical_vs_investigation_threshold.md` (the 3-second test apply per proposal).\n\n## DELIVERABLE 1: Independent empirical verification (re-run greps)\n\nFor EACH of LP-1 and LP-2, independently run the proposal's grep_patterns against `/home/suzume/workspace/BEC-simulation/src/` using the Grep tool (NOT bash rg). Record:\n- Raw hit count\n- First 10 hits with file:line (more if surprising; less if 0)\n- Whether each hit is a TRUE-POSITIVE (matches the proposal's described class) vs FALSE-POSITIVE (caught by the regex but semantically different)\n- If 0 hits: is the proposal nonetheless useful as a forward-looking watchdog? Justify YES/NO.\n\nLP-1 grep verbatim: `abs\\([a-zA-Z_]\\w*\\)\\s*[><=]+\\s*1e-(?!30\\b)\\d+`\nLP-2 grep verbatim: `#\\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\\s+(the\\s+)?spin|Normalise?\\s+to)`\n\n## DELIVERABLE 2: 4-question audit per proposal\n\nFor EACH proposal, answer the 4 §F6 questions with explicit YES/NO + 1-2 sentence justification:\n\n**Q1: Has a runnable grep_patterns OR detect block?**\n- Confirm the proposal has executable detection, not vague description.\n\n**Q2: Empirical check: running the grep produces between 1 and ~10000 hits?**\n- If 0 hits: FAIL the rule unless the proposal explicitly waives this rule with director-approved rationale.\n- If >10000 hits: FAIL (too noisy).\n- If 1-10000 hits: PASS empirically.\n\n**Q3: Is the analogy concrete (not just 'feels similar')?**\n- LP-1 claims relation to `hardcoded-magic-number`. Verify the analogical link.\n- LP-2 claims relation to `cargo-cult-comment`. Verify the analogical link.\n- For each: is the proposal a sharp specialization, a true sibling, or a vague vibes-association?\n\n**Q4: Sharp differentiation from existing 9 catalog entries?**\n- For each, walk through the 9 active patterns (deprecated-name-leak, api-rename-stragglers, doc-staleness, hardcoded-magic-number, dead-export, large-file-bloat, test-mock-of-real, cargo-cult-comment, paper-unit-system-wrong-param-in-spot-check) and confirm the proposal is not a near-duplicate of any.\n\n## DELIVERABLE 3: Verdict per proposal\n\nOne of:\n\n- **ACCEPT-TO-ACTIVE**: all 4 questions PASS. The proposal moves from `proposed_classes` to active `patterns:`. T53 implementer applies the move (mechanical YAML edit).\n- **REJECT-WITH-RATIONALE**: 1+ questions FAIL with no fix path. Proposal stays in `proposed_classes` permanently with rejection_reason added; NOT added to active catalog. The proposal is dead.\n- **REVISE-AND-RESUBMIT**: 1+ questions FAIL but the underlying class is real and the proposal can be tightened/broadened to pass. State concrete revision (e.g., \"broaden regex to include `[<>]=?` variants AND add a second clause for `(c0|c1|c_dd|q|gamma_dr) [...] threshold` with threshold != 1e-30\"). Proposal stays in `proposed_classes` with status updated to `pending_revision`.\n\nFor LP-1 specifically, given the 0-hits empirical failure: consider whether the proposal's intent (forward-looking watchdog) is structurally incompatible with the §F6 1-10000 rule (which assumes a CURRENT class-level finding exists), and if so, recommend REJECT or RESUBMIT with broader scope.\n\n## DELIVERABLE 4: Audit report at `runs/_loop/judge/turn_52_critic_audit.md`\n\nMarkdown structure:\n\n```markdown\n---\nturn: 52\nsubagent: critic\ninvestigation_id: audit-class-scan-2026-05-18-T50\nstage: L3_critic_audit\nproposal_count: 2\nverdicts: { LP-1: \"ACCEPT-TO-ACTIVE | REJECT-WITH-RATIONALE | REVISE-AND-RESUBMIT\", LP-2: \"...\" }\n---\n\n# Turn 52 — L3 Critic Audit of patterns.yaml::proposed_classes\n\n## 1. Scope\n- Proposals audited: LP-1 (coupling-skip-gate-inconsistency), LP-2 (topology-function-WHAT-comment-pattern)\n- Audit basis: §F6 4-question safety rail\n- Independent re-verification performed (greps re-run, file:line evidence cited)\n\n## 2. LP-1: coupling-skip-gate-inconsistency\n\n### 2.1 Empirical re-verification\n... <grep hit count, first 10 hits or 'NONE', true-positive vs false-positive analysis> ...\n\n### 2.2 4-question audit\n- Q1 (runnable detector): YES/NO + justification\n- Q2 (1-10000 hits): YES/NO + justification\n- Q3 (concrete analogy to hardcoded-magic-number): YES/NO + justification\n- Q4 (sharp differentiation from 9 active patterns): YES/NO + justification\n\n### 2.3 Verdict\n<ACCEPT-TO-ACTIVE | REJECT-WITH-RATIONALE | REVISE-AND-RESUBMIT> + rationale paragraph.\n\n## 3. LP-2: topology-function-WHAT-comment-pattern\n\n... <symmetric structure> ...\n\n## 4. Summary\n- LP-1 verdict: ...\n- LP-2 verdict: ...\n- T53 implementer action required: ...\n\n## 5. Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"proposals_audited\": 2,\n  \"lp_1_grep_hit_count\": <integer>,\n  \"lp_1_q1_runnable_detector\": true | false,\n  \"lp_1_q2_in_range\": true | false,\n  \"lp_1_q3_concrete_analogy\": true | false,\n  \"lp_1_q4_sharp_differentiation\": true | false,\n  \"lp_1_verdict\": \"ACCEPT-TO-ACTIVE | REJECT-WITH-RATIONALE | REVISE-AND-RESUBMIT\",\n  \"lp_2_grep_hit_count\": <integer>,\n  \"lp_2_q1_runnable_detector\": true | false,\n  \"lp_2_q2_in_range\": true | false,\n  \"lp_2_q3_concrete_analogy\": true | false,\n  \"lp_2_q4_sharp_differentiation\": true | false,\n  \"lp_2_verdict\": \"ACCEPT-TO-ACTIVE | REJECT-WITH-RATIONALE | REVISE-AND-RESUBMIT\",\n  \"audit_report_present\": true,\n  \"src_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"investigation_id\": \"audit-class-scan-2026-05-18-T50\",\n  \"stage_advancing_to\": \"L3_critic_audit\",\n  \"flow_template\": \"audit-class-scan\"\n}\n```\n```\n\n## CONSTRAINTS\n\n- **DO NOT modify any file** other than creating `runs/_loop/judge/turn_52_critic_audit.md` and `runs/_loop/sim/turn_52.md` (the latter with §4 JSON metrics block for judge.py).\n- **DO NOT modify `src/`**.\n- **DO NOT modify `patterns.yaml`** — your verdict drives T53 implementer's YAML edits. You produce the audit report; implementer applies the resulting moves.\n- **DO NOT modify `state.json`**.\n- **Be evidence-driven**, not vibes-driven. Run the greps. Cite file:line. If you find the proposal's described class doesn't actually exist in the codebase, REJECT explicitly with the empirical evidence — that is the safety rail working as intended.\n- **English only**.\n- **No emojis**.\n- **Absolute paths in all tool invocations**.\n- **Stay within ~1.5M effective tokens, ~12 min wall**.\n\n## SUCCESS CRITERIA (judge.py evaluates sim/turn_52.md §4 metrics block)\n\nThe sim turn at `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_52.md` MUST contain a fenced ```json block (parseable by judge.py) with the metric keys in the observable_manifest below. Report HONESTLY: if LP-1 has 0 hits, write 0; if LP-2 has 7 hits, write 7. Do not round to the director's pre-flight number.\n\nDo NOT auto-commit. Per CLAUDE.md `## Code Artifacts: No auto-commits`.\n\nReport honestly. If a proposal cannot be definitively judged (e.g., the grep tool errored, or the proposal description is ambiguous), document the obstruction and choose the most defensible verdict given available evidence; tag in §5 metrics as `obstruction_encountered: true` for director awareness.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "proposals_audited",
      "lp_1_grep_hit_count",
      "lp_1_q1_runnable_detector",
      "lp_1_q2_in_range",
      "lp_1_q3_concrete_analogy",
      "lp_1_q4_sharp_differentiation",
      "lp_1_verdict",
      "lp_2_grep_hit_count",
      "lp_2_q1_runnable_detector",
      "lp_2_q2_in_range",
      "lp_2_q3_concrete_analogy",
      "lp_2_q4_sharp_differentiation",
      "lp_2_verdict",
      "audit_report_present",
      "src_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "investigation_id",
      "stage_advancing_to",
      "flow_template"
    ],
    "optional": ["obstruction_encountered", "verdict_summary"],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml && python3 -c \"import yaml; cat = yaml.safe_load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml')); pc = cat.get('proposed_classes', []); assert len(pc) == 2, f'expected 2 proposed_classes, got {len(pc)}'; ids = [p['id'] for p in pc]; assert 'coupling-skip-gate-inconsistency' in ids, 'LP-1 missing'; assert 'topology-function-WHAT-comment-pattern' in ids, 'LP-2 missing'; assert all(p.get('status') == 'pending_critic_audit' for p in pc), 'all proposed_classes must have status pending_critic_audit'\" && echo 'precondition OK: patterns.yaml has 2 proposed_classes (LP-1, LP-2) with status pending_critic_audit'"
  },
  "success_criteria": [
    {
      "id": "two_proposals_audited",
      "metric": "proposals_audited",
      "operator": "==",
      "value": 2,
      "tolerance": null,
      "rationale": "Both LP-1 and LP-2 must receive verdicts; no partial audit."
    },
    {
      "id": "lp_1_verdict_valid",
      "metric": "lp_1_verdict",
      "operator": "in",
      "value": ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"],
      "tolerance": null,
      "rationale": "LP-1 verdict must be one of the 3 allowed strings."
    },
    {
      "id": "lp_2_verdict_valid",
      "metric": "lp_2_verdict",
      "operator": "in",
      "value": ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"],
      "tolerance": null,
      "rationale": "LP-2 verdict must be one of the 3 allowed strings."
    },
    {
      "id": "lp_1_grep_evidence_provided",
      "metric": "lp_1_grep_hit_count",
      "operator": ">=",
      "value": 0,
      "tolerance": null,
      "rationale": "Critic must report an actual integer hit count (incl. 0 — that IS evidence). Negative values fail."
    },
    {
      "id": "lp_2_grep_evidence_provided",
      "metric": "lp_2_grep_hit_count",
      "operator": ">=",
      "value": 0,
      "tolerance": null,
      "rationale": "Same."
    },
    {
      "id": "lp_1_4q_answered",
      "metric": "lp_1_q1_runnable_detector",
      "operator": "in",
      "value": [true, false],
      "tolerance": null,
      "rationale": "Each of the 4 §F6 questions must receive boolean answer."
    },
    {
      "id": "audit_report_present_check",
      "metric": "audit_report_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "runs/_loop/judge/turn_52_critic_audit.md must exist."
    },
    {
      "id": "no_src_touch",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Critic audit is text-only; no src/ modifications."
    },
    {
      "id": "no_patterns_yaml_touch",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "T53 implementer applies YAML moves after critic verdict; critic does not edit catalog."
    },
    {
      "id": "no_state_json_touch",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Director updates state.json post-PASS."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "audit-class-scan-2026-05-18-T50",
      "tolerance": null,
      "rationale": "Investigation continuity."
    },
    {
      "id": "stage_l3_critic",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "L3_critic_audit",
      "tolerance": null,
      "rationale": "Sub-stage per §F6 safety rail."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "audit-class-scan",
      "tolerance": null,
      "rationale": "Template consistency."
    }
  ],
  "failure_modes": [
    {
      "if": "lp_1_verdict not in allowed_strings OR lp_2_verdict not in allowed_strings",
      "category": "operational",
      "next_action": "T53 director = re-dispatch critic with explicit string enforcement. Acceptable verdicts: ACCEPT-TO-ACTIVE, REJECT-WITH-RATIONALE, REVISE-AND-RESUBMIT (case-sensitive)."
    },
    {
      "if": "audit_report_present == false",
      "category": "operational",
      "next_action": "T53 director = re-dispatch critic with explicit Write requirement for runs/_loop/judge/turn_52_critic_audit.md."
    },
    {
      "if": "src_files_modified > 0 OR patterns_yaml_modified == true OR state_json_modified == true",
      "category": "scope_violation",
      "next_action": "T53 director = revert any extraneous modifications via `git restore`. Critic must produce text reports only; YAML edits + state.json updates are T53 implementer + director responsibilities."
    },
    {
      "if": "lp_1_verdict == 'ACCEPT-TO-ACTIVE' AND lp_1_grep_hit_count == 0",
      "category": "scientific_red_flag",
      "next_action": "T53 director = scrutinize the critic's rationale. §F6 1-10000 rule was supposed to fail LP-1 at 0 hits. If critic accepts anyway, the rationale must explicitly invoke the 'forward-looking watchdog' deviation with director sign-off. If critic simply ignored the rule, treat as critic mistake — re-dispatch with §F6 rule enforcement."
    },
    {
      "if": "lp_1_verdict == 'REJECT-WITH-RATIONALE' AND lp_2_verdict == 'ACCEPT-TO-ACTIVE'",
      "category": "scientific_success",
      "next_action": "T53 director = dispatch implementer_text to (a) move LP-2 from proposed_classes to active patterns list in patterns.yaml; (b) add rejection_reason field to LP-1 entry with critic's rationale; (c) close audit-class-scan-2026-05-18-T50 cycle via Document stage (tier 0.85 → 1.0); (d) update state.json: add audit-class-scan-2026-05-18-T50 to investigations_index, set current_stage = closed, tier_current = 1.0. Then T54 = pivot to klaus-bch-leak Hypothesize OR noop per scheduler + priority signal."
    },
    {
      "if": "lp_1_verdict == 'ACCEPT-TO-ACTIVE' AND lp_2_verdict == 'ACCEPT-TO-ACTIVE'",
      "category": "scientific_success",
      "next_action": "T53 director = dispatch implementer_text to move both LP-1 and LP-2 from proposed_classes to active patterns list; close audit-class-scan-2026-05-18-T50 cycle via Document stage. Same state.json update. (This branch is unlikely given LP-1's empirical-anchor failure.)"
    },
    {
      "if": "lp_1_verdict == 'REJECT-WITH-RATIONALE' AND lp_2_verdict == 'REJECT-WITH-RATIONALE'",
      "category": "scientific_success_low_value",
      "next_action": "T53 director = dispatch implementer_text to add rejection_reason fields to both LP-1 and LP-2 entries; close audit-class-scan-2026-05-18-T50 cycle via Document stage. Audit catalog gains no new entries but the safety rail correctly filtered noise. Lesson: future audit-class-scan flows should encourage researcher to gate-check grep counts before proposing."
    },
    {
      "if": "either lp_1_verdict or lp_2_verdict == 'REVISE-AND-RESUBMIT'",
      "category": "scientific_partial_progress",
      "next_action": "T53 director = dispatch implementer_text to update the revising proposal's status to 'pending_revision' with critic's revision notes attached; close audit-class-scan-2026-05-18-T50 cycle via Document stage with the revision queued for a future audit cycle. Do NOT spawn an immediate revision turn — the proposal can wait for the next ~10-turn audit boundary OR an anko-explicit prioritization."
    },
    {
      "if": "obstruction_encountered == true",
      "category": "data_gap",
      "next_action": "T53 director = read critic's §6 obstruction notes; if grep tool errored, re-run greps via director's own Grep tool and supply numbers to critic re-dispatch; if proposal description was ambiguous, decide whether the proposal stays REJECTED on ambiguity grounds or REVISE-AND-RESUBMIT with clarification request."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 1800000,
    "wall_time_hard_cap_sec": 900
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 540,
    "split_by_subtask": {
      "read_proposals_and_research_artifact": 300000,
      "independent_grep_lp1": 200000,
      "independent_grep_lp2": 200000,
      "4q_audit_per_proposal": 350000,
      "write_audit_report_and_sim_metrics": 250000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document (T53 — close audit-class-scan cycle, tier 0.85 → 1.0; implementer_text applies critic-verdict-driven YAML moves: move ACCEPT verdicts from proposed_classes to active patterns; add rejection_reason to REJECT verdicts; update status to pending_revision for REVISE verdicts; update state.json adding audit-class-scan-2026-05-18-T50 to investigations_index with current_stage=closed, tier_current=1.0). Then T54 = pivot to klaus-bch-leak Hypothesize OR noop per anko priority signal.",
    "if_success_tier_becomes": 0.85,
    "if_refuted_advance_to_stage": "N/A — L3 critic audit is gating, not falsifying. Operational failure (e.g., verdict string invalid) routes to T53 critic re-dispatch with stricter contract.",
    "if_refuted_tier_becomes": "N/A",
    "next_falsifier_to_test_after": "N/A — meta-investigation; T53 = Document + state.json close-out; T54+ = next investigation."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_52.json` (policy=JULIA_GPU_OK; `critic` in allowed_workloads; window 1,188,610s left; VRAM 12,964 MB free; foreign julia=0).
- [x] Read `runs/_loop/state.json` end-to-end (audit-class-scan-2026-05-18-T50 is active; not yet in investigations_index — T53 director will add it on Document close; yan-li-saito Document terminal tier 0.4; klaus-bch-leak documented dormant; barnett CLOSED Tier 3.0).
- [x] Read `runs/_loop/seed.md` (priority order unchanged; manuscript OUT).
- [x] Read `runs/_loop/director/turn_51.md` end-to-end (T51 Triage PASS; success-path failure_modes explicitly routed T52 to critic L3 audit for LP-1+LP-2).
- [x] Read `runs/_loop/sim/turn_51.md` (T51 PASS deliverables confirmed; 2 commit messages drafted, no auto-commit; patterns.yaml updated with 2 proposed_classes at status pending_critic_audit).
- [x] Read `runs/_loop/judge/turn_51.json` (PASS verdict; all 13 success criteria passed).
- [x] Read `runs/_loop/patterns.yaml` end-to-end (9 active patterns; 2 proposed_classes at pending_critic_audit; 3 audit_history rows including T50 sweep summary; LP-1 and LP-2 verbatim per researcher proposals).
- [x] Read `runs/_loop/research/turn_50_audit_class_scan.md` first 100 lines (researcher's per-pattern findings + L3 proposals rationale).
- [x] Read `runs/_loop/director/turn_50.md` first 100 lines (continuity context).
- [x] Pre-flight greps run via Grep tool: LP-1 returned 0 hits; LP-2 returned 5 hits in 3 files (combined_spin_step.jl, parsing_blocks.jl, lbfgs/driver.jl). These are FYI for critic, not authoritative.
- [x] Read memory `feedback_fix_the_class_not_the_instance.md` (3-second test; L3 proposals' raison d'être).
- [x] Read memory `feedback_mechanical_vs_investigation_threshold.md` (per-proposal triage rule).
- [x] Read memory `feedback_decision_style.md` (single commitment per turn: T52 = critic L3 audit, NOT Document yet).
- [x] investigation_id `audit-class-scan-2026-05-18-T50` consistent across T50/T51/T52.
- [x] stage_advancing_to `L3_critic_audit` is the §F6 safety rail sub-stage between Triage and Document.
- [x] subagent_type `critic` matches §F6 "Critic audits each proposal" verbatim.
- [x] success_criteria 13 criteria, all machine-evaluable (booleans, integer counts, strings-in-allowed-set).
- [x] failure_modes cover 9 likely outcomes including all 4 verdict-pair branches + edge cases (scope violation, scientific red flag, obstruction).
- [x] observable_manifest precondition_check is concrete python YAML assertion (verifies patterns.yaml has 2 proposed_classes at status pending_critic_audit before critic dispatches).
- [x] budget 1.3M expected, 1.8M tolerance; well within per-turn cap (6M) and scheduler window. Wall 9 min < 900s hard cap.
- [x] §A6 research-first citation present (10 references: §F6 spec verbatim, patterns.yaml LP-1/LP-2 entries, researcher proposal, T51 director re-triage precedent, memories, CLAUDE.md exclusions, LATS Reflect+Backprop analogue).
- [x] §A5 D3 SECONDARY (loop-architecture quality gate via L3 safety rail). Not D1, not D2. Manuscript NOT primary.
- [x] Considered switching investigations: yan-li-saito (no R4 signal; Document terminal); klaus-bch-leak (still needs theorist re-Hypothesize, not 1-turn-able; better to first close audit cycle); meta-* (defer post-audit). Audit-class-scan L3 critic audit is the natural §F6 continuation, single-turn-able, low-cost (~1.3M), high-information (gates whether 2 L3 proposals enter active catalog).
- [x] All file paths in brief are absolute.
- [x] Brief explicitly instructs critic to INDEPENDENTLY re-run greps (not take director's pre-flight numbers as authoritative).
- [x] Brief covers all 4 verdict-pair branches in success_criteria + failure_modes so T53 routing is pre-decided.
- [x] sim/turn_52.md §4 JSON metrics block requirement specified to prevent T50's FAIL_NO_METRICS failure mode from recurring.
- [x] No conventional commits drafted this turn (critic audit produces report only; no code/YAML changes).
- [x] T53 routing pre-planned for each verdict-pair in `if_success_advance_to_stage`.
