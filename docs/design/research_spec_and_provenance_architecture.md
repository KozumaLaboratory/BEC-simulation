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

**The one stage cache is a hand-written allowlist.** `_gs_cache_key`
(`run_step_ground_state.jl:249-271`) is 19 entries, and its own docstring
enumerates what it drops. Two of the omissions are HamTerms that the *same
function* passes to `make_workspace` twenty lines later: `light_shift`
(`:479-480`, used at `:508`) and `rotating_frame_omega` (`:495`, used at `:511`).
Changing either serves a stale ground state at full confidence.

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
arbitrates = true          # this number, not the centre, decides the comparison
```

Provenance becomes data. `arbitrates` is the column that matters and the pattern
already ships: `test/validation/test_matsui_fig4_dip.jl` pins width and centre
and carries a canary at `:122` — shift the curve and the centre moves by exactly
the shift while the width does not; stretch it and the width doubles.

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
*Gate:* grep — exactly one call site constructs an id. This deletes
`_gs_cache_key` (`run_step_ground_state.jl:249-271`), 19 hand-listed entries
whose own docstring enumerates its exclusions and which omits `light_shift`
(`:479`) and `rotating_frame_omega` (`:495`).

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

**Step 3 — flip admission to `artifact_id`.** One-line change once steps 1 and 2
are green. `git rm src/workflow/experiments/pipeline/run_step_ground_state.jl`'s
`_gs_cache_key` (`:249-271`) and its `_hashable` helpers (`:235-241`) in the same
commit.

**Step 4 — the 11 ambient `Ref`s become `stage.params` fields.** Eleven
mechanical edits, listed by file:line in §1. `DEALIAS_K_CUTOFF` and
`DEALIAS_2_3_ENABLED` first: they are the pair that 75 committed configs set and
that no spec-derived key could see. Gate is a grep for `const … = Ref(` under
`src/hamiltonian/` and `src/foundation/spinor_utils/`.

**Step 5 — `refs/<paper>.toml` + `claim`.** One file, `refs/matsui2025.toml`,
populated from the numbers already pinned in
`test/validation/test_matsui_fig4_dip.jl`. `Claim`'s inner constructor is 8
lines.

**Step 6 — delete `metadata:`.** `schema.jl:402`, plus the 45 keys in configs,
after grepping that nothing reads them (it does not, by §1).

**Deleted from `src/` by the end:** `_gs_cache_key` + `_hashable`
(`run_step_ground_state.jl:235-271`), the `"metadata"` schema key
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
