# Overnight v8 — high-res EdH vs Flower CSS-ness re-sim (2026-07-16, launched ~01:05)

## ✅ COMPLETE (fetched ~10:20). Products in `figures/v8/`:
- `css_analysis_v8.png` — quantitative: EdH s̄ drops from t≈25 ms, cores to ~0.1, ~15 % non-CSS mass;
  Flower stays s≡1. Global Pythagoras <1 for EdH only. (Physics as predicted.)
- `css_volume_v8.mp4` — 3D non-CSS isosurface (96³, smooth): EdH grows a **structured equatorial
  ring pinched along z=B** (rank-2 signature); Flower has NO red (fully CSS). bulk s: EdH 0.971 / FL 1.000.
- `css_slices_v8.mp4` — full-grid orthogonal slices, time-aligned EdH|Flower.
- `edh_v8_3d_spin_texture.mp4`, `flower_v8_3d_spin_texture.mp4` — proven v6 spin-texture renders.
Sims: EdH goto.h5 5.3 GB / 150 frames, Flower 3.1 GB / 87 frames (raw pruned). Both node_q, ~2 h each.

**One issue hit + fixed:** TSUBAME's ffmpeg 8.0.1 (CUDA build) has no libx264/`-crf`, so the two CSS
mp4 encodes failed initially (frames were fine). Re-encoded from the existing PNG frames with
`-c:v mpeg4 -q:v 3` (portable). Source scripts patched to mpeg4 + re-synced so re-runs won't hit it.
Cosmetic: css_volume title text overlaps slightly — can re-encode cheaply if a v2 is wanted.

---


## What was requested
High-quality, research-level re-simulation + analysis on TSUBAME, products (mp4/figs) fetched
to local, **raw data stays on TSUBAME** (too heavy). New protocols:
- **EdH**: moderate-speed ramp down to **+26 µG**.
- **Flower (FL)**: slow ramp down to **+100 µG**.
Fine grid / fine dt / fine save cadence; better rendering (no coarse 32³ blockiness, respect
the full spatial extent).

## Decisions (and why)
- **Grid 96³** (box 18), f64 snapshots. Forced by disk: TSUBAME group storage has only **~102 GB free**
  (90 % full), so 128³ (~65 GB raw/run) was infeasible. 96³ is the validated v6 production grid and
  3× finer per dim than the 32³ the local `isoviz_dev/*.h5` were (that was the "coarse" complaint).
- **Reused the existing 96³ ground state** `cache/gs_10mG_c1_36_96.jld2` (no GS job needed).
- **Only additive changes** to the TSUBAME group clone (new configs + new render scripts). The
  validated `src/` (v6 physics) was NOT touched — bug-safety.
- **No psi13 / tomography this round** (disk). Focus = CSS-ness deliverables.
- **DDI = full (non-secular), verified.** The v8 configs mirror v6 (no explicit `ddi:` block), so DDI
  is atom-derived (Eu151 c_dd). The secular default was verified `false` in source
  (`src/.../schema/schema.jl:234` `FieldSpec(default=false)`; all `get(ddi,"secular",false)`), so the
  runs use full DDI — satisfying the "never secular" rule. An explicit `ddi:{secular:false}` block was
  deliberately NOT added: v6 (validated) has none, and adding an untested block risked zeroing c_dd
  (DDI off → no EdH). Bug-safety > literal explicitness, since the default is provably false.
- Ramps are **linear**, time-matched to 120 internal (~173.6 ms): EdH ramp 15 internal (~21.7 ms,
  "moderate") vs FL ramp 100 internal (~144.7 ms, "slow"); EdH lands at 26 µG (low field, less Larmor
  protection → expect partial CSS loss), FL at 100 µG (protected → expect CSS preserved).

## Files created (local + rsync'd to group clone)
- `runs/eu151_edh_vs_flower/edh_ramp26_v8.yaml`, `flower_slow100_v8.yaml`
- `scripts/edh_vs_flower/css_volume.py`  — 3D non-CSS-region isosurface + density envelope (no slicing)
- `scripts/edh_vs_flower/css_slices.py`  — smooth full-grid orthogonal slices, s-coloured, spin arrows
- `scripts/edh_vs_flower/css_analysis.py`— quantitative stills (s̄(t), non-CSS mass fraction, hist, Pythagoras)
- `scripts/edh_vs_flower/submit_{edh,flower,viz}_v8.sh`
All three render scripts validated locally on the 32³ data before launch.

## Jobs submitted (UGE, group tga-kozuma-kouhi)
- **8168815 edh_v8**    node_q, 12 h  (RTP → extract spin3d → goto.h5 → prune raw)
- **8168816 flower_v8** node_q, 12 h
- **8168817 viz_v8**    cpu_40, 8 h, held on the two sims → renders in `figures_v8/`:
  `css_analysis_v8.png`, `css_volume_v8.mp4`, `css_slices_v8.mp4`, `{edh,flower}_v8_3d_spin_texture.mp4`

Data on TSUBAME: `/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/` (raw pruned after goto.h5).
Budget: 344.68 pt available before launch (ample).

## Auto-fetch
Background watcher polls every 10 min and, when viz finishes, pulls **only** mp4/png/logs to
`runs/eu151_edh_vs_flower/figures/v8/` (never raw). Manual fetch anytime:
`bash <scratchpad>/fetch_v8.sh`  ·  status log: `<scratchpad>/watcher_v8_status.txt`.

## Expected physics (to verify from products)
EdH (26 µG) should show a spatially-localised **non-CSS region** (red isosurface / red slice shells)
where |⟨F⟩|/(nF) < 1 — the rank-2 (MDDI + qF_z²) shear pushing the local spinor off the max-spin
(CSS) manifold. Flower (100 µG, slow) should stay ~fully CSS (blue everywhere) — the adiabatic control.

## If something failed (for the morning)
- Check `figures/v8/*.log` (fetched) or on TSUBAME `edh_vs_flower_data/{edh,flower,viz}_v8.log`.
- `ssh t4 qstat` for job state.
- Re-fetch: `bash <scratchpad>/fetch_v8.sh`.
