# Figures — rotating field → vortices + Barnett spin excitation (¹⁵¹Eu F=6)

All figures are line-based (no density heatmaps). Each `<name>.png` has a
matching `<name>.pdf`. Regenerate with the `plot_*.py` in the parent dir
(they write here automatically).

## Main story (current)

| Figure | What it shows | Script |
|---|---|---|
| `edh_baseline.png` | Einstein-de Haas: field quench → spin→orbital transfer, J_z conserved, quantised vortices ℓ=F−m | `plot_edh_baseline.py` |
| `barnett_direction_lines.png` | **Left/right rotation = exact mirror** (±Ω give opposite-sign vortices + Barnett), Ω=0.30 | `plot_direction_lines.py` |
| `resonance_onesided.png` | **One-sided (chiral) excitation** — field-down ground state, resonant −Ω excites + vortices, off-resonant frozen (28×) | `plot_resonance_lines.py` |
| `fieldup_onesided.png` | **Field-UP metastable + relaxation time** — large gap ω_L=5, only resonant +Ω Rabi-flops; vortices live in the slow relaxation channel | `plot_fieldup_onesided.py` |
| `cone_angle_scan.png` | **Best field tilt** — selectivity vs vortices vs cone angle θ; recommended θ≈25° | `plot_angle_scan.py` |
| `optimization_scaling.png` | Dense response sweeps: vortex ⟨L_z⟩ and Barnett ⟨F_z⟩ vs Ω (41 pts) and B_⊥ (30 pts) | `plot_scaling.py` |

## Earlier / auxiliary

| Figure | Note |
|---|---|
| `barnett_direction_definitive.png` | ±0.5 direction control (superseded by `barnett_direction_lines.png` at optimal Ω=0.30) |
| `master_figure.png`, `ddi_control.png`, `barnett_direction.png` | earlier composite / DDI on-off control panels |
| `vortex_timelapse.png` | vortex-core time lapse |
| `optimization_2d.png` | 2D Ω×B_⊥ optimum surface (if generated) |
