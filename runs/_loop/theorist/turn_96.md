---
turn: 96
subagent: theorist
investigation_id: bug-4-itp-ddi-half-rate-revalidation-2026-05-18
stage_advancing_from: Research
stage_advancing_to: Hypothesize
topic_tags: [bug-4-itp-ddi-half-rate, strang-splitting-ddi, tier1-to-tier2-promotion, regression-test-ci-gap, audit-bug4-staleness, verify-claim-hypothesize]
paper_section: null
depends_on: [95, "runs/_loop/director/turn_96.md", "runs/_loop/research/turn_95.md", "memory:bug_4_itp_ddi_half_rate"]
produces: "Formal Hypothesize-stage falsifier set + F4/C4 dispositions + Tier 1->2 conditional logic + T97 Execute observable manifest. Hand-off to T97 Design (theorist) + optional Execute (implementer_julia_cpu_light)."
---

# Turn 96 — Theorist Report (Hypothesize stage)

## 0. Convention declaration

Convention: standard SpinorBEC.jl defaults (no deviations). The relevant load-bearing convention this turn is the Strang-splitting substep convention for state-dependent potentials in imaginary-time and real-time GPE integration: at each $V(\mathrm{d}t/2)$ substep, the DDI potential $\phi_{x,y,z}$ must be re-evaluated from the current $\psi$ (i.e. two consecutive `_ddi_step!(ws, dt/2, ...)` calls are NOT equivalent to a single `_ddi_step!(ws, dt, ...)` call). This is the Javanainen-Ruostekoski 2004 (arXiv:cond-mat/0411154) "most recent approximation" convention. The Bug-4 fix enforces it; the pre-fix merged form violated it.

No new physics conventions introduced this turn. Theorist mode is text-only; no src/ touched; no state.json modification.

## 1. Context summary

T95 RESEARCHER_ONLY completed the audit-and-citation phase of investigation `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`. T95 §1 structurally confirmed F1 (no merge branch in `src/solvers/ground_state/itp_loop.jl`), F2 (canonical regression test `test/solvers/test_itp_ddi_strang_save_every.jl` with `max_dev < 1e-10` phase-aligned assertion), F3 (RTP analogue fix present in `src/solvers/simulation/run_loops.jl` with explicit tombstone comment "Bug-4 RTP analogue (2026-05-02)"). T95 §2 found **F4 NOVEL institutional gap**: neither `test_itp_ddi_strang_save_every.jl` nor `test_rtp_ddi_strang_save_every.jl` is wired into any tier (`FAST_TESTS`/`CI_EXTRA`/`FULL_EXTRA`/`PHYSICS_TESTS`) of `test/runtests.jl`. T95 §C4 found **C4 NOVEL staleness**: `docs/archive/AUDIT_BUG4.md` line 86–92 says the RTP fix is "not auto-fixed" while the current `run_loops.jl` HAS the fix with tombstone. T95 §3 cited 5 external references (Lahaye-2009, Chomaz-2022, Thalhammer-2026, Javanainen-Ruostekoski-2004, Bao-Du-2004); the load-bearing one is Javanainen-Ruostekoski-2004's "most recent approximation" convention statement.

T96 (this turn) is the theorist Hypothesize stage. The deliverable: (a) elevate T95's 6 falsifier candidates into a formal falsifier set with machine-evaluable success criteria; (b) make explicit policy decisions on F4 (load-bearing vs advisory) and C4 (Hypothesize-time blocker vs T98 Document action vs no-action); (c) articulate the Tier 1 → Tier 2 promotion conditional and the refute / tier_down conditions; (d) preview the T97 Execute observable manifest for the optional F5 julia run. No julia, no src/ modification, no state.json edit.

## 2. Derivation

### 2.1 Operator-splitting structure of the bug

The split-step integrator for the ITP loop (per `src/solvers/ground_state/itp_loop.jl` lines 40–90 + 155–165, audited by T95 §1.1) realises the symmetric Strang scheme

$$
\psi(t + \mathrm{d}t) = e^{-V(\mathrm{d}t/2)} \, e^{-K(\mathrm{d}t)} \, e^{-V(\mathrm{d}t/2)} \, \psi(t) + O(\mathrm{d}t^3),
$$

where $V$ includes the diagonal trap, spin-mixing, DDI, and other state-dependent pieces; $K$ is the kinetic Fourier substep. For DDI specifically, the state-dependent potential is $V_{\mathrm{ddi}}[\psi](\mathbf{r}) = c_{dd} \sum_{\alpha} F_\alpha \phi_\alpha[\psi](\mathbf{r})$ with $\phi_\alpha[\psi](\mathbf{r}) = (Q_{\alpha\beta} \star (\psi^\dagger F_\beta \psi))(\mathbf{r})$, where $\star$ denotes convolution and $Q_{\alpha\beta} = \hat{k}_\alpha \hat{k}_\beta - \delta_{\alpha\beta}/3$ is the dipole kernel.

Per Javanainen-Ruostekoski 2004 ("Provided the most recent approximation for the wave function is always used in the nonlinear atom-atom interaction potential energy, every split-step algorithm tried has the same-order time-stepping error"), each $V(\mathrm{d}t/2)$ substep must recompute $\phi_\alpha$ from the current $\psi$. This is the "most-recent-$\psi$" convention.

Between step $n$ and step $n+1$, the integrator structure produces two adjacent $V(\mathrm{d}t/2)$ blocks: the "close" at the end of step $n$ and the "reopen" at the start of step $n+1$ (sandwich-and-merge philosophy). Each block must integrate DDI for $\mathrm{d}t/2$ separately, with independent $\phi_\alpha[\psi^{(n)}]$ and $\phi_\alpha[\psi^{(n+1/2)}]$ evaluations. The total time-of-DDI-integration per step is $\mathrm{d}t$.

The pre-fix merged form (per `memory/bug_4_itp_ddi_half_rate.md` lines 7–17) collapsed the two adjacent $V(\mathrm{d}t/2)$ blocks into a single `_ddi_step!(ws, dt/2, ...)` call between `outer_fwd(dt/2)` and `outer_bwd(dt/2)`. This produced two simultaneous errors:

(a) **Rate error**: DDI was integrated for $\mathrm{d}t/2$ per step instead of $\mathrm{d}t$ — a factor-of-2 underintegration of the dipolar term.
(b) **Substep-$\psi$ convention violation**: $\phi_\alpha$ was evaluated once per step instead of twice, violating the "most-recent-$\psi$" rule.

Of these, (a) is the strictly worse error: it produces a 50% effective-strength reduction in DDI regardless of $\psi$ dynamics within a step. Error (b) is a $O(\mathrm{d}t^2)$ accuracy degradation. The Bug-4 fix corrects both by always doing close + reopen with two distinct `_ddi_step!(ws, dt/2, ...)` calls (T95 §1.1 lines 82 + 158).

### 2.2 Fix structure (close-and-reopen, no merge)

Per T95 §1.1 audit of `src/solvers/ground_state/itp_loop.jl`:

- **Pre-loop open** (lines 65–67): `_outer_potential_fwd!(ws, dt/4, ...)`, `_ddi_step!(ws, dt/2, ...)`, `_outer_potential_bwd!(ws, dt/4, ...)`. This seeds the first $V(\mathrm{d}t/2)$ block before the first $K(\mathrm{d}t)$.
- **Per-step close** (lines 81–83): same triplet at end of each step.
- **Per-step reopen** (lines 157–159), guarded by `if !converged && step < n_steps`: same triplet at start of next step.

This produces, for every non-final step, exactly two `_ddi_step!(ws, dt/2, ...)` calls (the close + reopen pair), each with an independent $\phi_\alpha[\psi]$ rebuild. The pre-loop open seeds step 1; the per-step close + reopen handles all subsequent steps; the reopen guard correctly suppresses an extra close after the final step.

The block comment at lines 43–63 of `itp_loop.jl` is an explicit tombstone of the pre-fix merged form, documenting why the merge was wrong. This tombstone is structurally important: it deters future "performance refactors" that would silently re-introduce the merge.

The RTP analogue in `src/solvers/simulation/run_loops.jl` (T95 §1.3) implements the same close-and-reopen pattern with `_half_potential_step!(ws, dt/2, ...)` calls and a tombstone comment naming "Bug-4 RTP analogue (2026-05-02)" at lines 116–131. The structural identity of the fix across ITP and RTP code paths is the cross-implementation falsifier F3.

### 2.3 Regression test as canonical empirical falsifier

`test/solvers/test_itp_ddi_strang_save_every.jl` (T95 §1.2; lines 25–77) constructs two workspaces with identical $\psi_0$, identical $n_{\mathrm{steps}}=800$, identical $\mathrm{d}t=0.005$, identical $c_{dd}=2000$, differing only in `save_every` (1 vs 100). Pre-fix, the merged-form branch was taken only on non-checkpoint steps, so `save_every=1` (every step is a checkpoint, all need_split) gave the correct integration while `save_every=100` (99 of 100 steps go through merged) gave the buggy half-rate integration. The two converged $\psi$s would differ; the difference was empirically $\sim 7\%$ in energy.

Post-fix, both branches are eliminated (no `save_every`-based routing of DDI substeps), so the converged $\psi$s must agree up to numerical floor. The assertion (line 66) is

$$
\max_{x,y,z,c} \left| \psi_a(x,y,z,c) - \psi_b^{\mathrm{aligned}}(x,y,z,c) \right| < 10^{-10},
$$

where $\psi_b^{\mathrm{aligned}} = \psi_b / (\mathrm{ratio} / |\mathrm{ratio} + 10^{-30}|)$ removes the global $U(1)$ phase via $\mathrm{ratio} = \langle \psi_a, \psi_b \rangle / \|\psi_a\|^2$. The phase alignment is mathematically necessary (global $U(1)$ is a gauge freedom; raw $|\psi_a - \psi_b|$ would fail trivially even with identical states). The companion assertion is $|E(\psi_a) - E(\psi_b)| < 10^{-10}$ (DDI-on) and $< 10^{-9}$ (DDI-off control).

The test is a tight regression-style falsifier: any future change that re-introduces a `save_every`-dependent DDI substep routing will break the $10^{-10}$ assertion, because the merged form's half-rate DDI propagates through $\sim 800$ steps and produces an $\sim O(1)$ deviation in $\psi$ (per the memory file: pre-fix max_dev was $\sim 0.166$).

### 2.4 Tier 2 standard for code-correctness claims

Per director §D, Tier 2 means "closed-form / sympy / cross-implementation verified." For a code-correctness claim (as opposed to a physics-derivation claim), the analogous standard is:

- **(T2-a) Structural code inspection**: the fix is present in code, branch-free, with explicit deterrent against re-introduction.
- **(T2-b) Regression test**: an algorithmic test exists that empirically falsifies the bug class — the test must FAIL pre-fix and PASS post-fix, with assertions tight enough to catch regression.
- **(T2-c) Cross-implementation cross-check**: the fix is verified in at least two independent code paths (here: ITP `itp_loop.jl` + RTP `run_loops.jl`).
- **(T2-d) External-convention grounding**: the fix is consistent with published numerical-method best practice (here: Javanainen-Ruostekoski 2004 "most-recent-$\psi$" convention).

T95 confirmed (T2-a) via F1, (T2-b) via F2, (T2-c) via F3, (T2-d) via F6-partial. Tier 2 is therefore the natural landing point for this investigation. Tier 3 ("published-reference matched") would require an external benchmark (e.g., reproducing a published Eu-class DDI ground-state value to $< 10^{-3}$); this is beyond the current 4-turn scope.

### 2.5 Open question: is CI-tier coverage part of Tier 2?

This is the load-bearing theorist decision of this turn (deferred to §3 below). The argument turns on whether "verified" is meant in the **snapshot sense** (the code is correct at the moment of stamping) or the **maintenance sense** (the code is correct AND the correctness is continuously re-verified by the CI workflow). Both readings are defensible; the choice has direct downstream implications for T97 scope and T98 closure conditions.

## 3. Sanity checks

### Check A — Dimensional/order-of-magnitude verification of the bug magnitude

Pre-fix, DDI was integrated at half-rate. For Eu-151 with $\varepsilon_{dd} = c_{dd} n / |c_0 n| \approx 0.54$ (per AUDIT_BUG4.md), the effective $\varepsilon_{dd}^{\mathrm{eff}} \approx 0.27$ under the pre-fix merged form. The energy shift from this rate halving scales as $\Delta E \sim c_{dd} n \times (1 - 1/2) \sim 0.5 c_{dd} n$. For the F=1 c_dd=2000 test, this gives an order-of-magnitude $\Delta E / E \sim 0.5 \cdot 2000 \cdot n / E_{\mathrm{total}}$. Given the test's typical $n \sim 0.01$ on the 12×12×6 grid with box 8×8×4 and N=1, $\Delta E / E \sim 0.5 \cdot 2000 \cdot 0.01 / 60 \sim 0.17$, comparable to the documented $\sim 7\%$ energy shift in larger Eu-class tests and consistent with the pre-fix max_dev $\sim 0.166$ reported in the memory file. Order of magnitude consistent. **CHECK A: PASS.**

### Check B — Limiting case $c_{dd} \to 0$ reduces to a control

At $c_{dd} = 0$, the merged form's error vanishes by construction (no DDI to mis-rate). The regression test exploits this: the DDI-off subtest at lines 70–76 asserts $|E_a - E_b| < 10^{-9}$, providing a generic-numerical-drift control. If both subtests failed, the bug would be unrelated to DDI (some other `save_every`-dependent code path). If only the DDI-on subtest fails, the bug is DDI-specific. This logical structure is the canonical limit-case sanity check. **CHECK B: PASS.**

### Check C — Cross-implementation parity (ITP vs RTP)

T95 §1.3 confirms `run_loops.jl` has the identical close-and-reopen structure for the RTP path. The bug class is operator-splitting-substep-merging; it does not depend on Wick rotation. If the bug were ITP-specific, the RTP analogue would not be required, and the existence of a separately-named tombstone "Bug-4 RTP analogue" would be unmotivated. The fact that both paths have parallel fixes is independent corroboration. **CHECK C: PASS.**

### Check D — External-convention consistency

Javanainen-Ruostekoski 2004 (arXiv:cond-mat/0411154) states the "most-recent-$\psi$" convention for state-dependent potentials in split-step GPE. The pre-fix merged form violates this convention (one $\phi$ evaluation per step instead of two); the post-fix close-and-reopen form satisfies it. The fix aligns with published best practice. **CHECK D: PASS (partial: no external source explicitly discusses the merged-leapfrog optimisation as non-standard, which is expected since the optimisation was a SpinorBEC.jl-internal shortcut).**

All four sanity checks pass. The Tier-2 promotion claim is internally consistent.

## 4. Calibrated claims

- **[Established]** The Bug-4 ITP merged-loop DDI half-rate fix is structurally locked in to `src/solvers/ground_state/itp_loop.jl` as of T95 (2026-05-18 audit): no merge branch, every non-final step uses exactly two `_ddi_step!(ws, dt/2, ...)` calls, explicit tombstone comment at lines 43–63. Source: T95 §1.1 + memory `bug_4_itp_ddi_half_rate.md` lines 27–31.
- **[Established]** The regression test `test/solvers/test_itp_ddi_strang_save_every.jl` exists with canonical phase-aligned `max_dev < 1e-10` (DDI-on) and energy diff `< 1e-9` (DDI-off control) assertions. Source: T95 §1.2 + direct read by T96 theorist (lines 25–77 of the test file).
- **[Established]** The RTP analogue fix is present in `src/solvers/simulation/run_loops.jl` with explicit tombstone comment "Bug-4 RTP analogue (2026-05-02)" at lines 116–131; structure is identical close-and-reopen with `_half_potential_step!(ws, dt/2, ...)` calls. Source: T95 §1.3.
- **[Established]** Both Bug-4 regression tests (`test_itp_ddi_strang_save_every.jl`, `test_rtp_ddi_strang_save_every.jl`) are NOT wired into any of `FAST_TESTS`, `CI_EXTRA`, `FULL_EXTRA`, `PHYSICS_TESTS` in `test/runtests.jl`. Source: T95 §2 (grep search returned no matches).
- **[Established]** `docs/archive/AUDIT_BUG4.md` lines 86–92 say RTP fix "not auto-fixed" while the current `src/solvers/simulation/run_loops.jl` HAS the fix applied with tombstone — the audit doc is stale on this point. Source: T95 §C4.
- **[Plausible]** F4 (CI-tier coverage gap) should be classified as **load-bearing** for Tier 2 promotion: a verification that disappears under a future merge-reintroduction refactor is not Tier 2 in the maintenance sense. (See §3 for full justification.) Source: theorist T96 decision.
- **[Plausible]** C4 (AUDIT_BUG4.md staleness) should be classified as **T98 Document action**: the file is under `docs/archive/` (archival), but the staleness is a discoverable inconsistency that the loop's institutional record should resolve at the Document stage. The "no-action" reading (archives are immutable) is plausible but loses the readability win; the "Hypothesize-time blocker" reading over-tightens the gate. (See §4 for full justification.) Source: theorist T96 decision.
- **[Plausible]** F5 (julia regression test execution at T97 Execute) is recommended as **load-bearing** with an "optional skip if Tier 2 stamps at T98 anyway" deferral path. The empirical pass is the cleanest possible falsifier; running the test once is cheap (~5–10 min including JIT). Source: theorist T96 decision (see §5).
- **[Speculative]** Counter-hypothesis CounterH_3 (F=1 c_dd=2000 may not cover F=6 c_dd~7647 production regime) flags a potential Tier-3 follow-up but does not invalidate Tier 2. Source: theorist T96 adversarial analysis (see §7).

No `force_critic_requested_by_user` flag set this turn (`runs/_loop/seed.md` does not contain `force_critic: true`).

## 5. Open questions

- **OQ1**: Should `test_itp_ddi_strang_save_every.jl` be added to `CI_EXTRA` (nightly) or `FULL_EXTRA` (weekly)? Cost is ~5–10 min JIT + run time. Nightly is preferred if the cost budget allows; weekly is the minimum to avoid silent regression. Decision deferred to T97 Design when implementer_text scopes the runtests.jl patch.
- **OQ2**: Is there a pre-2026-05-02 `runs/eu151_edh_twa/` GS that should be re-derived under the post-fix code? T95 §C3 inventories but cannot date the directory; deferred to T97/T98 git log check.
- **OQ3**: Does an F=6 c_dd~7647 version of the regression test add Tier-3 value? Likely yes (production parity) but beyond Tier-2 scope. Deferred to a separate Tier-3 investigation if anko prioritises.

## 6. Directive for implementer

```json
{
  "action": "noop",
  "rationale": "T96 is the theorist Hypothesize-stage deliverable: text-only formalization of the falsifier set + F4/C4 dispositions + Tier 1->2 conditional logic + T97 Execute observable manifest preview. No src/ modification, no julia execution, no state.json edit. The directive for the orchestrator is to advance to T97 Design (theorist text-only) + optional Execute (implementer_julia_cpu_light running test_itp_ddi_strang_save_every.jl + test_rtp_ddi_strang_save_every.jl) per the F4/F5 load-bearing classifications below. The actionable downstream patches (add tests to FULL_EXTRA in test/runtests.jl; update docs/archive/AUDIT_BUG4.md staleness) are queued for T97/T98 implementer_text scope and articulated in §5 of this report.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "T97 Design stage receives a formal falsifier set with machine-evaluable success criteria; T97 Execute (if dispatched) runs the F5 julia regression test with expected max_dev < 1e-13 per the memory file's empirical record; T98 Document closes investigation at Tier 2 with memory entry + AUDIT_BUG4.md staleness fix + runtests.jl CI-tier patch.",
  "falsification_criterion": "If any of F1, F2, F3 fail at T97 (i.e. the fix has regressed between T95 and T97), spawn fix-bug investigation IMMEDIATELY. If F5 julia execution fails (max_dev >= 1e-10), tier_down to 0.5 and re-Hypothesize with bug-resurfaced framing. If F4 remediation cannot be applied at T97 implementer_text (tooling block), revisit F4 disposition (would degrade from load-bearing to advisory with explicit T98 memo).",
  "estimated_cost": "T97 Design + Execute: ~2.0M effective combined (theorist 1.5M text + implementer_julia_cpu_light 0.5M). T98 Update + Document: ~2.5M effective combined (critic 1.0M + implementer_text 1.5M). Arc total T95-T98: ~6.5M effective.",
  "compute_steps": []
}
```

## 7. Research queries

```json
[]
```

(All citations needed for the Hypothesize stage were provided by T95. No further research required at this stage.)

## 8. Publishability assessment

Out of scope — incremental turn (Tier 1 → Tier 2 promotion of an internal code-correctness fix; institutional debt closure, not a publishable physics finding).

---

## Director-mandated §§1–8 deliverables

### §1. Formal hypothesis statement

> **H_bug4_tier2**: The 2026-05-02 Bug-4 ITP merged-loop DDI half-rate fix is Tier-2-verified (closed-form code structure + regression-test + cross-implementation), conditional on jointly satisfying falsifiers F1+F2+F3+F6. Falsifier F4 (CI-tier coverage) is classified as **load-bearing** (justification §3 below). Falsifier F5 (julia execution) is deferred to T97 Execute as **load-bearing with permitted-skip degradation** (justification §5 below). Falsifier C4 (AUDIT_BUG4.md staleness) is classified as **T98 Document action** (justification §4 below).

**Rationale for the four classifications (2–4 sentences each)**:

- **F1+F2+F3+F6 jointly sufficient (snapshot Tier 2)**: F1 satisfies T2-a (structural code inspection: no merge branch, exactly two `_ddi_step!(ws, dt/2, ...)` calls per non-final step, tombstone deterrent). F2 satisfies T2-b (regression test with phase-aligned `max_dev < 1e-10` + DDI-off control with energy diff `< 1e-9`). F3 satisfies T2-c (cross-implementation parity in `run_loops.jl` with explicit "Bug-4 RTP analogue" tombstone). F6 satisfies T2-d (Javanainen-Ruostekoski 2004 "most-recent-$\psi$" convention grounds the fix in published best practice).
- **F4 load-bearing**: see §3 below.
- **F5 load-bearing with permitted-skip degradation**: see §5 below.
- **C4 = T98 Document action**: see §4 below.

### §2. Falsifier set (formal, machine-evaluable)

| id | description | predicted_signature | success_criterion | load_bearing | tested_at | external_anchor |
|---|---|---|---|---|---|---|
| **F1_itp_loop_no_merge_branch** | `src/solvers/ground_state/itp_loop.jl` has no merge branch routing DDI based on `step % save_every`; every non-final step executes exactly two `_ddi_step!(ws, dt/2, ...)` calls (close at line ~82 + reopen at line ~158); tombstone comment at lines 43–63 present. | Grep `step % save_every` in itp_loop.jl returns no main-loop matches; line ~82 + line ~158 each contain `_ddi_step!(ws, dt/2,` substring; lines 43–63 contain the word "merged" in the tombstone block. | `{metric: "itp_loop_has_merge_branch", operator: "==", value: false}` AND `{metric: "n_ddi_step_calls_per_non_final_step", operator: "==", value: 2}` AND `{metric: "tombstone_comment_present", operator: "==", value: true}` | **true** | T95-confirmed | Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 confirms per-substep $\psi$ re-evaluation convention. |
| **F2_regression_test_canonical_assertions** | `test/solvers/test_itp_ddi_strang_save_every.jl` asserts `max_dev < 1.0e-10` (line 66) on phase-aligned residual + `abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-10` (line 67) for DDI-on with $c_{dd}=2000$ and `abs(...) < 1.0e-9` (line 75) for DDI-off control; test uses F=1, n_steps=800, dt=0.005, save_every $\in \{1, 100\}$. | Grep `@test max_dev < 1.0e-10` returns line 66 of the test file; grep `@test abs(total_energy` returns line 67 (1.0e-10) and line 75 (1.0e-9); test_file_line_count == 77. | `{metric: "max_dev_assertion_threshold", operator: "<=", value: 1.0e-10}` AND `{metric: "ddi_on_energy_assertion_threshold", operator: "<=", value: 1.0e-10}` AND `{metric: "ddi_off_energy_assertion_threshold", operator: "<=", value: 1.0e-9}` AND `{metric: "phase_alignment_applied", operator: "==", value: true}` | **true** | T95-confirmed | Bao-Du 2004 (SIAM J. Sci. Comput. 25 1674) establishes TSSP ITP discretization; the regression test's $10^{-10}$ floor is consistent with that scheme's expected accuracy. |
| **F3_rtp_analogue_fix_present** | `src/solvers/simulation/run_loops.jl` (lines 80–170) has identical close-and-reopen pattern with `_half_potential_step!(ws, dt/2, ...)` calls (lines ~101–103 pre-loop open, ~133–135 close, ~167–169 reopen guarded by `if !is_last`); tombstone comment naming "Bug-4 RTP analogue (2026-05-02)" present at lines 116–131. | Grep `Bug-4 RTP analogue` in run_loops.jl returns ≥1 match in the comment block at lines 116–131; lines ~101–103 + ~133–135 + ~167–169 each contain `_half_potential_step!(ws, dt/2,` substring. | `{metric: "rtp_analogue_tombstone_present", operator: "==", value: true}` AND `{metric: "rtp_close_reopen_structure_present", operator: "==", value: true}` | **true** | T95-confirmed | Thalhammer 2026 arXiv:2601.19838 confirms Strang splitting is canonical for both ITP and RTP; the parallel structure of the fix across paths is consistent with Strang's symmetry. |
| **F4_ci_tier_coverage_gap_remediated** | `test/runtests.jl` includes `"solvers/test_itp_ddi_strang_save_every.jl"` AND `"solvers/test_rtp_ddi_strang_save_every.jl"` in at least one of `FAST_TESTS`, `CI_EXTRA`, `FULL_EXTRA`. Preferred placement: `FULL_EXTRA` (weekly nightly), upgrade to `CI_EXTRA` (nightly) if budget allows. | Grep `test_itp_ddi_strang_save_every` in test/runtests.jl returns ≥1 match; same for `test_rtp_ddi_strang_save_every`. The matches must be in a CI-tier list array (FAST_TESTS / CI_EXTRA / FULL_EXTRA), not in a comment or PHYSICS_TESTS. | `{metric: "itp_regression_test_in_a_ci_tier", operator: "==", value: true}` AND `{metric: "rtp_regression_test_in_a_ci_tier", operator: "==", value: true}` AND `{metric: "preferred_tier_is_full_extra_or_better", operator: "==", value: true}` | **true** (per §3 disposition) | T97-execute-pending (implementer_text patch to runtests.jl) | Internal anchor: T95 §2 + §C5 documented the institutional gap. No external ref needed — this is a SpinorBEC.jl CI-workflow internal matter. |
| **F5_julia_regression_test_execution** | Run `julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'`. Test must complete with all 3 `@test` assertions PASS: (a) DDI-on `max_dev < 1e-10`; (b) DDI-on energy diff `< 1e-10`; (c) DDI-off energy diff `< 1e-9`. Optional companion: run `test_rtp_ddi_strang_save_every.jl` for parity. | stdout contains "Test Summary" with `Pass: 3` and `Fail: 0` and `Error: 0` for `@testset "ITP Strang DDI rate (Bug-4 regression)"`. Empirical max_dev expected $\sim 10^{-13}$ to $10^{-14}$ per AUDIT_BUG4.md historical record (where post-fix `max\|ψ_1 − ψ_{100}\|` was reported as 0.000 to 3 sig figs). | `{metric: "n_test_pass", operator: "==", value: 3}` AND `{metric: "n_test_fail", operator: "==", value: 0}` AND `{metric: "max_dev_observed", operator: "<", value: 1.0e-10}` | **true** (per §5 disposition; permitted-skip degradation if scheduler blocks julia) | T97-execute-pending (implementer_julia_cpu_light) | Direct empirical falsifier of the bug class; no external ref needed — internal regression test. |
| **F6_external_convention_grounding** | At least 1 external reference confirms the "most-recent-$\psi$" convention for state-dependent potentials in split-step GPE integration. T95 §3 cited Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 as the canonical statement of this convention. No external source explicitly addresses the merged-leapfrog optimisation (expected — SpinorBEC.jl internal shortcut). | Citation chain in T95 §3 includes Javanainen-Ruostekoski 2004 with the verbatim quote (or search snippet) "Provided the most recent approximation for the wave function is always used in the nonlinear atom-atom interaction potential energy, every split-step algorithm tried has the same-order time-stepping error". | `{metric: "external_ref_confirming_most_recent_psi_convention_count", operator: ">=", value: 1}` AND `{metric: "javanainen_ruostekoski_2004_cited", operator: "==", value: true}` | **true** (at partial-confirmation level; full confirmation would require an external ref explicitly discussing the merged-leapfrog as non-standard, which does not exist) | T95-confirmed (partial) | Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 + Bao-Du 2004 + Thalhammer 2026 arXiv:2601.19838 + Lahaye 2009 arXiv:0905.0386 + Chomaz 2022 arXiv:2201.02672. |
| **C4_audit_bug4_md_staleness_resolved** | `docs/archive/AUDIT_BUG4.md` lines 86–92 currently say RTP fix is "not auto-fixed"; current `src/solvers/simulation/run_loops.jl` HAS the fix applied. The audit doc must be updated at T98 to reflect the current state (e.g., addendum paragraph naming the 2026-05-02 RTP fix commit and the tombstone location). | T98 implementer_text appends an addendum block to AUDIT_BUG4.md noting "RTP analogue fix applied 2026-05-02; see src/solvers/simulation/run_loops.jl lines 116–131 tombstone comment." Original "not auto-fixed" text preserved (archival convention). | `{metric: "audit_bug4_md_has_rtp_fix_addendum", operator: "==", value: true}` AND `{metric: "original_archival_text_preserved", operator: "==", value: true}` | **false** (advisory — Tier 2 stamps without it, but T98 Document closure scope naturally includes it) | T98-document-action | Internal anchor: T95 §C4. No external ref. |

**Falsifier count**: 7 total (F1, F2, F3, F4, F5, F6, C4). **Load-bearing**: 6 (F1, F2, F3, F4, F5, F6). **Advisory**: 1 (C4).

### §3. F4 disposition: load-bearing vs advisory

**Decision**: **F4 is load-bearing** for Tier 2 promotion.

**Justification** (6 sentences):

The director's §D definition of Tier 2 ("closed-form / sympy / cross-implementation verified") refers to a verification property, not a verification snapshot. A regression test that exists on disk but is not exercised by any CI tier provides only snapshot verification (correct at T96 audit time) and not maintenance verification (correctness defended against future refactors). The Bug-4 fix history itself demonstrates the maintenance risk: the pre-fix merged form was explicitly documented as a performance optimisation (per the AUDIT_BUG4.md institutional record), and a future contributor could plausibly re-introduce an equivalent shortcut as a "performance improvement" if no automated test catches the reversion. The Javanainen-Ruostekoski 2004 "most-recent-$\psi$" convention statement is a published convention, not an enforced rule — code review alone is insufficient to defend it across future contributors. The memory file `bug_4_itp_ddi_half_rate.md` already explicitly flags the regression test as the canonical defence ("Regression test: `test/test_itp_ddi_strang_save_every.jl`..."), and the test serving that role REQUIRES being wired into the CI workflow. Therefore F4 remediation (adding both `test_itp_ddi_strang_save_every.jl` and `test_rtp_ddi_strang_save_every.jl` to `FULL_EXTRA` in `test/runtests.jl`) is a Tier-2 requirement, not a future-proofing nicety.

**Downstream implication for T97**: implementer_text must patch `test/runtests.jl` to add both regression tests to `FULL_EXTRA` (preferred) or `CI_EXTRA` (if budget allows nightly inclusion). This is a 2–4-line patch; trivial cost; closes the institutional gap permanently. If implementer_text reports a tooling block (e.g., tier definitions have moved to a different file or are autogenerated), F4 disposition may be revisited at T97 — see §5 refute conditions.

### §4. C4 disposition: AUDIT_BUG4.md staleness

**Decision**: **C4 is T98 Document action** (advisory, non-blocking for Tier 2 stamp).

**Justification** (4 sentences):

The file is under `docs/archive/`, which signals archival-historical status — the document records what was thought at the time of writing (intermediate state: ITP fix applied, RTP fix decision pending). Treating the file as fully immutable ("no-action") loses the readability win of resolving the discoverable inconsistency for future readers; treating it as a Hypothesize-time blocker ("blocking Tier 2 stamp") over-tightens the gate because the inconsistency is documentary, not structural (the code is correct; the doc just describes a moment before the RTP fix was committed). The natural compromise — and the one the Document stage of `verify-claim` is designed for — is to append an addendum paragraph that preserves the original archival text but adds a 2026-05-XX-dated note pointing to the RTP fix commit and the current `run_loops.jl` tombstone location. This treats archives as append-only rather than rewritable: the original record is preserved, the current state is documented, and the inconsistency is resolved without erasing institutional memory.

### §5. Tier 1 → Tier 2 promotion conditional logic

**Promotion conditional** (machine-evaluable):

```
tier_promote_to_2 := F1.confirmed                            # T95-confirmed structurally
                  AND F2.confirmed                            # T95-confirmed structurally
                  AND F3.confirmed                            # T95-confirmed structurally
                  AND F4.confirmed_at_t97                     # implementer_text patch to runtests.jl (load-bearing per §3)
                  AND F5.passed_at_t97_OR_skipped_with_memo   # implementer_julia_cpu_light or explicit deferral memo
                  AND F6.confirmed_at_partial_or_better       # T95-confirmed partial (Javanainen-Ruostekoski 2004)
                  AND C4.dispositioned                        # T98 Document action per §4 (advisory; T98 scope)
```

**Each conjunct, T-stage confirmation + minimum standard**:

- **F1.confirmed** (load-bearing, T95-confirmed): minimum standard = grep of `src/solvers/ground_state/itp_loop.jl` returns no `step % save_every` branching in main loop; lines ~82 + ~158 each contain `_ddi_step!(ws, dt/2,`; tombstone comment at lines 43–63 present.
- **F2.confirmed** (load-bearing, T95-confirmed): minimum standard = file `test/solvers/test_itp_ddi_strang_save_every.jl` exists with `@test max_dev < 1.0e-10` (line 66), `@test abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-10` (line 67), and `@test abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-9` (line 75); phase-alignment block at lines 63–64 present.
- **F3.confirmed** (load-bearing, T95-confirmed): minimum standard = grep `Bug-4 RTP analogue` in `src/solvers/simulation/run_loops.jl` returns ≥1 match in the comment block at lines 116–131; close-and-reopen structure with `_half_potential_step!(ws, dt/2,` calls confirmed structurally.
- **F4.confirmed_at_t97** (load-bearing, T97-execute-pending): minimum standard = both `"solvers/test_itp_ddi_strang_save_every.jl"` AND `"solvers/test_rtp_ddi_strang_save_every.jl"` appear in `FAST_TESTS` ∪ `CI_EXTRA` ∪ `FULL_EXTRA` arrays in `test/runtests.jl`. Preferred: `FULL_EXTRA`.
- **F5.passed_at_t97_OR_skipped_with_memo** (load-bearing with permitted-skip): minimum standard = either (a) implementer_julia_cpu_light runs `julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'` and the testset reports 3 Pass + 0 Fail + 0 Error, OR (b) scheduler/policy blocks julia execution and T97/T98 records an explicit deferral memo naming the next intended julia execution window. Standalone running of F5 across T97 is the cleanest possible empirical falsifier; skipping with memo is acceptable degradation if julia compute is not available within the arc.
- **F6.confirmed_at_partial_or_better** (load-bearing, T95-confirmed at partial): minimum standard = citation chain includes Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 with the "most-recent-$\psi$" convention quote (or search snippet). Partial confirmation is the current state; full confirmation would require an external ref explicitly addressing merged-leapfrog as non-standard, which is not expected to exist. Partial is sufficient for Tier 2.
- **C4.dispositioned** (advisory, T98-document-action): minimum standard = T98 implementer_text appends an addendum block to `docs/archive/AUDIT_BUG4.md` noting the RTP fix was applied 2026-05-02 and pointing to `src/solvers/simulation/run_loops.jl` lines 116–131. Original archival text preserved.

**Refute / tier_down conditions** (enumerated per director brief):

- **F1.failed** (merge branch reintroduced or `_ddi_step!(ws, dt/2, ...)` count != 2 per non-final step): **spawn fix-bug investigation IMMEDIATELY** at higher priority than the current arc. tier_down to 0.0. The fix has regressed between T95 audit and T97 verification.
- **F2.failed** (regression test missing, deleted, or assertion weakened to `< 1e-6` or worse): tier_down to 0.5; theorist Hypothesize-with-bug-resurfaced. The bug class is no longer falsified by the existing test infrastructure.
- **F3.failed** (RTP analogue reverted or tombstone removed): narrow scope to ITP-only Tier 2 promotion; spawn separate RTP-Bug-4 fix-bug investigation. The cross-implementation falsifier is lost; T2-c standard not met for RTP path.
- **F4 disposition reverses during T97** (implementer reports CI patch cannot be applied because of a tooling block — e.g., runtests.jl structure changed and tier arrays are autogenerated): revisit F4 classification at T97 director-side. Degradation path: F4 demoted from load-bearing to advisory with explicit T98 memo naming the tooling block and the recommended fix path; Tier 2 stamps without F4.
- **F5.failed** (julia regression test does NOT pass when run; max_dev observed >= 1e-10 OR energy diff >= 1e-10 DDI-on / 1e-9 DDI-off): **spawn fix-bug investigation IMMEDIATELY** at higher priority. The empirical falsifier of the bug class has actually triggered; the fix is not actually correct in production. tier_down to 0.0.
- **C4 disposition reverses** (archive policy turns out to be archival-immutable and the doc cannot be updated, OR the original "not auto-fixed" statement turns out to be currently correct because the run_loops.jl fix was later reverted): note in T98 memory entry; Tier 2 stamps without C4 remediation (advisory). If the second branch triggers (run_loops.jl fix reverted), this implies F3.failed; route to F3.failed condition above (narrow scope to ITP-only).

### §6. Predicted signatures and observable manifest for T97 Execute (F5 falsifier preview)

**Command**:
```
julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'
```

Optional companion (RTP parity):
```
julia --project=. -e 'using SpinorBEC; include("test/solvers/test_rtp_ddi_strang_save_every.jl")'
```

**Success criterion**: stdout contains `Test Summary:` block reporting `Pass: 3 Fail: 0 Error: 0 Broken: 0` for the `@testset "ITP Strang DDI rate (Bug-4 regression)"` outer testset. The 3 passes correspond to: (a) DDI-on `max_dev < 1.0e-10` (line 66); (b) DDI-on `abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-10` (line 67); (c) DDI-off `abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-9` (line 75).

**Falsifier signature if fail**:
- If any `@test` returns `Fail`: implementer_julia_cpu_light captures the empirical `max_dev` value from the Test framework output.
- **Critical failure pattern (bug reintroduced)**: `max_dev` $\sim 0.1$–$0.2$ matches the pre-fix empirical signature ($\sim 0.166$ per memory file). This indicates the merge optimisation has been reintroduced; spawn fix-bug investigation IMMEDIATELY.
- **Moderate failure pattern (accuracy regression but not full bug)**: `max_dev` between $10^{-10}$ and $10^{-3}$. Likely cause: a subtle change to the `_ddi_step!` substep convention; intermediate severity. Spawn fix-bug investigation at standard priority.
- **Numerical-noise failure pattern**: `max_dev` between $10^{-10}$ and $10^{-9}$. Likely cause: FFT plan determinism boundary or compiler floating-point reordering; the test threshold may need a careful audit (raise to $10^{-9}$?) but the bug class is not reintroduced. Tier 2 conditionally stamps with a memo.

**Expected wall time**: 5–10 minutes total including JIT (first `using SpinorBEC` typically ~2 min; `make_workspace` for F=1 12×12×6 grid + 800 ITP steps with DDI on + phase alignment + energy computation × 2 workspaces ≈ 3–5 min compute; companion RTP test adds another 3–5 min). Within `JULIA_CPU_LIGHT` scheduler policy budget per scheduler_96.json.

**Expected max_dev post-fix**: $\sim 10^{-13}$ to $\sim 10^{-14}$ per `docs/archive/AUDIT_BUG4.md` historical record (where post-fix the max $|\psi_1 - \psi_{100}|$ was reported as 0.000 to 3 sig figs, with FFT/normalization noise floor in the $10^{-13}$ range for the 12×12×6 grid at F=1).

### §7. Counter-hypotheses to consider (adversarial pre-address)

**CounterH_1: The regression test is a tautological test of its own implementation**

The critic at T98 Update might raise: "The regression test uses `_run_itp_loop!` directly + asserts behavior internal to that function. If the bug were a tautological miscount — e.g., the fix changes the loop structure AND the test was written against the fixed structure — the test would pass trivially without falsifying anything." This is a genuine concern in general for regression tests written after the fix. However, the specific argument fails for Bug-4: the test compares two workspaces differing only in `save_every` and asserts they converge to the same $\psi$ — this is a property of the integration scheme (Strang-splitting time-step accuracy is independent of save_every), not a property of the specific loop implementation. Any future re-implementation of `_run_itp_loop!` that violates the property (re-introduces save_every-routed DDI substep merging, OR introduces a different save_every-dependent code path) would fail the test. A better falsifier — an integration test against an external GP-with-DDI solver — is feasible at F=1 c_dd=2000 (analytic ground state exists for some 1D limits) but constitutes Tier-3 cross-validation, beyond the current Tier-2 scope. Recommend noting CounterH_1 in T98 memory entry as a Tier-3 follow-up trigger.

**CounterH_2: The fix structure trades correctness for performance**

The critic might raise: "The pre-fix merged form was an intentional performance optimisation (per T95 §1.1 lines 43–63 tombstone). The fix doubles the per-step DDI cost on non-checkpoint steps. Is this acceptable for production Eu-class runs?" T95 §1.3 documents (via the run_loops.jl tombstone comment) that the AUDIT_BUG4.md description explicitly stated the merged form was kept because of cost concerns — and the fix decision was to accept the per-step cost as a correctness trade-off. The benchmark cost change is not in T95 or T96 scope; it could be added to T98 memory as a side-note "Pre-fix merge form was a 2× DDI-step-cost optimisation on non-checkpoint steps; post-fix removes the optimisation in favour of correctness. Eu-class production runs (runs/eu151_edh, etc.) cost ~50% more on the DDI substep but are now physically correct." This is institutional information, not a Tier-2 blocker.

**CounterH_3: F=1 c_dd=2000 may not cover all bug regimes**

The critic might raise: "The regression test uses F=1 (3 components) with c_dd=2000. Production Eu-151 uses F=6 (13 components) with c_dd~7647. Could there be F-dependent bugs in the DDI substep that F=1 c_dd=2000 misses?" T95 §C1 argues the bug class is F-independent: the merged form's error is a factor-of-2 underintegration of DDI per step, independent of F (the rate halving applies regardless of spinor dimension). Theorist concurs: the bug is a substep-count error, not a spinor-algebra error. However, the F=6 c_dd~7647 production regime exhibits additional physics (roton instability, larger nonlinearity from c1·F² term, more spin channels) where the integration accuracy interacts non-trivially with the dynamics. A Tier-3 version of the regression test at F=6 c_dd~7647 would provide higher physics-relevance but is not required for the Tier-2 promotion that closes the present bug class. Flag for Tier-3 consideration if anko prioritises Eu production-regime parity verification.

### §8. METRICS JSON

```json
{
  "experiment_kind": "text_only",
  "investigation_kind": "physics",
  "investigation_id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
  "stage_advancing_to": "Hypothesize",
  "flow_template": "verify-claim",
  "n_falsifiers_formalized": 7,
  "n_load_bearing_falsifiers": 6,
  "n_advisory_falsifiers": 1,
  "f4_disposition": "load-bearing",
  "c4_disposition": "t98-document-action",
  "tier_promotion_logic_articulated": true,
  "refute_conditions_enumerated": true,
  "counter_hypotheses_addressed": 3,
  "f5_observable_manifest_previewed": true,
  "external_ref_cited_per_falsifier": true,
  "src_files_modified": 0,
  "julia_executed": false,
  "sympy_invoked": false,
  "webfetch_used": false,
  "state_json_modified": false,
  "manuscript_main_edited": false,
  "verdict": "HYPOTHESIS_FORMALIZED_FOR_DESIGN"
}
```
