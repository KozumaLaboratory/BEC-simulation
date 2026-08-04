# Adding a new Hamiltonian term

> **FROZEN 2026-08-04.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

> **This page is a pointer.** The procedure lives in `CLAUDE.md`, section
> **"Adding a new HamTerm — protocol"** — seven numbered steps, kept current
> because CLAUDE.md is the file every session loads.

This document used to restate that protocol, and the copy rotted, which is the
whole argument for not having two:

- its boilerplate implemented `add_gradient!`, a face **deleted 2026-06-06**;
  the real one is `apply_operator!` with the accumulate contract
  (`out .+= H·ψ`). Following this page produced a term that would not compile
  into the registry.
- it said to model the new term on `terms/zeeman_z.jl`, a file that does not
  exist (there is one `ZeemanTerm`).
- it omitted three registration sites CLAUDE.md requires:
  `H_TERMS_CANONICAL_ORDER`, the `validation/dumb_reference.jl` slot, and the
  `energy_breakdown_via_registry` field.
- its Zeeman example carried the lab-field sign INVERTED — corrected across
  three files on 2026-08-04; the operator form is `H = -p·F_z + q·F_z²` and,
  since `p ≡ -g_F μ_B B` (`Units.bfield_to_p`), that is `+(g_F μ_B B·F)` in
  the lab, so +Bz on a g_F>0 atom gives ground state m = -F.

Last content revision was 2026-08-04; the full text is in git history if you want to
see what it said.

**Related, and still live:** `docs/conventions/hamiltonian_sign_audit.md` (the
per-term sign × path audit table) and `docs/conventions/testing_strategy.md`.
