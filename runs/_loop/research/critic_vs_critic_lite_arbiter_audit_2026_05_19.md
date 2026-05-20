---
date: 2026-05-19
audit: arbiter-framework-pairwise-interference
targets:
  - .claude/agents/critic.md (Sonnet 4.6, 136 lines)
  - .claude/agents/critic_lite.md (Haiku 4.5, 96 lines)
auditor: critic (Mode 3 — adversarial prompt audit)
framework: arXiv:2603.08993
---

# Arbiter audit — critic.md × critic_lite.md pairing (post-split 2026-05-19)

## §1 Direct answers to items 1–5

### Item 1 — Scope overlap (claimed-by-both checks)

| Pair | critic.md | critic_lite.md | Verdict |
|---|---|---|---|
| Conclusions-index redundancy | **B7** L69–72 ("Re-derivation waste → PASS_REDUNDANT") | **C5** L52 ("jaccard ≥ 0.6 → PASS_REDUNDANT_CANDIDATE for critic.md to confirm") | **OVERLAP, soft-resolved.** lite emits *CANDIDATE*, full critic confirms. Workable IF director enforces sequential dispatch. |
| Schema check on §5 Metrics | **B1** L53 ("§1 Directive and §4 Metrics describe same experiment") | **C2/C3** L46–48 ("parse §5 Metrics JSON; observable_manifest fields present") | **OVERLAP, weak.** B1 is *semantic* consistency (directive ↔ metrics); C2/C3 is *syntactic* (parseable JSON, keys exist). Different layer but both touch §5. Ambiguity: an `experiment_kind` mismatch ('order test' vs `analyze_existing`) — who flags? Both can. |
| Falsifier coverage | **B2** L55 ("falsifier actually testable from metrics") | **C7** L57 ("§8 mentions each falsifier ID with TESTED/...") | **OVERLAP, complementary.** C7 = format check (ID present); B2 = substantive (testability). No conflict but neither agent's prompt says so. |

**Section 5 mismatch.** critic.md B1 cites "§4 Metrics"; critic_lite C2 cites "§5 Metrics". implementer.md L75–84 ('Sim report schema (strict)') confirms the schema uses §5 — **critic.md B1 has a stale section number**. Independent bug, surfaced by this audit.

### Item 2 — ESCALATE_TO_CRITIC contract

critic_lite L73 emits `verdict: ESCALATE_TO_CRITIC` when physics is needed. critic.md's **Inputs to read** table (L14–22) **does NOT list `critic/turn_${N}_lite.md`**. critic.md L118 ("Independent context: do NOT cite prior critic turns") *forbids* reading it.

So critic.md, when dispatched after an ESCALATE, has no formal channel to know critic_lite already ran. It re-does C1–C7 inline as part of B1/B7 (wasteful) or skips them (gap). **No explicit dispatch-marker contract.** director.md L109 says "dispatch critic.md when critic_lite returns PASS or ESCALATE_TO_CRITIC" — but the §6 brief never carries that signal to critic.md itself. **HIGH-severity gap.**

### Item 3 — Precedence under conflict (PASS_REDUNDANT_CANDIDATE vs PASS)

- critic.md L136: "CLAUDE.md Conventions > §6 contract > this prompt."
- critic_lite L96: "critic.md (Sonnet, physics judgment) wins for physics calls; critic_lite wins for schema/redundancy detection."

If lite says `PASS_REDUNDANT_CANDIDATE` and critic.md says `PASS` (non-redundant), per critic_lite's own precedence rule **lite wins on redundancy**. But critic.md L70 is the *full* PASS_REDUNDANT logic and is on Sonnet. So lite's "I win on redundancy" actually overrides Sonnet's deeper read. **This is backwards** — the cheap agent gets veto on its own domain. **MEDIUM.** No merge rule in director.md L96–109.

### Item 4 — Independent-context vs sequential dispatch

director.md L109 mandates **sequential**: lite → (conditional) critic. critic.md L118: "do NOT cite prior critic turns in this investigation (you should reach the same verdict from the data alone)."

**Direct contradiction.** Sequential dispatch creates a prior critic-class turn whose verdict drives whether critic.md is even invoked. If critic.md must reach the verdict "from data alone", then conditioning its invocation on lite's verdict is selection bias: critic.md will systematically miss the `FAIL_SCHEMA` cases (it's never dispatched on them) and will be over-represented on `ESCALATE_TO_CRITIC` cases. Stratified sampling. **HIGH-severity.** Either drop "independent context" or drop sequential gating; can't have both.

### Item 5 — Tool-grant + PASS-meaning ambiguity

Tools identical (`Read, Grep, Glob`) — no risk. But:
- critic.md L10: "PASS is the default only when all checks clear."
- critic_lite L73: `verdict: PASS` ≡ all of C1–C7 passed (schema only).

director.md / loop.sh has no documented rule saying "lite PASS ≠ turn PASS, must still dispatch critic.md unless skipped intentionally." A naive implementation of director.md L109 ("dispatch critic.md when lite returns PASS") could be read as **optional**, allowing the loop to advance on lite-PASS alone. **MEDIUM-severity ambiguity.**

## §2 NEW interference pairs (≥5)

**N1 (HIGH).** critic.md B7 reads `runs/_loop/conclusions/<inv_id>.md`; critic_lite C5 reads the same file. Both compute redundancy independently. **Risk:** lite uses Jaccard ≥ 0.6 (mechanical tokens); critic.md uses semantic judgment. They will disagree on borderline cases. No tie-breaker.

**N2 (HIGH).** critic.md L117 ("No `Write` outside `runs/_loop/critic/turn_${N}.md`") and critic_lite L60 (writes `runs/_loop/critic/turn_${N}_lite.md`). **Both write under `runs/_loop/critic/`.** If a downstream tool greps `runs/_loop/critic/turn_${N}*` for "the critic verdict", it will find two files. No spec says which is canonical. judge.py likely needs an update or it will pick whichever sorts first.

**N3 (MEDIUM).** critic.md offers three modes (L27–47: Mode 1 investigation_update, Mode 2 question_validity, Mode 3 adversarial_prompt). critic_lite has no `mode` field — only `mode: schema_check` is hard-coded (L66). If director dispatches lite for a **Mode 2 question-validity** turn, lite has no rubric → must emit ESCALATE → wasted Haiku call. director.md L96 table doesn't address Modes 2/3.

**N4 (MEDIUM).** Anchor drift on "PASS_REDUNDANT" naming. critic.md L70/L94 uses `PASS_REDUNDANT`. critic_lite L73 uses `PASS_REDUNDANT_CANDIDATE`. Two distinct enum values — downstream consumers (conclusions_index updater, judge.py) need to handle both, and the rules for promotion (CANDIDATE → confirmed) are unstated.

**N5 (MEDIUM).** critic.md L74 (B8 Tier-3 central falsifier) is **not** in critic_lite. If an investigation has `if_success_tier_becomes ≥ 3.0` and director routes only critic_lite (because schema-check shape), the Tier-3 gate is silently skipped — judge.py clamps to 2.75, but critic.md was supposed to "call this out explicitly". Routing rule absent.

**N6 (LOW).** critic.md L117 forbids `Bash`; critic_lite has no Bash listing either (L4). Both safe, but C6 ("Verify each path exists via Glob") at L55 in critic_lite — Glob can fail silently on non-glob-pattern strings. The path-existence check is weaker than critic.md's implicit check via Read.

**N7 (LOW).** critic.md L132 ("AI Scientist v1 reference") cites NeurIPS THOUGHT/REVIEW JSON pattern. critic_lite L70 (compact JSON) does **not** carry THOUGHT field. If anyone iterates the format upstream from AI Scientist, the two will drift.

**N8 (LOW, latent).** critic.md L22 reads `memory/feedback_*.md`; critic_lite does not. If anko's feedback file says "stop emitting PASS_REDUNDANT for X-class claims", lite won't know.

## §3 Severity tally

- HIGH: Item 2 (ESCALATE contract gap), Item 4 (independent-context contradiction), N1 (dual redundancy compute), N2 (output-path collision under `runs/_loop/critic/`). **= 4**
- MEDIUM: Item 1 (B1 vs C2/C3 §4 vs §5 + B7 vs C5), Item 3 (precedence under conflict), Item 5 (lite-PASS as turn-PASS), N3 (modes not routed), N4 (enum drift), N5 (Tier-3 gate skip). **= 6**
- LOW: N6, N7, N8. **= 3**

**Total: 13 interferences.**

## §4 Overall vs v2 director's 8-baseline

The v2 director.md self-audit (turn_69-class) found 8 interferences inside one agent file. The new critic+critic_lite **pair** has **13** — net +5. Most of the increase is structural: introducing a second agent in the same role-slot doubles the surface area for verdict-namespace overlap (N2, N4), context-isolation rules (Item 4), and routing tables (N3, N5). The split *saved* tokens on the C1–C7 axis but *created* coordination debt.

## §5 Recommendation

**Surgical patch (not ship-as-is, not merge).**

Five edits, ranked by severity:

1. **(HIGH, Item 4 + N2)** critic.md L118: replace "do NOT cite prior critic turns" with "do NOT cite prior critic.md turns in this investigation; critic_lite mechanical-check output MAY be cited as input (it is not a verdict on the same domain)." And rename lite output to `runs/_loop/critic_lite/turn_${N}.md` to fix N2 path collision.
2. **(HIGH, Item 2)** Add `runs/_loop/critic_lite/turn_${N}.md` to critic.md Inputs-to-read table (L14–22) with note "skim for schema-FAIL summary; do not inherit verdict."
3. **(MEDIUM, Item 1 section-number bug)** critic.md B1 L53: replace "§4 Metrics" with "§5 Metrics" to match implementer.md schema.
4. **(MEDIUM, Item 3 + N4)** director.md L96 table: add a merge row — "If lite emits `PASS_REDUNDANT_CANDIDATE` AND critic.md emits `PASS`, final verdict = `PASS_REDUNDANT` (lite wins on its own domain)." Promote `PASS_REDUNDANT_CANDIDATE` → `PASS_REDUNDANT` as deterministic.
5. **(MEDIUM, N5 + N3)** director.md L96 table: add an explicit rule "Tier-3 investigations (if_success_tier_becomes ≥ 3.0) and Mode 2/3 turns dispatch critic.md directly, skip critic_lite." Block lite from being the sole auditor on load-bearing turns.

Cost: 5 edits across 2 files, all under 10 lines each. No agent rewrite. No merge. After patch, expect interference count to drop from 13 → ~5 (Item 5, N6, N7, N8, plus residual semantic-vs-syntactic §5 overlap which is acceptable defense-in-depth).

**Do NOT merge agents.** The Haiku/Sonnet cost split is real (per L98 quota incident) and the C1–C7 mechanical work genuinely doesn't need Sonnet. Merge would re-inflate token cost without solving the actual interference set, which is coordination-layer not capability-layer.

**Verdict on the split itself:** ARBITER_FAIL pending the 5-edit patch above. Re-audit after edits; expect ARBITER_PASS.
