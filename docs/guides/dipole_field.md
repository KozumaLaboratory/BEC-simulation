# Dipolar magnetic field radiated by a cloud

> **FROZEN 2026-06-10.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

The field a spin-polarised condensate radiates is the magnetostatic analogue
of the DDI mean-field potential: the same k-space convolution with the dipole
kernel `Q_αβ = k̂_α k̂_β − δ_αβ/3`, only the prefactor differs (μ₀·moment for a
field, μ₀·moment² for an energy). This is the in-project replacement for the
MATLAB DBEC-GP post-processing (Kishor Kumar et al., CPC **195** (2015) 117) —
the density comes from a SpinorBEC ground state instead of `imag3d-den.txt`.

```
B_α(r) = -μ₀ · ℱ⁻¹{ Σ_β Q_αβ(k) M̃_β(k) }
```

`Q(k=0)=0` automatically drops the uniform/contact (Fermi δ) term — the same
term the MATLAB reference discards by hand. The kernel is **scale-free** (it
depends only on the direction of `k`), so the field of a magnetised body
depends on its *shape* and magnetisation [A/m], not its absolute size; B comes
out in tesla as long as the magnetisation is physical.

## API (`src/analysis/dipole_field.jl`)

| Function | Input | Use |
|---|---|---|
| `dipole_magnetic_field(grid, Mx, My, Mz; mu0, padded)` | magnetisation `M` [A/m] | core; any magnetisation field |
| `magnetic_field_from_density(grid, density; atom, a_ho, n_atoms, polarization, padded)` | normalised density (∫ρ dV=1) | fully spin-polarised cloud |
| `magnetic_field_from_spinor(psi, grid, sm, atom; a_ho, n_atoms, padded)` | spinor `ψ` | general / textured magnetisation |

All return `(Bx, By, Bz)` real arrays in tesla.

- `a_ho` [m] is the harmonic-oscillator length the internal grid is expressed
  in; `n_atoms` the total atom number. Physical density `n = density·n_atoms/a_ho³`,
  magnetisation `M = atom.mu_mag·n` (saturation moment `g_F·F·μ_B`).
- `padded=true` (default) zero-pads to a doubled grid → open-boundary (linear)
  convolution matching `convn(...,'same')`; the long-range 1/r³ tail makes this
  the safer choice. `padded=false` is the cheaper periodic form.

## Plotting

`plot_dipole_field(grid, density, Bx, By, Bz; plane=:xz, ...)` (Makie
extension) draws the x–z view from the MATLAB reference: a |B| heatmap, the
in-plane field as a quiver, and a density contour outlining the gas. Needs a
Makie backend (`using CairoMakie`) loaded on top of `SpinorBECMakieExt`.

## Demo

```bash
julia --project=. scripts/dipole_field_demo.jl [outdir]
```

Builds an oblate spin-polarised ¹⁵¹Eu cloud, computes the self-field, adds an
external z bias, and reports the local tilt angle of the total field away from
ẑ (the input to the rotation / Larmor analysis). Writes the x–z slices to
`dipole_field_xz.jld2` and, if a Makie backend is installed, PNGs.
