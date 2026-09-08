# Prior art — evaporation_optimization

> **FROZEN 2026-09-02.** A snapshot of the open work on evaporation_optimization as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: evaporation, evaporative, cooling, ramp, trap_depth, eta, runaway. Regenerate with
`python3 scripts/prior_art.py --topic evaporation_optimization --keywords evaporation evaporative cooling ramp trap_depth eta runaway`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/feat/evaporation-ramp-optimizer | superseded | branch:  | Already an ancestor of `main` (`git merge-base --is-ancestor` → 0). `optimize_ramp_monotone` / `optimize_ramp_coordinate` / `ramp_scale_powers` are in `src/solvers/evaporation/evaporation_optimize.jl` on this checkout. Nothing to pick up. |
| origin/feat/evaporation-k3-trap-shaping | read | branch:  | 2026-07-02, **unmerged**. 0-D two-component K₃ study, 4 axes. euv3 is **133× K₃-limited** (1.56e5 at K₃=0 vs 1.17e3 fitted). Back-half coordinate descent → **9.90×** (`figs/k3_dense_maps/d3_timing_schedule.csv`), converging in one pass (1169 → 10743 → 11584). Loosening during forced evaporation is **not** a lever (1.01× final-power, 1.11× waist — the ω̄^2.4 rate cut cancels against lower T_c); decompression helps only during a BEC hold (~1.3×). η_start is a **degenerate knob**: N₀ flat to 0.05 % over T₀ = 20–50 µK, with a cliff at ~60 µK as the positive control (`d2_eta_start_1d.csv`). **Its numbers are superseded by `fix/evaporation-parameter-free`** (a month newer, and it changes the condensate 3-body ⟨n²⟩ by 4/7 → 8/21 and drops the fitted K₃), and its schedule re-tightens the trap, which the newer guide says explicitly not to execute. |
| origin/fix/evaporation-parameter-free | depends | branch:  | 2026-08-05, **unmerged**, and does **not** contain the k3-trap-shaping branch. Drops the fit knobs (exact LRW rate, ab-initio K₃ = 1e-41, re-anchored T₀ = 18 µK) and fixes the 3-body convention. Carries `docs/guides/eu_evaporation_ramp_optimization.md`: over the **realizable monotone-decreasing** family the optimum beats euv3 r14 by **3.48×** (N_BEC 2.29e5 → 7.95e5, γ 1.64 → 3.03, BEC onset 1.44 s → 0.45 s) by **evaporating harder early** — HFORT from the loaded 4.0 W to ~0.08 W over the first 0.5 s. Guide's own caveats: **verification type B, not C**; absolute N over-predicts the measured 5.02e4 endpoint; and `optimize_ramp_coordinate` (the re-tightening family) must **not** be used for a schedule intended for execution. **`ramp_opt.csv` on that branch is inconsistent with its own guide** (7.4 s long, HFORT rising to 10 W then to 9 W at t = 6.7 s — not monotone, and the guide describes a 0.5 s drop), so the executable schedule cannot be transcribed from the committed artifact; `summary.txt` matches the guide and gives per-beam step ratios instead. Regenerate with the guide's Reproduce block **on that branch** before trusting any transcription. |
| #32 | unrelated | issue: feat: EdH vs Flower 判定 — smooth ramp vs Matsui-quench at 63 µG (K_3=10⁻⁴⁰, 質量流含む) | The "ramp" here is the magnetic-field quench schedule for the EdH/flower discrimination, not the FORT evaporation ramp. Shares only the K₃ parameter. |
| #75 | depends | issue: Eu evaporation-ramp optimization + parameter calibration (Miyazawa 2021 thesis) | The open issue this topic belongs to. Lab inputs (a_s = 135 a_B, ε_dd = 0.44, K₃ 1.2e-41 DIRECT vs 4.6e-42 BEC-fit ⇒ **~2.6× systematic**) — see `reference_miyazawa_2021_thesis_eu_evap_params`. The K₃ systematic is exactly why the model's absolute numbers cannot arbitrate and the objective was moved to the measured atom number. |

## Disposition summary (2026-09-02)

The optimization question is **largely answered in the model and not at all in the
lab**. Two independent 0-D studies agree on the direction and disagree on the
size (3.48× monotone / 9.90× re-tightening), both are verification type **B**,
and the newer one over-predicts the one measured endpoint there is. Eu's K₃ is
unmeasured across a 100× band.

What that licenses: taking the **mechanism** (evaporate hardest where the elastic
collision rate is highest — i.e. right after loading) as the direction to
perturb first, and taking **nothing** about the magnitude.

What it forbids: transcribing either optimized schedule into
`euv4_transfer.js`. One is the re-tightening family the guide says not to
execute; the other's committed ramp CSV contradicts its own guide.

Acted on instead: the objective was moved to the **measured** atom number
(`EVAP_OPT_MODE` in `euv4_transfer.js`), staged `noise` → `sens` → `search` so
that σ is measured before any difference is read.
