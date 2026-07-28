# Stored `runs/` results: every one predates every physics correction

**As of 2026-07-29.** Audit of whether the results stored under `runs/` can be
quoted as current evidence. They cannot.

This is not a list of suspect cases. It is a single fact with a date.

## The measurement

230 `summary.json` files exist under `runs/` (this worktree plus the main
checkout). **Zero carry a producing commit** — the stamp only landed in #139, so
none can be retro-dated. Using file mtime as the only available proxy for
vintage:

| | |
|---|---|
| stored summaries | 230 |
| stamped with a commit | 0 |
| newest summary | **2026-06-02** |
| oldest | 2026-05-25 |
| summaries predating **all** the corrections below | **230 of 230** |

## The corrections they predate

Physics-affecting fixes merged after 2026-06-02, i.e. after the newest stored
result. Each changes numbers a spinor Eu run would produce:

| merged | correction |
|---|---|
| 2026-06-15 | ITP spin-rotation Stage-3 density bias (c₁ + DDI) — changes ground states |
| 2026-06-22 | Strang / Yoshida order under DDI restored via midpoint mean-field — the integrator was first-order with DDI |
| 2026-06-22 | LBFGS driven to its true gradient floor |
| **2026-07-08** | **Eu quadratic Zeeman was 11× too large** — affects every Eu run with a field |
| 2026-07-27 | `full_bdg` LHY UV counterterm (ε_k subtracted twice) |
| 2026-07-27 | scalar `c_lhy` short by π(a_s/a_ho)√N |
| 2026-07-28 | tabulated LHY dropped on the broadcast path; its energy 2.5× too large |

The quadratic-Zeeman one alone is disqualifying for any Eu result that used a
field: $q$ was wrong by an order of magnitude, and $q$ sets the m-level
structure.

## What follows

**No stored `runs/` summary is quotable as current evidence.** They are not
"slightly stale" and they are not auditable — auditing would need a per-run
comparison against current code, which costs the same as re-running. The A/B on
`eu_k3_lhy_control` measured what that gap looks like in one case: peak_max
0.007487 → 0.005775 and the collapse class moving `delay` → `marginal_arrest`,
of which the `c_lhy` fix accounts for only 2 %.

So a claim resting on a stored run has to be re-derived, not re-checked.

### Documents that cite stored runs

Highest counts first — these are where such claims live and where a reader is
most likely to pick one up:

| citations | file |
|---|---|
| 12 | `validation/self_contained_validation_report.md` |
| 12 | `validation/day_inventory_2026_05_26.md` |
| 11 | `manuscript/four_figure_spec_2026_05_26.md` |
| 10 | `manuscript/thesis/chapters/Ch5_TWA_chaotic_dynamics_integrated.md` |
| 9 | `manuscript/shared/figures.md` |
| 7 | `manuscript/klaus_quench_protocol_spec_2026_05_26.md` |
| 6 | `research_notes/eu_collapse_lhy_insufficient.md` |

All of these do carry a date — `self_contained_validation_report.md` opens with
"As of 2026-05-26" and `eu_collapse_lhy_insufficient.md` with "Date: 2026-05-07".
That is the honest form and it was checked rather than assumed.

The residual hazard is narrower: **a date does not tell a reader what changed
since it.** Someone reading "2026-05-26" has no way to know that the Eu
quadratic Zeeman was 11× too large until July, or that the DDI integrator was
first-order until late June. So each of these files now carries a one-line
pointer here, which is the part a date cannot supply.

## What is *not* affected

- Everything gated by a test in a tier. Those run against current code on every
  push, which is the point of the tier system.
- The results produced during 2026-07-27/28 and recorded in
  [`dipolar_supersolid_tube.md`](dipolar_supersolid_tube.md) and
  [`superfluidity_knowledge_state.md`](superfluidity_knowledge_state.md). Those
  post-date the corrections and their figures ship with the scripts that made
  them.
- Claims that turn on a coefficient identity rather than a run — e.g. the SI
  round-trip oracles, $Q_5$ closed forms, $a_{dd}$ values.

## First re-derivation: the conclusion held, the evidence was vacuous

`research_notes/eu_collapse_lhy_insufficient.md` claimed all five LHY treatments
give identical density profiles for the Eu F=6 EdH post-quench collapse, hence
"LHY is sub-leading vs the mean-field DDI attraction".

**The conclusion survives.** Re-run in current code, same GPU backend, the four
usable modes agree to 4.7 % in peak density:

| mode | $E$ | peak $n$ | FWHM$_z$ | $M_z$ |
|---|---:|---:|---:|---:|
| off | −881.086 | 0.01014 | 10 | −5.4104 |
| scalar | −880.993 | 0.00968 | 10 | −5.4567 |
| polar_contact | −881.022 | 0.00982 | 10 | −5.4431 |
| fm_contact | −881.022 | 0.00982 | 10 | −5.4431 |
| *full_bdg* | *−847.324* | *0.00054* | *22* | *−5.9955* |

**Its evidence did not.** Three of the original five rows ran with `c_lhy = 0` —
that config is `backend: gpu` and until #125 every tabulated LHY was silently
zeroed on the GPU broadcast path — and a fourth ran 2.34× too weak. "All five
identical" was four flavours of *off*: the observation was guaranteed regardless
of the physics. The closed forms are active now (all three differ from each other
and from `off`), so the comparison could have come out otherwise, which is what
makes it evidence.

`full_bdg` is excluded: it self-reports "mean field is dynamically unstable
(max Im ω = 213), ε_LHY is scheme-dependent here", and its ITP returned
`conv=false`.

**This is the pattern to expect from the rest of the list.** Not "the numbers
moved a little" but "the comparison was between things that were secretly the
same". A stale null result is the dangerous kind, because a broken knob and a
knob that does not matter look identical.

### Two false starts, recorded because they are the same trap

Both were mine, both caught before they shipped, both by checking the code's own
report rather than by reasoning:

1. First re-run reported the closed forms cutting peak density **15×** and
   arresting the collapse. That was #158 — closed-form tables $N_{atoms}$ too
   large — which merged **22 minutes after** the run. Caught with
   `git merge-base --is-ancestor`, i.e. by asking whether the run contained the
   fix rather than assuming it did.
2. The surviving 19× outlier was nearly quoted as "LHY can arrest this collapse".
   It was `full_bdg`, which prints a warning saying its ε_LHY is
   scheme-dependent for exactly this state, and did not converge.

Generalisation for anyone re-deriving from this list: **check the run's commit
against the fix list above, and read the run's own warnings, before comparing
numbers.**

## Second re-derivation: a figure whose premise no longer exists

`manuscript/four_figure_spec_2026_05_26.md` Figure 2 specifies that "F=6 collapse
arrest in the cigar stress regime is determined by the LHY closure, NOT by
three-body loss K₃", with `off` and `scalar` collapsing (`delay`) while
`polar_contact` / `icosahedral` cap the peak (`stable_arrest`).

Re-running the K₃=0 factorial on current `main`:

| arm | ratio now | class now | ratio 2026-05 | class 2026-05 |
|---|---:|---|---:|---|
| off | **1.0502** | stable_arrest | 2.3339 | delay |
| scalar | **1.1839** | stable_arrest | 2.3599 | delay |
| polar_contact | **1.3883** | stable_arrest | 1.6294 | stable_arrest |
| icosahedral | **1.2801** | stable_arrest | 1.5991 | stable_arrest |

**All four arms arrest.** The figure's premise — that there is a collapse for the
LHY closure to determine — is absent from current code. The ordering has also
inverted: the closures now arrest *least*.

This is a different failure mode from the first re-derivation. There the
conclusion survived a vacuous comparison; here the *phenomenon* is gone. Between
them they cover both ways a stored result can fail: the knob was broken, or the
thing the knob acted on no longer happens.

Note also the ground-state peak density: 0.0044–0.0046 for off/scalar but
0.0177–0.0185 for the closed forms, a factor 4 *after* #158. That gap is
unexplained and is not what the caption describes — it needs its own work before
any of these arms is quoted.

## Recommended order

1. **Do not re-run 230 suites.** Most were exploratory. Re-derive only what a
   live document actually claims.
2. Start with the two undated documents above, since they read as current.
3. New runs are self-dating: `summary_provenance(run_dir)` reports the producing
   commit and whether the tree was dirty. A summary with `stamped == false` means
   the question cannot be answered from the file — treat it as this audit treats
   all 230.
