---
turn: 41
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Execute
stage_advancing_to: Research
topic_tags: [yan-li-saito-2026, paper-pdf-read, fig1c-F-clarification, initial-state-procedure, chi-epsilon-dd-numerical, data-gap-c-closure, post-refuted-research-reinjection]
paper_section: null
depends_on: [40, 39, 38, 37, "runs/_loop/sim/turn_40.md", "runs/_loop/judge/turn_40.json", "runs/_loop/theorist/turn_40.md", "runs/_loop/research/turn_39_Q1.md", "runs/_loop/state.json (next_stage_action explicit)", "/tmp/yan_li_saito_2605.11670.pdf (18848 lines, accessible)", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Researcher Research-stage brief that reads /tmp/yan_li_saito_2605.11670.pdf end-to-end and resolves three questions blocking the (a4) vs (c) discrimination: Q1 (Fig 1c F-value), Q2 (paper's exact initial-state + ITP procedure), Q3 (paper's numerical χ(ε_dd=1.2) value + DDI convention factor)."
---

# Turn 41 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.6 → tier_target 3). Continuing the T37→T38→T39→T40 cycle.
- **Stage transition**: **Execute → Research** (re-injection per §F1 verify-claim REFUTED-with-data-gap handling). T40 Execute REFUTED both (b) seed-basin density-axis hypothesis AND (a2) topology hypothesis. The verdict matrix row 4 (theorist/turn_40.md §6) leaves three candidate causes: (a4) framework deep bug, (c) paper-claim wrong, (a1) LHY χ(ε_dd>1) issue. Q1 already resolved at T39 research (`runs/_loop/research/turn_39_Q1.md`: Lima-Pelster Re-prescription = truncate-to-zero, our impl matches, NO bug in `lima_pelster_Q5`). So (a1) is closed. Remaining: (a4) vs (c). Discriminating these requires NEW DATA (paper-source-of-truth) before another critic dispatch can usefully narrow further.
- **Tier**: stays 0.6 entering Research re-injection. On Research success (paper questions answered): tier nudges to 0.7. On subsequent critic-narrow → fix-bug or close-as-paper-wrong: tier → 1.0+.
- **Falsifiers tested/refuted**:
  - `f1-direct-reproduction` T37 FALSIFIED. T40 5-point discriminator (state.json line 2173-2174): "P0/P1/P2/P3 (Gaussian σ sweep 0.5→14) all delocalized confirming theorist E_DDI=0 isotropy derivation; P4 (fl_vortex JLD2, topology preserved to machine eps) ALSO delocalized refuting topology-axis hypothesis. Both (b) and (a2) REFUTED. Open: (a4) framework deep-bug, (a1) LHY χ(ε_dd>1) issue, (c) paper-claim wrong." (a1) now closed by T39 Q1.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed at Tier 3.0 (T29 Document).
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, documented): blocked on julia P3 validation. Could unblock under JULIA_GPU_OK but priority 1 yan-li-saito owns this turn.
  - `fullbdg-f6-polar-3000x` (priority 99, dormant): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, kind=meta, Observe): observation pool growing. T39→T40 sequence is mixed evidence: T39 critic NARROWED cleanly, T40 implementer ran the experiment that REFUTED the narrowed hypothesis (a productive REFUTED-outcome per grounded-autonomous-research arXiv:2604.12198). The meta-hypothesis about critic-placement remains under-observed. Re-evaluate at T44+.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T38 | Update (critic) | CRITIC_PASS / NEEDS-FURTHER-DISCRIMINATION | Critic narrowed root-cause space (Q5 HIGH, Q1 MEDIUM, Q2 RULED OUT); recommended Design with ε_dd-sweep + sympy. |
| T39 | Update (critic re-dispatch) | CRITIC_PASS / NARROWED-TO-2-CAUSES | 4-class enumeration → (b)+(a2) HIGH; (c) data-gap (PDF was "permission-denied" at T39 — but file exists at /tmp/yan_li_saito_2605.11670.pdf per memory). T39 critic argued seed |ψ|²_peak 575× gap. |
| T40 | Design+Execute (theorist+implementer chained) | INCONCLUSIVE (contract-shape) / SUBSTANTIVELY REFUTED | Theorist Design (turn_40.md §2.2) derived E_DDI=0 exact for spherical Gaussian (isotropy), predicted ALL σ-axis points would spread regardless of seed density — CORRECTLY contradicting T39 critic's "density basin" intuition. Implementer ran all 5 points GPU ITP (299s total). Result: P0=0.99, P1=1.06, P2=0.60, P3=0.21, P4=0.61 D₀ (vs target 13000 D₀). All DELOCALIZED. P4 fl_vortex topology preserved (f_z = 2.7e-16 at ring, m_+1=m_-1=0.5 throughout 5000 ITP steps) but density never rose. Theorist verdict-matrix row 4 selected: "(a4) framework deep bug OR (c) paper wrong OR (a1) LHY issue. Even topologically correct seed cannot stabilize droplet." Judge marked INCONCLUSIVE because T40's success_criteria were designed for a theorist-Design output and the implementer's metrics are experiment-shaped (per-point n_max etc.). The science verdict is REFUTED, not inconclusive. |

**Strategic implication**: Three things are now true that weren't before T40:
1. Theorist derivation E_DDI^Gaussian=0 by 3D isotropy is the LOAD-BEARING physics insight: any spherically-symmetric seed cannot harness DDI attraction. The σ-sweep was always going to fail. T39 critic was wrong on this point.
2. Even topologically nontrivial (P4 flux-closure torus) starting at ~0.15 D₀ peak density did NOT contract to droplet basin — ITP gradient descent does not span 4 orders of magnitude in peak density from coarse-grid seed (grid dx=0.44 a_ho vs paper dx=0.014 a_ho, 31× coarser). This could be: (a4) framework gap (grid resolution, ITP convergence criteria, free-space BCs), OR (c) paper-claim wrong about F=1.
3. Q1 (LHY χ-prescription bug) was already closed at T39 research — `lima_pelster_Q5` uses truncate-to-zero matching LP-2011 canonical. So (a1) is DEAD.

The minimum-cost highest-leverage next move is RESEARCHER reading the paper PDF (NOW accessible at /tmp/yan_li_saito_2605.11670.pdf, 18848 lines of text content per Grep) to close three specific questions that DISCRIMINATE (a4) from (c) cheaply BEFORE committing to expensive deep-framework-audit.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Standard verdict-mapping** per director.md §B3: REFUTED → jump to Update (revise hyp). But the Update stage's role is critic, and the critic cannot productively re-narrow without NEW EVIDENCE — T39 already did that twice. The flow allows Research re-injection when data-gap blocks Update: the paper-source-of-truth was UNAVAILABLE at T39 (claimed permission-denied) and IS NOW AVAILABLE at /tmp/yan_li_saito_2605.11670.pdf. This is the data-gap closure that unblocks the next Update.
- **Role for stage Research**: researcher (§F1).
- **Why this stage now (vs other options)**:
  - **Why not Update (critic)**: Critic at T38/T39 already exhaustively enumerated and narrowed the root-cause space. Re-dispatching critic without new evidence would be retry-hell (the exact pattern the meta-critic-placement investigation is observing). The new evidence is the paper PDF, which only researcher can extract.
  - **Why not Hypothesize (theorist)**: Theorist at T40 derived the correct prediction (E_DDI=0 for Gaussian) and the experiment confirmed it. The hypothesis space is well-articulated; what's missing is paper-side data to discriminate (a4) vs (c).
  - **Why not Design+Execute another GPU round**: T40's verdict-matrix row 4 explicitly recommends BOTH (i) PDF-fetch researcher AND (ii) deep-framework-audit. (i) is cheap (text-only ~2M effective); (ii) is expensive (theorist deep-dive + possible sympy chi cross-check ~5M effective). Cheap-first is canonical per AI Scientist v2 multi-axis-cheap pattern + Reflexion verbal-critique-before-action.
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1 + clear actionable next step. Switching would orphan the cycle mid-cascade.
  - **Why not switch to meta (priority 50)**: meta picks up after current investigation closes its cycle. Per §B2 interleaving rule, meta is INTERLEAVED not parallel; mid-cascade is the wrong moment.
  - **Why not noop**: clear actionable directive with high leverage (data-gap closure unblocks 2 downstream paths).

## 4. Research grounding (§A6)

**External references (load-bearing for this dispatch)**:

1. **Yan-Li-Saito 2026 paper PDF at /tmp/yan_li_saito_2605.11670.pdf**: the source-of-truth that T39 critic claimed inaccessible but is in fact present (verified via Grep finding 18848 lines of content). Memory anchor `yan_li_saito_2026_barnett_paper.md` line 13 documents the local copy. This is the data-gap that has been blocking (c) resolution.

2. **`runs/_loop/research/turn_39_Q1.md`**: prior researcher work resolving Q1 (Lima-Pelster Re-prescription). Establishes the precedent that researcher dispatches with focused questions and PDF/external-source access produce clean discriminator-class answers (~3.5M effective at T39 by orchestrator total). Same shape applies here.

3. **`runs/_loop/sim/turn_40.md` §7 "Falsification check"**: explicit verdict matrix row 4 selection: "(a4) framework deep bug OR (c) paper wrong OR (a1) LHY issue. Even topologically correct seed cannot stabilize droplet." Recommended T41+ routing item 1: "Spawn researcher PDF-fetch (hypothesis c: paper claims F-independence, verify if Fig 1c is actually F=6 only)". Director honors this recommendation.

4. **`runs/_loop/state.json` next_stage_action (line 2165) for yan-li-saito**: "T41 must be critic/researcher to narrow these. Parallel: paper-fetch arXiv:2605.11670 to close (c) data gap; theorist deep-audit rotating_basis F=1 + DDI path." Director.md §B2 directs that this be honored verbatim.

5. **`runs/_loop/theorist/turn_40.md` §11 research_queries Q1**: theorist explicitly flagged Q1 = "does Fig 1c show F=1 numerical or only F=6 with F-independence assertion?" as the load-bearing paper-side question. This is the exact prompt this turn's researcher will answer.

6. **`runs/_loop/theorist/turn_40.md` §2.2 [Established] E_DDI=0 for spherical Gaussian**: cited and CONFIRMED by T40 experiment. This insight changes which paper-side details are now important: NOT "what initial sigma did the paper use" (irrelevant if topology is sufficient) but "what IS the paper's initial state procedure" (phase imprint, L_z+f_z conservation, ITP wall-time, grid resolution).

7. **director.md §G "Grounded autonomous research (arXiv:2604.12198)"**: "agent unsupervised proposed HSE, ran it, refuted its own prior → wrote the inversion in worklog. This is the gold standard for the Update stage — REFUTED is a science success when documented." T40's REFUTED result IS documented (theorist verdict-matrix + sim §7); the next move is the canonical post-refutation lit-grounded narrowing.

8. **director.md §G "AI Scientist v2: cheap multi-axis discriminator before expensive single-point retry"**: researcher PDF-fetch (~2M effective, ≤30 min wall) is the cheap axis; theorist deep-framework-audit (~5M+ effective) is the expensive axis. Cheap-first is canonical.

9. **Reflexion (Shinn et al. NeurIPS 2023)**: verbal critique cycle (T38→T39 critic) has saturated; next loop iteration requires action (researcher reads paper) rather than more critique.

10. **Memory `feedback_manuscript_is_not_the_essence.md`**: "real bug-finding in production code IS the essence". Closing the paper-data-gap to discriminate (a4) framework-bug from (c) paper-wrong is exactly real-bug-finding-vs-paper-error-discrimination work.

11. **Memory `yan_li_saito_2026_barnett_paper.md` lines 65-72 + 74-82**: anchor numbers and Numerical-section details from the paper that researcher must verify against the PDF content (paper claims dx≈10⁻³, dt≈10⁻⁷, ITP, phase imprint exp(iℓφ), L_z+f_z conservation; anchor target torus density ~13000 D₀, ⟨L_z⟩≃0.96, ⟨f_z⟩≃0.04 for ℓ=1).

12. **director.md §F1 Research row**: "lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain". This dispatch is Research-re-injection AFTER REFUTED Execute; same role applies.

**Why these inform the dispatch**: The paper PDF is accessible NOW. The T39 critic's permission-denied claim is contradicted by file existence + content. AI Scientist v2 + Reflexion + grounded-autonomous-research jointly endorse "after exhaustive critique-cycle saturation, gather new evidence". The cheap researcher dispatch closes (c) at ~2M effective; if (c) PASSes (paper-claim valid), T42 = theorist deep-framework-audit. If (c) FAILs (paper-claim wrong, e.g. Fig 1c is F=6-only), T42 = Document REFUTED-paper-claim + close investigation OR pivot to F=6 reproduction. Either outcome is high-information per ~30 min researcher work.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics). Researcher closes the paper-data-gap that has been blocking (a4) vs (c) discrimination. The output enables a concrete next-step (deep-audit vs pivot) that wouldn't be discriminable without paper-side facts.
- **D3 SECONDARY**: researcher's output is lit-grounded by definition (paper is the source-of-truth). If researcher finds the paper Fig 1c uses F=6 with F-independence-asserted, this is itself a tier-2 finding — "Yan-Li-Saito F-universality claim is asserted not numerically verified at F=1" — which would be a publishable methods-note observation.
- **D2 NOT advanced this turn** (no service optimization).
- **Tier ladder position**: 0.6 (after T40 Execute REFUTED) → 0.7 (after T41 Research data-gap closure) → 1.0+ contingent on T42 critic-with-new-evidence verdict.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T41 delivers researcher research brief only.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "rationale": "T40 Execute REFUTED both (b) seed-basin density-axis and (a2) topology-axis hypotheses (all 5 GPU points delocalized at 0.2-1.1 D₀ vs paper target 13000 D₀). Verdict-matrix row 4 (theorist/turn_40.md §6) leaves (a4) framework deep-bug, (c) paper-claim wrong, (a1) LHY χ issue. (a1) closed at T39 research (Q1 RESOLVED). Discriminating (a4) vs (c) requires paper-side facts that critic at T38/T39 could not obtain (PDF claimed permission-denied). PDF IS in fact at /tmp/yan_li_saito_2605.11670.pdf (file existence + 18848 lines of content verified via Grep this turn). Per §F1 verify-claim with data-gap, Research re-injection. Per AI Scientist v2 cheap-axis-first + Reflexion verbal-critique-saturation + grounded-autonomous-research lit-grounded-narrowing, researcher PDF-read at ~2M effective unblocks T42 critic with new evidence. State.json next_stage_action line 2165 + theorist verdict matrix § 6 + sim/turn_40.md §7 all explicitly recommend this exact move.",
  "brief": "Read the Yan-Li-Saito 2026 paper PDF at `/tmp/yan_li_saito_2605.11670.pdf` (18848 lines of text content verified accessible) end-to-end. Resolve three specific questions that discriminate (a4) framework-deep-bug from (c) paper-claim-wrong for the yan-li-saito-2026-reproduction investigation.\n\n## CONTEXT FOR RESEARCHER\n\nT40 ran a 5-point GPU ITP discriminator (σ-sweep + fl_vortex topology) for F=1 N=15000 ε_dd=1.2 free-space droplet GS. All 5 points DELOCALIZED with n_max in [0.21, 1.06] D₀ vs paper target 13000 D₀ (factor 12000 deficit). P4 (flux-closure torus seed, R_t=7 r_t=2 a_ho) preserved its topology to machine precision (f_z = 2.7e-16 at ring, m_+1=m_-1=0.5 throughout 5000 ITP steps) but density did not rise. Theorist (turn_40.md §2.2) derived E_DDI^Gaussian=0 exactly by 3D isotropy — confirming all spherical seeds will fail. Q1 (Lima-Pelster Re-prescription) was resolved at T39 research (your previous Q1 work at runs/_loop/research/turn_39_Q1.md): truncate-to-zero, our lima_pelster_Q5 impl matches LP-2011 canonical, NO bug. So (a1) LHY-χ is dead. Remaining: (a4) framework gap (grid resolution, ITP convergence, free-space BCs, missing angular-momentum-conserving ITP) OR (c) paper-claim wrong (Fig 1c is F=6-only with F-independence asserted, not numerically verified at F=1).\n\n## REQUIRED READING\n\n1. `/tmp/yan_li_saito_2605.11670.pdf` — the paper itself, end-to-end. Use Read tool with `pages` parameter to chunk it; the file has 18848 lines of extracted content. Confirm you can actually access it (T39 critic claimed permission-denied — likely false; verify).\n2. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 30-82 — memory's prior summary of paper Eq 1, normalization, numerical, anchor numbers. Use this as your starting prior; the PDF is the ground truth.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_40.md` §2.2-2.4 + §11 — theorist's Q1 question on F-value of Fig 1c, plus the E_DDI=0 isotropy argument that frames why paper's initial-state procedure (NOT seed sigma) is the load-bearing detail.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md` §5-§7 — T40 experiment result + theorist verdict matrix selection.\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_39_Q1.md` — your prior research output style/depth (RESOLVED-status format, source-of-truth citations, calibration tags).\n\n## DELIVERABLE: Write `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_41.md`\n\nFollow the §F1 Research stage role: lit scan + memory + paper → citation chain for next Update.\n\n### §1 Queries received\n\nList Q1, Q2, Q3 verbatim as below.\n\n### §2 Findings per query\n\n**Q1 — Fig 1c F-value**\n- Topic: \"Does Yan-Li-Saito Fig 1c (torus magnetic-vortex GS with peak density ~13000 D₀) show F=1 numerical simulation result, or is it F=6 (or other) with F-independence merely asserted in the text?\"\n- Why: T37 + T40 reproduction at F=1 ε_dd=1.2 N=15000 in :scalar+DDI+LHY framework yields ~1 D₀, not 13000 D₀. If the paper's actual Fig 1c is F=6 with `qualitative F-independence`, our F=1 target may be wrong and we should retry at F=6 (different c_dd, c_0 scaling).\n- Required answer: STATE EXPLICITLY which F-value Fig 1c uses. Quote the figure caption verbatim. Quote any F-independence claim verbatim with surrounding 2-3 sentences for context. Status: RESOLVED / OPEN / INCONCLUSIVE.\n\n**Q2 — Exact initial-state + ITP procedure**\n- Topic: \"What is the paper's exact procedure to obtain the Fig 1c torus magnetic-vortex GS? Specifically: (i) initial state (Gaussian? Thomas-Fermi? Phase imprint? L_z structure?), (ii) is angular-momentum conservation enforced during ITP, (iii) what wall-time / step-count of ITP is used, (iv) what grid resolution (dx, dt), (v) what BCs (free space or large box)?\"\n- Why: Memory line 71 reads `ℓ=1 vortex state obtained via phase imprint exp(iℓφ) + energy relaxation with total angular momentum conservation`. But the Fig 1c GS (torus magnetic vortex) is the B=0 GS at ⟨L⟩=0, ⟨f⟩=0 — is it obtained from the phase-imprint procedure or from a different initial-state? Our T37/T40 used spherical Gaussian seed without phase imprint and without L_z conservation; if paper uses phase imprint + L_z+f_z conservation for Fig 1c specifically, this is a framework-gap = (a4) but with a clear fix path (implement angular-momentum-conserving ITP + phase-imprint init). If paper uses plain ITP from any seed and droplet emerges, (a4) is a different/deeper gap.\n- Required answer: STATE the initial-state. Quote any procedural details verbatim. List dx, dt, ITP wall-time, BC type. Status.\n\n**Q3 — paper's numerical χ(ε_dd=1.2) value + DDI prefactor convention**\n- Topic: \"What numerical value does the paper report (or implicitly use) for χ(ε_dd=1.2)? Does the paper cite Lima-Pelster Q5 or use a different LHY prefactor? What is the EXACT DDI prefactor convention (paper says μ_0(gμ_B)²/8π in E_ddi; what is the factor on `Q_αβ = k̂_αk̂_β - δ_αβ/3`)?\"\n- Why: Our γ_LHY=12.8 at T37 derives from `(128√π/3)(a_s/a_ho)^{5/2} N^{3/2} χ(ε_dd)` (CLAUDE.md scalar form). If our χ(ε_dd=1.2) ≈ 2.5 vs paper's value differs by factor 2 or more, (a1) is reopened (different χ-integral convention). Q1 at T39 closed the prescription branch (truncate-to-zero) but did NOT verify our numerical χ-value against paper's. DDI convention: our `c_dd = μ_0 μ²` (no 4π) vs paper's `μ_0(gμ_B)²/8π = c_dd/2` per memory line 90 — we need to check if our factor matches what T37 used (c_dd=639 effective).\n- Required answer: STATE paper's χ(ε_dd=1.2) value if given numerically. STATE paper's E_ddi prefactor and Q-tensor form verbatim. Compare to SpinorBEC.jl convention. Status.\n\n### §3 Cross-reference table\n\n| Question | T40 finding implicating Q | Resolution | Discriminates |\n|---|---|---|---|\n| Q1 | All 5 F=1 points failed | F=1 numerical in Fig 1c? Or F=6-with-F-independence-asserted? | (a4) deep bug vs (c) paper-claim-wrong-at-F=1 |\n| Q2 | P4 fl_vortex JLD2 torus topology preserved but density not increased | Paper's initial-state procedure | (a4) angular-momentum-conserving-ITP-needed vs paper-procedure-mystery-solves-it |\n| Q3 | n_max factor 12000 deficit | χ-value or DDI-prefactor numerical | Reopens (a1) if mismatched |\n\n### §4 Implications for T42+ routing\n\n- If Q1 resolves to `F=6-only-Fig-1c, F-independence-asserted`: pivot investigation to F=6 reproduction OR document REFUTED-as-paper-F-independence-claim-not-verified-at-F=1 and propose paper-#5-seed `F-dependence-of-Yan-Li-Saito-droplet`. Tier 0.6 → 1.5 (refuted-with-published-finding).\n- If Q1 resolves to `F=1 numerical in Fig 1c, paper-claim verified`: deep-framework-audit (a4) is mandatory. T42 = theorist child-investigation seeded by Q2 procedural facts (e.g., angular-momentum-conserving ITP needed? grid refinement? free-space BCs)?\n- If Q2 reveals paper uses phase-imprint + L_z+f_z conservation while we use plain ITP: spawn fix-bug for angular-momentum-conserving ITP in rotating_basis path; tier 0.6 → 1.0 on fix-bug-success.\n- If Q3 reveals χ-numerical-discrepancy: reopen (a1), spawn sympy χ(ε_dd=1.2) cross-implementation; tier holds.\n- If all three Q resolve with paper-side-aligned + our impl correct: framework-deep-audit becomes the only path; tier holds at 0.7.\n\n### §5 Style guide\n\n- Quote paper verbatim where possible (a-c). DO NOT paraphrase critical numerical values.\n- Use calibration tags: [Established], [Plausible], [Speculative], [Unknown] per `runs/_loop/research/turn_39_Q1.md` precedent.\n- For each Q, include `status` field: RESOLVED / OPEN / PARTIAL.\n- Add a §Sources list at the end with: paper PDF page numbers, any cross-citations to derived LP-2011 / dipolar-droplet-review papers, any prior loop turn references.\n- If you cannot access the PDF for any reason, STATE the exact error and which `Read` tool invocation produced it. Do NOT proceed with speculation if PDF read fails — return `STATUS: PDF_INACCESSIBLE` and let director pivot.\n\n### §6 Out-of-scope (do NOT do this turn)\n\n- DO NOT derive new physics. (Theorist's job at T42 if Q2 reveals framework gap.)\n- DO NOT propose a fix-bug investigation. (Director spawns at T42 based on your findings.)\n- DO NOT critique T40 result interpretation. (Critic's job at T42 Update.)\n- DO NOT run julia, sympy, or any code. Text-only Research stage.\n- DO NOT speculate beyond paper content. If a Q is OPEN (paper silent), say so.\n\n### §7 Metrics block (required by judge.py)\n\nReport at the bottom of turn_41.md (JSON code block) with these machine-readable fields:\n- `pdf_accessible`: true | false\n- `q1_status`: \"RESOLVED\" | \"OPEN\" | \"PARTIAL\"\n- `q1_fig1c_F_value`: <integer or \"asserted-F-independent\" | \"unspecified\">\n- `q1_fig1c_verbatim_caption_quoted`: true | false\n- `q2_status`: \"RESOLVED\" | \"OPEN\" | \"PARTIAL\"\n- `q2_initial_state_procedure`: <string describing paper's procedure verbatim or summary if quoted>\n- `q2_angular_momentum_conservation`: \"yes\" | \"no\" | \"unspecified\"\n- `q2_grid_dx`: <numerical value or \"unspecified\">\n- `q2_grid_dt`: <numerical value or \"unspecified\">\n- `q2_bc_type`: \"free-space\" | \"large-box\" | \"unspecified\"\n- `q3_status`: \"RESOLVED\" | \"OPEN\" | \"PARTIAL\"\n- `q3_chi_value_at_1p2`: <numerical or \"unspecified\">\n- `q3_ddi_prefactor_matches_spinorbec`: true | false | \"unspecified\"\n- `t42_routing_recommendation`: \"F6-pivot\" | \"framework-deep-audit\" | \"angular-momentum-conserving-itp-fixbug\" | \"chi-sympy-cross-impl\" | \"close-as-paper-refuted\"\n- `n_sources_cited`: <integer>\n- `pages_read_from_pdf`: <list of integer page ranges>\n\n## STYLE / TONE\n\n- Concise. Per anko's `feedback_decision_style`. Pick a verdict and document.\n- Source-of-truth-citations matter more than prose. If paper says X verbatim, quote X.\n- If you find the paper actually contradicts memory's summary (e.g., memory says ε_dd=1.2 but paper Fig 1c is at ε_dd=1.3), flag it explicitly under [Unknown] → resolve-via-PDF tag.\n- ~2M effective budget; PDF is local file, fast to read. Total wall ≤ 30 min.",
  "observable_manifest": {
    "required": [
      "research_turn_41_md_exists_on_disk",
      "pdf_accessible",
      "q1_status",
      "q2_status",
      "q3_status",
      "t42_routing_recommendation",
      "n_sources_cited"
    ],
    "optional": [
      "q1_fig1c_F_value",
      "q2_initial_state_procedure",
      "q2_angular_momentum_conservation",
      "q3_chi_value_at_1p2",
      "q3_ddi_prefactor_matches_spinorbec",
      "pages_read_from_pdf",
      "q1_fig1c_verbatim_caption_quoted"
    ],
    "precondition_check": "test -f /tmp/yan_li_saito_2605.11670.pdf && test -s /tmp/yan_li_saito_2605.11670.pdf && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_39_Q1.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && echo 'precondition OK: paper PDF + T40 sim + T40 theorist + T39 Q1 research + memory all on disk'"
  },
  "success_criteria": [
    {
      "id": "research_md_on_disk",
      "metric": "research_turn_41_md_exists_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required; researcher must Write to the expected path."
    },
    {
      "id": "pdf_was_accessible",
      "metric": "pdf_accessible",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "If PDF actually inaccessible (Grep verified content but Read tool may behave differently), researcher must report so explicitly; director pivots."
    },
    {
      "id": "q1_resolved_or_partial",
      "metric": "q1_status",
      "operator": "in",
      "value": ["RESOLVED", "PARTIAL"],
      "tolerance": null,
      "rationale": "Q1 (Fig 1c F-value) is the load-bearing question; OPEN status means researcher couldn't even find the figure, which is a serious failure mode."
    },
    {
      "id": "q2_resolved_or_partial",
      "metric": "q2_status",
      "operator": "in",
      "value": ["RESOLVED", "PARTIAL"],
      "tolerance": null,
      "rationale": "Q2 (initial-state procedure) is the second load-bearing question; same logic as Q1."
    },
    {
      "id": "q3_resolved_or_partial_or_open",
      "metric": "q3_status",
      "operator": "in",
      "value": ["RESOLVED", "PARTIAL", "OPEN"],
      "tolerance": null,
      "rationale": "Q3 (χ-value + DDI prefactor) may be implicit in the paper; OPEN is acceptable here (paper may not state χ-value numerically)."
    },
    {
      "id": "routing_recommendation_present",
      "metric": "t42_routing_recommendation",
      "operator": "in",
      "value": ["F6-pivot", "framework-deep-audit", "angular-momentum-conserving-itp-fixbug", "chi-sympy-cross-impl", "close-as-paper-refuted"],
      "tolerance": null,
      "rationale": "Researcher must commit to a concrete next-step recommendation; this is the meta-output that orchestrates T42's role choice (theorist? critic? implementer? researcher?)."
    },
    {
      "id": "sources_cited_minimum",
      "metric": "n_sources_cited",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "At minimum: paper PDF + memory entry + one prior loop turn. Per Research stage §F1 'sets up Hypothesize with citation chain'."
    }
  ],
  "failure_modes": [
    {
      "if": "research_md_on_disk failed",
      "category": "operational",
      "next_action": "T42 = re-dispatch researcher with stricter file-path enforcement. If 2nd attempt fails, escalate to anko (subagent infrastructure problem)."
    },
    {
      "if": "pdf_was_accessible failed (researcher reports STATUS: PDF_INACCESSIBLE)",
      "category": "data_gap",
      "next_action": "T42 = director debugs PDF access (maybe permissions, maybe Read-tool limit on file size). If unresolvable, pivot to abstract+arXiv-HTML version via WebFetch with arXiv:2605.11670 URL. Or escalate to anko for manual paper-data dump."
    },
    {
      "if": "q1_resolved_or_partial failed (q1_status == OPEN)",
      "category": "data_gap",
      "next_action": "T42 = re-dispatch researcher with explicit page-range guidance (search PDF for 'F=1' / 'F=6' / 'F-independence' / figure caption text); if 2nd attempt fails, escalate."
    },
    {
      "if": "q1_fig1c_F_value resolves to 'asserted-F-independent' AND not F=1 numerical",
      "category": "scientific_paper_claim_unverified",
      "next_action": "T42 = critic Update with new evidence: paper claim is asserted not numerically verified at F=1. Recommend: (a) pivot investigation to F=6 reproduction (clearer test of paper's actual numerical work); (b) document REFUTED-paper-F-independence-claim as a paper-#5-candidate seed. Tier 0.6 → 1.0 (refuted-with-documented-finding)."
    },
    {
      "if": "q1_fig1c_F_value resolves to 'F=1' (paper-claim verified) AND q2 reveals angular-momentum-conserving ITP + phase-imprint init",
      "category": "framework_gap_identified",
      "next_action": "T42 = director spawns fix-bug child investigation 'rotating_basis-angular-momentum-conserving-ITP' (D2 service axis, justified by D1 yan-li-saito reproduction need). Implementer adds option to find_ground_state_rotating! for L_z+f_z conservation. Tier yan-li-saito 0.6 → 0.7 (data-gap closed, fix path identified)."
    },
    {
      "if": "q1_fig1c_F_value resolves to 'F=1' (paper-claim verified) AND q2 reveals plain ITP from any seed (no special procedure)",
      "category": "framework_deep_bug",
      "next_action": "T42 = theorist deep-framework-audit child investigation. Likely culprit: free-space BCs, grid resolution (our dx=0.44 a_ho vs paper's 0.014 a_ho, 31× coarser), or BUG-9 (energy_mu=NaN at rotating_basis μ estimator). Theorist scopes the audit. Tier yan-li-saito 0.6 → 0.7."
    },
    {
      "if": "q3 reveals chi-value or DDI-prefactor mismatch",
      "category": "scientific_a1_reopened",
      "next_action": "T42 = implementer_sympy dispatch: compute χ(ε_dd=1.2) under our truncate-to-zero prescription and paper's exact prescription, compare numerical values. If mismatch ≥ 5%, (a1) reopens. If ≤ 5%, (a1) stays dead and (a4) remains primary."
    },
    {
      "if": "all three Q resolve cleanly with no mismatch and no procedural gap",
      "category": "framework_deep_audit_required",
      "next_action": "T42 = theorist deep-framework-audit dispatch (BUG-9 μ-estimator, rotating_basis F=1 + DDI code path, grid-refinement test). Tier yan-li-saito 0.6 → 0.7."
    },
    {
      "if": "cost_within_budget failed (research exceeds 4M effective)",
      "category": "operational",
      "next_action": "Acceptable up to per-turn 6M cap; if researcher exceeds 6M, escalate to anko for context-management discussion."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 4000000
  },
  "budget": {
    "expected_cost_eff": 2200000,
    "expected_wall_time_sec": 1200,
    "split_by_subtask": {
      "read_pdf_in_chunks": 900000,
      "read_required_loop_files_5": 400000,
      "extract_verbatim_quotes_for_q1_q2_q3": 500000,
      "write_research_brief_with_routing_recommendation": 400000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update",
    "if_success_tier_becomes": 0.7,
    "if_success_falsifier_update": "T41 researcher reads paper PDF and resolves Q1 (Fig 1c F-value), Q2 (initial-state procedure + grid/dt/BC), Q3 (χ-value + DDI prefactor). Output discriminates (a4) framework-deep-bug from (c) paper-claim-wrong. T42 routing per §6 failure_modes: pivot-to-F6 OR fix-bug-angular-momentum-ITP OR deep-framework-audit OR reopen-a1. Tier yan-li-saito 0.6 → 0.7 (data-gap closed); subsequent T42-T44 cycle can lift to 1.0+ on concrete-fix-path or close-as-paper-refuted.",
    "if_refuted_advance_to_stage": "Research (retry with WebFetch arXiv:2605.11670 if PDF read fails)",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "T42 critic Update incorporates research findings; T43+ depends on routing. Meta-critic-placement (priority 50) observation: T40→T41 cascade shows REFUTED-without-data-gap-resolution requires Research re-injection; this strengthens the meta-hypothesis that the standard verify-claim flow needs an explicit data-gap-detection branch. Meta moves at T44+ once yan-li-saito root cause is identified."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_41.json` (policy=JULIA_GPU_OK; researcher in allowed_workloads; window 20084 min left).
- [x] Read `runs/_loop/state.json` history T37-T40 + investigations.yan-li-saito-2026-reproduction.next_stage_action (line 2165, explicit T41 directive: critic/researcher to narrow + parallel paper-fetch arXiv:2605.11670).
- [x] Read `runs/_loop/seed.md` (yan-li-saito priority 1; Tier-3 candidate path with anchor numbers).
- [x] Read `runs/_loop/director/turn_40.md` end-to-end (prior turn's dispatch shape + theorist-Design-success-criteria mismatch with implementer-Execute-metrics → judge INCONCLUSIVE explanation).
- [x] Read `runs/_loop/sim/turn_40.md` end-to-end (T40 substantive REFUTED; theorist verdict matrix row 4; recommended T41+ routing items 1-3 with PDF-fetch as item 1).
- [x] Read `runs/_loop/judge/turn_40.json` (judge marked INCONCLUSIVE due to contract-shape mismatch — success_criteria metrics expected theorist Design fields but implementer reported Execute fields; substantive science verdict is REFUTED).
- [x] Read `runs/_loop/theorist/turn_40.md` §0.5 (E_DDI=0 isotropy argument), §2.2 (energy-balance table), §11 (Q1 query for paper Fig 1c F-value), §12 (chained directive to implementer that ran T40 Execute).
- [x] Read `runs/_loop/research/turn_39_Q1.md` (precedent for researcher dispatch shape; Q1 resolution closing (a1) LHY-χ-prescription).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` lines 13 (PDF local copy), 30-82 (paper Eq 1, normalization, numerical, anchor numbers, Q1-Q5 open questions, likely failure modes), 112-122 (likely failure modes including F=1 test coverage).
- [x] Verified PDF accessibility: `/tmp/yan_li_saito_2605.11670.pdf` exists with 18848 lines of extractable text content (Grep verified).
- [x] investigation_id `yan-li-saito-2026-reproduction` valid in state.investigations.
- [x] stage_advancing_to=Research is the canonical move per §F1 verify-claim with REFUTED+data-gap (Research re-injection when new evidence is the bottleneck for Update).
- [x] subagent_type=researcher matches §F1 Research row.
- [x] success_criteria are machine-evaluable: 7 criteria covering file-existence, PDF accessibility, Q1/Q2/Q3 status, routing recommendation, sources cited.
- [x] failure_modes cover 8 scenarios: operational (no md), data-gap (PDF inaccessible / Q1 OPEN), 4 routing branches (F6-pivot / fixbug-ang-mom / deep-audit / a1-reopen), all-clean (audit-required), budget-exceeded.
- [x] observable_manifest precondition_check is literal bash chain (5 test -f + 1 test -s + echo) — exits 0 before researcher invocation if all files present.
- [x] Budget 2.2M effective + 20-min wall fits within scheduler window + cost_cap_per_turn_effective (6M). Tolerance_overrides set tighter cost_cap (4M) for this researcher-text-only stage.
- [x] §A6 research-first citations: paper PDF, T39 Q1 research, theorist T40 §11, sim T40 §7, state.json next_stage_action, memory anchor, AI Scientist v2, Reflexion, grounded-autonomous-research, feedback-manuscript-is-not-essence, director.md §F1 Research row.
- [x] §A5 D1 PRIMARY articulated (researcher closes data-gap blocking (a4) vs (c) discrimination); D3 implicit (lit-grounded by paper-source-of-truth); manuscript NOT primary.
- [x] investigation_update has explicit success/refute branches and per-Q-resolution T42 routing (8 routing scenarios).
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — yan-li-saito priority 1 + clear next step + cascade continuity.
- [x] Considered switching to meta-critic-placement (priority 50): rejected per §B2 interleaving rule; meta picks up after current investigation closes.
- [x] Considered NOOP: rejected — clear high-leverage actionable directive (~2M effective unblocks 2 downstream paths).
- [x] Considered Update (critic) directly: rejected — critic cannot productively re-narrow without new evidence (the paper PDF). T38/T39 already saturated the verbal-critique cycle.
- [x] Considered Hypothesize (theorist re-design): rejected — theorist at T40 derived correct (E_DDI=0) prediction; hypothesis space is well-articulated, data-gap is the bottleneck.
- [x] Considered Execute (more GPU): rejected — cost prohibitive (~6M effective) and would just be a parameter sweep without paper-side anchoring; need paper data to inform what to sweep.
- [x] Honored state.json next_stage_action verbatim: "T41 must be critic/researcher to narrow these. Parallel: paper-fetch arXiv:2605.11670 to close (c) data gap" → chose researcher path because researcher-PDF-read closes the data-gap that critic needs.
- [x] Honored sim/turn_40.md §7 recommended T41+ routing item 1: "Spawn researcher PDF-fetch".
- [x] Honored theorist/turn_40.md §11 research_queries Q1: Fig 1c F-value question is THE blocker.
- [x] `consumed_seed_md: false` — same investigation, no new seed entry.
- [x] Drift advisory DRIFT_COST_INFLATION (cost_inflation = 1.576 at T40): respected by keeping T41 at researcher text-only (~2.2M) vs T40's 18.9M GPU+chained run. Cost trajectory inverts.
- [x] Drift advisory DRIFT_MANUSCRIPT_DELTA_ZERO: ignored per `feedback_manuscript_is_not_the_essence.md`.
