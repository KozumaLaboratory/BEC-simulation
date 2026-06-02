# Sweep view — architecture

**Status (2026-06-02):** data contract + golden gating live (this commit).
`to_viewspec` resolver + Vega-Lite renderer + VSUP composition are
scheduled, schema slots reserved.

## The problem

Parameter sweeps live in many shapes (1D, 2D, 1D + multistart, 3D+time,
ensemble), and each carries many observables of different types (signed
± centred, positive monotone, wide-range quality metric, categorical,
spectrum). Hand-rolling a custom view per shape × observable is the
exact same anti-pattern as hand-rolling a custom physics step per
operator. **The class bug we are dodging:** rule duplication. If the
dispatcher rule "signed observable → cmocean balance with symmetric
clip" lives both in a React file and a Makie script and a docs table,
the three drift, the dashboard and the paper figure disagree, and
"verified implementations over claimed results" stops being true at
the visual layer.

## The architecture (one diagram)

```
                  ┌────────────────────────────────────────┐
                  │     SweepResult{axes, observables,     │
data ────────────▶│     data, meta}    (Julia struct)      │
                  └──────────────┬─────────────────────────┘
                                 │
                                 ▼
                  ┌────────────────────────────────────────┐
                  │  to_viewspec(::SweepResult; defaults)  │
                  │  ── single dispatcher ──               │
                  │     resolves per-cell fill_hex,        │
                  │     vmin/vmax, contour values,         │
                  │     dominant_m + decision_gap,         │
                  │     quality_alpha, layout              │
                  └─────────┬──────────────────┬───────────┘
                            │                  │
                ┌───────────▼──────┐   ┌──────▼──────────┐
                │ viewspec.json    │   │  SweepResult    │
                │ (Vega-Lite)      │   │  (in-memory)    │
                └───────┬──────────┘   └────────┬────────┘
                        │                       │
                ┌───────▼─────────┐    ┌────────▼────────┐
                │ React +         │    │  Makie          │
                │ vega-embed      │    │  plot_sweep     │
                │ (interactive    │    │  (publication-  │
                │  dashboard)     │    │   ready PDF)    │
                └─────────────────┘    └─────────────────┘
```

**Single source of truth = resolved viewspec.** Renderers paint, they do
not decide. The dispatcher runs once, in Julia, against `SweepResult`.

Why not "rules in docs, implemented twice":

  * Mechanical drift between two implementations is silent. Markdown
    can't enforce that a JS colormap LUT matches a Julia one.
  * `cmocean.balance` is the same name in two libraries with slightly
    different sample points; "ColorSchemes.jl balance" vs an npm port
    will differ at intermediate stops.
  * VSUP's tree-quantization parameters are tunable — implementing it
    twice is asking for the quantization tree to drift.

Resolving **per-cell fill hex in Julia** collapses the failure surface to
"painted correctly" vs "painted wrong" (visible to the eye); no JS-side
LUT can quietly diverge.

## Data contract (`src/analysis/sweep.jl`)

```julia
struct SweepAxis{T}
    name::Symbol; unit::String; scale::Symbol  # :linear | :log
    values::Vector{T}
end

Base.@kwdef struct SweepObservable
    key::Symbol; label::String; kind::Symbol
    scale::Symbol = :linear
    role::Symbol = :data        # :data | :quality | :mask
    center::Union{Nothing, Float64} = nothing
    oracle::Union{Nothing, Float64} = nothing
    oracle_label::Union{Nothing, String} = nothing
    index::Union{Nothing, Symbol} = nothing      # :m for spectrum
end

struct SweepResult
    axes::Vector{SweepAxis}
    observables::Vector{SweepObservable}
    data::Vector{Dict{Symbol, Any}}
    meta::Dict{Symbol, Any}
end
```

### Key design decisions

#### `m` is NOT an axis

`view_shape` dispatch uses `count(length(a.values) > 1 for a in axes)`.
If `m` (spinor component index) is parked in `axes`, every spinor sweep
unconditionally promotes to `axes_dim ≥ 3`, defeating the natural 2D
heatmap. `m` lives **inside** a `spectrum`-kind observable's `index`
field (e.g. `index=:m`). Axes are reserved for swept control parameters
(B, Ω, [seed], [time]).

#### Dominant-m via decision margin, NOT absolute purity

For a populations vector that sums to 1, `max(populations) >= 0.5`
always for the 2-state case. An absolute "purity < 0.4 → mixed" rule
**never triggers** for 50-50, leaving that boundary to snap to either
state under infinitesimal noise. The correct measure is the top-1 / top-2
**decision gap**:

```julia
perm = sortperm(populations; rev=true)
gap = populations[perm[1]] - populations[perm[2]]
dominant = gap < margin ? :mixed : m_values[perm[1]]
```

Behaviour:

| populations | top1 | top2 | gap | result @ margin=0.1 |
|---|---|---|---|---|
| 50-50 (2-state) | 0.50 | 0.50 | 0.00 | `:mixed` |
| 49-51 (noise) | 0.51 | 0.49 | 0.02 | `:mixed` |
| 40-35-25 (3-way) | 0.40 | 0.35 | 0.05 | `:mixed` |
| 70-15-15 | 0.70 | 0.15 | 0.55 | dominant |
| stretched (1-only) | 1.00 | 0.00 | 1.00 | dominant |

Default `margin = 0.1`. YAML-override (project / per-run) supported.

#### Symmetric clip = fixed `±F`, NOT data-driven

For signed observables (⟨F_z⟩, ⟨L_z⟩, ⟨F_x⟩) on F-spin BEC, the
**physical bound `±F`** is the default `(vmin, vmax)`. Rationale:

  * **Run-to-run comparability.** Data-driven clip means the same
    observable gets different colorbars on two runs of the same sweep;
    a polished-broken `⟨F_z⟩=4.5` and a scout-correct `⟨F_z⟩=0.226`
    would land on the same intense colour if vmax is each-run's own max.
  * **No artefact-driven scale.** Unconverged cells (the 4.5 artefact)
    don't inflate the colorbar of other runs.

Cost: small signals (≤ 1 on a ±6 scale) wash out. Override via the YAML
defaults layer when contrast tuning is needed:

```yaml
# config/sweep_view.yaml
per_run_overrides:
  "sprint5_M1_*":
    fz_total: {clip: [-4, 4], reason: "observed range ≤ |4.5|, headroom 4"}
```

When the user computes an override clip from data, the convention is
**converged-only with robust quantile (5th, 95th percentile)** — this
is the only place `‖∇E‖` enters the clip decision. Masking and scaling
are otherwise **separated**: a cell being unconverged doesn't touch
`vmin/vmax`, it touches `quality_alpha` (today: a bool `masked`).

#### `masked` today is bool, schema is reserved for `quality_alpha::Float64`

VSUP (Value-Suppressing Uncertainty Palette; Correll, Moritz & Heer
2018, CHI) maps two values per cell — value and uncertainty — onto one
palette via tree quantization. The natural composition is value→fill_hex
(today) + quality→alpha (tomorrow), kept **as separate fields** so:

  * The diff at the golden gate sees them independently. Changing the
    VSUP tree without changing the LUT still diffs.
  * The renderer composites at paint time, not in Julia. If a future
    requirement wants alpha-blending against a different background,
    no re-resolve.

Today: `masked: bool` (derived from `conv` column in `result.meta`).
Tomorrow: `quality_alpha: float ∈ [0, 1]` (derived from
`role=:quality` observable via VSUP). The golden table schema reserves
the slot.

## JSON / YAML boundary

| Object | Format | Why |
|---|---|---|
| `SweepResult` struct | Julia code | type-checked, in-memory |
| Per-cell golden table | **JSON** | machine-generated, machine-consumed, type-strict (no YAML implicit-typing footguns) |
| Resolved viewspec | **JSON** | Vega-Lite native; vega-embed expects JSON |
| Project defaults | **YAML** | human-edited; comments are load-bearing ("oracle 0.24 — F·Barnett/Zeeman @ B=100, Ω=0.6") |
| Per-run overrides | **YAML** | as above |
| Experiment configs | **YAML** | existing convention; sweep declaration can be inlined |

Test of intent: "do humans write this file by hand?" → YAML.
Everything else → JSON.

## Reference colormaps

Two LUTs in `src/analysis/sweep.jl`, both sampled at 256 entries and
versioned (`SWEEP_COLORMAP_VERSION = "1.0"`):

  * `sweep_balance_lut()` — cmocean `balance` (Crameri & Hartley 2020).
    11-stop sampling: deep blue → off-white → deep red. For signed
    observables with symmetric clip.
  * `sweep_viridis_lut()` — viridis. For `:positive` / `:wide`
    monotone observables. Use with `scale=:log` for `:wide` (e.g.
    `‖∇E‖` spanning ~5 orders).

Out-of-clip values saturate to the LUT endpoint (no extrapolation).
`NaN` → `#9aa0a6` (neutral grey) so unresolved cells are visibly
distinct from the balance LUT centre.

Future: cividis (color-blind-safe) as a `:positive` alternative,
toggleable per project via `config/sweep_view.yaml`.

## Golden gate workflow

```
1. Generate golden (today, manual):
     scripts/m1_sweep_golden_export.jl
     → runs/sprint5_M1_*/golden/per_cell_table.json

2. Implement to_viewspec (tomorrow):
     viewspec = to_viewspec(SweepResult; defaults_path="config/sweep_view.yaml")

3. Gate:
     for each cell:
         assert viewspec.marks[i].fill        == golden.cells[i].fz_total_fill_hex
         assert viewspec.marks[i].x           == golden.cells[i].B_nT
         assert isapprox(viewspec.vmin, golden.vmin; rtol=1e-10)
         ...
```

Image-level gating (PNG diff) is explicitly **not** the design.
Renderers differ in font metrics / anti-aliasing / tick placement;
chasing pixel parity is a time sink. Per-cell hex parity is both
stricter (catches off-by-one LUT bugs) and renderer-agnostic.

## Schema for `per_cell_table.json`

```jsonc
{
  "schema_version": "1.0",
  "colormap_version": "1.0",
  "F": 6,
  "axes": {
    "B_nT":  {"scale": "log",    "unit": "nT",  "values": [...]},
    "omega": {"scale": "linear", "unit": "ω_⊥", "values": [...]}
  },
  "observables": {
    "fz_total": {
      "kind": "signed", "label": "⟨F_z⟩",
      "vmin": -6.0, "vmax": 6.0,
      "colormap": "cmocean.balance", "colormap_version": "1.0",
      "center": 0.0, "oracle": 0.24,
      "oracle_label": "F·Barnett/Zeeman @ B=100, Ω=0.6"
    },
    "grad_norm": {
      "kind": "wide", "scale": "log", "role": "quality",
      "vmin": 1.0e-4, "vmax": 1.2,
      "colormap": "viridis", "colormap_version": "1.0"
    },
    "m_dist": {
      "kind": "spectrum", "index": "m",
      "margin": 0.1, "mixed_hex": "#9aa0a6"
    }
  },
  "cells": [
    {
      "B_nT": 100.0, "omega": 0.6,
      "fz_total": 4.501, "fz_total_fill_hex": "#7e1a25",
      "Lz": 5.86,        "Lz_fill_hex": "...",
      "grad_norm": 0.240,
      "m_dist_dominant_m": -6,
      "m_dist_decision_gap": 0.42,
      "masked": true
      // tomorrow (VSUP): "quality_alpha": 0.15
    }
  ],
  "meta": {...}
}
```

`schema_version` bump rules:

  * `1.0 → 1.1` (additive): new optional field (e.g. `quality_alpha`).
    Old gates still pass; new gates may use the new field.
  * `1.x → 2.0` (breaking): existing field renamed / removed / type
    changed. Old golden tables stop matching.

## What's next (in order)

1. **`to_viewspec(::SweepResult; defaults_path)`** — the resolver. Reads
   YAML defaults, emits both the viewspec.json (Vega-Lite spec) and
   the per_cell_table.json. Existing `write_golden_per_cell_table`
   gets called from inside the resolver.
2. **Vega-Lite renderer plumbing** — React `SweepView` component
   embedding the viewspec via vega-embed; linked brushing via Vega's
   selection grammar.
3. **`plot_sweep(::SweepResult)`** in `ext/SpinorBECMakieExt` —
   publication PDF / PNG from the same SweepResult. Reads the resolved
   per-cell fill (does NOT re-decide).
4. **VSUP composition** — promote `masked: bool` to
   `quality_alpha: float`. Tree quantization tuning lives in the
   resolver; renderers paint pre-composed alpha.

## Citation

VSUP: **Correll, Moritz & Heer (2018).** *Value-Suppressing Uncertainty
Palettes.* CHI Conference on Human Factors in Computing Systems.

cmocean `balance`: **Crameri, F., Shephard, G. E. & Heron, P. J.
(2020).** *The misuse of colour in science communication.* Nature
Communications 11:5444.
