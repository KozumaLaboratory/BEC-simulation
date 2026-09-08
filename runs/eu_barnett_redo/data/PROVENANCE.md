# What each ledger supports, and what has no ledger at all

Recovered 2026-08-25 from `/gs/fs/tga-kozuma-kouhi/uk07267/{barnett_out,barnett_probe,barnett_redo}`
on TSUBAME. Until then this directory held **only** `.gitignore`: every number in
`../README.md` rested on job logs and four PNGs, and `fig4_efficiency.py` could not
be re-run at all.

The ledger CSVs were never in `.gitignore` — only `frames_*.jld2` and `*smoke*` are.
They were simply never committed, and the study's own outputs lived on the cluster
where nothing gated them.

Every row below is recomputed from the CSV in this directory, not copied from the
README. `eff` is `ΔF_z / |ΔL_z|` over the quench (`t ≥ 30`), `leak` is
`J_z(end) − J_z(quench start)` — zero in the continuum, so it is the error bar.

## Production cells

| file | cell | grid | xy half-box | eff | leak/conv | edge_x | supports |
|---|---|---|---|---|---|---|---|
| `ledger_minus_prod_box35.csv` | minus | 240×240×120 | 35 | 0.9806 | 2.0 % | 1.95e-05 | README box-35 row |
| `ledger_plus_prod_box47.csv` | plus | 320×320×120 | 46.67 | 0.9912 | 0.9 % | 2.41e-10 | README box-47 row, and the only clean full time series behind the 0.99 |
| `ledger_zero_prod_box35.csv` | zero | 240×240×120 | 35 | — (conv 7.3e-05) | — | 4.58e-05 | Ω = 0 control |
| `ledger_plus_nodd_prod_box35.csv` | plus_nodd | 240×240×120 | 35 | — (conv 0 exactly) | — | 3.28e-21 | DDI-off mechanism control |
| `ledger_plus_om055_prod_box42.csv` | plus, **Ω = 0.55** | 288×288×120 | 42 | 0.9937 | 0.6 % | 1.96e-06 | README Ω-scan row 0.55 (injection 1.4916, eff 0.994) |
| `ledger_{plus,minus,zero,plus_nodd}_prod_box28.csv` | all four | 128×128×80 | 28 | 0.5964 (plus/minus) | 68 % | 3.68e-04 | the **contaminated** box, kept because it is the only ±Ω pair at one geometry |

## Three README numbers have no time series

1. **The box-42 Ω = 0.74 cell — the row the 0.991 headline is quoted from — was
   overwritten.** The file that arrived under the name `ledger_plus_prod_box42.csv`
   is the **Ω = 0.55** run: over their whole overlap (167 rows, t ≤ 16.6) it is
   *bit-identical* to `ledger_plus_om055_prod_box42.csv` in every column, against a
   negative control (the Ω = 0.95 arm) differing by 8.96 in `L_z`. It was renamed
   accordingly, and the truncated duplicate deleted. This is exactly the
   output-name collision `variants.sh` documents — it clobbered the very row the
   README cites. What survives is the summary line in `leak_scan_prod.csv`:
   `leak 0.008564, conv 1.013251, dLz −1.021816, edge_x 8.904e-07` ⇒ eff 0.9916.
2. **There is no box-35 `plus` cell and there never was.** The README's box-35 row
   and figures 1–3 are the `minus` cell, read through the mirror. Figures that
   claim to show `plus` at box 35 do not have a `plus` file to show.
3. **The Ω-scan rows for 0.74 and 1.20 are log-derived.** `om120` and `om040` /
   `om095` were killed mid-stir (t_end = 11.8 / 18.6 / 13.3 against a stir of 30),
   so they never reached the injection point and are kept with a `_partial` suffix.
   Their summary rows (`conv 0.317254`, eff 0.9941) survive in `leak_scan_prod.csv`
   under the colliding tag `plus_prod_box42`, which is why the tag cannot be trusted
   to identify a row — read the geometry columns.

## The ±Ω mirror is a symmetry of the discretisation, not a measurement

At box 28, where both arms exist, `F_z`, `L_z`, `J_z`, `edge_frac` and `norm` are
**bit-identical after the sign flip** and the rest agree to the last printed digit
(1e-06). That is the expected result: the setup is symmetric under reflection in the
xz-plane (`B_y → −B_y`, `Ω → −Ω`, `F_z → −F_z`, `L_z → −L_z`) with the GS spin along
−x̂ invariant, and a cubic grid respects that reflection. So "the sign follows the
rotation" is guaranteed once the arms are built as mirrors, and the ± pair tests the
wiring rather than the physics.

What is measured, and could have come out otherwise: the conversion is **nonzero**,
`Ω = 0` gives 7.3e-05 of it, and switching the DDI off gives exactly zero.

## Geometry probes

`ledger_plus_probe_*.csv` (7 files) + `leak_scan_probe.csv` are the round-1/2 leak
hunt at probe stage lengths — base / pad / dtx / xybox / zbox / trunc / fine, one
knob each, dx held to the last digit. `ledger_plus_probe_finer.csv` +
`leak_scan_box28_and_probe.csv` carry the third dx point. These are the evidence for
"the leak is spatial, not temporal": `dtx` (dt halved) reproduces `base` to six
digits while `fine` moves the leak 2.1×.

## Not recovered

The `_prod_box35` `plus` cell (never run), the original box-42 Ω = 0.74 time series
(overwritten), and the box-42 Ω = 0.74 / 1.20 injections (logs only). Full `psi`
frames were never kept off-cluster and are not on it either.
