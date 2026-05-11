# Archive

Dated or superseded docs. Kept for historical context but not part of the live documentation set.
Each entry below explains why it's archived and where the live equivalent lives now.

## Bug audits (Bug-4: ITP merged-loop DDI half-rate)

Bug fixed 2026-05-02 in `src/solvers/ground_state/itp_loop.jl`.
Regression test: `test/test_itp_ddi_strang_save_every.jl`.

- **`AUDIT_BUG4.md`** — full diagnosis + affected-runs table + per-`save_every` shift formula `(N+1)/(2N)`.
  Also documents a deferred trade-off: the analogous *2nd-order accuracy degradation* (not a rate bug) on the RTP merged-leapfrog branch (`_run_simulation_leapfrog!`) — ψ at `save_every=1` vs `save_every=100` can differ ~30% for stiff DDI in real time. Not auto-fixed; doubling DDI per-step cost was deemed not worth it.
- **`RUNS_INVENTORY.md`** — every `runs/<name>/config.yaml` cross-referenced against the post-fix code state. Snapshot of one moment.
- **`RUNS_REVERIFICATION_GPU.md`** — local re-run + GPU bench. Side-finding: 4 layered bugs in `runs/eu151_lab_calibrated/` (3 fixed inline, 4th — *ITP NaN at step 1 with calibrated parameters at dt=0.005* — still relevant; see `guides/performance_tuning.md` "dt rule of thumb").

## Measurement campaign (Phase 2)

- **`MEASUREMENT_CAMPAIGN_PHASE2.md`** — TSUBAME burst plan for R32–R39 (Sobolev preconditioner, MFBO, pseudo-arclength continuation, active learning, triple-point hunting, BdG along boundary). All R3x capabilities now live in `src/workflow/experiments/optimization/` + `scripts/`.
- **`MEASUREMENT_RESULTS_GPU.md`** — raw bench dump, RTX 5070 Ti, 2026-05-02. R32 + R33 numerical results.
- **`MEASUREMENT_RESULTS_LOCAL.md`** — raw bench dump, laptop CPU, 2026-05-02. R32–R36, R39 numerical results.

## Session handoffs (single-day session logs)

- **`session_handoff_2026-04-25.md`** — Phase 4/5 primitives backlog closed; PlotlyJS removed; `live_monitor` + `seed_k_cut` wired; frontend WebGPU complete; `dry_run` returns YAML string. All deliverables landed in tree.
- **`session_handoff_2026-04-29.md`** — 4 review rounds, 12h batch + audit, ε=1e-3 Klaus regime numerical artifact found, CUDA Graph alloc-reduction landed, F32 mixed precision end-to-end, save format unified. Substantive rules (ε threshold) now in CLAUDE.md + `_run_rotating_basis_dynamics_inner` warning.

## Plans + roadmaps (point-in-time intent)

- **`plan.md`** — pre-implementation snapshot (~2026-04-14). Stage 0/1/2/3/4 layout; AtomOptics.jl split idea (abandoned). Marked obsolete in its own header.
- **`plan2.md`** — pre-implementation snapshot (~2026-04-14). Test pyramid (Level 0–3) — implemented as `test/test_propagators/`, `test_conservation/`, `test_ground_state/`, `test_dynamics/`. Marked obsolete in its own header.
- **`optimization_roadmap_2026-04-29.md`** — outstanding items split into the live design docs:
  - CUDA Graph re-enable → see `design/higher_order_integrators.md` + `cuda_graph_stubs.jl`
  - Mixed precision F32 → `design/mixed_precision_design.md`
  - Multi-GPU → `design/multi_gpu_design.md`
  - Higher-order regime-aware ε → `design/higher_order_integrators.md`
  - F=6 LHY closed form → derived since; see `theory/icosahedral_lhy.md`
- **`thesis_batch_audit_2026-04-28.md`** — ε threshold finding (`p·F·dt > 100` needs ε=1e-6) and regime classification table. Now enforced via `_run_rotating_basis_dynamics_inner` advisory + CLAUDE.md "Known limitations".

## Superseded designs

- **`spin_larmor_frame.md`** — narrower Path-A Larmor-frame design (single-axis Bz, F=8 Dy164 only initially). Superseded by `design/option_gamma_rotating_basis.md` (math) + `guides/klaus_regime.md` (usage). Option γ handles full B̂(t) for general F including Eu151 F=6 (Phase II/III passed 2026-04-27; production path).
- **`phase15_zeeman_levels.md`** — design rationale for Level 0/1/2 Zeeman dispatch (closures vs sampled waveforms; omega_ref resolution rules). Implementation done 2026-04-23. User-facing reference is now `reference/yaml_schema_reference.md` "zeeman" section + `guides/klaus_regime.md` "Spec B(t)".

## Historical feature description

- **`ENHANCED_MONITORING.md`** — explicitly marked historical (2026-04-26). The features described still exist; live paths are `src/workflow/monitoring/` (progress, ascii_plot, logging, resource_monitor, notifications) and `src/workflow/experiments/runtime/adaptive_advice.jl`. The dashboard side replaced the imagined WebSocket server (`reference/architecture.md` §Dashboard, `reference/dynamics.md` for the YAML knobs).
