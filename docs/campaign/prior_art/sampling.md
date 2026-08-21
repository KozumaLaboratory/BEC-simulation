# Prior art — sampling

> **FROZEN 2026-08-21.** A snapshot of the open work on sampling as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: sampling, adaptive, convergence, stopping, refine, scan, resolution, criterion. Regenerate with
`python3 scripts/prior_art.py --topic sampling --keywords sampling adaptive convergence stopping refine scan resolution criterion`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/feat/manuscript-refinement-round5 | unrelated | branch:  | **0 commits ahead of main** — already in. Manuscript text (Paper #3 v3 + Ch.3/Ch.6 integration); matched "refine" in the BRANCH NAME, which is about prose rounds, not sampling refinement. |
| origin/feat/manuscript-refinement-round6 | unrelated | branch:  | Same: 0 commits ahead of main, Ch.6 inline + Paper #1 integration. Two of the three matches on this topic are the word "refinement" in a manuscript branch name — worth noting when tuning the keyword list. |
| #57 | depends | issue: research(phases): 2D Eu F=6 phase diagram via adaptive multi-seed mapping | **This is the home for the stopping-rule work.** Its design (`docs/design/eu_phase_diagram_adaptive_mapping.md`) specifies HOW to build adaptively — coarse multi-seed recon → detect where the phase changes → bisect / boundary-trace / active-learn → fill interiors by continuation — and names the boundary DETECTORS (multi-seed min-E crossing, order-parameter jump, bidirectional hysteresis divergence, solver-struggle). What it does NOT contain is a stopping rule: nothing says when a boundary is resolved enough to stop bisecting, or when the map is done. That gap is exactly the session-plan item, so this work belongs on #57 rather than beside it. |
