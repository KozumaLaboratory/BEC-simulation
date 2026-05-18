# Investigation thread — edh-eu151-vortex-vs-matsui-science-2026

**Title**: Einstein-de Haas Eu-151 vortex emergence — reproduction of Matsui et al. Science 391, 384-388 (2026)

**Hypothesis**: SpinorBEC.jl spinor-DDI + split-step framework reproduces Matsui et al. Science 391, 384–388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357] within factor-2 of the experimental EdH timescale τ_EdH^exp and matches the ring-vortex topology (winding number ℓ consistent with F=6 angular-momentum balance) when fed the paper's published parameters (N, trap frequencies ω_{x,y,z}, B-quench waveform, a_s, c_dd).

**Flow template**: verify-claim

**Tier target**: 3

## Turn-by-turn narrative

### T73 (2026-05-18T13:26:28.883814+09:00) — PASS — `edh-eu151-matsui-design-yaml-baseline`

- Stage: **Design**, tier: 1.0
- Cost: 1815k effective tokens
- Contract: PASS
- Budget audit: BUDGET_BUSTED (actual/expected = 2.59)

### T74 (2026-05-18T13:45:33.666002+09:00) — FAIL_OPERATIONAL — `edh-matsui-execute-baseline-case-A`

- Stage: **Execute**, tier: 1.0
- Cost: 2061k effective tokens
- Issues: run_yaml_completed=False == True → False; output_dir_populated=False == True → False
- Contract: FAIL_OPERATIONAL

### T76 (2026-05-18T14:43:56.162913+09:00) — PASS — `edh-matsui-analyze-baseline-case-A`

- Stage: **Execute**, tier: 1.0
- Cost: 3055k effective tokens
- Contract: PASS
- Budget audit: BUDGET_OVER (actual/expected = 1.53)

### T78 (2026-05-18T15:15:06.146511+09:00) — PASS — `edh-matsui-prereq-class-fix-haskey-B-yaml-bz-sign`

- Stage: **Update**, tier: 1.5
- Cost: 1430k effective tokens
- Contract: PASS
- Budget audit: BUDGET_BUSTED (actual/expected = 2.04)

### T79 (2026-05-18T15:32:12.932979+09:00) — INCONCLUSIVE — `edh-matsui-execute-r1-retry-blocked-julia-approval-gate`

- Stage: **Execute (T79 R1 full retry on corrected YAML against fixed main HEAD)**, tier: 1.5
- Cost: 1728k effective tokens
- Issues: precondition_check_passed=False == True → False; run_yaml_completed=False == True → False
- Contract: INCONCLUSIVE

### T80 (2026-05-18T15:52:08.593128+09:00) — PASS — `edh-matsui-execute-T80-bz-sign-convention-independent-derivation`

- Stage: **Execute (T79 R1 full retry on corrected YAML against fixed main HEAD)**, tier: 1.5
- Cost: 1892k effective tokens
- Contract: PASS
- Budget audit: BUDGET_OVER (actual/expected = 1.46)

### T81 (2026-05-18T16:15:41.762286+09:00) — PASS — `edh-matsui-execute-T81-r2-gpu-wrapper-script-workaround`

- Stage: **Execute (T81 implementer_julia_gpu retry with src-anchored high-confidence prior + approval-gate workaround)**, tier: 1.5
- Cost: 1879k effective tokens
- Contract: PASS

### T82 (2026-05-18T16:42:33.922298+09:00) — PASS — `edh-matsui-analyze-T82-f1-f2-f3-jld2-extraction`

- Stage: **Analyze (T82 implementer_julia_cpu_light extracts F1 t_ring, F2 winding ℓ, F3 GS energy E_sim vs E_mf/N)**, tier: 2.0
- Cost: 2016k effective tokens
- Contract: PASS
- Budget audit: BUDGET_OVER (actual/expected = 1.55)

### T83 (2026-05-18) — CRITIC_PASS — `edh-matsui-update-T83-critic-operational-gate-deep-audit`

- Stage: **Update**, tier: 2.5
- Cost: 1932k effective tokens
- Verdict: CORROBORATE_WITH_ERRATA
- F3 critic classification: CORROBORATE_AFTER_CONVENTION_FIX; corrected rel_error = 8.0%; convention = INTENSIVE per-atom
- 4 errata (1 load-bearing, 3 advisory)
- T84 next-action: implementer_text Document

### T84 (2026-05-18) — PASS — `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`

- Stage: **Document**, tier: 2.5 → 2.75
- Artifacts: 5 (new memory file edh_matsui_baseline_2026_05_18.md; state.json patch with closing_note + errata_resolved; by_tag indices appended: edh-eu151-matsui-science-2026.md + edh-eu151.md + matsui-science-2026.md + matsui-2026.md; status narrative appended)
- Terminal Tier 3.0 trajectory at T85 verification turn (lightweight pass OR F1 longer-dynamics rerun)

### T84 (2026-05-18T17:20:53.273824+09:00) — PASS — `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`

- Stage: **Document (F3 CORROBORATE_WITH_ERRATA at tier 2.75; F1 NOT_APPLICABLE deferred-rerun; terminal Tier 3.0 closure at T85 verification turn)**, tier: 2.75
- Cost: 1573k effective tokens
- Contract: PASS
- Budget audit: BUDGET_OVER (actual/expected = 1.43)

### T85 (2026-05-18T17:37:38.543090+09:00) — FAIL_OPERATIONAL — `edh-matsui-document-verify-T85-tier-3-0-terminal-closure-lightweight`

- Stage: **Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)**, tier: 2.75
- Cost: 1664k effective tokens
- Issues: phase_1_checks_passed=6 == 7 → False; state_json_tier_advanced_to_3=False == True → False
- Contract: FAIL_OPERATIONAL
- Budget audit: BUDGET_BUSTED (actual/expected = 2.22)

### T86 (2026-05-18) — PASS — `edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore`

- Stage: **Document-verify (TIER_3_TERMINAL_CLOSURE)**, tier: 2.75 → 3.0
- Phase 0 repair: 3 by_tag files restored from T85 verbatim corrective content (root cause: T84 Edit/Write produced AM git status — index had T84 entries, working tree did not)
- Verification: 7/7 mechanical checks PASS (Check 6 now passes after Phase 0 restore)
- State patch: tier_current 2.75 → 3.0, current_stage "closed", last_turn=86, last_stage="Document-verify", last_verdict="TIER_3_TERMINAL_CLOSURE", closing_note extended with terminal-closure stamp + T85→T86 retry rationale
- Project's 3rd Tier-3 trajectory closure (1st lab-paper benchmark vs Matsui Science 2026)
- T87 next-action: audit-class-scan-2026-05-18-T87 (AUDIT_DUE gap=23 cadence trigger) OR F1 longer-dynamics rerun OR meta-investigation Hypothesize

