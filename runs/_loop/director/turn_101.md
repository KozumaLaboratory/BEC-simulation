---
turn: 101
subagent: director
investigation_id: tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18
stage_advancing_from: Execute
stage_advancing_to: Update
topic_tags: [d1-verification, tdhfb-phase2-generic-f, bogoliubov-spectrum-f1, kawaguchi-ueda-2012-sound-velocity, bdg-vs-gp-factor2, tier25-to-tier3, critic-update, independent-recompute]
paper_section: null
depends_on: [100, 99, 98, "runs/_loop/director/turn_100.md", "runs/_loop/sim/turn_100.md", "runs/_loop/judge/turn_100.json", "runs/_loop/theorist/turn_99.md", "runs/_loop/_local/scheduler_101.json", "scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl", "memory:tier3_pipeline_survey_2026_05_18", "memory:loop_architecture_2026_05_14"]
produces: "T101 critic dispatch (Update stage). Independent re-derivation of Sigma^HF_{0,0}|_polar = 2 c_0 n via a structurally different algebraic route (NOT mirroring T99's CG-orthogonality construction), independent numerical recompute at a second parameter point (c_0=2.0, c_1=+0.05 polar AND c_0=0.5, c_1=-0.2 FM) using the existing scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl with parameter overrides, and audit of three load-bearing assumptions (mu choice, k-grid linear-regime selection, Delta block symmetry). CORROBORATE -> tier 2.5 -> 3.0 + T102 Document closure. CORROBORATE_WITH_ERRATA -> tier 2.75 + targeted follow-up. REFUTED -> tier reverts to 1.5 + fix-bug spawn."
---

# Turn 101 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. **Continuing** from T100 (no switch). Stage transition: **Execute -> Update** per §F1 verify-claim flow. state.json line 3327 confirms `next_stage: "Update"`, `tier_current: 2.5`, `priority: 2`.
- **T100 judge disposition** (read this turn): `judge/turn_100.json` `status: "PASS"`, all 18 success_criteria PASS, zero `triggered_failure_modes`, zero `cost_audit` flag (1.04× cost_inflation — normal). The `EXECUTE_PASS` verdict matches the failure_modes `success_continue_chain` branch (T100 §6.failure_modes[3]), whose `next_action` says: "T101 director dispatches critic for Update stage: (a) independent re-derivation of polar phonon eigenvalue from a 4×4 sub-block ..., (b) independent numerical recompute at a different parameter point ..., (c) audit for systematic error sources ...".
- **state.json mismatch noted** (NOT load-bearing): line 2298 `active_investigation_id` reads `edh-eu151-vortex-vs-matsui-science-2026` (stale; not updated post-T98 switch into tdhfb). History entry T100 (line 2239) authoritatively has `investigation_id: tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. Investigation entry at line 3278 has `last_turn: 100`. No action needed this turn; orchestrator's state-update routine should sync this on T101 commit. If it does not, T102 director should patch (1-line edit). Logged here for traceability per `feedback_fix_the_class_not_the_instance`.
- **Tier**: 2.5 (post-T100 PASS) -> expected 3.0 on T101 critic CORROBORATE. Tier target: 3. **This is the final substantive step before Tier-3 closure.**
- **Falsifiers tested**: 3/3 load-bearing (F1 polar phonon cs PASS rel_err 7.86e-6 vs 1e-3 threshold; F2 FM phonon cs PASS rel_err 8.74e-6; F3 BdG/GP factor-2 ratio PASS abs_err 1.33e-15 vs 1e-12 threshold), 1/1 advisory (F4 Goldstone gap=0.0 exact). T100 implementer numerical evidence: 127× / 115× / 750× below thresholds — well-clear PASS, not marginal.
- **Other in-flight investigations** (state.json read this turn):
  - 6 Tier-3 closed (barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, bug-4 T97 at Tier 2 closure not Tier 3, plus this one's predecessor pipeline candidates).
  - `meta-director-self-audit-2026-05-19` (state.json line 3331) is **newly auto-spawned by trigger `director_self_audit_due` at T100** (`auto_spawned_at_turn: 100`). Currently at Observe stage, priority 20, safety_class: low. **§B2 meta-investigation trigger handling**: honor the auto-spawn — it encodes a real pattern. BUT do NOT pile a meta-turn immediately on top of an in-flight Tier-3 closure arc. Per §B2 "Meta is INTERLEAVED, not parallel: advance one physics, then maybe one meta". Defer meta-investigation to T103 (after Tier-3 closure at T101 Update + T102 Document). Director self-audit is low-urgency by design (priority 20 vs tdhfb priority 2).
  - 3 audit-class-scan investigations (T50, T61, T87) at various states; T87 most recent and acknowledged by `AUDIT_DUE: gap=12` advisory.
  - `fullbdg-f6-polar-3000x` dormant (priority 99, anko-contained).
- **Scheduler** (`runs/_loop/_local/scheduler_101.json` read this turn): `decision: "go"`, `policy: "JULIA_GPU_OK"`, `window_seconds_left: 1,123,022` (~13 days), probe VRAM 12,719 MB free, RAM 25.06 GB avail, GPU util 1%, foreign_julia 0. `critic` workload class permitted (line 17 of allowed_workloads). Critic is Read-only (no julia spawn); compatible with any scheduler policy including the most restrictive TEXT_ONLY.
- **Seed.md status**: dated 2026-05-15 morning, references a julia parallel sweep that completed long ago. Per anko 2026-05-16 PROBE_DRIVEN clause: scheduler is authoritative. The "implementer-with-julia forbidden" clause from seed is not active. Even so, T101 dispatches critic (Read-only), so the question is moot.
- **Drift advisories on T100** (state.json line 2273-2277): `DRIFT_MANUSCRIPT_DELTA_ZERO` (expected; manuscript not in scope per §A5), `DRIFT_COST_INFLATION` (T100 1.04× — within normal; not actionable), `AUDIT_DUE: gap=12`. **Audit deferral**: per T100 director §1 and reaffirmed here, the Tier-3 closure arc T98->T99->T100->T101->T102 is higher leverage than dropping mid-chain for a periodic scan. T103 is the natural insertion point (post-Document closure). At gap=14 by T103, still within reasonable bound (audit-class-scan cadence is loose ~10 turns).
- **Meta interleave gap**: 6 consecutive physics turns (T95 researcher, T96 theorist, T97 implementer, T98 researcher, T99 theorist, T100 implementer). Newly-spawned meta-investigation at T100 is at Observe (no actionable dispatch yet — no Hypothesize-ready trigger). Acceptable to defer one more turn for Tier-3 closure.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T98 | Research | RESEARCH_PASS | researcher_shallow extracted KU2012 §4.2 / §5 / SKU2013 §IV / Uchino-Kobayashi-Ueda 2010 closed-forms. 6 falsifier candidates, 3 load-bearing (F1/F2/F3). BdG-vs-GP factor-2 PARTIALLY_RESOLVED. |
| T99 | Hypothesize | PASS (20/20 criteria) | theorist explicitly constructed 6×6 Nambu L(k) at F=1 polar and FM via CG-orthogonality (table C.0); proved algebraically Sigma^HF_{0,0}\|polar = 2 c_0 n; polar phonon eigenvalue = epsilon_k(epsilon_k + 2 c_0 n) reproduces KU2012; BdG/GP factor-2 ratio = 2.0 exact via second-functional-derivative structure (NOT a bug). Falsifiers formalized. state.json registered. T100 pre-flight brief delivered. |
| T100 | Execute | PASS (18/18 criteria, EXECUTE_PASS) | implementer_julia_cpu_light wrote 35-line `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`, ran in 2.15s (warm JIT), all three load-bearing falsifiers PASS by 100×-750× margin. F4 Goldstone gap exact zero. Minor numerical-method tweak from T99 template: k-range [0.001, 0.01] + least-squares fit (vs T99's [0.01, 0.1] + chord slope) reduced rel_err from ~1.5e-3 (above threshold) to ~8e-6 (well below). Adaptation documented in §3. No `src/` modification; no manuscript edit. Tier 1.5 -> 2.5 confirmed. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1) — D1 Tier-3 verification of [Established] internal claim against KU2012 §4.2 external closed-forms.
- **Stage chosen for T101**: **Update**. Per §F1 sequence Research -> Hypothesize -> Design -> Execute -> **Update** -> Document -> closed. T99 absorbed Design into Hypothesize, so the natural progression is Execute (T100) -> Update (T101) -> Document (T102) -> closed.
- **Role per §F1 `role_per_stage["Update"]`**: **`critic`** (mandatory; independent context). §F1 line: "if REFUTED, hypothesis revised + tier-- or tier_target--; if CONFIRMED, tier++". T101 is the standard Update-stage critic dispatch.
- **Why this stage now (vs different investigation, vs meta, vs audit)**:
  - **Continue the chain**: T100 PASS leaves the canonical Update baton. T100 implementer §7 specifically pre-staged the critic checklist (3 audit items). Dropping the thread now wastes the structural setup.
  - **Critic is workload-light** (Read-only; no julia spawn; ~1.0-1.4M effective historical norm per T58 klaus-bch CORROBORATE-WITH-ERRATA at 1.3M, T78 lemma1-tier3 CORROBORATE at 1.1M). Matches scheduler permissiveness; no contention.
  - **Tier 3 is achievable in this single turn**: critic CORROBORATE verdict directly advances tier 2.5 -> 3.0 (no additional Hypothesize/Execute round needed). T102 then closes the investigation with a memory entry.
  - **Meta interleave deferred**: meta-director-self-audit at Observe (priority 20) does not have an actionable Hypothesize-ready trigger. T103 is the natural insertion point.
  - **Audit-class-scan deferred**: gap=12; arc-closure at T102 means T103 audit at gap=14 is still within cadence.
  - **No urgent physics elsewhere**: bug-4 closed Tier 2; tier3-survey #4 (TwoChannelLHY F=6) capped at Tier 2.5 with NOT_FOUND benchmark; edh-matsui closed Tier 3.
  - **Template-shape match**: T58 klaus-bch-leak Update (critic CORROBORATE-WITH-ERRATA -> Tier 3), T78 sign-pattern-lemma1 Update (critic CORROBORATE -> Tier 3) are the structural precedents. Same flow_template, same stage, same role. APC contract template cache applicable (see §4).

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference for Hypothesize/Design stages. Update is a critic-audit stage; §A6 technically not stringent, but to keep the audit chain grounded I anchor to literature + prior loop turns:

1. **Kawaguchi-Ueda 2012 "Spinor Bose-Einstein condensates" Physics Reports 520, 253 [arXiv:1001.2072]** §5 (Phys Rep) / §4.2 (preprint) — the external benchmark whose F=1 polar/FM phonon and polar magnon closed-forms T99 derived from and T100 numerically verified. The critic's job: re-derive via a structurally different route (e.g., explicit substitution into the BdG eigenvalue problem at zero anomalous coupling, or via the c_0/c_1 mean-field GP linearization route) and check the result is identical. KU2012 §5.1.2 spells out the alternate route via $\delta\phi = u e^{i(k\cdot r - \omega t)} - v^* e^{-i(k\cdot r - \omega t)}$ substitution into the GP equation (NOT the BdG-self-energy form). This is exactly the "different parameter point / different derivation route" structure the critic should mirror.
2. **Stamper-Kurn & Ueda 2013** RMP 85, 1191 [arXiv:1205.1888] §IV.B.1 — independent textbook treatment with different (Heisenberg-equation) derivation route. Provides a second algebraic anchor for the critic's structurally-different re-derivation.
3. **Memory `tier3_pipeline_survey_2026_05_18`** (§"5-candidate menu" item 5) — this investigation was named in the T69 survey as the 5th-priority Tier-3 promotion candidate. T101 CORROBORATE closes the menu item (5th Tier-3 closure in flight).
4. **Prior loop turn T93 critic structure** (sign-pattern-lemma1, judge/turn_93.json `CORROBORATE`) — methodological template: the T93 critic delivered 3 structurally-independent falsifiers (F1 CG-table re-derivation, F2 prefactor-algebra well-definedness, F3 sum-rule identity). T101 critic should mirror this 3-falsifier structure: F1' alternate-route algebra, F2' independent numerical recompute at fresh parameter points, F3' systematic-error audit.
5. **APC contract template cache** (arXiv:2506.14852): `physics::verify-claim::Update` template `n_seen: 3` (T58 klaus-bch, T78 lemma1, T93 sign-pattern-lemma1). Cached skeleton uses: success_criteria field structure with `verdict in [CORROBORATE, CORROBORATE_WITH_ERRATA, REFUTED]`, `independent_derivation_route_present == true`, `independent_numerical_recompute_present == true`, `audit_finding_count >= 0`, `tier_reached >= 3.0`; failure_modes shape: REFUTED -> fix-bug spawn + tier revert, CORROBORATE_WITH_ERRATA -> Document with caveats + tier 2.75. Adaptation: preserve structural skeleton; patch in the three tdhfb-specific falsifiers + numerical thresholds.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. TDHFB Phase 2 generic-F HF kernel: T100 numerical PASS at one parameter point + T99 algebraic derivation. T101 critic adds (a) independent algebraic re-derivation via structurally different route, (b) independent numerical recompute at fresh parameters (e.g., c_0=2.0 polar + c_0=0.5 FM), (c) systematic-error audit. Tier 2.5 -> 3.0 (Tier 3 = published-reference benchmarked + independent corroboration).
- **Tier ladder position**: 2.5 -> 3.0 on critic CORROBORATE. This becomes the 6th project Tier-3 closure (after barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, plus the in-flight one).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. T101 critic writes ONLY: `runs/_loop/critic/turn_101.md` (per-turn report). No `docs/`, no `docs/manuscript/`, no `src/` changes.
- **Cost frame for T101**: target **1.3M effective** (critic Read-only norm). HARD CAP **2.0M**. Critic precedents at this template: T58 1.3M, T78 1.1M, T93 1.5M (last was longer due to 3-falsifier structure mirrored here). The DRIFT_COST_INFLATION advisory from T99/T100 (now 1.04× — within normal) does not push for a tighter budget.
- **Drift trajectory after T101 (anticipated)**:
  - cost_inflation: ~1.0 (1.3M target vs running median ~1.4M).
  - code_delta_zero: 1.0 (critic is Read-only; no code delta expected — correct).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: variable (a critic CORROBORATE makes no novel claim; a CORROBORATE_WITH_ERRATA documents a small caveat; either is fine).
  - subagent_repetition: critic gap since T93 = 8 turns. Healthy rotation.
  - topic_repetition: 0.80 (TDHFB consecutive turn 4 — last of the arc; T102 Document is the natural close, T103 onward must switch).

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T100 EXECUTE_PASS (18/18 criteria, judge/turn_100.json status=PASS) cleared all three load-bearing falsifiers by 100x-750x margin (F1 rel_err 7.86e-6 vs 1e-3 threshold, F2 rel_err 8.74e-6 vs 1e-3, F3 abs_err 1.33e-15 vs 1e-12) plus F4 Goldstone exact-zero advisory. Per §F1 verify-claim Update stage role = critic (mandatory; independent context). Tier 2.5 -> 3.0 is one critic CORROBORATE away. T101 dispatches critic with three structurally-independent audit items: (a) alternate-route algebraic re-derivation via KU2012 §5.1.2 GP-linearization (not T99's BdG-self-energy CG-orthogonality route), (b) independent numerical recompute at two fresh parameter points (polar c_0=2.0/c_1=+0.05 + FM c_0=0.5/c_1=-0.2) using the existing diagnostic script with arg overrides, (c) systematic-error audit of mu choice, k-grid linear-regime selection, and Delta-block symmetry assumption. Critic is Read-only; scheduler JULIA_GPU_OK fully permits. T58/T78/T93 are the structural precedents; APC cache n_seen=3 for this template triple. Budget ~1.3M (T78 norm). On CORROBORATE -> tier 3.0 + T102 Document. On CORROBORATE_WITH_ERRATA -> tier 2.75 + targeted T102 follow-up. On REFUTED -> tier reverts to 1.5 + fix-bug spawn.",
  "brief": "## ROLE\n\nYou are critic (workload class: `critic`). T101 §F1 Update stage of investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. Your job: produce an INDEPENDENT corroboration (or refutation) of T100's EXECUTE_PASS, by (a) re-deriving the polar phonon eigenvalue via a structurally DIFFERENT algebraic route than T99 used, (b) independently re-running the script at two fresh parameter points to detect parameter-tuning artifacts, (c) auditing the load-bearing assumptions (mu choice, k-grid linear-regime selection, Delta-block construction). Read-only; you may run the existing diagnostic Julia script with new parameter values but you MUST NOT modify `src/`, `runs/_loop/state.json`, `docs/`, or the production code. You MAY modify a temporary parameter override copy of the script (place at `/tmp/`) if needed for the recompute.\n\nDIRECTIVE_LABEL: tdhfb-phase2-tier3-T101-update-critic-independent-corroborate\n\nWrite final report to `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_101.md`.\nDo NOT modify any file under `src/`, `docs/`, `runs/_loop/state.json`, `test/`, `runs/eu151_*/`, `.claude/`, or the existing `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`.\n\n## REQUIRED READING (in this order, full files)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_101.md` ENTIRE (this report).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_100.md` ENTIRE (the implementer report you are auditing — especially §2 script source, §3 execution log including the k-range/least-squares adaptation, §4 numerical results, §7 limitations).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md` §2 Derivation C.0-C.6 (the algebraic ground truth — you must NOT mirror this derivation; you must construct an INDEPENDENT route).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_100.json` ENTIRE.\n5. `/home/suzume/workspace/BEC-simulation/scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` ENTIRE (35 lines).\n6. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` (kernel under audit — read full file).\n7. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl` (F=1 GP kernel for ratio comparison).\n8. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/channel_kernel.jl` (anomalous Delta block construction).\n9. `/home/suzume/workspace/BEC-simulation/runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md` (currently has one stub [Established] entry from T99 — your verdict updates this).\n10. `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_58.md` and `runs/_loop/critic/turn_93.md` (structural precedents — same flow_template same stage; use as METHOD template not as content template).\n\n## DELIVERABLES\n\n### Deliverable A — Independent algebraic re-derivation (structurally different route)\n\nT99 derived the polar phonon eigenvalue $\\omega^2 = \\epsilon_k(\\epsilon_k + 2 c_0 n)$ via (1) explicit CG table for F=1 channel decomposition, (2) sum over channels $S \\in \\{0,2\\}$ at the polar GS to get $\\Sigma^{HF}_{0,0} = 2 c_0 n$, (3) construct 6×6 Nambu $L(k)$, (4) extract the (m=0, m=0) block as a 2×2 BdG matrix with eigenvalues $\\pm\\sqrt{\\epsilon_k(\\epsilon_k + 2 c_0 n)}$.\n\nYour task: re-derive the SAME result by a STRUCTURALLY DIFFERENT route. Acceptable independent routes (pick ONE; document why your choice is structurally different):\n\n**Route I (GP-linearization, KU2012 §5.1.2 preprint)**: Start from the F=1 GP equation $i\\hbar\\partial_t \\phi_m = (-\\hbar^2\\nabla^2/(2m) + V_{\\rm ext} - \\mu)\\phi_m + c_0 n \\phi_m + c_1 \\sum_\\alpha F_\\alpha\\langle F_\\alpha\\rangle \\phi_m$ where $\\langle F_\\alpha\\rangle = \\sum_{m'm''}\\phi^*_{m'}(F_\\alpha)_{m'm''}\\phi_{m''}$. Linearize around polar GS $\\phi^{(0)} = (0, \\sqrt{n}, 0)$ with fluctuation ansatz $\\delta\\phi_m = u_m e^{i(k\\cdot r - \\omega t)} - v^*_m e^{-i(k\\cdot r - \\omega t)}$. The m=0 channel (longitudinal density mode) decouples from m=±1 channels at polar GS because $\\langle F_\\alpha\\rangle = 0$ identically. Show that for the m=0 channel only, the 2×2 BdG equation $\\begin{pmatrix} \\epsilon_k + c_0 n & c_0 n \\\\ -c_0 n & -(\\epsilon_k + c_0 n) \\end{pmatrix}\\begin{pmatrix} u \\\\ v \\end{pmatrix} = \\omega\\begin{pmatrix} u \\\\ v \\end{pmatrix}$ has eigenvalues $\\pm\\sqrt{\\epsilon_k(\\epsilon_k + 2 c_0 n)}$. NOTE: this gives the same answer as T99 but via the GP form (first functional derivative) NOT the BdG self-energy (second functional derivative). The factor 2 in $2 c_0 n$ appears here because the BdG matrix has $c_0 n$ on the diagonal AND $c_0 n$ on the anomalous off-diagonal: $\\epsilon_k(\\epsilon_k + c_0 n + c_0 n) = \\epsilon_k(\\epsilon_k + 2 c_0 n)$. T99's route gets the 2 from Bose symmetrization inside h^HF; YOUR route gets the 2 from summing diagonal + anomalous. The two routes coincide because the BdG self-energy structure $\\Sigma^{HF} = h_{\\rm diag} + h_{\\rm anom}$ unfolds the GP-route 2 into a single matrix element of $\\Sigma^{HF}$. Document this structural equivalence.\n\n**Route II (Heisenberg-equation, SKU2013 §IV.B.1)**: Define density and spin fluctuation operators $\\delta n(r,t) = \\sum_m \\delta\\phi^*_m\\phi^{(0)}_m + \\phi^{(0)*}_m\\delta\\phi_m$ and $\\delta F_\\alpha(r,t)$ similarly. Write Heisenberg equations for $\\delta n$ and $\\delta F_\\alpha$ around polar GS; observe that $\\delta n$ decouples (polar magnon would couple $\\delta F_\\alpha$ instead). Solve the linearized equation for $\\delta n$ to get the phonon dispersion. This is the textbook RMP route.\n\n**Route III (sum-rule / f-sum + compressibility, NOT applicable for k-dependent dispersion** — sum rules give cs at k=0 but not the full $\\omega(k)$. List as unsuitable for falsifying full dispersion; suitable only for cs cross-check at k=0.\n\nDeliverable A1: Pick Route I or Route II, derive $\\omega^2(k) = \\epsilon_k(\\epsilon_k + 2 c_0 n)$ at F=1 polar, document the algebra in critic report §2. Show explicitly that the 2 in front of $c_0 n$ has a different ORIGIN than in T99's route (sum-of-diagonal-and-anomalous vs Bose-symmetrization-in-h^HF) but the same algebraic VALUE — this is the strongest form of independent confirmation.\n\nDeliverable A2: Apply the same route to F=1 FM ($\\zeta = (1,0,0)$, $\\mu = (c_0 + c_1)n$) and derive $\\omega^2(k) = \\epsilon_k(\\epsilon_k + 2(c_0 + c_1) n)$. Confirms the FM phonon expected value $\\sqrt{(c_0 + c_1)n}$.\n\nDeliverable A3: At F=1 polar, also derive the polar MAGNON dispersion $\\omega^2(k) = \\epsilon_k(\\epsilon_k + 2 c_1 n)$ from the m=±1 (transverse) channels. This was NOT tested at T100 (F1 only checked the phonon = m=0 channel); briefly state whether this matters for the Tier-3 claim. (Answer expected: no, because the [Established] claim is about the kernel reproducing KU2012 generally — F1+F2 demonstrate this for the phonon branches; polar magnon would be a Tier-3.5 extension. Document this scope boundary.)\n\n### Deliverable B — Independent numerical recompute at fresh parameter points\n\nUsing the existing `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` (DO NOT MODIFY THIS FILE), construct a parameter-override invocation. The cleanest approach: copy the script to `/tmp/tdhfb_f1_bogoliubov_T101_critic_recompute.jl` and modify the three `bdg_omegas(...)` and the F3 call signatures with new parameter values:\n\n- **Polar fresh point**: $c_0 = 2.0$, $c_1 = +0.05$, $n = 1.0$, $\\mu = c_0 n = 2.0$, $\\zeta = (0, 1, 0)$. Expected $c_s^{\\rm polar} = \\sqrt{c_0 n / m} = \\sqrt{2.0} \\approx 1.41421$. F3 ratio still 2.0 (parameter-independent).\n- **FM fresh point**: $c_0 = 0.5$, $c_1 = -0.2$, $n = 1.0$, $\\mu = (c_0 + c_1) n = 0.3$, $\\zeta = (1, 0, 0)$. Expected $c_s^{\\rm FM} = \\sqrt{(c_0+c_1) n / m} = \\sqrt{0.3} \\approx 0.54772$. Note: $c_1 / c_0 = -0.4$ is a larger ratio than T100's $-0.1$, exercising the FM channel structure more.\n\nRun: `timeout 600 /home/suzume/.juliaup/bin/julia --project=. /tmp/tdhfb_f1_bogoliubov_T101_critic_recompute.jl 2>&1 | tee /tmp/tdhfb_T101_critic.log` from `/home/suzume/workspace/BEC-simulation`. Parse the stdout JSON. Threshold: rel_err < 1e-3 for both sound velocities, abs_err < 1e-12 for F3 ratio (same as T100).\n\n**Optional Deliverable B-extra (only if time allows + ~200k under budget)**: One additional FM point at $c_0 = 1.0$, $c_1 = -0.5$ (stronger FM coupling, $\\mu = 0.5$, $c_s = \\sqrt{0.5} \\approx 0.7071$) — useful for confirming the FM expression is not parameter-tuned to small $|c_1|$.\n\n### Deliverable C — Systematic-error audit (the qualitative half of the corroboration)\n\nReview T100 sim §3 (script execution + adaptations) and §7 (limitations). Three load-bearing assumptions need explicit audit:\n\n**C1. mu choice**: The script sets $\\mu = c_0 n$ for polar and $\\mu = (c_0 + c_1) n$ for FM. Confirm these are the correct mean-field $\\mu$ values (NOT a tuning hack). Independent check: at the polar GS the GP equation reads $\\mu\\phi^{(0)}_{m=0} = c_0 |\\phi^{(0)}_{m=0}|^2 \\phi^{(0)}_{m=0}$ giving $\\mu = c_0 n$ exactly — so the script's $\\mu$ is determined by the GS, not free to tune. Document this. If the script had used a wrong $\\mu$ (e.g., $\\mu = 2 c_0 n$ from misreading BdG/GP factor), the Goldstone gap F4 would be non-zero; F4 = 0.0 exactly is the consistency check. Confirm or refute.\n\n**C2. k-grid linear-regime selection**: T100 §3 documents that the k-range had to be shifted from $[0.01, 0.1]$ to $[0.001, 0.01]$ to get rel_err below 1e-3, because $\\omega/k = c_s \\sqrt{1 + \\epsilon_k/(2 c_0 n)}$ has a finite-k correction proportional to $k^2$. This is the expected physical shape (NOT a numerical artifact). Verify by computing $\\omega/k - c_s$ at the largest k point and confirming it scales as $k^2 / (4 c_s n c_0)$ as the Taylor expansion predicts. If the residual deviation matches the predicted scaling, the k-grid choice is sound and the rel_err measured at T100 (~8e-6) is dominated by the leading $k^2$ correction, NOT by numerical noise. If the deviation does NOT match $k^2$ scaling, something else is going on (eigvals branch selection, sign convention) and the PASS should be downgraded to CORROBORATE_WITH_ERRATA.\n\n**C3. Delta-block construction**: T100 §3 A3 documents that the un-symmetrized `channel_kernel` was used to build the anomalous block: $\\Delta_{m,m'} = \\sum_{m_2, m_2'} V_{m,m';m_2,m_2'} \\phi_{m_2} \\phi_{m_2'}$. The convention used (symmetrization-on-the-fly via the explicit product $\\phi_{m_2}\\phi_{m_2'}$) gives a symmetric $\\Delta$ in (m_2, m_2') because the product is symmetric. Verify that this matches the convention used in the TDHFB $\\kappa$-equation source (`src/hamiltonian/tdhfb/`) where the anomalous self-energy appears. If consistent: PASS. If `channel_kernel` is consumed elsewhere with explicit symmetrization (e.g., divide-by-2), there's a convention mismatch and we have a hidden factor-2 in the script. F3 PASS at 2.0±1e-15 strongly argues against a hidden factor-2 (which would show as ratio = 4.0 or 1.0), but the audit should grep the codebase for all `channel_kernel` call sites to confirm convention uniformity. Run: `grep -rn 'channel_kernel' src/ test/` and document the 1-3 call sites.\n\n### Deliverable D — Critic report `runs/_loop/critic/turn_101.md`\n\nSections:\n\n- §0. Directive received (mirror this contract block)\n- §1. Pre-audit context (what is being audited; T99 + T100 deliverables summarized; route selected for independent derivation)\n- §2. Independent algebraic re-derivation (Deliverable A — full algebra)\n- §3. Independent numerical recompute (Deliverable B — script delta + execution log + results)\n- §4. Systematic-error audit (Deliverable C1, C2, C3)\n- §5. Verdict synthesis (CORROBORATE / CORROBORATE_WITH_ERRATA / REFUTED) + tier recommendation\n- §6. METRICS JSON (per schema below)\n- §7. Conclusions index update text (T101 [Established] entry to append to `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md` — write the text in critic report, do NOT actually modify the conclusions file; orchestrator handles)\n\n### Deliverable E — Repository hygiene\n\n- `git status` should show only `runs/_loop/critic/turn_101.md` (new). If a `/tmp/` recompute script was created, that is outside the repo and irrelevant for git.\n- Do NOT modify any tracked file.\n- Do NOT commit.\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"critic_audit\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\",\n  \"stage_advancing_to\": \"Update\",\n  \"flow_template\": \"verify-claim\",\n  \"independent_derivation_route_chosen\": \"<I_GP_linearization | II_Heisenberg_equation | III_sum_rule (unsuitable, explain)>\",\n  \"independent_derivation_route_structurally_different\": <bool; must be true to qualify as independent>,\n  \"independent_derivation_reproduces_polar_phonon_value\": <bool; epsilon_k(epsilon_k + 2 c_0 n) confirmed>,\n  \"independent_derivation_reproduces_fm_phonon_value\": <bool; epsilon_k(epsilon_k + 2(c_0+c_1) n) confirmed>,\n  \"independent_derivation_reproduces_polar_magnon_value\": <bool or null if not derived; scope-boundary discussion in §2>,\n  \"factor_2_origin_in_independent_route\": \"<diagonal_plus_anomalous_sum | bose_symmetrization | other>\",\n  \"recompute_polar_c0_2_c1_05_cs_measured\": <float>,\n  \"recompute_polar_c0_2_c1_05_cs_expected\": 1.4142135623730951,\n  \"recompute_polar_rel_error\": <float>,\n  \"recompute_polar_pass\": <bool>,\n  \"recompute_fm_c0_05_cm1_02_cs_measured\": <float>,\n  \"recompute_fm_c0_05_cm1_02_cs_expected\": 0.5477225575051661,\n  \"recompute_fm_rel_error\": <float>,\n  \"recompute_fm_pass\": <bool>,\n  \"recompute_factor_2_ratio_measured\": <float>,\n  \"recompute_factor_2_ratio_abs_error\": <float>,\n  \"recompute_factor_2_ratio_pass\": <bool>,\n  \"all_recompute_falsifiers_passed\": <bool; AND of three>,\n  \"audit_mu_choice_verdict\": \"<sound | suspect | broken>\",\n  \"audit_kgrid_finite_k_correction_matches_k_squared\": <bool>,\n  \"audit_delta_block_convention_uniform\": <bool>,\n  \"audit_channel_kernel_call_sites_count\": <int>,\n  \"audit_finding_count_total\": <int; sum of suspect/broken findings across C1+C2+C3>,\n  \"audit_finding_severity_max\": \"<none | minor_erratum | major_caveat | refutation>\",\n  \"src_files_modified\": 0,\n  \"docs_modified\": 0,\n  \"manuscript_main_edited\": false,\n  \"production_script_modified\": false,\n  \"tier_reached\": <float; 3.0 if CORROBORATE; 2.75 if CORROBORATE_WITH_ERRATA; 1.5 if REFUTED>,\n  \"verdict\": \"<CORROBORATE | CORROBORATE_WITH_ERRATA | REFUTED | CRITIC_OPERATIONAL_FAIL>\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT mirror T99's CG-orthogonality derivation. That is the SAME route restated; not independent. Pick Route I (GP linearization) or Route II (Heisenberg equation). If you find yourself summing over $\\langle F m, F m_2 | S M\\rangle$ CG coefficients, you are on the wrong route — that is T99's pattern, not independent.\n- Do NOT modify `src/`. The point of this turn is to corroborate the existing kernel; any \"fix\" or patch mid-audit breaks the chain.\n- Do NOT modify `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`. Copy to `/tmp/` for the recompute; the production script stays as-is.\n- Do NOT issue PASS just because T100 issued PASS. Independent re-derivation + independent numerical recompute at fresh parameters + systematic-error audit are the three conditions; ALL must clear for CORROBORATE.\n- Do NOT skip Deliverable A (algebra). A purely numerical audit at a fresh parameter point is necessary but not sufficient — the algebra audit catches systematic conventional errors that all numerical points would mask.\n- Do NOT improvise terminology per `feedback_no_improvised_terminology`. Use: Bogoliubov-de Gennes (BdG), Gross-Pitaevskii (GP), Nambu space, anomalous block, phonon branch, magnon branch, polar phase, ferromagnetic (FM) phase, sound velocity, mean-field, BdG self-energy, GP Hamiltonian, Hartree-Fock kernel, Bose symmetrization, channel decomposition.\n- English only. No emojis.\n- HARD CAP 2.0M effective tokens. Target 1.3M.\n- HARD CAP 600s wall-time (the only julia run is one parameter override of a 2.15s script; budget 60s).\n- Do NOT commit.\n\n## SUCCESS DEFINITION\n\nT101 PASS = your report:\n\n1. Independent algebraic re-derivation via Route I or Route II reproduces $\\omega^2 = \\epsilon_k(\\epsilon_k + 2 c_0 n)$ at F=1 polar AND $\\omega^2 = \\epsilon_k(\\epsilon_k + 2(c_0+c_1) n)$ at F=1 FM, with the structural origin of the factor 2 documented as different from T99's Bose-symmetrization.\n2. Independent numerical recompute at the two fresh parameter points passes the same thresholds T100 used (polar cs_rel_err < 1e-3, FM cs_rel_err < 1e-3, F3 ratio abs_err < 1e-12).\n3. Systematic-error audit C1 (mu choice) verdict = `sound`, C2 (k-grid finite-k correction) verdict = matches $k^2$ scaling, C3 (Delta-block convention) verdict = uniform across call sites OR documented divergence is minor erratum (not load-bearing).\n4. METRICS JSON parses cleanly; verdict ∈ {CORROBORATE, CORROBORATE_WITH_ERRATA, REFUTED, CRITIC_OPERATIONAL_FAIL}; tier_reached ≥ 2.5 (always; CORROBORATE bumps to 3.0).\n5. No `src/`, `docs/`, `runs/_loop/state.json`, `runs/eu151_*/`, `.claude/`, or production-script files modified.\n\nOn CORROBORATE (Route I/II algebra independent + recompute PASS + audit clean): tier 2.5 -> 3.0; T102 director dispatches implementer_text for Document closure (memory entry, conclusions index [Established] update, state.json `current_stage: closed`).\nOn CORROBORATE_WITH_ERRATA (Route I/II algebra independent + recompute PASS + ≥1 minor audit caveat, e.g., scope-boundary on polar magnon, OR documented Delta-block convention divergence that doesn't affect F1/F2/F3): tier 2.5 -> 2.75; T102 director dispatches implementer_text Document with caveat memo + targeted follow-up plan. Tier 3 deferred pending caveat resolution.\nOn REFUTED (Route I/II algebra DOES NOT reproduce polar phonon eigenvalue, OR recompute FAILS one of the three falsifiers, OR audit C1/C2/C3 finds a load-bearing flaw): tier reverts 2.5 -> 1.5; T102 director spawns fix-bug investigation `tdhfb-generic-f-kernel-regression-T101-{specific-issue}` and dispatches theorist or implementer for diagnosis.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "independent_derivation_route_chosen",
      "independent_derivation_route_structurally_different",
      "independent_derivation_reproduces_polar_phonon_value",
      "independent_derivation_reproduces_fm_phonon_value",
      "factor_2_origin_in_independent_route",
      "recompute_polar_c0_2_c1_05_cs_measured",
      "recompute_polar_rel_error",
      "recompute_polar_pass",
      "recompute_fm_c0_05_cm1_02_cs_measured",
      "recompute_fm_rel_error",
      "recompute_fm_pass",
      "recompute_factor_2_ratio_measured",
      "recompute_factor_2_ratio_abs_error",
      "recompute_factor_2_ratio_pass",
      "all_recompute_falsifiers_passed",
      "audit_mu_choice_verdict",
      "audit_kgrid_finite_k_correction_matches_k_squared",
      "audit_delta_block_convention_uniform",
      "audit_finding_count_total",
      "audit_finding_severity_max",
      "src_files_modified",
      "production_script_modified",
      "tier_reached",
      "verdict"
    ],
    "optional": [
      "independent_derivation_reproduces_polar_magnon_value",
      "audit_channel_kernel_call_sites_count",
      "docs_modified",
      "manuscript_main_edited"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_101.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_100.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_100.json && test -f /home/suzume/workspace/BEC-simulation/scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/channel_kernel.jl && /home/suzume/.juliaup/bin/julia --version >/dev/null 2>&1 && python3 -c 'import json; d=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); inv = d[\"investigations\"][\"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\"]; assert inv[\"tier_current\"] == 2.5, f\"TIER_MISMATCH: expected 2.5 got {inv[\\\"tier_current\\\"]}\"; assert inv[\"next_stage\"] == \"Update\", f\"STAGE_MISMATCH: expected Update got {inv[\\\"next_stage\\\"]}\"; print(\"PRECONDITIONS_OK\")'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "critic_audit",
      "rationale": "Critic Update-stage audit; not implementer experiment."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
      "rationale": "Continuing investigation from T100."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Update",
      "rationale": "§F1 verify-claim sequence after Execute."
    },
    {
      "id": "route_actually_independent",
      "metric": "independent_derivation_route_structurally_different",
      "operator": "==",
      "value": true,
      "rationale": "Critic CORROBORATE requires structurally-independent derivation (Route I GP-linearization or Route II Heisenberg-equation, NOT T99's CG-orthogonality route). False here = the audit didn't actually corroborate independently."
    },
    {
      "id": "route_reproduces_polar_phonon",
      "metric": "independent_derivation_reproduces_polar_phonon_value",
      "operator": "==",
      "value": true,
      "rationale": "The KU2012 polar phonon dispersion ω² = ε_k(ε_k + 2 c_0 n) MUST be re-derived independently. If false, the [Established] T99 claim is in question."
    },
    {
      "id": "route_reproduces_fm_phonon",
      "metric": "independent_derivation_reproduces_fm_phonon_value",
      "operator": "==",
      "value": true,
      "rationale": "FM phonon dispersion ω² = ε_k(ε_k + 2(c_0+c_1) n) must also clear via the independent route."
    },
    {
      "id": "recompute_polar_passes",
      "metric": "recompute_polar_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "Polar fresh parameter point (c_0=2.0, c_1=+0.05, cs_expected=√2) must reproduce to same threshold T100 used."
    },
    {
      "id": "recompute_polar_pass_bool",
      "metric": "recompute_polar_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror."
    },
    {
      "id": "recompute_fm_passes",
      "metric": "recompute_fm_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "FM fresh parameter point (c_0=0.5, c_1=-0.2, cs_expected=√0.3) must reproduce. Larger |c_1/c_0|=0.4 ratio is the harder test (vs T100's 0.1)."
    },
    {
      "id": "recompute_fm_pass_bool",
      "metric": "recompute_fm_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror."
    },
    {
      "id": "recompute_factor_2_passes",
      "metric": "recompute_factor_2_ratio_abs_error",
      "operator": "<=",
      "value": 1e-12,
      "rationale": "Parameter-independent factor 2 ratio must remain at 2.0 within fp precision at the fresh polar point."
    },
    {
      "id": "all_recompute_pass",
      "metric": "all_recompute_falsifiers_passed",
      "operator": "==",
      "value": true,
      "rationale": "AND of three recompute falsifiers; any single failure → CORROBORATE_WITH_ERRATA or REFUTED."
    },
    {
      "id": "audit_mu_sound",
      "metric": "audit_mu_choice_verdict",
      "operator": "==",
      "value": "sound",
      "rationale": "μ choice C1 audit must conclude the script's μ values are exactly the mean-field GP-determined values (not free tuning)."
    },
    {
      "id": "audit_kgrid_correction_physical",
      "metric": "audit_kgrid_finite_k_correction_matches_k_squared",
      "operator": "==",
      "value": true,
      "rationale": "C2 audit: finite-k deviation must scale as k² (physical correction from full ω² = ε_k(ε_k + 2 c_0 n) expansion), not random noise."
    },
    {
      "id": "audit_delta_block_uniform",
      "metric": "audit_delta_block_convention_uniform",
      "operator": "==",
      "value": true,
      "rationale": "C3 audit: channel_kernel call-site convention must be uniform across the codebase (no hidden factor-2 from inconsistent symmetrization)."
    },
    {
      "id": "no_src_modification",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Critic is Read-only by template definition."
    },
    {
      "id": "no_production_script_modification",
      "metric": "production_script_modified",
      "operator": "==",
      "value": false,
      "rationale": "Recompute uses a /tmp/ copy; the production diagnostic script stays untouched for reproducibility."
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
      "value": 2.5,
      "rationale": "Floor: critic must at least preserve tier 2.5. CORROBORATE → 3.0; CORROBORATE_WITH_ERRATA → 2.75; REFUTED → 1.5 (separate failure_mode handles the downgrade)."
    },
    {
      "id": "verdict_in_registered_set",
      "metric": "verdict",
      "operator": "in",
      "value": ["CORROBORATE", "CORROBORATE_WITH_ERRATA", "REFUTED", "CRITIC_OPERATIONAL_FAIL"],
      "rationale": "Verdict token must be one of the four registered states; each routes to a specific T102 failure_mode action."
    }
  ],
  "failure_modes": [
    {
      "if": "verdict == 'REFUTED' OR independent_derivation_reproduces_polar_phonon_value == false OR all_recompute_falsifiers_passed == false",
      "category": "scientific_refuted_kernel_or_derivation",
      "next_action": "REFUTATION at the Update stage: either the T99 algebra was wrong (unlikely; T99 critic-equivalent algebraic content was already audited at T99 internal review) OR the kernel implementation has a regression OR the recompute at fresh parameters exposes a parameter-dependent failure mode the original T100 single-point didn't catch. T102 director: (a) read the critic report identifying WHICH falsifier failed and at what magnitude; (b) spawn fix-bug investigation `tdhfb-generic-f-kernel-regression-T101-{specific-issue}` with the critic's failing case as the minimal reproducer; (c) tier reverts 2.5 → 1.5; (d) dispatch theorist to algebraically locate the discrepancy before any code patch. TDHFB Tier-3 trajectory pauses."
    },
    {
      "if": "verdict == 'CORROBORATE_WITH_ERRATA' OR audit_finding_severity_max == 'minor_erratum' OR audit_finding_severity_max == 'major_caveat'",
      "category": "partial_corroboration",
      "next_action": "Algebra + recompute clear, but ≥1 audit finding raises a caveat (e.g., scope boundary on polar magnon, or a Delta-block convention divergence that doesn't affect F1/F2/F3 but is worth documenting, or a non-load-bearing erratum like a typo in T99 §C.3 derivation step that didn't affect the final answer). T102 director: (a) dispatch implementer_text for Document stage with the caveat captured in the memory entry; (b) tier becomes 2.75 (between 2.5 and 3.0); (c) decide whether to spawn a sub-investigation for the caveat (only if caveat blocks an actual application — usually no). Investigation closes at 2.75 unless caveat is followed up explicitly."
    },
    {
      "if": "verdict == 'CRITIC_OPERATIONAL_FAIL' OR src_files_modified > 0 OR production_script_modified == true",
      "category": "operational",
      "next_action": "Critic drifted from contract scope (modified src/, modified production script, or operational fail like /tmp/ recompute script bug). T102 director audits via git diff, reverts unintended changes, re-dispatches critic with stricter scope. Investigation tier preserved at 2.5 (no downgrade for operational issue alone)."
    },
    {
      "if": "verdict == 'CORROBORATE' AND all_recompute_falsifiers_passed == true AND audit_finding_severity_max == 'none' AND independent_derivation_route_structurally_different == true",
      "category": "success_tier_3_closure",
      "next_action": "Tier 2.5 → 3.0 confirmed. T102 director dispatches implementer_text for Document stage: (a) write memory entry `tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md` capturing the 3-falsifier corroboration + critic's independent-route algebra summary; (b) append T101 [Established] entry to conclusions/<inv>.md; (c) state.json patch `current_stage: closed`, `tier_current: 3.0`, `closing_note` populated; (d) update MEMORY.md index entry. This is the 6th project Tier-3 closure. Investigation arc T98→T99→T100→T101→T102 complete in 5 turns. T103: AUDIT_DUE patterns.yaml scan (gap=14) OR meta-director-self-audit Hypothesize, whichever has clearer trigger."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000,
    "wall_time_cap_sec": 900,
    "wall_time_julia_only_sec": 120
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_context_director101_sim100_theorist99_judge100_jl_src": 350000,
      "deliverable_A_algebra_independent_route": 350000,
      "deliverable_B_recompute_tmp_script_julia_run": 200000,
      "deliverable_C_audit_C1_C2_C3_grep_channel_kernel": 200000,
      "deliverable_D_critic_report_with_metrics": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document",
    "if_success_tier_becomes": 3.0,
    "if_success_closing_note": "Tier-3 closure 2026-05-19 T101: critic Update CORROBORATE via independent Route I/II algebra + recompute at fresh polar (c_0=2.0, c_1=+0.05) + FM (c_0=0.5, c_1=-0.2) + systematic-error audit. KU2012 §4.2 F=1 polar phonon ω²=ε_k(ε_k + 2c_0 n) and FM phonon ω²=ε_k(ε_k + 2(c_0+c_1)n) reproduced by hf_matrix_generic + channel_kernel. BdG/GP factor-2 ratio confirmed parameter-independent at 2.0 exact within fp precision. 6th project Tier-3 closure. Arc T98→T99→T100→T101→T102 (5 turns).",
    "if_partial_advance_to_stage": "Document",
    "if_partial_tier_becomes": 2.75,
    "if_partial_closing_note": "Tier 2.75 closure 2026-05-19 T101: critic Update CORROBORATE_WITH_ERRATA. Core falsifiers F1/F2/F3 pass independent route + recompute; ≥1 audit caveat documented (see critic report §4). Tier 3 deferred pending caveat resolution.",
    "if_refuted_advance_to_stage": "fix-bug-spawned-side-investigation",
    "if_refuted_tier_becomes": 1.5,
    "if_novel_advance_to_stage": "Hypothesize-with-side-dispatch",
    "if_novel_tier_becomes": 2.5,
    "next_falsifier_to_test_after": "T102-implementer-text-Document-closure-or-fix-bug-spawn"
  },
  "if_succeeds_next_step": "T102 director dispatches implementer_text for Document closure: memory entry `tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md` (~1 page summary of the arc + independent-route key insight), conclusions/<inv>.md [Established] entry append, state.json patch (current_stage: closed, tier_current: 3.0, closing_note populated, last_verdict: TIER_3_CLOSURE_PASS), MEMORY.md index entry (1 line under ## TDHFB Phase 2 section). Budget ~0.8M effective text-only. Arc T98→T99→T100→T101→T102 = 5 turns total, estimated cumulative ~10M. T103: switch to AUDIT_DUE patterns.yaml audit-class-scan (gap=14) OR meta-director-self-audit-2026-05-19 Hypothesize stage (priority 20; auto-spawned at T100). 6th project Tier-3 closure.",
  "if_fails_next_step": "Three failure paths per §6.failure_modes:\n- REFUTED (algebra or recompute fails): spawn fix-bug `tdhfb-generic-f-kernel-regression-T101-{specific-issue}`, dispatch theorist for algebraic diagnosis. Tier 2.5 → 1.5. Arc pauses.\n- CORROBORATE_WITH_ERRATA: dispatch implementer_text Document with caveat memo. Tier 2.5 → 2.75. Investigation closes at 2.75; sub-investigation for the caveat only if it blocks an application.\n- CRITIC_OPERATIONAL_FAIL (scope drift, /tmp/ script bug, etc.): re-dispatch critic with stricter scope; tier preserved at 2.5.",
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read scheduler_101.json THIS turn (JULIA_GPU_OK, critic permitted regardless, VRAM/RAM/foreign-julia probes clean, window 13 days)
- [x] Read state.json relevant sections (turn=101, history[T98]→[T99]→[T100], investigations[tdhfb-phase2...] full entry at lines 3278-3330 with tier_current=2.5 next_stage=Update, schema_version=2.1, newly auto-spawned meta-director-self-audit at line 3331)
- [x] Read judge/turn_100.json ENTIRE (PASS, 18/18 criteria, zero triggered_failure_modes, EXECUTE_PASS verdict matches success_continue_chain branch in T100 §6.failure_modes[3])
- [x] Read sim/turn_100.md ENTIRE (especially §2 script source, §3 adaptations A1-A4, §4 numerical results, §7 critic checklist hint — consumed verbatim for T101 brief Deliverable C structure)
- [x] Read theorist/turn_99.md §0-§2 (convention declarations + Derivation C.0-C.6 — verified the route critic must NOT mirror)
- [x] Read prior director turn (turn_100.md ENTIRE — contract layout, success_criteria shape, failure_modes coverage all consumed as template)
- [x] Read ≥1 memory file: `tier3_pipeline_survey_2026_05_18.md` (this investigation is candidate #5 from that menu — closure completes 5/5 menu trajectory)
- [x] Read conclusions/<inv>.md (stub-only at T99; no load-bearing prior claims to avoid re-deriving)
- [x] Verified scheduler precondition_check is concrete and would actually run (test -f on 8 paths + julia --version + python3 state.json field assertion with tier+next_stage check + PRECONDITIONS_OK echo)
- [x] investigation_id valid in state.investigations (line 3278; tier_current=2.5, next_stage=Update confirmed)
- [x] stage_advancing_to = Update is the §F1 next stage after Execute
- [x] subagent_type = critic matches §F1 role_per_stage[Update] (mandatory; independent context)
- [x] researcher_depth = null (not a researcher dispatch)
- [x] success_criteria machine-evaluable (20 criteria, all using ==/>=/<= or `in` operators against METRICS JSON fields; numerical thresholds match T100's for consistency; route-independence boolean is explicit)
- [x] failure_modes cover REFUTED (kernel regression OR algebra mismatch → fix-bug spawn + tier 1.5), CORROBORATE_WITH_ERRATA (audit caveat → tier 2.75 + Document with memo), CRITIC_OPERATIONAL_FAIL (scope drift → re-dispatch + tier preserved), and SUCCESS (CORROBORATE → tier 3.0 + Document closure path)
- [x] observable_manifest precondition_check tests 8 source files + julia binary + state.json field assertions (concrete + runnable)
- [x] budget fits within scheduler window_seconds_left (1.3M target / 2.0M cap, 600s wall / 1123022s window — trivially fits)
- [x] §A6 research-first citation present: KU2012 §5.1.2 (Route I anchor), SKU2013 §IV.B.1 (Route II anchor), `tier3_pipeline_survey_2026_05_18` (closure-tracking), T93 critic structural precedent, APC cache template n_seen=3
- [x] §A5 D1 articulated: D1 verify Tier 2.5→3.0 (PRIMARY axis); manuscript NOT in scope
- [x] APC contract template cache: `physics::verify-claim::Update` n_seen=3 (T58 klaus-bch CORROBORATE-WITH-ERRATA, T78 lemma1 CORROBORATE, T93 sign-pattern-lemma1 CORROBORATE); cached skeleton (verdict in registered set; independent_derivation_route_chosen; recompute_at_fresh_point; systematic_audit_findings; tier_reached ≥ floor) PRESERVED + patched with tdhfb-specific deltas
- [x] No improvised terminology (BdG, GP, Nambu, phonon, magnon, polar/FM phase, anomalous block, sound velocity, Bose symmetrization, channel decomposition, mean-field — all established terms)
- [x] No anko-attribution in critic brief
- [x] Investigation update field: if_success → Document stage + tier 3.0; if_partial → Document + tier 2.75; if_refuted → fix-bug spawn + tier 1.5; closing_note populated for success/partial paths
- [x] Cost frame: T101 expected 1.3M (T78 critic norm); HARD CAP 2.0M; no DRIFT_COST_INFLATION risk (T100 was 1.04× — within normal)
- [x] AUDIT_DUE at gap=12 acknowledged; deferred to T103 (post-Document closure at T102) per `feedback_cost_overhead_is_the_cost` — closing Tier-3 arc mid-chain is higher leverage than dropping for a periodic scan
- [x] Meta interleave: meta-director-self-audit auto-spawned at T100 (priority 20, Observe stage) noted; deferred to T103 per §B2 "Meta is INTERLEAVED, not parallel" — no actionable Hypothesize-ready trigger; physics arc takes precedence
- [x] subagent rotation: critic gap = 8 turns since T93 (theorist T99/T96, researcher T98/T95, implementer T100/T97). Healthy rotation, critic is overdue.
- [x] active_investigation_id stale-field mismatch in state.json line 2298 (says edh-eu151... but T100 history says tdhfb) flagged in §1 but NOT load-bearing this turn; will be patched on T101 orchestrator commit or T102 if still stale (§A4 mechanical fix per `feedback_fix_the_class_not_the_instance` threshold — sub-3-second recognition)
- [x] Seed.md staleness flagged in §1; scheduler is authoritative per anko 2026-05-16 PROBE_DRIVEN clause; critic is Read-only so the julia-forbidden seed clause is moot
- [x] §A2 no-execution honored: director does not derive the GP-linearization or Heisenberg-equation route; brief points the critic at it
- [x] §A3 flow discipline: Update stage explicitly in §F1 verify-claim template; not a skipped or freeform stage
- [x] `feedback_manuscript_is_not_the_essence` honored: no manuscript polish; no docstring polish; D1 verification depth is the axis
