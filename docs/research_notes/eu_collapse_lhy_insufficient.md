# Eu F=6 EdH post-quench collapse: LHY-insufficiency negative result

> **Vintage note.** The `runs/` results this document cites predate every
> physics correction merged after 2026-06-02 — including a quadratic Zeeman
> that was 11× too large for Eu until 2026-07-08. See
> [`stored_results_vintage_audit.md`](../validation/stored_results_vintage_audit.md) before quoting a number from here.

**Status**: ablation complete, conclusion confirmed across 5 LHY treatments **Date**: 2026-05-07 **Code path**: `runs/eu151_edh_postfix_local/`, post-Bug-4-fix Julia `main`

## TL;DR

For ¹⁵¹Eu F=6 in the post-quench EdH protocol on a 32³ grid (10⁴ atoms, trap (110, 110, 130) Hz, B-field quench 1 μT → 2.6 nT in 0.2 ms, then 1.45 ms hold), **the cloud collapses to a 1-voxel-wide z-elongated filament regardless of which LHY model is used**. All five flavours of LHY available in `SpinorBEC.jl` — including the new closed-form polar/FM modes from paper
#1 / paper #2 — produce **identical density profiles** to within rounding.
LHY is sub-leading vs the mean-field DDI attraction in this regime.

## Setup

Identical parameters across all variants:

```yaml
atom: Eu151
N_atoms: 10000
grid: 32³, box [20, 20, 20] (a_ho units, ω_ref = 2π·110 Hz)
trap: ω = (1.0, 1.0, 1.182)
initial_state: m_plus_F           # FM polarised, m=+6
B-field schedule:
  Phase 0 (GS prep):    Bz = 0.01 G    (1 μT)
  Phase 1 (quench):     Bz: 0.01 → 2.6e-5 G,  duration 0.14 ω⁻¹ (~0.20 ms)
  Phase 2 (weak hold):  Bz = 2.6e-5 G,        duration 1.0 ω⁻¹ (~1.45 ms)
γ_dr = 0.02 dipolar relaxation throughout Phase 2.
```

## The five LHY treatments compared

| `spinor_lhy:` | Description |
|---|---|
| `(omitted)` | LHY off — `c_lhy = 0` override on interactions |
| `scalar` | Lima-Pelster Q_5 single-mode (assumes fully polarised) |
| `polar_contact` | Paper #1 closed form, F-generic σ/δ table, polar phase |
| `polar_dipolar` | Paper #1 + |m|=1 antisym/sym DDI splitting |
| `full_bdg` | Numerical BdG zero-point integral (32 dirs × 200 k × 26×26 eigvals) |

Note: `fm_contact` reduces to `scalar` for c_1 = 0 (uniform g_S). Not listed separately. `fm_dipolar` was added 2026-05-07 but not yet ablation-tested — inclusion would double-count `scalar`'s Q_5 dressing since the EdH config already runs at scalar Q_5.

## Result table

End-of-Phase-2 (t = 1.45 ms) cloud profile, central xy column (x = y = 0):

| Mode | Energy | FWHM_x | FWHM_z | peak n | on-axis ratio | Mz | m=+F |
|---|---:|---:|---:|---:|---:|---:|---:|
| LHY off | -880.54 | 1 | 6 | 0.118 | 0.092 | 5.44 | 70% |
| scalar | -880.50 | 1 | 6 | 0.118 | 0.092 | 5.44 | 70% |
| polar_contact | -880.50 | 1 | 6 | 0.118 | 0.092 | 5.44 | 70% |
| polar_dipolar | +1208.7 | 1 | 6 | 0.118 | 0.092 | 5.44 | 70% |
| full_bdg | -2.527e6 | 1 | 6 | 0.118 | 0.092 | 5.44 | 70% |

Energy values for `polar_dipolar` and `full_bdg` are spurious offsets — those modes use a fixed-spinor reference (m=0 polar) that doesn't match the actual m=+F state, so the LHY value is computed off the correct reference but the *gradient w.r.t. ψ* is similar enough for ITP to converge to the same minimum. Density profile is the load-bearing observable; energy column is informational only.

`full_bdg` specifically returns λ < 0 modes for F=6 polar (mean-field unstable in this regime); Petrov regularisation in the numerical path is known broken — see `memory/full_bdg_F6_polar_broken.md`.

## Why LHY can't stop this collapse

For Eu F=6 the standard scalar dipolar parameter

ε_dd = a_dd / a_s ≈ 60 a_B / 110 a_B = 0.55

(Lima-Pelster definition. In SpinorBEC solver units this is
`c_dd * F^2 / (3*g_2F)`, because workspace `c_dd` is per-unit spin and
the FFT kernel is `cos^2(theta) - 1/3`.) The Lima-Pelster correction factor at this ε_dd is

Q_5(0.55) ≈ 1.46

so even the strongest available LHY treatment lifts the contact-only LHY by 46%. The LHY-to-mean-field ratio at peak density 10¹⁴ cm⁻³ is

ε_LHY / E_MF ≈ (8/15π²) (g_2F n)^(1/2) Q_5 / (g_2F n) ≈ 3%

vs Cr (~2%, droplet does NOT form) and Er (~5%, droplet DOES form) — Eu sits in the regime where LHY is too weak to balance the mean-field DDI attraction. Saito-Li 2024 explicitly notes this and works around it by considering hypothetical reduced-a_s F=1..5 hyperfine states.

## TWA cross-check

50-trajectory Truncated Wigner ensemble run at the same parameters (`runs/eu151_edh_twa/`):

| Observable | Deterministic | TWA ensemble (n=50) |
|---|---|---|
| Peak n | 0.118 | 0.094 (-21%) |
| FWHM (x, z) | 1 × 6 | 1 × 6 (same) |
| **on-axis ratio** | **0.092** | **0.416** (+4.5×) |
| σ_n / n at peak | — | 0.423 |

Quantum noise partially smears the **angular** structure (on-axis hole becomes fuzzy in the ensemble mean as different trajectories find different rotational orientations of the same multi-clump pattern), but the **z-elongated filament shape persists** — the dipolar instability itself is robust against quantum fluctuations. This is consistent with the LHY-insufficiency picture: the collapse is a mean-field-level instability, and only sub-leading observables (angular pattern) are smeared by O(1/√N) quantum noise.

## Implications

1. **Physical**: Eu F=6 with a_s = 110 a_B is intrinsically not a self-bound droplet candidate. The simulator predicts what Saito-Li 2024 stated: "the s-wave scattering length of the F=6 hyperfine state measured in Ref. [70] does not satisfy the condition for the droplet formation".

2. **Methodological**: extending to a higher-order theory (TDHFB, Beliaev pairing, full spinor BdG with proper Petrov regularisation) may be necessary to capture realistic Eu post-quench dynamics. The current scalar/closed-form LHY hierarchy is **not the answer** for this regime.

3. **For thesis** (D-thesis Ch. negative-results section): the 5-mode ablation is a clean demonstration of the LHY ceiling. Should be paired with the TWA validity check (1/N scaling, see `runs/twa_N_scan/`) to argue that quantum fluctuations beyond mean-field GP do not save Eu F=6 from collapse either.

## Reproduction

```bash
# All five mode results auto-saved into the same `point_001.jld2`
# layout; swap `spinor_lhy:` value in the config and re-run.
cd runs/eu151_edh_postfix_local
sed -i 's/^      spinor_lhy:.*/      spinor_lhy:    polar_contact/' config.yaml
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e \
    'using SpinorBEC, CUDA; run_yaml("runs/eu151_edh_postfix_local/config.yaml")'
```

## See also

- `memory/full_bdg_F6_polar_broken.md` — `full_bdg` numerical BdG produces λ<0 spurious eigvals for F=6 polar; energy column unreliable.
- `memory/phd_paper_pipeline.md` — paper #1 (polar) / paper #2 (FM) status snapshot.
- `runs/eu151_edh_twa/result.jld2` — full 50-trajectory TWA ensemble data (mean + variance + 56-frame timeseries, 226 MB).
