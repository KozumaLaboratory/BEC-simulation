---
turn: 48
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Update
stage_advancing_to: Research
topic_tags: [yan-li-saito-2026, normalization-audit, D0-discrepancy-152x, paper-vs-framework-units, fix-the-class-not-the-instance, cheap-text-discriminator, drift-address]
paper_section: null
depends_on: [47, 46, 45, "runs/_loop/judge/turn_47_critic_audit.md", "runs/_loop/sim/turn_46.md", "runs/_loop/judge/turn_45_critic_audit.md", "runs/_loop/director/turn_47.md", "runs/_loop/_local/scheduler_48.json", "runs/_loop/state.json", "runs/_loop/seed.md", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_mathematical_elegance_bias"]
produces: "researcher/implementer_text artifact at runs/yan_li_saito_f1_grid_refinement/normalization_audit.md: paper D₀ formula traced from Eq 1, framework D0_factor=2990.1 derivation traced from rotating_basis source, root-cause of 152× discrepancy identified, revised n_max comparison table in consistent units (paper vs T40 P4, T44, T46), tier revision recommendation for T49."
---

# Turn 48 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.70 → 0.60 per T47 critic §F).
- **Stage transition**: **Update → Research** per §F1 verify-claim template. T47 critic Update committed to Option 3 (Normalization audit) as the §E single routing recommendation. Per verify-claim, this is a back-to-Research side-step (the existing hypothesis & falsifier framework cannot be re-Hypothesized until the units are reconciled — any next Hypothesize would inherit the 152× D₀ ambiguity).
- **Tier**: 0.70 → 0.60 (committed at T47 §F). T49 will revise to 0.40 (paper not reproducible) or 0.80 (revival via unit correction) depending on §D resolution.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: CLOSED at Tier 3.0.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): still blocked on julia P3 validation; not picked because (a) yan-li-saito is open with a cheap-text bottleneck at exactly this point; (b) per `feedback_mathematical_elegance_bias`, finish the cheap text-audit before opening a parallel front.
  - `meta-critic-placement-2026-05-17` (priority 50, kind=meta, Observe): defer.
  - `meta-stage-routing-2026-05-18` (priority 25, kind=meta, Observe, auto-spawned T44): now has STRONG re-framing evidence from T47 critic §5 — the genuine meta-target is judge.py contract-flattening, NOT stage routing. Defer to a dedicated meta turn after the cascade closes; re-framing will be cleaner once we have the post-audit data.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED 2026-05-18 via direct mechanical execute per `feedback_mechanical_vs_investigation_threshold`. No action.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
- **Drift signals from T47** (`advisory` only, NOT director_must_address — T47 was a critic audit; drift advisories: `DRIFT_MANUSCRIPT_DELTA_ZERO`, `AUDIT_DUE: patterns.yaml gap=47`).
  - `topic_repetition=0.455`, `verdict_drift=0.5`, `cost_inflation=0.99` — all sub-threshold.
  - `AUDIT_DUE` is real (T47's predecessor T46 was at gap=46; now 47) — explicit T49 commitment below.
  - Manuscript-zero is policy-compliant per `feedback_manuscript_is_not_the_essence`.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T45 Update (critic) | Update | CRITIC PASS | §A UNDETERMINED-NEED-EXTENDED-RUN; §C LHY-LOOKS-OK (Petrov branch); §E R2_c-extend-itp routing; §F tier 0.75→0.70. |
| T46 Execute (implementer_julia_gpu) | Execute | INCONCLUSIVE (UNDETERMINED_R2c) | +12500 ITP steps from T44 jld2: m_0 evacuated 0.250→0.003 (hypothesis (iii) CONFIRMED), n_max FELL 3.09→1.91 D₀, μ plateaued 0.147→0.146. Implementer §5: "Mermin-Ho (0.5, 0, 0.5) IS the fine-grid equilibrium, NOT a self-bound droplet." §8 recommended T47 = theorist+implementer R3 (128³ box=8 dx=0.0625). |
| T47 Update (critic) | Update | CRITIC PASS | §A CORROBORATE-PLATEAU, §B CORROBORATE-DELOCALIZED-EQUILIBRIUM-IS-GRID-INDEPENDENT (T40 P4 sibling-instance), §C REFUTE-R3-AS-NEXT-STEP (R3 narrows dx-gap from ~9× to ~4.6×, but §B sibling-class evidence at 3.5× dx-span shows equilibrium is grid-independent), **§D FLAG-NORMALIZATION-DISCREPANCY (D₀ formula spot-check yields paper 3.43 μm⁻³ vs first-principles 0.0226 μm⁻³ = 152× ratio)**, §E committed Option 3 = Normalization audit (text-only, ~1.5M, highest cost-per-bit), §F tier 0.70 → 0.60. Also flagged class-pattern candidate `fine-and-coarse-grid-both-converge-to-Mermin-Ho-delocalized-not-self-bound-droplet` (supersedes T45 candidate). Meta-data point §5: T46 is FOURTH instance in 5 turns of judge-contract-flattening artifact. |

**Key observation from T47 (decisive for T48 dispatch)**: T47 critic explicitly committed to Option 3 single-routing per `feedback_decision_style`. The 152× D₀ discrepancy is a **binary discriminator**: if our framework's D₀ is wrong by 152×, then T46's "n_max=1.91 D₀" might actually be "n_max≈290 D₀" in paper units — closer to the paper anchor 13000 D₀ — and the entire "delocalized vs self-bound" classification across T37/T40/T43/T44/T46 would need re-interpretation. Conversely, if the discrepancy is in the paper memory transcription, our framework D₀ is correct and the delocalized verdict stands. Until this binary is resolved, ANY further Execute spend (R3, R4, F64-spot-check, match-paper-grid) wastes tokens on an interpretation that may be off by 2 orders of magnitude. T48 = T47's committed Option 3 = normalization audit. No deviation.

## 3. Flow template recall

- **Template**: `verify-claim`.
- **Stage rule**: T47 was Update. The mandatory critic Update has occurred; verdict was CORROBORATE-with-routing-recommendation. The natural template progression after Update is Document (if confirming) or back to Hypothesize (if refuted). T47 critic committed to neither — it committed to a Research-class side-step (Option 3 normalization audit) because the necessary pre-condition for any next Hypothesize (knowing whether n_max is 1.91 or 290 in comparable units) is currently broken. Per §F1 the legitimate move is to re-enter **Research** for the unit reconciliation, then re-Hypothesize at T49 with corrected units. This is NOT a stage-skip — it is the correct verify-claim response to "Update surfaced a load-bearing data-integrity question."
- **Role for stage Research**: **researcher** primarily (lit/paper reading + framework source tracing); could be **implementer_text** if framing the task as "trace source, write artifact." Per the deliverable (a markdown artifact at `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md` containing paper Eq 1 verbatim + our D0_factor source trace + numerical reconciliation), this is a hybrid task. Scheduler allows BOTH `researcher` and `implementer_text`. Per the natural primary action (re-read paper + grep codebase + write report), `researcher` is the cleaner fit: researcher is the lit/source-reading role; implementer_text is for committing finalized memory entries. The artifact is the AUDIT, not the memory entry — memory comes at T49+ Document.
- **Why researcher NOW**:

  **Why not advance to theorist Hypothesize for a new falsifier**:
  - T47 critic explicitly REJECTED multi-path advance per `feedback_decision_style` single-commitment. Any new Hypothesize without first resolving §D inherits 152× ambiguity in n_max threshold.
  - Per `feedback_fix_the_class_not_the_instance`, a unit bug (if real) is a CLASS-level issue affecting EVERY yan-li-saito run, not just T46. Hypothesizing without fixing the class wastes T49+.

  **Why not implementer_julia_gpu R3 (per T46 §8)**:
  - T47 critic §C explicitly REFUTED R3 as next step (~5-10M cost, equilibrium-class evidence argues null result, AND units still ambiguous so even a R3 PASS would be unreadable).

  **Why not switch to klaus-bch-leak (priority 3)**:
  - Lower priority; loses cascade context at exactly the cheap-bottleneck.

  **Why not audit-class-scan (AUDIT_DUE gap=47)**:
  - Legitimate signal. Explicit T49 commitment (if T48 audit completes cleanly, T49 = audit-class-scan IF tier-decision is clear; ELSE T49 = re-Hypothesize-with-corrected-units and T50 = audit-class-scan). Either way, AUDIT_DUE addressed within 2 turns.

  **Why not noop**:
  - T47 critic committed Option 3 with specific deliverable + cost estimate (~1.5M / 10-20 min). Executing it is the literal next step in template.

  **Why researcher (not implementer_text) is primary**:
  - The primary load-bearing action is reading + reconciling: (a) paper Eq 1 verbatim from `/tmp/yan_li_saito_2605.11670.pdf`, (b) memory `yan_li_saito_2026_barnett_paper.md` line 56-63 normalization claims, (c) source trace of `D0_factor_used=2990.1` in framework code (where it's set in our config or computed in framework). This is lit+source reading = researcher's job.
  - implementer_text could finalize the audit-markdown, but the audit IS the deliverable. No code change is being made at T48. researcher's output IS an `.md` file at `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md` (a research artifact, not a memory entry — memory entry at T49+ Document if applicable).

## 4. Research grounding (§A6)

External references for this Research dispatch:

1. **`runs/_loop/judge/turn_47_critic_audit.md` §D + §E + §3** (T47 critic's full quantitative §D discrepancy derivation; §3 lists 5 specific open questions for the audit; §E commits Option 3 with success criterion). This T48 dispatch executes T47's committed routing verbatim.

2. **Paper arXiv:2605.11670v1, Eq 1 (full Hamiltonian) + Normalization section** (per memory line 56-63: L₀ = a_s N, T₀ = M a_s² N²/ℏ, D₀ = 1/(a_s³ N²), B₀ = ℏ²/(M a_s² N² gμ_B); anchor "L₀=16.35 μm, T₀=0.64s, D₀=3.43 μm⁻³, B₀=0.2 μG" for Eu-151 F=1 N=15000 ε_dd=1.2). PDF local copy at `/tmp/yan_li_saito_2605.11670.pdf` per memory.

3. **Memory `yan_li_saito_2026_barnett_paper.md` lines 56-100**: declares normalization formulas AND anchor numbers; T47 critic's §D worked from this memory. T48 researcher must verify memory transcription against the PDF.

4. **T47 critic §D candidate root causes** (a)/(b)/(c):
   - (a) `a_s` in paper's D₀ might be NORMALIZED (a_s/a_ho), not SI.
   - (b) Paper's D₀ might use a different physical length scale (a_dd? hybrid?).
   - (c) Our `D0_factor_used=2990.1` is internally consistent but uses a different convention than paper's μ⁻³ unit.
   T48 researcher must test each.

5. **T40 §5 hint** (per T47 critic §3 open question 2): `D₀ factor = 2990.1 (n_max [D₀] = n_max_dimless × 2990.1)` with `D₀_factor_formula = "N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3"`. **This is the codebase-side D₀ formula** — must be traced to whichever script sets it (one of `runs/yan_li_saito_f1_grid_refinement/run_R*.jl`).

6. **Memory `feedback_fix_the_class_not_the_instance.md`** (anko 2026-05-18): when ONE instance of a unit-bug class surfaces, grep the codebase for siblings. T48 researcher must grep for `D0`, `D_0`, `D0_factor`, `a_s`, normalized-density across `runs/yan_li_saito*/`, `runs/eu151_klaus_*/`, `src/`. If a unit-consistency bug exists, it likely affects MORE than just yan-li-saito.

7. **Memory `feedback_mathematical_elegance_bias.md`**: cheap-fixes-first. T48 normalization audit IS the cheap fix; it must NOT expand into a unit-system refactor at T48 (audit only; fix at T49+ if needed).

8. **`runs/_loop/director/turn_47.md` §6 dispatch contract + failure_modes**: explicitly anticipated this branch: failure_mode "critic §D FLAGs normalization discrepancy → T48 = implementer_text (cheap) audit of D0_factor + paper normalization formulas". T48 executes that failure_mode-path directive.

9. **`runs/_loop/sim/turn_40.md` §5 metrics + P4 row, `runs/_loop/sim/turn_43.md` §4 metrics, `runs/_loop/sim/turn_44.md` §4 metrics, `runs/_loop/sim/turn_46.md` §4 metrics**: ALL report n_max in D₀ units using `D0_factor_used=2990.1`. After audit, these MUST be re-interpreted in a consistent comparison table (T47 critic §3 open question 4).

10. **CLAUDE.md "Dimensionless units: ℏ=m=ω_ref=1"** + "Mixed precision (rotating_basis only)" section: confirms a_ho normalization convention used in framework — relevant for testing T47 §D candidate (a) (whether paper's a_s is normalized vs SI).

11. **`src/foundation/` (or wherever D₀/D_0 is computed)**: T48 researcher must grep + read the canonical source.

12. **`runs/_loop/patterns.yaml`** + drift signal `AUDIT_DUE gap=47`: T49 commitment to add a `unit-system-cross-reference-vs-published-paper` pattern entry (if §D resolves to "our framework is wrong") or close the AUDIT_DUE gap regardless. Per `feedback_fix_the_class_not_the_instance`, the audit-class-scan after T48 will look for the class-pattern across the codebase.

13. **director.md §A6 + §F1**: this turn's dispatch is anchored in T47 critic (§E committed routing) + T46 sim (§4 trajectory data) + paper memory (anchor numbers) + 5 critic-specified open questions — NOT self-invented.

14. **director.md §F1 Research stage role description**: "lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain." T48 is exactly this — sets up T49 Hypothesize-with-corrected-units (if needed) or T49 Document-close (if normalization is OK and delocalized verdict stands).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics — yan-li-saito tier-3 candidate). T48 normalization audit is a verification action: testing whether the framework's reported n_max in D₀ units is unit-consistent with the paper's claimed n_max in D₀ units. If they aren't, the framework's interpretation of all prior yan-li-saito Execute runs has been wrong by up to 152× in absolute density. This is high-leverage verification at low cost (~1.5M).
- **D3 SECONDARY**: The audit's findings feed patterns.yaml (T49 audit-class-scan input): potential new pattern `unit-system-cross-reference-vs-published-paper` or `D0-factor-formula-must-match-paper-not-just-framework-internal`.
- **D2 NOT advanced**.
- **Tier ladder position**: entering Research (post-Update) at tier 0.60. Target trajectory:
  - Normalization OK + paper claim genuinely unreachable in our framework: tier 0.60 → 0.40 at T49.
  - Normalization off by 152× and re-classification flips delocalized → bound: tier 0.60 → 0.80 at T49.
  - Discrepancy is in memory transcription of paper (not framework or paper): tier 0.60 → 0.55 at T49 (small downgrade — memory needs fix but physics-finding stands; investigation continues toward Document).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "rationale": "T47 critic Update committed Option 3 (Normalization audit) per §E single-routing. The 152× D₀ discrepancy surfaced in T47 §D (paper anchor 3.43 μm⁻³ vs first-principles 1/(a_s³N²) = 0.0226 μm⁻³ for Eu-151 a_s=110a₀ N=15000) is a binary discriminator: until resolved, every yan-li-saito sim metric (T40/T43/T44/T46) reports n_max in D₀ that may be off by 152× vs the paper's units, making PASS/FAIL classification meaningless. Per `feedback_fix_the_class_not_the_instance`, this is a class-level question affecting the entire investigation. Per `feedback_mathematical_elegance_bias`, cheap text audit (~1.5M, ~15 min) dominates any further Execute (~5-15M) on cost-per-bit. Per §F1 verify-claim, Update → Research side-step is the correct response to 'Update surfaced load-bearing data-integrity question.' T48 executes T47 critic's literal §E committed routing.",
  "brief": "## ROLE\n\nYou are the researcher subagent (workload: researcher). Research stage (post-Update side-step) for the yan-li-saito-2026-reproduction investigation per §F1 verify-claim template: paper-vs-framework normalization audit to resolve the 152× D₀ discrepancy flagged in T47 critic §D.\n\nDeliverable: `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md` with sections §1-§7 below + final §8 metrics block.\n\n## CONTEXT\n\nT47 critic §D performed a spot-check of the paper's normalization:\n- Paper memory `yan_li_saito_2026_barnett_paper.md` line 59-63 states: `D₀ = 1/(a_s³ N²)`, with anchor `D₀ = 3.43 μm⁻³ for Eu-151 F=1 N=15000 ε_dd=1.2`.\n- T47 first-principles calculation: a_s = 110 a₀ = 5.82e-9 m → a_s³ = 1.97e-25 m³ → D₀ = 1 / (1.97e-25 × 2.25e8) = **0.0226 μm⁻³**.\n- Ratio: paper anchor 3.43 / first-principles 0.0226 = **152×**.\n\nThree candidate root causes per T47 §D (a)/(b)/(c):\n  (a) `a_s` in paper's D₀ formula is NORMALIZED (a_s/a_ho), not SI.\n  (b) Paper's D₀ uses a different length scale (e.g. a_dd, not a_s).\n  (c) Framework's `D0_factor_used=2990.1` is internally consistent but uses a different convention than paper's μ⁻³ unit.\n\nThis must be resolved before any T49 re-Hypothesize, R3 execute, or investigation closure.\n\n## REQUIRED READING\n\n1. `/tmp/yan_li_saito_2605.11670.pdf` — Yan-Li-Saito 2026 paper. Open with WebFetch if PDF read available, OR `Read` the local file. Focus: **Eq 1 (Hamiltonian) and surrounding text defining L₀, T₀, D₀, B₀**. Get the FORMULAS VERBATIM. The memory line 56-63 transcription is what we suspect — verify it character-by-character.\n\n2. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 30-80 (Hamiltonian + Normalization + Anchor numbers).\n\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_47_critic_audit.md` §D + §3 (5 open questions for this audit) + §6 next_falsifier_observable_manifest (10 items for the audit).\n\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md` §5 metrics + the `D0_factor_used=2990.1` value + the `D0_factor_formula = N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3` hint (per T47 critic §3 open question 2).\n\n5. **Codebase grep** for the source of D₀ / D0_factor:\n```bash\ncd /home/suzume/workspace/BEC-simulation && rg -n --type-add 'jl:*.jl' --type jl 'D0_factor|D_0|D₀|D0\\b' runs/yan_li_saito_f1_grid_refinement/ src/ runs/eu151_*/ scripts/ 2>/dev/null | head -200\n```\nIdentify whether D0_factor is set per-config (in `runs/yan_li_saito_f1_grid_refinement/run_R*.jl` scripts) or in framework source (`src/`).\n\n6. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` 'Dimensionless units: ℏ=m=ω_ref=1' section + '¹⁵¹Eu' section (F=6, g_J=1.9934, g_F≈1.163, a_s≈110 a₀).\n\n7. Recent sim outputs for the comparison table:\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md` §4 (P0-P4 5-point n_max values)\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_43.md` §4 (P0_pre n_max)\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_44.md` §4 (R2 fl_vortex n_max=3.09)\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_46.md` §4 (R2c n_max trajectory 3.08→1.91)\n\n## REQUIRED SECTIONS (§1-§7 + §8)\n\n### §1. Paper Eq 1 verbatim normalization extraction\n\nRead the PDF Eq 1 section (and the surrounding 'Normalization' / 'Numerical' / 'Setup' paragraphs). Extract VERBATIM:\n\n- L₀ definition (formula + symbols).\n- T₀ definition.\n- **D₀ definition** (formula + symbols + units).\n- B₀ definition.\n- For each: what are `a_s`, `N`, `M`, `g`, `μ_B` symbolically — SI or normalized?\n- If the paper says 'normalized', what is the normalizing scale (a_ho? a_dd? L₀ itself?).\n- The Eu-151 N=15000 ε_dd=1.2 anchor: what are L₀, T₀, D₀, B₀ values given by the paper?\n\nCompare line-by-line with memory `yan_li_saito_2026_barnett_paper.md` lines 56-63. **List any discrepancies.**\n\n### §2. First-principles re-derivation of paper's D₀\n\nUsing the verbatim formula from §1, compute D₀ for Eu-151 F=1 N=15000 ε_dd=1.2 in SI units (μm⁻³).\n\n- If paper formula is `D₀ = 1/(a_s³ N²)` with a_s in SI: D₀ = 1/(110 × 5.291e-11)³ / 15000² = ? μm⁻³.\n- If paper formula uses a different convention (e.g. a_s/a_ho): re-compute.\n- Report the calculation in 5+ steps with all intermediate values.\n\nReconcile with paper anchor 3.43 μm⁻³ (or whatever §1 extracts from the PDF). If discrepancy remains: which of T47 §D (a)/(b)/(c) explains it?\n\n### §3. Framework D₀ source trace\n\nGrep for the source of `D0_factor_used=2990.1`:\n\n```bash\nrg -n --type-add 'jl:*.jl' --type jl --type py 'D0_factor|D_0_si|D0_factor_used|2990' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_grid_refinement/ /home/suzume/workspace/BEC-simulation/src/ /home/suzume/workspace/BEC-simulation/scripts/ 2>/dev/null\n```\n\nIdentify:\n- Where is D0_factor set? (config / per-script / framework)\n- What formula derives 2990.1? Test the hint `D0_factor_formula = N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3`:\n  - N^3 * (a_s/a_ho)^3 for Eu-151 N=15000, a_s=110 a₀, a_ho = 1.157 μm = ?\n  - a_s/a_ho = 110 × 5.291e-11 / 1.157e-6 = 5.03e-3.\n  - (a_s/a_ho)^3 = 1.27e-7.\n  - N^3 × 1.27e-7 = 3.375e12 × 1.27e-7 = 428,625.\n  - Hmm, that's not 2990. So either the formula hint is wrong, or one of the values (N, a_s, a_ho) differs.\n- Try `(N × a_s/a_ho)^3 / N²` = N × (a_s/a_ho)^3 = 15000 × 1.27e-7 = 1.905e-3. Not 2990.\n- Try `N² × (a_s/a_ho)^3` = 2.25e8 × 1.27e-7 = 28.6. Not 2990.\n- Try `(N × a_s/a_ho)^3` = (75.5)^3 = 430,368. Not 2990.\n- Try the inverse: 1/(2990.1) = 3.34e-4. What's its interpretation? a_s/a_ho × N = 75.5; 75.5^(some power)? 75.5^2 = 5700; sqrt(75.5) × 75.5 = 8.69 × 75.5 = 656.\n- This is genuinely puzzling — find the formula in the codebase rather than reverse-engineering.\n\n**Once formula is found**: state it; evaluate it; identify whether it converts a_ho-normalized-density to paper-D₀-density or to SI density.\n\n### §4. Cross-reference: paper's D₀ vs framework's D0_factor\n\nGiven §1, §2, §3, answer:\n- Is `n_max [D₀] = n_max_dimless × D0_factor_used` the same unit as paper's `n_max [D₀]`?\n- If not, what's the conversion factor?\n- Specifically: T46's `n_max_dimless = 6.39e-4` (per sim/turn_46.md §4) × D0_factor_used 2990.1 = 1.91. This 1.91 is what unit? Convert to:\n  (a) SI: μm⁻³ (using framework convention).\n  (b) Paper's D₀ units (using paper formula).\n- For paper target 13000 D₀ (paper units): what's that in framework's D₀ units? in SI μm⁻³?\n\nProduce a 2-row table (paper vs framework) for the conversion.\n\n### §5. Revised n_max comparison table\n\nBuild a table with rows = sim runs and columns:\n\n| Run | n_max_dimless | n_max [framework D₀] | n_max [SI μm⁻³] | n_max [paper D₀] | self-bound? |\n|---|---|---|---|---|---|\n| T40 P0 | ... | ... | ... | ... | NO |\n| T40 P1 | ... | ... | ... | ... | NO |\n| T40 P2 | ... | ... | ... | ... | NO |\n| T40 P3 | ... | ... | ... | ... | NO |\n| T40 P4 | ... | 0.614 (D₀ per T40 §4) | ... | ... | NO |\n| T43 P0_pre | ... | ... | ... | ... | NO |\n| T44 R2 (start) | ... | 3.09 | ... | ... | NO |\n| T46 R2c (final) | 6.39e-4 | 1.91 | ... | ... | NO |\n| Paper target | — | — | 44,600 μm⁻³ (?) | 13000 | YES |\n\nPopulate the SI and paper-D₀ columns once §4 conversion is established.\n\n**Crux question**: after consistent-unit conversion, is the gap between our T46 final and paper target still 4-orders-of-magnitude, or is it smaller (say 100×)? This determines whether revival is possible.\n\n### §6. Sibling-class grep (per `feedback_fix_the_class_not_the_instance`)\n\nIf §3 found a framework D₀ formula error (or codebase-side inconsistency), grep for sibling instances:\n\n```bash\nrg -n --type-add 'jl:*.jl' --type jl 'D_0|D0_factor|a_dd|N\\^2|N\\^3' /home/suzume/workspace/BEC-simulation/src/ /home/suzume/workspace/BEC-simulation/runs/ 2>/dev/null | rg -v 'comment|#' | head -50\n```\n\nList any other call sites that use the same `D0_factor` or compute density in framework D₀ units. Are those affected by the same potential bug?\n\n**Class-pattern proposal for patterns.yaml** (T49 audit-class-scan input):\n- name: `unit-system-cross-reference-vs-published-paper`\n- detect: anywhere the codebase reports a metric in 'paper D₀ units' (or similar paper-defined units) without first verifying the conversion factor against paper's formula.\n- grep anchor: ... (specify).\n\n### §7. Routing recommendation + tier transition\n\nGiven §1-§6 findings, recommend ONE of:\n\n- **Option A: Memory transcription error** (paper's formula in memory line 59 is wrong, paper's actual formula differs, but framework is correct). T49 = implementer_text Document stage: update memory `yan_li_saito_2026_barnett_paper.md` with verbatim paper formulas; physics-finding (delocalized at T46) stands; tier 0.60 → 0.55.\n\n- **Option B: Framework D0_factor error** (framework's D0_factor=2990.1 uses wrong formula, paper is right). T49 = implementer_julia_cpu_light fix to D0_factor in `runs/yan_li_saito_f1_grid_refinement/run_*.jl` (and any framework source identified in §3, §6); re-run T46 metrics interpretation; re-classify each prior run; tier 0.60 → 0.50 (work increase) but possibly REVIVAL signal if re-interpretation flips delocalized → bound at some point.\n\n- **Option C: Both agree (conversion factor identified)** (paper's D₀ and framework's D0_factor are two different units; conversion is just a fixed ratio). T49 = implementer_text Document stage: add conversion table to memory; tier 0.60 → 0.55. Re-interpret all sim metrics with conversion; if even after conversion T46 is still 100×+ away from paper target, classify as 'partial REFUTE — paper claim not reproducible in our framework at feasible grid' and proceed to investigation closure at T50.\n\n- **Option D: Investigation closure** (after audit, no plausible revival path; gap is unmoved). T49 = implementer_text Document stage memory entry; tier 0.60 → 0.40; investigation closes.\n\nCommit to ONE option per `feedback_decision_style`. Provide cost estimate + 1-line success criterion for T49.\n\n### §8. Metrics block (JSON)\n\n```json\n{\n  \"audit_target\": \"D0_normalization_paper_vs_framework\",\n  \"paper_D0_formula_verbatim\": \"<from Eq 1 PDF read>\",\n  \"paper_D0_anchor_value_micron_inverse_cube\": <float>,\n  \"framework_D0_factor_used\": 2990.1,\n  \"framework_D0_factor_formula_source_file\": \"<path:line>\",\n  \"framework_D0_factor_formula_verbatim\": \"<formula>\",\n  \"framework_D0_value_micron_inverse_cube\": <float>,\n  \"discrepancy_ratio_paper_over_framework\": <float>,\n  \"discrepancy_root_cause\": \"<memory-transcription | framework-formula | convention-difference | other>\",\n  \"revised_n_max_table_present\": true,\n  \"t46_n_max_in_paper_D0_units\": <float>,\n  \"t46_n_max_in_SI_micron_inverse_cube\": <float>,\n  \"paper_target_in_framework_D0_units\": <float>,\n  \"gap_factor_after_conversion\": <float>,\n  \"class_pattern_proposal_for_patterns_yaml\": \"<one-sentence description>\",\n  \"sibling_class_grep_hits\": <int>,\n  \"section_7_routing_recommendation\": \"<A | B | C | D>\",\n  \"section_7_tier_transition\": <float>,\n  \"cost_budget_t49_estimate_effective\": <int>,\n  \"cost_budget_t49_estimate_wall_sec\": <int>,\n  \"audit_md_on_disk\": true,\n  \"audit_md_path\": \"runs/yan_li_saito_f1_grid_refinement/normalization_audit.md\",\n  \"sources_cited\": <int>,\n  \"investigation_id\": \"yan-li-saito-2026-reproduction\",\n  \"recommends_close_investigation\": <bool>\n}\n```\n\n## STYLE & CONSTRAINTS\n\n- Cite ≥ 7 sources (paper PDF, memory, T47 critic audit, T46 sim, T40 sim, codebase grep results, CLAUDE.md).\n- Verbatim paper-formula quotation is MANDATORY — no paraphrasing the Hamiltonian or normalization.\n- Do NOT modify code at T48 (audit only). T49 may modify code per §7 routing.\n- Do NOT propose multi-option §7 routing — commit to ONE per `feedback_decision_style`.\n- Per `feedback_no_improvised_terminology`: standard physics terms only.\n- Per `feedback_fix_the_class_not_the_instance`: §6 sibling-class grep is MANDATORY, not optional.\n- Budget: ~1.5M effective, ~10-20 min wall (text-only researcher; PDF read + grep + write).\n- Output single markdown file `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md`. No commits.\n- If PDF read fails (e.g. binary not accessible), fall back to memory line 30-100 as paper proxy + note the limitation in §1.\n\n## DELIVERABLE\n\n1. `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md` — §1-§7 + §8 metrics block.\n2. Single committed §7 routing recommendation (A/B/C/D) with cost + success criterion.\n3. §8 metrics block parseable by judge.py.\n4. Class-pattern proposal entry suitable for patterns.yaml insertion at T49+ audit-class-scan.",
  "observable_manifest": {
    "required": [
      "audit_md_on_disk",
      "audit_md_path",
      "paper_D0_formula_verbatim",
      "framework_D0_factor_formula_source_file",
      "discrepancy_root_cause",
      "section_7_routing_recommendation",
      "section_7_tier_transition",
      "investigation_id",
      "sources_cited",
      "revised_n_max_table_present"
    ],
    "optional": [
      "paper_D0_anchor_value_micron_inverse_cube",
      "framework_D0_value_micron_inverse_cube",
      "discrepancy_ratio_paper_over_framework",
      "t46_n_max_in_paper_D0_units",
      "t46_n_max_in_SI_micron_inverse_cube",
      "paper_target_in_framework_D0_units",
      "gap_factor_after_conversion",
      "class_pattern_proposal_for_patterns_yaml",
      "sibling_class_grep_hits",
      "cost_budget_t49_estimate_effective",
      "cost_budget_t49_estimate_wall_sec",
      "recommends_close_investigation"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_47_critic_audit.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_46.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_44.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && test -d /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_grid_refinement/ && (test -f /tmp/yan_li_saito_2605.11670.pdf || echo 'PDF MISSING — researcher uses memory proxy + notes limitation in §1') && echo 'precondition OK: all required input files present for normalization audit'"
  },
  "success_criteria": [
    {
      "id": "audit_md_on_disk",
      "metric": "audit_md_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit deliverable required — researcher must Write to runs/yan_li_saito_f1_grid_refinement/normalization_audit.md."
    },
    {
      "id": "paper_formula_extracted",
      "metric": "paper_D0_formula_verbatim",
      "operator": "!=",
      "value": null,
      "tolerance": null,
      "rationale": "§1 deliverable: verbatim D₀ formula from paper. Null means PDF was not read OR memory proxy was used without verbatim extraction — both unacceptable."
    },
    {
      "id": "framework_source_identified",
      "metric": "framework_D0_factor_formula_source_file",
      "operator": "!=",
      "value": null,
      "tolerance": null,
      "rationale": "§3 deliverable: D0_factor source location identified by file:line. Required for class-pattern grep at §6."
    },
    {
      "id": "root_cause_committed",
      "metric": "discrepancy_root_cause",
      "operator": "in",
      "value": ["memory-transcription", "framework-formula", "convention-difference", "no-discrepancy-after-audit", "other"],
      "tolerance": null,
      "rationale": "§2-§4 deliverable: ONE committed root cause classification. 'other' is allowed but must be elaborated in audit.md."
    },
    {
      "id": "routing_single_commit",
      "metric": "section_7_routing_recommendation",
      "operator": "in",
      "value": ["A", "B", "C", "D"],
      "tolerance": null,
      "rationale": "§7 deliverable: single committed routing (A=memory-fix, B=framework-fix, C=conversion-table, D=close-investigation) per `feedback_decision_style`."
    },
    {
      "id": "tier_in_plausible_range",
      "metric": "section_7_tier_transition",
      "operator": "in_range",
      "value": [0.30, 0.85],
      "tolerance": null,
      "rationale": "Tier must be in plausible range; 0.40-0.80 most likely depending on which option committed."
    },
    {
      "id": "sources_cited_sufficient",
      "metric": "sources_cited",
      "operator": ">=",
      "value": 7,
      "tolerance": null,
      "rationale": "Per researcher convention: substantive audits cite ≥ 7 sources (T47 critic cited 12)."
    },
    {
      "id": "revised_table_present",
      "metric": "revised_n_max_table_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§5 deliverable: revised n_max comparison table across T40/T43/T44/T46 in consistent units."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "yan-li-saito-2026-reproduction",
      "tolerance": null,
      "rationale": "Stage routing depends on correct investigation_id."
    }
  ],
  "failure_modes": [
    {
      "if": "audit_md_on_disk == false",
      "category": "operational",
      "next_action": "T49 = re-dispatch researcher with explicit file-path enforcement. If 2nd attempt fails, escalate to anko."
    },
    {
      "if": "discrepancy_root_cause == 'memory-transcription' (Option A)",
      "category": "scientific_data_integrity_memory",
      "next_action": "T49 = implementer_text Document stage: update memory `yan_li_saito_2026_barnett_paper.md` with verbatim paper formulas. Physics-finding (delocalized at T46) stands. Tier 0.60 → 0.55. Investigation continues toward Document-close after one more verification pass."
    },
    {
      "if": "discrepancy_root_cause == 'framework-formula' (Option B)",
      "category": "scientific_data_integrity_framework",
      "next_action": "T49 = implementer_julia_cpu_light fix to D0_factor formula in framework / config scripts. Re-interpret T40/T43/T44/T46 metrics. Tier 0.60 → 0.50 (work increase) with REVIVAL POSSIBILITY if re-interpretation flips delocalized→bound at any prior run."
    },
    {
      "if": "discrepancy_root_cause == 'convention-difference' (Option C)",
      "category": "scientific_unit_audit",
      "next_action": "T49 = implementer_text Document stage: add conversion table to memory. Re-interpret all sim metrics. If even after conversion gap > 100× to paper target, T50 = investigation closure path. Tier 0.60 → 0.55."
    },
    {
      "if": "discrepancy_root_cause == 'no-discrepancy-after-audit' (paper anchor wrong or T47 critic mis-calculation)",
      "category": "scientific_no_action_needed",
      "next_action": "T49 = implementer_text Document stage memory entry noting audit cleared the false alarm. Tier 0.60 → 0.50 (delocalized finding stands without unit ambiguity). Investigation continues toward closure path."
    },
    {
      "if": "section_7_routing_recommendation == 'D' (close investigation)",
      "category": "scientific_refuted",
      "next_action": "T49 = implementer_text Document stage memory entry capturing 'yan-li-saito free-space droplet not reproducible in current framework at feasible grids' lesson + normalization audit findings. Tier 0.60 → 0.40. Investigation closes; loop frees for klaus-bch-leak (priority 3) OR audit-class-scan."
    },
    {
      "if": "sibling_class_grep_hits >= 3",
      "category": "fix_the_class",
      "next_action": "Note for T50 audit-class-scan: add proposed pattern `unit-system-cross-reference-vs-published-paper` to patterns.yaml with researcher's grep anchor. Per `feedback_fix_the_class_not_the_instance`, sibling instances batch-fixed at T50+."
    },
    {
      "if": "researcher produces hedged multi-option §7 recommendation",
      "category": "scope_violation",
      "next_action": "T49 = re-dispatch researcher with explicit single-commitment enforcement. Per `feedback_decision_style`: commit to ONE path."
    },
    {
      "if": "sources_cited < 7",
      "category": "scope_violation_low_grounding",
      "next_action": "T49 = re-dispatch researcher with explicit sources-cited floor."
    },
    {
      "if": "PDF read fails AND memory proxy is used",
      "category": "data_gap_partial",
      "next_action": "Audit may still produce §7 commitment if memory + first-principles re-derivation suffice. T49 may be conditional on PDF access (e.g. anko ratifies a follow-up PDF read in a future turn). Tier transition should be more conservative (closer to 0.60 unchanged) given the incomplete primary source access."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2500000,
    "wall_time_hard_cap_sec": 1500
  },
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 900,
    "split_by_subtask": {
      "read_t47_critic_t46_t40_t44_sim_paper_memory": 400000,
      "pdf_read_or_proxy_paper_eq1_normalization": 300000,
      "grep_codebase_D0_factor_source_trace": 250000,
      "first_principles_recalc_and_reconciliation": 250000,
      "write_audit_md_with_metrics_and_table": 300000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Depends on §7 routing: A (memory-fix) → Document (T49 implementer_text); B (framework-fix) → Hypothesize then Execute (T49 theorist + T50 implementer_julia_cpu_light); C (conversion-table) → Document (T49 implementer_text); D (close) → Document (T49 implementer_text close-out memory). All paths land at Document; routing differs in scope of work BEFORE Document.",
    "if_success_tier_becomes": "Per §7: researcher's committed tier value (expected range 0.40-0.80 given §1-§6 findings; specific value depends on routing).",
    "if_refuted_advance_to_stage": "N/A — researcher Research is preparatory; there is no 'researcher REFUTED' branch in template, only routing recommendations. If researcher produces malformed output, T49 = re-dispatch researcher.",
    "if_refuted_tier_becomes": "N/A (per above).",
    "next_falsifier_to_test_after": "Per researcher §8 metrics class_pattern_proposal_for_patterns_yaml field. T49 director uses §7 routing recommendation as authoritative for next dispatch. EXPLICIT T49/T50 COMMITMENT (per director.md §B6 drift acknowledgement + AUDIT_DUE gap=47): T49 = whatever §7 recommends; T50 = audit-class-scan if not already triggered. AUDIT_DUE MUST close by T50 at the latest."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_48.json` (policy=JULIA_GPU_OK; `researcher` in allowed_workloads; window 1192414s left; PROBE_DRIVEN; vram free 12962 MB).
- [x] Read `runs/_loop/state.json` (yan-li-saito-2026-reproduction is active_investigation_id; current_stage=Update at state; tier 0.70; falsifier history through T45).
- [x] Read `runs/_loop/seed.md` (yan-li-saito priority 2 per seed but priority 1 in state — state authoritative; Tier-3 candidate; cost cap 100M rolling / 6M per-turn).
- [x] Read `runs/_loop/director/turn_47.md` (prior director — confirmed T47 critic Update was correctly dispatched; T48 should execute §E committed routing).
- [x] Read `runs/_loop/judge/turn_47_critic_audit.md` end-to-end (T47 critic §A/§B/§C/§D/§E/§F + §6 metrics; §E commits Option 3 Normalization audit + new class-pattern candidate + meta-data point).
- [x] Read `runs/_loop/sim/turn_46.md` first 200 lines (T46 metrics + trajectory; D0_factor_used=2990.1 confirmed).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` lines 1-100 (normalization formulas + anchor numbers — primary input for §1 audit).
- [x] investigation_id 'yan-li-saito-2026-reproduction' valid in state.investigations.
- [x] stage_advancing_to 'Research' is correct per §F1 verify-claim: post-Update side-step when Update surfaces load-bearing data-integrity question; researcher role per stage.
- [x] subagent_type 'researcher' matches role_per_stage[Research] in §F1 + scheduler.allowed_workloads.
- [x] success_criteria 9 criteria, machine-evaluable (file existence + verbatim extraction + commitment + tier range).
- [x] failure_modes cover 10 likely outcomes including each §7 routing branch + PDF-read-failure fallback + sibling-class trigger.
- [x] observable_manifest precondition_check is concrete bash (5 file checks + 1 conditional PDF check + echo); falls back gracefully if PDF missing.
- [x] budget 1.5M effective fits within scheduler window + per-turn cap (6M) + tolerance_override 2.5M.
- [x] §A6 research-first citation present (14 references in §4, anchored on T47 critic's §E single-routing commitment + paper memory + framework source trace).
- [x] §A5 D1 PRIMARY articulated (verify unit consistency before further Execute spend); D3 SECONDARY (class-pattern proposal for patterns.yaml T50 audit input); manuscript NOT primary.
- [x] Investigation update articulates per-routing-outcome (A/B/C/D) stage transitions and tier values.
- [x] Considered switching investigations: klaus-bch-leak (loses cascade context at cheap-bottleneck); audit-class-scan (legitimate AUDIT_DUE — explicit T50 commitment); meta-investigations (defer post-cascade); noop (rejected — T47 critic committed Option 3 with concrete deliverable; executing is the literal template-correct next move).
- [x] Drift signals from T47 are advisory-only (sub-threshold) — no `director_must_address` to satisfy; AUDIT_DUE explicitly committed for T50.
- [x] Resisted T47 critic's secondary suggestion to dispatch as implementer_text — used researcher because the primary action is paper-read + codebase-grep (researcher's job); implementer_text would be appropriate at T49 if §7 routes to A/C (memory-fix or conversion-table commit).
