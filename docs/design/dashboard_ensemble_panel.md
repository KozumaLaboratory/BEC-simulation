# Dashboard ensemble panel (Round-2 Task 5)

**Status**: scalar-summary surface shipped 2026-05-07. 3D mean/variance volume rendering deferred — the toggle row labels those modes "follow-up" rather than wiring partial behaviour.

## What it shows

Each ensemble phase exposes three Recharts panels and a stats strip:

| Panel | Source | Why |
|---|---|---|
| **on-axis ratio** vs t | `density/mean[cx, cy, cz, t] / max(mean[..., t])` | The Eu EdH headline: deterministic = 0.092, TWA mean = 0.416 (4.5× smearing). Plot makes the divergence visible per frame. |
| **σ/μ at peak** vs t | `sqrt(variance[argmax(mean), t]) / max(mean[..., t])` | Trajectory-level fluctuation at the densest voxel. Quantifies how strong quantum noise is at the collapse front. |
| **σ/μ histogram** (final frame) | All voxels with ⟨n⟩ > 1% peak, binned 0.05 wide on [0, 2] | Spatial structure of the noise — does it cluster around the peak or spread uniformly? |
| Stats strip | n_trajectories, n_frames, final on_axis, final σ/μ | One-glance acceptance/rejection of the run. |

The 1%-of-peak threshold on the histogram exists so vacuum voxels (where μ ≈ 0 makes σ/μ explode) don't dominate.

## Backend wiring

- Route: `GET /api/ensemble/:run/:file` → JSON
- Handler: `_route_ensemble` in `src/workflow/io/dashboard/routes.jl` — appended after `_route_snapshots`.
- Reads the layout written by `save_rotating_basis_result!`:
  ```
  dynamics/ensemble/phase_NN/
    n_trajectories : Int
    times          : Vector{Float64}
    density/mean       : Array{Float64, 4}  (nx, ny, nz, nt)
    density/variance   : Array{Float64, 4}
    magnetization/mean : Array{Float64, 5}  (3, nx, ny, nz, nt)
    ...
  ```
- Time series and the histogram are computed in `_density_scalars!` — pure-Julia loops over the 4D arrays. Cost: ~50 ms for a 32³×16-frame ensemble. No caching layer yet because the volume is small enough to recompute per request.

## Frontend wiring

- Component: `dashboard/src/components/EnsemblePanel.tsx` (≈260 lines)
- Props: `{ runName: string; fileName: string }`
- Aesthetic: matches `ScanGroupView` — Fraunces serif + JetBrains Mono, charcoal `#0e0f12` panels, teal `#7fb9a6` mean line, amber `#d6c7a8` σ/μ, red `#c97064` σ=μ reference. Staggered fade-in on mount.
- View-mode toggle row: `deterministic` / `single` / `mean` / `variance`. The first two are intentionally disabled with a `line-through` style — they belong to the (future) 3D-volume surface, not this scalar panel.

## What's deferred to a follow-up

3D volume rendering of `density/mean` and `density/variance`. Two ways to ship it:

1. **Reuse `density3d_bin`**: have `_route_density3d_bin` accept `?source=ensemble&phase=NN&kind=mean` so the existing WebGPU raymarcher loads ensemble volumes via the same path as `psi_snapshots_streamed`. Easiest if `View3D` already takes a generic "binary volume" prop.
2. **Mode-aware View3D**: thread an `EnsembleMode` enum through the 3D pipeline and switch shaders for variance overlay. Larger surface change.

The current scalar panel covers the most decision-relevant data (does the ensemble actually smear the on-axis hole? how much trajectory-level noise?) so the volume rendering is genuinely a "next iteration" rather than a prereq.

## Sample server response

```json
{
  "phases": [
    {
      "phase_idx": 2,
      "n_trajectories": 50,
      "times": [0.0, 0.0625, 0.125, ...],
      "observables": ["density", "magnetization", "component_density"],
      "density": {
        "has_mean": true,
        "has_variance": true,
        "shape": [32, 32, 32, 17],
        "peak_mean": [0.118, 0.116, ...],
        "on_axis_ratio_mean": [1.00, 0.96, ..., 0.416],
        "sigma_over_mu_at_peak": [0.0, 0.04, ..., 0.423],
        "sigma_over_mu_histogram": {
          "bin_edges": [0.0, 0.05, 0.10, ...],
          "counts": [1024, 832, ...],
          "n_voxels": 4892,
          "threshold_frac_of_peak": 0.01
        }
      },
      "magnetization": { "has_mean": true, "has_variance": true, "shape": [3, 32, 32, 32, 17] }
    }
  ]
}
```

## How to integrate the panel into a page

```tsx
import EnsemblePanel from './components/EnsemblePanel'

<EnsemblePanel runName="eu151_edh_twa" fileName="result.jld2" />
```

Drop into the existing dashboard layout next to the per-trajectory `View3D` once a parent page exists. (No global page-level integration yet — wiring into `App.tsx` requires the run-picker to know which runs have ensemble data, which is a separate UX decision.)
