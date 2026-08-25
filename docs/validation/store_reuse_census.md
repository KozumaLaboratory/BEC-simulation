# The run store, as a cache: what is recoverable and what is not

> **FROZEN 2026-08-26.** A measurement record with a date. The instruments it
> reports are maintained (`store_census`, `reanalyze` — their docstrings are the
> live description); the NUMBERS are as of this date and are re-derivable in
> seconds with `julia --project=. scripts/cli.jl catalog census <runs_root>`.
> Live sources: `docs/campaign/claims.toml` rows `store-*` and
> `stored-runs-corpus-is-attributable-not-admissible`.

Closes the measurement half of #478 and the mechanism half of #483.

## The question, and why it was mis-posed twice

#478 pre-registered three reasons a re-launch does not hit the cache — (a) the
values really differ, (b) same physics, different bytes, (c) same config,
different producing commit — and asked which dominates *before* anyone built a
canonical parameter grid to fix (a).

PR #482 measured it and got two things right and one wrong.

- **(c) dissolved.** The gate does not refuse on hash granularity; it refuses
  because all 224 stamped points record `git_dirty = true`, which no hashing
  scheme repairs. Relaxing the provenance gate would have bought nothing, so it
  was not relaxed. That is the rule working.
- **The corpus is attributable and re-analysable**, 224 of 230 points naming
  their producing commit over 23 commits — after a first pass had concluded the
  opposite from `summary.json` (0 of 219) and generalised a count about one
  artifact into a conclusion about another.
- **(b) was reported as 3.2 % with one on-disk example**, and the example is
  wrong. See below.

What #482 could not reach was **(a)**, and it said so: the store predates the
current 16-hex naming, so a run directory cannot be reverse-mapped to its source
YAML. It reported the ceiling — 34 basenames spread over 77 directories — and
estimated that most of it was (a).

The reverse map is not needed. **Every run directory carries its own
`config.yaml`**, so two directories sharing a basename can be diffed directly,
and the answer is not a count but the *set of dotted paths on which they
disagree*.

## The measurement

```
240 run dirs · 196 basenames · 34 basenames with >1 dir covering 77 dirs (32.1 %)
219 content-keyed dirs · 0 whose config.yaml no longer hashes to its own suffix

(b) canonically identical (bytes only)           0 basenames /  0 dirs
(b) annotation only — same physics, recomputed   0 basenames /  0 dirs
(e) execution knob only — parity / replicate    15 basenames / 32 dirs
(a) a physics or resolution knob differs        19 basenames / 45 dirs
```

**There is no recoverable cache waste in the store.** Not a small amount — none.

### (e) is a fourth cause, and it is 42 % of the tail

The pre-registration did not have it. Fifteen basenames — the ten `0X_*`
families, three `L4_eu_matsui_hamiltonian_only_*`, `L4dealiasv4_*`,
`barnett_eu_omm0p3_n64_DDIon` — differ on `defaults.backend` and nothing else.
They are the **Level-0 GPU=CPU parity arms**. They are supposed to exist.

This is the concrete cost of a duplicate count without a classifier: reading the
32 % as waste and deduplicating it would have deleted a validation-ladder gate.

### (a) is 19 basenames, and the differing paths name the physics

`store_census` prints them, so the classification is auditable rather than a
bucket total:

| group | differs on |
|---|---|
| `K{0,1}_gdr{0,1}_LHY{0,1}` (8 groups) | `ground_state.n_steps`, `potential.omega[3]`, `dynamics.dt` |
| `L3_cr_f3_edh_toy_ddi_{on,off}` | `defaults.interactions` present in one, absent in the other |
| `L4_eu_matsui_hamiltonian_only_{32,64}` | `defaults.interactions` (plus backend, plus metadata) |
| `L7_loss_only_uniform_K3` | `interactions.N_atoms`, `omega_ref`, `loss.K3_per_m_*` |
| `klaus_hybrid_{magnetostir,nostir}_*` | `B.B_mag`, `B.theta`, `initial_state`, … (11–12 paths) |
| `matsui_5ms_morphology_n{32,64}` | `B.Bz`, `dynamics.B.Bz.{from,to}` |
| `matsui_edh_baseline` | `ground_state.B.Bz` |

### Where (b) would have arrived, and why it did not

Canonical byte-equality finds nothing on disk because two runs of the same
physics essentially never differ by whitespace. They differ by a `metadata.suite`
label or a `metadata.noise_convention` note added between launches — annotation
that enters the byte key (`compute_run_dir` hashes the whole file) and reaches no
physics. That is the door (b) comes through, and it is the reason `store_census`
classifies paths into `annotation` / `execution` / `physics` rather than
`same` / `different`.

Measured, that door is also shut: **0 annotation-only groups.** Every group with
an annotation difference also has an execution or a physics one.

## The retraction

> **REFUTED.** `matsui_edh_baseline_9ca97308/` and `matsui_edh_baseline_529e3a77/`
> are **not** the same physics under two byte-different configs. Ledger row
> `store-byte-only-duplicate-pair-on-disk`.

Each directory's own `config.yaml` still hashes to its own name
(`9ca973088b1743d9`, `529e3a77181ea7ae`) and they carry `Bz: "-0.01 Gauss"` and
`Bz: "0.01 Gauss"` — a **sign flip on the field**, i.e. cause (a).

The *committed* copies agree, and that is the trap: `bce2068f` ("211 Eu configs
pinned m=-F under a field that prefers m=+F") edited one of them in place
afterwards. The edited copy now hashes to `89b5ed0b`, not `9ca97308`.

So the original measurement grouped **committed configs** and the conclusion was
stated about **run directories**. It is the same step #482's own lesson names —
*say which file a count is a count of* — one corpus over. The 3.2 % figure over
the 566 committed configs is a statement about that corpus and stands; the
inference to disk does not. And how much of the 3.2 % is manufactured the same
way cannot be answered from the tree, because only 2 of the store's 219 keyed
directories have a committed config at all.

## A check nobody had run: does the config still describe the run?

The directory name **is** `sha256(config bytes)`, so "is this the config that
ran?" is an equality, not a judgement — and the check carries a two-sided control
in a single pass. Reported as `store_census(...).stale_key`.

|  | result |
|---|---|
| store, keyed directories | **219 of 219 verify. 0 stale.** |
| committed run-dir configs in git | 2 exist; **1 is stale** (`matsui_edh_baseline_9ca97308` → `89b5ed0b`) |

For re-analysis this is the load-bearing property, and it is the opposite of the
intuition: **the store is trustworthy and the committed copy of it is not.** A
re-read takes its window, its component indices and its hold duration from the
config, so a config edited after the run would silently re-reduce the wrong
trajectory.

## What #483 adds, and what it refuses

`reanalyze` (`src/workflow/validation/reanalysis.jl`) is one entry point for
reading stored output a new way. Re-analysis was already *possible* by hand —
`97ec124e` corrected the EdH observable and re-extracted every affected number
from cache with zero recompute — and had already been done three times by
bespoke drivers, each re-implementing the window and the reduction and none
recording which vintage its numbers came off.

```julia
obs = ObservableDefinition("peak P_adj in hold";
    window = :last, window_frames = 11,     # 5.5292 / (0.005 * 100)
    reduction = :max, boundary = "reject")
ra = reanalyze(padj_series, arm_dirs;
    observable = obs, declare = REANALYSIS_DECLARATION)
ra.vintage.commits            # which code produced the arms
ra.admissible                 # false, with machine-readable reasons
reanalysis_record(ra)         # → JSON beside the output, or a [[claim]] row
```

Four refusals, each answering one line of #483:

1. **The observable must be defined before a number exists.** `window`,
   `reduction` and `boundary` are required, and they are *the ledger's own three
   fields* validated against `CLAIM_BOUNDARY_RULES` — so a result transcribes
   into `claims.toml` without anyone re-deciding what the window was. `boundary =
   "reject"` **withholds** a maximum that landed on a window edge, because a
   truncated maximum is not a peak.
2. **The vintage is aggregated over the points actually read** and carried in the
   result: producing commits with counts, `git_dirty`, unstamped. A point whose
   series is absent is recorded as missing, not skipped.
3. **`admissible` is `false`, as a field**, with reasons — `dirty_tree`,
   `mixed_vintage`, `not_ancestor_gated`. A clean single-vintage read still
   carries `not_ancestor_gated` on its own, so the field cannot decay into a
   proxy for tree hygiene. This is the `klaus_protocol_sheet.md` failure treated
   at the value rather than in prose: a correct retraction at the head of a
   document and the retracted number still prescribed 160 lines later.
4. **`SPINORBEC_ALLOW_STALE_POINTS` is never set implicitly.** It is the right
   switch here — no propagation is redone, so the code difference cannot reach
   the answer — and exactly for that reason it must not be set on the caller's
   behalf: a globally permissive process also reuses stale points on paths that
   *do* recompute. An ambient setting is *reported* (`stale_env`) rather than
   inherited silently, and the test asserts both the behaviour and the absence of
   any assignment in the source.

### The positive control

#483 asks for the `97ec124e` re-extraction reproduced through the new path with
the same numbers. `scripts/validation/klaus_weff_extract.jl::peak_padj` **is**
that re-extraction, so it is included and differenced against `reanalyze`
bit-identically (`==`, not `≈`) in
`test/workflow/test_reanalysis_entrypoint.jl`, on a fixture built to carry the
defect the correction was about — the whole-trajectory maximum sitting in the
pre-hold transient, argmax at frame 29, hold from frame 32.

The fixture's own control is asserted: `whole > peak` and `whole_frame == 29`. If
the two agreed, the differential would pass for a window that does nothing, which
is the bug `97ec124e` fixed.

That driver now routes its main path through `reanalyze` and keeps `peak_padj` as
the reference, differenced on every run — deliberate redundancy under
commitment 3, and the only thing that makes a routing change safe on arms nobody
can re-run. Two further defects fell out of the migration:

- its CSV was written with a bare `open`, i.e. with **no provenance header** —
  precisely what `measurement_provenance.jl` exists to prevent. Now `stamped_csv`.
- its two hold scales (`hold2p0x`) were **two window definitions in one column**.
  Now two `ObservableDefinition`s, declared separately.

### The other three drivers, and what migrating them found (2026-08-26)

All four stored-run readers now route through the entry point. The three that
were deferred are worth recording separately, because **two of them shared a
reason and the third contained a live defect**.

**The shared reason was a missing API, not a deferral.** `klaus2022_reanalyse.jl`
reduces seven quantities per window and `klaus_weff_cloud_size.jl` nine off two
series, both from one expensive read — FFT per frame in the first case, streamed
ψ snapshots in the second. One observable per call would have multiplied that
read by seven and by nine, which is exactly the pressure that keeps producing
bespoke drivers. `reanalyze(...; observables = [...])` reduces every declared
observable off ONE read and returns a `MultiReanalysis` with one shared vintage;
`test_reanalysis_entrypoint.jl` counts the reads and differences the grouped pass
against N separate single-observable calls.

**And that was MEASURED before the API was widened, because #495 pre-registered
the threshold** ("if re-reading costs less than 2× one pass, do not widen it —
use several calls"). On one real snapshot-bearing arm — `klaus_long_om0p0_holdonly_t350`,
613 MB, 89 streamed frames, the same `arm_series` path the ω_eff arms take:

| | |
|---|---|
| one extraction, cold | 1.94 s |
| one extraction, warm (page cache) | 0.49 s |
| one reduction over the extracted series | 1.6 ms |
| **one pass + 9 reductions** | **1.95 s** |
| **9 separate calls, warm** | **5.87 s → 3.01×** |
| 9 separate calls, cold | 17.5 s → 9.0× |

3.01× against a 2× threshold, and that is the *favourable* figure: the warm
number assumes every re-read hits the page cache, which a 94 GiB arm on a cluster
filesystem will not. The re-read is not I/O alone — `radial_rms` per frame is
recomputed every call and no cache helps it. The arm is a substitute (the ω_eff
arms are not in this tree) and is named rather than implied.

**`lt64_endpoint_verdict.jl` found a defect in `reanalyze` itself.** Its header
records that the suite's first run used `save_every = 100` where the config saves
every 1000, asked for a 200-frame hold window over a 20-frame array, and got the
whole trajectory: `max(1, n - w + 1)` clamps, silently, and every "hold peak" it
printed was the pre-hold transient. It was caught only because one of the three
arm groups had a stored number to disagree with. **`_window_range` reproduced
that clamp exactly**, while `:range` immediately below it refused to clip. Both
halves are now single statements:

- `hold_window_frames(hold; dt, save_every)` is the one definition of the frame
  count — `dt` and `save_every` are required keywords, because a default is how a
  caller inherits another suite's cadence without writing it down;
- an over-long `:last` / `:first` window is **refused per arm and named**, not
  clamped. Per arm rather than per call, so one short arm cannot silence nineteen
  good ones — the too-strict version of this rule is the version that gets
  switched off — and a read where *nothing* reduced throws rather than returning
  a table of blanks.

The pre-registered criterion in that driver (`K_SIGMA`, `N_MIN`, the pooled-sd
sizing) **did not move**: the migration stops at the extraction, and `arm_values`
is kept as the reference, differenced per arm, with its historical clamp left in
place so a short arm makes the two definitions disagree loudly.

**A third disagreement surfaced on the way.** `klaus_weff_cloud_size.jl` used a
fixed 11-frame window for every arm including `hold2p0x`, whose hold is twice as
long — the same "two hold scales in one column" defect that had already been
corrected in `klaus_weff_extract.jl`, in a section whose purpose is comparing 1×
against 2×. Two drivers read the same arms and disagreed about it. Both windows
are now reported for the doubled arms (per-arm hold, and the fixed base window
the earlier reading was taken off); neither replaces the other.

None of the three can be executed in CI, so
`test/workflow/test_reanalysis_driver_migration.jl` gates them on synthetic
fixtures, and every fixture carries the control that **the window matters on it** —
a differential over data where the whole trajectory and the hold agree is
satisfied by a window that does nothing.

## What this does NOT settle

- **Whether a canonical parameter grid is worth having.** It is a policy for
  future runs; the measurement says only that there is nothing on disk for it to
  recover. Make that case about future runs, as one.
- **Whether the annotation door will stay shut.** 0 today. `metadata.*` still
  enters the byte key, so it can open at any time; `store_census` is the
  instrument that would see it.
- **The 3.2 % over committed configs**, whose exposure to the same post-hoc-edit
  confound is unmeasurable from the tree.
- **Coverage of re-analysis drivers — now gated, and the list is a known cost.**
  Four `.jl` drivers under `scripts/` read a stored run artifact; one is
  migrated, and `test/test_reanalysis_driver_coverage.jl` requires each of the
  others to be **named with a reason**, so a fifth cannot appear unclassified.
  What is deferred, and the shape of it is itself a finding: **two of the three
  need a multi-observable pass, not a second driver rewrite.**
  `klaus2022_reanalyse.jl` reduces seven quantities per pass;
  `klaus_weff_cloud_size.jl` reduces nine off two series read from one file — its
  `radial_rms` per frame IS a clean `series`, which is the half of the first
  reading that held, but the reduction is not one observable. Re-reading streamed
  ψ snapshots once per observable is not a cheap alternative there, so
  "one `reanalyze` call per quantity" is not the answer either. A
  multi-observable pass therefore has **two callers rather than one**, which is
  what would justify extending an API two commits old — recorded rather than
  built here. **`lt64_endpoint_verdict.jl` is the one that matters** — it
  re-derives the in-hold window from its suite's own `dt`/`save_every` constants,
  its own header says getting them wrong is SILENT, and that is a second live
  statement of the observable `97ec124e` fixed. Migrating it moves a
  pre-registered rejection criterion, which must not ride along in a refactor.
