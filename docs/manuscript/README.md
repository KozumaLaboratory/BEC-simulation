# SpinorBEC manuscript working area

This directory holds the active drafting / refinement workspace for
three papers and the master thesis on Eu F=6 dipolar spinor BECs.

## Layout

```
docs/manuscript/
├── README.md                     ← this file
├── papers/
│   ├── paper1_F2_cyclic/         ← F=2 cyclic LHY closed form (PRA target)
│   ├── paper2_F6_icosahedral/    ← F=6 I_h LHY closed form (PRA / PRR target)
│   └── paper3_universal_theorem/ ← Universal Structure Theorem (PRR / PRX target)
├── thesis/
│   ├── chapters/                 ← per-chapter integrated markdown
│   ├── figures/                  ← rendered figure PDFs / SVGs (gitignored)
│   └── bibliography/             ← thesis-specific bib extensions (if any)
└── shared/
    ├── references.bib            ← single bibliography for all four documents
    ├── notation.md               ← convention single-source-of-truth
    └── figures.md                ← figure placeholder inventory
```

## Refinement-round-1 status (2026-05-07)

* `shared/references.bib` — 19 BibTeX entries seeded from the Round-4
  reference list. TODOs documented in the file header (Saito-Li 2024
  arXiv ID, Phuc-Ueda-Saito year disambiguation, Bach 2012 vol/pages).
* `shared/notation.md` — full convention table; deviation tracking
  section is empty (chapter integration deferred).
* `shared/figures.md` — figure inventory with stable labels and
  status flags. 21 placeholders, 3 entries with data already ready
  in repo (`runs/F6_phase_diagram/`, the EdH TWA, the N scan).
* `papers/paper3_universal_theorem/main.md` — refinement stub with
  paste target and pass-checklist.
* `thesis/chapters/Ch3_F2_cyclic_integrated.md` — integration stub
  with paste targets for the main body + Sec 3.7-3.8 enhancement.
* `thesis/chapters/Ch6_polyhedral_phases_integrated.md` — same for
  Ch.6 main + F=4 / F=10 update.

## What's blocked

Tasks 2, 3, 6 from the Round-4 prompt require source files that
currently live only in the Claude.ai web sandbox at
`/mnt/user-data/outputs/`. The local WSL repo does not have access
to that path. To unblock:

* Paste the source content into the labelled `<!-- TODO-*-START / END -->`
  blocks in the three stub files, or
* Copy the source files into `/tmp/manuscript_drafts/` (or any local
  path) and notify; the next session can read from there.

After source files arrive, the integration is mechanical: splice the
update sections into the main bodies, run the notation pass, resolve
figure placeholders, and verify equation numbering / cross-references.

## Citation usage in markdown

Use Pandoc-style `[@KawaguchiUeda2012]` keys throughout the markdown
drafts. The keys must match `references.bib` exactly. When the
LaTeX conversion runs, Pandoc will resolve these via the bib file.

## Figure usage in markdown

Use the stable labels from `shared/figures.md`, e.g.

```markdown
The selection-rule pattern is shown in [FIG: paper3_FIG-3].
```

The label `paper3_FIG-3` ties the placeholder in the markdown to
the inventory entry; when the figure is rendered, save it as
`docs/manuscript/papers/paper3_universal_theorem/figures/paper3_FIG-3.pdf`
(or the equivalent path under `thesis/figures/`).
