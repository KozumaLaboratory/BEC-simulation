# R35 — B-1 boundary trace

**Target**: trace the FL ↔ uniform-polarization boundary in
(c₁_ratio, c_dd_ratio) space via pseudo-arclength continuation.
Replaces the 121-point 2-D grid scan (60 h baseline) with ~ 100 traced
points (≈ 1 h).

**Pre-flight (synthetic)**: 100 % residual < 1e-7 on vertical line +
unit circle (commit 4c26d76). On F=1 SpinorBEC the polar↔FM signs
match the canonical phase diagram (commit 018b4d4).

## Run

```julia
using SpinorBEC
using JLD2

# Load the Eu config and instantiate the grid + atom once.
config = SpinorBEC.load_config("runs/measurement_R3x_eu/r35_b1_boundary_trace/config.yaml")
gs_step = config.pipeline[1]                  # GroundStateStep
grid = SpinorBEC.make_grid_from_yaml(gs_step)
atom = SpinorBEC.atom_from_yaml(gs_step.atom)

# Build the F(θ) = E_FL - E_uniform closure.
F = make_phase_diff_eval(grid, atom;
    parameter_setter = θ -> (
        interactions = InteractionParams(
            gs_step.interactions.c0,    # c₀ fixed
            θ[1] * gs_step.interactions.c0,    # c₁_ratio → c₁
        ),
        enable_ddi = true,
        c_dd = θ[2] * <reference_c_dd>,         # c_dd_ratio → c_dd
        zeeman = ZeemanParams(0.0, 0.0),
        potential = HarmonicTrap((1.0, 1.0, 1.182)),
    ),
    phase_A_init = :m_plus_F,    # ferro-like — relaxes to FL on c₁ < 0
    phase_B_init = :polar,       # polar — relaxes to uniform on c₁ > 0
    n_steps = 500, tol = 1.0e-7,
    sobolev_alpha = 0.0,
    verbose = false,
)

# Step 1: locate one boundary point via existing 1-D bisection.
seed = scan_phase_boundary(...)  # fill in c_dd_ratio = 1.0, sweep c₁_ratio

θ_init = [seed.c1_ratio, 1.0]
t_init = tangent_at(F, θ_init)

# Step 2: trace.
trace = trace_phase_boundary(F, θ_init, t_init;
    arc_step = 0.005,
    arc_step_max = 0.02,
    max_steps = 100,
    newton_tol = 1.0e-7,
    verbose = true,
)
@show size(trace.points)  # → (n × 2)
@show maximum(trace.residuals)
@save "runs/measurement_R3x_eu/r35_b1_boundary_trace/trace.jld2" trace
```

## Expected wall-time

- Cold first GS: 1-2 min
- Warm subsequent GS: 30-60 s each (pair of GS per F call)
- 100 boundary points × 2 GS × 1 min ≈ 3.3 h

This wall-time is for 24³. Production thesis figure should re-run at
32³+ for ~ 8 h, identical workflow.
