# AGENTS.md

**Read `CLAUDE.md`.** It is the structural fixed-point for this repository and
is kept current; this file is not.

This page held a 138-line fork of CLAUDE.md's content, last revised 2026-05-21.
By 2026-08-04 it was the second-largest source of drift in the repository: of
105 facts stated in more than one place, **28 of the disagreements involved this
file**, and it was reachable from exactly one line anywhere — CLAUDE.md's note
saying not to trust it.

Specifics, so the reasoning survives the deletion:

- pre-rename type names (`nematic`, `TwoChannelLHY`); the live spellings are in
  `src/hamiltonian/terms/lhy/`
- predates the HamTerm protocol entirely, so its guidance on adding a term
  produces one that will not compile into the registry
- `backend: cuda`, step-level `zeeman:`, flat `save_every`, `spinor_lhy:` — four
  YAML spellings the schema now rejects outright
- an `lhy.kind` enum missing `spatial` and carrying `two_channel`, which throws
- the ¹⁵¹Eu `a_s`, the split-step inner V order, and the tier lists all
  disagreed with the code

The content is in git history. Nothing here was unique to this file.

For agent-facing conventions specifically, the live sources are `CLAUDE.md`
(architecture, conventions, cost model) and `docs/conventions/` (physics
convention authority, testing strategy).
