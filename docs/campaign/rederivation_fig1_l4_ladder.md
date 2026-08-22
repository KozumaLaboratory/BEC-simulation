# Figure 1 re-derived: peak density is 16.5 % lower, and the grid axis is irrelevant

> **FROZEN 2026-08-01.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**2026-08-01, TSUBAME jobs 8310351 / 8313735 (gpu_h).** Re-runs the committed n64
rung of `runs/l4_k3_ladder/*.yaml` and the two `runs/matsui_baseline/*_n64.yaml`
against their stored summaries of 2026-05-26 — among the 230 that predate every
correction and carry no producing commit.

`runs/l4_k3_ladder/`'s `summary.json` — the configs are tracked, the summary was
never committed — is the data behind **Fig 1 (a, b)** of
`four_figure_spec_2026_05_26.md` and behind claim row 1 of
`day_inventory_2026_05_26.md`, *"L4 isotropic no-collapse"*.
`runs/matsui_baseline/`'s `summary.json`, likewise uncommitted, is behind
**Fig 1 (c, d)**.

## The comparison, on the same quantity

`peak_max` is a maximum over time on both sides — taken from the run's own
`dynamics/peak_density` series, not from the final state.

| config | stored `peak_max` | re-derived | change |
|---|---:|---:|---:|
| `L4_K3_n64_HamOnly` | 0.00951101 | 0.00793751 | **−16.5 %** |
| `L4_K3_n64_K3` | 0.00949813 | 0.00792665 | **−16.5 %** |
| `L4_K3_n64_K3gdr` | 0.00949780 | 0.00792608 | **−16.5 %** |
| `L4_K3_n64_gdr` | 0.00951079 | 0.00793694 | **−16.5 %** |
| `L4_K3_n64_K3LHY` | 0.00953759 | 0.00692943 | **−27.3 %** |
| `matsui_40ms_dynamics_n64` | 0.00716601 | 0.00612421 | −14.5 % |
| `matsui_5ms_morphology_n64` | 0.00611232 | 0.00452326 | −26.0 % |

Four of the five L4 cells move by **the same −16.5 %**, agreeing with each other
to 0.14 %. K3 and γ_dr change nothing, which is the same conclusion Fig 3's
re-derivation reached from the other direction.

`K3LHY` is the outlier at −27.3 %, and it is the only cell with LHY active — so
its extra shift is the 2026-07 LHY corrections, isolated by construction against
the four `lhy: none` cells beside it.

## The n96 and n128 rungs were not run, on purpose

Raised by anko: is the rest of the ladder needed? Measured, no.

| | magnitude |
|---|---:|
| grid dependence, n64 → n128 at fixed physics (stored data) | **1.19 %** |
| the change this re-derivation found, at fixed n64 | **16.5 %** |

**The grid axis is a fourteenth of the effect**, the stored ladder was already
converged to ~1 %, and the shift is uniform across the physics branches — so the
higher rungs would restate −16.5 % at a few GPU-hours each. Spending that to
confirm a 1.2 % axis is the wrong trade. Stated rather than quietly skipped.

## A conservation scare that was mine, not the code's

I first flagged `Fz_drift` of 0.61–1.65 as "heavier than the classification
change". That was wrong, and the mistake was not checking what the conserved
quantity is.

These configs run **full MDDI** (`ddi.secular: false`). Under DDI, F_z is *not*
conserved — transferring spin to orbital angular momentum is the Einstein-de Haas
effect, which is the phenomenon being measured. The conserved quantity is
`J_z = L_z + S_z`:

| run | S_z(end) | L_z(end) | J_z(end) | ΔJ_z |
|---|---:|---:|---:|---:|
| `L4_K3_n64_HamOnly` | −5.3942 | −0.6056 | **−5.9998** | **+0.0002** |
| `L4_K3_n64_K3` | −5.3359 | −0.5953 | −5.9312 | +0.0688 |
| `matsui_40ms_dynamics_n64` | −4.8565 | −1.0524 | −5.9088 | +0.0912 |

The 0.606 I called drift appears in L_z as −0.6056 — **the same figure to four
places.** It is the signal. J_z holds to 2e-4 in the Hamiltonian-only cell; the
0.07–0.09 in the other two is K3 discarding atoms, which is what a non-Hermitian
loss does.

## Status of the claim

*"L4 isotropic no-collapse"* is unaffected in direction — nothing collapses in
either dataset — but every number under it moved by 16.5 %, and the figure should
be redrawn rather than re-captioned.

## The inset survives where the main panel does not

The inset's two lossy arms were re-run on TSUBAME. Its quantity is the surviving
fraction N(T)/N(0), which the stored summaries record as
`N_trajectory.N_final_ratio` and the v3 extractor as `1 − norm_rel_drift` — the
same number by construction, unlike ΔF_z below.

| config | stored | re-derived | change |
|---|---:|---:|---:|
| `matsui_40ms_lossy_medium` | 0.516038 | 0.516901 | **+0.17 %** |
| `matsui_40ms_lossy_strong` | 0.244302 | 0.243647 | **−0.27 %** |

**Two to three tenths of a percent, against −16.5 % on the same figure's main
panel.** The inset does not need redrawing.

That is a discrimination rather than a reassurance: both panels went through the
same pipeline on the same day and only one moved. Peak density is a local maximum
of the field and rides on the corrected LHY and dealias paths; the surviving
fraction is a volume integral of a K3 decay and does not. A campaign that had
re-derived only the inset would have concluded the figure was fine.

The re-derived runs also classify — `stable_arrest` (medium),
`sacrificial_arrest` (strong) — where the stored summaries classify nothing. New
information, not a comparison.

### What could not be compared, and why

The extractor schema changed between the two epochs. The stored summaries carry
a single `N_trajectory` block (`Fz_per_N`, `DeltaFz`, `N_final_ratio`, …);
`_extractor_version: 3` emits `Fz_drift`, `Mz` and `norm_rel_drift` instead.

- **ΔF_z is NOT reported here.** Stored `DeltaFz` is 3.478276 (medium) and
  re-derived `Fz_drift` is 3.328342, which looks like a −4.3 % shift — but
  `DeltaFz` is a per-atom difference over the `Fz_per_N` series while `Fz_drift`
  comes from a different extractor, and I did not confirm the two definitions
  agree. Quoting the ratio would repeat the Fig 3 error of comparing a
  time-maximum against a final-state value because both were called "peak".

  **CHECKED 2026-08-22 (#281). They do not agree, in three independent ways,
  and the caution was right.** Reading both definitions rather than inferring
  them — the retired one from `runs/eu151_edh_v2/extract_trajectory.jl` at
  `e2159486^`, the live one from `src/workflow/experiment_observables.jl:43`:

  | | stored `DeltaFz` | live `Fz_drift` |
  |---|---|---|
  | normalisation | **per atom** — `Fz_per_N[i] = Fz[i] / norms[i]` | **total** `F_z`, not divided by anything |
  | time reduction | **endpoint** difference, `[end] − [1]` | **maximum over the trajectory**, `max\|·\|` |
  | sign | signed | absolute value |

  Any one of the three would make the ratio meaningless. The first is decisive
  *on these particular arms*: they are the lossy ones, ending at **51.6 %** and
  **24.4 %** of their initial atom number, so dividing by `norms[i]` versus not
  is a factor of ~2 and ~4 by the end of the run. A −4.3 % agreement between two
  quantities that differ by a factor of four is a coincidence, and reporting it
  would have been the Fig 3 error exactly.

  **It is reconstructible, and that is a separate job.** The stored block keeps
  both `Fz_per_N` and `N_over_N0`, so the total series is
  `Fz[i] = Fz_per_N[i] · N_over_N0[i] · norms[1]`, and a like-for-like
  `max\|Fz[i] − Fz[1]\|` follows once `norms[1]` is pinned from the config. That
  needs the stored `trajectory.json` for these two cells, which is not what this
  re-derivation was scoped to open. Recorded here so the next person does not
  re-derive the obstruction.
- **`peak_max` has no stored counterpart** for these two configs. Their stored
  summaries contain `N_trajectory` and nothing else, so there is no like-for-like
  density number to put beside the main panel's table.

## Not covered

- Fig 1 (d)'s density slice is an analysis of `matsui_5ms_morphology_n64`, which
  is re-derived in the table above (−26.0 %), not a separate run — so the slice
  moves with it and does not need its own cell.
- The n96/n128 rungs, deliberately, for the reason above.
- ΔF_z on the lossy arms. The check is DONE (above, 2026-08-22): the two
  extractors do **not** define it the same way — per-atom vs total, endpoint vs
  time-maximum, signed vs absolute — so the comparison is not merely unconfirmed,
  it is invalid as posed. Reconstructing a like-for-like number is possible from
  the stored `Fz_per_N` × `N_over_N0` series and is scoped out here.
