# R39 — BdG spectrum along R35 B-1 boundary

**Target**: produce a 2-D heatmap (boundary arclength × k) of
Re ω(k) along the B-1 phase boundary. Roton softening shows up as
a min(Re ω) dip toward zero where the modulation instability sets in.
Required figure for the Eu B-1 thesis chapter.

**Pre-flight (synthetic)**: F=1 weak-interaction at 3 boundary points
returns max_growth ≈ 0 (stable), 30/30 tests pass (commit afaf8c1).

## Pre-requisite

Run R35 first to produce `r35_b1_boundary_trace/trace.jld2`.

## Run

```julia
using SpinorBEC
using JLD2

# Load the boundary points from the R35 trace.
@load "runs/measurement_R3x_eu/r35_b1_boundary_trace/trace.jld2" trace
points = trace.points

# Use the R39 config to derive grid + atom + reference c_dd.
config = SpinorBEC.load_config("runs/measurement_R3x_eu/r39_bdg_along_b1/config.yaml")
gs_step = config.pipeline[1]
grid = SpinorBEC.make_grid_from_yaml(gs_step)
atom = SpinorBEC.atom_from_yaml(gs_step.atom)

# Compute spectra along the curve.
samples = bogoliubov_along_boundary_curve(
    points,
    θ -> (
        interactions = InteractionParams(
            gs_step.interactions.c0,
            θ[1] * gs_step.interactions.c0,
        ),
        enable_ddi = true,
        c_dd = θ[2] * <reference_c_dd>,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 1.182)),
    ),
    grid, atom;
    phase_init = :m_plus_F,
    k_max = 8.0, n_k = 64,
    k_direction = (0.0, 0.0, 1.0),
    n_steps = 500, tol = 1.0e-7,
    verbose = true,
)

@save "runs/measurement_R3x_eu/r39_bdg_along_b1/spectra.jld2" samples
```

## Plot recipe

```julia
using Plots, JLD2
@load "runs/measurement_R3x_eu/r39_bdg_along_b1/spectra.jld2" samples

n_pts = length(samples)
n_k = length(samples[1].bdg.k_values)
heatmap_data = zeros(Float64, n_k, n_pts)
for (i, s) in enumerate(samples)
    # Take the lowest-ω band (sorted) at each k as the "phonon branch"
    omega_sorted = sort(real.(s.bdg.omega); dims=1)
    heatmap_data[:, i] = omega_sorted[1, :]
end

heatmap(
    1:n_pts,                                # arclength index
    samples[1].bdg.k_values,                # k axis
    heatmap_data,
    xlabel = "boundary arclength (point index)",
    ylabel = "k",
    color = :viridis,
    title = "Re ω lowest band along B-1 boundary",
)
```

## Expected wall-time

- ~50 boundary points × (warm GS 30-60 s + BdG ~ 0.1 s) = 25-50 min
- BdG eigenvalue solve scales as O((2D)³) where D = 13 → 17576 ops
  per k, n_k = 64, total ~ 10⁶ ops, milliseconds. Cost is dominated
  by GS, not BdG.

## Roton signature

If the boundary crosses a roton-instability precursor, the lowest
band's min(Re ω) should dip below ~ 0.1 in dimensionless units in
the boundary segment near the precursor. If max_growth_rate goes
above 0 (Im ω ≠ 0), the instability is reached — the curve has
crossed into the modulation phase.
