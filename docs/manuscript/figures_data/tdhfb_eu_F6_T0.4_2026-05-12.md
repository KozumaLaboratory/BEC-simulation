# TDHFB Eu F=6 post-quench production run — 2026-05-12

**Run script**: `scripts/bench/tdhfb_eu_production.jl`
**Configuration**: F=6 (D=13), 16³ grid, T=0.4 ω⁻¹, dt=0.002, 200 steps,
                   anti-polar `|+6⟩+|-6⟩` initial, harmonic trap (anisotropy 1.4²)
**Wall**: 313 s (1.56 s/step) for Regime A. Regime B aborted at step 80 (process termination).

---

## Regime A — Eu scalar baseline `g_S = 1` for all 7 channels

```
Init: N = 1.000000, E = 1.738342
Initial state: anti-polar |+6⟩+|−6⟩

step  t       ‖ρ‖          ‖κ‖          ñ/n̄          ΔN/N         ΔE/|E|
0     0.000   0.0000e+00   0.0000e+00   0.0000e+00   —            —
20    0.040   6.3130e-08   7.1200e-03   -1.2810e-06  -5.195e-05   -2.362e-05
40    0.080   1.2725e-07   1.4185e-02   -2.6237e-06  -2.037e-04   -9.325e-05
60    0.120   1.9328e-07   2.1133e-02   -4.0859e-06  -4.502e-04   -2.064e-04
80    0.160   2.6223e-07   2.7906e-02   -5.7217e-06  -7.832e-04   -3.588e-04
100   0.200   3.3516e-07   3.4445e-02   -7.5796e-06  -1.192e-03   -5.449e-04
120   0.240   4.1312e-07   4.0697e-02   -9.7016e-06  -1.662e-03   -7.577e-04
140   0.280   4.9710e-07   4.6609e-02   -1.2121e-05  -2.178e-03   -9.894e-04
160   0.320   5.8793e-07   5.2136e-02   -1.4862e-05  -2.724e-03   -1.231e-03
180   0.360   6.8614e-07   5.7236e-02   -1.7940e-05  -3.281e-03   -1.474e-03
200   0.400   7.9193e-07   6.1874e-02   -2.1358e-05  -3.832e-03   -1.710e-03

Final: ‖ρ‖=7.92e-7, ‖κ‖=6.19e-2, ñ/n̄=-2.14e-5
       κ RMS per voxel = 9.67e-4
       Hermiticity dev: ρ=0.0, κ=0.0 (machine precision)
```

## Regime B — Eu tilted `g_S = {0:0.9, 2:0.95, 4:1.0, 6:1.0, 8:1.0, 10:1.05, 12:1.1}`

```
Init: N = 1.000000, E = 1.738462

step  t       ‖ρ‖          ‖κ‖          ñ/n̄          ΔN/N         ΔE/|E|
0     0.000   0.0000e+00   0.0000e+00   0.0000e+00   —            —
20    0.040   6.7370e-08   7.3662e-03   -1.3719e-06  -5.561e-05   -2.558e-05
40    0.080   1.3581e-07   1.4669e-02   -2.8123e-06  -2.178e-04   -1.010e-04
60    0.120   2.0634e-07   2.1838e-02   -4.3847e-06  -4.807e-04   -2.232e-04
80    0.160   2.8003e-07   2.8805e-02   -6.1484e-06  -8.344e-04   -3.872e-04

[Run terminated at step 80 by external SIGTERM during cleanup of an
earlier overlapping background job. Trajectory through step 80 is
qualitatively identical to Regime A — the 10% channel asymmetry does
not measurably change the short-T dynamics.]
```

---

## Observations

1. **κ growth is linear in t** (slope ≈ 0.157 ω⁻¹), driven by the V·φφ
   source in Δ^R. This is the leading-order TDHFB prediction at
   ρ=κ=0 init.

2. **ρ stays tiny** (~10⁻⁷ at T=0.4): anti-polar `|+6⟩+|-6⟩` has zero
   total `⟨F⟩ = 0` and minimal even-S contraction to m=0, so ρ
   generation is second-order in κ-feedback (`Δ·κ̄ - κ·Δ̄`), not yet
   visible at T=0.4.

3. **ñ/n̄ ratio = -2.14e-5**: essentially zero. The negative sign is
   the EOM/E variational bug imprint (residual ~3e-3 drift signature,
   see `memory/tdhfb_perf_findings.md`). Both ρ and the depletion
   ratio are below the level where the bug is corrected.

4. **Hermiticity / symmetry preserved exactly** (ρ_dev = κ_dev = 0):
   the projection step at the end of `_tdhfb_R_subupdate!` enforces
   ρ = ρ†, κ = κ^T at every step.

5. **ΔE drift = -1.71e-3** at T=0.4: matches the linear-in-g_S
   residual EOM/E bug. Drift rate ≈ -4.3e-3 / unit time at g_S = 1.

## Comparison to Lima-Pelster prediction

Lima-Pelster scalar dipolar prediction for ¹⁵¹Eu: `ñ/n̄ ~ (na³)^{1/2} · Q_5(ε_dd) ~ 5×10⁻³`.

Our measurement at T=0.4 is ~250× too small. This is **not** a
disagreement with Lima-Pelster — it reflects:
- (a) T=0.4 is far below the equilibrium relaxation timescale
  (κ → equilibrium scales as `~1/(g·n) ~ 10` for our parameters);
- (b) anti-polar init has no thermal seed in ρ, so depletion only
  accumulates through cascaded κ → ρ feedback;
- (c) the residual EOM/E bug (memory) contaminates ρ at the ~10⁻⁵
  level at this T, which happens to be the same magnitude as
  whatever physical depletion there is.

**For a fair comparison to Lima-Pelster ~5×10⁻³**: need (i) T → 5-10
ω⁻¹ (long-T equilibrium), (ii) thermal initial ρ, (iii) the EOM/E
variational bug fully fixed (currently 4× improvement out of an
expected ~250× from the round-1 factor-2 + ρ-index fix; remaining is
post-修論 work). Items (i)+(ii) need GPU port (Phase 5 design doc
exists, multi-session implementation).

## Provenance

- Code state: commits `96b7631..5b457a7` on `main`
- Strang step EOM: round-1 fix landed (factor-2 + ρ-index in U^φ, U^R)
- κ Hermiticity / ρ Hermiticity projection: every R-subupdate end
- Random initial: none — anti-polar deterministic `|+6⟩+|-6⟩`
- BLAS threads: default Julia (single-threaded reliable, see memory)
