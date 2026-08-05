# Figure 3 re-derived: seven of ten classifications changed

> **FROZEN 2026-07-31.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**2026-07-31, TSUBAME job 8309924 (cpu_16).** Re-runs the ten committed
`runs/eu_k3_sweep/*.yaml` on current `main` and compares against the stored
`summary.json` of 2026-05-26 — one of the 230 that predate every correction and
carry no producing commit.

`runs/eu_k3_sweep/`'s `summary.json` — the configs are tracked, the summary was
never committed — is the data behind **Fig 3 (a, b)** of
`four_figure_spec_2026_05_26.md` and behind claim row 5 of
`day_inventory_2026_05_26.md`, *"K3 not primary arrest mechanism"*.

## The comparison

| K3× | stored `classification` | re-derived `collapsed` | `energy_rel_drift` | F_z drift |
|---:|---|---|---:|---:|
| 0 | delay | **stable_arrest** | 7.1e-07 | 0.32 |
| 1 | delay | **stable_arrest** | 0.015 | 0.33 |
| 3 | delay | **stable_arrest** | 0.045 | 0.40 |
| 10 | delay | **stable_arrest** | 0.138 | 0.70 |
| 30 | delay | **stable_arrest** | 0.342 | 1.40 |
| 100 | delay | **stable_arrest** | 0.687 | 2.84 |
| 150 | delay | **sacrificial_arrest** | 0.794 | 3.41 |
| 200 | sacrificial_arrest | sacrificial_arrest | 0.856 | 3.80 |
| 250 | sacrificial_arrest | sacrificial_arrest | 0.896 | 4.10 |
| 300 | sacrificial_arrest | sacrificial_arrest | 0.922 | 4.32 |

**Seven of ten changed. `delay` has disappeared from the sweep entirely.**

The K3 = 0 row is not a new result: it is the same cell as Figure 2's `off` arm,
whose stored `ratio` of 2.3339 was already re-derived to 1.0502 with the class
moving `delay → stable_arrest`. What is new is that the *whole sweep* moved with
it, so the figure's shape — not just one anchor — is different.

## What it does to the claim

*"K3 not primary arrest mechanism"* **survives, and its support changed
completely.**

- Formally it is now stronger: the cloud arrests at K3 = 0, so the arrest cannot
  be K3's doing.
- But the stored figure argued it through a **transition** — `delay` at low K3
  giving way to `sacrificial_arrest` at high K3. That transition is gone. What
  remains is "arrest everywhere, turning sacrificial above K3 ≈ 150".

A sentence that survives on different evidence is not the same claim. Anyone
quoting Fig 3 should quote the new shape.

## Most of the sweep is not at a physical K₃

Raised by anko, and it was missing from my first write-up: I judged the rows by
their drift and never asked why those K₃ values were being measured at all.

The configs' own header says `K3_factor = 1.0 × Dy proxy = 1.0e-41 m⁶/s` — a
**dysprosium** proxy, not an ¹⁵¹Eu measurement. Eu's measured value, with the
convention unified 2026-07-25, is **direct K₃ ≈ 1.2×10⁻⁴¹** (the branch where the
thesis `L` and the 1.4 s lifetime agree) against **effective K₃(BEC-fit)
≈ 4.6×10⁻⁴²**, a ~2.6× systematic. In this sweep's units that is
`K3_factor ≈ 0.46 – 1.2`; allowing the systematic, 1 – 4.

| factor | K₃ [m⁶/s] | × measured direct (1.2e-41) |
|---:|---|---:|
| 1 | 1.0e-41 | 0.83 |
| 3 | 3.0e-41 | 2.5 |
| 10 | 1.0e-40 | 8 |
| 30 | 3.0e-40 | 25 |
| 100 | 1.0e-39 | 83 |
| 150–300 | 1.5–3.0e-39 | 125–250 |

**Seven of the ten points sit at ≥ 8× the measured value, reaching 250×.** As a
search for an arrest threshold that is a deliberate choice; as the evidence under
"K3 is not the primary arrest mechanism" it means the regime the claim was argued
in is not Eu's.

It also sharpens the point below: **the trustworthy rows and the physical rows are
the same rows.**

| factor | drift | × measured | usable |
|---:|---:|---:|---|
| 0, 1, 3 | ≤ 0.045 | 0 – 2.5 | **yes** |
| 10, 30 | 0.14, 0.34 | 8 – 25 | neither comfortably |
| 100 – 300 | 0.69 – 0.92 | 83 – 250 | no |

The reversal `delay → stable_arrest` happens at factors 0, 1 and 3 — trustworthy
and physical — so the headline stands. But the stored figure's *transition* to
`sacrificial_arrest` sat near factor 150, i.e. **125× the measured K₃**. Even had
the old numbers been right, that transition was never within reach of Eu's
physics.

## The high-K3 drift is physical, not numerical — settled 2026-08-01

The write-up below withheld the high-K3 rows because `energy_rel_drift` climbs to
0.92 and I had not separated K3's physical (non-Hermitian) energy loss from
numerical error. Settled by halving dt twice on `K3x300p0` — TSUBAME job 8315303:

| dt | `energy_rel_drift` | `norm_rel_drift` |
|---|---:|---:|
| 0.005 | 0.921524 | 0.710369 |
| 0.0025 | 0.921540 | 0.710330 |
| 0.00125 | 0.921544 | 0.710311 |

**Quartering dt moves the drift by 2.2e-5 relative.** Numerical error would fall
with dt — by 4× if first order, 16× under Strang. It does not move at all.

The corroboration is in the same table: `norm_rel_drift = 0.71`, i.e. **the run
loses 71 % of its atoms.** A 92 % energy decrease alongside a 71 % atom loss is
what a three-body loss channel does; it is the physics the config asks for.

So the integration is sound at every K3 in the sweep, and the earlier caution was
misplaced. **The reason not to quote the high-K3 rows is the other one: the
parameter is not Eu's.** Factor 300 is 250× the measured K₃, and no amount of
numerical accuracy makes that row a statement about ¹⁵¹Eu.

## Superseded caution (kept for the record)

`energy_rel_drift` climbs monotonically with K3, from 7.1e-07 to **0.92**. K3 is
a non-Hermitian three-body loss, so energy *should* fall — but I have not
separated that physical decrease from numerical error, and until that is done a
92 % drift is not a number to build on.

The low-K3 rows (0, 1, 3) sit at ≤ 0.015 drift, and **that is where the reversal
is**: `delay → stable_arrest` with the energy essentially conserved. The headline
therefore does not depend on how the drift question resolves.

F_z drift rises the same way, 0.32 → 4.32.

## Schema note

The stored rows carry `classification`; the current extractor (`_extractor_version: 3`)
writes `collapsed`. Same axis, different field name — worth knowing before
diffing the two files mechanically.

## Not covered

- The stored `peak_max` is a maximum over time. The first comparison I attempted
  used the peak of the **final** state, which is a different quantity; it is not
  reported here. The classification comparison above is like-for-like because
  both sides compute it the same way from their own run.
- `runs/eu_k3_sweep_96/`'s configs are tracked but its stored summary is not — the
  96³ anchor for the same figure is
  not re-run here.
