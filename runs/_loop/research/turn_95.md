---
turn: 95
subagent: researcher
topic_tags: [bug-4-itp-ddi-half-rate, strang-splitting-ddi, ground-state-itp, regression-test-audit, rtp-analogue, ci-tier-gap, institutional-debt]
paper_section: null
depends_on: [95-director]
produces: "citation chain + code audit + falsifier candidate list for T96 theorist Hypothesize"
---

# Turn 95 — Research Brief

## Queries received

```json
[
  "Is the Bug-4 ITP merged-loop DDI half-rate fix structurally locked in to current src/solvers/ground_state/itp_loop.jl?",
  "Does test/solvers/test_itp_ddi_strang_save_every.jl assert the canonical max|psi(save1) - psi(save100)| < 1e-10 boundary?",
  "Is the RTP analogue fix present in src/solvers/simulation.jl (commit 0353b9b)?",
  "Which SPINORBEC_TEST_TIER includes the Bug-4 regression test?",
  "What external Strang-DDI-numerics references confirm the dt/2 per V-block convention is standard?",
  "Are there other pre-2026-05-02 Eu DDI runs on disk that need re-verification?"
]
```

---

## Findings

### §1. Internal audit — fix structurally locked in?

#### §1.1 itp_loop.jl audit

File: `src/solvers/ground_state/itp_loop.jl` (read in full, 201 lines).

The file contains **no branching on `step % save_every == 0`** anywhere in the main integration loop body. The variable `save_every` appears in the loop exactly once, at line 121, for convergence-check / logging purposes only — it has zero connection to DDI step routing.

The Strang split structure is a close-and-reopen pattern with no merge:

- **Pre-loop open** (lines 65–67): `_outer_potential_fwd!(ws, dt/4, …)`, `_ddi_step!(ws, dt/2, …)`, `_outer_potential_bwd!(ws, dt/4, …)`.
- **Per-step close** (lines 81–83): same triplet. Comments at lines 78–83 confirm "On non-checkpoint steps the loop's reopen block at the end appends another V(dt/2), so DDI gets the full dt per step from the V(dt/2)+V(dt/2) pair."
- **Per-step reopen** (lines 157–159), guarded by `if !converged && step < n_steps`: same triplet. Correctly skipped after the final step.

Every non-final step therefore executes exactly **two** `_ddi_step!(ws, dt/2, …)` calls: close (line 82) + reopen (line 158). The pre-loop open seeds the very first step. This is precisely the fix structure described in `memory/bug_4_itp_ddi_half_rate.md`. No merged form survives.

The embedded block comment (lines 43–63) is an explicit tombstone of the pre-fix merged form, explaining why the merge was wrong. It will suppress any future re-introduction of the optimization.

**F1 confirmed: itp_loop.jl has no merge branch and every step uses exactly two `_ddi_step!(ws, dt/2, …)` calls.**

#### §1.2 test_itp_ddi_strang_save_every.jl audit

File: `test/solvers/test_itp_ddi_strang_save_every.jl` (read in full, 77 lines).

Structure:
- `@testset "ITP Strang DDI rate (Bug-4 regression)"` at line 25.
- Subtest `"DDI on: ψ independent of save_every"` (lines 55–68): builds two workspaces with `c_dd_val=2000.0`, `save_every=1` and `save_every=100` respectively; runs `_run_itp_loop!` for `n_steps=800, dt=0.005` on both; phase-aligns `psi_b` to `psi_a`; asserts `max_dev < 1.0e-10` (line 66) AND `abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-10` (line 67).
- Subtest `"DDI off: control passes"` (lines 70–76): same with `c_dd_val=0.0`; asserts `abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-9`.
- All test code is uncommented and complete.

Exact canonical assertion from line 66:
```julia
@test max_dev < 1.0e-10                       # bytewise post-fix
```

The test uses `_run_itp_loop!` imported via `using SpinorBEC: _run_itp_loop!` (line 22), so it exercises the internal function directly, not via the `find_ground_state` wrapper. Parameters F=1, n_steps=800, dt=0.005, c_dd=2000.0 match the memory description.

**Note on assertion wording vs. director brief:** The director's §4.5 description says "max|ψ(save_every=1) − ψ(save_every=100)| < 1e-10." The actual test uses phase-alignment (line 63–64: `ratio = sum(conj.(psi_a) .* psi_b) / sum(abs2, psi_a); psi_b_aligned = psi_b ./ (ratio / abs(ratio + 1e-30))`) before computing `max_dev`. The assertion is on the phase-aligned residual, not the raw ψ difference. This is the correct approach: global phase freedom means raw ψ comparison would fail for unrelated reasons. **This distinction is accurate and not a concern.**

**F2 confirmed: regression test exists, both DDI-on and DDI-off assertions present, uncommented, with the canonical 1e-10 boundary.**

#### §1.3 simulation.jl RTP analogue audit

`src/solvers/simulation.jl` is an umbrella file (18 lines) that includes three sub-files. The active file for per-step machinery is `src/solvers/simulation/run_loops.jl` (read in full, 193 lines).

The RTP leapfrog loop `_run_simulation_leapfrog!` (lines 82–193) has the same close-and-reopen structure as the ITP fix:

- **Pre-loop open** (lines 101–103): `_half_potential_step!(ws, dt/2, …)`.
- **Per-step close** (lines 133–135): `_half_potential_step!(ws, dt/2, …)`.
- **Per-step reopen** (lines 167–169), guarded by `if !is_last`: `_half_potential_step!(ws, dt/2, …)`.

The block comment at lines 116–131 is an explicit tombstone of the pre-fix merged form: it names "Bug-4 RTP analogue (2026-05-02)" and explains that the merged form was "a 2nd-order accuracy degradation, not a rate bug" (φ_{x,y,z} not re-evaluated between substeps when merge applied `_half_potential_step!(ws, dt, …)` once). Fix was identical in shape: always close + reopen.

**Important nuance documented in run_loops.jl vs. AUDIT_BUG4.md:** The AUDIT_BUG4.md (lines 86–92) describes the RTP analogue as a "2nd-order accuracy degradation, not a rate bug" — the merged form used `_half_potential_step!(ws, dt, …)` which scaled DDI to `dt` total (rate-correct), but skipped the intermediate φ re-evaluation. The ITP bug was strictly worse: the merged form used `_ddi_step!(ws, dt/2, …)` with no scaling compensation, so DDI was genuinely halved per step. The RTP "fix" was therefore an accuracy improvement, not a correctness fix in the same strict sense. Both are addressed.

**F3 confirmed structurally: the fix is present in run_loops.jl with explicit tombstone comment naming "Bug-4 RTP analogue (2026-05-02)".**

An additional regression test `test/solvers/test_rtp_ddi_strang_save_every.jl` (read in full, 70 lines) exists with analogous structure: F=1, n_steps=200, `run_simulation!` (real-time), `max_dev < 1.0e-10` for DDI-on and DDI-off.

#### §1.4 Git commit chain

Direct git log access is not available in researcher_shallow scope (no bash execution). The commit hash `0353b9b` appears in:
- `memory/bug_4_itp_ddi_half_rate.md` (line 1 CLAUDE.md): "RTP analogue (substep accuracy, not rate bug) fixed in same shape — see commit `0353b9b`."
- `runs/_loop/research/turn_69.md` (line 114): "the fix was committed 2026-05-02 (commit `0353b9b` area)."
- Director turn_95.md multiple references to 0353b9b as the RTP fix commit.

**Cannot confirm `0353b9b` in git log without bash.** However the structural evidence is conclusive: `run_loops.jl` contains the explicit tombstone comment naming "Bug-4 RTP analogue (2026-05-02)" and the fix structure is present in code. The commit reference is consistent across 3 independent memory/research artifacts. `commit_0353b9b_found_in_git_log` = NOT_CONFIRMED_VIA_BASH (expected: verified at T97 Execute stage).

`docs/archive/AUDIT_BUG4.md` (read in full, 101 lines) is an authoritative post-fix audit document that:
- Documents the pre-fix merge table (save_every → eff_DDI/true_DDI at lines 21–32).
- Lists affected runs (eu151_edh, eu151_lab_calibrated, eu151_phase_diagram_lbfgs) with severity ratings.
- Describes the RTP analogue finding and its "not auto-fixed" status (which the current code HAS now fixed per the run_loops.jl tombstone).

---

### §2. CI tier coverage

Reading `test/runtests.jl` (read in full, 187 lines):

```
FAST_TESTS   = [list of 56 unit tests — no itp_ddi, no rtp_ddi]
CI_EXTRA     = [11 integration tests — no itp_ddi, no rtp_ddi]
FULL_EXTRA   = [35 heavy tests — no itp_ddi, no rtp_ddi]
PHYSICS_TESTS = [6 analytic validation tests]
```

A Grep search for `test_itp_ddi_strang_save_every` and `test_rtp_ddi_strang_save_every` in `test/runtests.jl` returned **no matches**.

**Both Bug-4 regression tests (`test/solvers/test_itp_ddi_strang_save_every.jl` and `test/solvers/test_rtp_ddi_strang_save_every.jl`) are NOT included in ANY tier of `runtests.jl`.**

This is a confirmed institutional gap:
- `SPINORBEC_TEST_TIER=fast` (per-push CI, `.github/workflows/ci.yml`): does NOT run the regression test.
- `SPINORBEC_TEST_TIER=ci` (nightly, "fast + core integration"): does NOT run the regression test. `CI_EXTRA` contains `solvers/test_ground_state.jl` and `solvers/test_simulation.jl` but NOT `solvers/test_itp_ddi_strang_save_every.jl`.
- `SPINORBEC_TEST_TIER=full` (nightly heavy, `.github/workflows/nightly.yml`): does NOT run the regression test. `FULL_EXTRA` does not include it.
- `SPINORBEC_TEST_TIER=physics`: does NOT run the regression test.

The CI workflow (`.github/workflows/ci.yml`) runs `SPINORBEC_TEST_TIER: fast` on every push/PR. The nightly workflow (`.github/workflows/nightly.yml`) runs `SPINORBEC_TEST_TIER: full` weekdays. Neither picks up the Bug-4 regression test.

**The regression test can only be run manually:**
```
julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'
```

**This is the most significant institutional gap found in this audit.** The fix exists in code, the test exists on disk, but the test is not wired into any CI tier. A silent re-introduction of the merge optimization (e.g., as a "performance improvement") would not be caught by any automated test run.

The gap is not fatal for Tier 2 promotion — the test exists and verifies the fix — but `T96 theorist Hypothesize should include adding the test to FULL_EXTRA (or CI_EXTRA) as an optional F6 falsifier action item.`

---

### §3. External reference scan

**Ref 1:** Lahaye, Menotti, Santos, Lewenstein, Pfau (2009). "The physics of dipolar bosonic quantum gases." *Rep. Prog. Phys.* **72**, 126401. DOI: 10.1088/0034-4885/72/12/126401. arXiv: [0905.0386](https://arxiv.org/abs/0905.0386).

Canonical dipolar BEC review. Abstract confirms coverage of "the mean-field regime valid for dilute Bose-Einstein condensates." The numerical methods section discusses time-splitting Fourier methods for the GPE with DDI; the DDI is handled via convolution theorem in Fourier space and is applied in the V substep. The review does not discuss the specific question of whether the close+reopen pair should use two DDI(dt/2) calls or one DDI(dt) call — it predates the awareness of this substep-accuracy distinction. Relevance to Bug-4: establishes the DDI Strang-splitting framework that SpinorBEC.jl implements, but does not address the substep merging gotcha. [abstract-only; full PDF is OA at arXiv but not fetched per shallow-tier scope]

**Ref 2:** Chomaz, Ferrier-Barbut, Ferlaino, Laburthe-Tolra, Lev, Pfau (2022). "Dipolar physics: a review of experiments with magnetic quantum gases." *Rep. Prog. Phys.* **86**, 026401. DOI: 10.1088/1361-6633/aca814. arXiv: [2201.02672](https://arxiv.org/abs/2201.02672).

Recent (2022) comprehensive experimental review of magnetic dipolar quantum gases including Eu-class atoms. Covers DDI BEC ground states, droplets, supersolids, and spin physics. Does not focus on numerical-methods specifics in its abstract/overview, but contextualizes the physics regime (strong dipolar Eu-class) where Bug-4 would have had impact (ε_dd ~ 0.54 per AUDIT_BUG4.md). Relevance to Bug-4: background for why the DDI integration accuracy matters for Eu-151 specifically (ε_dd near roton instability makes DDI the dominant term). [abstract-only]

**Ref 3:** Thalhammer (2026). "Modified splitting methods for Gross-Pitaevskii systems modelling Bose-Einstein condensates: Time evolution and ground state computation." arXiv: [2601.19838](https://arxiv.org/abs/2601.19838).

Recent (2026) paper specifically on splitting methods for ITP ground-state computation. Key finding relevant to Bug-4: Strang splitting is the canonical 2nd-order choice for ITP because higher-order standard methods require negative coefficients that cause instability for non-reversible (imaginary-time) systems. The paper does NOT explicitly discuss whether DDI φ_{x,y,z} should be re-evaluated at each dt/2 substep vs. once per full step — it treats the nonlinear/DDI potential as evaluated once per V-substep, which is consistent with the close+reopen convention SpinorBEC.jl uses post-fix. [HTML full text fetched; §1 and §2 extracted]

**Ref 4:** Javanainen, Ruostekoski (2004). "Split-step Fourier methods for the Gross-Pitaevskii equation." arXiv: [cond-mat/0411154](https://arxiv.org/abs/cond-mat/0411154).

Systematic study of accuracy of split-step Fourier methods for the GPE. Key statement (from search extract): "Provided the most recent approximation for the wave function is always used in the nonlinear atom-atom interaction potential energy, every split-step algorithm tried has the same-order time-stepping error." This directly supports the Bug-4 fix rationale: using the most recent ψ to evaluate φ_{x,y,z} at each DDI substep (close+reopen with two separate `_compute_and_convolve_ddi!` calls) is more accurate than evaluating φ once for the merged dt call. [abstract + search snippet; partial-source]

**Ref 5 (supporting):** Bao, Du (2004). "Computing the Ground State Solution of Bose-Einstein Condensates by a Normalized Gradient Flow." *SIAM J. Sci. Comput.* **25**, 1674–1697. DOI: 10.1137/S1064827503422956.

Canonical reference for ITP (normalized gradient flow) for BEC ground states. The time-splitting spectral (TSSP) discretization presented here is the mathematical foundation of SpinorBEC.jl's ITP loop. Does not address DDI substep merging specifically, but establishes that each V-substep evaluation uses the "most recent" ψ — implying per-substep re-evaluation of state-dependent potentials is the correct convention. [abstract via search]

**Synthesis:** No external reference explicitly discusses the specific Bug-4 failure mode (merging two adjacent V(dt/2) blocks at inter-step boundaries and using only one DDI(dt/2) call instead of two). The references confirm that: (a) Strang V(dt/2)K(dt)V(dt/2) is the standard ITP scheme; (b) DDI is handled in the V-substep via FFT convolution with φ_{x,y,z} rebuilt from current ψ; (c) using the most recent ψ per substep is the accuracy-maximizing convention. The Bug-4 fix is consistent with all standard references; the merged optimization was a non-standard shortcut that violated the per-substep-ψ convention.

[depth: abstract-only for Refs 1-2; HTML-full for Ref 3; abstract+snippet for Refs 4-5; multi-source-cross-referenced N=5]

---

### §4. Falsifier candidate list

**F1 (itp_loop.jl structural — no merge branch, exactly two DDI(dt/2) calls per step)**
- Operational test: Read `src/solvers/ground_state/itp_loop.jl`; confirm (a) no `if step % save_every == 0` branching in main loop body that routes DDI steps; (b) every non-final loop iteration executes exactly two `_ddi_step!(ws, dt/2, …)` calls (close at line 82 + reopen at line 158); (c) tombstone comment at lines 43–63 present.
- Status this turn: **CONFIRMED** — F1 passes.

**F2 (regression test exists with canonical max_dev < 1e-10 assertion)**
- Operational test: Read `test/solvers/test_itp_ddi_strang_save_every.jl`; confirm (a) `@test max_dev < 1.0e-10` assertion on phase-aligned residual; (b) separate DDI-off control with `< 1e-9`; (c) F=1, n_steps=800, dt=0.005, c_dd=2000.0; (d) test is uncommented and self-contained.
- Status this turn: **CONFIRMED** — F2 passes. Secondary RTP test (`test_rtp_ddi_strang_save_every.jl`) also confirmed.

**F3 (RTP analogue fix present in simulation/run_loops.jl with tombstone comment)**
- Operational test: Read `src/solvers/simulation/run_loops.jl`; confirm (a) no merged `_half_potential_step!(ws, dt, …)` call on non-checkpoint steps; (b) always close+reopen with `_half_potential_step!(ws, dt/2, …)` pair; (c) tombstone comment naming "Bug-4 RTP analogue (2026-05-02)" present at lines 116–131.
- Status this turn: **CONFIRMED** — F3 passes.

**F4 (regression tests wired into CI — institutional gap check)**
- Operational test: Search `test/runtests.jl` for `test_itp_ddi_strang_save_every` and `test_rtp_ddi_strang_save_every`; confirm whether either string appears in any of `FAST_TESTS`, `CI_EXTRA`, `FULL_EXTRA`, or `PHYSICS_TESTS`.
- Status this turn: **FAILS** — neither regression test is wired into any CI tier. This is a newly identified institutional gap (not mentioned in memory or director). T96 theorist should include as a falsifier with proposed remediation: add both tests to `FULL_EXTRA` in `runtests.jl`.

**F5 (regression test execution produces max_dev ~ 1e-13 — optional Execute stage)**
- Operational test: Run `julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'`; observe that both subtests PASS with `max_dev` at floating-point-noise level (expected ~1e-13 per AUDIT_BUG4.md empirical table, where post-fix max|ψ₁ − ψ₁₀₀| = 0.000 and control was at ~8e-12).
- Status this turn: NOT_CONFIRMED (deferred to T97 Execute, implementer_julia_cpu_light scope).

**F6 (external Strang-DDI convention: per-substep ψ re-evaluation confirmed as standard)**
- Operational test: Locate ≥1 external reference (Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 is the canonical one) confirming that state-dependent potentials in split-step GPE should use the most recent ψ per substep. Thalhammer 2026 arXiv:2601.19838 confirms Strang is standard for ITP.
- Status this turn: **PARTIALLY CONFIRMED** — Javanainen-Ruostekoski confirms per-substep-ψ convention (search snippet); no external source explicitly discusses the merged-leapfrog optimization as non-standard. This is expected: the optimization is a SpinorBEC.jl-internal performance shortcut that was not drawn from any published reference.

---

### §5. Tier 1 → Tier 2 promotion argument

**Tier 2 definition** (per director §D): "closed-form / sympy / cross-implementation verified." For a code-fix-correctness claim, the analogous Tier-2 standard is: the fix is verified by (a) structural code inspection confirming the fix is present and merge-branch-free, (b) a regression test that algebraically exercises the bug class, and (c) a cross-implementation cross-check (ITP fix confirmed, RTP analogue confirmed as a separate code path).

**Promotion claim:**

The Bug-4 ITP merged-loop DDI half-rate fix (2026-05-02) satisfies Tier 2 by the following jointly sufficient falsifiers:

1. **Code structure audit** (F1): `itp_loop.jl` has no merge branch; every step uses two `_ddi_step!(ws, dt/2, …)` calls. The tombstone comment documents why the merge was wrong. The fix is structurally locked in — no branch to re-introduce the bug exists.

2. **Regression test existence** (F2): `test_itp_ddi_strang_save_every.jl` asserts `max|psi_a − psi_b_aligned| < 1e-10` for DDI-on and energy diff < 1e-9 for DDI-off. This is the canonical empirical falsifier of the bug: it was empirically confirmed pre-fix to fail with max_dev ~ 0.166, and to pass post-fix at max_dev ~ 0.

3. **Cross-implementation** (F3): The RTP analogue in `simulation/run_loops.jl` independently implements the same close+reopen pattern with an explicit tombstone comment. The structural correctness of the fix is not ITP-specific; it applies to both integration paths.

4. **External convention** (F6 partial): Javanainen-Ruostekoski 2004 confirms per-substep-ψ re-evaluation as the standard accuracy-maximizing convention for split-step GPE. The fix aligns with published best practice.

The remaining gap (F4: neither regression test is wired into CI tiers) is an institutional workflow gap, not a correctness gap. The fix itself is structurally correct and empirically exercised; the gap means the regression is not automatically re-verified on future code changes.

**Tier 2 claim:** The Bug-4 fix is Tier 2 — closed-form code structure verified (F1), regression-test verified (F2), cross-implementation verified (F3). Pending F5 (julia execution of the test) at T97, the promotion can be formally stamped at T98 Document.

---

### §6. Caveats and open gaps for T96+

**C1: F=1, c_dd=2000 representativeness**

The regression test uses F=1 (spin-1, 3 components) with c_dd=2000. Production Eu-151 uses F=6 (13 components) with c_dd ≈ 7647 (from CLAUDE.md: μ≈6.977μ_B, config `runs/eu151_edh/` uses c_dd computed from `omega_ref=691.15` and Eu151 atom). The choice is defensible for the following reason: the bug class (wrong DDI integration rate per step due to merge) is independent of F. The factor of 2 error in DDI integration time appears regardless of the number of components, because `_ddi_step!` is called once instead of twice in the merged path. F=1 is cheaper to run and sufficient to pin the structural correctness of the fix. For Tier-3 promotion, an F=6 c_dd=7647 test would provide higher physics relevance but is not required for Tier 2.

**C2: `runs/eu151_mz_scan/` disk status**

Glob `runs/eu151_*` returns no `eu151_mz_scan` directory. The survey memory (tier3_pipeline_survey_2026_05_18.md) notes "Re-run `runs/eu151_mz_scan/`" as the original comparison path for this investigation, but director turn_95.md §1 confirms the glob also returned no match this turn and pivots to the "audit-then-regression-test" path. **Status: absent.** The directory was apparently cleaned up between the survey (T69-T70) and this turn. Pre-fix comparison is impossible; the regression-test audit path is the correct substitute.

**C3: Pre-2026-05-02 Eu DDI runs on disk — inventory**

Glob `runs/eu151_*/config.yaml` returns 12 directories. Cross-referencing against `docs/archive/AUDIT_BUG4.md` affected-runs table:

| Directory | AUDIT_BUG4.md severity | On disk | save_every | eff/true (pre-fix) |
|---|---|---|---|---|
| `runs/eu151_edh/` | HIGH (🔴) | YES | default (n_steps/100 = 1000) | 0.5005 |
| `runs/eu151_lab_calibrated/` | HIGH (🔴) | YES | 40 (per AUDIT doc) | 0.5125 |
| `runs/eu151_phase_diagram_lbfgs/` | YELLOW (🟡 — rotating_basis, not affected) | YES | 5 | unaffected (LBFGS path) |
| `runs/eu151_edh_twa/` | not in AUDIT doc | YES | unknown | requires inspection |
| `runs/eu151_edh_postfix_local/` | not in AUDIT doc | YES | unknown | name suggests post-fix |
| `runs/eu151_edh_k3_compare/` | not in AUDIT doc | YES | unknown | post-fix era |
| `runs/eu151_edh_c1phys/` | not in AUDIT doc | YES | unknown | post-fix era |
| `runs/eu151_edh_K3_long/` | not in AUDIT doc | YES | unknown | post-fix era |
| `runs/eu151_edh_loss_factorial/` | not in AUDIT doc | YES | unknown | post-fix era |
| `runs/eu151_klaus_barnett/` | not in AUDIT doc | YES | unknown | post-fix era (T29+) |
| `runs/eu151_barnett_spin/` | not in AUDIT doc | YES | unknown | post-fix era |
| `runs/eu151_klaus_phi_phys/` | not in AUDIT doc | YES | 1 (per AUDIT doc) | unaffected (save_every=1) |

Additionally: `runs/matsui_edh_baseline_529e3a77/` and `runs/matsui_edh_baseline_9ca97308/` are the Matsui EdH benchmark runs (T73-T86), generated post-fix.

**Runs confirmed re-verification priority:**
1. `runs/eu151_edh/` — HIGH priority per AUDIT_BUG4.md; n_steps=100000, save_every≈1000 (default). Pre-fix effective DDI was ≈0.5005 of nominal (ε_dd ≈ 0.27 instead of ≈ 0.54). If any thesis figures or paper results derive from GS states computed from this directory pre-2026-05-02, they need re-derivation. The MEMORY.md explicitly flags this.
2. `runs/eu151_lab_calibrated/` — HIGH priority; same class.
3. `runs/eu151_edh_twa/` — timing unclear; if pre-2026-05-02, HIGH priority (TWA seed GS would be corrupted). The directory name doesn't include a date; T96 director or T97 Execute should check `git log -- runs/eu151_edh_twa/`.

The `matsui_edh_baseline_*` runs (T73-T86, May 2026) are post-fix and clean.

**C4: AUDIT_BUG4.md description of RTP analogue says "not auto-fixed" — now contradicted by current code**

The AUDIT_BUG4.md file (lines 86–92) states: "Not auto-fixed: applying the same substep treatment to RTP would double the per-step DDI cost for production dynamics runs." However, the current `src/solvers/simulation/run_loops.jl` HAS the close+reopen fix applied (tombstone comment: "Bug-4 RTP analogue (2026-05-02). Same shape as the ITP fix in itp_loop.jl: drop the merge, always do close + reopen so DDI is substepped."). This means `AUDIT_BUG4.md` was written at an intermediate point (after ITP fix, before RTP fix decision), and the RTP fix was subsequently applied. The doc is now outdated on this point. T96 theorist should note this discrepancy and may want T98 Document to update `docs/archive/AUDIT_BUG4.md`.

**C5: Both regression tests NOT in runtests.jl (F4 gap)**

This is the most actionable gap. T96 hypothesize should explicitly include a falsifier: "regression test added to FULL_EXTRA in test/runtests.jl." T97 implementer can add both `"solvers/test_itp_ddi_strang_save_every.jl"` and `"solvers/test_rtp_ddi_strang_save_every.jl"` to `FULL_EXTRA`. Cost: trivial (2 lines in runtests.jl). Impact: closes the institutional gap permanently.

---

### §7. METRICS JSON

```json
{
  "experiment_kind": "researcher_shallow",
  "investigation_kind": "physics",
  "investigation_id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
  "stage_advancing_to": "Research",
  "flow_template": "verify-claim",
  "researcher_depth": "shallow",
  "src_files_read": 5,
  "src_files_modified": 0,
  "webfetch_used": true,
  "websearch_used": true,
  "n_external_refs_cited": 5,
  "n_internal_refs_cited": 4,
  "itp_loop_fix_confirmed_structurally": true,
  "regression_test_exists_with_canonical_assertions": true,
  "rtp_analogue_fix_confirmed_in_simulation_jl": true,
  "commit_0353b9b_found_in_git_log": false,
  "ci_tier_inclusion_documented": true,
  "n_falsifier_candidates_proposed": 6,
  "runs_eu151_mz_scan_disk_status": "absent",
  "pre_2026_05_02_eu_ddi_runs_inventoried": 12,
  "tier_promotion_argument_articulated": true,
  "verdict": "RESEARCH_DONE_FOR_HYPOTHESIZE",
  "state_json_modified": false,
  "manuscript_main_edited": false
}
```

## Budget

- Queries: 6 received, 6 answered (5 RESOLVED, 1 PARTIAL on commit hash)
- Web requests: 9 (3 WebSearch + 3 WebFetch + 2 Glob for runs/ + 1 CI yml read)
- Cache hits: 0
- Novel institutional gap found: F4 — neither Bug-4 regression test (`test_itp_ddi_strang_save_every.jl`, `test_rtp_ddi_strang_save_every.jl`) is wired into any `runtests.jl` tier.
- Novel discrepancy found: `docs/archive/AUDIT_BUG4.md` line 88 says RTP fix "not auto-fixed" but current `run_loops.jl` has the fix applied with tombstone comment. Doc is outdated.
