---
turn: 13
subagent: director
topic_tags: [barnett, tau-prefactor, rank2-cg, sympy-verify, gamma-dr, d1-tier-lift]
paper_section: null
depends_on: [11, 12, "theorist/turn_11.md", "judge/turn_12_critic_audit.md", "seed.md (2026-05-16 Barnett-pumping)", "memory:yan_li_saito_2026_barnett_paper.md", "memory:feedback_manuscript_is_not_the_essence.md"]
produces: "A symbolic CG computation that resolves T11 §2.6's rank-1 vs rank-2 mismatch flagged by T12 critic Audit-5: compute the actual rank-2 spherical-tensor enhancement W^CG_{m=F=6} = (γ_{m=+F} / Γ_dr) from losses.jl:144-176's formula, derive the corrected closed-form τ_Barnett prefactor, and confirm whether the empirical 7-14 ms agreement survives. Output: a sympy/numerical scratch file under runs/_loop/sim/turn_13/ plus a turn_13.md report banking the corrected prefactor as [Established] (sympy-verified) and re-tiering T11 §4 claim 5 from [Plausible] to either [Established within order of magnitude] or [Refuted with revised number]. This unblocks queuing the γ_dr=0 julia falsifier at 22:00 JST with a properly-justified prefactor in the prediction window."
---

# Turn 13 — Director Report

## 1. Project state snapshot

- **Active thread: Barnett spin-pumping campaign (seed.md 2026-05-16).** Other-session F=6 Eu-151 weak-Bz Klaus-style data: ΔF_z/N = 4.60 between Ω=±0.5, τ ≈ 7-14 ms. T11 produced a closed-form prediction τ ≈ 1/(F(F+1)γ_dr) ≈ 6 ms and a [Refuted] verdict against anko's secular-DDI hypothesis; T12 critic returned WEAK_PASS with one load-bearing FAIL.
- **T12 critic Audit-5 FAIL is narrow and actionable** (`runs/_loop/judge/turn_12_critic_audit.md` lines 37-53). T11 §2.6 invokes the rank-1 F_- matrix element (giving 12), but `src/hamiltonian/interactions/losses.jl:137-189` implements a **rank-2** spherical-tensor with Δm ∈ {-1,-2} CG-weighted and normalized so the m-average equals Γ_dr. The factor-2 numerical match at 6 ms vs 7-14 ms is therefore a coincidence-of-arithmetic, not a derivation. Critic's recommendation (iv): "implementer_sympy `clebsch_gordan(6,6,2,-1,6,5)^2 + clebsch_gordan(6,6,2,-2,6,4)^2` and normalize against the 13-component average" — exactly the workload class for this turn.
- **`src/foundation/clebsch_gordan.jl` exists** in the codebase (the production CG routine `losses.jl` calls). sympy.physics.quantum.cg has `CG(...).doit()` for closed-form symbolic verification, which can either (a) confirm the production routine's numerical output or (b) discover a long-standing inconsistency. Either way is D1 leverage.
- **Scheduler T13 (`runs/_loop/_local/scheduler_13.json`):** policy `TEXT_ONLY` until 22:00 JST (~6.25h remaining, **22498s left**). `allowed_workloads` = theorist / researcher / critic / implementer_text / implementer_sympy / noop. GPU probe clean (12 GB VRAM free, 1% util) but anko presumed-using; julia rejected. **`implementer_sympy` is in scope and is exactly what T12 recommended.**
- **Drift signals all green** at T12 entry: topic_repetition=0.1, subagent_repetition=0.333, cost_inflation=0.926 (no advisory). No `human_required` or `director_must_address` escalation. Subagent rotation: T10 implementer_text / T11 theorist / T12 critic — dispatching implementer_sympy is healthy rotation (not same-class-twice).
- **What's blocked:** the strongest falsifier (γ_dr=0 julia control, T11 §5.3) is locked behind 22:00 JST. T13's job is to *prepare the prediction window's prefactor* in the text-only hours BEFORE julia opens, so that when the falsifier runs it has a properly-justified comparison number — not a rank-1 coincidence.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T10 | implementer_text BCH-leak docstring + Option-γ assertion on split_step.jl + propagators.jl | PASS | Auto-commit `0d6f1a6`, scaling formula + dt threshold landed in docstrings. Drift-compliant. | Yes for what it was, though seed-orthogonal (Klaus thread, not Barnett). |
| T11 | theorist closed-form τ_Barnett + mechanism audit of secular-DDI hypothesis | NOOP (procedural §6 mislabel) | 796 lines, factor-2 numerical match, [Refuted] anko's stated mechanism, 5 falsifiable predictions, 3 deferred queries. Substantively the highest-value turn this campaign. | Substantively YES, procedurally NO — produced un-banked-because-unaudited content. |
| T12 | critic audit of T11 | CRITIC_WEAK_PASS | 10 per-item audits + 5 specific findings + concrete T13 recommendation. Found one load-bearing flaw (Audit-5 rank-1/rank-2 mismatch); validated mechanism qualitatively; explicitly queued γ_dr=0 julia for 22:00 JST. | Yes — exactly the §B3 critic dispatch that gates julia spend; cheap (1.30M) and decisive. |

**Trajectory check (§B4):** T10 implementer_text / T11 theorist / T12 critic — clean rotation, no same-class-in-a-row trap. T13 implementer_sympy is the natural next step: critic identified a specific symbolic-verifiable issue, and the workload class exists explicitly for this. Topic continuity is high (Barnett thread, ~D1+D3) but topic_repetition signal stayed low (0.1) because each turn moved a different *sub-issue* (T11 derive, T12 audit, T13 fix prefactor).

## 3. Bottleneck analysis

Filtered to TEXT_ONLY workload set, ranked by leverage = value × p(this turn moves it) / cost. Critic T12 already framed most options for us.

### B-1: implementer_sympy resolves the rank-2 CG prefactor (T12 Audit-5 fix)

*Issue*: T11 §2.6 eq (6) factor 12 is rank-1; codebase (losses.jl:162-189) is rank-2. Computing W^CG_{m=F=6} = γ_{m=+F} / Γ_dr from the actual formula tells us whether the empirical 7-14 ms agreement survives the correction. This is a single symbolic CG-sum call: |CG(6,6;2,-1|6,5)|² + |CG(6,6;2,-2|6,4)|², divided by the 13-component normalization Z = (1/13) Σ_m Σ_q |CG|².

*Category*: verification gap (D1 dominant) — fix the load-bearing numerical claim from T11 §4 claim 5 before it banks at the wrong number.

*Leverage*: **5**. The cost is small (~10-15 min sympy, ≤1.2M tokens per workload_specs). The value is decisive: either T11's order-of-magnitude survives (the prediction window remains 7-14 ms compatible) or it doesn't (the [Plausible] tier needs rework before the julia falsifier compares against it). T12 critic's recommendation (iv) explicitly names this as the right next step; T11 itself flagged Q2 as RESEARCH_NEEDED so the theorist concedes the gap. Closes a Tier-1→Tier-2 verification gate at a level a downstream julia run cannot close (julia tests the mechanism, not the prefactor algebra).

*What moves it*: **implementer_sympy**. Brief: compute the rank-2 enhancement at m=+F=6, compare to the rank-1 factor of 12, report the corrected τ_Barnett prefactor, and re-tier T11 §4 claim 5. Cross-check against `src/hamiltonian/interactions/losses.jl`'s `_dipolar_relaxation_shape(6)` to verify the production code itself is internally consistent with the CG library — if the production output disagrees with sympy, that's a real bug in `losses.jl` (highest possible D1 leverage per seed.md "what 'essence' looks like" §3).

### B-2: researcher answers Q1 (p=0.69 vs 0.315) and Q3 (Born-Markov master equation)

*Issue*: T12 specific-finding 2 — the parameter discrepancy is honestly flagged but unresolved. T11 §3.6 traces it to a likely g_J vs g_F confusion (factor 2.1×). This affects how the Ω-sweep and p-sweep predictions (§5.1, §5.2) are interpreted but does NOT block the γ_dr=0 falsifier (which holds at fixed-p).

*Category*: verification gap (parameter-extraction).

*Leverage*: **3**. Useful before the p-sweep julia run (T11 §5.2), but not before the γ_dr=0 control (§5.3) which is the *first* julia dispatch. T13 implementer_sympy is more time-critical because the falsifier's interpretation depends on the prefactor. Q1 stays queued for T14.

*What moves it*: researcher. ~12 min, ~1.0M. Deferred.

### B-3: theorist re-derives §2.6 with rank-2 CG from scratch

*Issue*: One could ask the theorist to redo §2.6 with the correct rank-2 algebra and the rotating-frame-derivation context preserved.

*Category*: physics gap.

*Leverage*: **2**. Wastes theorist cost on what is essentially a one-line CG computation. implementer_sympy is the right tool — it can also verify the rank-1 vs rank-2 ratio symbolically, which is harder for a theorist to claim without a sympy backend anyway. Theorist would also re-pass on §2.4-§2.9 logic that T12 already cleared. **Reject — wrong workload class.**

### B-4: critic_audit T11 §6 Q4 (discrete-grid DDI rotation invariance)

*Issue*: T12 Audit-4 left WEAK_PASS on this discrete-grid question. A cheap follow-up critic could read the FFT-grid implementation to characterize the broken-symmetry magnitude.

*Category*: verification gap.

*Leverage*: **2**. Sub-leading effect at 32³ with ω_x=ω_y (per T12). Not load-bearing for the Barnett claim. Defer.

### B-5: noop until 22:00 JST

*Issue*: Wait for julia window.

*Category*: meta.

*Leverage*: **1**. Same §A5 fail as T12 — cheap leveraged move exists (B-1). "Cost overhead IS the cost" memory: just execute the prefactor fix, don't deliberate.

### B-6: implementer_text writes an `@info` advisory at the secular-DDI threshold

*Issue*: seed.md mentioned this as an acceptable downstream artifact AFTER theory is in place.

*Category*: docs gap.

*Leverage*: **1**. Seed.md explicit: "ONLY after the theory is in place." T11+T12+T13 are still ratifying the theory. Premature. Also, anko's `feedback_manuscript_is_not_the_essence.md` memory specifically de-prioritizes docstring polish.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | **implementer_sympy fixes rank-2 CG prefactor (T12 Audit-5 follow-up)** | **implementer (compute_sympy)** | NOW — T12 critic recommendation (iv); resolves load-bearing numerical claim before 22:00 JST julia | ≤ 15 min, ≤ 1.2M |
| 2 | researcher answers Q1 p-discrepancy and Q3 Born-Markov literature | researcher | T14 if Q1 surfaces in implementer output | ≤ 12 min, ≤ 1.0M |
| 3 | theorist re-derive §2.6 | theorist | NEVER — wrong workload class (use sympy) | ≤ 20 min, ≤ 1.5M |
| 4 | critic on §2.4 discrete-grid DDI Q4 | critic | T14+ | ≤ 10 min, ≤ 1.3M |
| 5 | noop | n/a | rejected — cheap leveraged move exists | 0 |
| 6 | implementer_text @info advisory | implementer | DEFER — premature, anti-memory | ≤ 10 min, ≤ 0.5M |

**Pick: Option 1 (implementer_sympy).**

Why:

- **§A5 axis (a) — verify existing-implementation claim**: T11 §4 claim 5 says τ_Barnett ≈ 6 ms matches empirical within factor 2. T12 found this rests on rank-1 algebra while losses.jl uses rank-2. Sympy verifies the actual rank-2 number. ✓
- **§A5 axis (a) — bug-hunt in production code**: if sympy.physics.quantum.cg.CG agrees with `losses.jl:162-189`'s output and the rank-2 number gives O(10) instead of 12, T11's prefactor needs correction. If sympy DISAGREES with `losses.jl`'s production output, that's a real bug in production (highest D1 leverage per `feedback_manuscript_is_not_the_essence.md` §17 "bug-finding in production code"). ✓
- **§B3 implementer dispatch rule**: "Dispatch when the bottleneck is 'code benchmark vs known reference' or 'add an effect whose theory is already settled' — no theorist directive needed first; you provide the directive in §6.brief." The theory (rank-2 CG sum) IS already settled in `losses.jl`; what's needed is the numerical evaluation + comparison to T11 §2.6. Textbook fit.
- **§B4 rotation favorable**: T10 implementer_text / T11 theorist / T12 critic / T13 implementer_sympy — different workload classes each turn. No same-class-twice.
- **§B6 drift compliance**: all signals green (T12 history); cost_inflation 0.926 (well within 1.5x advisory floor). Picking a ~1.0-1.2M class beats theorist (~1.5M).
- **§B8 scheduler compliance**: implementer_sympy ∈ allowed_workloads; TEXT_ONLY honored; 22498s window-left is >> typical_duration 720s.
- **§D1 dominant**: this is the gate that decides whether T11's prefactor banks or rolls. If sympy confirms order-of-magnitude: T11 §4 claim 5 lifts from [Plausible] to [Established within O(1)], the γ_dr=0 julia falsifier at 22:00 JST has a clean prediction-window to compare against. If sympy refutes the 6 ms number (e.g., gives 30 ms): T11 §4 claim 5 needs theorist rework but the *qualitative* [Plausibly Refuted] verdict against anko's secular-DDI hypothesis survives (per T12 Audit-8) and the julia falsifier still tests the qualitative mechanism. Either path advances D1.
- **T12 critic recommendation verbatim**: "(iv) Derivation step needing theorist rework: §2.6 eq (6) rank-1 vs rank-2 reconciliation. A short follow-up theorist turn (or implementer_sympy `clebsch_gordan(6,6,2,-1,6,5)^2 + clebsch_gordan(6,6,2,-2,6,4)^2` and normalize against the 13-component average) is sufficient. Do this in parallel with the 22:00 julia queue — it does not block dispatch but does affect how the result is interpreted." T13 honors this with the *more appropriate* of the two alternatives (sympy over theorist).
- **seed.md fit**: "**implementer_sympy** turns: verify identities (commutators, conservation laws)." Direct quote, line 56. The CG-sum identity at m=+F is exactly that class.

Why NOT Option 2 (researcher Q1): the parameter discrepancy doesn't block the γ_dr=0 falsifier interpretation. Sympy fix is more time-critical.

Why NOT Option 3 (theorist re-derive): T12 explicit "or implementer_sympy" preference; sympy is cheaper and more reliable for an algebra check.

Why NOT Option 4 (Q4 discrete-grid): sub-leading per T12.

Why NOT Option 5 (noop): cheap leveraged move exists.

Why NOT Option 6 (advisory): premature + anti-memory.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness (D1) | **at risk → on track if T13 PASS** | T11 mechanism qualitatively cleared by T12 Audit-1/2/3/4/6/7/8/9. The single open numerical claim (Audit-5 prefactor) is exactly what T13 sympy will resolve. |
| Verification depth (D1 dominant) | **at risk → on track if T13 PASS** | Tier ladder for the Barnett claim: T11 = Tier 1 (theorist self-derived). T12 = audit revealed flaw. T13 sympy = Tier 2 (independent symbolic verification of the prefactor). T14+ julia γ_dr=0 (22:00 JST) = Tier 3 (empirical falsifier). T13 closes the gap between T12 findings and the julia dispatch. |
| Manuscript (D non-primary) | **on track but de-prioritized** | Three unmerged branches sit awaiting anko-merge. Per `feedback_manuscript_is_not_the_essence`, not this turn's concern. |
| Reproducibility | **on track** | seed.md + schedule.yaml + runs/eu151_barnett_spin/ archived. T13 will produce a reproducible sympy scratch under `runs/_loop/sim/turn_13/`. |
| Loop infrastructure | **healthy** | Drift all green; subagent rotation healthy across 4 turns; novel_claim_zero=0 since T11. |

**Mark**: Verification axis remains load-bearing. T13 implementer_sympy is the *precise* numerical resolution step between T12's critique and the eventual julia falsifier.

## 6. Dispatch decision

```json
{
  "subagent_type": "implementer",
  "rationale": "T12 critic (runs/_loop/judge/turn_12_critic_audit.md) WEAK_PASS hinged on one specific load-bearing FAIL: Audit-5 — T11 §2.6 eq (6) uses the rank-1 |F_-|² = 12 enhancement, but the codebase at src/hamiltonian/interactions/losses.jl:162-189 implements rank-2 spherical-tensor CG with Δm ∈ {-1, -2} normalized so the 13-component m-average = Γ_dr. The factor-12 numerical match (T11 τ ≈ 6 ms vs empirical 7-14 ms) is a coincidence-of-arithmetic, not a derivation. T12 recommendation (iv) verbatim: 'A short follow-up theorist turn (or implementer_sympy `clebsch_gordan(6,6,2,-1,6,5)^2 + clebsch_gordan(6,6,2,-2,6,4)^2` and normalize against the 13-component average) is sufficient.' implementer_sympy is the right choice (cheaper than theorist, exact algebra, also cross-checks the production routine). Scheduler T13 (runs/_loop/_local/scheduler_13.json) restricts to TEXT_ONLY; implementer_sympy is in allowed_workloads with ~720s typical duration vs 22498s window-left. seed.md line 56 explicitly lists 'implementer_sympy turns: verify identities (commutators, conservation laws)' as a campaign workload. This is the precise verification step between T12's flagged flaw and the 22:00 JST γ_dr=0 julia falsifier — without it, the julia run would compare against an un-justified prefactor.",
  "brief": "## Goal\n\nResolve T12 critic Audit-5 by computing the actual rank-2 spherical-tensor top-rung enhancement W^CG_{m=+F=6} that the codebase (`src/hamiltonian/interactions/losses.jl:162-189`) implements, derive the corrected closed-form τ_Barnett prefactor, and decide whether T11 §4 claim 5 (τ ≈ 6 ms matches empirical 7-14 ms within factor 2) survives the correction.\n\nAction class: `compute_sympy`. Produce a reproducible sympy script + a short report.\n\n## Materials to read\n\n1. `runs/_loop/theorist/turn_11.md` §2.5–§2.6 and §4 claim 5 — the rank-1 F_- argument and the factor-12 numerical claim.\n2. `runs/_loop/judge/turn_12_critic_audit.md` Audit-5 (lines 37-53) and Recommendation (iv) (lines 105) — the load-bearing flaw and the exact sympy expression suggested.\n3. `src/hamiltonian/interactions/losses.jl` lines 137-189 — the production formula:\n   - γ_m = Γ_dr · Σ_{q ∈ {-1,-2}} |CG(F, m; 2, q | F, m+q)|² / Z\n   - Z = (1/(2F+1)) · Σ_m Σ_q |CG|²\n   - Implementation in `_dipolar_relaxation_shape(F)`.\n4. (Cross-check only) `src/foundation/clebsch_gordan.jl` — production CG routine. Read just enough to confirm convention (Condon-Shortley phases, sign convention).\n\n## Computation\n\nWrite `runs/_loop/sim/turn_13/rank2_cg_prefactor.py` (or scratch under `/tmp/`; copy the file into `runs/_loop/sim/turn_13/` for the record).\n\nUse `sympy.physics.quantum.cg.CG(j1, m1, j2, m2, j3, m3).doit()` for exact rational arithmetic.\n\nSteps:\n\n1. For F=6 (D=13), compute the raw weight at m=+F:\n   - w_{+F} = |CG(6, 6; 2, -1 | 6, 5)|² + |CG(6, 6; 2, -2 | 6, 4)|²\n   - Note: CG(6, 6; 2, q | 6, 6+q) requires |6+q| ≤ 6; for q=-1 → m'=5; for q=-2 → m'=4. Both valid.\n2. For F=6, compute the raw weight at every m ∈ {-6, -5, ..., +6}:\n   - w_m = Σ_{q ∈ {-1,-2}, |m+q|≤F} |CG(6, m; 2, q | 6, m+q)|²\n3. Compute the normalization Z = (1/13) · Σ_m w_m.\n4. Compute the top-rung enhancement W^CG_{+F} = w_{+F} / Z. Report as exact rational, decimal, and as a ratio to T11's rank-1 value 12.\n5. Compute the corrected closed-form prefactor:\n   - τ^(-) ≈ 1 / (W^CG_{+F} · γ_dr)\n   - Using γ_dr = 4/50 = 0.08 dimless ω (per T11 §2.1), τ^(-) = (50/(4 W^CG_{+F})) · ω⁻¹ = (12.5 / W^CG_{+F}) · ω⁻¹\n   - Convert to ms via ω⁻¹ ≈ 0.92 ms (the run's ω_ref ≈ 1086 rad/s per T11 §2.1).\n   - Compare to empirical 7-14 ms.\n6. **Cross-validate against production**: invoke `_dipolar_relaxation_shape(6)` via a short julia one-liner OR replicate the Julia clebsch_gordan loop in python (use the same Condon-Shortley convention). Report the 13-component shape vector from sympy and confirm it matches the Julia production output element-wise. If they DISAGREE, this is a real production bug — flag it loudly. If they AGREE, the rank-2 algebra is self-consistent and T11's only error is the rank-1/rank-2 mismatch in §2.6 (a numerical re-interpretation, not a code bug).\n\n## Output\n\nWrite `runs/_loop/sim/turn_13.md` with:\n\n1. **Headline number**: W^CG_{+F=6} as exact rational + decimal.\n2. **Corrected τ_Barnett**: closed-form expression + numerical value in ms.\n3. **Empirical agreement re-assessment**: does the corrected prediction sit inside the empirical 7-14 ms window? If YES → T11 §4 claim 5 lifts from [Plausible] (with wrong reasoning) to [Established within order of magnitude]. If NO → T11 §4 claim 5 needs theorist rework on the *physics*, not just the algebra (perhaps the rotating-frame energy bias contributes a different m-resolved structure than pure γ_dr cascade).\n4. **Production cross-check**: sympy vs `losses.jl` output. State: AGREE (no bug found) or DISAGREE (production bug, name the discrepancy).\n5. **Re-tiering recommendation for T11 §4 claim 5**: explicit new tier ([Established within O(1)] or [Plausible with revised value] or [Refuted with empirical mismatch]).\n6. **Impact on γ_dr=0 julia falsifier (T11 §5.3)**: confirm that the falsifier remains decisive at the corrected prefactor (it should — the falsifier tests whether asymmetry persists at γ_dr=0, which is a yes/no question independent of the prefactor magnitude).\n\nKeep the report ≤ 200 lines. The sympy script under `runs/_loop/sim/turn_13/rank2_cg_prefactor.py` is the load-bearing artifact; the markdown summarizes.\n\n## Sanity checks before submitting\n\n- Confirm |CG(6, 6; 2, -1 | 6, 5)|² + |CG(6, 6; 2, -2 | 6, 4)|² is computed with the Condon-Shortley convention (sympy default).\n- Confirm the normalization Z averages over the 13 components AND over q ∈ {-1,-2} consistently with `losses.jl:177-189`.\n- The expected order of magnitude: rank-1 gave 12; rank-2 sum at m=+F with the same Δm=-1 channel plus a Δm=-2 channel should give O(1) to O(10) after normalization. If sympy gives O(100) or O(0.01), recheck the normalization.\n- Use exact rationals throughout; convert to decimal only at the end.\n\n## Out-of-scope\n\n- DO NOT run julia. The cross-check against `losses.jl` is python-replication of the loop with sympy CG, not a julia execution.\n- DO NOT modify `src/hamiltonian/interactions/losses.jl` even if AGREE. Production code untouched this turn — T14+ can write a docstring note if needed.\n- DO NOT re-derive §2.4 rotating-frame Hamiltonian or §2.7 c_1=0 isolation — those passed T12 audit.\n- DO NOT WebFetch CG tables. sympy.physics.quantum.cg.CG.doit() is the source of truth here.\n- DO NOT escalate to theorist for the physics interpretation of the corrected number — that's T14's job if needed.",
  "expected_outcome": "(1) `runs/_loop/sim/turn_13/rank2_cg_prefactor.py` reproducible sympy script. (2) `runs/_loop/sim/turn_13.md` with: W^CG_{+F=6} as exact rational + decimal (likely O(1)-O(10)); corrected τ_Barnett in ms; explicit verdict on whether corrected prediction fits empirical 7-14 ms; production cross-check sympy vs losses.jl (AGREE or DISAGREE-with-bug-flag); re-tiering for T11 §4 claim 5. (3) Decision-ready for the 22:00 JST γ_dr=0 julia dispatch — the falsifier remains decisive regardless of prefactor, but the comparison number is now properly justified. (4) If production cross-check DISAGREE: highest-D1-leverage bug surface this campaign. Cost ≤ 1.2M effective.",
  "expected_cost": "≤ 15 min wall-clock, ≤ 1.2M effective tokens. Reads ~50 lines of theorist/turn_11.md (§2.5-§2.6, §4 claim 5), ~20 lines of judge/turn_12_critic_audit.md (Audit-5 + Recommendation iv), ~60 lines of losses.jl, ~30 lines of clebsch_gordan.jl. Writes ~100 lines of python (uv run) + ~150 lines of markdown report. Comparable to T3 compute_sympy infra exercise (1.16M).",
  "if_fails_next_step": "If sympy AGREE with losses.jl AND corrected τ_Barnett fits empirical 7-14 ms: T14 queues the γ_dr=0 julia falsifier for the 22:00 JST window opening as the first dispatch (per T11 §8 Option B and T12 Recommendation iii). Parallel-dispatch researcher for Q1 (p=0.69 vs 0.315) and Q3 (Born-Markov KU2012/SKU2013/Pasquiou) if budget permits. If sympy AGREE with losses.jl BUT corrected τ_Barnett does NOT fit empirical window (e.g., gives 30 ms or 0.5 ms): T14 dispatches theorist to revisit §2.6's mechanism — perhaps the rotating-frame bias term contributes to the m-cascade rate in a way that is not pure γ_dr-weighted (e.g., partial coherent enhancement). Julia γ_dr=0 falsifier still queued at 22:00 because it remains the decisive test. If sympy DISAGREES with losses.jl (production bug found): T14 dispatches critic to confirm the bug independently, then implementer_text to add a `@warn` advisory or correctness fix to `losses.jl`. This would be a Tier-3 D1 win (real bug found in production code via the loop). Julia dispatch held until production fix in place.",
  "consumed_seed_md": true
}
```

`consumed_seed_md: true`. seed.md 2026-05-16 lines 55-56 explicitly call out "**implementer_sympy** turns: verify identities (commutators, conservation laws)" as a campaign workload. T13 honors T12 critic recommendation (iv) verbatim. The CG-sum identity at m=+F is exactly the workload class. The seed's "what 'essence' looks like" section lines 96-104 lists "*bug-discovery* if reproduction or audit reveals SpinorBEC.jl framework error (highest individual D1 leverage)" — the production cross-check inside this turn is precisely that opportunity.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=13, T11 NOOP / T12 CRITIC_WEAK_PASS, drift all green, last_judge=CRITIC_WEAK_PASS).
- [x] Read `runs/_loop/seed.md` (Barnett campaign; implementer_sympy explicit in list of campaign workloads, line 56).
- [x] Read `runs/_loop/judge/turn_12_critic_audit.md` (Audit-5 FAIL + Recommendation iv naming the sympy fix).
- [x] Read `runs/_loop/director/turn_12.md` (continuity — last director dispatched critic; this turn cashes the critic's findings).
- [x] Read `runs/_loop/_local/scheduler_13.json` (TEXT_ONLY, julia rejected, implementer_sympy ∈ allowed_workloads, 22498s window-left).
- [x] Read `runs/_loop/schedule.yaml` (3rd window: 08:00–22:00 JST TEXT_ONLY default-conservative).
- [x] Read `src/hamiltonian/interactions/losses.jl:130-189` to verify the rank-2 formula the critic referenced — confirmed: γ_m = Γ_dr · Σ_{q∈{-1,-2}} |CG(F,m;2,q|F,m+q)|² / Z.
- [x] Confirmed `src/foundation/clebsch_gordan.jl` exists for production cross-check.
- [x] Confirmed `.claude/workload_specs.yaml` lists `implementer_sympy` with typical_duration_sec=720 and typical_cost_eff=1.2M.
- [x] Read memory: `feedback_manuscript_is_not_the_essence.md` (D1 dominant, sympy + critic + bug-find > manuscript polish).
- [x] Considered NOT dispatching implementer_sympy — challenged with researcher (B-2: Q1 not blocking), theorist (B-3: wrong workload class per T12), critic (B-4: sub-leading), noop (B-5: leveraged move exists), implementer_text (B-6: premature + anti-memory). implementer_sympy wins on T12 recommendation verbatim + workload-class fit + §B4 rotation + §B8 scheduler.
- [x] §6 brief is specific: 4 numbered materials, 6 computation steps with exact sympy calls, 6 output items, sanity-check list, explicit out-of-scope. Implementer needs no clarifying questions.
- [x] Justified why THIS turn — the prefactor must be correct BEFORE the 22:00 JST γ_dr=0 julia dispatch so the comparison number is justified. Delaying means either delaying julia or running julia against an un-justified rank-1 prefactor.
- [x] `consumed_seed_md: true` — seed.md "implementer_sympy turns: verify identities" honored verbatim; T12 critic Recommendation (iv) verbatim.
