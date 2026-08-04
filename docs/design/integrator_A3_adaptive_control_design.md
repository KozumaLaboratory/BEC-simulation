# A3 — Adaptive Timestep Control (Design)

> **FROZEN 2026-05-12.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status**: design only, no current implementation.
**Master plan reference**: `docs/design/integrator_architecture_completion_plan.md` §A3.
**Estimated implementation scope**: 2–3 sessions.

---

## 1. Motivation

The current SpinorBEC integrator suite uses **fixed `dt`** throughout a
simulation. This is wasteful in two regimes:

- **Smooth slow dynamics** (e.g., long equilibration, ITP):
  conservative dt under-utilizes the smooth phase.
- **Near-instability bursts** (e.g., post-quench dipolar collapse):
  the user must pre-select dt small enough to handle the burst, leaving
  the smooth pre-burst phase over-resolved.

Adaptive control provides 5–50× wall-time speedups in similar PDE
contexts (Hairer-Wanner, Söderlind 2003). For our integrator suite
production runs (Phase 6 TDHFB Eu, F=6 long-T DDI, etc.) it would be a
significant ergonomics + cost improvement.

## 2. Three approaches

### 2.1 — Defect-based estimator (Hairer-Wanner)

For a scheme `S` of order `p`, compute the local defect via Richardson
extrapolation:

```
defect_n = |S(dt_n) ψ_n - S(dt_n/2) S(dt_n/2) ψ_n|   ≈ C · dt_n^{p+1}
```

The "two half-steps" path provides one order higher accuracy (when both
halves are at the same Richardson stage).

**Cost**: 3× per accepted step (one S(dt) + two S(dt/2)). Reduce if
S(dt/2)² intermediate state is cached for the actual integration.

**Step-size update** (basic):
```
dt_{n+1} = dt_n · safety · (tol / defect_n)^(1/p)
```

Reject step if `defect_n > rtol · ‖ψ_n‖` and retry with halved dt.

### 2.2 — Embedded pairs (Fehlberg/Dormand-Prince style)

Construct two schemes of orders `p` and `p-1` that share most of the
same FFT/V/K evaluations. Difference between them = local error
estimate at minimal additional cost.

For symplectic split-step, this requires constructing matched pairs.
Yoshida-4 and Strang have natural embedding (Y4 contains 3 Strang
substeps; Strang is the order-2 partner). MPS-6 embeds Y4 via the
Richardson stack.

**Cost**: 1.1× (essentially free error estimation).

**Step-size update**: same Söderlind PI form below.

### 2.3 — Söderlind 2003 PI controller

Standard PI controller for step-size with proportional + integral terms:

```
dt_{n+1} = dt_n · safety · (tol / err_n)^α · (err_{n-1} / err_n)^β
```

with α = 1/(p+1), β = 1/(p+1). Smoother step-size sequences than basic
control; less aggressive rejection.

**Pros**: simple to graft onto any error estimator.
**Cons**: needs the estimator from 2.1 or 2.2 to compute `err_n`.

## 3. Recommended implementation: 2.1 + 2.3

A defect-based estimator (2.1) combined with the Söderlind PI
controller (2.3) is the cleanest path:
- Defect estimator: structurally compatible with any split-step
  scheme (no need to construct matched pairs).
- PI controller: smoother behavior than basic controller, well-
  tested in ODE/SDE literature.

### 3.1 — API sketch

```julia
# src/hamiltonian/integrator/adaptive.jl  (NEW)

"""
    adaptive_step!(ws, step!::Function;
                   tol_abs=1e-8, tol_rel=1e-6,
                   safety=0.9, max_dt_factor=5.0,
                   min_dt_factor=0.2,
                   p::Int=4) -> dt_used::Float64
"""
function adaptive_step!(ws, step!::Function; kwargs...)
    # Save ψ_n
    psi_backup = copy(ws.state.psi)
    dt = ws.sim_params.dt

    # Full step
    step!(ws)
    psi_full = copy(ws.state.psi)

    # Restore + two half steps
    ws.state.psi .= psi_backup
    ws.sim_params.dt = dt / 2  # NEEDS Workspace mutability or fresh ws
    step!(ws); step!(ws)
    psi_double = ws.state.psi

    # Defect (Richardson)
    defect = norm(psi_full .- psi_double)

    # Step-size update
    rtol = tol_abs + tol_rel * norm(psi_double)
    if defect > rtol
        # Reject: retry with dt/2
        ws.state.psi .= psi_backup
        ws.sim_params.dt /= 2
        return adaptive_step!(ws, step!; kwargs...)
    end

    # Accept: dt_new for next iteration
    dt_new = dt * clamp(safety * (rtol / defect)^(1.0 / (p + 1)),
                       1.0 / max_dt_factor, max_dt_factor)
    ws.sim_params.dt = dt_new
    return dt
end
```

**Caveat**: requires Workspace.sim_params to be mutable (currently
immutable struct in `src/foundation/types/sim_params.jl`). Either:
- Make sim_params a mutable wrapper around the immutable struct
- Or pass `dt` explicitly to step! (refactor)

The second approach is cleaner long-term — fits the "step! takes dt as
arg" pattern used in the unified test bench scripts.

## 4. Test protocol

### 4.1 — Smooth dynamics regime

Phase 2a problem (Rb87 F=1 16³, c0=50, c1=1, c_dd=1, T=0.04):
- Fixed Y4-mid at dt=4e-3: wall ~5s, err 2e-8.
- Adaptive Y4-mid at tol=1e-7: target err ≤ 1e-7, wall < 3s.

### 4.2 — Near-instability regime

Eu post-quench (F=6 16³ Eu, T=1.0):
- Fixed Y4-mid at dt=2e-4: wall ~30 min (TDHFB-like cost), accuracy
  satisfactory.
- Adaptive Y4-mid at tol=1e-5: target wall < 8 min by skipping the
  smooth pre-burst phase.

## 5. Acceptance criteria

- [ ] Adaptive control delivers same final accuracy at ≤ 2× fixed-dt
      cost on smooth Phase 2a.
- [ ] Adaptive control at < 50% fixed-dt cost on near-instability Eu
      post-quench regime.
- [ ] Step-size adaptation does NOT break order: measured global order
      = scheme's nominal order (e.g., Y4-mid = order 4).
- [ ] User-facing API mirrors existing `split_step!(ws)` etc. via a
      drop-in `adaptive_split_step!(ws; tol=...)` wrapper.

## 6. Implementation phases

1. **Workspace mutability fix or step!-takes-dt refactor** (1 session).
2. **`adaptive_step!` infrastructure + defect estimator** (1 session).
3. **PI controller + tests** (1 session).

Total: 2–3 sessions assuming the refactor in phase 1 is contained
(avoid the Workspace type-parameter explosion documented in
`memory/pitfall_pipeline_inference.md`).

## 7. Cross-references

- `docs/design/integrator_architecture_completion_plan.md` §A3
- Hairer, Norsett, Wanner: "Solving Ordinary Differential Equations I"
  (defect-based estimator)
- Söderlind 2003: "Digital Filters in Adaptive Time-Stepping"
- `memory/pitfall_pipeline_inference.md` (Workspace type-parameter
  caveat that any sim_params refactor must respect)

---

**Last update**: 2026-05-12 (initial design; implementation deferred
per master plan).
