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

## Promoted out of agent memory 2026-07-31

Document-shaped notes (roadmaps, status snapshots, arc logs) that had accumulated in the agent
memory store, where the one-file-one-fact rule does not fit them. They are dated records of how a
decision was reached — **none of them is a live specification**; the live equivalent is named per entry.

Two of the seven did not land here. `option_gamma_rotating_basis_design.md` and
`validation_ladder_2026-05-22.md` between them cite seven `runs/` directories that do not exist, which
`test/oracles/test_doc_run_citations_resolve.jl` correctly rejects: that gate is a ratchet on unresolved
citations, and importing a document is no reason to widen it. They are historical records whose value is
the reasoning, not the runs, so they were moved outside the repository to
`BEC-simulation-archive/promoted_memory_notes_2026_07_31/` instead of being carried here with their
citations pinned as permanent exceptions.

- **`north_star_phase_diagram_plan_2026-06-02.md`** — the 4-track ¹⁵¹Eu (F=6) roadmap (A phase diagram, B fluctuation selection, C vortices, D experimental anchor) written after the c-determination protocol closed, plus the execution discipline distilled from the Sprint 1–5 failure modes. Live equivalent: `design/eu_phase_diagram_adaptive_mapping.md` and the active-arc section of the agent memory index.
- **`hamiltonian_layered_architecture_arc_2026-06-05.md`** — round-by-round log of the layered-Hamiltonian redesign. Live SSoT is `design/hamiltonian_layered_architecture.md`; this is only the reasoning trail that produced it.
- **`sprint3_static_gate_baseline_2026-06-01.md`** — static-gate measurement baseline for Sprint 3. Live equivalent: the oracle suite under `test/oracles/`.
- **`integrator_modernization_status_2026-05.md`** — May-2026 status snapshot. Live equivalent: `design/integrator_modernization_plan.md` + `design/integrator_ch3_plan.md`.
- **`klaus_quench_protocol_pivot_2026-05-26.md`** — record of the rotation+quench magnetostir protocol pivot. Live equivalent: `guides/klaus_regime.md`.

## Removed in tidy-up 2026-05-13

11 unreferenced entries pruned: `ENHANCED_MONITORING.md`, `MEASUREMENT_RESULTS_GPU.md`, `MEASUREMENT_RESULTS_LOCAL.md`, `RUNS_INVENTORY.md`, `RUNS_REVERIFICATION_GPU.md`, `optimization_roadmap_2026-04-29.md`, `plan.md`, `plan2.md`, `session_handoff_2026-04-25.md`, `session_handoff_2026-04-29.md`, `spin_larmor_frame.md`. Available via `git log -- docs/archive/<name>.md`.
