---
turn: 30
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Research
stage_advancing_to: Hypothesize
topic_tags: [yan-li-saito-2026, tier3-candidate, hypothesize-stage, framework-gap-mapping, lima-pelster-chi, ddi-prefactor-convention, free-space-itp, l_z-conservation-itp, flux-closure-torus, paper-reproduction]
paper_section: null
depends_on: [29, 28, 27, "runs/_loop/judge/turn_29.json", "runs/_loop/by_tag/barnett-mechanism-confirmed.md", "runs/_loop/state.json#yan-li-saito-2026-reproduction", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Hypothesize-stage theorist artifact runs/_loop/theorist/turn_30.md: (a) maps Yan-Li-Saito 2026 PRL Eq 1 Hamiltonian to SpinorBEC.jl notation (kinetic, contact, DDI, LHY, Zeeman) term-by-term with explicit prefactor conversion table; (b) resolves 5 open audit questions from the memory file (χ(ε_dd) integrand match, c_dd vs μ_0(gμ_B)²/8π factor, free-space ITP convergence path, ℓ=1 phase-imprint + L_z+f_z conservation ITP route, state_zoo flux-closure-torus availability); (c) produces a verify-claim falsifier list: ≥3 falsifiable predictions where SpinorBEC.jl would visibly disagree with paper if any framework gap is real (e.g. torus density peak, ⟨f_z⟩ at ℓ=1, Larmor slope ω_L/B_y), each with quantitative discriminator threshold."
---

# Turn 30 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1 as of T29 state.json update, tier_current 0 → tier_target 3).
- **Stage transition**: **Research → Hypothesize**. Per state.json `next_stage: "Hypothesize"` and `next_stage_action: "theorist maps Yan-Li-Saito 2026 PRL Hamiltonian to SpinorBEC.jl notation; identifies framework gaps..."` (set by T29 director after critic §8 recommendation). The Research stage is substantively complete: memory file `yan_li_saito_2026_barnett_paper.md` (164 lines) contains the paper Hamiltonian (Eq 1), normalization scheme (L₀, T₀, D₀, B₀), Eu-151 anchor numbers (L₀=16.35μm, T₀=0.64s for F=1 N=15000 ε_dd=1.2), numerical method (pseudospectral dx≈10⁻³, dt≈10⁻⁷), and 5 explicit open theorist questions Q1-Q5. The citation chain (Li-Saito 2024 [64], Barnett original [65], Lima-Pelster LHY [66,67], single-domain precession analogy [70]) is enumerated. No additional Research turn is needed before Hypothesize.
- **Tier**: 0 → ~0.5 on Hypothesize success. Hypothesize stage produces theorist-derived alignment + falsifier list, not empirical verification — Tier 1 requires Execute + Analyze first. Full Tier 3 path: Hypothesize → Design → Execute (Julia GPU) → Analyze → Update (critic) → Document. Estimate 4-6 turns end-to-end if no framework gap is fatal.
- **Falsifiers** (anticipated, to be formalized by theorist at this turn):
  - F1: Torus GS density peak n_max (D₀ units) within ±10% of paper Fig 1c (~13000).
  - F2: ℓ=1 state ⟨f_z⟩ within ±0.01 of paper-claimed 0.04 (Barnett mechanism signature).
  - F3: Larmor slope dω_L/dB_y (Fig 2c) matches γ=gμ_B/ℏ to ±5%.
  - F4 (gap-discriminator): if our χ(ε_dd) implementation differs from paper integrand at ε_dd=1.2, predict by how much LHY energy will deviate (computable in advance from Lima-Pelster integral mismatch).
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16` (closed at T29, tier 3.0, the project's first Tier-3 claim) — no longer in active rotation; cross-linked from this investigation.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, current_stage=documented, blocked_on="needs julia P3 validation against anko Klaus phi sweep data") — still blocked; could be unblocked by an implementer_julia_cpu turn later in this window if yan-li-saito stalls.
  - `fullbdg-f6-polar-3000x` (dormant priority 99) — closed-form alternatives contain bug; do NOT touch.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

This investigation has zero prior loop turns of its own — T30 is its FIRST active turn. Audit the cross-cutting trail that activated it:

| Turn | Stage (of barnett) | Verdict | What happened (relevant to yan-li-saito activation) |
|---|---|---|---|
| T27 | Execute (barnett γ_dr=K3=0 falsifier) | PASS, 4/4 criteria | Coherent mechanism confirmed; established the "next investigation should be a Tier-3 external benchmark" framing. |
| T28 | Update (barnett critic Heisenberg-Slichter) | CORROBORATE | Critic §8 explicit recommendation: "T29 director → Document stage (implementer_text) THEN activate yan-li-saito as priority-1 successor." |
| T29 | Document (barnett closure + tier 3.0 + yan-li-saito activation) | INCONCLUSIVE-by-judge-metric-name-mapping (substantively PASS per sim §3 validations: jq state.json checks 4/4 PASS, memo created with 9 sections + 5 Bloch-Siegert + 2 T23 mentions, barnett.md appended T29 total=19) | barnett closed tier 3.0; yan-li-saito priority set to 1; active_investigation_id switched. The judge INCONCLUSIVE is a metric-name mismatch (sim reported `memo_created: true` rather than the criterion's literal expression `file_exists(...)`); the underlying work is verified PASS. State.json reflects all updates correctly. |

**Trajectory check**: Subagent rotation T26-T29 was implementer_julia / critic / implementer_text. Theorist last ran T27 (3 turns ago) and produced the Barnett closed form — clean, no saturation. Hypothesize stage in verify-claim template is theorist by definition (no rotation concern). Researcher last ran T14 (16 turns ago) but Research stage for this investigation is substantively done in memory; no researcher need.

**Judge T29 INCONCLUSIVE response**: per director protocol §B3 verdict table, INCONCLUSIVE → "repeat current stage with refined approach." However, this is a JUDGE METRIC NAME mismatch, not a substantive INCONCLUSIVE. Reading sim/turn_29.md §3 commands shows all 4 state-assertion jq queries returned the expected values (3.0, "closed", 1, "yan-li-saito-2026-reproduction"); the memo grep -c showed 5 and 2 (both pass the ≥2 and ≥1 thresholds); barnett.md appended T29 with total=19. The substantive Document stage IS complete. The fix forward is structural (judge.py needs to accept "memo_created: true" as satisfying "file_exists(...)" — out of director scope), not re-running T29. Proceeding to T30 advance of yan-li-saito; if anko or future critic wants T29 re-verified, the state.json + memo are inspectable.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → **Hypothesize** → Design → Execute → Analyze → Update → Document → closed). Same template as barnett-mechanism (which just closed at Tier 3). Re-using the template means we already have a proven path: theorist Hypothesize → theorist Design → implementer_julia Execute → implementer Analyze → critic Update → implementer_text Document.
- **Role for stage Hypothesize**: per director §F1 row "Hypothesize": "theorist — formal claim + predicted signature + falsifier list (each falsifier is a falsifiable experiment)". This is the canonical Hypothesize role. The investigation's `next_stage_action` (set by T29 director) names "theorist" implicitly via the deliverable being a theorist-turn artifact (`runs/_loop/theorist/turn_30.md`).
- **Why Hypothesize now (vs other options)**:
  - Template-mandatory after Research. Research stage is substantively done in `yan_li_saito_2026_barnett_paper.md` (anko did the paper triage 2026-05-16). The 5 open theorist Q1-Q5 are exactly Hypothesize-stage material (mapping paper notation to our notation + identifying framework gaps).
  - Skipping to Design would be premature: Design needs the formal claim + falsifier list (Hypothesize outputs) to write a julia-runnable config. We don't even know the right LHY mode (`:scalar` per memo, but bit-exact χ integrand needs verification) or whether free-space ITP converges in our framework.
  - Switching to `klaus-magnetostir-bch-leak` (priority 3): rejected. Still blocked on julia P3 validation (which is a separate Execute-stage task; the BCH-leak investigation is at `documented` stage waiting for empirical comparison data, not a free Hypothesize advance). yan-li-saito at priority 1 has a clear actionable next step; klaus-bch-leak does not until someone runs the P3 julia.
  - NOOP: rejected. yan-li-saito is freshly activated priority-1, scheduler allows theorist (JULIA_GPU_OK, full whitelist), cost is ~1-2M (theorist baseline). NOOP would burn the window without advancing the project's second Tier-3 candidate.
  - Re-running T29 to fix judge INCONCLUSIVE: rejected. The substantive work is verified done via sim/turn_29.md §3 jq output (4/4 state assertions PASS, 9 memo sections present, files appended/created); the INCONCLUSIVE is a judge-side metric-name mapping issue, not a deliverable issue. Re-running would waste cost on a structural judge.py bug that should be fixed in the harness, not by retry.
  - Researcher follow-up before Hypothesize: rejected. The memory file already enumerates 5 references and 5 open theorist questions, and the paper PDF is at `/tmp/yan_li_saito_2605.11670.pdf` for cross-checking. Additional researcher passes would duplicate anko's 2026-05-16 triage without new information.

## 4. Research grounding (§A6)

- **External references (load-bearing for Hypothesize dispatch)**:
  - **Yan, Li, Saito, PRL 136 186502 (2026) [arXiv:2605.11670]** — the paper being reproduced. Eq 1 (H = E_kin + E_s + E_ddi + E_LHY + E_B), Fig 1c (torus GS at F=1 ε_dd=1.2), Fig 2c (mechanical Larmor precession ω_L vs B_y). The theorist must read this verbatim and produce a term-by-term mapping table to SpinorBEC.jl src/ notation. Local copy: `/tmp/yan_li_saito_2605.11670.pdf`.
  - **Lima, Pelster, Phys. Rev. A 84, 041604(R) (2011)** [memory ref [66]] — the χ(ε_dd) Lima-Pelster integral that paper Eq 1 cites. SpinorBEC.jl has `lima_pelster_Q5` in `src/hamiltonian/interactions/lhy/dispatch.jl` (per memory file `lhy_refactor_2026_05_12.md`); bit-exact match must be verified at the integrand level (Re ∫₀^π sinθ [1 + ε_dd(3cos²θ - 1)]^(5/2) / 2 dθ).
  - **Li, Saito, Phys. Rev. Research 6, L042049 (2024) [arXiv:2402.18885]** [memory ref [64]] — prior paper from same group on torus flux-closure droplet in spinor dipolar BEC, Eu-151 context. Cited as the antecedent of the 2026 paper. Theorist should at least know it exists for citation chain completeness.
  - **CLAUDE.md DDI convention** — the project uses `c_dd = μ_0 μ²` (no 4π), `Q_αβ = k̂_αk̂_β - δ_αβ/3` (no 1/(4π)), `Q(k=0)=0`. Paper uses `μ_0(gμ_B)²/8π` in E_ddi. The factor conversion is `c_dd_ours = 2 × (paper coefficient)` if the integrand prefactor (1-3cos²θ)/r³ is used uniformly. Theorist must produce the explicit prefactor table (no hand-wave).
  - **Prior turn `runs/_loop/by_tag/barnett-mechanism-confirmed.md`** — the project's first Tier-3 claim. Documents the pattern of explicit closed-form vs empirical match at 0.04-5.5% across 4 quantities. The yan-li-saito Hypothesize stage should follow the same pattern: pre-register quantitative predictions (n_max, ⟨f_z⟩, dω_L/dB_y) BEFORE julia run, so Analyze stage can use them as falsifiers.
  - **Anthropic context engineering essay (director §G)** — "Write / Select / Compress / Isolate context strategies." The Hypothesize stage exemplifies Compress: distilling the 164-line memory file + paper PDF + framework gaps into a single Hypothesize artifact (≤500 lines) the implementer can consume at Design stage without re-reading source material.
- **Why these inform the dispatch**: the Hypothesize stage value is not just "write down a hypothesis" — it is "write down a hypothesis with concrete falsifiable predictions and explicit framework alignment that the implementer can consume at Design stage." The Yan-Li-Saito paper's Eq 1 prefactor convention differs from ours (μ_0/(4π) vs no-4π) in a way that must be resolved BEFORE implementer writes a YAML config, or the run will silently use wrong DDI strength. The χ(ε_dd) integrand similarly: our `:scalar` mode computes Lima-Pelster Q5, but a sign or factor-1/2 difference at ε_dd=1.2 would silently produce wrong LHY energy.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify existing physics — this turn maps an external paper's claims to our framework, identifying any framework gaps that need fixing before the Tier-3 verification can be attempted). Hypothesize is the gate that filters "is this verification possible in our framework?" from "is this verification correct?"
- **Tier ladder position**: 0 → ~0.5 (Hypothesize stage produces theorist mapping + falsifier list; not yet empirically tested). Tier 3 requires full external-paper benchmark match, which needs Execute (Julia GPU run) + Analyze + Update at minimum.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. Hypothesize stage outputs are loop-internal theorist derivations + falsifier table, NOT a paper section. If Tier 3 is later achieved, the manuscript writeup is a separate anko-authorized event.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "rationale": "T29 closed barnett-mechanism at Tier 3.0 (project's first) and activated yan-li-saito as priority-1 successor per critic §8 recommendation. yan-li-saito current_stage=Research is substantively complete (memory file yan_li_saito_2026_barnett_paper.md contains full Eq 1 Hamiltonian, normalization, anchor numbers, citation chain, 5 explicit open theorist questions). Per verify-claim template the next stage is theorist Hypothesize: map paper Hamiltonian to SpinorBEC.jl notation, resolve 5 framework-gap questions, produce ≥3 quantitative falsifiers. This is D1 (verify external physics in our framework) and is the natural Tier-3 path. Cost ~1.5M theorist-baseline well within budget (5h cap 100M; scheduler JULIA_GPU_OK, theorist allowed). Skipping Hypothesize and going straight to Execute would silently inherit unresolved framework-gap risks (DDI prefactor convention mismatch could produce wrong DDI strength; χ(ε_dd) integrand mismatch could produce wrong LHY energy); both would yield false-positive or false-negative paper reproduction. Hypothesize is the gate that filters those before julia cost.",
  "brief": "Hypothesize stage for yan-li-saito-2026-reproduction (priority 1, tier 0 → 3 target). Produce runs/_loop/theorist/turn_30.md.\n\n## REQUIRED READING (in order)\n1. Memory file yan_li_saito_2026_barnett_paper.md (the full 164-line paper triage; quote Eq 1, normalization L₀/T₀/D₀/B₀, anchor numbers ⟨L_z⟩≃0.96/⟨f_z⟩≃0.04 at ℓ=1, χ(ε_dd) integrand).\n2. Local paper copy at /tmp/yan_li_saito_2605.11670.pdf — read Sec II (model + numerical), Sec III (results torus GS), Sec IV (results Larmor + chiral). Quote Eq 1 verbatim. Note Fig 1c reference parameters, Fig 2c B_y range, exact ε_dd=1.2 line.\n3. CLAUDE.md DDI convention section: 'c_dd=μ₀μ² (no 4π), Q_αβ=k̂_αk̂_β−δ_αβ/3 (no 1/(4π)), Q(k=0)=0.'\n4. src/hamiltonian/interactions/lhy/dispatch.jl — find lima_pelster_Q5 implementation; quote the χ integrand verbatim.\n5. src/hamiltonian/interactions/lhy/ — survey AbstractLHY hierarchy + :scalar mode (see CLAUDE.md LHY section, AbstractLHY hierarchy with TabulatedLHY parent).\n6. src/workflow/initialization/state_zoo.jl — survey 22 named init_psi_* builders; report which (if any) produces a flux-closure-torus or ℓ=1 phase-imprint state for F=1.\n7. Cross-link: runs/_loop/by_tag/barnett-mechanism-confirmed.md (the project's first Tier-3 closure pattern; emulate its 'pre-register quantitative predictions BEFORE julia run' discipline at this turn).\n\n## DELIVERABLE: runs/_loop/theorist/turn_30.md\n\n### Section 1: Paper Hamiltonian → SpinorBEC.jl notation mapping\nProduce a term-by-term table with EXPLICIT prefactor conversion. Columns: paper symbol (Eq 1), paper prefactor (including μ_0, gμ_B, factors of π), SpinorBEC.jl symbol (workspace/hamiltonian field), our prefactor convention (per CLAUDE.md), conversion formula, status (MATCH / DIFFER / UNKNOWN).\n\nMust cover: E_kin, E_s (contact), E_ddi (incl. (1-3cos²θ)/r³ kernel convention), E_LHY (incl. χ(ε_dd) prefactor + integrand), E_B (Zeeman -gμ_B f·B). At least 5 rows, no hand-waving.\n\n### Section 2: Resolve 5 open audit questions (from memory file)\nFor each Q1-Q5:\n- Q1: Does our `:scalar` LHY χ(ε_dd) integrand match paper's Re ∫₀^π sinθ [1 + ε_dd(3cos²θ - 1)]^(5/2) / 2 dθ? Quote both integrands. Verdict: bit-exact MATCH, factor-of-X MISMATCH (with X), or UNKNOWN-needs-sympy.\n- Q2: DDI prefactor: paper uses μ_0(gμ_B)²/8π in E_ddi; we use c_dd=μ_0μ² in (1-3cos²θ)/r³ kernel. Compute the factor ratio explicitly. If μ=gμ_B (which it is for Eu-151 hyperfine F-state), the ratio should be... derive it. State the exact numerical value of c_dd_ours / c_dd_paper-equivalent at our convention for Eu-151 F=1 ε_dd=1.2.\n- Q3: Free-space ITP convergence: can our find_ground_state run with V_trap=0 in YAML schema? Read parsing_blocks.jl for trap=none or zero-trap path. If YES, note the YAML knob. If NO, identify what code change is needed (a 1-line guard removal or a deeper refactor).\n- Q4: ℓ=1 phase-imprint + (L_z+f_z) conservation ITP path: does find_ground_state accept a phase-imprint init AND respect angular-momentum conservation? Read solvers/ground_state/ for any L_z constraint mode. If NO, identify the gap (likely no L_z constraint exists; suggest project_to_l_z_subspace approach or workaround).\n- Q5: state_zoo flux-closure-torus builder: enumerate state_zoo.jl init_psi_* names. Identify if any match flux-closure-torus topology for F=1. If NO, state explicitly that a new builder init_psi_flux_closure_torus_f1 is required (do NOT write it this turn — that is Design or Execute stage).\n\nFor each question, mark severity: BLOCKER (can't run without code change), KNOWN-ADJUSTMENT (needs YAML knob anko hasn't set), or CLEAR (works as-is).\n\n### Section 3: Falsifier list (≥3 quantitative falsifiers)\nFor each falsifier:\n- ID (kebab-case)\n- Predicted observable (with paper-Fig citation)\n- Predicted value (from paper text or figure read)\n- Tolerance (be specific: ±10% on density peak, ±0.01 on ⟨f_z⟩, ±5% on Larmor slope)\n- What it falsifies: if observed disagrees, which framework gap (Q1-Q5) is the leading suspect\n- Run cost estimate (small / medium / large GPU job)\n\nMust include:\n- F1: torus GS density peak n_max at F=1 ε_dd=1.2 (Fig 1c reading)\n- F2: ⟨f_z⟩ at ℓ=1 state (~0.04 per paper) — the Barnett signature\n- F3: Larmor slope dω_L/dB_y (Fig 2c) ≈ γ=gμ_B/ℏ within ±5%\n- Optional F4: any GAP-DISCRIMINATOR falsifier — a deliberately mismatched quantity that would tell us WHICH framework gap (Q1-Q5) caused the mismatch, e.g. if LHY contribution dominates n_max trend, then Q1 χ(ε_dd) mismatch is leading; if DDI contribution dominates, Q2 prefactor mismatch is leading.\n\n### Section 4: Design-stage handoff plan\n1-2 paragraphs. What does Design stage (theorist or implementer) need to do at T31? Specifically: which YAML knobs, which framework adjustments (if any from Q3-Q5), which initial state, which GPU cost estimate (32³ vs 64³ grid, F=1 only so D=3 cheap vs F=6 D=13).\n\n### Section 5: Pre-flight cost sanity check\nState: estimated full Hypothesize→Execute→Analyze chain cost in effective tokens + GPU wall-time. If the answer to Q3 (free-space ITP) is BLOCKER (requires code change), state cost of the code-change Design subroutine separately.\n\n## NON-DELIVERABLES (explicit)\n- Do NOT write any src/*.jl code. Hypothesize is text-only.\n- Do NOT run julia. No julia in this turn.\n- Do NOT write a paper section or manuscript paragraph.\n- Do NOT modify state.json (T31 director will do that based on this Hypothesize verdict).\n- Do NOT write runs/_loop/sim/turn_30.md — theorist artifacts go to runs/_loop/theorist/turn_30.md.\n- Do NOT skip Q1-Q5; if any cannot be resolved this turn, mark UNKNOWN-needs-X explicitly (do not silently omit).\n- Do NOT create the design-stage YAML or julia runscript (that is T31 Design's job).\n\n## STYLE\n- Quantitative everywhere. Numbers > prose. Reference figure/equation numbers, not 'Fig 1' alone.\n- Acknowledge sign-chain risk: the barnett investigation suffered a 5-turn sign-error chain (T23→T24→T27→T28) because rotating-frame Larmor sign was inherited wrong. Paper uses μ_0/(4π); we use no-4π; explicit factor table prevents repeat.\n- Cross-reference barnett-mechanism-confirmed.md as 'project's first Tier-3 precedent' — this investigation aims to be the second.\n\n## SUCCESS-CRITERION COMPATIBILITY\nThe success criteria (§6 below) include grep_count on '## Section', 'BLOCKER', 'falsifier', etc. Use those exact strings in section headers and falsifier IDs.",
  "observable_manifest": null,
  "success_criteria": [
    {
      "id": "theorist_artifact_created",
      "metric": "file_exists_runs_loop_theorist_turn_30_md",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Hypothesize-stage primary deliverable. Without the artifact, no downstream Design can run."
    },
    {
      "id": "hamiltonian_mapping_table_present",
      "metric": "grep_count_E_kin_OR_E_ddi_OR_E_LHY_in_theorist_turn_30",
      "operator": ">=",
      "value": 5,
      "tolerance": null,
      "rationale": "Section 1 must produce a term-by-term mapping table covering at least 5 Hamiltonian terms (E_kin, E_s, E_ddi, E_LHY, E_B). At least 5 mentions of these symbol stems is the minimum signal."
    },
    {
      "id": "five_open_questions_resolved",
      "metric": "grep_count_Q1_OR_Q2_OR_Q3_OR_Q4_OR_Q5_in_theorist_turn_30",
      "operator": ">=",
      "value": 5,
      "tolerance": null,
      "rationale": "Section 2 must explicitly resolve Q1-Q5 from the memory file; at least 5 mentions of these labels is the minimum signal."
    },
    {
      "id": "falsifier_list_minimum_3",
      "metric": "grep_count_falsifier_id_kebab_case_in_theorist_turn_30",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "Section 3 requires at least 3 quantitative falsifiers (F1, F2, F3 minimum)."
    },
    {
      "id": "severity_classification_present",
      "metric": "grep_count_BLOCKER_OR_KNOWN_ADJUSTMENT_OR_CLEAR_in_theorist_turn_30",
      "operator": ">=",
      "value": 5,
      "tolerance": null,
      "rationale": "Section 2 must classify severity of each Q1-Q5 framework gap; at least 5 severity labels is the minimum signal."
    },
    {
      "id": "ddi_prefactor_factor_explicit",
      "metric": "grep_count_c_dd_per_paper_OR_prefactor_ratio_OR_factor_of_in_theorist_turn_30",
      "operator": ">=",
      "value": 1,
      "tolerance": null,
      "rationale": "Q2 requires an EXPLICIT numerical prefactor ratio between our c_dd convention and the paper's μ_0(gμ_B)²/8π. A hand-wave 'should be the same' is rejected."
    },
    {
      "id": "design_handoff_present",
      "metric": "grep_count_Design_OR_T31_in_theorist_turn_30",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "Section 4 must specify what T31 Design stage needs to do; without this the chain breaks."
    }
  ],
  "failure_modes": [
    {
      "if": "theorist artifact missing or empty",
      "category": "operational",
      "next_action": "T31 = director re-dispatches theorist with TIGHTENED brief (drop Section 5 cost sanity, keep only Section 1-3 mandatory). No tier change (Hypothesize stage just doesn't advance; current_stage stays Research)."
    },
    {
      "if": "Section 2 Q1-Q5 not all resolved (any missing or vague UNKNOWN without justification)",
      "category": "operational",
      "next_action": "T31 = director re-dispatches theorist with explicit instruction: 'Re-read memory file Q1-Q5 and produce a verdict for each. UNKNOWN-needs-X is acceptable only with explicit X.' May also dispatch researcher to fill specific gaps if Q1 (Lima-Pelster integral) needs literature."
    },
    {
      "if": "theorist identifies Q2 (DDI prefactor) mismatch as BLOCKER (our DDI is silently 2× or 4× paper)",
      "category": "scientific_refuted",
      "next_action": "T31 = director dispatches critic Cross-check before any Execute. If critic confirms BLOCKER, T32 = implementer to either (a) write a YAML-side prefactor multiplier or (b) add a paper_convention_mode flag to make_workspace. Either way, Tier 3 is delayed but not refuted — framework gap is fixable. Update yan-li-saito investigation hypothesis: 'reproducibility possible WITH framework-gap fix at Q2 prefactor'."
    },
    {
      "if": "theorist identifies Q3 (free-space ITP) as BLOCKER (V_trap=0 path doesn't exist or doesn't converge)",
      "category": "data_gap",
      "next_action": "T31 = director dispatches implementer_text to add minimal V_trap=0 YAML knob if missing. ITP convergence test at T32 (light Julia CPU). If V_trap=0 path exists but ITP diverges (self-bound state requires careful init), that is a Design-stage problem; T32 = theorist Design how to init close to droplet attractor."
    },
    {
      "if": "theorist identifies Q5 (state_zoo flux-closure-torus) as BLOCKER (no builder, requires new init_psi_*)",
      "category": "data_gap",
      "next_action": "T31 or T32 = implementer_text adds init_psi_flux_closure_torus_f1 to state_zoo.jl following the 22-named-builder pattern (memory: state_zoo_yaml_integration_wip.md). This is a 1-screen wrapper around init_psi(state=:flux_closure_torus,...) IF underlying state mode exists; if not, Design-stage theorist derives the topology first."
    },
    {
      "if": "theorist writes paper section or src/ code (out of scope)",
      "category": "framework_error",
      "next_action": "T31 = director rolls back src/ changes; preserves theorist text artifact only; re-affirms Hypothesize is text-only and feedback_manuscript_is_not_the_essence."
    },
    {
      "if": "wall_time > 600 s for theorist (Hypothesize baseline ~3-5 min)",
      "category": "operational",
      "next_action": "Token budget likely exceeded. T31 director assesses partial artifact; if Section 1-3 present, accept and proceed to Design with deferred Section 4-5. If only Section 1-2 present, re-dispatch with budget cap warning."
    },
    {
      "if": "theorist artifact treats memory file as authoritative without quoting the paper Eq 1 directly",
      "category": "operational",
      "next_action": "T31 = director re-dispatches with explicit instruction to read /tmp/yan_li_saito_2605.11670.pdf and quote Eq 1 verbatim. Memory file is anko's triage; the paper is the source of truth. The sign-chain risk from barnett T23 (inherited from prior derivation without checking the source convention) must not be repeated."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000,
    "wall_time_sec_cap": 900
  },
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 480,
    "split_by_subtask": {
      "read_paper_and_memory_and_code_survey": 600000,
      "section_1_hamiltonian_mapping": 400000,
      "section_2_five_questions": 400000,
      "section_3_falsifier_list": 250000,
      "section_4_5_handoff_and_cost": 150000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Design",
    "if_success_tier_becomes": 0.5,
    "if_success_falsifier_update": null,
    "if_refuted_advance_to_stage": "Research",
    "if_refuted_tier_becomes": 0,
    "next_falsifier_to_test_after": "First implementer-runnable falsifier from theorist Section 3 — likely F1 (torus GS density peak) since it requires only ITP (no dynamics), so it is the lowest-cost first cut. F2 (⟨f_z⟩ at ℓ=1) requires the ℓ=1 phase-imprint path which may need Q4 code work first. F3 (Larmor slope) requires both ground state AND a B-field dynamics scan, costliest. Default-recommended order: F1 → F2 → F3 unless theorist flags a different sequencing."
  },
  "consumed_seed_md": true
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_30.json` (policy=JULIA_GPU_OK, all 9 workload classes incl. theorist allowed; 1250839 s window left; VRAM 12.5 GB free; foreign_julia=0). Theorist is text-only — no GPU/julia contention.
- [x] Read `runs/_loop/state.json` lines 1480-1622 (active_investigation_id=yan-li-saito-2026-reproduction, current_stage=Research, next_stage=Hypothesize, priority=1, tier 0 → 3). barnett-mechanism-2026-05-16 confirmed closed at tier 3.0.
- [x] Read `runs/_loop/seed.md` (priority 1 was barnett, now closed; priority 2 yan-li-saito was promoted to priority 1 at T29; klaus-bch-leak at priority 3 still blocked).
- [x] Read `runs/_loop/director/turn_29.md` in full (the prior dispatch that closed barnett and activated yan-li-saito; clear handoff with `next_falsifier_to_test_after` naming theorist Hypothesize for T30).
- [x] Read `runs/_loop/judge/turn_29.json` in full (INCONCLUSIVE-by-metric-name-mapping; substantively PASS per sim §3 jq output; structural judge.py bug, not deliverable issue; no T29 retry needed).
- [x] Read `runs/_loop/sim/turn_29.md` §0-§3 (commands verify all state assertions PASS, memo created, by_tag appended).
- [x] Read `runs/_loop/by_tag/barnett-mechanism-confirmed.md` in full (the Tier-3 precedent pattern this investigation is modeled on; cross-link section 'Downstream cross-link' explicitly names this investigation).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` in full (164 lines, full Eq 1, normalization, anchor numbers, Q1-Q5 open questions, citation chain).
- [x] Surveyed code: lima_pelster_Q5 exists in `src/hamiltonian/interactions/lhy/dispatch.jl`; state_zoo.jl has 22 init_psi_* builders but Grep for 'torus|flux.closure|vortex.*phase.imprint' in initialization/ returned 0 hits — Q5 is likely BLOCKER.
- [x] investigation_id valid (`yan-li-saito-2026-reproduction` present in state.investigations_index).
- [x] stage_advancing_to=Hypothesize is next per verify-claim flow template (Research → Hypothesize).
- [x] subagent_type=theorist matches role_per_stage[Hypothesize] for verify-claim: 'theorist — formal claim + predicted signature + falsifier list'.
- [x] success_criteria are machine-evaluable: file_exists (boolean), grep_count (integer >= thresholds). Judge.py can apply all 7. Used flat metric names (e.g. `grep_count_E_kin_OR_E_ddi_OR_E_LHY_in_theorist_turn_30`) to avoid the T29 judge mapping issue (sim should report keys matching these names).
- [x] failure_modes cover 8 scenarios (operational artifact-missing, vague Q1-Q5, Q2 BLOCKER prefactor scientific path, Q3 BLOCKER free-space ITP data-gap, Q5 BLOCKER state_zoo data-gap, scope-creep to code/manuscript, budget overrun, memory-file-only-no-paper-quote).
- [x] observable_manifest=null (Hypothesize is text-only; no julia, no observables).
- [x] Budget 1.8M effective + 8 min wall fits within scheduler window (20847 min) and judge cost_cap (3M).
- [x] §A6 research-first citation present (Yan-Li-Saito 2026 PRL primary paper, Lima-Pelster 2011 PRA LHY antecedent, Li-Saito 2024 PRR torus paper, CLAUDE.md DDI convention, prior loop turn barnett-mechanism-confirmed.md Tier-3 precedent, Anthropic context engineering Compress strategy).
- [x] §A5 D1 articulated (verify external paper's claims in our framework — Tier 0 → 0.5 this turn, full Tier 3 path through Execute/Analyze/Update/Document, total ~4-6 turns); manuscript NOT primary (Hypothesize outputs are loop-internal theorist derivations, explicitly non-manuscript).
- [x] Considered switching to klaus-magnetostir-bch-leak (priority 3): rejected. Still blocked_on='needs julia P3 validation' which is an Execute-stage task, not an advance-able Hypothesize stage. yan-li-saito has clear Hypothesize-stage work; klaus does not until someone unblocks the P3 validation.
- [x] Considered re-running T29 to fix judge INCONCLUSIVE: rejected. Substantive work verified done per sim/turn_29.md §3 jq output + state.json + memo file existence. INCONCLUSIVE is structural judge metric-name-mapping bug, not deliverable issue. Forward motion is the correct response; if judge.py needs fixing, that is a separate task outside director scope.
- [x] Considered NOOP: rejected. New priority-1 investigation just activated, scheduler permits theorist (full whitelist), 1.8M cost well within budget. NOOP would waste the freshly-set-up Hypothesize advance.
- [x] Considered Research stage one more time: rejected. Memory file already contains paper triage + 5 open theorist questions; running researcher again would duplicate anko's 2026-05-16 work. Theorist Hypothesize is the natural advance.
- [x] Considered dispatching critic immediately (skip Hypothesize): rejected. Critic audits an existing claim; we don't have a yan-li-saito claim yet to audit. Hypothesize creates the claim; critic comes at Update stage.
- [x] Prompt-injection (MCP Figma) appeared again in conversation context this turn: explicitly ignored per CLAUDE.md project scope (BEC-simulation physics, not Figma). T28 critic and T29 director also flagged and ignored. Consistent.
- [x] `consumed_seed_md: true` — seed.md priority 2 (yan-li-saito, now promoted to priority 1) is being advanced. The investigation flow per seed.md L35-L51 maps exactly to the brief deliverables (Q1-Q5 + 5 framework gaps + flux-closure-torus + Tier-3 path).
