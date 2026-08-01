# What the 481 stored summaries are still for, and what they are not

**Measured 2026-08-02** across all worktrees. Companion to
[`doc_run_citation_inventory.md`](doc_run_citation_inventory.md) and the
re-derivation write-ups. **Nothing is deleted by this document** — it records the
evidence and a reversible procedure, because the targets sit in the main checkout
and four worktrees.

## The classification

474 run directories hold a stored `summary.json` (481 files).

| class | dirs | what cites it |
|---|---:|---|
| **exact name** | 10 | a live document names the directory |
| **glob family** | 72 | a live document names `runs/<stem>_*` |
| **uncited** | 392 | nothing in `docs/**` outside `archive/` |

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

### 7 of the 392 "uncited" are tracked in git

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

## The disposable set: 385 directories

392 uncited, minus the 7 tracked ones.

Every one satisfies all of:

1. no live document cites it, by name or by family glob;
2. it is not tracked in git;
3. its `summary.json` carries no producing commit — like all 481, it is not
   reproducible from the repository;
4. it predates the 2026-06/07 corrections, so any number in it is superseded by
   construction.

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
