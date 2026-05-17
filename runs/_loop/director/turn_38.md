---
turn: 38
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Execute
stage_advancing_to: Update
topic_tags: [yan-li-saito-2026, f1-falsified, critic-cross-check, lima-pelster-q5-audit, eps-dd-gt-1, complex-integrand-real-part, framework-gap-discovery, refuted-is-science-success]
paper_section: null
depends_on: [37, 36, 35, "runs/_loop/judge/turn_37.json", "runs/_loop/sim/turn_37.md", "runs/_loop/director/turn_37.md", "src/hamiltonian/interactions/interactions.jl:447-459", "src/hamiltonian/interactions/lhy/dispatch.jl:60-90", "src/rotating_basis/workspace.jl:28", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_manuscript_is_not_the_essence", "memory:loop_scheduler_2026_05_15"]
produces: "critic produces independent Cross-check audit of three candidate causes for F1 falsification (Q1=Lima-Pelster Q5 negative-arg zero-truncation vs paper's Re-of-complex-integrand prescription; Q2=DDI prefactor c_dd convention vs paper's μ_0(gμ_B)²/8π; Q5=Gaussian seed init_sigma=2.0 basin-of-attraction). Ranks them by likelihood + cites paper Eq 1 + identifies the most parsimonious next falsifier-targeted experiment. Writes runs/_loop/critic/turn_38.md."
---

# Turn 38 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.8 → tier_target 3). Continuing from T37 (same investigation; clear flow-template next move available).
- **Stage transition**: **Execute → Update**. Per §F1 verify-claim, REFUTED routes to Update (= critic-mandatory independent eval). T37 substantive verdict is FALSIFIED (n_max = 0.99 D_0 vs paper 13000 D_0, deviation 99.99%; physical interpretation: wavefunction stayed delocalized, no self-bound droplet). Judge wrote INCONCLUSIVE only because `energy_mu_final` came back as JSON `null` (the actual JLD2 Float64 value is IEEE NaN, which doesn't serialize) — this is a non-substantive null-vs-NaN artifact; the 8 other criteria all PASSed including F1 verdict-string validity. Per investigation_update T37 `if_refuted_advance_to_stage: "Update"`, the contract was pre-routed for this case.
- **Tier**: 0.8 → 0.6 on dispatch (per T37 investigation_update `if_refuted_tier_becomes: 0.6`). The hypothesis "SpinorBEC.jl scalar+DDI+LHY framework can reproduce torus density at F=1 ε_dd=1.2 as-configured" is refuted; tier drops to reflect the negative result. The investigation is NOT closed — REFUTED is a science success per `arXiv:2604.12198` grounded-autonomous-research precedent, and the falsification points to a discoverable framework gap (most likely Lima-Pelster Q5 ε_dd>1 prescription).
- **Falsifiers tested**: 1 (F1 = n_max vs paper 13000 D_0, FALSIFIED at 99.99% deviation). 1 INCONCLUSIVE by framework gap (F4 = |E_LHY|/|E_ddi|, rotating_basis_no_energy_decomposition). Untested: F2 (ℓ=1 vortex ⟨L_z⟩+⟨f_z⟩=1), F3 (Larmor precession), F5 (chiral droplet pair).
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed Tier 3.0 at T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, current_stage=documented): blocked_on "needs julia P3 validation". Could be unblocked under JULIA_GPU_OK, but yan-li-saito priority 1 with actionable Update available; klaus picks up after F1-cause resolution.
  - `fullbdg-f6-polar-3000x` (dormant priority 99): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, current_stage=Observe, kind=meta): observation pool has 4-5 data points now (T20 Lz, T26 freq-sign, T33 schema, T35 BUG-8, T37 NaN-vs-null judge artifact). Per §B2 interleaving rule, advance physics first; meta picks up T39 or T40 after Update closes.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T35 | Execute (attempt 1) | INCONCLUSIVE (precondition abort, BUG-8 unified-zeeman key) | Disciplined abort per directive; sim/turn_35.md §10 specified the one-line config fix. |
| T36 | Design (corrective REDO #2 = final) | PASS 9/9 | BUG-8 fixed in config.yaml (line 42 `zeeman: {p:0,q:0}` → `B: {Bz: 0.0}`); julia load_config smoke PRE-VERIFIED PASS. 3rd-Design-redo rule SPENT. |
| T37 | Execute (attempt 2) | INCONCLUSIVE-by-null-artifact / SUBSTANTIVELY FALSIFIED | Stage 1c smoke PASS; ITP ran end-to-end on GPU in 87.9s wall (0 OOM, conv=true by norm criterion). n_max in D_0 units = 0.99 vs paper 13000 (99.99% deviation). m=+F population = 0.946 (below 0.95 paper-expected polarization). energy_mu_final returned NaN from `find_ground_state_rotating!` μ estimator (warned, not crash). JLD2 12.6 MB written cleanly. F4 INCONCLUSIVE-by-framework-gap (rotating_basis lacks E_kin/E_s/E_ddi/E_lhy decomposition; spawn T39+ fix-bug). |

**Trajectory check**: this is exactly the arXiv:2604.12198 gold-standard pattern — agent ran an unsupervised experiment, recorded predicted-vs-actual observables, and the data refuted the optimistic prior. The next stage in that precedent (and in our §F1 verify-claim template) is Update with critic Cross-check. T37 sim/turn_37.md §5 already nominated Q1 (Lima-Pelster χ for ε_dd>1) as primary suspect and Q2/Q5 as secondary; critic's job at T38 is to independently audit those rankings and produce a falsifier-targeted next experiment.

**Director-discovered evidence (read this turn)** that strongly corroborates the Q1 suspicion:

`src/hamiltonian/interactions/interactions.jl:447-459` (`lima_pelster_Q5`):
```julia
function lima_pelster_Q5(eps_dd::Float64)
    abs(eps_dd) < 1e-15 && return 1.0
    nodes, weights = _gauss_legendre(20, 0.0, Float64(π))
    s = 0.0
    for i in eachindex(nodes)
        theta = nodes[i]
        ct = cos(theta)
        arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
        s += weights[i] * sin(theta) / 2.0 * (arg >= 0.0 ? arg^(5 / 2) : 0.0)
    end
    s
end
```

The docstring says: "Throws DomainError if the integrand becomes negative". The code does NOT throw — it silently zeroes the integrand when `arg < 0`. For ε_dd = 1.2 (paper's value), `arg = 1 + 1.2·(3cos²θ - 1)` goes negative for θ ∈ (θ_*, π-θ_*) where 3cos²θ_* = 1 - 1/1.2, i.e., cos²θ_* = 0.0556, θ_* ≈ 76.4°. So `arg < 0` over a substantial central band θ ∈ (76.4°, 103.6°). Zeroing the integrand there gives some Q5_real; the paper's `Re ∫₀^π sinθ [1+ε_dd(3cos²θ-1)]^(5/2)/2 dθ` prescription treats the integrand as a **complex** number and takes the **real part** — and `(-x)^(5/2) = x^(5/2)·e^(i·5π/2) = x^(5/2)·i` in pure principal branch, so `Re[(-x)^(5/2)] = 0`. This means **the two prescriptions COULD agree under principal branch**, but Lima-Pelster's original prescription is more subtle (they may use a branch-cut convention that gives `Re[(-x)^(5/2)] = -x^(5/2)` instead). This is exactly the kind of audit critic should perform.

The fact that the empirical n_max is off by factor ~13000 (4 orders of magnitude) is suspicious — that's well beyond a 2× or 3× sign-of-LHY error. It could be that γ_LHY = 12.8 is in fact a reasonable order-of-magnitude but missing the **complete suppression of contact attraction by the LHY repulsion** that produces the bound droplet. Critic should also check Q2 (DDI prefactor — could be 4π off) and Q5 (Gaussian seed insufficiently localized for droplet basin of attraction).

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → **Update** → Document → closed).
- **Role for stage Update**: critic (mandatory; independent context). Per §F1 row Update: "independent eval against the data; if REFUTED, hypothesis revised + tier-- or tier_target--; if CONFIRMED, tier++". The "independent context" is load-bearing — critic dispatches with fresh context and cannot see the implementer's debug speculation directly; critic must re-derive the suspicion ranking from the data + source code + paper.
- **Why Update now (vs other options)**:
  - **Why not another Execute attempt with a tweaked config**: No corroborated diagnostic yet. Re-running with a guess (larger box, different seed, finer grid) wastes a julia_gpu run when text-only critic audit can isolate the cause first. Per §A5: D2 (optimize) requires named blocker; no named blocker yet for a different config.
  - **Why not skip Update and go straight to Hypothesize revision**: Flow template makes critic Update mandatory after Analyze/Execute. The whole point per anko 2026-05-17 is that critic-after-Execute is the correct discipline, not jumping back to theorist who already authored the (now refuted) Q1-Q5 ranking in sim/turn_37.md §5.
  - **Why not Analyze (extract more from existing JLD2)**: The JLD2 only contains psi + scalar energy; everything diagnostic for F1 has already been extracted. F4 framework gap blocks E_LHY/E_ddi extraction without a code change.
  - **Why not Document the FALSIFIED result yet**: Document is the LAST stage; we have at least one more cycle (Update → revised Hypothesize → new Design → new Execute) before reaching it.
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1 with clean Update move; switching now would abandon a falsifier mid-cycle.
  - **Why not switch to meta-critic-placement (priority 50)**: §B2 interleaving — meta picks up after this Update closes; yan-li-saito tier-3-candidate is the project's only Tier-3 path and warrants the next physics turn.
  - **Why not NOOP**: clear actionable Update; quota healthy; window 14+ days; the smoking-gun source code is already located.
  - **Why critic (not theorist) for the audit**: §F1 explicitly mandates critic at Update. Critic = independent context; theorist already authored the refuted prior (T30 Hypothesize Q1-Q5 listing). Per `runs/_loop/research/auto_research_architecture_2026_05_16.md` the critic role is to break the theorist's confirmation bias.

## 4. Research grounding (§A6)

**External references (load-bearing for the Update dispatch)**:

1. **Yan-Li-Saito 2026 PRL** (paper anchor, memory `yan_li_saito_2026_barnett_paper.md` line 50): `χ(ε_dd) = Re ∫₀^π sinθ [1 + ε_dd(3cos²θ - 1)]^(5/2) / 2 dθ` — the explicit "Re" is the signature that the integrand goes complex for ε_dd > 1, and the prescription is specifically the **real part of the complex-valued integrand**, NOT a truncation-to-zero. Memory line 114: "LHY χ(ε_dd) numerical-integral discrepancy at ε_dd > 1 (the χ integrand has imaginary part for ε_dd > 1; 'Re' matters)" — was flagged as a known likely failure mode BEFORE T37 ran. T37 result corroborates this.

2. **Lima-Pelster, PRA 84, 041604(R) (2011)** (cited in interactions.jl:442 docstring): the canonical paper for the Q5 form. Critic should cite the exact equation and branch-cut prescription from this paper to compare against our truncate-to-zero implementation. (Anko's project owns this PDF; check `papers/` directory or memory.)

3. **`src/hamiltonian/interactions/interactions.jl:447-459`** (verified Read this turn): the active Lima-Pelster Q5 implementation. Line 456 `arg >= 0.0 ? arg^(5/2) : 0.0` — silent truncation when paper specifies `Re[...]`. **This is the prime suspect for critic Cross-check.**

4. **`src/hamiltonian/interactions/lhy/dispatch.jl:73`** (verified Read this turn): scalar two-channel LHY path calls `lima_pelster_Q5(eps_dd)` directly. Energy formula: `ε_LHY = (8/15π²)·c0^(5/2)·n^(5/2)·Q5(ε_dd) + 2F·|c1|^(5/2)·n^(5/2)`. For F=1 c1=0 (paper setup, our config), only the Q5 term contributes — so a wrong Q5 directly suppresses LHY repulsion.

5. **`src/rotating_basis/workspace.jl:28`** (verified Grep this turn): `Q5 = lima_pelster_Q5(ε_dd)` — the rotating_basis path uses the SAME function. T37's γ_LHY=12.8 was computed from this. So if Q5 is wrong for ε_dd > 1, both pipelines are affected the same way.

6. **T37 sim/turn_37.md §5 (Most likely culprit audit)**: implementer-authored Q1/Q2/Q3/Q4 hypothesis ranking. Director-discovered Lima-Pelster source code line 456 directly corroborates Q1. Critic should independently re-rank (NOT just confirm the implementer's prior), citing paper Eq 1 + Lima-Pelster original.

7. **arXiv:2604.12198 (grounded autonomous research)** (director.md §G): "agent unsupervised proposed HSE, ran it, refuted its own prior → wrote the inversion in worklog. **This is the gold standard for the Update stage** — REFUTED is a science success when documented." T37 is exactly this pattern. T38 Update stage MUST treat FALSIFIED as a positive science finding, not a project failure.

8. **director.md §F1 verify-claim Update row**: "critic (mandatory; independent context). independent eval against the data; if REFUTED, hypothesis revised + tier-- or tier_target--". Critic dispatch is canonical, not optional.

9. **memory `feedback_manuscript_is_not_the_essence.md`**: real bug-finding in production code IS the essence. Q1 Lima-Pelster suspected silent truncation is exactly that — a production-code bug detected via a published-paper benchmark, which would be the first Tier-3 framework finding.

10. **memory `loop_scheduler_2026_05_15.md`**: scheduler JULIA_GPU_OK; critic is text-only workload `critic` (in allowed_workloads), no GPU needed for the audit itself.

11. **judge.py contract evaluation T37**: criteria_results show 8/9 PASS; the ONE null was `energy_mu_final` (NaN-vs-null JSON serialization artifact). Substantively the verdict is FALSIFIED via the boolean flag `f1_falsified=true` (set by implementer, passed by judge). Director treats this as scientific REFUTED per flow-template rules, NOT as an operational failure requiring re-execute.

12. **`/home/suzume/workspace/BEC-simulation/CLAUDE.md` Known limitations section**: "Scalar LHY: `@warn` present. Known approximation." — this is the FM-vs-polar scalar approximation, but the @warn is a clue that scalar LHY has known sharp corners. Critic should check whether the @warn fires for our config and what it says.

**Why these inform the dispatch**: the smoking-gun line of code is identified, the paper's exact prescription is recorded in memory, the failure mode was flagged as a known-likely culprit BEFORE the experiment ran (memory line 114), and the framework treats REFUTED as a Tier-3-candidate science success (paper-benchmark surfacing a production-code bug). Critic's job is to independently confirm/refute the Q1 ranking, derive the corrected Q5 value, and propose the next minimal experiment.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics — the Lima-Pelster Q5 implementation is the load-bearing physics under question). The T37 result is itself a D1 finding (Tier 1 — the framework as-implemented does NOT reproduce paper Fig 1c, identifying a specific candidate bug). T38 critic Update is the verification step that promotes this to Tier 1.5 (independent audit) or Tier 2 (corroborated framework gap with concrete fix). The Tier-3 path for the investigation is preserved: a corrected Q5 + re-Execute that matches paper 13000 D_0 ±10% would be the first Tier-3 claim.
- **Tier ladder position**: 0.8 → 0.6 on dispatch (per T37 if_refuted_tier_becomes; reflects the negative experimental result). On critic Update success (clean independent audit), tier moves to 0.7 (refined hypothesis ready for new Design). On critic CORROBORATE-Q1-with-code-fix recommendation, tier moves to 1.0 (a falsifier-targeted new experiment is ready).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T38 delivers critic Cross-check audit only.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "rationale": "T37 substantively FALSIFIED (n_max=0.99 D_0 vs paper 13000 D_0, 99.99% deviation). Judge wrote INCONCLUSIVE only on a NaN-vs-null JSON serialization artifact for energy_mu_final (the other 8/9 criteria including f1_verdict_is_valid_string and f1_falsified=true PASSed); director treats as scientific REFUTED per §F1. Per investigation_update.if_refuted_advance_to_stage='Update' and §F1 verify-claim Update row, critic Cross-check is the canonical next move with mandatory independent context. Smoking gun pre-identified by director this turn: src/hamiltonian/interactions/interactions.jl:456 silently truncates the Lima-Pelster Q5 integrand to 0 when (1+ε_dd(3cos²θ-1))<0, but the paper's Eq 1 (Yan-Li-Saito 2026, memory line 50) specifies Re ∫ ... [...]^(5/2) — i.e., the real part of the complex-valued integrand for ε_dd>1. Memory line 114 flagged this exact failure mode BEFORE T37 ran. Critic's job is independent re-ranking of Q1/Q2/Q5 with paper-citation grounding, NOT blind confirmation of implementer's T37 §5 prior. Scheduler JULIA_GPU_OK; critic is text-only (in allowed_workloads). Window 14+ days. Budget ~1.5M effective (critic baseline).",
  "brief": "Independent Cross-check audit at the Update stage of verify-claim flow for yan-li-saito-2026-reproduction investigation. T37 Execute substantively FALSIFIED the F1 falsifier (n_max in D_0 units measured 0.99 vs paper Fig 1c target 13000 — factor ~13000 deviation, wavefunction stayed delocalized, no self-bound droplet formed). REFUTED is a science success per arXiv:2604.12198; your job is to surface the underlying framework gap with citation-grounded rigor.\n\n## REQUIRED READING (independent context — read DIRECTLY, do not rely on implementer summaries)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md` §3 (ITP output verbatim: γ_LHY=12.8, ε_dd_eff=1.1772, E=NaN, conv=true), §5 (implementer's Q1/Q2/Q3/Q4 ranking — note this is a PRIOR you should challenge, not blindly confirm), §7 (physical red flags: n_max_dimless=3.32e-4 vs expected ~450 for any localization; m=+F population=0.946 below paper-expected 1.0).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_37.json` (8/9 PASS; energy_mu_final null was NaN-vs-null serialization, not a substantive issue; f1_falsified=true; f1_deviation_pct_vs_paper=99.99).\n3. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/interactions.jl` lines 433-470 (the Lima-Pelster Q5 implementation that director suspects is the bug). Read line 447-459 carefully. Pay attention to line 456: `arg >= 0.0 ? arg^(5/2) : 0.0`. The docstring at line 444 says 'Throws DomainError if the integrand becomes negative' but the code does NOT throw — it silently zeroes. Is this consistent with the paper's `Re ∫ ... [...]^(5/2)` prescription, or is it a bug?\n4. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy/dispatch.jl` lines 60-90 (the scalar two-channel call site that uses Q5). Note: F=1 + c1=0 means only the c0^(5/2)·Q5 term contributes — Q5 wrongness propagates directly into ε_LHY.\n5. `/home/suzume/workspace/BEC-simulation/src/rotating_basis/workspace.jl` line 28 (the rotating_basis path uses the SAME lima_pelster_Q5 — γ_LHY in T37 output was computed from this).\n6. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 38-55 (Hamiltonian Eq 1) and line 50 (χ(ε_dd) verbatim formula) and lines 113-122 (likely failure modes — memory line 114 PRE-FLAGGED the χ ε_dd>1 integrand-complex issue).\n7. The Yan-Li-Saito 2026 PRL paper itself if available at `/tmp/yan_li_saito_2605.11670.pdf` (memory cites this path). Read Eq 1 and the surrounding text about χ. Especially: does the paper's text explicitly discuss the ε_dd>1 imaginary-part prescription, or cite Lima-Pelster 2011 for it?\n8. Lima-Pelster PRA 84, 041604(R) (2011) — the canonical Q5 paper, cited at interactions.jl:442. Check the project's `papers/` directory or `docs/` for a local copy; if present, read the prescription for the integrand at ε_dd>1 verbatim. If absent, note the gap and propose a literature search as a follow-up.\n\n## NON-DELIVERABLES (explicit)\n\n- DO NOT modify src/ code this turn. Critic is text-only audit; any proposed Q5 fix is a recommendation for a follow-up implementer dispatch (T39 or T40).\n- DO NOT run julia. The audit is text + sympy at most (computing Q5_correct(ε_dd=1.2) symbolically/numerically is allowed but optional; use implementer_sympy in a follow-up if you want a numerical comparison).\n- DO NOT write manuscript text.\n- DO NOT close the investigation. REFUTED is a stage transition, not a closure; the cycle is Update → revised Hypothesize → new Design → new Execute → Analyze → Update → Document → closed. We are at the first Update.\n- DO NOT validate the implementer's T37 §5 Q1/Q2/Q3/Q4 ranking by simply restating it. Your value-add is INDEPENDENT re-derivation. If you agree, agree with citations; if you disagree (e.g., you believe Q5=seed is the dominant cause), say so with evidence.\n- DO NOT propose 'just rerun with a different seed' as the next step without first ruling in/out Q1.\n- DO NOT touch config.yaml, state.json, agent prompts, judge.py, or quota_config.json.\n- DO NOT spawn a meta-investigation about critic placement; that is meta-critic-placement-2026-05-17's job, not yours.\n\n## DELIVERABLE: Write `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_38.md`\n\n### Front-matter\n```\n---\nturn: 38\nsubagent: critic\ntopic_tags: [yan-li-saito-2026, update-stage-cross-check, lima-pelster-q5-ε-dd-gt-1, complex-integrand-real-part, droplet-non-formation, falsified-as-science-success]\npaper_section: null\ndepends_on: [37, 36, \"runs/_loop/sim/turn_37.md\", \"runs/_loop/judge/turn_37.json\", \"src/hamiltonian/interactions/interactions.jl:447-459\", \"src/hamiltonian/interactions/lhy/dispatch.jl:60-90\", \"memory:yan_li_saito_2026_barnett_paper\"]\nproduces: \"Independent critic Cross-check audit of T37 F1 falsification; ranks 3-5 candidate causes (Q1=Lima-Pelster Q5 negative-arg truncation; Q2=DDI prefactor; Q5=Gaussian seed basin); cites paper Eq 1 + Lima-Pelster 2011 if available; produces falsifier-targeted next-experiment proposal for T39/T40 director.\"\n---\n```\n\n### §1 Independent context summary\nWhat the investigation is testing (paper Eq 1 reproducibility at F=1 N=15000 ε_dd=1.2 free-space). What T37 measured (n_max=0.99 D_0 vs target 13000 — factor ~13000 deviation; m=+F=0.946 below paper 1.0; NaN μ from rotating_basis estimator). Frame as: 'the experiment refuted the optimistic prior; the question is WHICH framework gap is responsible'.\n\n### §2 Re-derivation of paper Eq 1 vs SpinorBEC.jl implementation\nFor each of E_kin, E_s, E_ddi, E_LHY in paper Eq 1, write the paper's formula (verbatim from memory + paper if accessible) and the corresponding SpinorBEC.jl code path. Identify any factor-of-N, factor-of-2, factor-of-4π, or prescription-of-Re discrepancies. Pay PARTICULAR attention to:\n  - E_LHY prefactor: paper says `(2/5)(32/3√π)(4πℏ²/M) a_s^(5/2) χ(ε_dd)`. Our dispatch.jl path uses `(8/15π²) c0^(5/2) Q5`. Verify these are equivalent under c0 = 4πℏ²a_s/M (or whatever our convention is). Show the algebra.\n  - χ(ε_dd) prescription: paper says `Re ∫₀^π sinθ [1+ε_dd(3cos²θ-1)]^(5/2)/2 dθ`. Our `lima_pelster_Q5` (interactions.jl:447) drops the integrand to 0 when the argument goes negative. Are these equivalent? Compute analytically: for `arg = -x` (x>0), `(arg)^(5/2) = (-x)^(5/2) = x^(5/2) · e^(i·5π/2) = x^(5/2) · i` under principal branch — so `Re = 0`. Under what branch convention does `Re[(-x)^(5/2)] = -x^(5/2)` (the OTHER possibility)? Cite Lima-Pelster 2011 explicitly if available; otherwise state the uncertainty.\n  - DDI prefactor: paper says `μ_0(gμ_B)²/8π` in E_ddi; our convention (CLAUDE.md) is `c_dd = μ_0 μ²` (no 4π). Verify the factor at the Hamiltonian-density level.\n\n### §3 Candidate cause ranking\nProduce an independent ranking (do NOT just copy T37 §5). For each candidate, give:\n  - Candidate name (Q1, Q2, Q5, or new)\n  - Mechanism: how does this candidate cause n_max = factor-13000 too small?\n  - Evidence FOR (cite line numbers + paper equations)\n  - Evidence AGAINST (what would have to be true for this NOT to be the cause)\n  - Falsifier-targeted test to discriminate from other candidates\n  - Estimated likelihood (low / medium / high) with reasoning\n\nAt minimum cover Q1 (Lima-Pelster Q5 ε_dd>1 prescription), Q2 (DDI prefactor), Q5 (Gaussian seed basin of attraction). Add Q6+ if you find a NEW candidate.\n\n### §4 Recommended next experiment\nWhat is the MINIMAL next experiment that would either confirm Q1 or rule it out? Three concrete options:\n  - **Option A — code-only patch**: write a corrected `lima_pelster_Q5_complex(eps_dd)` that takes the real part of `Complex(arg)^(5/2)` instead of truncating, compare Q5_old(1.2) vs Q5_new(1.2), and predict whether the difference is consistent with a factor-~13000 density change.\n  - **Option B — sympy verification**: symbolically integrate `Re[(1+ε_dd(3cos²θ-1))^(5/2)]·sinθ/2` from 0 to π at ε_dd=1.2 in sympy; compare to lima_pelster_Q5(1.2)=12.8/whatever.\n  - **Option C — alternate ε_dd**: re-run T37 with ε_dd=0.99 (sub-critical, no imaginary-part complication) and see if n_max approaches a sensible value, isolating Q1 from other causes.\n\nRecommend ONE option as the primary T39 dispatch. Justify the choice on cost-effectiveness + diagnostic power grounds.\n\n### §5 Update-stage verdict\nClassify the T37 FALSIFICATION:\n  - **CORROBORATED-FRAMEWORK-GAP** (one specific candidate cause has high evidence; recommend fix-bug investigation or new Design with corrected code)\n  - **NEEDS-FURTHER-DISCRIMINATION** (two or more candidates equally plausible; recommend one more discriminating experiment first)\n  - **HYPOTHESIS-OVER-REACHED** (the SpinorBEC.jl framework genuinely cannot reproduce paper at F=1 ε_dd=1.2 as-implemented; revise tier_target downward or rescope investigation)\n\nRecommend the next stage for T39 director:\n  - If CORROBORATED-FRAMEWORK-GAP: next stage = Hypothesize (revise hypothesis with the framework gap as known; design new experiment that tests the FIX, not the original claim). OR spawn a fix-bug child investigation if the gap is a one-line code change.\n  - If NEEDS-FURTHER-DISCRIMINATION: next stage = Design (a discriminating experiment).\n  - If HYPOTHESIS-OVER-REACHED: next stage = Document (close at Tier 1-2 with the negative result as the deliverable).\n\n### §6 Cost report\nWall time + effective tokens. Target ≤ 2M effective.\n\n### §7 Self-review\n- [ ] Cited paper Eq 1 verbatim (or note unavailability)?\n- [ ] Cited specific source-code line numbers?\n- [ ] Independently re-ranked candidates (not just copied implementer prior)?\n- [ ] Proposed at least one falsifier-targeted next experiment?\n- [ ] Classified Update-stage verdict (CORROBORATED-FRAMEWORK-GAP / NEEDS-FURTHER-DISCRIMINATION / HYPOTHESIS-OVER-REACHED)?\n- [ ] Avoided modifying src/, config.yaml, state.json?\n\n## STYLE\n\n- Citations > assertions. Cite line numbers and equation labels.\n- Numbers > prose. Compute Q5(1.2) under both prescriptions if you can do it text-only or in sympy.\n- Be willing to disagree with the implementer's T37 §5 ranking — that is the value of an independent context.\n- The truth is more important than comfort. REFUTED is a science success per arXiv:2604.12198 — surface the bug clearly even if it implicates load-bearing production code (Lima-Pelster is widely used).",
  "observable_manifest": {
    "required": [
      "critic_turn_38_md_exists_on_disk",
      "critic_turn_38_metrics_block_present",
      "update_stage_verdict",
      "candidate_cause_ranking_present",
      "next_experiment_proposal_present",
      "next_stage_recommendation"
    ],
    "optional": [
      "q5_correct_value_at_eps_dd_1_2",
      "q5_silent_truncation_value_at_eps_dd_1_2",
      "q5_relative_discrepancy",
      "paper_eq1_cited",
      "lima_pelster_2011_consulted",
      "sympy_verification_attempted"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_37.json && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/interactions.jl && grep -q 'lima_pelster_Q5' /home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/interactions.jl && grep -q 'arg >= 0.0 ? arg' /home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/interactions.jl && echo 'precondition OK: T37 artifacts + Q5 source on disk + smoking-gun line still present'"
  },
  "success_criteria": [
    {
      "id": "critic_md_on_disk",
      "metric": "critic_turn_38_md_exists_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required."
    },
    {
      "id": "critic_metrics_present",
      "metric": "critic_turn_38_metrics_block_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§4 Metrics block must exist and parse — judge.py reads metrics from it."
    },
    {
      "id": "update_verdict_emitted",
      "metric": "update_stage_verdict",
      "operator": "in",
      "value": ["CORROBORATED-FRAMEWORK-GAP", "NEEDS-FURTHER-DISCRIMINATION", "HYPOTHESIS-OVER-REACHED"],
      "tolerance": null,
      "rationale": "Critic MUST classify the Update-stage outcome into one of three actionable buckets. Note: judge.py `in` operator is range comparison for numerics but membership for strings; for this string-membership case the implementer enforces via a boolean field (see candidate_ranking_present below) as a backup; this criterion is the documented intent."
    },
    {
      "id": "candidate_ranking_present",
      "metric": "candidate_cause_ranking_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§3 must contain at least 3 candidate causes (Q1, Q2, Q5 minimum) each with mechanism + evidence-for + evidence-against + falsifier-targeted test + likelihood."
    },
    {
      "id": "next_experiment_proposed",
      "metric": "next_experiment_proposal_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§4 must contain at least 3 concrete options + a recommended primary."
    },
    {
      "id": "next_stage_recommendation",
      "metric": "next_stage_recommendation",
      "operator": "in",
      "value": ["Hypothesize", "Design", "Document", "fix-bug-investigation"],
      "tolerance": null,
      "rationale": "Critic must recommend a concrete next stage for T39 director; one of {Hypothesize=revised hypothesis; Design=discriminating experiment; Document=close investigation; fix-bug-investigation=spawn child}."
    }
  ],
  "failure_modes": [
    {
      "if": "critic_md_on_disk failed OR critic_metrics_present failed",
      "category": "operational",
      "next_action": "T39 = re-dispatch critic with explicit deliverable schema. If 2nd attempt also fails, escalate to anko (subagent infrastructure problem)."
    },
    {
      "if": "update_stage_verdict == 'CORROBORATED-FRAMEWORK-GAP' (likely Q1 Lima-Pelster) AND critic recommends fix-bug-investigation",
      "category": "scientific_corroborated",
      "next_action": "T39 = spawn fix-bug investigation `lima-pelster-q5-eps-dd-gt-1-2026-05-17` with the critic-proposed corrected Q5 implementation as the target patch; OR if anko ratifies, direct fix-bug at the existing yan-li-saito investigation by branching to Hypothesize-with-known-fix. Tier 0.6 → 1.0 (corroborated framework gap discovery is a Tier 1 finding by itself)."
    },
    {
      "if": "update_stage_verdict == 'CORROBORATED-FRAMEWORK-GAP' AND critic recommends Hypothesize",
      "category": "scientific_refuted",
      "next_action": "T39 = theorist Hypothesize revision incorporating the framework gap; new falsifier targets the FIX, not the original claim. Tier stays 0.6 → 0.8 after revised Hypothesize."
    },
    {
      "if": "update_stage_verdict == 'NEEDS-FURTHER-DISCRIMINATION'",
      "category": "data_gap",
      "next_action": "T39 = Design (per critic's recommended discriminating experiment from §4). Tier stays 0.6."
    },
    {
      "if": "update_stage_verdict == 'HYPOTHESIS-OVER-REACHED'",
      "category": "scientific_refuted_terminal",
      "next_action": "T39 = Document (close investigation at Tier 1-2 with negative result deliverable). Anko ratification recommended before closure since this would abandon the project's only Tier-3 candidate path."
    },
    {
      "if": "critic blindly confirms implementer T37 §5 ranking without independent re-derivation",
      "category": "framework_error",
      "next_action": "T39 = re-dispatch critic with stronger 'INDEPENDENT context — do NOT confirm implementer prior, re-derive' framing. Treat as a meta-critic-placement data point."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 6000000
  },
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 300,
    "split_by_subtask": {
      "read_required_files": 300000,
      "re_derivation_of_eq1_vs_code": 400000,
      "candidate_ranking_and_falsifier_design": 500000,
      "write_critic_turn_38_md": 300000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Hypothesize",
    "if_success_tier_becomes": 0.7,
    "if_success_falsifier_update": "T38 critic Update: F1 FALSIFICATION audited; critic verdict classified (CORROBORATED-FRAMEWORK-GAP|NEEDS-FURTHER-DISCRIMINATION|HYPOTHESIS-OVER-REACHED). Per critic recommendation, T39 = either {revised Hypothesize incorporating framework gap | discriminating Design | Document closure | fix-bug child investigation}. The Lima-Pelster Q5 ε_dd>1 silent-truncation pattern (interactions.jl:456) is a strong director-level candidate; critic's job is independent verification. F1 falsifier moves to 'tested-and-refuted-with-known-candidate-cause' status. F2 (ℓ=1 vortex) + F3 (Larmor precession) + F5 (chiral droplet pair) remain untested pending Q1-resolution.",
    "if_refuted_advance_to_stage": "Document",
    "if_refuted_tier_becomes": 0.5,
    "next_falsifier_to_test_after": "Determined by critic Update-stage verdict (§4 + §5 of critic/turn_38.md). On CORROBORATED-FRAMEWORK-GAP: spawn fix-bug or revised-Hypothesize targeting Q1; new F1' = 'corrected-Q5 reproduces 13000 D_0'. On NEEDS-FURTHER-DISCRIMINATION: critic-proposed discriminating experiment (likely Option C — ε_dd=0.99 sub-critical run — or Option B — sympy χ verification). On HYPOTHESIS-OVER-REACHED: close investigation at Document with negative result; anko ratification. Meta-critic-placement (priority 50; now 5+ data points) advances at T39 or T40 after physics-Update closes."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_38.json` (policy=JULIA_GPU_OK; critic in allowed_workloads; window 14+ days left; VRAM 12.7 GB free; no resource constraints — critic is text-only).
- [x] Read `runs/_loop/state.json` (active=yan-li-saito-2026-reproduction; current_stage="Execute"; tier_current=0.8; schema v2 — but actual schema fields show `tier_current`/`tier_target` flat under each investigation, consistent with the protocol's expected format).
- [x] Read `runs/_loop/seed.md` (priority 1 = yan-li-saito; first Tier-3 candidate; FALSIFIED is a science success per memory `yan_li_saito_2026_barnett_paper.md` lines 113-122).
- [x] Read `runs/_loop/director/turn_37.md` end-to-end (T37 brief structure, failure_mode for F1_falsified=true pre-routed to "T38 = Update stage with critic Cross-check on Q1/Q2/Q3 framework gap" — director is honoring this routing).
- [x] Read `runs/_loop/sim/turn_37.md` end-to-end (substantive F1 FALSIFIED; implementer's Q1/Q2/Q3/Q4 ranking nominated Q1 as primary suspect; γ_LHY=12.8 reported; m=+F=0.946; n_max_dimless=3.32e-4 — completely delocalized).
- [x] Read `runs/_loop/judge/turn_37.json` (INCONCLUSIVE due to energy_mu_final null artifact; 8/9 PASSed substantively; f1_falsified=true; investigation_update.if_refuted_advance_to_stage="Update").
- [x] Read `src/hamiltonian/interactions/interactions.jl:447-459` directly (CONFIRMED line 456 `arg >= 0.0 ? arg^(5/2) : 0.0` silently truncates; docstring at line 444 says "Throws DomainError" but code does not throw — likely-bug or stale docstring).
- [x] Read `src/hamiltonian/interactions/lhy/dispatch.jl` lines 60-90 (scalar two-channel path calls Q5 directly; F=1 c1=0 → only Q5 term contributes).
- [x] Read `src/rotating_basis/workspace.jl:28` location grep (`Q5 = lima_pelster_Q5(ε_dd)` — same function used in rotating_basis path).
- [x] Memory `yan_li_saito_2026_barnett_paper.md` — paper Eq 1 verbatim, χ(ε_dd) prescription, memory line 114 PRE-FLAGGED the ε_dd>1 imaginary-part failure mode.
- [x] Memory `feedback_manuscript_is_not_the_essence.md` (real bug-finding IS the essence; framework-gap discovery is Tier-1+ science finding).
- [x] Memory `loop_scheduler_2026_05_15.md` (scheduler authority; critic is text-only workload).
- [x] investigation_id `yan-li-saito-2026-reproduction` valid in state.investigations.
- [x] stage_advancing_to=Update is the next stage per verify-claim flow §F1 when last verdict is REFUTED (T37 substantively FALSIFIED, judge null-artifact non-substantive).
- [x] subagent_type=critic matches §F1 Update row "critic (mandatory; independent context)".
- [x] success_criteria are machine-evaluable: 6 criteria, mix of boolean (`==`) and string-membership (`in` — flagged as potentially-judge-buggy per turn 37 director §6.10, with boolean backup `candidate_ranking_present` to compensate).
- [x] failure_modes cover 6 scenarios: operational (audit not emitted), CORROBORATED-FRAMEWORK-GAP + fix-bug, CORROBORATED-FRAMEWORK-GAP + Hypothesize, NEEDS-FURTHER-DISCRIMINATION, HYPOTHESIS-OVER-REACHED, critic-blind-confirmation (meta-anti-pattern caught).
- [x] observable_manifest precondition_check is a literal bash chain (test -f for T37 artifacts + Q5 source + grep for smoking-gun line) that exits 0 before critic invocation.
- [x] Budget 1.5M effective + 5-min wall fits within scheduler window (14 days) + cost_cap_per_turn_effective (6M).
- [x] §A6 research-first citations: Yan-Li-Saito paper Eq 1 + memory, Lima-Pelster PRA 84 041604(R) 2011, source-code line numbers, T37 sim/judge outputs, arXiv:2604.12198 (FALSIFIED-as-science-success precedent), director §F1/§G, CLAUDE.md known-limitations.
- [x] §A5 D1 PRIMARY articulated (verify published-paper benchmark uncovers production-code framework gap = Tier-1+ science finding); manuscript NOT primary.
- [x] investigation_update has 2 explicit branches (success → Hypothesize + tier 0.7, refuted → Document + tier 0.5); next_falsifier_to_test_after branches by critic Update-stage verdict.
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — yan-li-saito priority 1 with clean Update move; abandoning mid-cycle would be wasteful.
- [x] Considered switching to meta-critic-placement (priority 50): rejected per §B2 interleaving rule; meta picks up T39+ after Update closes (it has 5+ data points now — T20/T26/T33/T35/T37 — ripe but not urgent).
- [x] Considered NOOP: rejected — clear actionable Update; the smoking-gun source code is pre-identified; the critic audit is exactly the kind of independent-context high-leverage text work the loop should do.
- [x] Considered re-Execute with tweaked config (different seed, larger box): rejected — no corroborated diagnostic yet; per §A5 D2 requires named blocker; running julia_gpu without a hypothesis-driven change wastes ~3M effective.
- [x] Considered skipping Update and going straight to Hypothesize revision: rejected — §F1 makes critic Update mandatory after REFUTED; the whole point of meta-critic-placement-2026-05-17 hypothesis is that critic-after-Execute is the discipline that catches framework-gap kind of issues.
- [x] Considered Document (closing investigation): rejected — Document is the LAST stage; we have at least one Hypothesize-Design-Execute cycle ahead before the negative result can be characterized.
- [x] Treated T37 substantive verdict as REFUTED despite judge INCONCLUSIVE: justified by 8/9 PASSed criteria, f1_falsified=true boolean flag, energy_mu_final null being a NaN-vs-null JSON serialization artifact (T37 §10 cost_report verified the ITP didn't crash — μ estimator returned NaN, not the integrator).
- [x] `consumed_seed_md: false` — same investigation, not a new seed entry.
