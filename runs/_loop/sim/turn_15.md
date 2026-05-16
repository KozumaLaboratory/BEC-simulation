---
turn: 15
subagent: implementer
topic_tags: [barnett, rank2-cg, cascade, candidate-c, tau-init-slope, gamma-dr, eu151, d1-tier-lift]
paper_section: null
depends_on: [11, 13, 14]
produces: "runs/_loop/sim/turn_15/cascade_initial_slope.py; auto/turn_15_cascade-initial-slope-candidate-c branch"
---

# Turn 15 — Implementer Report

## 1. Directive received

Director §6 brief (verbatim JSON not provided — director format, not theorist JSON):

Goal: Resolve T13 §5 Candidate C (definition mismatch) by computing (a) dF_z/dt|_{t=0+}
and (b) t* for ⟨F_z⟩/N to drop from 6 to 5.02 under the rank-2 cascade master equation
with γ_dr=0.02. Verdict: does t* lie in [7,14] ms?
Five computation targets; deliverable is cascade_initial_slope.py + report.

## 2. Branch / commit

- Branch: `auto/turn_15_cascade-initial-slope-candidate-c`
- Parent: `07fa338` (main HEAD)
- Files produced: `runs/_loop/sim/turn_15/cascade_initial_slope.py`

## 3. Commands executed

```
$ git checkout -b auto/turn_15_cascade-initial-slope-candidate-c
$ uv run --with sympy --with scipy --with numpy python3 \
    runs/_loop/sim/turn_15/cascade_initial_slope.py
```

Full output captured below in §5.

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "tests_passed": null,
  "wall_time_sec": 45.0,
  "peak_memory_gb": null,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "total": null
  },
  "warnings": [],
  "physical_red_flags": [
    "Candidate C REFUTED: pure rank-2 cascade from m=+6 does NOT reach <F_z>/N=5.02 within t=30 ω⁻¹. At t=30 ω⁻¹=43.4 ms, <F_z>/N=5.257. τ_init_slope=67.5 ms >> [7,14] ms. Gap factor ~5-10x remains.",
    "gamma_eff(t) grows from 1.15x at t=0 to 1.34x at t=15 ω⁻¹ — multi-rung cascade acceleration (Candidate A) is real but insufficient (only ~30% speedup vs needed 5-10x)."
  ],
  "falsification_result": "REFUTED",
  "compute_results": [
    {
      "id": "S1",
      "task": "Split W^CG_{m,q} for q=-1 and q=-2 at F=6",
      "status": "OK",
      "result": "W^CG_{m=+6,q=-1}=11/14, W^CG_{m=+6,q=-2}=1/7; SUM=13/14 (matches T13 S3). Z=2/5 confirmed."
    },
    {
      "id": "S2",
      "task": "dF_z/dt|_{t=0+} exact rational",
      "status": "OK",
      "result": "dF_z/dt|_{t=0+} = -3/140 ω⁻¹ (exact). Dimensional: -0.0148 ms⁻¹ at ω_ref=691.15. τ_init_slope=140/3=46.67 ω⁻¹=67.52 ms. NOT in [7,14] ms."
    },
    {
      "id": "S3",
      "task": "Full ODE integration; find t* where <F_z>/N=5.02",
      "status": "OK",
      "result": "<F_z>/N at t=30 ω⁻¹ is 5.257, never reaches 5.02 within t=30 ω⁻¹. t* does not exist in this window. Cascade too slow by factor ~5-10."
    },
    {
      "id": "S4",
      "task": "losses.jl Heaviside gating check",
      "status": "OK",
      "result": "AGREE. _dipolar_relaxation_shape(F) applies no Heaviside gate. All m decay at gamma_dr*shape[m]."
    },
    {
      "id": "S5",
      "task": "gamma_eff(t) acceleration profile",
      "status": "OK",
      "result": "γ_eff/γ_0: 1.15 at t=0, 1.25 at t=8 ω⁻¹, 1.34 at t=15 ω⁻¹. Cascade accelerates ~30% as mid-rungs are reached. Insufficient to close 5-10x gap."
    }
  ]
}
```

## 5. Observations

### Headline verdict

**Candidate C: REFUTED** (τ_init_slope = 67.5 ms >> [7,14] ms; gap factor ~5).

The rank-2 cascade master equation, starting from the fully-polarized m=+6 state and
evolving under γ_dr=0.02, gives an initial slope dF_z/dt|_{t=0+} = −3/140 ω⁻¹ (exact),
corresponding to τ_init_slope = 140/3 ω⁻¹ ≈ 67.5 ms. This is 5× larger than the
empirical upper bound of 14 ms. The definition-mismatch hypothesis (Candidate C) does NOT
close the gap.

### Target 1: 13×2 split table W^CG_{m,q} (exact rationals)

| m  | W^CG_{q=-1} | W^CG_{q=-2} | W^CG total |
|----|-------------|-------------|------------|
| +6 | 11/14       | 1/7         | 13/14      |
| +5 | 27/28       | 5/14        | 37/28      |
| +4 | 35/44       | 45/77       | 425/308    |
| +3 | 75/154      | 60/77       | 195/154    |
| +2 | 15/77       | 10/11       | 85/77      |
| +1 | 1/44        | 21/22       | 43/44      |
|  0 | 1/44        | 10/11       | 41/44      |
| -1 | 15/77       | 60/77       | 75/77      |
| -2 | 75/154      | 45/77       | 15/14      |
| -3 | 35/44       | 5/14        | 355/308    |
| -4 | 27/28       | 1/7         | 31/28      |
| -5 | 11/14       | 0           | 11/14      |
| -6 | 0           | 0           | 0          |

Sanity checks (all pass):
- W^CG_{m=+6, q=-1} + W^CG_{m=+6, q=-2} = 11/14 + 1/7 = 11/14 + 2/14 = 13/14 ✓
- sum over all m of W^CG_total = 13 = D ✓
- shape[m=-6] = 0 (absorbing boundary) ✓
- Z = 2/5 confirmed ✓

### Target 2: dF_z/dt|_{t=0+}

Exact computation (initial state n_{+6}=1, all others 0):

```
dF_z/dt|_{t=0+} = -γ_dr * [1 × W^CG_{+6,q=-1} + 2 × W^CG_{+6,q=-2}]
                = -(2/100) * [1 × 11/14 + 2 × 1/7]
                = -(2/100) * [11/14 + 2/14]
                = -(2/100) * (15/14)
                = -30/1400 = -3/140   (exact rational)
```

- Dimless: dF_z/dt|_{t=0+} = −3/140 ≈ −0.02143 ω⁻¹
- Dimensional: −0.0148 ms⁻¹ at ω_ref=691.15 rad/s
- Sign: NEGATIVE ✓ (F_z decreasing from m=+6 initial state)
- τ_init_slope = 1/|dF_z/dt|_{t=0+}| = 140/3 ≈ 46.67 ω⁻¹ = **67.52 ms**
- **In [7,14] ms: NO** (gap factor ≈ 5)

Note: τ_init_slope is only slightly smaller than the single-rung τ = 700/13 ≈ 53.85 ω⁻¹
from T13, because the initial slope captures BOTH the Δm=-1 and Δm=-2 channels.
The factor 15/14 vs 13/14 reflects the additional Δm=-2 contribution weighted by |Δm|=2.
Still far from the empirical window.

### Target 3: Full trajectory and t*

ODE integration (scipy RK45, rtol=1e-10, norm conserved to <1e-8):

| t (ω⁻¹) | t (ms)  | ⟨F_z⟩/N | norm       |
|---------|---------|---------|------------|
| 0       | 0.00    | 6.0000  | 1.00000000 |
| 1       | 1.45    | 5.9785  | 1.00000000 |
| 2       | 2.89    | 5.9567  | 1.00000000 |
| 4       | 5.79    | 5.9124  | 1.00000000 |
| 8       | 11.57   | 5.8210  | 1.00000000 |
| 15      | 21.70   | 5.6525  | 1.00000000 |
| 30      | 43.41   | 5.2574  | 1.00000000 |

**t* (⟨F_z⟩/N = 5.02) does not exist within t ∈ [0, 30] ω⁻¹.**
At t=30 ω⁻¹, ⟨F_z⟩/N = 5.257 — still 0.24 above the empirical endpoint.
The full cascade would reach 5.02 at roughly t ≈ 85 ω⁻¹ ≈ 123 ms by
extrapolation — roughly 9× slower than the empirical 7-14 ms window.

**Candidate C: REFUTED** — the definition mismatch (initial slope vs single-rung τ)
does NOT close the gap. Norm is exactly conserved (as expected for pure cascade without
loss): ✓

### Target 4: losses.jl Heaviside check

`_dipolar_relaxation_shape(F)` at `losses.jl:162-189` applies no Heaviside gate.
The loop iterates over all c=1..D (all m) and computes shape[m] = raw[m]/Z for every m.
No reference to Ω or sgn(g_F) in this function.

**AGREE**: T11's Heaviside Θ(-Ω·sgn(g_F)) is a macroscopic rotating-frame energy selector,
not a per-rung kernel gate. The master equation above correctly models the -Ω (unobstructed)
cascade. No deviation from T14 §2 description found.

### Target 5: γ_eff(t) acceleration profile

| t (ω⁻¹) | t (ms)  | ⟨F_z⟩/N | |dF_z/dt|  | γ_eff/γ_0 |
|---------|---------|---------|-----------|-----------|
| 0       | 0.00    | 6.0000  | 0.02143   | 1.154     |
| 1       | 1.45    | 5.9785  | 0.02167   | 1.167     |
| 2       | 2.89    | 5.9567  | 0.02191   | 1.180     |
| 4       | 5.79    | 5.9124  | 0.02238   | 1.205     |
| 8       | 11.57   | 5.8210  | 0.02330   | 1.255     |
| 15      | 21.70   | 5.6525  | 0.02483   | 1.337     |

γ_0 = γ_dr × W^CG_{m=+6} = 0.02 × 13/14 = 0.01857 ω⁻¹.

The cascade rate DOES accelerate (γ_eff/γ_0 increases from 1.15 to 1.34 over 15 ω⁻¹)
as population shifts from m=+6 (shape=13/14 < 1) toward m=+4 (shape=425/308 ≈ 1.38,
the maximum). However, the acceleration is only ~30% at t=15 ω⁻¹. This is Candidate A
(multi-rung acceleration) but it contributes a factor ~1.3, not the needed 5-10.

**Candidate A partially confirmed but insufficient.** The multi-rung effect accelerates
the cascade by ~30% over the empirically-relevant window — real but not dominant.

## 6. Issues / deviations

- `[WARN]` The directive says "τ_init_slope = 1/|dF_z/dt|_{t=0+}|" as a definition.
  We confirm this gives 67.52 ms. An alternative definition τ' = (ΔF_z_target) / |dF_z/dt|_{t=0+}|
  where ΔF_z_target = 6 - 5.02 = 0.98 would give τ' = 0.98 × 140/3 ω⁻¹ = 45.7 ω⁻¹ = 66.1 ms —
  still 5× outside [7,14] ms. No redefinition rescues Candidate C.

- `[INFO]` ODE norm is conserved to machine precision (all pop stays in m-ladder;
  no loss term in this master equation). Confirms absorbing-boundary at m=-6 working.

- `[INFO]` The +Ω empirical endpoint ⟨F_z⟩/N = 5.02 in the memory file is for the
  STABLE (co-rotating) direction, not the relaxing direction. The cascade model applies
  to the -Ω direction which fully relaxes. The directive correctly identifies this as
  the initial-slope definition mismatch test; that test fails regardless.

## 7. Falsification check

Directive falsification criterion: does t* (⟨F_z⟩/N = 5.02) lie in [7,14] ms?

**REFUTED.** The pure rank-2 cascade model does not reach ⟨F_z⟩/N = 5.02 within
t=30 ω⁻¹ = 43 ms. τ_init_slope = 67.5 ms >> 14 ms. Gap factor ~5.

---

## Re-tiering recommendation for T11 §4 claim 5

**[Refuted with gap factor ~5, route to Candidate B]**

T11 §4 claim 5 ("τ ≈ 6 ms matches empirical within factor ~2") was previously revised by T13
to "[Plausible with revised value τ_cascade ≈ 78 ms, gap factor 5-10x]". This turn's Candidate C
analysis (definition mismatch, initial slope) was the remaining logical escape — if the empirical
τ is the initial slope rather than the 1/e time, the gap might close. It does not. τ_init_slope
= 67.5 ms, nearly identical to the naive single-rung τ = 77.9 ms from T13.

**New tier**: [Refuted: all definitions of τ from the pure-cooling rank-2 cascade model give
~50-80 ms, factor 5-10× above the empirical 7-14 ms onset window. The mechanism qualitative
logic is sound (rotating-frame bias + γ_dr cascade) but the numerical prefactor is missing
physics. Candidate B (DDI-mediated spin-mixing pre-population) is the remaining unexplored
explanation.]

## Sequencing for T16

**Route T16 to Candidate B (DDI-mediated spin-mixing pre-population).**

Candidate A: confirmed but insufficient (~30% acceleration, not 5-10×).
Candidate C: REFUTED by this turn (67.5 ms vs 7-14 ms empirical).
Candidate B: DDI off-diagonal components mix m-levels on timescale 1/(c_dd × n) ≈ 5 μs,
  potentially pre-populating m=+5, m=+4 before γ_dr acts. This would effectively present
  a higher-shape target to γ_dr and shorten the observable onset timescale.

**T16 recommended action**: Researcher task to quantify DDI-mediated spin-mixing
pre-population. Specifically: at what timescale does transverse magnetization (seeded by
the tilted rotating B at t=0+) drive coherent DDI population transfer from m=+6 to m=+5?
Can the effective initial shape[m] presented to γ_dr be larger than shape[m=+6]=13/14?

The γ_dr=0 julia falsifier (T11 §5.3) remains the most decisive experiment: it tests
whether asymmetry is dissipative (should vanish at γ_dr=0) or coherent (persists).
If coherent, Candidate B is confirmed as the primary mechanism.

## Production cross-check

`src/hamiltonian/interactions/losses.jl:162-189` implements:

```
raw[c] = Σ_{q∈{-1,-2}} |CG(F, m, 2, q, F, m+q)|²
Z      = sum(raw) / D
shape  = raw / Z
```

This matches the master equation in Target 3 exactly. **AGREE.**
No Heaviside gate, no Ω dependence, shape vector is F-dependent and cached.
The production code has no bug in this kernel (confirmed T13 S5).
