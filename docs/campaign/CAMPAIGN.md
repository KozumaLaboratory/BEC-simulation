# Campaign charter — re-derivation & phase selection

**Every campaign session reads this file first.** Per-session prompts stay short and
point here; do not paste this content into a prompt.

Scope: one campaign, four lanes (A/B/C/D), two gates (G1/G2). A session is one lane
item, one PR, one machine-checkable exit criterion.

Cross-cutting record (dated, FROZEN): **`lessons_2026_08_04.md`** — one latent code defect (a
GPU dispatch reachable only on a stage-cache hit), two defects in the instruments
used to observe the work (no clock; a memory index 43 % over its load limit with
41 % never loaded), and the classes the day's six self-corrections fell into. Five
of the six were invisible from the inside.

---

## 1. Why this campaign exists

`docs/validation/stored_results_vintage_audit.md`: 230 stored `summary.json` files,
**0 stamped with a producing commit**, newest 2026-06-02 — all predate the physics
corrections below. Two re-derivations already executed showed both failure modes:

1. **The conclusion survived but the evidence was vacuous.** Four of five LHY arms were
   secretly `c_lhy = 0`; "all five identical" was guaranteed regardless of physics.
2. **The phenomenon itself was gone.** `four_figure_spec` Fig. 2's premise does not
   reproduce on current code.

> A stale null result is the dangerous kind, because a broken knob and a knob that does
> not matter look identical.

The campaign's job is not to re-run 230 suites. It is to make every **live claim**
re-derivable, and to install gates so this class of failure cannot recur silently.

---

## 2. The correction fix-list (authoritative)

Any run whose producing commit is **not** a descendant of all of these is disqualified
as campaign evidence.

The machine-readable ref list is **`docs/campaign/fix_list.toml`** — the file guard 1
reads, and the only place the SHAs are declared. The table below is the human-readable
context and deliberately carries no SHAs, so the two cannot drift. It has 17 entries to
this table's 14: the June integrator row expands into the four propagator paths that
carried the same defect (#45 Strang, #46 Yoshida, #47 adaptive, #49 combined step).
`test/test_campaign_fix_list_gate.jl` pins the two counts against each other
and re-runs the ancestor check over every ref, so neither the drift nor a dead ref is
left to a reader.

| merged | correction | effect |
|---|---|---|
| **2026-04-28** | **`c_dd` carried an unnecessary F² = 36 factor** | effective DDI 7,647 → 275,292. **Every DDI-dependent result before this ref is void.** Added to the machine-readable list on 2026-08-25: until then the only record in the tree was a code comment, so guard 1 could not see it — the #343 class, at the oldest correction in the campaign |
| 2026-06-15 | ITP spin-rotation Stage-3 density bias (c₁ + DDI) | changes ground states |
| 2026-06-22 | Strang/Yoshida order restored under DDI via midpoint mean-field | integrator was **1st order** with DDI |
| 2026-06-22 | LBFGS driven to its true gradient floor | changes converged GS |
| **2026-07-08** | **Eu quadratic Zeeman was 11× too large** | disqualifies every Eu run with a field |
| 2026-07-27 | `full_bdg` LHY UV counterterm (ε_k subtracted twice) | divergent at every F |
| 2026-07-27 | scalar `c_lhy` short by π(a_s/a_ho)√N | 6.8× for ¹⁵¹Eu |
| 2026-07-28 | tabulated LHY dropped on the GPU broadcast path (#125) | LHY silently off |
| 2026-07-28 | tabulated LHY energy 2.5× too large | — |
| **2026-07-29** | **211 Eu configs pinned m = −F under a field that prefers m = +F** | the dynamics ran in a field opposing the prepared polarisation; **configs, not code** — see below |
| #158 | closed-form tables `N_atoms` too large | caused a spurious 15× arrest |
| #174 | closed-form LHY drift (135 % → ~1e-9; LHY 97 % → 5–7 % of total) | — |
| #139 | `summary_provenance` / `_repo_commit` stamping landed | pre-#139 runs cannot be retro-dated |
| **2026-08-19** | **the EdH-quench corpus was studying the ALIGNED preparation** | the cascade only runs from the Zeeman-HIGHEST state: +16.5 % vs −0.45 %; **configs, not code** — same caveat as the 2026-07-29 row |

**The gate is mechanical, not a judgement call.** Use
`git merge-base --is-ancestor <ref> HEAD` over every ref in `fix_list.toml` — not "this
run looks recent". One re-derivation was nearly published because a fix merged **22
minutes after** the run. Run it with
`julia --project=. scripts/cli.jl campaign-gate` (`--runs` to sweep stored runs).

**The 2026-07-29 row is the one that does not mean what the others mean.** Every other
ref corrects code, so "the producing commit descends from it" is the whole question.
That one corrects the **config corpus**, and descent only says the repaired YAML *was
available* — a run can descend from it and still have been launched from an
uncommitted copy carrying the old sign. Descent is necessary, not sufficient; for that
row also check the config the run actually consumed. It was added 2026-08-19 (issue
#343) after being cited as a disqualifying correction by
`docs/manuscript/klaus_protocol_sheet.md` while absent from the machine-readable list —
i.e. the gate could not see the fix the prose leant on.

---

## 3. Stale documentation — four of the five overrides are now discharged

Measured 2026-07-30 by reading code against docs; **re-measured 2026-08-02 before
this charter landed**. Four of the five rows had been fixed at the source in the
meantime. They are kept as a record, struck, rather than deleted — a table that
claims to override `CLAUDE.md` is exactly the thing that must not be allowed to
go stale unnoticed.

| Doc says | Reality | Status 2026-08-02 |
|---|---|---|
| ~~`CLAUDE.md:256` — tensor c2/c4 not in `energy_gradient!`, LBFGS falls back to ITP `[KNOWN-LIMIT]`~~ | Retired 2026-06-09; LBFGS/Newton-CG optimise the full Hamiltonian including `TensorTerm` | **DISCHARGED** — `CLAUDE.md:261` now states this; no `KNOWN-LIMIT` remains in the file |
| ~~`ueda_status.md:32,80` — independent reference-RHS "(planned)"~~ | Exists, `src/validation/reference_rhs/` | **DISCHARGED** — both sites read "(implemented)" |
| ~~`matsui_reproduction_status.md` Level 5 — "not started; needs imaging pipeline"~~ | The imaging chain is complete | **DISCHARGED** — the row now reads "the pipeline EXISTS … Blocker is the Fig-2C source data, not the code" |
| ~~`README.md` CI badge points at `anko9801/BEC-simulation`~~ | — | **DISCHARGED** — no such URL in `README.md` |
| `dthesis_year1_roadmap.md:41` — Q2 dated 2027-07 marked "CLOSED AHEAD OF SCHEDULE (2026-05-11)" | The document is internally inconsistent as a plan | **OPEN**, narrowed. The affiliation half of the original row was wrong: the doc says 上妻研, never 上妻研（東大）, so there is nothing to correct there |

**Consequence for planning:** the tensor gradient is on the critical path for Lane C.
It works. Use LBFGS, not ITP, for tensor-active ground states.

**Structural fix (session S-DOC):** every `KNOWN-LIMIT` / `not implemented` / `planned`
claim must carry a machine-checkable predicate (a test name or a grep assertion) that
**fails when the limit no longer holds**. Same discipline as the existing
set-equivalence meta-test. Four rows discharging themselves within three days,
silently, is the argument for it: nothing told anyone.

**And a `KNOWN-LIMIT` that says a coefficient is gated by NOTHING is a defect
report, not a caveat.** `test_bogoliubov_anchor.jl` carried exactly that sentence
about the DDI block of the homogeneous BdG. When the block was finally derived
(#361, 2026-08-19) it was wrong in two independent ways at once — the normal term
was the Hartree piece, which is identically zero for a uniform cloud, so it was
2× on a polarized state and structurally absent on a polar one — and the μ it fed
depended on the probe direction, in four hand-written copies of one assembly.
Neither could have survived a single gate. The rule that follows is cheap:
**when a header names an ungated coefficient, treat that sentence as the work
item, and do not read the absence of red as agreement.** The correction moved the
most-unstable direction of a production Eu fixture from 15° to 90°
(`docs/validation/bdg_ddi_verdict_delta_361.md`) while every gated verdict stayed
green — which is what "gated by nothing" means in numbers.

---

## 4. Guards — fail-closed, on every campaign job

### Pre-flight (register as `:block` in the inspector)

1. **Ancestor gate.** `HEAD` must descend from every ref in §2. Refuse otherwise.
2. **Clean tree.** Dirty ⇒ `:block`. `summary_provenance(run_dir).stamped` must be true.
3. **DDI mode is a decision.** Compute `ω_L / (c_dd·⟨n⟩)`; require the config to state
   `secular:` explicitly. `spin_rotating_frame_omega ≠ 0` already requires
   `secular_ddi=true` (`ArgumentError`) — do not weaken.
4. **Resolution floor.** Grid points per healing length ≥ 4. A droplet seed at 1.6
   points/σ once produced ΔE = +35.7 of pure representation error.

### Post-run (classify in `outcome.toml`, do not leave to a human reader)

5. `energy_rel_drift` above tier threshold ⇒ `:killed_data`, not a data point.
6. **Record the LHY fraction of total energy.** > 15 % ⇒ auto-disqualify. The 97 % case
   was the table's magnitude, and it looked like a result.
7. `conv == false` ⇒ disqualified.
8. **Ingest the run's own warnings into the summary.** `full_bdg` prints "mean field is
   dynamically unstable, ε_LHY is scheme-dependent here" — that must not depend on a
   human reading stdout.
9. `spin_direction_spread > 0.05` ⇒ drop `superfluid_fraction` from quotable outputs
   (density-only $f_s$ overestimates by up to ~20× on a textured spinor).
10. Any result using `SpatialLHY` must quote `spatial_lhy_residual` (~1–3 %) alongside.
11. F32 mixed-precision runs are not figure-eligible until an F64 parity point exists.

### Independence

Parallel sessions reading the same `CLAUDE.md` are **not** independent — they share
conventions, the sign source-of-truth, and any stale limit. Only four things buy
independence: external code, someone else's measurement, an analytic identity, and a
disagreeing human. Note which one a claim rests on.

---

## 5. Claim taxonomy (from `CLAUDE.md`, enforced here)

- **A — code correctness**: units, sign, conservation, bit-identity, GPU = CPU.
- **B — physics agreement**: closed-form limits, F=1 polar vs FM, polyhedral classification.
- **C — model fidelity**: comparison to published experiment (Matsui EdH, Klaus et al. 2022,
  Yan-Li-Saito Barnett).

Every numeric claim a session writes must carry: **type (A/B/C) + producing commit +
test tier**. "Tests pass" is A. "Matches Matsui" is C. Do not conflate.

For ¹⁵¹Eu: **type A is achievable now; type C is blocked on atomic-physics inputs** for
anything depending on channel-resolved interactions. Claims resting only on $q$,
$\epsilon_{dd}$, or geometry are quotable today.

**Per claim, that split is `as_dependency_map.md`.** The boundary is sharper than
this paragraph implies and it is exact: the one measured input, $a_{12} = 110(4)a_B$,
IS the constraint $c_0 + 36c_1 = c_\text{total}$, and the stretched pair plus its
first magnon are pure $S = 2F$ — so a fully polarized cloud's mean field, LHY (FM
closed form), phonon branch and first magnon cannot be moved by the six unmeasured
channels at all, while the phase diagram is nothing *but* those channels. Gated by
`test/oracles/test_stretched_channel_invariance.jl`.

---

## 6. Parallel axes

| ✅ parallelise | ❌ keep serial |
|---|---|
| seed (cheapest, prefer it) | time evolution |
| grid / dt / box / `k_cut` / `ddi_pad_factor` / cutoff on-off | continuation axes (B-scan, ε_dd ladder) |
| δg_S sample points | branch tracking (converge each branch, *then* compare energies) |
| prior samples (SBI) | ITP relaxation (ITP is minimisation, not smoothing) |
| LHY closure arms, DDI modes | — |
| k points (BdG) | — |
| imaging axis, TOF times | — |

Parallelising a continuation axis destroys branch tracking. This is the one axis choice
that is not obvious.

---

## 7. Cost model

Anchor: `gpu_step_us = 3207.21` at 64³ D=13 (`ddi_rotation_us = 334.89`),
`gpu_busy_pct = 96.88`. FFT-limited ⇒ scale ∝ cells.

| grid | t_step (est.) | 5 ms (T=3.456) | 40 ms (T=27.65) |
|---|---|---|---|
| 32³ | ~0.4 ms | 1.4 s | 11 s |
| 64³ | 3.2 ms (measured) | 11 s | 88 s |
| 96³ | ~11 ms | 38 s | 5 min |
| 128³ | ~26 ms | 90 s | 12 min |

(dt = 1e-3 assumed; substitute the measured dt.) State array at 128³, D=13, complex F64
is 436 MB; 2–4 GB with Workspace.

**Packing:** ≥ 64³ ⇒ one config per GPU (occupancy already 96.88 %). 32³ ⇒ 4–8 separate
processes per GPU (processes, not streams).

Budget: campaign cap 30.0 points, spent 0.0542, balance 338.77. **The cap is the
binding constraint, not the hardware.** Raise it deliberately before Lane D round 2.
Suggested split: A 0.5 · B 4 · C 2 · D 15 · reserve 8.5.

---

## 8. Lanes and gates

```
t=0 ─┬─ Lane A  (CPU, independent anchors) ─────────────► G1
     ├─ S-G0   (guards, §4)                ─────────────► G1
     ├─ S-DOC  (drift, §3)
     └─ Lane C1/C2a/C3 (CPU algebra, runs during Lane B)

G1 = every Lane A anchor green + guards installed
     └─┬─ Lane B2/B4/B5 (GPU, embarrassingly parallel)
       ├─ Lane B1/B3    (B3: B axis serial)
       └─ Lane D3 + D2  (CPU, cheap) ──────────────────► G2

G2 = D3 has ranked the observables by Fisher information
     └─ D1a (32³ ×1000) → D1b (64³, SNPE rounds) → D1c (96³ spot-check)

C2b runs once C2a and A4 are both green, as GPU frees up. C4 (secular vs full DDI
factorial at the degeneracy) follows C2b on the same allocation.
```

**No campaign GPU job before G1.** At 30× throughput the audit pile grows 30× too;
ordering is worth *more* when execution is cheap, not less.

---

## 9. Session hygiene

- **One session = one lane item = one PR.** The repo's workflow is PR merges (#183–#194).
- `/clear` between sessions. Do not carry a finished item's context forward.
- Use **plan mode** for design-heavy items (C1, C3, D1, S-G0): plan → approve → implement.
- Use **subagents** for read-only breadth (e.g. "audit all docs for stale limit claims").
  Keep the main context for the edit.
- **Bounded reading.** Each prompt lists the files to read. Do not read `runs/` wholesale.
- **Before treating a defect as new, check whether it has a class.**
  `pr_mistake_census_2026_08_22.md` folds PR #1–#446 into eight recurring classes
  and names the gate standing over each. Every class has one; the point of
  looking is to find out that the thing you just hit is already understood, and
  which gate should have caught it. The document is FROZEN — the present is held
  by the gates, and if the two disagree the gate wins. `scripts/pr_mistake_census.py`
  re-derives it (`--verify-doc`, `--extract --since <n>`, `--counts`).
- If the session degrades or exceeds its turn estimate by ~2×: **write a handoff note to
  `docs/archive/` and stop.** Do not push through.
- Respect `.githooks/pre-commit`, `.JuliaFormatter.toml`, and `CLAUDE.md`
  "Conventions (do NOT fix)" and "Design boundaries (intentional non-support)" —
  **except** where §3 above overrides.
- **Do not touch performance** during a physics session. `gpu_busy_pct` has 3.1 % of
  headroom left; marginal value is ~zero relative to validation.

## 10. Definition of done (campaign session)

1. Exit criterion met, stated as a command someone else can run.
2. New/changed behaviour gated by a test in a named tier.
3. Every numeric claim labelled A/B/C with producing commit + tier.
4. Docs touched in the **same commit** as the code (naming convention: file name =
   primary export; renames delete the old name).
5. If a limit was removed, its §3 row or `CLAUDE.md` entry is deleted in the same PR.
6. If the session produced no result: say so plainly and record what was ruled out. A
   recorded negative is worth more than a reframed positive — see the three successive
   reframings of Figure 2 in one day.

---

## 11. ¹⁵¹Eu quick facts (use these, not memory)

F = 6 (13 components), g_J = 1.9934, g_F ≈ 1.163, μ ≈ 6.977 μ_B, a_s = 110(4) a₀,
$\epsilon_{dd}$ ≈ 0.54, $a_{dd}$ ≈ 59 a₀.
**q/h = 1.42 kHz/G² at 1 G** (post-2026-07-08; any earlier figure is 11× high).
Measured 2026-07-30 with `compute_quadratic_zeeman` (`src/hamiltonian/coefficients.jl:310`;
there is no `bfield_to_q`): 1 G → q/h = 1421 Hz, 3 G → 12.79 kHz, 1.32 G → 2.48 kHz,
but **2.6 nT → q/h = 9.6e-7 Hz against p/h = 42.3 Hz**, a ratio of 2.3e-8. So the 11×
error is decisive in the gauss band — the (p,q) diagrams, `eu151_B_sweep_pm120`, the
1.32 G Feshbach region — and cannot move an nT-band EdH run at all. Weak-field runs are
still disqualified, but by the integrator / ITP-bias / LHY corrections, not by q. Order
the re-derivation accordingly: gauss-band scans first, since only there is q the reason.
Constraint `c₀ + 36 c₁ = 4π(a_s/a_ho)N`. Only $a_{12}$ is known — the other six $a_S$
have **never been measured and have no theoretical value to quote**; Tomza's Eu+Eu work
fixes only the long range ($C_6 = 3610$ a.u. ⇒ $R_6 = 178\,a_0$). ¹⁵³Eu's registry entry
carries the ¹⁵¹Eu value as an explicit placeholder. `K_3` has a ~2.6× systematic between
direct and BEC-fit determinations.

At uniform $g_S$ the σ_S sum rule degenerates **the whole spinor manifold**, not four
phases. $\sum_{S\,\text{even}} \sigma_S(\zeta) = \langle \zeta\otimes\zeta | \zeta\otimes\zeta\rangle = 1$
for **any** normalised $\zeta$ — the even-$S$ states span the symmetric two-body
subspace, so the sum rule is an identity and not a coincidence of the four
candidates. Hence $\varepsilon_{MF}(\zeta) = g/2$ everywhere on $\mathbb{CP}^{12}$,
and Eu sits on the FM/cyclic/$I_h$ triple junction of the *physical* $g_S$. Mean field
cannot select the phase. That is the campaign's central physics opportunity, not a
problem.

**The dimension is what makes it an opportunity rather than a curiosity.** Order-by-disorder
needs a *continuous* accidental degeneracy: four isolated points would let fluctuations
choose between them by an energy difference, but only a continuous manifold has a
would-be Goldstone mode for the selection to gap. This is the same structure Turner *et
al.* (PRL **98**, 190404) exploit for the spin-2 nematic manifold, at higher dimension.
Ledger row: `f6-uniform-gs-degenerates-the-whole-manifold`. **Do not restate the four-phase
form** — it was written here and in memory until 2026-08-25 and it understates the result
in exactly the way that would have killed the pseudo-Goldstone programme on paper.
---

## 12. Blind analysis — the half the prediction field does not cover

**Scope: type-C only.** Do not apply this to A or B; a bit-identity check has nothing
to hide from.

The ledger already protects the **hypothesis**: `prediction_registered = before | after`,
and the gate refuses to count an `after` row as a prediction. Nothing protects the
**analysis**. Between "the observable was fixed before launch" and "the number came out"
there is a step where the window, the reduction, the fit range and the rejection rule get
chosen, and at 10.4 nT three readings of the same cached arms put the argmax at three
different points. That is not a measurement, and no registration field sees it.

So, borrowing the standard from particle physics:

1. **Freeze the analysis on synthetic data.** Observable definition (window / reduction /
   boundary — the `quantity` fields), fit method, rejection criterion and error treatment
   are fixed against the synthetic SG / TOF / tomography pipeline. Commit them.
2. **Salt the real data.** Apply an offset the analyst does not know.
3. **Run the frozen pipeline on the salted data.**
4. **Unblind.** If the pipeline is changed after unblinding — sometimes it must be — the
   change and the reason are recorded. The rule is not "never touch it"; the rule is that
   touching it after seeing the answer is **visible**.

**One analyst.** With a single person, salt-and-forget is not available, so use
commit-and-reveal: draw the salt, commit `sha256(salt)` to the tree with the frozen
pipeline, and disclose the salt at unblinding. The hash is what makes step 4 checkable by
someone else later, which is the whole point.

**Cost is a convention, not code.** The synthetic observable pipeline already exists; what
is missing is the agreement about when it is allowed to be edited.

**What this buys.** "Nothing in this repo has been fitted to an experiment" is currently
a *claim about our own conduct*. Under this protocol it becomes a property of the record,
which is the same move the ledger made for claim status — and the same reason.

Related: `docs/campaign/claims.toml` (`quantity`, `prediction_registered`), §10 above.
The FLAG-style quality colouring used in lattice QCD is the natural external-facing
presentation of the A/B/C split plus these tags, if the campaign ever publishes the table.

---

## 13. The claim lifecycle, and the ladder each type has to walk

`status` says whether a claim is still believed. **`lifecycle` says what it has been
through**, and the two are orthogonal.

```
exploratory → candidate → registered → published
```

| state | bound by | may be used for |
|---|---|---|
| **exploratory** | **nothing** | anything. This is the point |
| **candidate** | everything the ledger parser already demands | internal argument |
| **registered** | the ladder below | **prose, slides, the lab** |
| **published** | registered + an unblinding record (§12) | outside |

**The first state is ungated on purpose, and that is the load-bearing part.** Every
other rule in this campaign binds a row that is already written down. None reaches the
stage where a number is being *found*, and none should: the measured lesson here is that
a gate which reddens during correct work gets disabled, and a disabled gate protects
nothing. Gates bind **at the moment a claim becomes words**, not while it is being
discovered.

Absent means `candidate` — a row is in the ledger, so it is at least that.

### The ladders, derived from what actually went wrong

The 18 retirements in the ledger fall into five shapes. Each ladder is the counter to one.

**Numeric claims** — against *the convergence illusion* (`32³/64³ agree to 4 digits`,
which was +2.47 % one-signed) and *coefficient/scaling* errors (`c_dd` × F² = 36, the
11× quadratic Zeeman):

- **three points per cutoff axis, and check monotonicity.** dx, dt, hold length, box,
  `nev`, `ε_cut`. **Two points are banned**: two values cannot separate agreement from a
  shared offset, and that is exactly how the 4-digit claim survived.
- **one analytic anchor** — a TF limit, a sum rule, or a closed form that IS the limit.
- If nothing converges (an identity, a census, a re-extraction from cache), say
  `exact: <why>` rather than leaving the field blank.

If the canonical grid carries a resolution ladder, the promotion evidence is a
**by-product** rather than an extra run.

**Mechanism claims** — against *the story arriving before the discriminator* (Coriolis):

- **two discriminators of different kinds**, declared before the measurement: a
  **symmetry test** (parity, channel invariance) and an **ablation or substitution**
  (turn the term off; reproduce it with a static trap at ω_eff).
- **One is refused by the parser.** A single test that agrees with the story is what the
  story predicts.
- The rule generalises: *the test that killed the last mechanism becomes a required
  item for the next one*. The Ω-parity scan was not luck, it was the template.

**Phase and boundary claims** — against *branch confusion* (68.4 µG read as a spinodal;
the Saito-Li cigar branch):

- a single warm-started continuation is **not** sufficient. Use deflation or an
  independent-initial-condition ensemble, and establish existence **and** absence.
- **a boundary may only be registered as a band, never as a line.** The LHY scheme moves
  the FM/polar boundary by +0.40 against +9.9 µG; a line is a retraction candidate the
  moment it is drawn.

**Type-C claims** — blind analysis, §12.

### Designing claims that are hard to retract

Order the work by robustness, not by interest. This changes no issue's *order* — it adds
one line to each issue's exit criterion.

| wave | what | why it survives |
|---|---|---|
| **0** | sum rules, gated invariances, closed-form-is-the-limit | structurally protected |
| **1** | discrete observables — level counts, label transitions, signs, parities | "it was slightly off" cannot happen to an integer |
| **2** | continuous quantities **as bands**, with scheme / resolution / statistical width shown separately | an interval absorbs what a point cannot |
| **3** | mechanism | needs the discriminator pair, so it lands last by construction |

### The two numbers worth tracking

**Internal capture rate** (errors that died before `registered`, over all errors) and
**claim half-life** (candidate → retraction, as a distribution). Rising capture and
falling half-life mean the institution works.

**The retraction count is not a metric.** Minimising it selects for not making claims.
The target is zero *external* retractions and *earlier* internal ones.

### A third candidate — node hours per claim advanced. Defined here, not adopted

#478 asked for the definition to be written and left adoption to after its
decomposition. Written:

**Denominator — a claim advanced** is a `claims.toml` row *entering* an
evidence-bearing status (`live` / `scoped` / `refuted` / `superseded` / `closed`),
either as a new row or from `open` / `suggested`. A restatement inside the advanced
set does not count, and neither does a new `open` / `suggested` row — posing a
question is not advancing one.

**Compute it on `--first-parent`, or it is wrong by half.** `git log -- claims.toml`
walks both sides of every merge, so a row appears on a branch, vanishes at the next
mainline commit and returns: measured 2026-08-26 over 2026-08-20…26, the full walk
reports **113** advances with 33 removals and 3 regressions where the mainline has
**79, zero and zero**. The per-row `commit` field is not a substitute — it is
`"unknown"` on 28 of 85 rows.

**Numerator — node hours. The writer works; nothing aggregates it, and the store
predates it.** `run_pipeline` stamps `runtime_seconds` into `_exit_summary.json` on
both the success and the failure path, and where that writer existed it fired: **11
of the 11 such files on this host carry a numeric value**, all `completed = true`.
They sit in **four separate roots and not one of them is `runs/`** — 0 of its 240
directories has one, because every `runs/` directory that carried a live-status path
predates the writer (`0d640402`, 2026-05-28; the store's 194 `_live_status.json`
files are all 2026-05-13…27). Total wall time recorded anywhere on this host:
**1.20 h.** The autopilot's counter received none of it — `runs/budget.toml` still
reads `realized_total = 0.0`, `today = "2026-06-14"`, because the qacct poller behind
`refresh_budget!` was never written. Counts and roots: ledger row
`node-hours-per-claim-has-no-numerator`.

So the numerator is **absent retrospectively and available going forward**, and the
enabling condition is not a new stamp — the stamp exists. It is an aggregator across
roots, and `refresh_budget!` actually being fed.

**Not adopted, and the reason is the numerator, not the subject.** #478's answer —
no recoverable cache waste on disk — removes the *duplicate-submission* motive. It
does not remove what this ratio measures: the day §"Before computing" is about (24
× 45-point GPU scans, every premise published and wrong) is ~3 h of node time
against zero claims advanced, and that is the shape this number is for. There is
simply nothing to divide over the period the store covers. Adopt it forward, from
the first period in which both halves are recorded — not backwards, because a
reconstructed numerator is one that gets quoted off the wrong walk.

**A `runs/`-only scan cannot see this**, which is the sharper lesson: the first pass
here counted 0 exit summaries under `runs/` and was about to conclude that nothing
records wall time. The artifact existed the whole time, one root over. Say which
directory a count is a count of — and when the answer is "there is none anywhere",
check that "anywhere" was the search.

---

## 14. When we disagree with a paper — attribution, in a fixed order

**A published number is not an oracle.** `refs/` exists because the alternative — a
number typed out of a PDF — is one more place a value drifts from the paper it came
from, and `src/model/ref.jl` therefore re-measures a published target off a committed
fixture with the metric we apply to our own runs, and **derives** `arbitrates` rather
than letting anyone assert it. Only what is registered there can decide a comparison; a
`.bib` entry and a PDF in `docs/refs/` cannot.

And a registered paper can still be wrong. Saito-Li's cigar branch is not the minimum of
Saito-Li's own functional (#387). So the question "who is wrong" needs a procedure, not a
disposition.

### The four hypotheses, eliminated in this order

**1. The two numbers are not the same quantity.** Window, reduction, boundary — the
`quantity` fields from §13. This is the 10.4 nT shape: three readings of one cached scan
put the argmax in three places, and 16 of 20 arms were reading a pre-hold transient.
Before anything else, check that both sides reduce the same thing over the same interval.

**2. The conventions differ.** `c_dd` with or without 4π; `F` versus `S`; the rotating
frame's sign; ω̄ as geometric or arithmetic mean; per-atom versus norm-N couplings.
**Keep a conversion table per source**, in that source's `refs/` file — not in prose,
because the next reader will re-derive it and get a different answer half the time.

**3. We are wrong.** Walk the numeric ladder (§13): three points per cutoff axis with
monotonicity, plus an analytic anchor. Most of the time this is where it ends.

**4. They are wrong.**

**Claiming 4 requires 1–3 to have been eliminated in writing.** Not considered — written
down, in the row or the report. This is the one step whose cost is asymmetric: a wrong
claim of (3) costs a re-run, a wrong claim of (4) costs a correction to someone else's
published work.

### The weapon for step 4 is a one-sided test, not a better simulation

Two integrators disagreeing is not evidence about which is right. **A variational or
inequality argument is**, because it does not require trusting either one:

- put **their** solution into **our** functional — if it is above our minimum, their
  branch is not the minimum of the functional they claim to minimise;
- bound **our** answer from one side with a trial function — a *weaker* bound that still
  excludes their value is a *stronger* result, because it leans on less;
- the virial theorem and sum rules are the same shape: an identity the answer must satisfy
  regardless of how it was computed.

`SpinorBEC.variational_bound` is this instrument, and `testing_strategy.md` already names
`bound` as **the only grounding method that says which side of a disagreement is wrong**.
#387 reached for it by accident and it settled the question at every field (+1.07 to
+1.48); the point of this section is that it should be reached for on purpose, as step 4's
first move rather than its last.

### What this changes about choosing what to reproduce

Reproduction is **pulled by claims, not pushed by the literature.** A claim that wants
`registered` declares the external results it leans on (`anchors`); if one is not
registered, registering it is the gate. The weekly arXiv sweep becomes an act of filing,
not a queue of work.

Measured 2026-08-25, and it inverts the intuition about what to read next: the ledger's
**six type-C claims have zero anchors between them**. The two registered sources arbitrate
nothing in the ledger, and everything needing arbitration leans on a source that is not
registered — five evaporation rows on Miyazawa 2021, one on Saito-Li 2024. So the cheapest
next move is not the most interesting paper; it is **registering a source five live claims
already depend on**.
