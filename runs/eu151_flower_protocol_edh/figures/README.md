# Eu-151 Flower Protocol (EDH) — Figures

This directory holds **committed** rendered media (PNG / GIF) from the
flower-protocol simulations. Heavy raw data (`*.h5`, `*.jld2`) lives
under `../data/` and is **not** tracked.

## Naming convention

```
figures/<experiment>/<render_kind>_<threshold>_<components>[_<frame_label>].<ext>
```

- `<experiment>`        — e.g. `b_sweep_pm60uG`, `goto_protocol_10mG`
- `<render_kind>`       — `isosurface`, `volume_density_phase`, `tilted_pair`, …
- `<threshold>`         — `mass95` (95 % cumulative mass) or `peakNN` (NN % of frame peak)
- `<components>`        — `m6`, `m6m5m4`, etc.
- `<frame_label>`       — e.g. `Bp65uG`, `Bm10uG`, `t0`. Omit for full time-lapse GIF.

A bare `.gif` is the time-lapse / parameter sweep; PNGs are highlight
snapshots.

## Current contents

### `b_sweep_pm60uG/` — quasi-static B sweep from +65 → −10 μG (10 frames)

| File | Source script | Source data |
|---|---|---|
| `isosurface_mass95_m6m5m4.gif`        | `scripts/flower_protocol_edh/plot_b_sweep_3d_isosurfaces_95mass.py` (looped over B index) | `data/b_sweep_3d_components.h5` |
| `isosurface_mass95_m6m5m4_Bp65uG.png` | same, single frame at B = +65 μG | same |
| `isosurface_mass95_m6m5m4_Bm10uG.png` | same, single frame at B = −10 μG | same |

### `goto_protocol_10mG/` — full Goto RTP trajectory from 10 mG → 0 G

| File | Source script | Source data |
|---|---|---|
| `volume_density_phase.gif`                  | `scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py`           | `data/rtp_10mG_goto.h5` |
| `isosurface_mass95_m6_t0.png`               | `scripts/flower_protocol_edh/plot_goto_3d_isosurface.py`                       | same |
| `isosurface_peak30_m6.gif`                  | `scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6.py`              | same |
| `isosurface_peak30_m6m5m4_secondhalf.gif`     | `scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py` (`ISO_PEAK_RATIO_M6=0.30`) | same |
| `isosurface_peak70m6_30m5m4_secondhalf.gif`   | same script, default per-component ratios | same |

`peak30` = uniform 30 % × per-component peak (m=-5/-4 well-resolved, m=-6
shows its bulk envelope). `peak70m6_30m5m4` = stricter 70 % × peak on the
m=-6 panel to expose the DDI-driven prolate (lemon-shaped) tip that the
30 % cut smears out, while keeping m=-5/-4 at 30 % so they remain visible.
The `secondhalf` suffix crops to t > 125 ms (|B| < ~500 μG) where the
spinor dynamics activate and m=-5, -4 populations become non-trivial.

## Regenerating

All scripts read input H5 via `RTP_H5` / `GOTO_H5` / `FPE_ROOT` env vars
and write output via `OUT_GIF` / `OUT_PNG`. On Tsubame the data lives at
`/gs/fs/tga-kozuma-kouhi/ue06186/bec-runs/flower_protocol_edh/`; locally
the canonical landing is `runs/eu151_flower_protocol_edh/data/` (untracked).
