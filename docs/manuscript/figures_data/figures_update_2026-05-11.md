# Figure inventory — Round 7 (2026-05-11) update

本 doc は `shared/figures.md` の 2026-05-11 session updates。新 figures (本 session
で生まれた結果用) + data-ready figures の status update。

---

## New figures (Round 7 NEW)

### Paper #3 (Universal Theorem) — Sign Pattern + F=12

| Label | Description | Source / method | Status |
|---|---|---|---|
| `paper3_FIG-6` | **Sign Pattern Anomalous Identity** result — 5 polyhedral cases (F=3, 4, 6, 8, 10) showing β_S^{λ_spin} sign vs X_S^{(anom)} sign, with sign change locations marked | matplotlib stacked bar from `figures_data/sign_pattern_table.csv` | **data ready** |
| `paper3_FIG-7` | **Polyhedral inert state Majorana grid (F=2 to F=12)** — 7-panel Bloch-sphere figure covering Paper #3 §V.A–§V.G inert states, including F=12 I:A. Stars computed via `SpinorBEC.majorana_stars` (single source of truth); multiplicity-2 orbits at F=8 (cube) and F=12 (icosa) shown as larger markers | `scripts/cli.jl figure --paper paper3 --fig 6` → CSV → matplotlib (`fig-7_paper3_majorana.py`) | **rendered** |
| `paper3_FIG-8` | **F-universality of I_h selection rule** — exclusion pattern $\{S=2,4,8,14\}$ shared across F=6, F=10, F=12 (bar chart with $\beta_S^{c_0}$ heights, zero entries highlighted) | matplotlib from CSV | data ready |
| `paper3_FIG-9` | **Schur isotropy verification heatmap** — $\langle F_a^2\rangle$ for each polyhedral case showing perfect $F(F+1)/3$ value (deviation < $10^{-12}$) | matplotlib from `audit_result_2026-05-11.md` table | data ready |

### Chapter 5 (TWA chaos)

| Label | Description | Source / method | Status |
|---|---|---|---|
| `thesis_FIG-5.4` | **σ/μ × √N scaling failure** — 17.7 → 41.5 → 259 across N (pinned Sinatra-clean) | matplotlib from `runs/twa_N_scan_pinned_16g/` | data ready |
| `thesis_FIG-5.5` | **Species ε_dd scan** — Cr/Eu/Er/Dy z-elongation + σ/μ chaos peak at marginal | matplotlib from `runs/twa_eps_dd_scan/` | data ready |
| `thesis_FIG-5.6` | **Resolution-matched GS profile comparison** — 16³×box=20 vs 16³×box=10 ground state density profiles, showing GS-resolution artifact | matplotlib from `runs/twa_sinatra/` (gone) | data ready |

### Appendix E (verify-first audit details)

| Label | Description | Source / method | Status |
|---|---|---|---|
| `thesis_FIG-E.1` | **Bug catch summary** — icosahedral 3-fold axis (correct vs wrong) + A_2 character C_4-square criterion (correct vs wrong) — visual schematic | TikZ diagram | placeholder |
| `thesis_FIG-E.2` | **Audit framework flow chart** — paper3_audit.jl execution flow (spin matrices → group closure → projector → spinor → sanity checks → selection rule) | TikZ flowchart | placeholder |

---

## Updated status of existing placeholders

Round 4-6 era placeholders, some now have data:

| Label | Round 7 status |
|---|---|
| `paper2_FIG-3` (F=6 phase diagram with Eu marker) | **data ready** (runs/F6_phase_diagram/result.json) |
| `paper3_FIG-3` (selection rule bar chart) | **data ready** (from `audit_result_2026-05-11.md`) |
| `paper3_FIG-4` (F-systematic multiplicity heatmap) | **data ready** (Appendix D §D.5 Table II) |
| `thesis_FIG-5.2` (Eu EdH 50-trajectory ensemble) | **data ready** (runs/eu151_edh_twa/result.jld2) |

---

## Rendering pipeline

For figures with "data ready" status, the rendering pipeline:

### CSV / JSON → matplotlib (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("docs/manuscript/figures_data/sign_pattern_table.csv")

# Group by F and plot β_S^{c0} + X_S^{anom} together
fig, axes = plt.subplots(5, 1, figsize=(10, 12))
for ax, (F, group) in zip(axes, df.groupby("F")):
    ax.bar(group["S"], group["X_S_anom"], color=["red" if x < 0 else "blue" for x in group["X_S_anom"]])
    ax.set_title(f"F = {F}, {group['group_irrep'].iloc[0]}")
    ax.axhline(0, color="black", linewidth=0.5)
plt.tight_layout()
plt.savefig("paper3_FIG-6.pdf")
```

### JLD2 → Julia + Plots

```julia
using Plots, JLD2
result = load("runs/twa_N_scan_pinned_16g/N100000_pinned_16g_e439bbff/result.jld2")
# Extract σ/μ time series, plot
```

Both pipelines deterministic, can be added to `scripts/cli.jl figure`.

---

## Submission-ready figure list

End-state figures for 修論 submission:

### Paper #1 (F=2 cyclic LHY)
- FIG-1: tetrahedron Majorana (placeholder)
- FIG-2: BdG block decomposition schematic (placeholder)
- FIG-3: φ₁^reg profile (placeholder, data eval'd in `phi_one_reg.jl`)

### Paper #2 (F=6 icosahedral LHY)
- FIG-1: icosahedron Majorana (placeholder)
- FIG-2: mod-5 block schematic (placeholder)
- FIG-3: Eu phase diagram (data ready)
- FIG-4: Feshbach realizability (placeholder)

### Paper #3 (Universal Structure Theorem)
- FIG-1: T_1 irreducibility schematic (placeholder)
- FIG-2: 4-panel polyhedral Majorana (placeholder)
- FIG-3: selection rule bar (data ready)
- FIG-4: F-systematic heatmap (data ready)
- FIG-5: master classification flowchart (placeholder)
- **FIG-6**: Sign Pattern Anomalous Identity (data ready) ← Round 7 NEW
- **FIG-7**: Polyhedral inert state Majorana grid (F=2 to F=12, 7-panel) (rendered)
- **FIG-8**: F-universality of selection rule across F=6/10/12 (data ready)
- **FIG-9**: Schur isotropy verification heatmap (data ready)

### Paper #4 (TWA chaos)
- FIG-1: TWA noise-injection schematic (placeholder)
- FIG-2: σ/μ peak vs N coupling scan (data ready)
- FIG-3: σ/μ × √N scaling failure (data ready) ← Round 7 NEW
- FIG-4: Species ε_dd universality (data ready) ← Round 7 NEW
- FIG-5: GS-resolution caveat comparison (data ready) ← Round 7 NEW

### 修論本体
- Reuse paper figures + add Master flowchart (Ch.7 summary) (placeholder)

---

## Estimated work remaining

For all figures to be submission-ready:

| Type | Count | Estimated effort |
|---|---|---|
| matplotlib from CSV / JSON | 8 (data ready) | 1-2 days |
| matplotlib from JLD2 runs | 5 (data ready) | 2-3 days |
| Mathematica / three.js Majorana | 4 (placeholders) | 2-3 days |
| TikZ schematics / flowcharts | 8 (placeholders) | 2-3 days |
| **Total** | **25 figures** | **~1-2 weeks dedicated** |

Year 1 Q1 budget (= post-修論 submission push): ~1 week dedicated figure work, mostly
matplotlib + TikZ. Mathematica Majorana figures can be done in parallel by collaborator
familiar with Mathematica.

---

## Connection to `submission_packaging.md`

Figures workflow integrates into `docs/manuscript/submission_packaging.md` §4.3:

- Figure PDFs in `docs/manuscript/<paper>/figures/<figXX>.pdf`
- LaTeX `\includegraphics` reference with stable labels (= this inventory's labels)
- Cross-paper figure sharing (e.g., `paper1_FIG-1` reused in `thesis_FIG-3.2`)
- Supplementary material: high-resolution figures + raw data CSV files

---

(figures_update_2026-05-11.md 終了)
