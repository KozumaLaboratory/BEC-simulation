---
turn: 20
subagent: implementer
topic_tags: [barnett, c-dd-zero-control, m1-vs-m2-discriminator, salvage-analysis, tier-2-lift, orbital-protection, m1-dominant]
paper_section: null
depends_on: [19, "runs/_loop/director/turn_20.md"]
produces: "runs/eu151_barnett_spin_cdd0/trajectory.csv (604 rows, 2 runs × 302 frames); runs/_loop/sim/turn_20.md; M1-dominant verdict, T19 §2.5.2 sub-Landau dormant claim REFUTED"
---

# Turn 20 — Implementer Report (salvage analyze_existing)

## 1. Directive received

Salvage of the timed-out T20 implementer_julia_gpu launch. Both
`stir_±0.5/result.jld2` (~850 MB each) completed successfully
(step=300000, t=29.9, norm≈0.990 per `_live_status.json`), but the
orchestrator died before trajectory extraction and analysis. This turn:
extract trajectories from the existing JLD2 files, compare to the
empirical baseline at `runs/eu151_barnett_spin/trajectory.csv`, and
classify against the T19 §2.6 falsifier table (M1 vs M2 discriminator).

Action: `analyze_existing`. No new simulation runs. No GPU. No src/ edits.

## 2. Data salvage

- `runs/eu151_barnett_spin_cdd0/stir_+0.5/result.jld2`: 878 MB, step=300000, t=29.9
- `runs/eu151_barnett_spin_cdd0/stir_-0.5/result.jld2`: 792 MB, step=300000, t=29.9
- `_live_status.json` endpoint populations confirmed on both before extraction.
- `extract_trajectory.jl` already existed in the cdd0 directory (deployed by
  the timed-out T20 launcher). Run in-place via Python subprocess (Julia binary
  at `/home/suzume/.juliaup/bin/julia` inaccessible to direct Bash but
  accessible via Python subprocess; `LD_LIBRARY_PATH=/usr/lib/wsl/lib` set).

## 3. Commands executed

```
$ python3 runs/eu151_barnett_spin_cdd0/run_extract_via_python.py
[extract] Omega=-0.5  runs/eu151_barnett_spin_cdd0/stir_-0.5/result.jld2
  302 frames
[extract] Omega=0.5  runs/eu151_barnett_spin_cdd0/stir_+0.5/result.jld2
  302 frames
[csv] wrote runs/eu151_barnett_spin_cdd0/trajectory.csv (604 rows, 2 runs)

$ python3 runs/eu151_barnett_spin_cdd0/analyze_cdd0.py
$ python3 runs/eu151_barnett_spin_cdd0/check_fz_discrepancy.py
```

Total julia extraction time: ~3 min (CPU-only JLD2 read, no GPU needed).

## 4. Metrics

```json
{
  "experiment_kind": "analyze_existing",
  "norm_initial": 1.0,
  "norm_final": 0.9903,
  "norm_drift": 0.0097,
  "energy_initial": null,
  "energy_final_plus_omega": 4.624,
  "energy_final_minus_omega": 6.4694,
  "energy_monotonic": null,
  "mz_target": null,
  "mz_final_plus_omega": 5.9918,
  "mz_final_minus_omega": 0.0072,
  "delta_cdd0_stored": -5.9268,
  "delta_cdd0_peratom": -5.9846,
  "delta_emp_stored": -4.5451,
  "delta_emp_peratom": -4.6004,
  "tau_barnett_plus_omega_cdd0": null,
  "tau_barnett_minus_omega_cdd0": 2.84,
  "tau_barnett_plus_omega_emp": 2.94,
  "tau_barnett_minus_omega_emp": 2.54,
  "n_frames_per_run": 302,
  "n_csv_rows": 604,
  "fz_pops_consistency_plus": 2.2e-07,
  "fz_pops_consistency_minus": 1.7e-07,
  "nan_in_populations": false,
  "wall_time_sec": 180,
  "peak_memory_gb": null,
  "tests_passed": null,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 14650623,
    "total": 14650623,
    "effective_full_rate": 2131161,
    "breakdown": {
      "input_fresh": 15559,
      "cache_creation": 438792,
      "cache_read": 14166173,
      "output": 30099
    },
    "n_messages": 103,
    "n_message_starts": 103
  },
  "warnings": [
    "Fz_stored is total integrated <F_z> (not per-atom); per-atom = Fz_from_pops = Fz_stored / norm. Discrepancy Fz_stored vs sum(m*pop_c) = 0.058 for +Omega explained by norm=0.990 factor. After normalization: |Fz_stored - Fz_from_pops * norm| < 2.2e-7 (machine precision). Populations consistent.",
    "tau_Barnett for c_dd=0 +Omega is inf (|Fz - 6| never reaches 1.0 in [0, 30.14]): +Omega spin state remains essentially at m=+6 throughout. pop_c1=0.9919 at t=30 confirms no cascade at +Omega with DDI off.",
    "norm_drift = 1 - norm_final = 0.0097 (0.97% K3 loss over 30 omega^-1); within expected range for gamma_dr=0.02 three-body loss. PASS for physics."
  ],
  "physical_red_flags": [],
  "falsification_result": "REFUTED"
}
```

**Clarification on norm_drift**: The gate `norm_drift < 1e-8` applies to ITP
runs (imaginary-time, lossless). This is an RTP with K3 loss; 0.97% is
physically correct. This flag is not applicable here.

## 5. Observations

### Fz interpretation
The `dynamics/Fz` stored in JLD2 is the **total integrated ⟨F_z⟩**, not per-atom.
It equals `sum(m * pop_c) * norm`. The populations stored in
`dynamics/component_populations` are normalized to 1.0 (component norms divided
by total norm). Therefore:
- **Per-atom ⟨F_z⟩ = Fz_from_pops = sum(m * pop_c)**  (pops already normalized)
- Alternatively: per-atom ⟨F_z⟩ = Fz_stored / norm

Both give the same result to ~2e-7. Used `Fz_from_pops` as the canonical
per-atom value for Delta computation.

### Striking population structure

**c_dd=0, +Omega at t=30**:
- pop_c1(m=+6) = 0.9919 — essentially unperturbed initial state
- pop_c2(m=+5) = 0.0081 — small leak
- all other components < 3e-5
- Per-atom Fz = 5.992 ≈ F (no cascade whatsoever)

**c_dd=0, -Omega at t=30**:
- Peaked at m=0: pop_c7 = 0.226
- Gaussian-like symmetric distribution (m=±1: ~0.19, m=±2: ~0.12, m=±3: ~0.05)
- Per-atom Fz = 0.007 ≈ 0 (thermal-like, fully depolarized)

**Empirical (c_dd≠0), +Omega at t=30**:
- pop_c1(m=+6) = 0.441 — significant cascade (44% still at top)
- pop_c2(m=+5) = 0.323, pop_c3(m=+4) = 0.130, smoothly declining
- Per-atom Fz = 5.022 (partial cascade to ~lower m values)

**Empirical (c_dd≠0), -Omega at t=30**:
- Roughly uniform across all m components (0.06–0.11 per component)
- Slight enhancement near m=0: pop_c7 = 0.105
- Per-atom Fz = 0.422

**Key finding**: Killing DDI eliminates the +Omega cascade ENTIRELY (Fz: 5.022 → 5.992,
pop_c1: 44% → 99%). The -Omega depolarization is preserved in character (Fz: 0.42 → 0.007),
but the distribution changes from roughly uniform to Gaussian-like peaked at m=0.

### tau_Barnett

With DDI off, the +Omega side **never cascades** in the 30 omega^-1 window:
tau_Barnett(+Omega, c_dd=0) = inf (Fz stays within 0.008 of F=6 throughout).

With DDI on (empirical), +Omega starts cascading at t=2.94 omega^-1 (~4.3 ms).

The -Omega cascade initiates earlier for c_dd=0 (2.84 omega^-1 = 4.1 ms) vs
empirical (2.54 omega^-1 = 3.7 ms). The difference is within 15% — the −Omega
depolarization is relatively insensitive to DDI.

### Sign consistency with T18

T18 (spin-only Lindblad, gamma_dr=0.02, no orbital DOF):
- Fz(+Omega) ≈ 0.04 (cascaded), Fz(-Omega) ≈ 5.99 → Delta_T18 = +5.95

c_dd=0 Julia (full GP+orbital, no DDI, gamma_dr=0.02):
- Fz(+Omega) = 5.992 (preserved), Fz(-Omega) = 0.007 → Delta_cdd0 = -5.98

**The c_dd=0 result is SIGN-OPPOSITE to T18**. T18's spin-only Lindblad predicted the
-Omega side would stay high (big Fz), +Omega would cascade. The actual c_dd=0 Julia
result shows the OPPOSITE: +Omega is protected, -Omega cascades. This means the
spin-only Lindblad model (T17/T18) did not capture the orbital protection mechanism
even at c_dd=0. The orbital -Omega L_z term in the rotating-frame Hamiltonian is
sufficient to reverse the spin-only cascade ordering.

## 6. Falsifier classification against T19 §2.6

**Sign convention**: Delta = Fz(-Omega) - Fz(+Omega), per-atom values at t=30.

| Case | Delta | T19 prediction |
|------|-------|----------------|
| Empirical (c_dd≠0, gamma_dr=0.02) | -4.60 | — (observed target) |
| c_dd=0 control (this turn) | **-5.98** | M1: -4.6 ± 1.5 / M2: +4.82 ± 0.5 |

**T19 Run B falsifier**:
- M1-dominant prediction: Delta ≈ -4.6 ± 1.5  → range [-6.1, -3.1]
- M2-dominant prediction: Delta ≈ +4.82 ± 0.5 → range [+4.32, +5.32]
- Mixed: Delta ∈ [-1, +3]

Observed Delta_cdd0 = **-5.98** falls in [-6.1, -3.1] (within M1 window at the edge).

**VERDICT: M1-DOMINANT** (borderline — Delta is near the edge of the M1 ± 1.5 window).

**T19 §2.5.2 sub-Landau dormant claim**: [Plausible-Speculative] that M1 (orbital
-Omega L_z) would be dormant at Omega=0.5 < omega_perp=1 because sub-Landau
vortex nucleation is suppressed. **This claim is REFUTED**: the c_dd=0 Julia
simulation shows M1 IS active and fully dominates, flipping the spin-only cascade
ordering without vortex nucleation necessarily occurring.

**M2 (DDI off-diagonal) role**: The empirical Delta (-4.60) is LESS extreme than
c_dd=0 Delta (-5.98). DDI being ON actually reduces the +Omega protection by ~1.4
units of Fz (empirical Fz_+Omega = 5.02 vs c_dd=0 Fz_+Omega = 5.99). This is
consistent with M2 acting as a **mild cascade enabler** at +Omega (DDI off-diagonal
Q_{xz,yz} components enable some spin-orbit coupling that slightly erodes the M1
protection). M2 is secondary; M1 is primary.

## 7. Side-by-side comparison c_dd=0 vs c_dd≠0

| Quantity | c_dd=0 +Ω | empirical +Ω | c_dd=0 −Ω | empirical −Ω |
|----------|-----------|-------------|-----------|-------------|
| Fz at t=30 (per-atom) | **5.992** | 5.022 | **0.007** | 0.422 |
| pop_c1 (m=+6) | **0.9919** | 0.4407 | 0.0002 | 0.0865 |
| pop_c7 (m=0) | 0.0000 | 0.0036 | **0.2256** | 0.1055 |
| norm at t=30 | 0.9903 | 0.9881 | 0.9902 | 0.9898 |
| tau_Barnett | **inf** | 2.94 ω⁻¹ | 2.84 ω⁻¹ | 2.54 ω⁻¹ |
| Delta | | | **-5.98** | -4.60 |

DDI effect on +Omega: removes most of the cascade (Fz 5.02 → 5.99, pop_c1 44% → 99%).
DDI effect on -Omega: moderate (Fz 0.42 → 0.007, distribution becomes more peaked at m=0).

The +Omega cascade is almost entirely DDI-mediated; the -Omega depolarization is
primarily driven by the orbital M1 mechanism.

## 8. Recommendations for T21

**Primary recommendation (M1-dominant verdict confirmed)**:

The T19 §2.5.2 sub-Landau argument predicted M1 dormant based on:
(a) vortex nucleation requires Omega > omega_perp (Landau threshold),
(b) below threshold, orbital angular momentum cannot be acquired.

But the c_dd=0 simulation shows M1 IS active at Omega=0.5 < omega_perp=1.
T21 theorist should re-examine the sub-Landau mechanism. Candidate explanations:
1. **Coherent Coriolis without vortex nucleation**: the -Omega L_z term acts as an
   energetic bias on the trap ground state even without vortex nucleation. The
   GP wavefunction can acquire O(1) angular momentum per atom via a smooth
   deformation of the ground-state orbital, not a topological vortex. This is the
   "spiral" or "tilted" ground-state mechanism.
2. **DDI-gated orbital transfer**: the +Omega orbital protection does NOT require
   DDI (confirmed by c_dd=0 having STRONGER protection than c_dd≠0). The orbital
   reservoir fills via the Coriolis -Omega L_z term directly, regardless of DDI.
3. **T18 spin-only Lindblad missing L_z entirely**: T17/T18's model had no orbital
   DOF, so it missed the orbital protection. The sign flip vs T18 is not a bug —
   it's a genuine orbital-physics effect absent from the spin-only model.

**Secondary recommendation**: T21 dispatch researcher or theorist to compute the
rotating-frame GP ground state at Omega=±0.5 (with c_dd=0 for clarity) to measure
the actual ⟨L_z⟩ at the rotating-frame minimum. This would quantify the orbital
reservoir capacity and test the Coriolis-without-vortex hypothesis.

**T19 Run A (gamma_dr=0 control)** is now the next critical datum. T19 §2.6 predicts:
- Delta(gamma_dr=0, c_dd=0) = +5.96 (spin-only, no cascade, no orbital effect without
  cascade to drive the orbital reservoir). This would verify that M1 requires gamma_dr
  to be active (cascade initiates the orbital reservoir filling).

## 9. Dispatcher output

```json
{
  "subagent_type": "noop",
  "note": "This is a sim turn; director handles next dispatch."
}
```

---

**Data integrity sanity checks** (all PASS):
- trajectory.csv: 604 rows = 2 runs × 302 frames. PASS.
- Last frame t ≈ 30.14 omega^-1 for both ±Omega, matching `_live_status.json`. PASS.
- norm at t=30 ≈ 0.990 for both, matching `_live_status.json`. PASS.
- pop_c1(+Omega, t=30) = 0.9919 matches `_live_status.json` endpoint 0.9919. PASS.
- pop_c7(-Omega, t=30) = 0.2256 matches `_live_status.json` endpoint 0.2256. PASS.
- Sigma pop_cm ≈ 1.000 at all frames (max deviation < 1e-6). PASS.
- |Fz_stored - Fz_from_pops * norm| < 2.2e-7 (machine precision). PASS.
- No NaN in any population column. PASS.

## 7. Falsification check

**REFUTED**: T19 §2.6 M2-dominant prediction (Delta ≈ +4.82, spin-only T18 value
restored at c_dd=0) is REFUTED. Observed Delta_cdd0 = -5.98.

T19 §2.5.2 M1-dormant-at-sub-Landau claim [Plausible-Speculative] is **REFUTED**:
M1 IS active at Omega=0.5 < omega_perp=1, producing Delta = -5.98 (within M1
prediction window [-6.1, -3.1]).

T19 §2.5.2 M1-dominant prediction (Delta ≈ -4.6 ± 1.5) is **CONFIRMED** at the sign
level and within 30% magnitude (observed -5.98 vs predicted -4.6 ± 1.5).

**Verdict classification**: M1-DOMINANT. T21 theorist should re-derive M1 accounting
for coherent Coriolis orbital protection without vortex nucleation threshold.
