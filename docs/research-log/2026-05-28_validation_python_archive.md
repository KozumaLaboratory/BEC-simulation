# scripts/validation/ + scripts/manuscript/ Python figure scripts — 2026-05-28

> **FROZEN 2026-05-28.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

8 standalone Python figure renderers retired. Each was a research-log
artefact tied to a specific JSON summary from a specific scan campaign
— bespoke matplotlib for a single weekly presentation, thesis figure,
or paper-3 sign-pattern visualization.

Per the scripts/ invariant in CONTRIBUTING.md, these don't fit category
1 (≤30 LOC pure dispatch) or category 2 (PackageCompiler). They're
700-800 LOC figure-specific code. Two outcomes per file:

- **Replaced by manuscript subsystem** (`src/manuscript/figures/`,
  rendered via `cli.jl figure --paper P --fig N`):
  - paper3 sign pattern figure → `paper3_fig2.jl` (β_S^λ / β_S^c0 prefactor)

- **Research log only** — bespoke figures for past presentations /
  thesis drafts. Future re-renders should be small Julia functions
  in `src/manuscript/figures/` keyed by paper+FIG-N, not loose
  Python scripts.

Recovery: `git show <commit>:scripts/validation/<name>.py`. Last
touched at SHA `2eab19f` (feat(figures): rotation-assisted EdH quench K1 v3 +
long-time vortex statistics).

## Inventory

| File | LOC | Purpose | Data source |
|---|---|---|---|
| `validation/make_klaus_long_time_figure.py` | 107 | K13 long-time vortex nucleation (Prasad timescale) | `runs/klaus_*/summary.json` |
| `validation/make_klaus_omega_refine_figure.py` | 118 | K14 Ω* parabolic fit | `runs/klaus_quench/summary.json` |
| `validation/make_klaus_quench_fig_k10.py` | 144 | K10 mechanism (z=0 density + phase, 4 cells) | `docs/manuscript/figures_data/klaus_quench_mode_extract.json` |
| `validation/make_klaus_quench_figures.py` | 815 | K1/K2/K3 — 10-cell klaus_quench 2-phase protocol scan | `runs/klaus_quench/summary.json` |
| `validation/make_klaus_vortex_figures.py` | 149 | K10v vortex + mass current + per-component L_z | klaus_vortex_diagnostics.jl JSON |
| `validation/make_manuscript_figures.py` | 609 | 4-figure thesis composer (per `four_figure_spec_2026_05_26.md`) | week_figures JSON inputs |
| `validation/make_week_figures.py` | 588 | Weekly presentation 4-figure layout (2026-05-26 framing) | multiple `runs/*/summary.json` |
| `manuscript/render_sign_pattern_fig.py` | 171 | paper3 FIG-6 sign-pattern visualization | `docs/manuscript/figures_data/sign_pattern_table.csv` |

## What replaces them

For paper figures: `cli.jl figure --paper paper3 --fig 2` (and other
keyed entries; see `list_manuscript_figures()`). The manuscript subsystem
emits matplotlib renderers alongside CSV/TikZ source under
`docs/manuscript/papers/<paper>/figures/`.

For one-off weekly / thesis-draft figures: write the renderer as a
docstring + `_emit_csv_py` call in a new `src/manuscript/figures/<name>.jl`
and register it in `MANUSCRIPT_FIGURE_REGISTRY`. The Python lives in a
heredoc inside the Julia builder so the CSV + py source go through the
same dispatch.
