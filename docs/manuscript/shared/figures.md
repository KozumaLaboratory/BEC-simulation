# Figure inventory across papers and thesis

Refinement-round-1 list. Each entry has:

  * a stable label (e.g. `paper3_FIG-2`) used as the placeholder in
    draft markdown,
  * a brief description,
  * a candidate generation method (Majorana visualisations are most
    naturally Mathematica or Three.js exports; data plots are
    matplotlib / Plots.jl from the analysis JSONs),
  * a status flag.

When a figure is generated, drop the rendered `*.pdf` (or `*.svg`) into
`docs/manuscript/thesis/figures/` (or the relevant paper subdirectory)
with the same stable label as filename.

## Paper #1 — F=2 cyclic LHY closed form

| Label | Description | Source / method | Status |
|---|---|---|---|
| `paper1_FIG-1` | F=2 cyclic Majorana tetrahedron (4 stars at vertices of a regular tetrahedron on the Bloch sphere) | Mathematica `MajoranaPlot` or three.js polyhedron | placeholder |
| `paper1_FIG-2` | BdG block decomposition schematic for F=2 cyclic (5×5 matrix factoring into 1+1+3 blocks under T_d) | TikZ block-diagram | placeholder |
| `paper1_FIG-3` | φ₁^reg(t) profile vs Petrov regulariser (knot points + analytic comparison) | matplotlib from `phi_one_reg.jl` evaluation grid | placeholder |

## Paper #2 — F=6 icosahedral LHY closed form

| Label | Description | Source / method | Status |
|---|---|---|---|
| `paper2_FIG-1` | F=6 icosahedron Majorana visualisation (12 stars at icosahedron vertices on the Bloch sphere) | Mathematica `MajoranaPlot` from `ZETA_F6_IH` | placeholder |
| `paper2_FIG-2` | Mod-5 block structure for I_h (26×26 → 5 blocks labelled by 5-fold rotation eigenvalue) | TikZ block-diagram | placeholder |
| `paper2_FIG-3` | F=6 (g_10, g_12) phase diagram with overlay of linearised I_h↔FM and I_h↔polar boundaries; Eu marker at (1, 1) | matplotlib from `runs/F6_phase_diagram/result.json` | data ready |
| `paper2_FIG-4` | Eu Feshbach realizability map (proposed engineered g_S regions vs current Eu values) | matplotlib + literature data | placeholder |

## Paper #3 — Universal Structure Theorem

| Label | Description | Source / method | Status |
|---|---|---|---|
| `paper3_FIG-1` | T_1 irreducibility under polyhedral groups — visualisation of why the spin-Goldstone block is invariant only under the polyhedral subgroup | TikZ + Bloch-sphere insets | placeholder |
| `paper3_FIG-2` | Four polyhedral spinor Majorana visualisations side-by-side: F=2 (tetrahedron), F=4 (cube), F=6 (icosahedron), F=10 (dodecahedron) | Mathematica multi-panel | placeholder |
| `paper3_FIG-3` | Selection rule pattern — bar chart of g_S contributions per phase, showing which channels cancel under each polyhedral symmetry | matplotlib stacked bar | placeholder |
| `paper3_FIG-4` | F-systematic multiplicity table (heatmap of `ν_block` for F=2..10 phases × phonon/spin block) | matplotlib heatmap | placeholder |
| `paper3_FIG-5` | Master classification flow diagram — from F to ground-state symmetry to BdG block structure to LHY closed form | TikZ flowchart | placeholder |

## Master thesis figures

### Ch. 3 — F=2 cyclic

| Label | Description | Status |
|---|---|---|
| `thesis_FIG-3.1` | F=2 phase diagram (g_1 vs g_2 plane), with cyclic / polar / FM / BN regions labelled | placeholder |
| `thesis_FIG-3.2` | Reuse `paper1_FIG-1` (Majorana tetrahedron) | shared |
| `thesis_FIG-3.3` | Selection-rule unification diagram (Sec 3.7) | placeholder |
| `thesis_FIG-3.4` | F-systematic classification preview (Sec 3.8) | placeholder |

### Ch. 5 — TWA methodology

| Label | Description | Source / method | Status |
|---|---|---|---|
| `thesis_FIG-5.1` | TWA noise-injection schematic (Wigner sample on grid) | TikZ | placeholder |
| `thesis_FIG-5.2` | Eu EdH 50-trajectory ensemble: deterministic vs ensemble mean density profiles, FWHM comparison | matplotlib from `runs/eu151_edh_twa/result.jld2` | data ready |
| `thesis_FIG-5.3` | Coupling-strength scan (N=10³, 10⁴, 10⁵) — peak n / FWHM / σ-over-μ vs N | matplotlib from N scan results | data ready |
| `thesis_FIG-5.4` | Pinned 1/N validity test — Δrel × N and σ/μ × √N vs N | matplotlib from pinned re-run results | awaiting data |
| `thesis_FIG-5.5` | Sinatra criterion validation — σ/μ at peak vs Sinatra ratio across 3 grid+cutoff configs | matplotlib from `runs/twa_sinatra_validation/` | awaiting data |
| `thesis_FIG-5.6` | ε_dd species scan — Cr/Eu/Er/Dy on-axis ratio + FWHM_z / FWHM_x | matplotlib from `runs/twa_eps_dd_scan/` | awaiting data |

### Ch. 6 — Icosahedral / polyhedral

| Label | Description | Status |
|---|---|---|
| `thesis_FIG-6.1` | Reuse `paper2_FIG-1` (F=6 icosahedron Majorana) | shared |
| `thesis_FIG-6.2` | Reuse `paper2_FIG-3` ((g_10, g_12) phase diagram) | shared |
| `thesis_FIG-6.3` | F=4 cube Majorana visualisation (Sec 6.6) | placeholder |
| `thesis_FIG-6.4` | F=10 dodecahedron Majorana visualisation (Sec 6.7) | placeholder |
| `thesis_FIG-6.5` | Master verification summary table (Sec 6.8) | placeholder (table, not figure) |

## Status legend

* `placeholder` — figure not yet drawn; markdown carries `[FIG: <label>]`
  marker.
* `data ready` — analysis JSON / JLD2 exists in repo; figure is a
  matplotlib script away.
* `awaiting data` — depends on a still-pending GPU run.
* `shared` — figure is generated for one document and re-used in
  another. Generate once, import twice.

## Generation pipeline (to be created later)

* `docs/manuscript/scripts/make_figures.py` will iterate over the
  `data ready` / `awaiting data` entries and produce the matplotlib
  PDFs.
* Mathematica / Three.js Majorana visualisations are one-off renders;
  source notebooks / HTML go in
  `docs/manuscript/thesis/figures/sources/`.

## TODO before submission

* Decide colour palette per paper (PRA / PRR style guides differ).
* Convert all matplotlib outputs to PDF + LaTeX-friendly fonts.
* Add CC-BY licence metadata to original figures.

## Paper #4 — Chaotic dipolar instability (added 2026-05-12)

| Label | Description | Source / method | Status |
|---|---|---|---|
| `paper4_FIG-1` | Mean-field GP-LHY post-quench density snapshot at t=5 (Eu params, filament pattern) | Plots.jl from `runs/paper4_meanfield/result.jld2` (planned) | placeholder |
| `paper4_FIG-2` | σ/μ vs N showing 1/√N breakdown (N = 10³, 10⁴, 10⁵ from Round-5 GPU + Round-6 Sinatra-clean) | matplotlib from `runs/sigma_mu_scan_round5/result.json` (planned) | placeholder |
| `paper4_FIG-3` | Species universality: σ/μ vs ε_dd (Cr=0.15, Eu=0.55, Er=0.88, Dy=1.39) showing chaos-onset peak at Eu | matplotlib from `runs/species_scan_round6/result.json` (planned) | placeholder |
| `paper4_FIG-4` | Lyapunov trajectory divergence: ‖Δζ(t)‖ for two nearby Wigner seeds — exponential growth + amplitude saturation | matplotlib from `runs/lyapunov_diagnostic_round6/result.jld2` (planned) | placeholder |
| `paper4_FIG-5` | 50-trajectory ensemble traces at Eu (overlay of |ψ(t,x_center)|² for 50 Wigner samples) | matplotlib from `runs/ensemble_traces_round5/snapshots/` (planned) | placeholder |
