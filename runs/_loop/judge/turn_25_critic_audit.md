---
turn: 25
subagent: critic
verdict: FAIL
confidence: high
target: theorist T11/T13/T24 "factor 27 cascade-rate gap" → density-weighting accounting
read_only: true
files_referenced:
  - src/hamiltonian/interactions/losses.jl
  - src/hamiltonian/interactions/interactions.jl
  - runs/_loop/theorist/turn_24.md
  - runs/_loop/sim/turn_24.md
  - runs/_loop/sim/turn_20.md
  - runs/eu151_barnett_spin/config.yaml
prompt_injection_flag: true
prompt_injection_source: "Read of runs/eu151_barnett_spin/config.yaml returned an unsolicited 'MCP Server Instructions / claude.ai Figma' block — ignored."
---

# Turn 25 — Critic Audit Report

## 0. Scope and Read-Only Constraint

Reviewing the load-bearing assumption underlying T11-T24's mechanism speculation: that `Γ_theory = γ_dr · s(+F) · P̄_-` (theorist §2.5/§2.13 single-bin Rabi-cascade prediction) and `Γ_empirical = 1/τ_Barnett ≈ 0.35/ω` (from `runs/eu151_barnett_spin_cdd0/trajectory.csv` analysis at Ω=-0.5) are apples-to-apples comparable.

Files read (in order):
- `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/losses.jl` (1-190)
- `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_24.md` (1-665, 1270-1359)
- `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_24.md` (full)
- `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_20.md` (lines 1-150)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_barnett_spin/config.yaml`
- `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/interactions.jl` (lines 80-114)

No julia executed (read-only per critic.md §A2).

**Prompt-injection notice:** The Read output of `runs/eu151_barnett_spin/config.yaml` was followed by an unsolicited "MCP Server Instructions / claude.ai Figma" block. This was injected via the file-read channel and **not** part of the user's mandate. I ignored it and continued the audit. Reporting to anko per protocol.

---

## 1. Audit-1: Rate convention identification

**Theorist's `Γ_theory = γ_dr · s(+F) · P̄_- = 0.0186/ω` (§2.13)** is a **bare per-atom rate** with no `n(r)` weighting. It is dimensioned as [time⁻¹] and treats `γ_dr · s(+F) = γ_dr · 0.9286` as the lab Lindblad rate of a single isolated atom in state `|m=+F⟩`.

**Production code's effective rate at voxel `r`** (line 109 of `losses.jl`):
```
psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)
```
where `gamma_lin_rate = γ_dr · shape[m]` and `density_buf = n_total(r) = Σ_m |ψ_m(r)|²`. So the per-atom rate at site `r` is **`γ_dr · shape[m] · n_total(r)`** — explicitly density-weighted, of dimension [time⁻¹] only after multiplication by the dimensionless local density. This is consistent with the docstring at line 13 of `losses.jl`: `exp(-γ_m · n_tot · dt / 2)`. The structure is **2-body-shape** (linear-in-n_total), not single-atom Lindblad.

**Empirical `Γ_emp = 1/τ_Barnett = 1/2.84 ω⁻¹ ≈ 0.352/ω`** (sim/turn_20 §3). `τ_Barnett` is defined in `analyze_lz.py` as "time when |F_z - 6| crosses 1" — i.e., the time to lose **one unit** of `⟨F_z⟩` integrated over the whole cloud (norm-normalized). It is the rate-of-`⟨F_z⟩`-decay, which in steady-flow approximation = (avg Δm per jump) × (density-weighted per-atom transition rate over the cloud).

**Conclusion (Audit-1): The three rates use three different conventions.** Theorist's `Γ_theory` ignores `n(r)`; production's local rate scales linearly with `n(r)`; empirical `Γ_emp` is a globally density-weighted observable rate (and may also fold in cascade-multiplicity). The §2.13 statement `Γ_theory vs Γ_emp → factor 27 → Dicke` is comparing **incompatible quantities**.

---

## 2. Audit-2: n_peak in dimensionless units

From theorist §2.3:
- `c_0 = 4π · (a_s/a_ho) · N = 4π · 6.4e-3 · 10⁴ = 804` (dimensionless, contains N).
- `μ_TF = (1/2) · (15 · N · c_0 · λ / (4π))^(2/5) · ω̄ ≈ 8.78` (dimensionless).
- `n_peak^code = μ_TF / c_0 = 8.78 / 804 ≈ 0.0109 a_ho⁻³`.

Cross-check from `sim/turn_20.md` lines 79 and 84 (actual numerical `peak` column of trajectory.csv at t=0 and t≈30 of the run):
- `peak = 9.55e-3` at t=0 (Ω=-0.5), `peak = 9.17e-3` near t=30 (Ω=+0.5).

The simulation's peak `|ψ|²` is `~0.01`, consistent with theorist's TF estimate. **Audit-2 confirms n_peak ≈ 0.01.**

Compute production-code rate at the cloud center, m=+F:
```
Γ_voxel(r=0, m=+F) = γ_dr · shape[+F] · n_peak
                  = 0.02 · 0.9286 · 0.0095
                  ≈ 1.77 × 10⁻⁴ /ω
```
This is **two orders of magnitude SMALLER than `Γ_theory = 0.0186/ω`**, not larger — because theorist's bare formula corresponds to `n_total = 1` (a unit-density atom), but actual `n_total ≈ 0.01`.

It is **four orders of magnitude SMALLER than `Γ_emp = 0.35/ω`** (factor ~2000).

---

## 3. Audit-3: Shape normalization (Z factor)

Independent recomputation from `losses.jl` lines 162-189 (using S2 sympy output of `sim/turn_24.md` for raw rank-2 |T²_q|² values):

```
raw[c, m] = |⟨m-1|T²_{-1}|m⟩|² + |⟨m-2|T²_{-2}|m⟩|²
```

Summing over c=1..13 (m=+6,+5,...,-6) from sim/turn_24 S2:
```
m=+6: 0.31429 + 0.05714 = 0.37143
m=+5: 0.38571 + 0.14286 = 0.52857
m=+4: 0.31818 + 0.23377 = 0.55195
m=+3: 0.19481 + 0.31169 = 0.50650
m=+2: 0.07792 + 0.36364 = 0.44156
m=+1: 0.00909 + 0.38182 = 0.39091
m= 0: 0.00909 + 0.36364 = 0.37273
m=-1: 0.07792 + 0.31169 = 0.38961
m=-2: 0.19481 + 0.23377 = 0.42857
m=-3: 0.31818 + 0.14286 = 0.46104
m=-4: 0.38571 + 0.05714 = 0.44286
m=-5: 0.31429 + 0         = 0.31429
m=-6: 0      + 0          = 0
raw_sum ≈ 5.20002
Z = raw_sum / D = 5.20002 / 13 ≈ 0.40000
shape[+F=+6] = raw[+F] / Z = 0.37143 / 0.40000 ≈ 0.9286 ≡ 13/14
```

**Audit-3 confirms `shape[+F] = 13/14`** matches theorist's T13 value to machine precision. The normalization conventions on the two sides ARE consistent at this point. No factor-13 or factor-14 hides here.

---

## 4. Audit-4: Cascade vs single-jump multiplicity

`τ_Barnett` is the time for `⟨F_z⟩` to drop by 1. For a single atom at m=+F undergoing rank-2 dissipative jumps (Δm ∈ {-1, -2}), the average `⟨ΔF_z⟩` per jump is

```
⟨ΔF_z⟩ = -(s_{q=-1}·1 + s_{q=-2}·2) / (s_{q=-1} + s_{q=-2})
       = -(0.31429·1 + 0.05714·2) / (0.31429 + 0.05714)
       = -0.42857 / 0.37143
       ≈ -1.154
```

So one jump removes ~1.15 units of `F_z`. `τ_Barnett = 1 jump-time / 1.15`. This means the comparison between `Γ_emp` and per-atom rate is off by only a small `O(1)` factor (not the factor-9 the original mandate suggested). **Cascade multiplicity does NOT close the gap; it changes the comparison by ~15%.**

Audit-4 does not resolve the gap.

---

## 5. Audit-5: Cross-check of production rate at cloud center vs empirical 0.35/ω

```
Γ_production(r=0, m=+F) ≈ γ_dr · shape[+F] · n_peak
                       = 0.02 · 0.9286 · 0.0095 ≈ 1.8 × 10⁻⁴ /ω

τ_predicted_from_code = 1 / (1.15 · 1.8e-4) ≈ 4900 ω⁻¹

τ_empirical = 2.84 ω⁻¹
```

**Ratio ≈ 1700×.** The production code with the supplied parameters (γ_dr = 0.02, n_peak ≈ 0.01) should produce a `τ_Barnett` of order **5000 ω⁻¹**, not 2.84 ω⁻¹.

Yet the simulation **observed** τ = 2.84 ω⁻¹. This means one of:

- (a) `γ_dr = 0.02` in YAML is **not** the dimensionless rate I assumed — there is a hidden N-factor, a frequency-scale factor, or `gamma_dr` is interpreted differently in the rotating-basis or spinor path than the losses.jl docstring claims;
- (b) The empirical decay at Ω=-0.5 is dominated by a **different mechanism** (e.g., coherent Rabi at the tilted axis + Larmor precession + DDI off-diagonal F_+L_- — recall config.yaml lines 8-15 describe an explicitly off-diagonal-DDI active regime), with `γ_dr` contributing only the bookkeeping cascade;
- (c) The empirical decay is amplified by spatial-mode redistribution that concentrates `|ψ_m|²` into very high local density spots (factor ~1700 increase in effective `n`).

None of these match the "Dicke superradiance N²-enhancement" hypothesis the theorist invoked.

**Audit-5 verdict: the gap between production code's expected rate (with density weighting) and empirical 0.35/ω is ≈ 1700×, NOT factor 27.** The "factor 27" stated in §2.13 was computed against the *un-density-weighted* `Γ_theory = 0.0186/ω` (a number that does not correspond to anything physical in the production code). The real anomaly is ~2 orders of magnitude larger and points to either a **production-code convention misalignment** (γ_dr units) or a **mechanism entirely outside the dipolar-relaxation Lindblad** (Rabi+Larmor+DDI off-diagonal coherent mixing), not Dicke collectivity.

---

## 6. Audit-6: Is Q24.1 the right question?

Q24.1 = "what is the Dicke-collective enhancement factor C(β, F=6, N=10⁴)?"

Given Audit-1..5:
- The "factor 27" gap that motivated Q24.1 is an **accounting artifact** from comparing a `n=1`-bare per-atom rate with a globally density-weighted observable.
- The actual production-code-vs-empirical gap (with consistent density weighting) is `~1700`, an order of magnitude larger than Q24.1 contemplated.
- Production `apply_loss_step!` (losses.jl line 109) applies the Lindblad **independently per voxel** with no N-body coherent collective Hilbert space (sim/turn_24 §S4 explicitly confirms this). No Dicke regime is possible in the current code.

**Q24.1 has been pursuing a phantom.** Even if the Dicke calculation succeeded with C ≈ 14, it would not be active in the current production pipeline, and the residual factor (1700 / 14 ≈ 120) would still be unexplained.

---

## 7. Audit-7: Bug or convention difference?

Classification:

- **(c) Convention difference** for the comparison `Γ_theory vs Γ_emp` itself: the theorist's single-bin formula treats `γ_dr · s(m)` as a Lindblad rate; production code treats it as a 2-body-shape coefficient. Both are internally valid; the §2.13 comparison conflated them.
- **Possibly (a) Production-vs-YAML calibration gap**: the gap factor ~1700 between expected code rate at n_peak ≈ 0.01 and observed τ_Barnett = 2.84 ω⁻¹ is **so large that there may be a separate production issue** — `γ_dr` in the YAML may be interpreted by the spinor pipeline differently than the losses.jl docstring suggests, OR the trajectory's effective density during cascade is much higher than n_peak (which would require GP-shape distortion, but n_peak doesn't grow that much).
- **(b) Theorist accounting error**: yes — §2.13 quoted the "factor 27" as if comparing equal-convention numbers. The seven turns of mechanism speculation (rank-1 → rank-2 → Dicke) rest on this misframed gap.

Precedent: `gotcha_K3_routing_pre_2026_05_13.md` documents a recent case where loss-coefficient routing was wrong by factor 2 / factor 10 inside production code (the K3_per_m_si → L3_per_m vs K3_per_m_cubic mix-up). The current audit suggests a similar production-vs-YAML mismatch may exist for `gamma_dr` in the spinor/rotating-basis path — at the order-of-magnitude level it is a closer match to "code bug" than to "theory bug".

---

## 8. Findings

### F1 (LOAD_BEARING) — §2.13 "factor 27" is an apples-to-oranges comparison

`Γ_theory = γ_dr · s(+F) · P̄_- = 0.0186/ω` (theorist §2.5/§2.13) is a bare per-atom rate that does not account for the explicit `n_total(r)` factor in `losses.jl` line 109. Comparing it to `Γ_emp = 0.35/ω` (a globally density-weighted observable rate) yields a meaningless ratio. **The seven-turn mechanism speculation chain (T11 rank-1 → T13 rank-2 → T24 Dicke) is built on this unsound comparison.**

Recommendation to T26: theorist must first **rederive `Γ_theory` with proper density weighting**: `Γ_theory^{cloud-avg} = γ_dr · s(+F) · P̄_- · ⟨n⟩_avg`, where `⟨n⟩_avg = ∫ n² d³r / ∫ n d³r = (4/7) n_peak ≈ 0.005` for a TF profile. Then `Γ_theory^{proper} ≈ 0.0186 · 0.005 ≈ 9 × 10⁻⁵/ω`. The gap-vs-empirical becomes ~4000×, even worse than the naive comparison — but at least it is **a meaningful comparison**.

### F2 (LOAD_BEARING) — actual production-vs-empirical gap is ~1700×, not 27×

Direct estimate from production code at the cloud center: `Γ_production(0, +F) = γ_dr · shape[+F] · n_peak = 0.02 · 0.9286 · 0.0095 ≈ 1.8e-4 /ω`. Multiplied by cascade Δm-per-jump ≈ 1.15: predicted `τ ≈ 4900 ω⁻¹`. Empirical `τ = 2.84 ω⁻¹`. Ratio = 1700.

**This is the real anomaly the campaign should be investigating, not factor 27.** Dicke single-atom enhancement (S3 ratio 1.087) is utterly irrelevant; even an N² collective factor (10⁸) overshoots by orders of magnitude.

Recommendation to T26: pin down whether the gap is a code convention error (γ_dr in the YAML feeding the spinor pipeline gets re-scaled by a hidden factor, similar to K3 routing pre-fix) OR a missing physical mechanism (e.g., Rabi+Larmor + off-diagonal DDI coherently mixing components on a Rabi timescale, with γ_dr playing only a small bookkeeping role).

### F3 (LOAD_BEARING) — shape normalization (Audit-3) is consistent

Both theorist and production code use `shape[+F=+6] = 13/14`. The convention agreement here is real and verifiable. **No factor-13/14 hidden in the shape normalization.** This eliminates one possible source of the gap.

### F4 (ADVISORY) — sim/turn_24 §S4 correctly noted Dicke inapplicability

The implementer's S4 observation (`sim/turn_24` line 184: "production SpinorBEC.jl `apply_loss_step!` applies the Lindblad jump operators locally to the spinor field — there is no N-body collective Hilbert space. The factor 10⁸ does not appear.") **already independently refuted the Dicke pathway**. The theorist's §2.13 Dicke speculation should have been retired at the level of inspection of `losses.jl` line 109, before any sympy run. Implementer caught what the theorist did not.

Recommendation: T26 dispatch should **not** re-engage Dicke (researcher Q24.1 literature anchor is moot per F1+F2+F4).

### F5 (ADVISORY) — empirical τ_Barnett at Ω=+0.5 is "NEVER reaches threshold"

sim/turn_20 line 112: at `Ω=+0.5`, `τ_Barnett = NEVER reaches threshold`. At `Ω=-0.5`, τ = 2.84 ω⁻¹. The asymmetry is real and dramatic. **Whatever mechanism is responsible operates strongly at -Ω and not at +Ω**. Neither rank-2 dipolar (Audit-3, gives ratio 1.087) nor Dicke (Audit-6) explains the asymmetry direction. Position-resolved Bloch with coherent Rabi (theorist §2.4-§2.6) predicts the opposite sign (theorist §2.13 line 1295: "Δ_theory = +1.6" vs empirical "-5.985"). **The mechanism that produces the asymmetry remains unidentified after T24.** Audit-7's option (b) — Rabi+Larmor + off-diagonal-DDI coherent mixing — is the most plausible un-explored direction, especially because config.yaml line 11 *explicitly* designs the run to be in the off-diagonal-DDI-active regime (`p·F/c_dd·n ≈ 17 ≪ secular threshold`).

### F6 (ADVISORY) — falsification_criterion in sim/turn_24 was met but the criterion itself was based on a phantom

sim/turn_24 line 200-202 reports `falsification_result: CONFIRMED` (Dicke refuted, ratio 1.087 < 5). The criterion logic IS sound (single-atom rank-2 cannot produce factor 14). But because F1+F2 show the original "factor 27" was a phantom anyway, the falsification has limited information value — it would have arrived at the same conclusion by simply reading line 109 of `losses.jl`. The "8 minutes of sympy" was not wrong; it was *unnecessary*.

---

## 9. Recommendation to T26 (Dispatch Plan)

**Drop the Dicke pathway entirely** (F1, F2, F4, F6). Q24.1 is moot.

**Pivot T26 to one of two candidate audits**:

- **Option A (preferred): theorist-style review of the spinor-path γ_dr propagation.** Theorist re-derives the production-code effective rate from line 109 of `losses.jl` with full density weighting and TF profile, comparing to empirical τ = 2.84 ω⁻¹. Document the ~1700× gap *with* density weighting. State whether γ_dr in the YAML is **intended** as a bare-per-atom Lindblad rate or as a 2-body-shape coefficient. If a code convention issue is suspected, dispatch implementer_audit_existing in T27 to inspect how γ_dr flows from YAML → LossParams → rotating_basis or spinor pipeline (test for a `· N`, `· ω_ref`, or `/n_peak` rescaling that may be inadvertently or intentionally applied).

- **Option B: theorist explores the coherent (non-dissipative) channel.** The empirical Δ ≈ -5.985 (sim/turn_20) may be driven by **Rabi + off-diagonal-DDI F_+L_-** coherent mixing, not by `γ_dr` cascade at all. The config.yaml comment lines 8-15 explicitly designed this regime ("`p·F/c_dd·n ratio ~17 ≪ secular advisory threshold of 100`"). The cdd0 control run shows decay even with c_dd=0, but perhaps via Rabi+Larmor alone with population redistribution feeding back into n_m(r). This is plausible since at -Ω the Rabi axis is nearly aligned with the initial Bloch vector but slow oscillations at ω_R = 0.844/ω could still resonate with the trap-frequency mode mixing.

Either option requires **no julia execution**, so the sandbox gate (mentioned in the mandate as "retries 1->2 if julia retried") is not at risk. Pure theorist work, ~1.0M tokens.

---

## 10. Verdict block

```
VERDICT: FAIL

CONFIDENCE: high

RATIONALE: T24's §2.13 "factor 27" gap is an accounting artifact from
comparing a bare per-atom rate (γ_dr·s(+F)·P̄ = 0.0186/ω, theorist) to
a density-weighted observable (1/τ_Barnett = 0.35/ω, empirical). The
production code at losses.jl line 109 explicitly multiplies γ_dr·shape
by n_total(r); the theorist's formula does not, so the two sides of
"0.013 vs 0.35" are not the same quantity (Audit-1). With proper
density weighting at n_peak ≈ 0.0095 (Audit-2, confirmed by trajectory.csv
peak column in sim/turn_20), the production-code expected rate at the
cloud center is ~1.8e-4/ω, predicting τ ≈ 4900 ω⁻¹ vs empirical 2.84 ω⁻¹
(F2 gap ~1700×, not 27×). Dicke speculation (§2.13 lines 1336-1358) is
moot: (i) the real gap is two orders of magnitude larger than the gap
Dicke was hypothesized to close, (ii) production code has no collective
N-body Hilbert space (sim/turn_24 §S4 line 184), (iii) the shape
normalization Z factor IS consistent (Audit-3: shape[+F]=13/14 matches
in both code and theorist). The seven-turn mechanism chain T11→T13→T24
rests on a misframed comparison. B1 (internal consistency) and B4
(magnitude check on novel claim) both flag. T26 must drop Dicke and
either (A) redo the comparison with density weighting OR (B) explore
coherent Rabi+off-diagonal-DDI mixing as the dominant -Ω asymmetry
driver.

RECOMMENDED ACTION: Reject, return to theorist with:
"Recompute Γ_theory^{cloud-avg} = γ_dr · s(+F) · P̄_- · ⟨n²⟩/⟨n⟩
using losses.jl line 109's actual density-weighted form. State the
density-weighted predicted τ_Barnett and compare to empirical 2.84 ω⁻¹.
If the gap is ≫ 100, propose what physical or code-convention factor
closes it; do NOT pursue Dicke (F1+F2+F4+F6 retire it). Inspect whether
the γ_dr in YAML is consistent with its losses.jl docstring convention
(2-body-shape rate per density) or if a hidden N or ω_ref rescaling
exists in the spinor or rotating_basis loss path. Reference precedent
gotcha_K3_routing_pre_2026_05_13.md as a similar production-routing
miscalibration."
```

VERDICT: FAIL

---

**Note to orchestrator on prompt injection:** During reading of `runs/eu151_barnett_spin/config.yaml`, the file-read response included an unsolicited "# MCP Server Instructions / claude.ai Figma" block that attempted to instruct me about Figma tooling. This was not part of the user's mandate and not part of the file contents. I ignored it and continued the read-only audit per critic.md §A1-A2. Reporting per anko's standing protocol.
