# eu151_edh_v2 — Matsui-aligned canonical EdH

Consolidated improvement of all previous EdH runs in this repo:

```
runs/eu151_edh/                — baseline (1.5 ms only, c1=0, N=10k)
runs/eu151_edh_c1phys/         — c1=0.003 (lower-bound estimate)
runs/eu151_edh_K3_long/        — 14.5 ms with K3 + γ_dr loss
runs/eu151_edh_k3_compare/     — A/B K3 comparison (single value)
runs/eu151_edh_loss_factorial/ — 2×2 K3 × γ_dr factorial
runs/matsui_baseline/          — N=5e4, c1=1/36, 40 ms loss-free + K3 sweep
                                 (matsui_40ms_dynamics_n64,
                                  matsui_40ms_lossy_K3factor_5..30,
                                  matsui_40ms_lossy_medium, _strong)
```

## What this run is for

- A single, well-documented Matsui-aligned EdH config that uses **the
  K_3 value calibrated against Matsui's experimental ~40% atom loss**
  (from the K3 fine bracket scan), at the **real Matsui parameter
  set** (N = 5×10⁴, c₁/c₀ = 1/36, full 40 ms hold).
- Two cells in one YAML via `scan.comparison_runs`:
  - `lossfree` — Matsui's loss-free simulation reference
  - `K3_calibrated` — K_3 = 2.1×10⁻⁴⁰ m⁶/s (≈ 21 × Dy proxy)
- Trajectory + plot scripts co-located in this directory.

## What changed vs prior EdH runs

| key                | prior EdH        | this run (v2)    | source                                        |
|--------------------|------------------|------------------|-----------------------------------------------|
| N                  | 10 000 (most)    | 50 000           | matsui_baseline / real Matsui                 |
| c₁/c₀              | 0 or 0.003       | 1/36 = 0.02778   | Matsui best-fit                                |
| initial state      | m_plus_F, Bz > 0 | m_minus_F, Bz < 0| project sign convention (matsui_baseline)      |
| grid box           | [20, 20, 20]     | [12, 12, 12]     | matsui_baseline (finer dx at same n_grid)      |
| LHY                | scalar           | none             | F=6 ablation: scalar = no-LHY                  |
| Loss channels      | γ_dr 0.02 + K3   | K3 alone         | K3 calibration; γ_dr would double-count        |
| K_3                | 1×10⁻⁴¹ m⁶/s     | 2.1×10⁻⁴⁰ m⁶/s   | K3 fine bracket → Matsui ~40% loss             |
| Hold duration      | 1.5–14.5 ms      | 40 ms (27.6 ω⁻¹) | Matsui Fig. 2 timeline                         |
| GS n_steps         | 100 000          | 2 000            | matsui_baseline (sufficient at this convergence)|
| Multi-cell pattern | single config    | comparison_runs  | k3_compare / loss_factorial                    |

## K_3 calibration data

From `matsui_40ms_lossy_K3factor_*` runs (proxy = 1.0×10⁻⁴¹ m⁶/s):

| K3 / proxy | N(40 ms) / N(0) | Fz/N final | P_{-5,-4} max |
|-----------:|----------------:|-----------:|--------------:|
|     0      | 1.000           | (loss-free)| 0.50          |
|     5      | 0.865           | −4.82      | 0.502         |
|    10      | 0.762           | −4.94      | 0.500         |
|    15      | 0.681           | −4.87      | 0.499         |
|  **20**    | **0.615**       | **−4.86**  | **0.497**     |
|    25      | 0.561           | −4.89      | 0.495         |
|    30      | 0.516           | (similar)  | (similar)     |
|   100      | 0.244           | (large)    | (similar)     |

Linear interpolation: **K_3 ≈ 21 × proxy = 2.1×10⁻⁴⁰ m⁶/s** for
Matsui's experimental N(40 ms)/N(0) ≈ 0.60.

Observation: **P_{-5,-4} max ≈ 0.50 across all K_3 in [0, 25]** — the
EdH cascade morphology is robust to phenomenological loss; only the
atom-number amplitude depends on K_3.

## How to dispatch

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  julia --project=. -e 'import CUDA; using SpinorBEC; run_yaml("runs/eu151_edh_v2/config.yaml")'
```

The `comparison_runs` scan produces two run directories:

```
runs/eu151_edh_v2_lossfree_<hash>/
runs/eu151_edh_v2_K3_calibrated_<hash>/
```

Wall time on GPU (64³, 40 ms hold, single cell): ~30–60 minutes.
Total for both cells: ~1–2 hours.

## How to analyze

After dispatch:

```bash
# Extract per-frame observables → trajectory.json
julia --project=. runs/eu151_edh_v2/extract_trajectory.jl

# Plot N(t), Fz(t), N_m(t), peak(t) → trajectory.png
python3 runs/eu151_edh_v2/plot_trajectory.py
```

## Files in this directory

- `config.yaml`               — the canonical Matsui EdH YAML
- `README.md`                 — this file
- `extract_trajectory.jl`     — post-process result.jld2 → trajectory.json
- `plot_trajectory.py`        — produce 2×2 figure from trajectory.json
- (after dispatch + extract):
  - `trajectory.json`         — per-frame observables for both cells
  - `trajectory.png`          — 4-panel figure

## Caveats

1. **K_3 = 2.1×10⁻⁴⁰ m⁶/s is a phenomenological calibration**, NOT a
   measurement of Eu's actual three-body rate (which is unknown).  It
   reproduces Matsui's atom loss; what physical channel saturates that
   rate is an open experimental question.
2. **No LHY** — the F=6 ablation (2026-05-07 audit; eu_k3_lhy_control
   2×4 factorial) showed scalar LHY ≡ no LHY at F=6 in collapse stress
   regimes.  If high-density runaway is seen in the Matsui regime, the
   project-validated path is to add polar_contact or icosahedral LHY
   closures (not scalar).
3. **No γ_dr** — eu151_edh_K3_long and loss_factorial bundled
   γ_dr=0.02 with K_3.  v2 drops γ_dr because the K_3 calibration
   alone already matches the experimental loss; including γ_dr would
   double-count.
4. **Bz sign convention**: project uses Bz<0 for m_minus_F GS.  Older
   EdH cells used Bz>0 with m_plus_F initial state — they relax via
   ITP to the same magnitude of spin polarisation but with opposite
   sign of m.  Match the convention to project standard for direct
   comparability with klaus_quench / matsui_baseline outputs.
