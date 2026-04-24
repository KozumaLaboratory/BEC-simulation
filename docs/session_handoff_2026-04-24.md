# Session Handoff — 2026-04-24 @ commit `78c750e`

Persistent notes for the next Claude session. Pulled out of chat memory
into a durable doc so nothing is lost when the conversation closes.

## Detached long-running processes (survive Claude close)

```
PID 81971  SID 81971  → eu151_edh_ext full run  → logs/eu151_edh_ext.log
PID 82239  SID 82239  → dashboard serve_dashboard(8765)  → logs/dashboard.log
```

Both have PID == SID, i.e. session leaders in their own process group.
SIGHUP does not propagate from the old Claude shell. Health check:

```bash
ps -o pid,ppid,sid,cmd -C julia
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8765/api/runs
tail logs/eu151_edh_ext.log
```

## Running config

`runs/eu151_edh_ext/config.yaml` — EdH 107.6 ω⁻¹ relaxation with:
- Zeeman sign flipped (p = −100 → −0.39), ground state at m=−6
- `save_psi_snapshots: true` (callback-streamed ~78 MB peak host RAM)
- `save_snapshot_precision: "f32"` default (half disk, ~1e-7 error)
- Scan: `pipeline.2.seed_amplitude: [1e-6, 1e-4]`
- Point 1 (seed=1e-6): may skip if `runs/eu151_edh_ext/point_001.jld2`
  already exists from an earlier completed run (4.2 GB, legacy 5D
  layout — reader auto-detects).
- Point 2 (seed=1e-4): computing now.

If either point finishes and the dashboard is open, the new streamed
`dynamics/psi_snapshots_streamed/frame_XXXXX` layout + full time
scrubber UI on the 3D View tab should light up.

## This session's commit chain (on main)

```
78c750e refactor(foundation): dtype kwarg on make_fft_plans/make_rfft_plans — MP phase 2
d94fc8e refactor(foundation): parameterise Grid{N,T} — phase 1 of MP refactor
c285818 feat(pipeline): save_snapshot_precision — switchable f32/f64 snapshots
143b504 perf(pipeline): callback-streamed snapshots — ~8 GB → ~26 MB host RAM
a9865a9 chore(budget): reflect callback-streaming host RAM profile
63597c9 feat(pipeline): SPINORBEC_SCRATCH_DIR for HPC-friendly staged writes
      + optional zlib compression + run-budget estimator + MP design doc
a052f72 fix(pipeline): stream psi_snapshots to disk (avoid 1 GB intermediate)
00cb2cb fix(dashboard): fall back to config.yaml when jld2 lacks grid_box_size
(…web UX upgrade batch…)
10b2373 feat(analysis): circulation line integral for vortex winding
```

~20 commits total this session.

## Mixed-precision refactor — phase tracker

- **Phase 1 ✓** — `Grid{N,T<:AbstractFloat}` + `make_grid(...; dtype=)`
  + `const GridF64{N} = Grid{N,Float64}` alias. 17/17 test_grid pass.
- **Phase 2 ✓** — `make_fft_plans(...; dtype=)` /
  `make_rfft_plans(...; dtype=)`. FFTPlans already had P/IP params
  so no struct change. 6/6 test_propagators pass.
- **Phase 3 — NOT STARTED**: `Workspace{..., T}` propagation.
  Scope audit needed first because `types.jl` has dozens of concrete
  `Float64` / `ComplexF64` fields on downstream structs:
  `InteractionParams`, `ZeemanParams`, `RamanParams`, `HarmonicTrap`,
  `GravityPotential`, `LaserPotential`, `DDIField`, `SpinMatrices`
  (uses SMatrix with element type), `AbsorbingBoundary`,
  `LiveMonitor`, `BatchedKinetic`, etc.
  Every one needs a T parameter + constructors that accept it.
- **Phase 4 — NOT STARTED**: kernel audit. Every literal
  `0.0` / `ComplexF64(...)` / `Float64(x)` in split_step.jl, ddi.jl,
  spin_mixing.jl, nematic_tensor.jl, raman.jl, zeeman.jl,
  absorbing_boundary.jl needs to be `zero(T)` / `Complex{T}(...)` /
  `T(x)`. CUDA-side kernels similarly.
- **Phase 5 — NOT STARTED**: analyzer audit. Bogoliubov diag, LBFGS
  grad norms, ITP tolerance thresholds need adjustment for F32.
- **Phase 6 — NOT STARTED**: dual-dtype smoke test +
  `pipeline.0.dtype: f32 | f64` YAML knob.

`docs/mixed_precision_design.md` has the full plan.

**Realistic ETA for completion**: 1–2 weeks of focused sessions.

**Immediate payoff once done**: ~5–10× speedup on RTX 5070 Ti local
runs (consumer FP64 is 1/64 of FP32). Marginal (~2×) on TSUBAME H100
where FP64 is already full-rate.

## UX / dashboard state

All of the following landed in the web/ migration and are live via the
dashboard at http://localhost:8765 (and `:5173` if Vite dev running):

- Tabs: Overview / 2D View / 3D View / Data / Config
- URL-persisted run / point / tab / snap / component selections (nuqs)
- Keyboard shortcuts + ⌘K command palette (react-hotkeys-hook + cmdk)
- 3D view layers (toggle each via leva): density volume raymarch,
  phase hue (per m), vector arrows (current / spin / velocity),
  particle advection (density seed or vortex-shell seed with optional
  azimuthal-only projection — "cheat" toggle, default off),
  vortex-line glowing tubes (plaquette-winding extraction)
- Camera presets (Top / Front / Iso / Reset) using drei CameraControls
- Time scrubber for snapshot-bearing runs (30 fps play/pause)
- Sparklines on every DataTable row (Mz(t) / E(t))
- Shiki YAML syntax highlighting in Config tab with derived-value panel
- ErrorBoundary per tab — one crashing tab can't nuke the app

## Pending decisions left to the user

1. `/legacy` route / `runs/tools/dashboard.html` — keep or delete.
   React app has parity minus the quantization-axis tilt slider.
2. `PLAN.md` and many untracked `runs/*/config.yaml` files — gitignore
   or commit.
3. Lossy snapshot reductions (component mask, density mask) — user
   flagged as physics-destructive, reverted. Do NOT resurrect.

## Known caveats

- **Deprecation warnings** from R3F / Three.js (`THREE.Clock deprecated`)
  are harmless — awaiting upstream fix.
- **WSL2 localhost:8080** blocked by Tailscale serve on this machine.
  Dashboard is on 8765 instead.
- **WebGPU** needs Chrome 113+, Edge, or Firefox Nightly.
- `eu151_edh/point_001.jld2` is 4.2 GB with legacy 5D snapshot layout
  from the original run. Reader supports both layouts; no migration
  needed.

## Next actions ranked by ROI

1. Wait for `eu151_edh_ext` to complete, inspect point_002 for
   stronger-seed EdH evolution. Does Mz reach 0 with seed=1e-4?
2. Start MP Phase 3 — `Workspace{..., T}`. Begin with the smallest
   downstream struct (InteractionParams) to prove the pattern, then
   propagate.
3. Run the full 8600+ test suite against commit `78c750e` to confirm
   Phase 1+2 broke nothing beyond the two tests already verified.
4. Delete `/legacy` once user confirms React app is "daily driver".
