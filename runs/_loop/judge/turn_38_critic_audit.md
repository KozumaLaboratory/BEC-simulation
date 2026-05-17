---
turn: 38
subagent: critic
dispatch: directive-route-critic (director §F1 Update-stage Cross-check)
returned: text-only (critic system prompt override; no separate runs/_loop/critic/turn_38.md file written)
verdict: PASS
update_stage_verdict: NEEDS-FURTHER-DISCRIMINATION
next_stage_recommendation: Design
---

# T38 Critic Audit — yan-li-saito-2026-reproduction Update Stage

## Independent Cross-check Audit Summary

**Investigation:** yan-li-saito-2026-reproduction
**Audit target:** T37 sim report F1 falsifier verdict (n_max = 0.99 D_0 vs paper 13000 D_0)
**Stance:** REFUTED is the science success; my job is to surface the framework gap with citation-grounded rigor, NOT rubber-stamp the implementer's Q1 prior.

### §1 Independent context summary

T37 Execute landed cleanly post-BUG-8 fix: GPU rotating-basis ITP ran 5000 steps in 87.9 s with norm drift 2.22e-16, ε_dd_eff = 1.1772 (within 2% of paper 1.2), γ_LHY = 12.8. The wavefunction stayed delocalized: **n_max = 0.99 D_0 vs paper Fig 1c target ~13000 D_0** (sim turn_37.md:75-83, 109). m=+F population = 0.946 (below paper's f/ρ ≃ 1 expectation, turn_37.md:120-123). μ estimator returned NaN (operationally annoying but not the physics issue). Judge T37 returned INCONCLUSIVE only because of NaN-vs-null serialization in `energy_finite`; F1 falsifier itself fired cleanly with `f1_falsified=true, f1_deviation_pct_vs_paper=99.99`.

The question driving Update: **which framework gap explains a factor ~13000 density deficit?** The implementer's T37 §5 ranks Q1 (Lima-Pelster Q5) > Q3 (box) > Q4 (steps) > Q2 (DDI prefactor). My job is independent re-derivation.

### §2 Re-derivation of paper Eq 1 vs SpinorBEC.jl

Paper Eq 1 (memory line 38-50, verbatim):
- `E_LHY = (2/5)(32/3√π)(4πℏ²/M) a_s^(5/2) χ(ε_dd) ∫ρ^(5/2)`
- `χ(ε_dd) = Re ∫₀^π sinθ [1 + ε_dd(3cos²θ - 1)]^(5/2) / 2 dθ`

SpinorBEC.jl path (rotating_basis, `src/rotating_basis/workspace.jl:14-31`):
- `γ_LHY = (128√π/3) · (a_s/a_ho)^(5/2) · N^(3/2) · Q5(ε_dd)`
- where `Q5 = ∫₀^π (sinθ/2)[1 + ε_dd(3cos²θ - 1)]^(5/2) dθ` (interactions.jl:436-440)

**Prefactor cross-check (algebra):** Paper µ_LHY from differentiating E_LHY w.r.t. ρ at peak: `µ_LHY ∝ (5/2)·a_s^(5/2)·χ·ρ^(3/2)`. Combining `(2/5)·(32/3√π)·(4π) = 256√π/15`, then µ-derivative gives factor (5/2): `(5/2)·(256√π/15) = 128√π/3`. **Prefactor matches paper Eq 1 algebraically.** Q5 vs χ are the same integral.

**DDI prefactor (Q2):** T37 reports `c_dd = 6.392e+02` and `ε_dd_eff = a_dd/a_s = 1.1772` — the latter matches paper 1.2 to 2%, which is **strong evidence Q2 is NOT broken** (a factor-of-2 or 4π error in c_dd would propagate to ε_dd via a_dd ∝ c_dd, breaking the 1.1772 match). **Q2 RULED OUT.**

**Q1 deep dive — the silent truncation at interactions.jl:456:**

```julia
arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
s += weights[i] * sin(theta) / 2.0 * (arg >= 0.0 ? arg^(5 / 2) : 0.0)
```

The docstring (line 444) says "Throws DomainError if the integrand becomes negative" — **the code does not throw, it silently zeros.** Docstring-vs-implementation mismatch is itself a bug worth noting.

For ε_dd=1.2: `arg = -0.2 + 3.6 cos²θ`. Roots at cos²θ = 1/18, i.e. θ_c ≈ 76.37° and 103.63°. The integrand is negative for θ ∈ (76.37°, 103.63°). Current code drops this region entirely.

**Is truncate-to-zero equivalent to `Re[(...)^{5/2}]` under principal branch?** Yes. For (-x)^(5/2) with x>0 under principal branch, `(-x)^(5/2) = x^(5/2)·e^{i·5π/2} = x^(5/2)·i` → `Re = 0`. So the truncate-to-zero code IS the principal-branch Re prescription.

**BUT** — Lima-Pelster 2011 may use a different prescription (BdG zero-point analytic continuation that gives `Re[(-x)^{5/2}] = -x^{5/2}` sign flip). I cannot find a local copy of Lima-Pelster PRA 84, 041604(R) (2011) on disk to verify the canonical prescription verbatim.

### §3 Candidate cause ranking (independent re-rank, DISAGREEING with implementer)

| Rank | Cause | Mechanism | Evidence FOR | Evidence AGAINST | Likelihood |
|---|---|---|---|---|---|
| **#1** | **Q5 (Gaussian seed basin)** | init_sigma=2.0 gives σ ≈ 2 a_ho cloud. Paper's droplet radius L_0/a_ho ≈ 14. Seed is **7× smaller** than target droplet. ITP spreads it (delocalization is the kinetic-energy-minimum free-space limit). | T37 §7 #5: n_max_dimless = 3.32e-4 vs expected ~450 — "essentially flat at a very low value with most probability at the box boundary". This is the **signature of free-space delocalization from a too-narrow seed**, NOT of LHY-too-weak (which would show partial collapse before stalling). | If Q5 is the problem, switching seed wouldn't help unless Q1 also rules out. | **HIGH** |
| **#2** | **Q1 (Lima-Pelster Q5 branch prescription)** | Truncate-to-zero at interactions.jl:456 may differ from Lima-Pelster 2011 prescription. If LP uses Re of analytically-continued (-x)^{5/2} = -x^{5/2}, Q5(1.2) much smaller than 12.8 (possibly negative). | Code docstring/implementation mismatch (line 444 vs 456). Memory line 114 pre-flagged this. | A wrong Q5 would still produce *some* density profile (LHY would balance at wrong density), not 1.35e6× delocalization. | **MEDIUM** |
| **#3** | **Q6 NEW: free-space ITP seed-basin coupling** | T37 box=28 a_ho, droplet radius=14 a_ho → only 2 droplet radii of box. Gaussian seed σ=2 — basin disconnected from droplet basin. | n_max 1.35e6× below uniform-fill = free-particle ITP behavior with finite box. | Partially overlapping with Q5. | **HIGH (coupled to Q5)** |
| #4 | Q3 (box too small) | Boundary leakage. | T37 §5 ranking. | Factor-13000 is too big for boundary effect alone. | LOW |
| #5 | Q4 (n_steps=5000 insufficient) | dt=0.005, total ITP time = 25 ω⁻¹. | None — `conv=true` from norm check. | Partial collapse would show. T37 shows zero. | LOW |
| - | Q2 (DDI prefactor) | — | None. | ε_dd_eff=1.1772 matching paper 1.2 within 2%. | RULED OUT |

**Disagreement with implementer's T37 §5 ranking:** the implementer ranks Q1 HIGH and Q5 MEDIUM. **I invert this:** Q5 (seed basin) is HIGH and Q1 is MEDIUM. Justification: "completely delocalized, n_max 1.35e6× below uniform-fill" is the **textbook signature of free-particle ITP** with oversized box and undersized seed, NOT "LHY too weak" (which would show partial collapse stalling at wrong density).

### §4 Recommended next experiment

**PRIMARY — Option C (alternate ε_dd, sub-critical):** Re-run T37 with ε_dd ∈ {0.95, 0.99}. If still delocalizes → Q1 RULED OUT, Q5 confirmed. If droplet forms → Q1 elevated to HIGH and we have a clean discriminator. **Cost:** ~88 s × 2 ITP runs. **Diagnostic power:** decisively separates Q1 from Q5+Q6.

**PARALLEL CHEAP — Option B (sympy Q5 verification):** Compute χ(1.2) symbolically under (a) truncate-to-zero principal branch and (b) Lima-Pelster real-part-of-analytically-continued prescription. Compare against lima_pelster_Q5(1.2)=12.8. **Cost:** ~5 minutes implementer_sympy dispatch.

**Option A (code patch + predict):** Lowest priority. Premature without first knowing whether Q1 is even the culprit.

### §5 Update-stage verdict

**Classification: NEEDS-FURTHER-DISCRIMINATION.**

Two candidates (Q1 Lima-Pelster prescription, Q5 Gaussian seed basin) are both consistent with T37; data does not decisively select. Closing on Q1 without first running Option C risks fixing a non-bug.

**Recommended next stage for T39 director: Design** (discriminating experiment per Option C). Design a new ε_dd-sweep falsifier at ε_dd ∈ {0.95, 0.99, 1.05, 1.20}, measure n_max:
- **If Q1 dominant:** sub-critical points form droplets cleanly; super-critical fail.
- **If Q5 dominant:** all four points equally fail with Gaussian σ=2 seed.
- **If both broken:** sub-critical partially localize but to wrong density.

**Secondary recommendation (parallel, cheap):** Spawn `implementer_sympy` to compute χ(1.2) under {principal-branch-Re, LP-2011-analytic-continuation, truncate-zero} prescriptions.

**DO NOT close the investigation.** First Update; cycle continues. Tier remains 0.6.

**Additional findings:**
1. Docstring-vs-implementation bug at interactions.jl:444 vs 456 (low-priority follow-up).
2. F4 framework gap remains: rotating_basis path has no E_kin/E_s/E_ddi/E_lhy decomposition saved to JLD2. Spawn separate fix-bug regardless of Q1/Q5 outcome.
3. μ estimator NaN (BUG-9) at integrators.jl:131 — operationally annoying but not load-bearing.

### §6 Cost report

Text-only critic, no julia/sympy. Wall time ≈ 6 minutes. Effective tokens ~80k (well under 2M target). Reported usage: total_tokens=66219, tool_uses=8, duration=152.6 s.

### §7 Self-review

- [x] Cited paper Eq 1 verbatim (via memory line 38-50; /tmp PDF read was permission-denied) — flagged unavailability.
- [x] Cited specific source-code line numbers (interactions.jl:444 vs 456, dispatch.jl:60-90, workspace.jl:14-31, integrators.jl:131).
- [x] Independently re-ranked candidates and **explicitly disagreed** with implementer T37 §5 (inverted Q5 vs Q1 priority).
- [x] Proposed Option C as falsifier-targeted next experiment.
- [x] Classified Update-stage verdict: NEEDS-FURTHER-DISCRIMINATION.
- [x] Avoided modifying src/, config.yaml, state.json.

VERDICT: PASS
