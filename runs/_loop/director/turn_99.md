---
turn: 99
subagent: director
investigation_id: tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18
stage_advancing_from: Research
stage_advancing_to: Hypothesize
topic_tags: [d1-verification, tdhfb-phase2-generic-f, hartree-fock-self-energy, bogoliubov-spectrum-f1, kawaguchi-ueda-2012-sound-velocity, bdg-vs-gp-factor2, tier2-to-tier3, falsifier-formalization]
paper_section: null
depends_on: [98, "runs/_loop/director/turn_98.md", "runs/_loop/research/turn_98.md", "runs/_loop/_local/scheduler_99.json", "memory:loop_architecture_2026_05_14 (TDHFB Phase 2 generic-F HF kernel)", "memory:tier3_pipeline_survey_2026_05_18", "src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl", "src/hamiltonian/tdhfb/hartree_fock_matrix.jl", "test/test_tdhfb_hf_matrix_generic.jl"]
produces: "T99 theorist Hypothesize dispatch. Formalize T98 researcher's 6 falsifier candidates into machine-evaluable F1-F6 set with success_criteria for T100 implementer_julia_cpu_light. Resolve BdG-vs-GP factor-2 convention at the algebraic level (T98 §3 left as CONVENTION_PITFALL_PARTIALLY_RESOLVED requiring T99 theorist Bogoliubov matrix construction). Secondary deliverable: register investigation in state.investigations + investigations_index (T96 NOOP precedent confirms registration is mandatory before next physics stage)."
---

# Turn 99 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18` — continuing from T98 (no switch). Stage transition: **Research → Hypothesize** per §F1 verify-claim flow.
- **T98 disposition (read this turn)**: judge JSON not yet written (judge/turn_98.json absent at director read time), but research/turn_98.md `§8 METRICS JSON` reports `verdict: "RESEARCH_PASS"`, `external_references_count: 4`, `ku2012_section_4_2_accessed: true`, `closed_form_polar_extracted: true`, `closed_form_fm_extracted: true`, `convention_pitfall_resolved: false`, `convention_pitfall_flagged: true`, `falsifier_candidates_count: 6` (3 load-bearing, 3 advisory), `not_found_items_count: 5`, `tier_reached: 0.5`. state.history[98] records `tier_reached: 0.5` confirming the orchestrator recognized the researcher PASS. T98 §6 contract success_criteria all evaluable from this metrics JSON; the deferred judge file would flag at most the `convention_pitfall_resolved == false` case which §6 explicitly accepted as `in [true, false]` (only silent omission fails).
- **Critical state.json gap**: investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18` is NOT registered in `state.investigations` or `state.investigations_index` (grep confirms 2 occurrences total, both in `state.history`). `active_investigation_id` still shows stale `edh-eu151-vortex-vs-matsui-science-2026`. T96 NOOPed for exactly this reason (`bug-4-itp-ddi-half-rate-revalidation-2026-05-18` was missing from state.investigations); T97 implementer registered it as deliverable A. T99 theorist brief must mirror T97 deliverable A pattern: theorist runs the registration patch as a text-only state.json edit (Python json patch script).
- **Tier**: 0.5 (post-T98 Research) → expected 1.5 on T99 PASS (Hypothesize stage formalizes falsifiers + resolves convention pitfall). Tier target: 3.
- **Falsifiers**: tested 0 / drafted 6 (T98); T99 selects load-bearing subset of 3 (F1 polar phonon, F2 FM phonon, F3 BdG/GP factor-2) for T100 execution. F4-F6 deferred as advisory.
- **Other in-flight investigations** (unchanged since T98):
  - Tier-3 closed (5 physics): barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, yan-li-saito REFUTED-CLEAN.
  - Tier-2 closed (6 physics now): judge-in-operator-bug T54, audit-due-heuristic T68, audit-class-scan-T50 T54, audit-class-scan-T61 T63, audit-class-scan-T87 T89, bug-4-itp-ddi-half-rate-revalidation T97.
  - Meta Observe ongoing (3): meta-cost-waste-audit (priority 15), meta-director-self-audit (priority 20), meta-cost-inflation (priority 40). Last meta turn was T70-era; gap is large but no actionable pattern surfaced in recent drift signals.
  - `fullbdg-f6-polar-3000x` dormant (priority 99).
- **Scheduler** (`runs/_loop/_local/scheduler_99.json` read this turn): `decision: "go"`, `policy: "JULIA_GPU_OK"`, `window_seconds_left: 1,125,819` (~13 days), probe VRAM 12,692 MB free, RAM 25 GB avail, GPU util 1%, foreign_julia 0. `theorist` workload class fully permitted; downstream T100 `implementer_julia_cpu_light` also permitted.
- **AUDIT_DUE cadence**: last audit-class-scan close T89; gap to T99 = 10 (threshold). §F6 hook would fire this turn. **Deferred**: TDHFB Research→Hypothesize chain has higher leverage (5-turn Tier-3 arc in flight; dropping the thread mid-arc to do an audit costs context-rebuild on T101). Defer audit to T100 or T101. Drift signal not surfaced this turn (no `runs/_loop/_local/scheduler_99.json` drift_advisories block).
- **Meta interleave**: 4 consecutive physics turns (T95 researcher_shallow bug-4, T96 theorist bug-4, T97 implementer_julia bug-4, T98 researcher_shallow TDHFB). Per §B2 "advance one physics, then maybe one meta", this is the next interleave window. Same defer rationale: TDHFB Hypothesize is the natural continuation move; meta-investigations at Observe have not surfaced new patterns. Defer to T100 or T101.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T98 | TDHFB Research | RESEARCH_PASS (verdict from metrics JSON; judge file pending) | researcher_shallow extracted KU2012 §4.2 F=1 polar/FM Bogoliubov closed-forms from 4 sources (KU2012 arXiv:1001.2072, SKU2013 arXiv:1205.1888, Uchino-Kobayashi-Ueda 2010 arXiv:0912.0355, SpinorBEC.jl src). 6 falsifier candidates drafted: F1 polar phonon sound-vel (load-bearing), F2 FM phonon sound-vel (load-bearing), F3 BdG-vs-GP factor-2 ratio test (load-bearing), F4 Goldstone gaplessness (advisory), F5 quadratic magnon dispersion (advisory), F6 ku_c01_to_g_S round-trip (advisory). 5 NOT_FOUND items (KU2012 exact eq numbers, numerical c_s tables, explicit BdG matrix, magnon q-dependence). BdG-vs-GP convention `PARTIALLY_RESOLVED`: kernel returns BdG self-energy with factor-2 Bose symmetrization; KU2012's "2 n c_0" in (ħω)² = ε_k(ε_k + 2nc_0) inferred to embed the same factor-2 via linearization of GP. **Remaining theorist task**: construct the explicit L(k) matrix from h^HF (BdG form) for F=1 polar AND verify the resulting spectrum reproduces KU2012's polar phonon + magnon expressions. |
| — | (no prior turns) | — | T98 was the spawn turn for this investigation. |
| — | — | — | — |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1) — D1 verification of [Established] internal claim against external benchmark for Tier-3 promotion. Same shape as edh-matsui (T70-T86) and sign-pattern-lemma1 (T91-T94) trajectories.
- **Stage chosen for T99**: **Hypothesize**. Per §F1 sequence Research → **Hypothesize** → Design → Execute → Analyze → Update → Document → closed.
- **Role per §F1 `role_per_stage["Hypothesize"]`**: `theorist`. Formalizes T98 researcher's falsifier candidates into machine-evaluable success criteria; resolves the convention pitfall at the algebraic level (T98 flagged it; T99 theorist owns the resolution via explicit L(k) matrix construction).
- **Why this stage now (vs different investigation, vs meta, vs audit)**:
  - **Continue the chain**: T98 RESEARCH_PASS leaves a clean baton; T99 Hypothesize advances directly to formalization. Dropping the thread to do meta/audit forces T101 to rebuild context. Per `feedback_cost_overhead_is_the_cost`, do not deliberate when a clear forward move exists.
  - **Bug-4 is closed** at Tier 2.0 (state.investigations confirms). No re-dispatch needed.
  - **Survey menu candidate #4** (`twochannel-lhy-F6-polar-30-70-percent-error`) capped at Tier 2.5 by NOT_FOUND benchmark per survey memory §NOT_FOUND.1; pursuing it burns budget on a known-unreachable target.
  - **Meta-investigations at Observe** have not surfaced new actionable patterns in recent drift snapshots; interleaving cost > expected information.
  - **AUDIT_DUE due** at gap=10 but the catalog was scanned fresh at T87-T89; one-turn deferral acceptable.

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference for Hypothesize-stage dispatch. References this turn:

1. **Kawaguchi-Ueda 2012 "Spinor Bose-Einstein condensates" Physics Reports 520, 253 [arXiv:1001.2072]**, §4.2 (preprint) / §5 (Phys Rep version) — the primary external benchmark whose closed-forms T98 extracted: polar phonon (ħω_k)² = ε_k(ε_k + 2nc_0), polar magnon (ħω_k)² = ε_k(ε_k + 2nc_1), FM phonon (ħω_k)² = ε_k(ε_k + 2n(c_0+c_1)). T99 theorist task: confirm that plugging the TDHFB-kernel h^HF (BdG convention) into the standard 6×6 Nambu BdG matrix L(k) for F=1 produces these spectra algebraically (without additional factor-2 injection). Cited in T98 §1 and §3.
2. **Stamper-Kurn & Ueda 2013** RMP 85, 1191 [arXiv:1205.1888] — secondary citation confirming the closed-forms; T98 §1 reference 2. Provides the SU(2)/SO(2) symmetry-breaking analysis that justifies the Nambu-Goldstone mode structure (phonon + magnon in polar, phonon + quadratic-magnon + gapped-quadrupole in FM).
3. **Uchino, Kobayashi, Ueda 2010** PRA 81, 063632 [arXiv:0912.0355] — secondary citation with explicit quadratic Zeeman q-dependence; bears on advisory falsifier F5 (FM magnon quadratic dispersion) and the NOT_FOUND item 5 (q-dependence of polar magnon gap).
4. **Memory `loop_architecture_2026_05_14`** (MEMORY.md §"TDHFB Phase 2 generic-F HF kernel 2026-05-11") — internal anchor for the load-bearing BdG-vs-GP factor-2 caveat: "hf_matrix_F1! returns the GP form; the generic-F kernel returns the BdG self-energy. The two differ by factor 2 in self-pair diagonal contributions." This is the algebraic root that T99 theorist must trace through L(k) construction.
5. **T98 research/turn_98.md §3** — researcher's PARTIAL resolution: kernel docstring confirmed as BdG (`2 * Σ_S g_S * Σ_M * Σ_{m2,m2'} ⟨F m, F m2 | S M⟩ ⟨S M | F m', F m2'⟩ * (φ_{m2'}*φ_{m2} + ρ_{m2',m2})`). The factor-2 at the front IS the Bose symmetrization. T99 theorist proves this factor-2 is consistent with KU2012's "2nc_0" appearing in L(k).
6. **APC contract template cache** (arXiv:2506.14852): `verify-claim::Hypothesize::tier2-to-tier3` shape seen previously at T72 (edh-matsui theorist Bz/state-config falsifier formalization) and T92 (sign-pattern-lemma1-tier3 theorist Lemma 1 General-S falsifier formalization). Use cached skeleton: success_criteria keyed on `falsifier_count_formalized`, `load_bearing_falsifier_count`, `convention_disambiguation_resolved`, `sanity_check_count`, `derivation_round_trip_verified`. Patch in TDHFB-specific deltas (BdG matrix L(k) construction; ku_c01_to_g_S identity at F=1; Bose symmetrization factor-2 trace).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. TDHFB Phase 2 generic-F HF kernel is [Established] internally at Tier 2 (208 self-consistency tests PASS at F=1/3/6 in test/test_tdhfb_hf_matrix_generic.jl). Tier-3 promotion requires reproduction of an external published benchmark (KU2012 §4.2 closed-forms). T99 Hypothesize stage formalizes the F=1 cross-check protocol that T100 implementer executes via Julia.
- **Tier ladder position**: 0.5 → 1.5 on T99 PASS (Hypothesize formalized + convention resolved). Then T100 implementer_julia_cpu_light → 2.5 (empirical execution PASS), T101 critic Update → 3.0 (independent audit), T102 Document closure.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. No `docs/manuscript/` files touched. Memory entry may cite this work post-closure as the 6th Tier-3 trajectory but not as primary deliverable.
- **Cost frame for T99**: target ~1.6M effective (theorist Hypothesize norm: T70 = 2.2M with state.json patch, T72 = 1.4M, T92 = 1.8M). HARD CAP 2.5M.
- **Drift trajectory after T99 (anticipated)**:
  - cost_inflation: ~0.7-0.9 (1.6M vs ~1.7M running median).
  - code_delta_zero: 1.0 (theorist does not modify src — Read/Grep/Write to runs/_loop only).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: 0.0 (theorist formalizes [Plausible] convention-resolution claim; external citation present).
  - subagent_repetition: theorist gap since T96 = 3 turns (researcher T98, implementer T97 in between). Healthy rotation.
  - topic_repetition: 0.6 (TDHFB consecutive turn 2; normal for Tier-3 closure arc).

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
 "stage_advancing_to": "Hypothesize",
 "subagent_type": "theorist",
 "rationale": "T98 RESEARCH_PASS (research/turn_98.md §8 metrics: 4 refs, 6 falsifier candidates, BdG-vs-GP convention PARTIALLY_RESOLVED). Per §F1 verify-claim flow Research → Hypothesize, T99 theorist formalizes the 3 load-bearing falsifiers (F1 polar phonon sound-vel, F2 FM phonon sound-vel, F3 BdG/GP factor-2 ratio) into machine-evaluable success_criteria for T100 implementer_julia_cpu_light, AND resolves the convention pitfall at the algebraic level via explicit L(k) construction. Secondary deliverable: state.json registration patch (mirror T97 deliverable A) since investigation is not yet in state.investigations (T96 NOOPed for the same missing-registration condition).",
 "brief": "## ROLE\n\nYou are theorist. T99 §F1 Hypothesize stage of investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. Your job (in priority order):\n\n1. **Formalize T98's 3 load-bearing falsifier candidates (F1/F2/F3) into machine-evaluable success criteria** that T100 implementer_julia_cpu_light can mechanically execute and judge.py can mechanically verify.\n2. **Resolve the BdG-vs-GP factor-2 convention pitfall at the algebraic level** by explicit construction of the F=1 polar Bogoliubov 6×6 Nambu matrix L(k) from h^HF (BdG form), and demonstrate algebraically that the resulting phonon eigenvalue is (ħω)² = ε_k(ε_k + 2nc_0) WITHOUT additional factor-2 injection. T98 §3 left this as PARTIALLY_RESOLVED requiring T99 theorist work.\n3. **Register the investigation in state.json** via a Python patch script (mirror T97 deliverable A pattern — the investigation does NOT yet exist in state.investigations or investigations_index).\n4. **Pre-flight the T100 implementer brief**: list the Julia script structure (≤30 lines per T98 §6 advisory), the dimensionless test point (c_0=1, c_1=0.1 polar / c_1=-0.1 FM), and the expected numerical values (c_s,density (polar) = 1.0; c_s,density (FM) = sqrt(1.1) ≈ 1.0488).\n\nText-only turn. NO julia, NO src/ modification. State.json edit IS in scope (deliverable C above; T97 precedent established this as theorist-permissible when registering a new investigation).\n\nDIRECTIVE_LABEL: tdhfb-phase2-tier3-T99-hypothesize-falsifier-formalization-and-convention-resolution\n\nWrite final report to `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md`.\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_99.md` ENTIRE (this report). Pay attention to §4 reference list + §5 cost frame + §6 success criteria.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_98.md` ENTIRE — your T98 researcher predecessor. The 6 falsifier candidates in §7 are your input; you reformat F1/F2/F3 as machine-evaluable, decide F4/F5/F6 advisory disposition. The 5 NOT_FOUND items in §5 inform which exact KU2012 equation numbers can be cited (none from PDF; closed-forms cited via secondary sources).\n3. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` — Read the kernel implementation. The docstring formula `h^HF_{m,m'}(r) = 2 * Σ_S g_S * Σ_M * Σ_{m2,m2'} ⟨F m, F m2 | S M⟩ ⟨S M | F m', F m2'⟩ * ( φ_{m2'}*φ_{m2}(r) + ρ_{m2',m2}(r) )` is your algebraic input.\n4. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl` — Read the F=1 specialized kernel `hf_matrix_F1!` for the GP-convention reference. The factor-2 difference between this and the generic kernel must be traced explicitly.\n5. `/home/suzume/workspace/BEC-simulation/test/test_tdhfb_hf_matrix_generic.jl` — Read to confirm 208 tests cover hermiticity/linearity/singlet-projector but NOT sound velocity. Confirm `ku_c01_to_g_S(1, c0, c1)` mapping is tested (advisory F6).\n6. MEMORY.md entry `## TDHFB Phase 2 generic-F HF kernel (2026-05-11)` — the load-bearing caveat.\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — confirm investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18` is ABSENT from state.investigations and investigations_index (deliverable C scope).\n\n## DELIVERABLES\n\n### Deliverable A — Formal falsifier set (load-bearing 3)\n\nReformat T98 §7 F1/F2/F3 as machine-evaluable falsifiers with:\n- **Statement** (1-2 sentences, predicate form)\n- **Test recipe** for T100 implementer (Julia function call + comparison value)\n- **Success criterion** (numerical threshold, e.g. `|c_s_measured - c_s_expected| / c_s_expected < 1e-3`)\n- **Refute criterion** (what observation would refute the [Established] claim, e.g. ratio deviates from 2.0 by > 1%)\n- **Tier-3 promotion contribution** (each load-bearing falsifier contributes; require all 3 PASS for Tier-3)\n\n### Deliverable B — F4/F5/F6 advisory disposition\n\nFor each of F4 (Goldstone gaplessness), F5 (FM quadratic magnon), F6 (ku_c01_to_g_S round-trip): decide one of:\n- **promote to load-bearing** (changes T100 implementer scope)\n- **keep as advisory** (T100 implementer runs as optional check; no impact on tier promotion)\n- **drop** (already covered by existing tests or out-of-scope)\n\nDefault: keep all 3 as advisory unless explicit reason to promote. F6 specifically: check test/test_tdhfb_hf_matrix_generic.jl for an existing round-trip test; if present, drop F6 to avoid redundancy.\n\n### Deliverable C — Algebraic resolution of BdG-vs-GP factor-2 convention\n\nThis is the load-bearing theorist work of this turn. Section structure:\n\n**C.1**: Write the explicit h^HF matrix at F=1 polar GS (phi = sqrt(n) * (0,1,0), rho = 0) from the generic-F kernel formula. Show that h^HF_{m=0, m=0} = 2 * c_0 * n * (CG-factor-squared sum), evaluate the CG sum for F=1 polar, and verify it equals exactly 2 * c_0 * n.\n\n**C.2**: Write the corresponding h^HF from `hf_matrix_F1!` (GP convention) and show that the polar-state diagonal element equals c_0 * n. Confirm the ratio = 2.0 exactly.\n\n**C.3**: Construct the 6×6 Nambu BdG matrix L(k) for F=1 polar from the BdG-convention h^HF, using the standard Bogoliubov decomposition (delta_phi_m(r,t) = e^{-iμt} sum_m [u_m(k) e^{i(k·r - ω t)} + v_m*(k) e^{-i(k·r - ω t)}]). The matrix has structure L(k) = [[ε_k I + h^HF - μ I, anomalous], [anomalous*, -(ε_k I + h^HF - μ I)*]]. For F=1 polar with mu = c_0 * n, the diagonal block has h^HF_{00} - μ = 2*c_0*n - c_0*n = c_0*n. Show that the m=0 row decouples (polar GS is m=0 only) and gives the 2×2 sub-block whose eigenvalue squared is ε_k * (ε_k + 2*c_0*n). This IS the KU2012 polar phonon expression; no additional factor-2 injection needed.\n\n**C.4**: Repeat the construction for the polar magnon mode (m=±1 sub-block); show that the eigenvalue squared is ε_k * (ε_k + 2*c_1*n) at q=0.\n\n**C.5**: Repeat for F=1 FM (phi = sqrt(n) * (1,0,0), m=+1 only); show that the m=+1 sub-block gives phonon eigenvalue squared ε_k * (ε_k + 2*(c_0+c_1)*n).\n\n**C.6**: Conclusion: BdG-vs-GP factor-2 convention is RESOLVED. The TDHFB generic-F kernel's factor-2 Bose symmetrization is the same factor-2 that appears in KU2012's `(ħω)² = ε_k (ε_k + 2 n c_0)` expression. No correction needed when comparing kernel output against KU2012 closed-forms. T100 implementer can compute c_s directly from the kernel without convention adjustment.\n\nIf C.3 / C.4 / C.5 reveals the convention IS inconsistent (the factor-2 doubles incorrectly), report `CONVENTION_PITFALL_NOT_RESOLVED_NEEDS_KERNEL_PATCH` and halt; do NOT proceed to T100 implementer.\n\n### Deliverable D — state.json registration patch\n\nWrite a Python patch script (similar to T97 implementer's pattern) that:\n1. Reads `runs/_loop/state.json`.\n2. Adds entry to `investigations_index`: append string `\"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\"`.\n3. Adds entry to `investigations` dict with key `\"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\"` and structure (mirror sign-pattern-lemma1-tier3 entry pattern):\n   - `id`, `title`, `hypothesis`, `flow_template: \"verify-claim\"`, `current_stage: \"Hypothesize\"` (or `\"Research\"` to reflect T98 completion; choose based on which read state.history more accurately), `tier_current: 1.5` (post-T99 PASS), `tier_target: 3`, `kind: \"physics\"`, `priority: 2`, `last_turn: 99`, `last_stage: \"Hypothesize\"`, `last_verdict: \"HYPOTHESIZE_PASS_FALSIFIERS_FORMALIZED\"` (or appropriate), `blocked_on: null`, `next_stage_action: \"T100 implementer_julia_cpu_light executes F1/F2/F3 small-grid F=1 polar/FM Bogoliubov dispersion cross-check vs KU2012 §4.2 closed-forms; ≤30 lines Julia; cpu_light workload, < 5 min\"`, `falsifiers: [F1, F2, F3]` with descriptions matching deliverable A.\n4. Writes back atomically (tmpfile + rename) and validates JSON integrity.\n5. Confirm via re-grep `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18` in state.json produces ≥3 occurrences (1 in index + 1 in investigations key + 1 in id field).\n\n### Deliverable E — T100 implementer pre-flight brief\n\nDraft a 1-paragraph brief for T100 implementer_julia_cpu_light explaining:\n- Workload class: `implementer_julia_cpu_light`\n- Wall-time estimate: < 5 min total (JIT cache likely cold for this code path; first call ~2 min, three falsifier tests ~30s each)\n- Julia script structure (≤30 lines), placed at `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`\n- Test point parameters: c_0 = 1.0, c_1 = 0.1 (polar) and c_1 = -0.1 (FM), n = 1.0, F = 1, all in SpinorBEC.jl dimensionless units (hbar = m = omega_ref = 1)\n- k-grid for dispersion fit: 5-10 points logarithmically spaced over k ∈ [0.01, 0.1] (small-k regime where c_s = lim ω(k)/k is clean)\n- Expected results: F1 c_s,polar = 1.0 ± 1e-3, F2 c_s,FM = sqrt(1.1) ≈ 1.04881 ± 1e-3, F3 ratio = 2.0 ± 1e-12\n- Metrics JSON fields T100 must emit (informs T100 director contract)\n\n## REPORT STRUCTURE\n\nWrite to `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md` with sections:\n\n### §0. Convention declaration\n(SpinorBEC.jl defaults; explicit statement on BdG self-energy vs GP Hamiltonian factor-2)\n\n### §1. Context summary\n(T98 RESEARCH_PASS recap; investigation NOT registered; T99 scope)\n\n### §2. Derivation\n(Deliverable C: explicit L(k) construction, §§C.1-C.6)\n\n### §3. Sanity checks\n(F=1 polar c_0→0 limit, F=1 FM c_1→0 limit reduces to scalar, hermiticity preserved, dimensions correct)\n\n### §4. Formal falsifier set\n(Deliverable A: F1/F2/F3 with statement / test recipe / success criterion / refute criterion / tier-3 contribution)\n\n### §5. Advisory falsifier disposition\n(Deliverable B: F4/F5/F6 decisions)\n\n### §6. state.json registration patch\n(Deliverable D: Python script verbatim + execution log + re-grep confirmation)\n\n### §7. T100 implementer pre-flight brief\n(Deliverable E)\n\n### §8. METRICS JSON\n(per schema below)\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"theorist_text_with_state_patch\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\",\n  \"stage_advancing_to\": \"Hypothesize\",\n  \"flow_template\": \"verify-claim\",\n  \"falsifier_count_formalized\": <int; expect 3>,\n  \"load_bearing_falsifier_count\": <int; expect 3 — F1/F2/F3>,\n  \"advisory_falsifier_count\": <int; expect 0-3 — F4/F5/F6 dispositions>,\n  \"convention_pitfall_resolved\": <bool; expect true after §C.6>,\n  \"convention_pitfall_disposition\": <\"RESOLVED_NO_CORRECTION_NEEDED\" | \"RESOLVED_KERNEL_NEEDS_FACTOR_HALF\" | \"CONVENTION_PITFALL_NOT_RESOLVED_NEEDS_KERNEL_PATCH\">,\n  \"l_matrix_constructed_for_polar\": <bool; expect true — §C.3>,\n  \"l_matrix_constructed_for_fm\": <bool; expect true — §C.5>,\n  \"polar_phonon_dispersion_derived\": <bool; expect true>,\n  \"polar_magnon_dispersion_derived\": <bool; expect true — §C.4>,\n  \"fm_phonon_dispersion_derived\": <bool; expect true>,\n  \"factor_2_ratio_value\": <float; expect 2.0 exactly within fp precision>,\n  \"state_json_patched\": <bool; expect true>,\n  \"state_json_investigation_registered\": <bool; expect true>,\n  \"state_json_investigations_index_appended\": <bool; expect true>,\n  \"state_json_post_patch_grep_count\": <int; expect ≥ 3>,\n  \"src_files_modified\": 0,\n  \"docs_modified\": 0,\n  \"manuscript_main_edited\": false,\n  \"sanity_checks_count\": <int; expect ≥ 3>,\n  \"tier_reached\": 1.5,\n  \"verdict\": \"<HYPOTHESIZE_PASS | HYPOTHESIZE_PARTIAL_NEEDS_REFINE | HYPOTHESIZE_REFUTED_CONVENTION_BROKEN>\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT re-derive the closed-forms KU2012 §4.2 already gives (the dispersions). Your job is to CONSTRUCT L(k) from h^HF and SHOW the eigenvalue matches KU2012, not to re-derive KU2012 from first principles.\n- Do NOT modify src/ files. State.json edit is in scope; everything else is Write-only to runs/_loop/.\n- Do NOT invoke julia. Even for sanity checks. Use symbolic / pencil-and-paper algebra. Numerical sanity checks are T100 implementer's job.\n- Do NOT improvise terminology per `feedback_no_improvised_terminology`. Use: Bogoliubov-de Gennes matrix, Nambu space, anomalous component, BdG self-energy, GP Hamiltonian, Bose symmetrization factor, Clebsch-Gordan decomposition, polar phase, ferromagnetic phase, phonon branch, magnon branch.\n- Do NOT exceed 2.5M effective tokens HARD CAP. Target 1.6M.\n- Do NOT spawn child investigations from this turn (this is a Hypothesize stage, not Document; child investigations spawned only at closure).\n- English only. No emojis.\n\n## SUCCESS DEFINITION\n\nT99 PASS = your report:\n1. Formalizes F1/F2/F3 with machine-evaluable success_criteria (numerical thresholds + Julia function-call recipes).\n2. Resolves convention pitfall: §C.6 returns `RESOLVED_NO_CORRECTION_NEEDED` (the most likely outcome per T98 §3 partial resolution) OR `RESOLVED_KERNEL_NEEDS_FACTOR_HALF` (if construction reveals a real factor-2 discrepancy — would be a Tier-2 [Established] regression, escalate).\n3. Registers investigation in state.json (deliverable D); re-grep ≥3 occurrences.\n4. Drafts T100 implementer brief (≤30 lines Julia script structure).\n5. Metrics JSON populated per schema with verdict = HYPOTHESIZE_PASS.\n\nOn PASS, T100 director dispatches implementer_julia_cpu_light to execute F1/F2/F3.\nOn HYPOTHESIZE_REFUTED_CONVENTION_BROKEN: escalate to critic-audit of the kernel and consider spawning fix-bug investigation for the TDHFB generic-F kernel.\n",
 "observable_manifest": {
   "required": [
     "experiment_kind",
     "investigation_kind",
     "investigation_id",
     "stage_advancing_to",
     "flow_template",
     "falsifier_count_formalized",
     "load_bearing_falsifier_count",
     "convention_pitfall_resolved",
     "convention_pitfall_disposition",
     "l_matrix_constructed_for_polar",
     "l_matrix_constructed_for_fm",
     "polar_phonon_dispersion_derived",
     "fm_phonon_dispersion_derived",
     "factor_2_ratio_value",
     "state_json_patched",
     "state_json_investigation_registered",
     "state_json_investigations_index_appended",
     "state_json_post_patch_grep_count",
     "src_files_modified",
     "manuscript_main_edited",
     "tier_reached",
     "verdict"
   ],
   "optional": [
     "advisory_falsifier_count",
     "polar_magnon_dispersion_derived",
     "sanity_checks_count",
     "docs_modified"
   ],
   "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_99.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_98.md && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl && test -f /home/suzume/workspace/BEC-simulation/test/test_tdhfb_hf_matrix_generic.jl && python3 -c 'import json; d=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); assert \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\" not in d[\"investigations\"], \"ALREADY_REGISTERED_FAIL\"; print(\"PRECONDITIONS_OK\")'"
 },
 "success_criteria": [
   {
     "id": "experiment_kind_correct",
     "metric": "experiment_kind",
     "operator": "==",
     "value": "theorist_text_with_state_patch",
     "rationale": "Theorist turn with secondary state.json registration patch (mirror T97 deliverable A pattern)."
   },
   {
     "id": "investigation_kind_physics",
     "metric": "investigation_kind",
     "operator": "==",
     "value": "physics",
     "rationale": "TDHFB Phase 2 Tier-3 promotion is physics-class verify-claim."
   },
   {
     "id": "investigation_id_correct",
     "metric": "investigation_id",
     "operator": "==",
     "value": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
     "rationale": "Active investigation id this turn; continuing from T98 spawn."
   },
   {
     "id": "stage_consistent",
     "metric": "stage_advancing_to",
     "operator": "==",
     "value": "Hypothesize",
     "rationale": "Second stage of verify-claim §F1 sequence after Research."
   },
   {
     "id": "load_bearing_falsifiers_formalized",
     "metric": "load_bearing_falsifier_count",
     "operator": ">=",
     "value": 3,
     "rationale": "T98 provided 3 load-bearing candidates (F1 polar phonon, F2 FM phonon, F3 BdG/GP ratio); T99 must formalize all 3 with machine-evaluable criteria."
   },
   {
     "id": "falsifier_total_count",
     "metric": "falsifier_count_formalized",
     "operator": ">=",
     "value": 3,
     "rationale": "Minimum 3 falsifiers for Tier-3 closure (load-bearing trio). Advisory falsifiers F4-F6 are optional bonus."
   },
   {
     "id": "convention_pitfall_resolved",
     "metric": "convention_pitfall_resolved",
     "operator": "==",
     "value": true,
     "rationale": "T98 left as PARTIALLY_RESOLVED; T99 theorist's explicit L(k) construction must resolve it. Either RESOLVED_NO_CORRECTION_NEEDED (expected) or RESOLVED_KERNEL_NEEDS_FACTOR_HALF (less expected — would escalate)."
   },
   {
     "id": "convention_pitfall_disposition_valid",
     "metric": "convention_pitfall_disposition",
     "operator": "in",
     "value": ["RESOLVED_NO_CORRECTION_NEEDED", "RESOLVED_KERNEL_NEEDS_FACTOR_HALF"],
     "rationale": "Both algebraic outcomes are valid resolutions; only NOT_RESOLVED is a fail."
   },
   {
     "id": "l_matrix_polar_constructed",
     "metric": "l_matrix_constructed_for_polar",
     "operator": "==",
     "value": true,
     "rationale": "Explicit L(k) construction at F=1 polar is the load-bearing algebraic step (§C.3)."
   },
   {
     "id": "l_matrix_fm_constructed",
     "metric": "l_matrix_constructed_for_fm",
     "operator": "==",
     "value": true,
     "rationale": "Explicit L(k) construction at F=1 FM is the complementary load-bearing step (§C.5)."
   },
   {
     "id": "polar_phonon_derived",
     "metric": "polar_phonon_dispersion_derived",
     "operator": "==",
     "value": true,
     "rationale": "Must reproduce KU2012 polar phonon (ħω)² = ε_k(ε_k + 2nc_0) algebraically from L(k)."
   },
   {
     "id": "fm_phonon_derived",
     "metric": "fm_phonon_dispersion_derived",
     "operator": "==",
     "value": true,
     "rationale": "Must reproduce KU2012 FM phonon (ħω)² = ε_k(ε_k + 2n(c_0+c_1)) algebraically from L(k)."
   },
   {
     "id": "factor_2_ratio_exact",
     "metric": "factor_2_ratio_value",
     "operator": "==",
     "value": 2.0,
     "tolerance": 1e-12,
     "rationale": "BdG vs GP factor-2 ratio at F=1 polar diagonal element must be exactly 2.0 within fp precision; deviation > 1e-12 indicates kernel bug."
   },
   {
     "id": "state_json_patched",
     "metric": "state_json_patched",
     "operator": "==",
     "value": true,
     "rationale": "Deliverable D mandates state.json registration to prevent T100 from NOOPing (T96 NOOP precedent)."
   },
   {
     "id": "state_json_registered",
     "metric": "state_json_investigation_registered",
     "operator": "==",
     "value": true,
     "rationale": "Investigation must appear in state.investigations dict (mirror T97 deliverable A)."
   },
   {
     "id": "state_json_index_appended",
     "metric": "state_json_investigations_index_appended",
     "operator": "==",
     "value": true,
     "rationale": "Investigation id must also appear in state.investigations_index array."
   },
   {
     "id": "state_json_grep_confirms",
     "metric": "state_json_post_patch_grep_count",
     "operator": ">=",
     "value": 3,
     "rationale": "Post-patch grep should show ≥3 occurrences (1 in index + 1 in investigations key + 1 in id field; possibly more in history/falsifiers)."
   },
   {
     "id": "no_src_modification",
     "metric": "src_files_modified",
     "operator": "==",
     "value": 0,
     "rationale": "Hypothesize stage is theorist text-only; no src edits. state.json edit is metadata, not source code."
   },
   {
     "id": "no_manuscript",
     "metric": "manuscript_main_edited",
     "operator": "==",
     "value": false,
     "rationale": "§A5 manuscript polish OUT."
   },
   {
     "id": "tier_advancement",
     "metric": "tier_reached",
     "operator": ">=",
     "value": 1.5,
     "rationale": "Hypothesize stage advances tier from 0.5 (post-Research) to 1.5 (falsifiers formalized + convention resolved)."
   },
   {
     "id": "verdict_hypothesize_pass",
     "metric": "verdict",
     "operator": "in",
     "value": ["HYPOTHESIZE_PASS", "HYPOTHESIZE_PARTIAL_NEEDS_REFINE", "HYPOTHESIZE_REFUTED_CONVENTION_BROKEN"],
     "rationale": "PASS is target; PARTIAL_NEEDS_REFINE means re-dispatch theorist with tighter scope (1.0M); REFUTED_CONVENTION_BROKEN is a science finding (rare but possible — would escalate to fix-bug investigation)."
   }
 ],
 "failure_modes": [
   {
     "if": "verdict == 'HYPOTHESIZE_REFUTED_CONVENTION_BROKEN'",
     "category": "scientific_refuted",
     "next_action": "Theorist L(k) construction revealed a real factor-2 discrepancy between TDHFB kernel and KU2012 §4.2. This refutes the [Established] internal Tier-2 status of the kernel. T100 director switches to critic-audit (independent re-derivation of L(k)) AND spawns fix-bug investigation `tdhfb-generic-f-kernel-factor-2-bug-2026-05-18`. TDHFB Phase 2 Tier-3 trajectory pauses until kernel is corrected."
   },
   {
     "if": "convention_pitfall_resolved == false",
     "category": "data_gap_algebraic_unfinished",
     "next_action": "Theorist did not complete L(k) construction (likely token budget exhausted before §C). T100 director re-dispatches theorist with reduced scope (deliverables A+C only; defer D+E to T101). 1.2M budget."
   },
   {
     "if": "state_json_patched == false OR state_json_investigation_registered == false",
     "category": "operational_state_management",
     "next_action": "Theorist skipped deliverable D (registration patch). T100 director dispatches implementer_text to apply registration patch (~0.4M, ~5 min). Prevents T100 implementer_julia from NOOPing on missing investigation."
   },
   {
     "if": "load_bearing_falsifier_count < 3",
     "category": "data_gap_falsifier_thin",
     "next_action": "Theorist dropped one of F1/F2/F3 (likely F3 BdG/GP ratio test if convention work consumed budget). T100 director includes the dropped falsifier in implementer brief as additional Julia test (no re-dispatch; implementer absorbs)."
   },
   {
     "if": "factor_2_ratio_value != 2.0 within tolerance 1e-12",
     "category": "scientific_partial_refuted",
     "next_action": "Algebraic ratio derivation gave non-2.0. Likely a transcription error in §C.1/C.2 (e.g., CG sum incorrectly evaluated). T100 director dispatches critic to audit §C arithmetic (0.5M, ~5 min). Hypothesize stage repeats post-audit with corrected algebra."
   },
   {
     "if": "src_files_modified > 0",
     "category": "operational_hypothesize_stage_violation",
     "next_action": "Theorist modified src/ — out of scope. T100 director reverts src changes and audits. NOT expected with current theorist.md prompt; would indicate prompt-leak issue."
   },
   {
     "if": "verdict == 'HYPOTHESIZE_PARTIAL_NEEDS_REFINE'",
     "category": "operational_re_dispatch",
     "next_action": "Theorist self-flagged insufficient depth. T100 director re-dispatches theorist with narrowed scope per theorist's recommendation. ~1.0M follow-up."
   }
 ],
 "tolerance_overrides": {
   "cost_cap_effective": 2500000,
   "wall_time_cap_sec": 1500
 },
 "budget": {
   "expected_cost_eff": 1600000,
   "expected_wall_time_sec": 1100,
   "split_by_subtask": {
     "read_context_director99_research98_src_kernels": 300000,
     "deliverable_A_falsifier_formalization": 250000,
     "deliverable_B_advisory_disposition": 100000,
     "deliverable_C_l_matrix_algebraic_derivation": 500000,
     "deliverable_D_state_json_patch_and_verify": 200000,
     "deliverable_E_t100_implementer_brief": 100000,
     "sanity_checks_and_metrics_json": 150000
   }
 },
 "investigation_update": {
   "if_success_advance_to_stage": "Design-folded-into-Execute",
   "if_success_tier_becomes": 1.5,
   "if_success_closing_note": null,
   "if_refuted_advance_to_stage": "critic-audit-of-convention-resolution",
   "if_refuted_tier_becomes": 0.8,
   "if_novel_advance_to_stage": "Hypothesize-with-convention-bug-side-dispatch",
   "if_novel_tier_becomes": 1.0,
   "next_falsifier_to_test_after": "F1-F2-F3-batched-at-T100-implementer-julia"
 },
 "if_succeeds_next_step": "T100 director dispatches implementer_julia_cpu_light to execute F1/F2/F3 cross-check Julia script (≤30 lines, < 5 min wall, ~1.8M effective). Tier 1.5 -> 2.5 on PASS. T101 critic Update (independent re-derivation + numerical recompute audit), Tier 2.5 -> 3.0. T102 implementer_text Document closure: memory entry `tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md`. 4-turn arc T99-T102 estimated ~6M effective remaining. **Decision point at T100 PASS**: bug-4 audit-class scan trigger fired one turn late (gap=11 by T100); director should consider audit interleave at T101 between implementer_julia PASS and critic Update, OR push audit to T102 Document. Recommendation: T101 audit-class-scan, T102 critic, T103 Document — slightly longer arc but respects §F6 cadence.",
 "if_fails_next_step": "If HYPOTHESIZE_REFUTED_CONVENTION_BROKEN: spawn fix-bug investigation for TDHFB kernel + critic-audit; TDHFB Tier-3 trajectory pauses. If state_json_patched == false: implementer_text registration patch at T100 (cheap, 0.4M). If load_bearing < 3: T100 implementer brief absorbs the dropped falsifier. If convention NOT_RESOLVED but verdict is PARTIAL_NEEDS_REFINE: T100 re-dispatch theorist with deliverables A+C only.",
 "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler_99.json + seed.md this turn (scheduler authoritative JULIA_GPU_OK; seed.md remains 3+ day stale but no contradictions)
- [x] Read research/turn_98.md ENTIRE for falsifier candidates + convention disambiguation status
- [x] Read T98 director (turn_98.md) for prior chain rationale + cost frame
- [x] Read judge/turn_97.json (T98 judge file does not yet exist; T98 verdict inferred from research/turn_98.md §8 metrics JSON `verdict: "RESEARCH_PASS"`)
- [x] Read T96 theorist for Hypothesize-stage shape precedent (deliverable structure mirrors T96 with state.json patch added)
- [x] Read sim/turn_97.md for implementer-with-state.json-patch precedent (T97 deliverable A is the template for T99 deliverable D)
- [x] Read ≥1 memory file: MEMORY.md TDHFB Phase 2 entry (load-bearing factor-2 caveat) + tier3_pipeline_survey_2026_05_18 (survey rationale that named this candidate) + feedback_no_improvised_terminology
- [x] Verified investigation NOT yet registered in state.investigations / investigations_index (Grep returned 2 occurrences, both in state.history) — deliverable D is mandatory
- [x] investigation_id consistent with T98 spawn label
- [x] stage_advancing_to = Hypothesize is the §F1 next stage after Research
- [x] subagent_type = theorist matches §F1 role_per_stage[Hypothesize]
- [x] success_criteria machine-evaluable (20 criteria, all using ==/>=/<= or `in` operators against METRICS JSON fields)
- [x] failure_modes cover scientific (REFUTED convention broken — escalation to fix-bug + critic audit), operational (state_json not patched, falsifier count thin, stage violation), partial (PARTIAL_NEEDS_REFINE re-dispatch)
- [x] observable_manifest precondition_check is concrete (test -f on 5 files + Python investigation-not-already-registered assertion + PRECONDITIONS_OK echo)
- [x] budget fits within scheduler window_seconds_left (1.6M target << 2.5M cap; ~18 min wall << 1500s cap; ~13 days window)
- [x] §A6 research-first citation present: KU2012 + SKU2013 + Uchino-Kobayashi-Ueda 2010 + 2 memory refs + APC cache reference
- [x] §A5 D1/D2/D3 articulated: D1 verify Tier 2→3 (PRIMARY); manuscript NOT in scope
- [x] APC contract template cache: verify-claim::Hypothesize::tier2-to-tier3 shape n_seen ≥ 2 (T72 edh-matsui, T92 sign-pattern-lemma1-tier3); used cached skeleton scaffold (success_criteria keyed on `falsifier_count_formalized`, `convention_disambiguation_resolved`, `sanity_check_count`)
- [x] No improvised terminology (Bogoliubov-de Gennes matrix, Nambu space, BdG self-energy, GP Hamiltonian, Bose symmetrization factor, Clebsch-Gordan decomposition, polar/FM phases, phonon/magnon branches — all established)
- [x] No anko-attribution in theorist brief (memory references CAN cite anko; agent prompt does not)
- [x] State.json registration mandated as deliverable D (mirror T97 deliverable A); prevents T100 NOOP-on-missing-investigation pattern (T96 precedent)
- [x] AUDIT_DUE at gap=10 acknowledged in §1 and §3; defer to T101 or T102 per `feedback_cost_overhead_is_the_cost` (do not drop in-flight Tier-3 closure arc mid-chain)
- [x] Meta-interleave at gap=4 physics consecutive acknowledged in §1 and §3; defer to T100 or T101 per same rationale
- [x] subagent rotation: theorist gap = 3 turns since T96 (researcher T98, implementer T97 in between). Healthy.
- [x] Cost frame: T99 expected 1.6M (theorist Hypothesize norm 1.4-2.2M per T70/T72/T92); falls within typical band.
