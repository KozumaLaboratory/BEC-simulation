# Paper #3 — Universal Structure Theorem for Spinor LHY (refined draft)

**Refinement-round-1 status**: STUB awaiting source file.

## Input needed

| Source file (Claude.ai web sandbox) | Role |
|---|---|
| `paper3_universal_theorem_full_draft.md` | full manuscript draft including F=4 cube, F=10 dodecahedron, F=2 BN modified theorem v2 (λ_z = 0.443 corrected), F-systematic classification |

## Refinement plan

After paste:

1. **Section / equation numbering audit**
   * Roman numerals for sections (I, II, III, …).
   * Arabic equation numbers per section, e.g. (III.1), (III.2), …
   * Verify (III.1) is the first equation of Sec III, etc.; flag any
     gaps or out-of-order numbering.

2. **Cross-reference verification**
   * Every "see Sec X.Y" reference must point to an actual labelled
     section.
   * Every equation reference like "(V.5)" must exist.
   * Every figure reference resolves against
     `docs/manuscript/shared/figures.md`
     (`paper3_FIG-1` through `paper3_FIG-5`).
   * Every citation resolves against
     `docs/manuscript/shared/references.bib`.

3. **Notation pass** per `docs/manuscript/shared/notation.md`:
   * Mass: capital `M` (not lowercase m, which is reserved for spin
     projection).
   * `g_S` lowercase with capital S subscript.
   * Bra-ket: LaTeX `\langle`/`\rangle`.
   * Vectors: pick bold or arrow consistently (paper-3 will be **bold**
     by default — that's PRR / PRX style).
   * Hats on operators in math display.

4. **Figure placeholder markup**
   * Replace any "Figure 1", "Figure 2" prose with
     `[FIG: paper3_FIG-1]` etc. so the placeholder list in
     `figures.md` is the single source of truth.
   * Add explicit captions in the placeholder block.

5. **Inconsistency log**
   * Track any deviations found into
     `docs/manuscript/shared/notation.md` "Inconsistencies seen in
     drafts" section.

## Paste target

```
<!-- TODO-PAPER3-DRAFT-START
Paste the full content of paper3_universal_theorem_full_draft.md here.
Audit / refinement passes will run on this content in subsequent
sessions.
TODO-PAPER3-DRAFT-END -->
```

## Notes on the F=2 BN modified theorem v2 (λ_z = 0.443)

Per the Round-4 prompt, the draft already corrects an earlier
spurious `λ_z = 0.443` value. Verify this correction propagates
through:

* The F=2 BN section (somewhere in Sec III or IV depending on the
  draft layout).
* Any tabulated multiplicity / stiffness table.
* Any cross-reference from Paper #1 (F=2 cyclic) to Paper #3 (universal).
