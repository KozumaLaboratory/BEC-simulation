# What the 481 stored summaries are still for, and what they are not

**Measured 2026-08-02** across all worktrees. Companion to
[`doc_run_citation_inventory.md`](doc_run_citation_inventory.md) and the
re-derivation write-ups. **Nothing is deleted by this document** — it records the
evidence and a reversible procedure, because the targets sit in the main checkout
and four worktrees.

## The classification

474 run directories hold a stored `summary.json` (481 files).

| class | dirs (first matcher) | dirs (corrected) | what cites it |
|---|---:|---:|---|
| **exact name** | 10 | 21 | a live document names the directory |
| **glob family** | 72 | 242 | a live document names `runs/<stem>_*`, a brace set, or a bare prefix |
| **uncited** | 392 | 211 | nothing in `docs/**` outside `archive/` |

**Both columns are shown because the difference is the finding.** The left column
is what the first matcher reported and what the sections below were written
against; the right is after the three defects in *"the count was a property of
the matcher"* were fixed. Read the left column as a record of what was believed,
not as a count of anything.

### The 10 exact-named are the four figures — and those are now re-derived

8 of the 10 back a figure or a validation claim row; 2 are config-location
pointers. All ten are dated 2026-05-26/29 and unstamped. **Every figure resting on
them has now been re-run on current code**, and every one moved:

- Fig 1 — peak density −16.5 %, uniform across four cells
- Fig 2 — premise gone
- Fig 3 — 7 of 10 classifications changed
- Fig 4 — the ±Ω comparison turned out not to be a symmetry operation at all

So these ten are no longer the *evidence* for anything; they are the record of
what was believed before the corrections. That is a real use, and a much smaller
one than "data behind the figures".

### The 72 glob-matched back no quantitative claim

| stem | dirs | cited by | nature of the citation |
|---|---:|---|---|
| `klaus_*` | 65 | `research-log/2026-05-28_validation_python_archive.md` | the "data source" column of a table recording **eight retired Python figure scripts** — provenance for a deletion |
| `sprint5_M1_*` | 4 | `architecture/sweep_view.md` | a data-layout example |
| `eu151_*` | 2 | `guides/pipeline_cookbook.md` | a cookbook example |
| `eu_k3_*` | 1 | `matsui_reproduction_status.md`, this campaign | — |

Sixty-five of the seventy-two are cited by one research-log entry, in the column
that says where a *deleted* script used to get its input.

### 7 of the first matcher's 392 "uncited" are tracked in git

`eu_collapse_search`, `eu_ham_only_conservation`, `eu_ham_only_ramp_quench_24`,
`matsui_edh_baseline_529e3a77`, `matsui_edh_baseline_9ca97308`, `saito_li_torus`,
`yan_li_saito_f1_grid_refinement`.

Someone committed these deliberately. **Not cited ≠ not wanted** — they are out of
scope for disposal on that ground alone.

## Footprint

| location | uncited dirs | disk |
|---|---:|---:|
| `BEC-simulation` (main checkout) | 148 | **~230 GB** |
| `wt:silly-foraging-flame` | 213 | **~199 GB** |
| `wt:streamed-sniffing-sifakis` | 31 | — |
| `wt:frolicking-mapping-feather`, `wt:gs-stage-cache` | 7 | — |

Over 400 GB, against a 2 TB group quota that is already 1.2 TB used. This is worth
acting on, which is why the manifest exists.

## Correction: citation is necessary but not sufficient

Raised by anko — *"at least keep the phase diagrams."* Right, and my criterion was
wrong.

**"No live document cites it" is a reason to stop treating something as evidence.
It is not a reason to delete it.** A phase-diagram scan, a resolution ladder, a
Ω- or B-sweep is an expensive, reusable input whose value does not depend on
whether a markdown file happens to name it today. Deleting one because nobody
wrote it down is exactly the failure this campaign exists to stop, running the
other way.

Two facts, measured:

1. **The phase diagrams were never in scope.** This manifest's population is the
   474 directories that hold a `summary.json`. `F6_phase_diagram`,
   `eu_gs_phase_c1_B_kappa` and `berry_crossover_scan` carry none, so they were
   never candidates. That was luck, not design — the criterion would not have
   protected them.
2. **105 of the 385 are scan or sweep families** — `bzsweep_*`, `fieldsweep_*`,
   `omsweep_*`, `p2sweep_*`, `scan2d_*`, `dense_omega_*`, `dense_field_*`,
   `*_phase_*`, resolution ladders. **These are now KEEP**, regardless of citation.

Disposal therefore needs *all* of: uncited, untracked, unstamped, superseded by a
correction — **and not a scan family.**

## Second correction: the count was a property of the matcher

Raised by anko — *"that's still a lot."* It was, and chasing that produced the
finding that matters more than any of the numbers below.

**The size of the disposable set moved every time the citation matcher was fixed:
385 → 280 → 259 → 207.** Three separate defects, each found only because the
previous number was questioned:

1. **Nested citations were read at their first segment only.** The matcher keyed
   on the top-level directory, so `runs/verification_suite/L4_eu_matsui_hamiltonian_only_*` (gone)
   resolved to `verification_suite` and the 13 directories it names were
   scored uncited. `self_contained_validation_report.md:107` calls those runs
   *the canonical Eu Hamiltonian-only prediction for this codebase*. They were on
   the disposal list. Fixing the matcher then showed the citation itself was
   wrong: nothing named `L4_eu_matsui_hamiltonian_only_*` has ever existed under
   `verification_suite/`, in this worktree or the main checkout. The runs are at
   the top level of `runs/`, and three documents pointed at a path that was never
   there — invisibly, because the gate stopped at the first segment.
2. **Brace expansion was not expanded.** `day_inventory_2026_05_26.md:61` cites
   `L4_K3_n{64,96,128}_*_<hash>`; only the `n64` arm was matched. The `n96` and
   `n128` arms are 91 GiB — 55 % of the bytes then marked disposable.
3. **Only `runs/`-prefixed tokens counted.** That citation is a bare directory
   name in a table cell, with no `runs/` in front of it. A name in backticks is
   a citation whether or not it carries a path prefix.

Defects 1 and 3 are also present in `test/oracles/test_doc_run_citations_resolve.jl`,
whose `_CITE_RE` excludes `/` from the captured name — so for a nested citation the
gate checks that `runs/verification_suite` exists and never looks at the rest of
the path. The gate is weaker than it reads.

**What this means for disposal.** Every fix moved directories *out* of the
disposable set, never in. The criterion is not converging on a property of the
data; it is measuring how good the regex is that week. A list produced this way
is fine for *"stop citing these as evidence"* and is not fit to drive `rm`.

## The disposable set: 207 directories, 82 of them still on disk

Under the loosest matcher — any backticked token in a live document that names or
prefixes the directory — 263 of the 474 are mentioned somewhere and 211 are not.
Four of those 211 are scan families, kept by rule 5, leaving **207**. Of the 207,
82 still exist under `runs/` in the main checkout, totalling **60.6 GiB against a
261 GiB `runs/` tree**.

Rule 5 removes only four here, against 105 under the first matcher, because the
corrected matcher already keeps most scan families for the better reason: a
document names them.

Each of the 207 satisfies all of:

1. no live document mentions it, by name, prefix, glob or brace expansion;
2. it is not tracked in git;
3. its `summary.json` carries no producing commit — like all 474, it is not
   reproducible from the repository;
4. it predates the 2026-06/07 corrections, so any number in it is superseded by
   construction;
5. it is not a scan, sweep, ladder or phase map.

**Reclaim by bytes, not by count.** The distribution is concentrated: the largest
5 directories are 38 % of the 60.6 GiB, and the largest 15 are most of it.

| GiB | directory |
|---|---|
| 9.44 | `LHY_polar_contact_200ms_d82e14b5` |
| 4.73 | `LHY_polar_contact_100ms_283e1a72` |
| 3.36 | `L4dealiasv6_kcut11_eu_matsui_hamiltonian_only_96_f7d8dbf9` |
| 3.35 | `L4dealiasv4_eu_matsui_hamiltonian_only_96_6d8d0a7a` |
| 2.42 | `LHY_polar_contact_50ms_3e2af5d3` |

That is a short enough list to read one directory at a time, which is the only
review this evidence supports. The 125 entries with no directory on disk and the
tail of small ones are not worth a decision — 29 of the 82 are under 100 MiB.

**Rule 5 is a name-pattern match, and a name pattern is not a semantic
classifier.** `L4_K3_n{64,96,128}` is a grid-convergence ladder whose name
contains none of the words the rule looks for; it survived only because defect 2
was found first.

## Procedure — move, do not delete

```bash
# per worktree, with the manifest in hand
ARCHIVE=/gs/fs/tga-kozuma-kouhi/$USER/runs_retired_2026_08   # or a local volume
mkdir -p "$ARCHIVE"
while read -r d; do
    [ -d "runs/$d" ] && mv "runs/$d" "$ARCHIVE/"
done < disposable.txt
```

`mv` rather than `rm`: the classification above is evidence, not proof, and a
document could cite one of these tomorrow — at which point the citation gate
(`test_doc_run_citations_resolve.jl`) will say so and the directory can come back.
Deleting forecloses that; moving does not.

**Re-measure before running it.** The manifest is a snapshot; `docs/` changes
daily and a new citation moves a directory out of the disposable set.
