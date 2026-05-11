# Migration guide — when conventions change

This codebase has accumulated several scattering / Zeeman / DDI conventions over time. When upgrading from an older snapshot, these are the spots to audit.

## Scattering interactions

**Old form**: `interactions: {a_s: 90.0, omega_ref: 50.0, N_atoms: 60000}` — schema validator emits `Unknown key 'a_s'` warning.

**Current form**: derive `c_total` / `c_dd` / `c_lhy` from `(N_atoms, omega_ref)` and pass `c_total` directly OR `c0`/`c1` directly:

```yaml
interactions:
  N_atoms: 60000
  omega_ref: 691.15      # rad/s convention internally
  c1_ratio: 0.028        # spin-dependent fraction
```

Or for explicit control:

```yaml
interactions: {c0: 4500.0, c1: 130.0}
```

`a_s` is on the AtomSpecies struct (used internally for c_total derivation) but NOT a YAML field. To override the published a_s, edit the AtomSpecies definition in `src/workflow/initialization/atoms.jl`.

## Zeeman levels

Three levels coexist in the same `zeeman:` block:

- **Level 0** (legacy): dimensionless `p`, `q`, `bx`, `by`
- **Level 1**: `Bx`, `By`, `Bz` in Gauss strings (`"0.819 Gauss"`)
- **Level 2**: `B_mag` + `theta_deg` + `phi_deg` (spherical spec)

Mixing levels in a single block raises `ArgumentError`. Pick one per step.

## Snapshot format

**Old (legacy)**: `dynamics/psi_snapshots` as a single 5D array `(n_pts..., n_comp, n_snaps)` ComplexF64.

**Current**: `dynamics/psi_snapshots_streamed/frame_NNNNN` (one entry per frame, ComplexF32 default; ComplexF64 with `save_snapshot_precision: "f64"`). The dashboard reader and `column_density_movie` analyzer accept both.

## Calibration auto-application

**Old**: lab-unit YAML required `run_yaml_calibrated(path; calibration_path=...)`.

**Current**: `run_yaml(path)` auto-detects `calibration:` (single) or `calibration_history:` + optional `target_date:` (interpolated) at the YAML root. The wrapper still works for explicit external calibration files.

## Snapshot reader path

If your script directly reads `dynamics/psi_snapshots` and now sees empty arrays, switch to the streamed path:

```julia
jldopen(jld_path, "r") do f
    n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
    for i in 1:n
        frame = f["dynamics/psi_snapshots_streamed/frame_$(lpad(i, 5, '0'))"]
        # ... use frame (ComplexF32 by default)
    end
end
```

## Pipeline analyzer return shape

Analyzers that gained extra fields (vortex_detect now returns `positions`, monopole_charge gains `max_abs_density`, etc.) are backward-compatible — they only added named-tuple fields. Old code that does `result.vortex_count` still works.

## PlotlyJS removed (2026-04-26)

PlotlyJS is no longer a dependency. Two user-visible consequences:

1. `column_density_movie` no longer writes PNG frames. Output is now:
   - `<output_dir>/columns.jld2` — Float32 2D array per frame, key `frame_NNNNN`.
   - `<output_dir>/manifest.json` — `n_frames`, `n_phases`, `axis`, `frame_keys`, `times`, `phase_indices`, `archive`.

Migration: any post-processing script that walked `frames/*.png` should switch to reading `frames/columns.jld2` directly:

   ```julia
   using JLD2, JSON
   manifest = JSON.parsefile("frames/manifest.json")
   jldopen(joinpath("frames", manifest["archive"]), "r") do f
       for k in manifest["frame_keys"]
           col = f[k]   # Float32 2D array
           # render however you like (Makie, Plots, matplotlib via PythonCall, …)
       end
   end
   ```

The dashboard renders frames client-side from the JLD2 archive.

2. `plot_density` / `plot_spinor` / `plot_spin_texture` / `animate_dynamics` are now Makie-only. Load a Makie backend (`using GLMakie` or `using CairoMakie`) before calling them. The Plotly variants and `save_column_density_png` no longer exist.

## `dry_run` returns the YAML string (2026-04-26)

Old form silently called `redirect_stdout(IOBuffer())` and returned nothing useful. New form: `run_yaml(path; dry_run=true)` prints the post-calibration / post-validation YAML to stdout **and returns the same content as a `String`**. Tests that previously captured stdout with `redirect_stdout` should switch to inspecting the return value.
