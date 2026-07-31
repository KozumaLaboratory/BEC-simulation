# Figure 3 re-derived: seven of ten classifications changed

**2026-07-31, TSUBAME job 8309924 (cpu_16).** Re-runs the ten committed
`runs/eu_k3_sweep/*.yaml` on current `main` and compares against the stored
`summary.json` of 2026-05-26 — one of the 230 that predate every correction and
carry no producing commit.

`runs/eu_k3_sweep/summary.json` (gone) is the data behind **Fig 3 (a, b)** of
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

## Do not quote the high-K3 rows yet

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
- `runs/eu_k3_sweep_96/*.yaml` (gone) — the 96³ anchor for the same figure — is
  not re-run here.
