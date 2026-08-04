# Paper #4 Reframing: From "TWA Quantum Fluctuation" to "Chaotic Dipolar Instability"

> **FROZEN 2026-05-08.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status**: Round 5 GPU 結果 (16³ box=10 pinned 1/N) で σ/μ scaling が 1/√N 完全破綻、
TWA leading-order quantum fluctuation interpretation 否定。Paper #4 候補を 
**Chaotic Dipolar Instability study** として reframing。

---

## 1. New Paper Title

**Old**: "Quantum fluctuation effects in F=6 dipolar spinor BEC: predictions and 
experimental signatures"

**New**: 
> **"Chaotic dipolar instability in post-quench F=6 spinor BEC: trajectory 
> divergence and species universality"**

(Or alternative: "Lyapunov-bounded trajectory dispersion in post-quench F=6 dipolar 
BEC: TWA characterization across Cr, Eu, Er, Dy")

---

## 2. Core Findings (Reframed)

### Finding 1: Mean-field Eu post-quench dynamics

(Unchanged from original) GP-LHY deterministic evolution shows multi-clump azimuthal 
pattern with z-elongation FWHM ratio 1:6, on-axis density depletion, species universality 
across Cr/Eu/Er/Dy ε_dd values.

### Finding 2: TWA leading-order ensemble averaging — chaos signature

50-trajectory TWA ensemble shows σ/μ ≈ 0.4-0.8 spread, **NOT consistent with 1/√N 
quantum fluctuation scaling**. Three independent evidences:
1. Resolution-matched 16³ × box=10 reproduces 32³ σ/μ = 0.42 (Sinatra-independent)
2. Sinatra-clean N=10⁵ shows σ/μ = 0.82 (LARGER, opposite of QF prediction)
3. σ/μ × √N grows 17.7 → 41.5 → 259 (1/√N TWA scaling fully broken)

### Finding 3: Lyapunov-like Chaotic Dynamics Origin

Real physical origin: dipolar instability is chaotic. Wigner sampling generates 
small initial seed differences; dipolar dynamics amplifies these exponentially via 
$\delta\zeta(t) \sim e^{\Lambda t} \delta\zeta(0)$ with positive Lyapunov exponent 
$\Lambda$. Trajectories diverge to different filament orientations → ensemble 
spread is **physics-amplitude bounded** (chaos saturation), not noise-amplitude 
bounded (1/√N).

### Finding 4: Chaos-onset diagnostic across species

| Species | ε_dd | σ/μ | Interpretation |
|---|---|---|---|
| Cr | 0.15 | 0.001 | sub-instability, no chaos |
| Eu | 0.55 | **0.423** | **chaos onset, most active** |
| Er | 0.88 | 0.127 | chaos saturated, quasi-deterministic |
| Dy | 1.39 | 0.049 | full collapse, no spatial structure |

→ **σ/μ peak at Eu = chaos most-active regime**. Chaos diagnostic for dipolar 
instability across species.

### Finding 5: TWA Methodology Boundary

TWA leading-order **cannot quantitatively extract quantum fluctuation magnitude** in 
this regime. It is a **chaos diagnostic tool**, not a quantum fluctuation tool. True 
quantum fluctuation evaluation requires TDHFB / Beliaev (deferred to follow-up work).

---

## 3. Paper Structure (Outline)

### Section I: Introduction

- Spinor dipolar BEC post-quench dynamics
- Eu BEC realization (Miyazawa 2022) and unique properties
- TWA approach for ensemble dynamics
- Earlier expectation: quantum fluctuation evaluation via TWA leading-order
- This paper: Discovery that TWA captures chaos, not QF

### Section II: SpinorBEC.jl + TWA Framework

- F=6 spinor structure
- TWA implementation: Wigner sampling, ensemble evolution
- Welford accumulator for moment statistics
- Validation against scalar / F=1 BEC TWA literature

### Section III: Mean-field GP-LHY Baseline

- Deterministic post-quench dynamics
- Multi-clump azimuthal pattern formation
- z-elongation, on-axis depletion characterization
- Species comparison (ε_dd dependence)

### Section IV: TWA Ensemble Results

- 50-trajectory ensemble for Eu baseline (N=10⁴)
- σ/μ ≈ 0.42 at peak, on-axis 0.092 → 0.416
- Initial interpretation: "quantum fluctuation enhancement"

### Section V: Three Evidences against Quantum Fluctuation Origin

- Resolution-matched Sinatra-clean test
- N-scaling test (σ/μ × √N growing, not constant)
- Cross-species chaos correlation

### Section VI: Chaotic Dipolar Instability Mechanism

- Dipolar interaction non-linearity → Lyapunov-like instability
- Trajectory divergence in filament orientation space
- Physics-amplitude bounded vs noise-amplitude bounded
- Connection to classical chaos in continuous fluid systems

### Section VII: Implications for Spinor BEC Methodology

- TWA validity boundary identification
- Distinction: chaos diagnostic vs QF quantification
- Roadmap for true QF evaluation: TDHFB / Beliaev
- Saito-Li 2024 LHY-only insufficient + chaos = complementary

### Section VIII: Experimental Signatures and Predictions

- σ/μ ≈ 0.4 expected in 上妻研 Eu BEC shot-to-shot ensemble
- Cross-species predictions (Cr, Er, Dy comparison)
- Resolution requirements for filament observation
- Detection protocol for chaos signature

### Section IX: Conclusion

- First clean numerical identification of chaotic dipolar instability in spinor BEC
- Chaos-onset diagnostic across dipolar species
- TWA methodology refinement
- Path to TDHFB / Beliaev

---

## 4. Target Journal

**Primary**: PRR (Physical Review Research) — comprehensive numerical study with 
methodology refinement
**Alternative**: PRA (Physical Review A) — focused chaotic dynamics characterization
**Stretch**: Nature Communications — if connection to chaos / complexity in BEC 
ecosystem can be highlighted (probably too specialized)

---

## 5. Comparison to Original Paper #4 Plan

| Aspect | Original | New |
|---|---|---|
| Title | "Quantum fluctuation effects" | "Chaotic dipolar instability" |
| Core physics | TWA QF prediction | Lyapunov-bounded trajectory dispersion |
| Species coverage | Eu only | Cr, Eu, Er, Dy comparison |
| Methodology claim | TWA QF evaluation | TWA chaos diagnostic |
| Experimental tie | 上妻研 QF detection | 上妻研 chaos signature detection |
| Future work | Already addressed by TWA | TDHFB / Beliaev for true QF |
| Submission target | PRR | PRR / PRA |

---

## 6. Strategic Value

1. **Negative → Positive**: TWA QF claim invalidation became positive physics 
   discovery (chaos)

2. **Species universality**: ε_dd species scan provides clean cross-species 
   data, strengthens generality

3. **Methodology refinement**: TWA validity boundary clearly delineated, 
   community benefit

4. **D 論 path established**: TDHFB / Beliaev as natural follow-up

5. **修論 Ch.5 self-consistent**: Chaotic dynamics framing replaces QF 
   framing, cleaner narrative

6. **Saito-Li 2024 complementarity**: 
   - Saito-Li: LHY-only insufficient for Eu droplet
   - This work: chaos = additional dynamics layer, also relevant for Eu

---

## 7. Action Items

### Immediate (Paper #4 draft preparation)

1. Outline draft (above) — refine into full paper structure
2. Existing GPU data review:
   - 32³ N scan results (Section III, IV)
   - 32³ ε_dd species scan (Section III, IV)
   - 16³ pinned 1/N (Section V)
3. Schematic figures: Lyapunov mechanism (Section VI), chaos onset diagnostic (Section IV/V)

### Coordination

1. 上妻研実験 collaboration: σ/μ measurement protocol shared
2. Saito-Li 2024 polar Eu droplet (Task 4 deferred): now important 
   complementary reference
3. Anko Kozuma Lab shared data review

### After Paper #4 submission

1. TDHFB framework development (D 論 Ch.3)
2. Beliaev decay implementation
3. Higher-order TWA (1/N²) corrections

---

## 8. Updated Papers Portfolio

| Paper | Status | Target | Notes |
|---|---|---|---|
| #1 F=2 cyclic LHY | ✅ submission ready | PRA | Mean-field theoretical |
| #2 F=6 icosahedral LHY | ✅ submission ready | PRA / PRR | Mean-field theoretical |
| #3 Universal Theorem v3 | ✅ submission ready | PRX | 6 polyhedral cases + sign pattern |
| **#4 Chaotic dipolar instability** | **🔧 reframing** | **PRR / PRA** | **GPU work complete, draft pending** |

修論期間内 4 papers submission realistic (1-3 確実、4 reframing 後)。

---

## End of Paper #4 Reframing Document
