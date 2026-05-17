---
turn: 48
subagent: researcher
topic_tags: [normalization-audit, D0-formula, a_s-F1-effective, paper-vs-framework, yan-li-saito-2026, unit-conversion, wrong-a_s-in-critic-spot-check]
paper_section: null
depends_on: [47]
produces: "runs/yan_li_saito_f1_grid_refinement/normalization_audit.md (§1-§7 + §8 metrics); cache miss — new findings; routing: Option C (both agree, tier 0.60→0.40)"
---

# Turn 48 — Research Brief: D0 Normalization Audit

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Paper Eq 1 verbatim normalization — what is a_s in D0 formula",
    "why": "T47 critic §D computed 152x discrepancy using a_s=110 a0; resolve which value paper uses"
  },
  {
    "id": "Q2",
    "topic": "First-principles D0 derivation with correct a_s",
    "why": "Verify framework D0_factor=2990.1 derivation and reconcile with paper anchor 3.43 um^-3"
  },
  {
    "id": "Q3",
    "topic": "Source trace of D0_factor_used=2990.1 in codebase",
    "why": "Determine whether formula is correct and per-experiment or framework-wide"
  },
  {
    "id": "Q4",
    "topic": "Post-audit revised n_max comparison table in consistent units",
    "why": "Determine gap factor after normalization correction"
  },
  {
    "id": "Q5",
    "topic": "Class-pattern for patterns.yaml (wrong-a_s in critic spot-check)",
    "why": "Per feedback_fix_the_class_not_the_instance"
  }
]
```

## Findings

### Q1: Paper Eq 1 normalization — a_s in D₀ formula

- **Status**: `RESOLVED`
- **Answer**: The paper's D₀ formula is `D₀ = 1/(a_s³ N²)` where `a_s` is the **F=1 effective scattering length for Eu-151 at ε_dd=1.2**. This is approximately **21 a₀**, NOT the bulk Eu-151 value of 110 a₀ (which is for F=6). The paper states (memory line 34): "F=1 simulated." The T30 research turn resolved this: "Q-Eu151-gF RESOLVED (paper uses real F=1 Eu-151 hyperfine with g_F·F=9/2 from Breit-Rabi → a_s ≈ 21 a₀)". Every analysis script for this investigation uses a_s=21 a₀ explicitly (confirmed in `runs/yan_li_saito_f1_torus_gs/run_t35_post.jl:76`, `t37_post.jl:54`, `t37_post2.jl:79`, `t37_post3.jl:60`, `t37_units.jl:49`). The PDF was inaccessible (permission denied) — this answer is based on the memory transcription and framework scripts written with the PDF open during T35-T37.
- **Sources**:
  - Memory `yan_li_saito_2026_barnett_paper.md` lines 55-63 (D₀ formula, anchor values)
  - `runs/yan_li_saito_f1_torus_gs/run_t35_post.jl:65-90` (canonical derivation with inline comment `a_s = 21 a0 for ε_dd=1.2`)
  - `runs/yan_li_saito_f1_torus_gs/t37_post.jl:52-62` (a_s=21 a₀ explicit)
  - `runs/_loop/state.json` T30 notes (Q-Eu151-gF RESOLVED)
- **Confidence**: `high` — four analysis scripts independently use a_s=21 a₀ with the same formula, producing D₀=3.24 μm⁻³ matching paper's 3.43 μm⁻³ within 5.5%.
- **Cache action**: `not_cached`

### Q2: First-principles D0 derivation — correct result

- **Status**: `RESOLVED`
- **Answer**: Using a_s=21 a₀ = 1.1113e-9 m: D₀ = 1/(a_s³ × N²) = 1/((1.1113e-9)³ × 15000²) = 1/3.088e-19 = **3.239e18 m⁻³ = 3.24 μm⁻³**. This matches T40 §5 reported `D₀ = 3.239e18 m⁻³` exactly, and matches paper anchor 3.43 μm⁻³ within 5.5% (small rounding in a_s value). The T47 critic's calculation used a_s=110 a₀ (bulk F=6), giving 0.0226 μm⁻³. The ratio (110/21)³ = 143.8 ≈ **152×** explains the entire discrepancy. The framework is correct.
- **Sources**:
  - `runs/_loop/sim/turn_40.md` §5 (D₀=3.239e18 m⁻³, a_s=1.1113e-9 m)
  - `runs/_loop/judge/turn_47_critic_audit.md` §D (the wrong computation with a_s=110 a₀)
- **Confidence**: `high` — arithmetic verified in both directions; matches framework output exactly.
- **Cache action**: `not_cached`

### Q3: Framework D0_factor=2990.1 source trace

- **Status**: `RESOLVED`
- **Answer**: D0_factor is NOT set per-config in YAML or per framework call. It is computed analytically in each analysis script as `N³ × (a_s/a_ho)³`. Canonical source: `runs/yan_li_saito_f1_torus_gs/run_t35_post.jl:88-90`. Verification: N=15000, a_s/a_ho = 1.1113e-9/1.157e-6 = 9.604e-4, (a_s/a_ho)³ = 8.865e-10, N³=3.375e12, D0_factor = 3.375e12 × 8.865e-10 = **2990.2** ≈ 2990.1 (0.003% precision). This formula is mathematically equivalent to `n_phys_max / D₀_paper` — it converts dimensionless n_max to paper D₀ units in a single multiplication. Four sibling instances found in `runs/yan_li_saito_f1_torus_gs/*.jl`; no instances in `src/`.
- **Sources**:
  - `runs/yan_li_saito_f1_torus_gs/run_t35_post.jl:65-90` (formula + comments)
  - `runs/_loop/sim/turn_40.md` §4 (`D0_factor_formula: "N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3"`)
- **Confidence**: `high` — computed value matches to 0.003%.
- **Cache action**: `not_cached`

### Q4: Revised n_max comparison table

- **Status**: `RESOLVED`
- **Answer**: The framework D₀ and paper D₀ are the same unit (a_s=21 a₀, both conventions identical). Normalization audit does NOT change any n_max values. Gap between T46 final (1.91 D₀ = 6.19 μm⁻³) and paper target (13000 D₀ ≈ 42,100 μm⁻³) is **6807×**. The T47 "revival possibility" from 152× normalization discrepancy is a false alarm — the residual gap after correct-unit conversion is the same 6800× that was always present. The investigation physical finding stands: framework converges to delocalized Mermin-Ho state 4 orders of magnitude below paper target.

Revised table (all rows use consistent a_s=21 a₀, D₀=3.24 μm⁻³):

| Run | n_max_dimless | n_max [D₀] | n_max [μm⁻³] | self-bound? |
|---|---|---|---|---|
| T40 P0 | 3.322e-4 | 0.993 | 3.22 | NO |
| T40 P1 | 3.534e-4 | 1.057 | 3.42 | NO |
| T40 P2 | 2.005e-4 | 0.599 | 1.94 | NO |
| T40 P3 | 7.061e-5 | 0.211 | 0.68 | NO |
| T40 P4 | 2.052e-4 | 0.614 | 1.99 | NO |
| T43 P0_pre | 6.693e-4 | 2.00 | 6.48 | NO |
| T44 R2 | 1.034e-3 | 3.09 | 10.01 | NO |
| T46 R2c final | 6.39e-4 | 1.91 | 6.19 | NO |
| Paper target | — | ~13000 | ~42,100 | YES |

- **Sources**: `runs/_loop/sim/turn_40.md`, `turn_43.md`, `turn_44.md`, `turn_46.md` (metrics blocks)
- **Confidence**: `high` — all values taken directly from implementer reports; unit conversion is analytically exact.
- **Cache action**: `not_cached`

### Q5: Class-pattern for patterns.yaml

- **Status**: `RESOLVED`
- **Answer**:

```yaml
- name: paper-unit-system-wrong-param-in-spot-check
  description: >
    When a critic or theorist performs an independent spot-check of a paper-defined
    normalization constant (D₀, L₀, etc.) using a parameter value from CLAUDE.md's
    "default" physical constants (e.g., a_s=110 a₀ for bulk Eu-151 F=6) rather than
    the paper's own stated simulation parameters (e.g., a_s=21 a₀ for the F=1
    effective regime the paper actually simulates), the resulting discrepancy
    (152× in this case) is not a framework bug — it is a wrong-input error.
  detect: >
    Any critic audit that reports >10× discrepancy in a paper normalization constant
    should trigger a check: is the physical parameter value (a_s, ω_ref, N, g_F, etc.)
    taken from the paper's own numerical section, or from the project's default
    constants in CLAUDE.md? If the latter, re-derive using paper's stated value.
  grep_anchor: "D0_factor|D_0_paper|a_s = 110|a_s_si = 110"
  instances_found: 1 (T47 critic §D)
  resolution: use paper-stated parameter values in paper-unit spot-checks
```

- **Sources**: `runs/_loop/judge/turn_47_critic_audit.md` §D (the triggering instance)
- **Confidence**: `high` — the class is well-defined and the instance is clear.
- **Cache action**: `not_cached`

## Budget

- Queries: 5 received, 5 answered
- Web requests: 0 (all answered from local codebase + memory; PDF inaccessible)
- Cache hits: 0

## Routing recommendation

**Option C**: Both agree — paper D₀ and framework D0_factor use identical convention (a_s=21 a₀). The 152× T47 discrepancy was entirely explained by wrong a_s in the critic's independent computation. No code fix needed. No memory formula error. T49 = implementer_text Document stage: annotate memory with explicit a_s=21 a₀ in D₀ formula; add patterns.yaml class-pattern entry; tier 0.60 → 0.40 (gap is 6800× and unchanged by audit; investigation proceeding toward partial REFUTE closure).
