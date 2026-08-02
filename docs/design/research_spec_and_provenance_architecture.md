# Research spec and provenance architecture

**Status:** design, revision 3 (2026-07-31). Supersedes revisions 1 and 2 entirely.

**Audit trail.** Revision 1 was red-teamed across seven attack surfaces: 47
candidate findings, 15 survivors, recorded with file:line evidence as issue
**#250**. Revision 2 answered every survivor by adding a mechanism, reached 3,400
lines, and was then reconciled against its own 13 numbered invariants: **64
findings, zero invariants clean, 15 still open at the end**. Two of its
invariants were false about this codebase on the day they were written, and one
fix was written as dead code (`plan.backend_kind === :cuda`, when `_resolve_backend`
at `src/foundation/backend.jl:99-105` accepts `:cpu`/`:gpu` and *throws* on
`:cuda`) because it had no positive control. Revision 3 is a **deletion pass**:
no new mechanism, scope cut where a capability cost more concepts than it was
worth. Everything cut is named in §4.

---

## 1. The problem, in measurements

Measured at `bc23d150` on this worktree. Payload counts (run directories, jld2)
are from the main checkout, which is where run outputs live.

**Identity does not exist.** Two schemes are both called content-addressed and
neither contains any code identity:

- `content_id(spec)` (`src/workflow/experiment.jl:120`) — SHA-256 over canonical
  spec bytes. It is correct and it has addressed **zero** stored results.
- `compute_run_dir` (`src/workflow/experiments/pipeline/run_registry.jl:31-37`) —
  an 8-hex hash of raw YAML *file bytes*. Every stored payload came from this.

Neither hashes `src/`. A cache admission is `isfile(result.jld2)`
(`src/workflow/experiment.jl:190`) — file presence, nothing else.

**The one stage cache is a hand-written allowlist.** `_gs_cache_key` was 19
entries, and its own docstring enumerated what it drops. Two of the omissions are
HamTerms that the *same function* passes to `make_workspace` twenty lines later:
`light_shift` and `rotating_frame_omega`. Changing either serves a stale ground
state at full confidence. (*Deleted by step 3, together with nine more omissions
this paragraph did not know about — see §6.*)

**Ambient numeric state is invisible to any spec.** 20 module-level `const … =
Ref(…)` bindings exist under `src/`+`ext/`. **11 of them select a numeric path**:
`SPIN_TAYLOR_{ENABLED,TOL,RSAFE,DEGREE_CAP}`
(`src/foundation/spinor_utils/spin_rotation_taylor.jl:31,64,70,89`),
`MEANFIELD_MIDPOINT_ENABLED` (`src/hamiltonian/integrator/split_step.jl:27`),
`SPIN_CHAIN_FUSION_ENABLED` (`spin_chain.jl:43`),
`COMBINED_SPIN_STEP_ENABLED` (`combined_spin_step.jl:51`),
`DEALIAS_2_3_ENABLED` and `DEALIAS_K_CUTOFF` (`dealias.jl:95,120`),
`_SM_EULER_WARP` and `_DDI_EULER_WARP`
(`ext/SpinorBECCUDAExt/gpu_euler_kernel.jl:190,232`). The other 9 are queue,
breaker, registry and logging infrastructure. `dealias` is a top-level block in
**75 of the 429 committed configs** and no spec-derived key can see it.

**A killed run is indistinguishable from a converged one.** The ITP loop catches
`InterruptException`, sets `interrupted = true` and returns a normal-looking
NamedTuple (`src/solvers/ground_state/itp_loop.jl:223-233`, returned at `:293`).
Its only consumers are that file's own checkpoint branch and a `println`. A
partial result on disk is admitted by `isfile`.

**Provenance is prose.** 429 YAML files. The machine-readable slot is
`metadata:`, which `src/workflow/experiments/schema/schema.jl:402` declares
*"free-form provenance, ignored at runtime"* — 45 keys, zero readers. Per the
inventory in #220: 481 stored summaries, 0 reproducible; 43 of 70 `runs/`
directories cited by `docs/` do not exist and 27 were never committed.

**The spec layer that produced this** is 13,995 LOC across 68 files in
`src/workflow/experiments/`, compiling a raw `Dict` into `make_workspace` kwargs
through 15 in-place passes with no typed value anywhere in between.
`runfactory.jl` — the DSL CLAUDE.md says sweeps and tests use — has 3 call sites.

### Root cause

The unit of identity is a *text*, and the physics is a side effect of parsing it.
Nothing downstream is the same kind of thing as the key, so a key must be
hand-listed, and a hand list has an omission. Every defect above is that one
sentence.

---

## 2. The design

Six names the researcher types: `model`, `stage`, `sweep`, `claim`, `ref`,
`run!`. Everything else is a maintainer file or a row in a TOML.

### 2.1 `Model` — resolved physics as a value

**Written but not yet committed** — `src/model/`, 8 files, 1,734 LOC, currently
untracked on branch `feat/model-resolved-physics` (`git ls-files src/model/` is
empty). It loads (`using SpinorBEC` succeeds) but carries no tests, because the
pass that wrote it was stopped before its gates were. Cutover step 1 is to land
it *with* those gates, which is why that step is cheap rather than free. Every
`src/model/` line number below refers to that uncommitted prototype, not to
shipped code. 14 concrete fields (`src/model/model.jl:83-97`).

```julia
struct Model <: ModelValue
    grid::GridSpec;          atom::AtomSpecies;      interactions::InteractionSpec
    potential::PotentialSpec; zeeman::ZeemanSpec;    ddi::DDISpec
    lhy::LHYSpec;            raman::RamanSpec;       light_shift::LightShiftSpec
    magnetic_gradient::GradientSpec; frame::FrameSpec; geometry::GeometrySpec
    reservoir::ReservoirSpec; loss::LossParams
end
```

Two properties matter and both already hold:

- Time dependence is `ModelWaveform = Union{Float64, PiecewiseLinearWaveform}`
  (`src/model/model_waveform.jl:50`). A `Function` field cannot enter a `Model`,
  which is the closure-escape class CLAUDE.md commitment 8 names.
- The shape gate enumerates `subtypes(ModelValue)` rather than a hand list
  (`model_waveform.jl:13`), so a new spec type is covered by construction.

The ~21 `*Spec` types are **maintainer-facing**. A researcher writes

```julia
m = model(; grid=(n=(64,64,64), box=(12,12,12)), atom=:Eu151,
            interactions=(c0=..., c1=...), zeeman=(Bz=1.2e-7, theta=0.0),
            ddi=(c_dd=..., padded=true), lhy=:full_bdg)
```

and never types `GridSpec`.

### 2.2 `stage` — one struct, three kinds

```julia
struct Stage
    kind::Symbol                     # :relax | :evolve | :measure
    model::Model
    method::Symbol                   # :itp | :lbfgs | :strang | :bdg | ...
    from::Union{Nothing, Stage}      # dependency edge; nothing = from scratch
    params::NamedTuple               # dt, steps, tol, save_every, dealias, seed, ...
    backend::Symbol                  # :cpu | :gpu  (the values _resolve_backend accepts)
end

stage(kind; model, method, from=nothing, backend=:cpu, params...) = ...
```

`params` holds the numerics as ordinary typed fields, so they are hashed **by
construction**. That is what closes the save-cadence-in-no-digest hole without a
rule, and it is where the 11 ambient `Ref`s move to.

`from=` is the whole of what revision 2 called `Initial` / `FromScratch` /
`FromAnsatz` / `FromArtifact` / `ArtifactRef`. Omitted means from scratch.

### 2.3 Identity — one function, over the whole declaration

```julia
artifact_id(s::Stage) = content_id(Dict(
    "model"     => model_toml_dict(s.model),      # src/model/io.jl:89
    "kind"      => String(s.kind),
    "method"    => String(s.method),
    "backend"   => String(s.backend),
    "params"    => _enc(s.params),                # src/model/io.jl:58
    "from"      => s.from === nothing ? nothing : artifact_id(s.from),
    "code_rev"  => code_tree_hash(),              # `git rev-parse HEAD:src` + `:ext`
))
```

`content_id` is unchanged and already shipping (`src/workflow/experiment.jl:120`).
Nothing is *selected*, so nothing can be omitted. The enforcement is
`_canonical_bytes!`: it **errors** on any type it cannot canonicalise
(`experiment.jl:103`) and on non-finite floats (`:86`). The two encoders are
already written — `model_toml_dict` sorts `AtomSpecies.scattering_lengths` into
parallel channel arrays so the bytes do not depend on hash insertion order
(`src/model/io.jl:70-78`), and `_enc` reflects any struct into a `Dict`
(`io.jl:58`).

`code_rev` is **one tree hash of `src/` and `ext/`**. No file list, no ownership
map, no per-term digest. Total by construction — there is nothing to be
incomplete about, and no way to misfile a shared file. Priced, not assumed:
`git rev-list HEAD -n 1931 -- src ext | wc -l` = **1018 of 1931 commits (52.7%)**
move it. `docs/`, `test/`, `runs/`, `scripts/` and `dashboard/` do not.

This deletes `physics_id`, `method_id`, `input_digest`, `toolchain_id`,
`probe_id`, `StageId`, `JobEnv`, `scope_digest` and its five hand-maintained
lists, and the fifth `HamTerm` face — see §4.

### 2.4 `sweep` — Cartesian, and only Cartesian

The name already exists (`src/workflow/experiment_collections.jl:80`). Extended
to `Stage`, one axis or several, multiplied:

```julia
cells = sweep(base_stage; over = :Bz => Bz_values)
```

The axis is a *declaration*, so `differs_only_in` reads it directly. A serial
continuation is a `for` loop emitting N stages linked by `from=` — see §4.

### 2.5 `claim` and `ref` — the quote boundary

```julia
struct Claim
    statement::String
    kind::Symbol                    # :A code correctness | :B physics | :C model fidelity
    evidence::Vector{Stage}
    control::Union{Nothing, Stage}  # the arm that must FAIL
    target::Union{Nothing, NamedTuple}   # a row from refs/<paper>.toml
    function Claim(statement, kind, evidence, control, target)
        kind in (:A, :B, :C) || throw(ArgumentError("kind must be :A/:B/:C"))
        kind in (:B, :C) && control === nothing &&
            throw(ArgumentError("a :$kind claim needs a control that trips it"))
        kind === :C && target === nothing &&
            throw(ArgumentError("a :C claim needs a registered literature target"))
        new(statement, kind, evidence, control, target)
    end
end
```

That constructor is the entire enforceable content of the A/B/C taxonomy. It is
not a type hierarchy.

`ref(:matsui2025, :dip_width_nT)` reads a row from `refs/matsui2025.toml`:

```toml
[dip_width_nT]
value = 12.84
kind  = "read_off"        # read_off | inferred
note  = "Fig. 4B experimental trace, FWHM of the m=6 depletion"
doi   = "10.1103/..."
disqualified_by = []       # nothing stops this number deciding the comparison
```

Provenance becomes data. Whether a number DECIDES is the column that matters and
the pattern already ships: `test/validation/test_matsui_fig4_dip.jl` pins width
and centre and carries a canary at `:122` — shift the curve and the centre moves
by exactly the shift while the width does not; stretch it and the width doubles.

**As shipped, that column is `disqualified_by` and `arbitrates` is derived from
it** (`arbitrates == isempty(disqualified_by)`). A free `arbitrates` Bool is set
by whoever can also see how our number compares, which is the approval-testing
failure mode — golden tests fail by BLESSING a wrong value. `REF_DISQUALIFIERS`
is a closed vocabulary (`:axis_offset`, `:window_not_covered`,
`:absolute_population`) in which every entry is a property of the REFERENCE, so
there is no field to set while looking at our result. `Claim` refuses a `:C`
claim whose target does not arbitrate, which is what makes the flag load-bearing
rather than documentation with a Bool type.

### 2.6 `run!` — idempotent, returns records

```julia
run!(s::Stage)              -> Record
run!(cells::Vector{Stage})  -> Vector{Record}
```

A cache hit is a `Record` too, flagged as one. Admission requires the completion
marker of invariant 4, not `isfile`.

### 2.7 Guards reuse `CheckResult`

No `Guard` type. The three-valued `CheckResult`
(`src/workflow/validation/specs.jl:33-48`) and the control rule in
`src/workflow/validation/error_budget.jl:131-148` are the mechanism, unchanged.

### 2.8 `Record` — maintainer-facing, one flat TOML

The researcher indexes what `run!` returns and never opens this file.

```toml
id = "9f3c1a20be4d7712"
code_rev = "a91e...";  status = "complete"   # complete | cached | failed
[model]   # model_toml_dict output, verbatim
[stage]   # kind, method, backend, params
inputs = ["4b21..."]                          # from= chain, resolved
[timings] wall_s = 812.3
[env]     host = "...", julia = "1.12.6", manifest_sha = "...", backend_loaded = "gpu"
```

`[env]` is read by a human when two artifacts at one id disagree. It gates
nothing, and saying so is the point — revision 2's 20-field `ExecutionSeal` had
15 fields its own text admitted gate nothing.

---

## 3. Worked example — Matsui Fig. 4B

Six named concepts: `model`, `stage`, `sweep`, `claim`, `ref`, `run!`.

```julia
using SpinorBEC

# 1. the physics, as a value
eu = model(;
    grid         = (n=(64,64,64), box=(10.0,10.0,10.0)),
    atom         = :Eu151,
    interactions = (c0=1.34e3, c1=-2.1),
    potential    = (kind=:harmonic, omega=(1.0, 1.0, 1.4)),
    ddi          = (c_dd=8.9, padded=true, secular=true),
    lhy          = :full_bdg,
    zeeman       = (Bz=0.0, theta=0.0))

# 2. the two stages
gs = stage(:relax; model=eu, method=:lbfgs, tol=1e-8, dealias=:orszag)

ev = stage(:evolve; model=eu, method=:strang, from=gs,
           dt=2.0e-4, steps=150_000, save_every=500, backend=:gpu)

# 3. the field scan — one declared axis, 45 cells
cells = sweep(ev; over = :Bz => range(-40e-9, 40e-9; length=45))

recs = run!(cells)                       # idempotent; cache hits come back as Records

# 4. the claim, at the quote boundary
dip = resonance_dip(recs)                # existing analyzer

fig4b = claim("The m=6 depletion resonance reproduces Matsui Fig. 4B in WIDTH.",
    kind     = :C,
    evidence = cells,
    control  = stage(:evolve; model=with(eu, ddi=(c_dd=0.0,)), method=:strang,
                     from=gs, dt=2.0e-4, steps=150_000, backend=:gpu),
    target   = ref(:matsui2025, :dip_width_nT))
```

Reading it back:

```julia
artifact_id(cells[23])           # "9f3c1a20be4d7712"
record(cells[23]).model          # the resolved physics, losslessly
differs_only_in(cells)           # (:Bz,) — from the declared axis, not from a hash
```

**Why the control is the dipolar switch-off, not a tolerance.** The exercise is a
:C claim, so it needs an arm that fails. `c_dd = 0` is the arm that must NOT
reproduce the dip; if it does, the comparison was never measuring the dipolar
resonance and `error_budget.jl:131-148` returns `:indeterminate`, not `:pass`.

**Why `ref(:matsui2025, :dip_width_nT)` and not the centre.** Their published
experimental axis carries a ±10 nT offset — three times the centre value — so
only the width arbitrates (project note, 2026-07-30). That fact is now a TOML
column instead of a paragraph in a YAML comment.

---

## 4. What this design does NOT solve

Mandatory section. Each item is a capability revision 2 claimed and this one
drops on purpose.

1. **Partial cache invalidation.** Any commit under `src/` or `ext/` moves
   `code_rev` and the whole store stops hitting. Measured: 1018 of the last 1931
   commits (52.7%). The finest defensible partition would have been ~33% full
   invalidation. So this costs roughly 5x more full re-solves. Bought: five
   hand-maintained ownership lists deleted, and with them the only failure in that
   family that serves a **wrong** number rather than losing a hit — misfiling a
   shared file, which revision 2 had already done once with
   `ext/SpinorBECCUDAExt/gpu_euler_kernel.jl`.
2. **Adding HamTerm #15 in 2029 invalidates everything.** The alternative was a
   fifth `HamTerm` face on all 14 terms, requiring surgery on
   `build_h_terms_registry` (`src/hamiltonian/terms/registry.jl:77-112`, which
   computes `p_eff = z.p - ω_R` and the rotating-frame `(bx, by)` inline). That
   `NTuple{14,HamTerm}` is named load-bearing by CLAUDE.md commitment 8. We do not
   dismantle it for cache economics.
3. **Dependency versions are not in the key.** A `Pkg.up` of CUDA or FFTW moves no
   id. The resolved manifest hash is recorded in `[env]`. A dependency-caused
   divergence is found by re-running or by the nightly sampler, not by a miss.
   The event has happened once in repo history.
4. **Execution is witnessed by two assertions, not a seal.** The runner asserts
   loaded code revision == declared, and backend actually loaded == declared.
   Everything else — sysimage, BLAS, FFTW plan, CPU target, module build id — is a
   recorded string. In exchange, `-J` sysimage runs are not refused, which matters
   because that is how `src/workflow/autopilot/backends_uge.jl:184` launches
   TSUBAME. **A lying host is not detected.**
5. **Serial and seeded axes.** `sweep` is Cartesian and its cells are
   independent. A pinned B-continuation is a `for` loop emitting N stages linked
   by `from=`; there is no `Chain`, no `because`, no must-be-last rule. Resume
   granularity is per stage, not per link. Nothing structurally stops someone
   writing a `sweep` where a continuation was meant.
6. **Campaigns, lanes, GPU budgets, gate-nodes, recipe lineage.** Not addressed.
   Autopilot already owns budget caps, circuit breakers and `on_complete` lineage.
   A claim-gated *release* — "lane B does not start until claim G1 is green" — is
   the one thing autopilot does not have, and it is dropped rather than built.
7. **Taint does not travel the dependency edges.** A retracted artifact is marked
   in its own record; artifacts downstream are not invalidated. Finding them is a
   query a human runs. `RETRACTED.md` prose remains the mechanism.
8. **Read-off vs inferred is a TOML column, not a type.** Nothing mechanically
   stops someone typing a literal instead of `ref(...)`. That distinction is not
   machine-checkable and pretending otherwise is what made revision 2's invariant
   8 self-refuting inside its own worked example.
9. **Static shape-gating stops at `Model`.** A `:measure` stage's analyzer options
   are a per-instance `NamedTuple`: hashed and canonicalised, but not
   shape-checkable, because a `NamedTuple`'s field types are per-instance.
10. **Concurrency.** Two processes computing one id race. The loser's compute is
    wasted. No locking protocol is defined. `run_yaml` has this property today.
11. **TDHFB, Yoshida and Multistart are not day-1 methods.** `:itp`, `:lbfgs` and
    `:strang` are. CLAUDE.md forbids wiring TDHFB into the pipeline at all.

---

## 5. Invariants

Five. Every one checkable against the tree today.

**1. Identity is the whole declaration, never a selection from it.**
`artifact_id` is `content_id` over `(model, kind, method, backend, params, from,
code_rev)`.
*Verified:* `_canonical_bytes!` errors on any unsupported type
(`src/workflow/experiment.jl:103`) and on non-finite floats (`:86`) — an omitted
field is a hard error, not a silent skip. Both encoders exist:
`model_toml_dict` (`src/model/io.jl:89`) and `_enc` (`src/model/io.jl:58`).
*Gate:* grep — exactly one call site constructs an id. This deleted
`_gs_cache_key`, 19 hand-listed entries whose own docstring enumerated its
exclusions and which omitted `light_shift` and `rotating_frame_omega` (step 3;
`test/model/test_gs_admission_axes.jl` is the per-axis gate).

**2. The declaration is closed.** No field reachable from `Model` is typed `Any`,
`Function`, or an abstract non-union type; and no mutable module-level binding
selects a numeric path.
*Verified, first half:* `src/model/` declares none of the three today. Time
dependence is `ModelWaveform = Union{Float64, PiecewiseLinearWaveform}`
(`src/model/model_waveform.jl:50`); the shape gate enumerates
`subtypes(ModelValue)` (`:13`); the only container reached is
`AtomSpecies.scattering_lengths::Dict{Int,Float64}`
(`src/foundation/types/spin_atom.jl:134`), which is concrete and already
deterministically encoded by `_enc_atom` (`src/model/io.jl:70-78`). **Zero
exemptions needed** — revision 2's recursive-Dict ban needed one on day zero.
*Second half is the work item, and the set is enumerated and closed:* 20
`const … = Ref(…)` bindings exist under `src/`+`ext/`, of which the 11 numeric
ones are listed in §1. They move to `stage.params`; the grep gate keeps the set
empty. Also deleted: `schema.jl:402`'s `"metadata"  # free-form provenance,
ignored at runtime`.

**3. Code identity is one tree hash of `src/` and `ext/`.** No file list, no
ownership map, no per-term or per-scope digest.
*Verified:* total by construction — there is nothing to be incomplete about.
Priced: `git rev-list HEAD -n 1931 -- src ext | wc -l` = 1018 (52.7%).

**4. A cache hit requires a completion marker written last, naming the bytes it
certifies.** An id alone never serves.
*Verified need:* `src/solvers/ground_state/itp_loop.jl:223-233` catches
`InterruptException`, sets `interrupted = true`, and `:293` returns it inside an
otherwise normal NamedTuple whose only consumers are that file's checkpoint
branch and a `println`. Today's admission is `isfile`
(`src/workflow/experiment.jl:190`), so a killed run's output is served as
converged. This is the one invariant whose *implementation* does not exist yet;
its *need* is verified, which is why it is here and not in §4.

**5. A check with no control that trips it returns `:indeterminate`, never
`:pass`.**
*Verified in-tree:* implemented at
`src/workflow/validation/error_budget.jl:131-148`; `CheckResult` admits exactly
`:pass`/`:fail`/`:indeterminate` (`src/workflow/validation/specs.jl:33-48`); the
same shape ships as a canary in `test/validation/test_matsui_fig4_dip.jl:122`.
This is the one discipline that would have caught
`engaged(::Val{:gpu}, p) = p.backend_kind === :cuda`. It was caught in review
before it was committed, by reading `backend.jl` rather than by a test — which is
luck, not process, and is why the control is required rather than encouraged.

---

## 6. Cutover

Shortest path that ships value. Each step is independently useful and
independently revertable.

**Step 1 — `artifact_id` beside the existing key (no deletion).** Add
`code_tree_hash()` and `artifact_id(::Stage)`. Write both the new id and the old
`_gs_cache_key` into the record; admit on the old one. Value: every new run
records a complete id. Reversible by deleting one file.

**Step 2 — the completion marker (invariant 4).** `run!` writes
`complete.toml` last, naming the payload files and their sizes. Admission
becomes marker-present, not `isfile`. Positive control required and it is cheap:
a test that `kill -INT`s an ITP mid-run and asserts the next `run!` recomputes.
**Do not merge this step without that test** — that is the failure mode this
whole pass exists to stop.

*As landed* (`src/model/complete.jl`, four deviations a future reader should not
undo):

1. **Sidecar, not one file per directory.** `<payload>.complete.toml`. Every
   admission site in the tree tests ONE file, a scan directory is written by N
   independent processes under `SPINORBEC_SCAN_ONLY_INDEX`, and the sidecar sorts
   *after* its payload under `rsync`, so a collect cannot expose a marker whose
   bytes have not landed.
2. **Arm (b): a payload with NO marker is still admitted**, as `:unmarked`, warned
   once per store. Measured at cutover: 671 `.jld2` under `runs/`, zero markers.
   A cold flip meant recomputing the tree. Deleting arm (b) is step 3's business
   and it needs a dated cutoff.
3. **A tombstone, `<payload>.incomplete.toml`, written by a run that knows it did
   not finish.** Without it the mandatory control *cannot pass*: a run killed
   after its payload lands and before its marker is written is byte-identical to
   a pre-cutover artifact, so arm (b) would serve it and nothing would recompute.
   The tombstone is the discriminator; `write_complete_marker` clears it.
4. **The control does not use `kill -INT`, and the design's suggestion to is
   wrong.** Julia 1.12 script mode has `exit_on_sigint == true`, so a real SIGINT
   aborts the process before `itp_loop.jl:223` runs — nothing is written, the next
   run recomputes because there is nothing to serve, and the test is green before
   *and* after this step. `schedule(task, InterruptException(); error=true)` on an
   `@async` task reaches the swallow path, which is where the payload gets
   written. `Base.throwto` deadlocks; `Threads.@spawn` aborts the process.

The defect measured before the fix: a 64-point ITP killed at step 20 000 of
2 000 000 wrote a full `point_001.jld2` at E = 0.96272 against a converged
0.94108, `_exit_summary.json` said `completed: true`, the interrupt checkpoint
was deleted as "point completed successfully", and the next run served it in
0.008 s.

Two more things the same step had to close, found by corrupting the fix and
watching the suite stay green (canary pass, 2026-08-01):

5. **There are THREE swallowing loops, not one.** `itp_loop.jl:223` and both RTP
   loops (`simulation/run_loops.jl`). Forcing `interrupted[] = false` in the two
   RTP loops left every suite green, because the only interrupt test's kill
   landed in the GS and rode the `|` accumulation in `_step_dispatch!` — so a
   dynamics-only run killed mid-evolution was still certified and served.
   `test_interrupted_dynamics_recomputes.jl` drives both loops directly and then
   kills a `run_yaml` mid-dynamics, waiting on `_live_status.json` (written by
   the dynamics step and by nothing else) as the "the GS is done and the RTP is
   running" signal.
   A scheduler-delivered `InterruptException` can also land BETWEEN the pushes
   inside `_record_snapshot!` (measured: `times = 6`, everything else 5), and the
   ragged tail made the pipeline's dynamics auto-save raise — so the interrupted
   run wrote no `result.jld2` at all, losing both the forensic record and the
   tombstone. `_trim_interrupted_traces!` drops the partial row.

6. **`point_001.jld2` was not always a payload.** `save_rotating_basis_result!`
   published it as a symlink to `result.jld2` and `rm`'d whatever was there
   first; `run_pipeline` calls that once per scan point, so in a multi-point scan
   the name ended up on the LAST point's data (3 such symlinks under `runs/`,
   one in a 3-point scan). Pre-existing, surfaced by this step because the marker
   written for the real point 1 then disagreed with the link's target size. The
   alias is now published only into a name no point writer has claimed, and a
   rejection on a symlink says so instead of reporting truncation.

**Step 1b — `yaml_to_model` (ADDED 2026-08-01, after step 3 was attempted and
refused).** The plan as first written went from step 1 to step 3 assuming a
resolver from raw YAML to a `Model`, and there is none: `src/model.jl:8` itself
says the rewiring "is Step 1b" while section 6 listed no such step. That is a
hole in this plan, not in the code. Step 3 cannot flip admission to
`artifact_id` because nothing at the flip site can build the `Model` the id is
derived from.

Measured before writing this, on the 407 committed configs that carry a
`ground_state` step, attempting only 4 of the 14 slots (grid, atom,
interactions, ddi) with the same preprocessing `run_yaml` applies:

```
Model built:  42 / 407
        364   ArgumentError: trunc_radius must be >= 0 (0 = untruncated); got -1.0
          1   KeyError: "omega"   (one lab-calibration config)
```

**89.4 % fail on a single defect, and it is a representation defect rather than
a parsing one.** `_parse_ddi_trunc_radius`
(`src/workflow/experiments/schema/parsing_blocks.jl:468-482`) is THREE-valued:

```
absent / "auto" / "box_half"  ->  -1.0    auto — derive from the box (283 configs)
"none" / "off"                ->   NaN    no truncation, bare periodic kernel
a number                      ->  itself  explicit radius
```

`DDISpec.trunc_radius::Float64` accepts only `>= 0` with `0.0` meaning
untruncated, so it **has no representation for auto at all**, and the obvious
`NaN -> 0.0` mapping would collide *auto* with *none*. Those are different
physics: the bare kernel carries a 2-5 % dipolar field error that is flat in
resolution and does not go away by refining. A wrong translation here is a
physics collision, not a hashing detail.

**Decision: `trunc_radius::Union{Nothing, Float64}`**, `nothing` meaning auto.
A small closed union is the same shape the design already accepts for
`ModelWaveform`, it makes the third state unrepresentable-as-a-number rather
than encoded in a sentinel, and sentinels are precisely what this design exists
to delete. Rejected: keeping `-1.0` (a sentinel by another name), and a
mode-enum plus value (two fields that can disagree).

Scope: resolve `ground_state` blocks only — that is what admission keys on.
`Initial`, `InitialSpec` and the dynamics half stay out. The gate is that
`yaml_to_model` round-trips all committed `ground_state` steps, with any config
it cannot resolve listed by name and reason rather than skipped.

**The architectural requirement, and the shape it forces.** Re-interpreting
`potential:` / `B:` / `lhy:` / `ddi:` from raw YAML would be a second
declaration of the same physics — two readers, each self-consistent, drifting
silently. So the resolution was EXTRACTED rather than duplicated:
`resolve_gs(p, grid_prev, atom_prev, ws_prev) -> GSResolved`
(`src/workflow/experiments/pipeline/resolve_gs.jl`) is the one resolver, and it
has two consumers — `_run_step(::GroundStateStep, …)`, which reads the solver
faces off it, and `gs_model(r) -> Model`, which is a pure function of the same
struct and touches no dict. Everything `gs_model` needs that the solver does not
(`N_atoms`, `omega_ref`, the light-shift coupling triple, the dealias globals)
is read in the resolver and carried. `test/model/test_resolve_gs_is_shared.jl`
gates the property with three independent arms — the runner's lowered code names
`resolve_gs`; the runner's source calls no physics parser; and both consumers
reproduce the same LITERAL pinned numbers — because a second parser reappearing
is the failure this step exists to prevent.

Model-construction failures live in `gs_model`, not `resolve_gs`, so
`_run_step`'s behaviour does not change: a config with no `N_atoms` still
*solves*, it just has no model. Verified by a 10-scenario before/after probe
(itp, lbfgs, no ddi, scalar LHY, no potential, `trunc_radius: none`, explicit
radius, no `B`, chained inheritance) diffing byte-identical on energies to 14
digits, ψ samples and workspace digests.

**`yaml_to_model` had to be made PURE in the dealias globals.** Found by the
corpus gate, not by reading: `_run_yaml_prepare` is only the prepare half of a
prepare/execute pair — it applies a top-level `dealias:` block to
`DEALIAS_2_3_ENABLED[]` / `DEALIAS_K_CUTOFF[]` and leaves them set, and it is
`run_yaml`'s execute half that restores them in a `finally`
(`run_registry.jl:421-445`). `yaml_to_model` runs prepare alone, so until it did
the same restore, resolving a config that carried the block **rewrote the
`GridSpec` of every config resolved after it in the same session**:
`runs/validation_level10/L10_F1_smoke.yaml` measured
`dealias_two_thirds=false, k_cut=0.0` alone and `true, 10.0` after
`runs/eu_gs_phase_c1_B_kappa/config_boundary_64.yaml`, and the two models
compared unequal. For a resolver whose output is a content id that is fatal, and
it is invisible to any single-config test. Both the Refs and the pending-snapshot
slot are now restored in a `finally`; the order-independence arm of
`test/model/test_corpus_resolves.jl` gates it, with the disagreeing pair asserted
so the equality cannot pass vacuously.

**Three corrections to what this section said before it was implemented.**

1. **The premise that `light_shift` / `lhy_kind` / `lhy_opts` /
   `rotating_frame_omega` had already been hoisted above the cache branch was
   FALSE.** They sat ~170 lines below the cache-hit `return`; `git log -S` finds
   no hoist commit on any branch. Step 1b does the hoist. That closes a live
   gap as a side effect — the cache-hit `make_workspace` could not have been
   given those four, because they were not resolved yet — but the call itself is
   left unchanged, since passing them would change what a cache hit computes.
   Marked `[KNOWN-GAP]` at the site for step 3.

2. **`nothing` means AUTO in `DDISpec` and OFF in `make_ddi_params`**
   (`_build_q_tensor!`'s `do_trunc = trunc_radius !== nothing`,
   `qtensor.jl:145`), and `make_workspace` reads `<= 0.0` as auto — so the
   identity map is wrong in *both* directions and a naive conversion silently
   turns every untruncated run into an auto-truncated one. The conversion is
   `ddi_trunc_radius_kwarg` / `ddi_trunc_radius_from_kwarg`, declared once in
   `specs.jl`, and it is non-identity on `0.0` by construction. Also corrected:
   `DDISpec`'s docstring claimed "a model carries the one radius its own `padded`
   setting selects", which is false — `make_workspace` derives TWO radii from the
   one input and builds both objects, which is *why* auto cannot be resolved to a
   number before the model exists.

3. **The "364 / 407" measurement used 4 of the 14 slots**, so it saw only the
   `trunc_radius` defect. Over all 14, on the 429 config files under `runs/`
   — of which **407 carry a spinor `ground_state:` step** in the YAML, six of
   those being refused by `_run_yaml_prepare` before any resolver runs, so 401
   reach one:

   ```
   351  resolve AND round-trip through TOML unchanged
    22  tabulated LHY with no resolved n_max (NaN = "3x max|psi_init|^2")
    16  no N_atoms anywhere (bare c0/c1 verification configs)
    15  no spinor ground_state step (rotating_basis path)
     9  strict-schema failures that predate this step (`omega_ref` at step level)
     5  two ground_state steps, index required rather than guessed
     5  87Rb + auto-derived q, which `_resolve_q_waveform` refuses
     2  a B tilt the spinor runner drops (`B_direction`; klaus_hybrid)
     4  not pipeline configs / not parseable YAML
   ```

   351 + 56 in scope + 22 out of scope = 429. The list is not a report: it is
   `CORPUS_UNRESOLVED` in `test/model/test_corpus_resolves.jl`, config by config
   with its reason, gated in both directions — a config that stops resolving is
   red until someone writes down why, and one that starts resolving is red until
   it leaves the list. That gate also re-reads all 351 resolved models against
   their own YAML (5 255 checks: atom, grid, N, ω_ref, the c₀/c₁ constraint,
   c_dd, secular, LHY kind, trap ω, p, q) so that "constructs" and "carries the
   physics" are separate claims.

   The nine `:schema_strict` refusals are `_run_yaml_prepare`'s, and that is the
   same function `run_yaml` calls (`run_registry.jl:205`), so **those nine are
   unrunnable today** — independently of anything in this layer.

   One pre-existing defect the sweep surfaced and this step does NOT fix:
   `_parse_gs_interactions` (`parsing_blocks.jl:363-391`) tries `c_total`, then
   `N_atoms + omega_ref`, then explicit `c0`/`c1`, with **no warning when a
   later-priority key is present**. Two configs —
   `runs/verification_suite/yamls/L7{,clean}_loss_only_uniform_K3.yaml`, whose
   header says "no trap, no DDI, no contact, no LHY" — declare
   `{N_atoms: 100000, omega_ref: 628.3, c0: 0.0, c1: 0.0}` and therefore run
   with `c0 = 5338.9`, not 0. The model is faithful (both consumers share the
   resolver, so the run uses the same number); it is the config that is not
   doing what it says. Fixing the precedence changes what those runs compute and
   needs its own gate plus a retraction of any L7 claim, so it is filed here
   rather than done inside a cutover step.

   Every one of the 22 + 16 + 5 + 2 is a REAL gap in the config, not in the
   resolver: `gs_model` refuses rather than substituting a default, because a
   model that guessed would be a wrong answer wearing a content id in a shared
   store. The 2 `B_direction` configs are the pair that silently run with **B
   along +z instead of −z** today.

**Step 3 — flip admission to `artifact_id`.** The GS stage cache is keyed on
`artifact_id(gs_stage(r, p))`. `_gs_cache_key` and `_hashable` are deleted in the
same commit, and nothing falls back to them.

*As landed*, with the six things the one-line framing above got wrong:

1. **It is not one line, because the id has to be BUILT.** `artifact_id` hashes
   the whole `Stage`, so nothing is selected out of it — but turning a step dict
   into a `Stage` is a mapping, and a mapping is where an omission hides. The
   physics half is not mapped at all (`gs_model(r)`, the pure function of the
   same `GSResolved` the solver reads); the numerics half is
   `_gs_stage_params(r, p)`, and `test/model/test_gs_admission_axes.jl`
   partitions every `GS_SCHEMA` key into {model, stage, refused,
   not-on-this-path, destination}, asserts the partition is TOTAL, then moves
   each axis one at a time and asserts the id moves with it.

2. **The old key was blind to eleven inputs, not two.** Measured one knob at a
   time through `_gs_cache_key`: `m_lbfgs`, `newton_polish`, `residual_polish`,
   `pin`, `tol_drho`, `seed_from`, `noise_seed`, `light_shift`,
   `rotating_frame_omega`, `backend`, and the code revision. `config_c1kappa_B0`
   and `B10` carry a `pin:` block selecting a symmetry-broken BRANCH and
   `config_c1kappa_B60` does not; the only thing keeping the three apart today is
   that their `Bz` differ.

3. **FAIL-SAFE: no `Model`, no id, never a hit.** 78 of 429 committed configs do
   not resolve to a `Model`, and roughly 40 of those are runnable today. Such a
   config recomputes every time and says so once per distinct reason. Recomputing
   is only slower; serving an artifact under a key that cannot express the
   question is wrong. Measured before flipping: of the three submit scripts that
   `export SPINORBEC_STAGE_CACHE=1`, only `submit_texture_bscan_lhy.sh` launches
   configs that lose caching, and that config's own first line is
   `⚠️ DO NOT RUN AS-IS` for a reason reproduced at the time (`full_bdg` reports
   the mean field dynamically unstable, max Im ω = 1050).

4. **`seed_from` had to be refused.** `_gs_cache_key`'s docstring claimed
   warm-started solves "are never auto-cached", and the guard it relied on
   (`psi_prev === nothing`) does not catch `seed_from`, which warm-starts from
   bytes at a path. 19 committed configs use it. `Stage.from` is the slot a warm
   start belongs in and `artifact_id` recurses into it, but the predecessor here
   is a directory of point files rather than a `Stage`, so this is refused rather
   than mis-declared as from-scratch.

5. **`gs_model` gained one refusal.** `_resolve_lhy_block!` copies `lhy.c_lhy`
   into `interactions.c_lhy` for any kind but only sets `lhy_kind` when the kind
   is not `none`, so `lhy: {kind: none, c_lhy: 5.0}` runs with a `ScalarLHY`
   (`make_workspace.jl:435`) while `_lhy_spec` returns the inactive `LHYSpec()`.
   That is a model claiming there is no LHY over a run that has one — found by
   this step's acceptance condition, since `c_lhy` was one of the old key's 19
   entries. No committed config is that shape.

6. **The `[KNOWN-GAP]` correction 1 left here is CLOSED.** The cache-hit
   `make_workspace` now receives `light_shift`, `spinor_lhy`, `lhy_opts` and
   `rotating_frame_omega`. It has to close here because step 3 is what makes it
   dangerous — those are slots of the model the id is derived from, so a hit is
   by construction a hit for a config that declared them, and an id that promises
   LHY over a workspace that has none is the id lying about its own artifact. The
   flip is also what makes it safe: a tabulated LHY with no explicit `n_max` has
   no id and can never reach that branch, so the table can no longer be built
   from a different ψ than the solve used. Residual, named: `:full_bdg` still
   takes its SPINOR from `psi_init`.

**Two consequences to state plainly.**

*Every `src/` edit now invalidates the whole GS stage store*, because
`artifact_id` digests `code_tree_hash()`. That is invariant 3 working as
designed, and it is §7 question 1 — which is still open. It was measurable
before only as a hypothetical; from this commit it is the behaviour.

*Arm (b) of `admit_payload` is NOT deleted here.* Step 2's deviation 2 assigned
it to step 3, and it needs a dated cutoff plus its own gate. Its population at
this site is nevertheless zero twice over: the stage store
(`SPINORBEC_STAGE_DIR`, default `<store>/_stage/gs`) does not exist, and the
flip changes every id in the store, so a pre-flip artifact is no longer
ADDRESSABLE.

`scripts/backfill_gs_stage.jl` is deleted rather than rewritten. It reconstructed
a live `_gs_cache_key` for each old point and copied ψ into the stage store;
under an id that digests the code revision, an artifact backfilled from a run of
an OLD revision would be filed under the CURRENT one, which is a lie about what
produced it. It also had nothing to do: 0 `.jld2` exist under `runs/`.

**Step 4 — the 11 ambient `Ref`s become `stage.params` fields.** Eleven
mechanical edits, listed by file:line in §1. `DEALIAS_K_CUTOFF` and
`DEALIAS_2_3_ENABLED` first: they are the pair that 75 committed configs set and
that no spec-derived key could see. ~~Gate is a grep for `const … = Ref(` under `src/hamiltonian/` and
`src/foundation/spinor_utils/`.~~ **That gate, as I specified it, was defective
and was replaced when step 4 ran it verbatim.** It matches `Ref(` but not
`Ref{Union{…}}(`, so it cannot see `DEALIAS_K_CUTOFF` — one of the two the same
sentence calls out as the pair to do first — and it scans two directories, so
both euler warps in `ext/SpinorBECCUDAExt/` are outside it. Three of eleven
invisible; measured, the grep returns 6 lines against 15 module-level `Ref`s
under `src/` + `ext/`.

The gate is now a scanner over `CODE_TREE_DIRS` (asserted equal to
`("src", "ext")` rather than restated, so it cannot drift from what
`code_tree_hash` covers) matching `Ref(` / `Ref{` / `Base.RefValue`, compared
against a **pinned literal set with a reason per entry**, checked in both
directions so neither an addition nor a rename can pass. `test_no_ambient_module_refs.jl`.

Two further gates were found broken while doing this, both reported rather than
quietly strengthened. `bench/verify_euler_warp.jl` flipped `_DDI_EULER_WARP[]`
and then called a function that takes the Taylor path first at `D <= 16`, so it
compared the Taylor kernel with itself, measured relerr `0.0`, and printed OK
under a tolerance implying its author expected a difference; `_SM_EULER_WARP` had
no coverage at all. And `test_cpu_spin_rotation_taylor_parity.jl` did not gate
`SPIN_TAYLOR_RSAFE` — its own comment claims the sweep runs "far past
`SPIN_TAYLOR_RSAFE`, where every voxel halves", but the largest R it reaches is
8.17, where an unhalved degree-40 Horner is still 3.8e-12.

**Step 5 — `refs/<paper>.toml` + `claim`.** One file, `refs/matsui2025.toml`,
~~populated from the numbers already pinned in
`test/validation/test_matsui_fig4_dip.jl`~~. `Claim`'s inner constructor is 8
lines.

**That instruction, and the example row in §2.5, were both wrong, and the way
they were wrong is the reason the step exists.** §2.5 shows
`[dip_width_nT] value = 12.84`. That number appears nowhere in
`test_matsui_fig4_dip.jl`, which pins `14.5414`. Both are correct measurements
by the same metric of the same published curve: `14.5414` is the experimental
width over the full published range, `12.8383` is the same width restricted to
**our own scan's** `[-13, +9]` nT window, which is what §0.7 of the parameter
contract actually arbitrated on. `resonance_dip`'s `center` is a parabolic
vertex and is window-invariant (measured: identical to 12 digits across five
windows); its `width` is a half-depth crossing against a per-side **endpoint**
baseline and is therefore *defined by* the window — the simulated curve gives
15.0224 / 13.0734 / 12.7524 nT over `[-20,20]` / `[-13,9]` / `[-12.5,9]`. A row
storing a bare `dip_width_nT` is under-determined by 2.3 nT, **18 %, twice the
+8.8 % excess it is used to arbitrate**. So `window` and `window_from` are
required fields on every measured row, and `quotable_digits` carries §0.7's
"quote it to two significant figures, not four" as a column rather than a
parenthesis. Six configs under `runs/matsui_fig4b/` quote the full-window
`15.0224` in their headers as "the target" while the comparison used the
scan-window number — a live instance of exactly the drift this file removes.

The shipped shape is therefore not "the numbers, copied". A `measured` row names
the fixture (by path **and sha256**), the metric, the metric field, the baseline
convention and the window; `ref` **re-runs that measurement on every call** and
refuses the row if the stored value disagrees by more than `1e-9 / 1e-12`. The
stored number is a cross-check, never the authority. Two further provenances
carry what cannot be re-measured: `read_off` names `file:line` in the authors'
published Fortran (pinned by content hash, since only the CSV extracts are
committed), and `reconstructed` — a value that source does **not** contain —
additionally owes the alternative it was chosen over and what choosing wrong
costs, in units and by a stated method (`analytic` / `measured` / `unpriced`).
27 quantities: 8 measured, 17 read-off, 2 reconstructed.

`ref` returns a `RefRow`, an explicitly-typed `NamedTuple` — that is the
`Union{Nothing, NamedTuple}` §2.5 types `Claim.target` as, pinned so the shape
does not vary per row. It has to be the **whole row**: `target.value` is what a
comparison compares, but `target.window`, `target.metric` and
`target.endpoint_baseline` are what the comparison must consume to measure our
run the same way. `scripts/validation/matsui_fig4b_report.jl:86` already does
this by hand.

**Two numbers this document and its neighbours carried were re-derived and are
wrong.** (a) "`Ntot = 3.5e4` vs `5.0e4` is a factor 2 in `c_0`, worth 34 % in
peak density" — measured, it is **10/7** (`c_0 + 36c_1` = 4687.266 against
3281.086), and 34 % is `2^(-3/5)`, the figure for a factor 2. The factor 2 is
the *separate* `cc0_eff` item, which §0.3.5 of the parameter contract **proves
is degenerate** for a polarised `m = -F` state — so
`runs/matsui_fig4b/fig4b_gsvariant_n32.yaml` prices a knob the observable cannot
see, and `matsui_reproduction_status.md:22-25` still asserts the retracted
version. (b) `ZeemanQ = 1 Hz ⇒ 0.68 nT` **checks out** (11q against
p/h = 16.275 Hz/nT ⇒ 0.6759 nT) and is now a gated arithmetic identity rather
than a sentence.

**A gate that reads the TOML and checks the TOML proves nothing**, so
`test/validation/test_matsui2025_ref.jl` (391 assertions, tier `ci`) has three
independent arms: `ref_measure` against the fixture, literals pinned in the test
file, and the raw stored value parsed straight out of the TOML. That third arm
is not decoration — the first version of arm 1 compared `ref_measure(q)` with
`ref(q).value`, and since `ref` *returns the fresh measurement*, that was a
measurement compared with itself. It was caught by canary, not by review:
neutering `ref`'s own cross-check and perturbing a stored value by 0.1 left arms
1 and 2 fully green, and only the in-test canary went red.

Eight canaries were run by breaking source, reading the log from disk, and
restoring byte-identically — the fixture shifted 1 nT *with its declared hash
updated to match* (so only the measurement can catch it), each of `Claim`'s
three refusals deleted in turn, `ref`'s value cross-check / hash check /
reconstruction required-key clause neutered, and a positive control for the
"only reader of `refs/`" tripwire. **Two gates were found green and are reported,
not quietly strengthened**: arm 1's circularity above, and a canary aimed at the
reconstruction-specific required-key clause, which is redundant whenever a row
retains *any* other cost key — stripping one key still trips the general
all-or-nothing rule, so the canary had to strip the whole group.

**What is NOT shipped, and why.** No type-C Matsui claim is constructed. It
needs 45 `:evolve` cells plus a `c_dd = 0` control, and **zero of those 46
stages are constructible**: `gs_stage` (`run_step_ground_state.jl:310`) is the
only `Stage` producer in `src/`, and `run_step_dynamics.jl` declares none — the
same blocker two committed tests in `test/model/` already name. Offering the
ground-state stage as evidence for a dip-width claim would restate a different
observable, which is the failure the `control` field exists to name. What ships
instead is the type-**A** claim the tree does support — that
`fig4b_scan_n32.yaml` resolves to the parameters registered for the paper,
checked against `ref` rather than against the config's own header prose — plus a
tripwire that fires the day an `:evolve` producer appears. `Claim`'s constructor
is the specified 8 lines and no more; the one hole they leave (`evidence =
Stage[]` constructs) is pinned as an executable statement instead of closed
unilaterally.

**Answers §7 question 4:** `refs/` at the repo root. `docs/refs/` holds PDFs for
people; this is machine-read and gated. The CSV fixtures stay in
`test/fixtures/matsui2025/` — already committed, already gated, already rsynced
to TSUBAME, and outside `code_tree_hash`, so neither location touches identity.

**`claim` collided with the test runner, and only in parallel.** `run_chunk.jl`
does `using SpinorBEC` and then defined its own `claim(dir, i)` — the O_EXCL
queue helper — at top level, so `Main.claim` shadowed `SpinorBEC.claim` for
every file that process included. `test_matsui2025_ref.jl` was **green run
directly and red under `SPINORBEC_TEST_WORKERS=auto`**, which is the worst shape
a name collision can take. The runner's helper is renamed `claim_work_item`
(root fix: a private queue helper should not squat on a package export), and the
existing "no test file shadows a SpinorBEC export" gate — whose regex covered
`struct` / `const` / `abstract type` but **not `function`**, which is precisely
why it had been green over this collision since the day `claim` was exported —
now covers `function` too. Scanning `test/` with the extended pattern returns
exactly one hit, that one, so closing the class cost nothing. This is a live
argument for §7's unasked question: `ref` and `claim` are extremely generic
names to export from a package, and the first one has already bitten.

**Step 6 — delete `metadata:`.** `schema.jl:402`, plus the 45 keys in configs,
after grepping that nothing reads them (it does not, by §1).

**Deleted from `src/` by the end:** `_gs_cache_key` + `_hashable` (done, step 3;
`scripts/backfill_gs_stage.jl` went with them), the `"metadata"` schema key
(`schema.jl:402`), and 11 `const Ref` bindings. Nothing else is removed —
`src/model/` is kept as-is and `content_id` is untouched.

**Not built at all** (compared with revision 2): `src/plan/axis.jl`,
`src/plan/chain.jl`, `src/campaign/`, `src/run/guards.jl`,
`src/model/fingerprint.jl`, the `ExecutionSeal` type, and the `physics_digest`
face on all 14 `HamTerm`s.

---

## 7. Open questions for the user

1. **Is dropping partial invalidation acceptable at 5x?** §4.1 is the largest
   deliberate loss. 52.7% of commits invalidate the whole store. The honest
   framing: this is a *compute* cost that scales with how often you edit `src/`,
   traded against a *correctness* risk that is unbounded. If GPU hours are the
   binding constraint rather than trust, this is the item to revisit — but
   revisit it by measuring re-solve hours, not by re-adding the ownership map.

2. **Should the claim-gated release be built after all?** §4.6 drops "lane B
   does not start until claim G1 is green." It is the one capability in the whole
   deleted set that autopilot genuinely does not already have. Cost is roughly
   `Claim` + one field on the autopilot queue entry, not a `Campaign` subsystem.
   It is dropped as scope, not as a bad idea.

3. **Does `stage.params::NamedTuple` need to be typed?** §4.9: a `NamedTuple`'s
   field types are per-instance, so the shape gate cannot reach it. It is hashed
   and canonicalised correctly. The alternative is one struct per method, which is
   3 structs today and N forever.

4. **`refs/` at the repo root, or `docs/refs/`?** The latter already exists as
   prose. Machine-read TOML next to human-read prose, or separated.

5. **Who owns `code_tree_hash()` on TSUBAME?** A failed `git fetch` there
   silently runs the previous commit (`reference_tsubame_4_scheduler`). Invariant
   3 makes that *visible* — the id changes — but only if the hash is computed on
   the compute node from the actual checkout, not baked at submit time. Confirm
   that is the intended reading before step 1 ships.
