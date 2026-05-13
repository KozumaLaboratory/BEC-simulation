# Archive

Dated or superseded docs. Kept for historical context but not part of the live documentation set. Each entry below explains why it's archived and where the live equivalent lives now.

## Bug audits (Bug-4: ITP merged-loop DDI half-rate)

Bug fixed 2026-05-02 in `src/solvers/ground_state/itp_loop.jl`. Regression test: `test/test_itp_ddi_strang_save_every.jl`.

- **`AUDIT_BUG4.md`** — full diagnosis + affected-runs table + per-`save_every` shift formula `(N+1)/(2N)`. Also documents a deferred trade-off: the analogous *2nd-order accuracy degradation* (not a rate bug) on the RTP merged-leapfrog branch (`_run_simulation_leapfrog!`) — ψ at `save_every=1` vs `save_every=100` can differ ~30% for stiff DDI in real time. Not auto-fixed; doubling DDI per-step cost was deemed not worth it.

## Measurement campaign (Phase 2)

- **`MEASUREMENT_CAMPAIGN_PHASE2.md`** — TSUBAME burst plan for R32–R39 (Sobolev preconditioner, MFBO, pseudo-arclength continuation, active learning, triple-point hunting, BdG along boundary). All R3x capabilities now live in `src/workflow/experiments/optimization/` + `scripts/`.

## Empirical findings (now enforced in code)

- **`thesis_batch_audit_2026-04-28.md`** — ε threshold finding (`p · F · dt > 100` needs ε=1e-6) + regime classification table. Now enforced via `_run_rotating_basis_dynamics_inner` advisory + `guides/klaus_regime.md` "Hard constraint".

## Superseded designs

- **`phase15_zeeman_levels.md`** — design rationale for Level 0/1/2 Zeeman dispatch (closures vs sampled waveforms; omega_ref resolution rules). Implementation done 2026-04-23. User-facing reference is now `reference/yaml_schema_reference.md` "zeeman" section + `guides/klaus_regime.md` "Spec B(t)".

## Removed in tidy-up 2026-05-13

11 unreferenced entries pruned: `ENHANCED_MONITORING.md`, `MEASUREMENT_RESULTS_GPU.md`, `MEASUREMENT_RESULTS_LOCAL.md`, `RUNS_INVENTORY.md`, `RUNS_REVERIFICATION_GPU.md`, `optimization_roadmap_2026-04-29.md`, `plan.md`, `plan2.md`, `session_handoff_2026-04-25.md`, `session_handoff_2026-04-29.md`, `spin_larmor_frame.md`. Available via `git log -- docs/archive/<name>.md`.
