# Prior art — sampling

> **FROZEN 2026-08-21.** A snapshot of the open work on sampling as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: sampling, cadence, snapshot, frames, window. Regenerate with
`python3 scripts/prior_art.py --topic sampling --keywords sampling cadence snapshot frames window`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| #55 | depends | issue: feat(solvers): unified snapshot + spectral/real-space seeding mechanism | **Owns the mechanism #444 reads from, and the cadence hazard it must not trip.** #444 reconstructs the radial RMS from `psi_snapshots_streamed`, which is #55's surface. The live hazard is already recorded in `klaus_weff_extract.jl`: `component_populations` is derived from the psi snapshots and `times` from the scalar sampler, and they are DIFFERENT CADENCES (42 against 43), not an off-by-one — indexing one by the other threw a BoundsError, which was the lucky outcome. So the hold window is derived from the config, never from `times`. #444 does not change the mechanism, so this stays #55's; it constrains how #444 may index it. |
| #57 | depends | (no longer open) | **This is the home for the stopping-rule work.** Its design (`docs/design/eu_phase_diagram_adaptive_mapping.md`) specifies HOW to build adaptively — coarse multi-seed recon → detect where the phase changes → bisect / boundary-trace / active-learn → fill interiors by continuation — and names the boundary DETECTORS (multi-seed min-E crossing, order-parameter jump, bidirectional hysteresis divergence, solver-struggle). What it does NOT contain is a stopping rule: nothing says when a boundary is resolved enough to stop bisecting, or when the map is done. That gap is exactly the session-plan item, so this work belongs on #57 rather than beside it. |
| origin/feat/manuscript-refinement-round5 | unrelated | (no longer open) | **0 commits ahead of main** — already in. Manuscript text (Paper #3 v3 + Ch.3/Ch.6 integration); matched "refine" in the BRANCH NAME, which is about prose rounds, not sampling refinement. |
| origin/feat/manuscript-refinement-round6 | unrelated | (no longer open) | Same: 0 commits ahead of main, Ch.6 inline + Paper #1 integration. Two of the three matches on this topic are the word "refinement" in a manuscript branch name — worth noting when tuning the keyword list. |
