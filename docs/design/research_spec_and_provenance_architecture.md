# Research spec + provenance architecture — the resolved Model and the derived fingerprint (SSoT)

Status: **proposed 2026-07-31**. This document is the single source of truth
for the `src/workflow/` spec / run / provenance layer, the role
`docs/design/hamiltonian_layered_architecture.md` plays for `src/hamiltonian/`.
There is currently no SSoT for this layer — the normative statement is split
across CLAUDE.md §"Workflow model", `docs/guides/experiment_api.md`, and
`docs/reference/architecture.md`, and the three disagree (the last never
mentions `Experiment`, CAS, `sweep` or `twin` at all).

**Freeze discipline, inherited**: after adoption, changes to this design
require a bug or a measurement, not a framing preference.

**Scope**: spec construction, run identity, caching, scheduling, claims,
figures. It does NOT touch `src/hamiltonian/`, `src/analysis/`,
`src/solvers/` physics — those keep their own SSoT, and this design adds
exactly **one method per HamTerm** to that layer. It does not propose a
`docs/` reorganisation (that is in flight elsewhere) and it complements
rather than duplicates PR #200 (campaign charter), #198 (mutation harness),
#226/#227/#228 (CI and citation gates).

**Audit trail — revision 2, 2026-07-31.** The first draft of this document was
red-teamed across seven attack surfaces. **47 candidate findings were raised;
15 survived independent refutation**, and they are recorded verbatim, with
their file:line evidence and with the list of things that were checked and
found NOT broken, as **issue #250**. A reader in 2029 who wants to know whether
this design was ever adversarially tested should start there.

The audit's verdict was one sentence: *the design has a theory of INPUTS and no
theory of EXECUTION.* Identity was `H(declared inputs)`, so anything undeclared
that moves a number produced not a different artifact but a **collision**, which
the cache then served. That is why §2.10 exists, why `stage_id` grew a fourth
component, and why §2.12 gained three invariants.

Two survivors were **regressions against `main`** and are fixed by name in
§2.10: `backend` is a hashed schema field today
(`src/workflow/experiments/schema/schema.jl:306`) and the first draft demoted it
to a record field; and `dealias` — a top-level block in **75 committed configs**
(`grep -rl '^dealias:' runs | wc -l` = 75) — is implemented as module-level
`Ref`s (`src/hamiltonian/integrator/dealias.jl:95,120`) that a `Model`-derived
fingerprint structurally cannot see. Which findings this revision closes, and
which it leaves open, is stated in §10.2.

---

## 1. The problem, in measurements

Everything below is measured at `bc23d150`, or cited to the eight-survey
ground truth. Two measurement scopes are in play and are not interchangeable:
*source* counts (LOC, schema keys, configs, scripts) are measured on the
worktree, whereas *stored-payload* counts (run directories, `.jld2`, `env`
stamps, `summary.json`) are measured on the main checkout
`/home/suzume/workspace/BEC-simulation`, because a fresh worktree carries no
run outputs at all — 0 `.jld2` and 0 8-hex directories, against 671 and 227
respectively in the main checkout. Where a number below is a payload count it
is the main-checkout figure.

**The spec layer.** `src/workflow/experiments/` is 13,995 LOC across 68 files
(`schema/` 2,882, `pipeline/` 3,856, `inspect*`+`diff_dicts` 1,545, `runtime/`
1,408, `analyzers/` 2,172, `runfactory.jl` 294). It compiles a raw YAML `Dict`
into `make_workspace` kwargs through **15 sequential in-place passes**, with
no typed value anywhere between the file and the Workspace. Three *divergent*
normalisation sequences exist; the shortest (`load_config`) hard-errors on 75
of the 429 configs under `runs/` because `dealias` is absent from
`TOP_LEVEL_KEYS`. 67 of the 141 declared schema keys appear in zero configs; 3
`light_shift` keys route to an unconditional `throw`; `B.sources` is fully
implemented and structurally unreachable. `runfactory.jl` (294 LOC, the DSL
CLAUDE.md says sweeps and tests use) has **zero call sites**.

**The confirmed physics losses.** The split-step B path reads `theta_deg`,
which nothing in `src/` ever writes — 27 tilted-field step instances across 8
configs silently ran with $\vec B \parallel \hat z$. The mixin merge is
shallow, so `runs/saito_li_torus/config.yaml` loses `interactions.c_total: 583`
— the override that is the entire physics point of that config
($\varepsilon_{dd} = 1.3$ instead of the natural $0.54$). Neither is detectable
after the fact: the detective layer built to find exactly these
(`inspect_checks.jl:_check_input_resolved_drop`) is **switched off on the
production path**, because `run_registry.jl:219` calls `audit_loaded_data(data)`
without `raw`.

**Identity.** Two unrelated schemes both called content-addressed.
`content_id(spec)` (`experiment.jl:120`) is SHA-256 over canonical spec bytes —
and has addressed **zero** stored results: no 16-hex output directory exists
anywhere on this machine. Every one of the 1,563 stored payloads came from
`compute_run_dir` (`run_registry.jl:31-37`), an 8-hex hash of the raw YAML
*file bytes*. Neither contains any code identity. `run!` skips on
`isfile(result.jld2)`; `run_yaml` skips per scan point on `isfile(psi_file)`.
The only stage cache, `_gs_cache_key` (`run_step_ground_state.jl:249-272`), is
a 17-entry hand allowlist that omits ten parameters the same function passes to
the solver — including `light_shift` and `rotating_frame_omega`, which are
*HamTerms* — and whose regression test asserts that unknown keys must **not**
move the key.

**The consequence.** 481 stored result summaries, 0 reproducible; 231 of 231
`env`-stamped payloads carry `git_dirty = true`; 356 of 653 payloads carry no
`env` group at all. 43 of 70 `runs/` directories cited by `docs/` do not exist,
and 27 were never committed at any point in history.

**The bypass.** 147 `scripts/*.jl`, 22,096 LOC. **145 of 147 never touch
run_yaml**; they re-enter one layer below at `find_ground_state` (70 files) and
`make_workspace` (44). 86 write no file at all. 45 are hard-dead (26 read
absent `runs/` inputs, 19 name deleted symbols). Cross-script reuse is one
shared file against 14 independent `apply_noise!` and 12 `build_cpu_ws`
definitions, 3 of the latter byte-identical.

**The provenance.** 429 YAML files, 29,449 lines, **4,673 of them comment
prose**. That prose is the *only* copy of the literature reconstructions —
which Matsui parameter was read off `time.f90` versus inferred, and what each
ambiguity is worth ($N=3.5\times10^4$ shipped vs $5.0\times10^4$ published
$\Rightarrow$ 2× in $c_0$ $\Rightarrow$ 34 % in peak density; $q/h = 1$ Hz
$\Rightarrow$ 0.68 nT of dip position). The machine-readable half is a
`metadata:` block that `schema.jl:402` declares *"free-form provenance, ignored
at runtime"* — **zero of its 45 keys has a reader**. All 22 `generator:`
scripts cited by 156 files were deleted in `3be5146d`. `claim_type` — the A/B/C
taxonomy that is architectural commitment #6 — appears in 9 of 429 files and is
read by nothing.

### Root cause

**The unit of identity is a text, and the physics is a side effect of parsing
it.** A YAML dict (or its bytes) is hashed, then destroyed by fifteen lossy
rewrites, and the resulting Workspace — the only object that actually *is* the
computation — is never named, never hashed, never written down. Every defect
above follows: a key can be dropped because nothing downstream is the same kind
of thing as the key; a cache key must be hand-listed because there is no value
to derive it from; provenance must live in comments because the format that
would hold it structurally is a dict whose meaning is defined by 15 passes of
imperative code; and a script bypasses the layer because re-entering at
`make_workspace` gets you the physics without the parsing. Fix the primitive —
make the *resolved physics* a typed value, and derive identity from it — and
the fifteen passes, the detective layer, the allowlist, and the metadata block
all cease to have anything to do.

---

## 2. The design

### 2.1 The seven concepts

A newcomer holds exactly these. Nothing else is load-bearing.

| # | Concept | One line |
|---|---|---|
| 1 | `Model` | resolved physics as ONE concrete immutable value |
| 2 | `Stage` | one unit of computation, with its inputs DECLARED as `ArtifactRef`s |
| 3 | `Axis` | `Parallel` or `Chain` — how a plan is multiplied |
| 4 | `Artifact` / `Record` | content-addressed result + its self-describing record |
| 5 | `Guard` | a fail-closed check with a MANDATORY canary |
| 6 | `Claim` | a typed assertion with evidence, a target, and a breaching control |
| 7 | `Campaign` | lanes with budgets; a gate is a Claim node, not a new concept |

`Source` / `Target` / `Reconstruction` / `Retraction` are the four record types
a `Claim` cites. They are values a user *reads and writes in a refs file*, not
runtime machinery, and they are counted as part of concept 6.

### 2.2 `Model` — resolved physics as a value

```julia
# src/model/model.jl  (NEW)

"""
The resolved physics of one computation. ONE concrete type — no type
parameters, no `Dict`, no `Any`, no `Function` fields. Nothing downstream
specialises on it, so the 23-parameter `Workspace` explosion cannot be
triggered from the plan layer.
"""
struct Model
    grid::GridSpec                  # ndim, n_points, box, dealias_two_thirds, dealias_k_cut
                                    #   (dealias is PHYSICS — §2.10; dtype is in the method digest)
    atom::AtomSpecies               # from ATOM_REGISTRY, unchanged
    interactions::InteractionSpec   # N_atoms, omega_ref, resolved c0/c1/c_extra
    potential::PotentialSpec        # Harmonic | Ring | Lattice | Tabulated | TimeDep | NoTrap
    zeeman::ZeemanSpec              # p/q/bx/by as Waveform; spatial arm inline
    ddi::DDISpec                    # c_dd, secular, padded, pad_factor, trunc_radius, euler
    lhy::LHYSpec                    # kind::Symbol + table opts (n_max, n_knots, spatial)
    tensor::TensorSpec              # even-rank channels only
    raman::RamanSpec
    light_shift::LightShiftSpec
    magnetic_gradient::GradientSpec
    frame::FrameSpec                # rotating_frame_omega, spin_rotating_frame_omega
    geometry::GeometrySpec          # quasi_2d, l_z, quasi_2d_ddi, l_z_ddi, absorbing_boundary
    loss::LossSpec
end

const Waveform = Union{Float64, PiecewiseLinearWaveform}   # small union; NEVER a Function

active(s::DDISpec) = s.enabled && s.c_dd != 0.0            # per-spec activity, ONE place
active(s::LHYSpec) = s.kind !== :none
```

`make_workspace(m::Model; psi_init, backend)` is the ONE choke point
(`src/model/build.jl`, NEW), replacing `pipeline/parsing_blocks.jl` and the 15
passes. Every derivation that YAML could not express — unit conversion, the
$c_0 + 36c_1$ constraint, literature reconstruction — lives in ordinary tested
functions that *build* a `Model`.

`with(m; ddi = with(m.ddi; secular=false))` is a generated reconstructor
(6 lines, no `Setfield` dependency).

**Serialisation is TOML.** `model_toml(m)` writes the resolved value verbatim.
Julia stdlib, no dependency, parses in 2031, readable with `cat`.

### 2.3 `Stage` — computation with declared inputs

```julia
# src/plan/stage.jl  (NEW)
struct ArtifactRef; id::ArtifactId; field::Symbol; end   # NOT `Ref` — Base.Ref is used
                                                          # 37× unqualified in src/
abstract type Stage end
struct Relax   <: Stage; model::Model; method::Method;  initial::Initial;  end
struct Evolve  <: Stage; model::Model; method::Method;  initial::Initial; save::SaveSpec; end
struct Probe   <: Stage; model::Model; probe::Probe_;   initial::Initial;  end  # ∇E, Hessian, BdG
struct Measure <: Stage; probe::Symbol; opts::NamedTuple; inputs::Vector{ArtifactRef}; end
struct Figure  <: Stage; id::Symbol;    inputs::Vector{ArtifactRef}; emit::Symbol; end

abstract type Method end          # OPEN. Extension is a declared, gated extension point.
struct ITP       <: Method; dt::Float64; n_steps::Int; tol::Float64; end
struct LBFGS     <: Method; m::Int; tol::Float64; stop_at_floor::Bool; end
struct Multistart<: Method; inner::Method; seeds::Vector{Int}; select::Symbol; end
struct Strang    <: Method; dt::Float64; duration::Float64; end
struct Yoshida   <: Method; dt::Float64; duration::Float64; order::Int; end
struct TDHFB     <: Method; dt::Float64; duration::Float64; picard::Int; end

abstract type Initial end         # OPEN, same rule.
struct FromScratch  <: Initial; state::Symbol; params::NamedTuple; seed::Int; end
struct FromAnsatz   <: Initial; builder::Symbol; params::NamedTuple; seed::Int; end
struct FromArtifact <: Initial; ref::ArtifactRef; end   # ← THE serial-dependency carrier

const Plan = Vector{Stage}
```

`Method` and `Initial` being open (with the four capabilities that produced
most of `scripts/` — gradient/Hessian probes, multistart-with-argmin,
hand-built ansatz, time-dependent trap — shipped as day-1 library surface) is
deliberate: a closed union is what forces exploration outside the system.

### 2.4 `Axis` — where the parallel decision is taken

```julia
# src/plan/axis.jl  (NEW)
abstract type Axis end
struct Parallel{T,F} <: Axis; label::Symbol; values::Vector{T}; apply::F; end
struct Chain{T,F}    <: Axis; label::Symbol; values::Vector{T}; apply::F; because::String; end
#                                                                        ^ REQUIRED kwarg

expand(p::Plan, a::Parallel)  = Plan[a.apply(p, v) for v in a.values]  # ids computable NOW
expand(p::Plan, a::Chain)     = ChainedPlan(p, a)                      # ids NOT computable
expand(p::Plan, axes::Tuple)  = # cartesian product; ArgumentError unless a Chain is LAST

schedule(v::Vector{Plan}) = [Job(p) for p in v]   # N jobs
schedule(c::ChainedPlan)  = [Job(c)]              # exactly ONE job — no other method exists
```

### 2.5 `Artifact` / `Record`

```julia
# src/store/record.jl  (NEW)
struct StageId
    physics::UInt64      # §2.8 — resolved physics × per-active-scope tree digests
    method::UInt64       # §2.8 — method × Realization × backend_kind × dtype
    inputs::UInt64       # input_digest of the declared Initial, seed included
    toolchain::UInt64    # §2.10 — resolved dep tree hashes × julia × codegen flags
end
const ArtifactId = String                        # 16 hex of digest(StageId)

"""
What the PROCESS did, as opposed to what it was asked to do. §2.10. Not part
of the id — a truncated run and a complete run have identical declarations —
but a cache hit requires `state === :complete`, so admissibility is a separate
axis from identity and neither is expressible in terms of the other.
"""
struct Completion
    state::Symbol                                # :complete | :partial | :tainted
    realized_steps::Int
    realized_t::Float64
    stop_reason::Symbol                          # :tol | :n_steps | :interrupted |
                                                 #   :line_search_stalled | :floor
    members::Int                                 # ensembles: attempted
    finite_members::Int                          # ensembles: survived
end

# --- the id-DETERMINED half. ONE per id. Byte-identical on every host and in
# --- every worktree that computes it, which is what makes it committable.
struct Record                                    # serialised as record.toml
    format::Int                                  # 4
    id::ArtifactId
    stage_id::StageId
    model_toml::String                           # the RESOLVED model, verbatim, human-readable
    method::NamedTuple                           # incl. `realization` and `backend_kind` (§2.10)
    inputs::Vector{ArtifactId}
    code::NamedTuple                             # per-active-scope tree digests
    toolchain::NamedTuple                        # per-dep name/version/tree_hash (§2.10)
end

# --- the EXECUTION half. One per execution, filename carries ts/host/pid, so
# --- two worktrees cannot collide and nothing is ever rewritten. §2.10.
struct Execution                                 # store/<xx>/<id>/exec/<ts>-<host>-<pid>.toml
    format::Int                                  # 4
    id::ArtifactId
    seal::ExecutionSeal                          # §2.10 — REQUIRED. what the RUNTIME reported.
    completion::Completion
    env::NamedTuple                              # julia, head, dirty, host, device, driver.
                                                 #   NOT backend/dtype — those are KEY fields now.
    guards::Vector{GuardResult}
    quotable::Vector{Symbol}                     # observables NOT redacted by a guard
    scalars::Dict{String,Float64}
    warnings::Vector{String}                     # the run's OWN @warn stream, ingested
    cost::CostRecord                             # measured µs/step, wall, GPU busy
    reused::Union{Nothing,ArtifactId}            # non-nothing on a CACHE HIT
    provenance::Symbol                           # :run | :scratch | :archival
    admission::Symbol                            # :ok | :partial | :tainted | :redacted
    reproducible::Bool                           # false when a recorded digest no longer
                                                 #   resolves in git — a QUERYABLE field
end
```

**A cache HIT still writes an `Execution`** (`reused = <id>`, into
`store/<xx>/<id>/hits/`). This is AiiDA's invariant — *the provenance graph must
be identical whether caching is on or off* — and it is the difference between
"the system reused something" and silence.

**Why the split.** The first draft had one `record.toml` per id carrying both
halves. Three audit findings follow from that alone: a hit's record lands on the
producer's file and overwrites its ingested `@warn` stream and its `env.head`;
two worktrees running the same `Model` write byte-different records at an
identical path, which is a recurring add/add conflict whose predictable escape
(`git checkout --ours store/`) routes around the whole mechanism; and there is
nowhere to put the per-attempt process state (`attempt`, escalated profile,
`job_id`, `kill_reason`) that `retry` / `breakers` / `budget` operate on. Making
`record.toml` a pure function of the id closes the first two by construction and
gives the third an address. `exec/` and `hits/` are append-only directories of
uniquely-named files, the shape `observability/history.jsonl` already proves
here.

### 2.6 `Guard`

```julia
# src/run/guards.jl  (NEW) — the ONE file
struct Guard
    id::Symbol
    phase::Symbol       # :preflight | :postrun | :prequote
    severity::Symbol    # :block | :error | :warn | :info   (the existing 4-level ladder)
    applies::Function   # scope predicate — this replaces per-campaign guard lists
    check::Function     # -> GuardResult(status, value, redact::Vector{Symbol})
    canary::Function    # MANDATORY (inner constructor throws without it):
                        #   an object this guard MUST trip on
end
```

`GuardResult.status` is three-valued (`:pass`/`:fail`/`:indeterminate`),
reusing `CheckResult` (`src/workflow/validation/specs.jl:33-49`) verbatim. A
guard may **abstain**; a `:block` guard treats abstention as refusal.

### 2.7 `Claim`

```julia
# src/claims/claim.jl  (NEW)
abstract type ClaimKind end
struct CodeCorrectness  <: ClaimKind end                    # A
struct PhysicsAgreement <: ClaimKind end                    # B
struct ModelFidelity    <: ClaimKind; target::Symbol; end   # C — unconstructable without a Target

struct Source                        # refs/<id>.jl
    id::Symbol; title::String; doi::String
    tier::Symbol                     # :journal | :preprint | :thesis | :conference
    fixtures::Vector{String}         # committed under refs/, with licence + checksum
    verified::Date
end

struct Target                        # value MEASURED off the fixture, NEVER transcribed
    id::Symbol; source::Symbol; fixture::String
    metric::Function                 # the SAME function is applied to our run
    fields::Tuple; tol::Tolerance
    caveats::Vector{String}          # a target may DISQUALIFY part of itself
    arbitrates::Tuple                # ⊆ fields; the rest are reported, never graded
end

struct Reconstruction                # a number INFERRED, not read off
    source::Symbol; quantity::Symbol; value::Any
    derivation::String
    alternatives::Vector{Pair{Any,String}}
    cost::String                     # what the ambiguity is worth, QUANTIFIED
end
ref(src::Symbol, q::Symbol) = RECONSTRUCTIONS[(src,q)].value   # the ONLY legal entry path

struct Retraction; target::ArtifactId; date::Date;
                   defects::Vector{String}; survives::Vector{String};
                   replaced_by::Union{Nothing,ArtifactId}; end

struct Claim
    id::Symbol; kind::ClaimKind; lane::Symbol
    statement::String
    evidence::Function               # () -> Plan | Vector{Plan} | ChainedPlan  (a THUNK)
    verdict::Function                # (Vector{Record}) -> CheckResult
    requires::Vector{Precondition}   # e.g. differs_only_in(:lhy)
    control::Union{Nothing,Mutation} # MANDATORY for B and C — must BREACH
    caveats::Vector{String}
end

claim_kind(c::Claim) = c.kind        # cross-checked against the target object by a meta-test
```

Three things here are mechanism, not prose:

- **`control` is mandatory for B and C.** If the deliberately-broken arm does
  *not* breach the tolerance, the verdict is `:indeterminate` — "this
  comparison cannot fail" is never reported green. This generalises
  `src/workflow/validation/error_budget.jl`, whose own header records that the
  requirement **rejected two gates written for `SPIN_TAYLOR_TOL`** before one
  stood up: *"Both wrong controls would have shipped as green gates asserting
  nothing."*
- **`requires = [differs_only_in(:lhy)]`** diffs the evidence *fingerprints*
  slot by slot and returns `:indeterminate` **naming the extra differing slot**.
  This is exactly what voided the Matsui GS-variant arm (`c1_ratio` set in a
  `ground_state` step never reached $c_0$) and it is now unreachable.
- **`evidence` is a thunk.** Campaigns cost nothing at load; no `expand(...)`
  is executed at precompile time.

### 2.8 The fingerprint — derived, and gated three ways

The whole invalidation answer is the fifth HamTerm face, declared in the same
file and directly under the term's sign declaration:

```julia
# src/hamiltonian/terms/lhy/lhy_term.jl  (REPURPOSED: +8 lines, beside `sign_oracle`)

"""
    physics_digest(term::HamTerm, m::Model, ws) -> Union{Nothing, Any}

The FIFTH face of the HamTerm protocol, beside `apply_step!`,
`energy_contribution`, `apply_operator!` and `sign_oracle`.

CONTRACT — returns `nothing` **iff** the term is inactive, i.e. exactly when
the other three faces take their short-circuit. Otherwise it returns a
canonical value containing EVERY number the other three faces read.

There is NO fallback method: a new HamTerm without one is a MethodError at
plan time, not a silently-poisoned cache.
"""
physics_digest(::LHYTerm, m::Model, ws) =
    active(m.lhy) ? (kind   = m.lhy.kind,
                     table  = _table_digest(ws.lhy),   # the TABLE, not the kind symbol
                     spatial= ws.lhy isa SpatialLHY,
                     c_lhy  = m.interactions.c_lhy,    # LHY reads `interactions`, not just `lhy`
                     c_dd   = active(m.ddi) ? m.ddi.c_dd : 0.0,   # dipolar builders take it
                     zfield = _zfield_digest(m.zeeman),
                     q2d    = (m.geometry.quasi_2d, m.geometry.l_z)) : nothing
```

The `_table_digest` detail is load-bearing: hashing the *kind* and not the
*table* is what let 12 configs run with `c_lhy = 0.0` on GPU while their CPU
siblings ran correctly.

Ten of the fourteen terms are **fieldless** — `DDITerm`, `LHYTerm`,
`TensorTerm`, `KineticTerm`, `TrapTerm`, `LossTerm`, `RamanTerm`,
`LightShiftTerm`, `MagneticGradientTerm`, `SpatialZeemanTerm` are literally
`struct X <: HamTerm end` (verified). Their physics lives in `ws` and in the
`Model`. This is why the face takes both, and why the existing `_sign_mutant`
canary (`test_master_oracle.jl:61`, which returns `nothing` unless every field
is a `Number`) cannot by itself gate them.

```julia
# src/model/fingerprint.jl  (NEW)
function physics_id(m::Model, ws)
    parts = Any[]
    for (slot, term) in zip(H_TERMS_CANONICAL_ORDER, build_h_terms_registry(ws))
        d = physics_digest(term, m, ws)
        d === nothing && continue                          # INACTIVE SLOTS ARE OMITTED
        push!(parts, (slot, canonical(d), scope_digest(slot)))
    end
    digest16((grid = canonical(m.grid), atom = canonical(m.atom),
              terms = parts, core = scope_digest(:core)))
end

# `method_id` is where REALIZATION lives — the choice BETWEEN algorithms that
# compute the same physics. `Realization`, `backend_kind` and `dtype` are KEY
# fields, not record fields; §2.10 is the argument and the fix.
method_id(mth::Method, r::Realization, backend_kind::Symbol, dtype::DataType) =
    digest16((nameof(typeof(mth)), canonical(mth),
              canonical(r),            # ALL fields, always — see §2.10 on why not omitted
              backend_kind,            # :cpu | :cuda   ← closes the `backend` regression
              nameof(dtype),           # :Float64 | :Float32
              scope_digest(method_scope(mth))))   # :solve_itp | :solve_rtp | :solve_lbfgs | …

stage_id(s::Relax, j::JobEnv) =
    StageId(physics_id(s.model, probe_ws(s)),
            method_id(s.method, j.realization, j.backend_kind, j.dtype),
            input_digest(s.initial),
            toolchain_id())                       # §2.10
stage_id(s::Measure, j::JobEnv) =
    StageId(probe_id(s), method_id(NoMethod(), j.realization, j.backend_kind, j.dtype),
            input_digest(s.inputs), toolchain_id())
#   ^ a Measure's physics half is the ANALYZER's declaration, so a figure does NOT
#     depend on the integrator; it depends on the artifacts it reads and nothing else.
```

`JobEnv` is the resolved execution plan — `(realization, backend_kind, dtype,
fft_flags)` — computed by a **pure function of declared values before anything
runs** (§2.10). It is not the environment as observed; that is the
`ExecutionSeal`, and the difference between the two is the whole subject of
§2.10.

**Inactive TERM slots are omitted, not encoded as null.** Adding HamTerm slot
#15 in 2029 therefore invalidates **zero** existing artifacts. This is the
single property that keeps a derived fingerprint from rotting into a hand-bumped
version number the first time someone adds a term. The rule is licensed by a
specific fact — an inactive term contributes exactly zero to `energy_contribution`
and to `apply_operator!`, which Gate A asserts — and it therefore does **not**
generalise to `Realization`, whose fields select between two non-zero
alternatives. §2.10 states that boundary and pays for it.

### 2.9 Code identity — a total, measured, repo-wide partition

```julia
# src/model/scopes.jl  (NEW) — the ONE partition of the numeric tree
const NUMERIC_ROOTS = ("src/foundation", "src/hamiltonian", "src/solvers",
                       "src/analysis", "src/validation",
                       "src/workflow/initialization", "src/workflow/io/units.jl",
                       "ext/SpinorBECCUDAExt")

const SCOPE_OWNERS = Dict{Symbol, Vector{String}}(
  :core     => ["src/foundation/", "src/hamiltonian/coefficients.jl",
                "src/hamiltonian/terms/base.jl", "src/hamiltonian/terms/registry.jl",
                "src/workflow/initialization/make_workspace.jl",
                "src/workflow/io/units.jl", "src/workflow/initialization/atoms.jl"],
  :lhy      => ["src/hamiltonian/terms/lhy/", "ext/SpinorBECCUDAExt/gpu_lhy_field.jl"],
  :ddi      => ["src/hamiltonian/terms/ddi/",
                "ext/SpinorBECCUDAExt/gpu_ddi_contraction.jl",
                "ext/SpinorBECCUDAExt/gpu_ddi_rotation.jl",
                "ext/SpinorBECCUDAExt/gpu_euler_kernel.jl"],
  :contact  => ["src/hamiltonian/terms/contact/",              # 3 SLOTS, one directory
                "ext/SpinorBECCUDAExt/gpu_spin_mixing.jl",
                "ext/SpinorBECCUDAExt/gpu_singlet_pair.jl",
                "ext/SpinorBECCUDAExt/gpu_tensor.jl"],
  :integrate=> ["src/hamiltonian/integrator/", "ext/SpinorBECCUDAExt/gpu_diagonal.jl",
                "ext/SpinorBECCUDAExt/gpu_spin_chain.jl"],
  # … one entry per remaining term slot, plus :solve_itp, :solve_lbfgs, :solve_rtp,
  #   :tdhfb, :observe_<name>, :bdg
)
slot_scope(:density_c0) = :contact;  slot_scope(:spin_c1) = :contact
slot_scope(:tensor)     = :contact;  slot_scope(s)        = s
```

Three honest statements about this, each of which the judges forced:

1. **`src/foundation/` is flat.** There is no `src/foundation/math/` and no
   `src/hamiltonian/shared/` (verified: `ls` fails on both). `clebsch_gordan.jl`,
   `spin_matrices.jl`, `spherical_harmonics.jl`, `spinor_utils/` sit at the top
   level of `src/foundation/` and are all in `:core`.
2. **`ext/SpinorBECCUDAExt/` is 24 files of per-term physics mirror and is IN
   the partition**, claimed by the owning slot. Without this, the 2026-07-28
   fix in `gpu_lhy_field.jl` would move no digest and the pre-fix artifact would
   be served as a cache hit — a *new* wrong-number-serving path, strictly worse
   than today's obviously-untrustworthy skip.
3. **`contact/contact.jl` defines three terms** (`DensityC0Term:25`,
   `SpinC1Term:136`, `TensorTerm:271`). Ownership is therefore **slot-group**
   granularity there, not per-slot, and the quoted blast radius is the group's.

**The gate**: `test/oracles/test_scope_partition.jl` asserts every `.jl` under
`NUMERIC_ROOTS` is claimed by **exactly one** scope. An unclaimed file is RED,
so a new numeric file cannot be added quietly. The complement (non-numeric
roots) is an explicit allowlist that is *also* gated, so moving a numeric file
into `src/workflow/` to escape the partition reddens the same test.

**Measured blast radius, not advertised.** Over the last 120 days, 205 of 1,933
commits (10.6 %) touched `hamiltonian/{coefficients.jl,integrator/}` +
`foundation/` — i.e. `:core`/`:integrate` — and invalidate broadly. 19 commits
touched `terms/ddi/` and 23 touched `terms/lhy/`, invalidating only artifacts
with those terms active. LEDGER's independent count: 1,436 of 1,933 commits
(74.3 %) touch no numeric file at all and invalidate nothing. That is the real
economics — a factor of a few, not a factor of a thousand.

### 2.10 Execution identity — what SHOULD run, and what DID run

§2.8 and §2.9 answer *what should run*: a plan, known before anything executes,
which is what you need in order to address an output and decide whether to skip
it. They do not answer *what did run*, which is only knowable at or after the
run. The first draft answered the first question and then behaved as though it
had answered the second. This section separates them, and each half gets its own
mechanism:

| question | when known | mechanism | consequence of a mismatch |
|---|---|---|---|
| what SHOULD run | before dispatch | `StageId` — physics × method × inputs × toolchain | a different id, hence a different artifact |
| what DID run | at step entry / at exit | `ExecutionSeal` + `Completion` | the run **refuses**, or the artifact is not servable |

The rule that makes the first half sound is one sentence, and everything below
is its consequence:

> **A number the executing kernel reads is either a field of `Model` / `Method`
> / `Initial`, or a frozen `const` (which the scope digest already covers).
> A mutable module-level binding is neither, and is banned.**

#### 2.10.1 The leak, measured

`Model` bans `Dict` / `Any` / `Function` slots (invariant 1) because a free-form
slot lets a number enter the computation without entering the digest. The audit
found the same slot, relocated to module scope where the ban does not reach.
Sweeping the eight `NUMERIC_ROOTS` of §2.9:

```
11 mutable module-level numeric Refs, 68 read+write sites in src/ + ext/,
89 write sites in test/ + bench/          (measured by grep, this worktree)

src/hamiltonian/integrator/dealias.jl:95      DEALIAS_2_3_ENABLED       = Ref(false)
src/hamiltonian/integrator/dealias.jl:120     DEALIAS_K_CUTOFF          = Ref{Union{Nothing,Float64}}(nothing)
src/hamiltonian/integrator/split_step.jl:27   MEANFIELD_MIDPOINT_ENABLED= Ref(true)
src/hamiltonian/integrator/spin_chain.jl:43   SPIN_CHAIN_FUSION_ENABLED = Ref(true)
src/hamiltonian/integrator/combined_spin_step.jl:51
                                              COMBINED_SPIN_STEP_ENABLED= Ref(false)
src/foundation/spinor_utils/spin_rotation_taylor.jl:31,64,70,89
                                              SPIN_TAYLOR_{ENABLED,TOL,RSAFE,DEGREE_CAP}
ext/SpinorBECCUDAExt/gpu_euler_kernel.jl:190   _SM_EULER_WARP           = Ref(true)
ext/SpinorBECCUDAExt/gpu_euler_kernel.jl:232   _DDI_EULER_WARP          = Ref(true)
```

They are read at step time — `DEALIAS_2_3_ENABLED[]` inside the DDI apply at
`src/hamiltonian/terms/ddi/ddi_padded.jl:164` and again at
`src/hamiltonian/terms/ddi/convolution.jl:184`, `MEANFIELD_MIDPOINT_ENABLED[]`
at `split_step.jl:36` — and never stored on `Workspace`, so
`physics_digest(term, m, ws)` (§2.8) returns an identical value either way.
Gate B perturbs `fieldnames` of `Model`; Gate C instruments `getfield` on
`Model` inside `make_workspace`. A bare `Ref[]` read inside `split_step!` is
neither.

The codebase already classifies these as physics rather than as tuning:
`combined_spin_step.jl:42-46` — *"the two are different SPLITTINGS of the same
Hamiltonian, agreeing at O(dt³) but not bitwise, so flipping it changes
published numbers. It is a physics choice the run must make."* The two
`gpu_euler_kernel.jl` Refs the audit's own grep missed pick between a
warp-cooperative reduction (`:207`, `:344`) and a per-thread one — a different
accumulation order, therefore different bits.

Two more members of the same class, outside the `Ref` shape:

- **`ENV`** — `haskey(ENV, "SPINORBEC_NO_AUTO_BACKEND")` at
  `src/workflow/initialization/make_workspace.jl:857` forces `CPUBackend()`
  ahead of the auto-pick, so the *mere presence* of an environment variable
  flips CPU/GPU and no config hash can see it. (Measured: grepping `ENV[` /
  `haskey(ENV` / `get(ENV` across all eight `NUMERIC_ROOTS` returns **exactly
  this one site**, which is what makes banning the whole construct cheap.)
- **27 mutated module-level caches** under `NUMERIC_ROOTS`. These are the
  performance architecture and are **not** deleted; §2.10.6 brings them under a
  registration rule instead.

#### 2.10.2 The fix — delete the Refs into three destinations

Each of the eleven goes to exactly one place. Nothing is traced; the variable
is removed, so there is nothing left to observe.

| destination | which | rationale |
|---|---|---|
| **`Model`** (`GridSpec`) | `DEALIAS_2_3_ENABLED`, `DEALIAS_K_CUTOFF` | dealias is an exact spectral projector on the state: two runs that differ in it differ in their answer. It is physics. |
| **`Method`** (`Realization`) | `MEANFIELD_MIDPOINT_ENABLED`, `SPIN_CHAIN_FUSION_ENABLED`, `COMBINED_SPIN_STEP_ENABLED`, plus `fft_flags` | splitting and kernel-selection choices: same physics, different algorithm. |
| **frozen `const`** | `SPIN_TAYLOR_{ENABLED,TOL,RSAFE,DEGREE_CAP}`, `_SM_EULER_WARP`, `_DDI_EULER_WARP` | not run-selectable at all. A `const` is code; `scope_digest` already covers it. |

**The frozen arm is the cheap one and it is what the files themselves argue
for.** `spin_rotation_taylor.jl:56-59` on the tolerance: *"the tolerance is not
a decision the caller should be asked to make; `dt` is the decision, and this
follows from it."* `:75-88` on the degree cap: it exists *"so the accuracy
criterion needs a positive control and nothing else could provide one …
unclamped in production."* The two euler-warp Refs have **one writer in the
entire repository** (`bench/verify_euler_warp.jl:20`). Freezing them means the
parity gates that currently flip a `Ref` call the two implementations directly
instead — the same comparison, one less ambient variable. Changing a frozen
`const` is a code edit that moves `scope_digest(:core)` or `scope_digest(:ddi)`,
which is exactly the right invalidation.

```julia
# src/plan/realization.jl  (NEW, ~30 LOC)
"""
Every numeric switch that chooses BETWEEN algorithms computing the same physics.
ONE concrete immutable struct; all fields Bool / Int / UInt32, so it adds ZERO
type parameters to anything it is threaded into.

This type exists because these values were mutable module-level `Ref`s read
inside `split_step!` — the free-form slot invariant 1 bans, relocated to where
the ban did not reach. `test_no_ambient_numerics.jl` is what stops them moving
back.
"""
struct Realization
    midpoint::Bool           # was MEANFIELD_MIDPOINT_ENABLED   split_step.jl:27
    spin_chain_fusion::Bool  # was SPIN_CHAIN_FUSION_ENABLED    spin_chain.jl:43
    combined_spin::Bool      # was COMBINED_SPIN_STEP_ENABLED   combined_spin_step.jl:51
    fft_flags::UInt32        # was an unhashed make_workspace kwarg (:72)
end
const PRODUCTION_REALIZATION = Realization(true, true, false, FFTW.MEASURE)
```

**`canonical(::Realization)` emits ALL FOUR FIELDS, ALWAYS.** It is tempting to
borrow §2.8's "inactive slots are omitted" and canonicalise only deviations from
`PRODUCTION_REALIZATION`, which would make adding a fifth switch in 2029 free.
That is the same defect this section exists to remove: when a default flips, a
pre-flip run and a post-flip run both canonicalise to the empty tuple and
**collide**. It is not hypothetical here — `DDI_PADDED_DEFAULT` flipped
`false → true` at `9c117c05` with a documented incident
(`src/foundation/voxel_index.jl:14`, `spin_chain.jl:61-64`: the flip declined
the spin-chain fusion for every `run_yaml` RTP run while `bench/profile_rtp.jl`
kept measuring the fused path). §2.8's omission rule is licensed by a fact that
Gate A asserts — an inactive term contributes exactly zero — and a field equal
to a mutable default contributes something. **The cost is stated rather than
engineered away:** adding a fifth `Realization` field invalidates every stored
artifact. The set is four, it is frozen by `test_realization_frozen.jl` (field
names pinned to a committed list), and adding to it is a reviewed physics event,
not a routine addition.

**Feasibility, measured, because the two obvious objections are both false.**
`Workspace` has 20 type parameters (`src/foundation/types/workspace.jl:69-90`),
every one of them an array / eltype / optional-arm parameter; a `Bool` or
`UInt32` field adds none, so `typeof(ws)` does not change and the
`@noinline _step_dispatch!(@nospecialize(step), …)` firewall
(`src/workflow/experiments/pipeline/runner.jl:244`) is untouched. There is
exactly **one** positional `Workspace(...)` construction site
(`make_workspace.jl:465`); `_rebuild_workspace` (`:495-506`) already copies by
`fieldnames(Workspace)` and its docstring says why — *"Avoids fragile positional
constructor calls when Workspace gains new fields"* — so it needs no edit at
all. The CLAUDE.md JIT
landmine is `Dict{Symbol,Any}` and closures escaping into the Workspace path;
a concrete scalar struct is its documented opposite — `LHYTableOpts`
(`make_workspace.jl:33-57`) exists for exactly this reason.

**Dealias threading, the one non-trivial part.** Of the nine step-path reads,
seven already hold `ws` (`split_step.jl:82,385`, `spin_chain.jl:83`,
`itp_loop.jl:78,92`, `run_loops.jl:125,136`). The other two
(`ddi_padded.jl:164`, `convolution.jl:184`) hold a `DDIParams`, a mutable struct
that **already carries `box_size` for exactly this reason** —
`src/foundation/types/ddi_loss.jl:25-29`: *"it is carried here because the
Orszag F-filter's physical `DEALIAS_K_CUTOFF[]` is meaningless without it."*
So the spec lands on both `Workspace` and `DDIParams` (the psi-filter runs with
DDI off, so `Workspace` alone is not enough), and a one-line assertion in
`make_workspace` pins them together: `@assert ws.dealias === ws.ddi.dealias`.
`_spin_chain_reason` (`spin_chain.jl:83`) must read the same field the DDI path
reads, or fusion eligibility and the filter can disagree — that is the
`DDI_PADDED_DEFAULT` shape again, and it is why the assertion is not optional.

**`GridSpec` already declares this, and that is the sharper half of the
finding.** The in-progress `Model` prototype — *uncommitted*, on branch
`feat/model-resolved-physics`, and therefore not part of any claim about the
tree as it stands — carries `dealias_two_thirds::Bool` and `dealias_k_cut::Float64`
in `GridSpec`, and `physics_id` mixes in `canonical(m.grid)`. What is missing is a
**consumer**: nothing outside the prototype reads `GridSpec`, and
`grep dealias src/workflow/initialization/make_workspace.jl` is empty. So the
prototype would declare a dealias setting the propagator never reads. That
is *worse* than a collision — a `k_cut` sweep produces N distinct ids with
bit-identical numbers, which reads as positive evidence that `k_cut` does not
matter, which is precisely the false null the convergence study exists to avoid.
`make_workspace(m::Model)` (§2.2) becomes the single writer, and
`test_declared_equals_observed.jl` hard-errors when the built `Workspace`
disagrees with the `Model` that built it.

**The 75 configs.** `dealias:` is a top-level block in 75 committed configs, and
its only writer is `apply_dealias_block!`
(`src/workflow/experiments/runtime/dealias_block.jl:82-86`), which §6.2 deletes.
The block becomes a `GridSpec` field mapping in the `Model` builder — a schema
translation, not a data migration. The `auto_dt` pipeline walk
(`dealias_block.jl:94-132`) is pure dict manipulation and survives as a `Method`
builder. `_DEALIAS_PENDING_SNAPSHOT` (`:38`), the two-phase snapshot that can
strand a toggle at `true` across an exception — the incident is recorded in the
file itself at `:62-68`, where a stuck toggle silently degraded unrelated tests
from 1e-12 to 1e-10 — is deleted outright, not ported. With no global there is
nothing to snapshot.

**`with_reference_accuracy` stops being a null.** `ACCURACY_KNOBS`
(`src/workflow/validation/accuracy_knobs.jl:96-158`) has three `:global` entries
— `:spin_taylor` (`:97`), `:spin_taylor_tol` (`:104`), `:dealias_2_3` (`:110`) —
each a getter/setter closure pair over a Ref that this section deletes, flipped
by `with_reference_accuracy` (`:170-183`) *without changing the id*. That is the
degenerate measurement the audit named: the one instrument built to detect
approximation error returns the production artifact verbatim. Rewritten, a
reference accuracy run constructs a different `Model` (dealias) or a different
`Realization`, hence a different `method_id`, hence a different artifact. The
null becomes a measurement. This is a real rewrite of a 231-line file plus its
two test files, and it is priced in §9.

#### 2.10.3 `backend` is a KEY field — the first regression, fixed

`Method` in the first draft carried no backend; `backend` sat in `env`, declared
a record field. That is a **regression against `main`**, where `backend` is a
hashed schema field (`src/workflow/experiments/schema/schema.jl:306`,
`enum=["cpu","gpu"]`) and CPU/GPU variants are therefore distinct directories
under `compute_run_dir`. Backend-only variants are established practice here:
`runs/eu_ham_only_ramp_quench_24/config.yaml:11` documents itself as
*"backend: gpu -> cpu (CI-friendly)"*.

The rationale offered in the prototype (uncommitted; *"GPU and CPU are gated to
bit-parity by Level 0, so the backend cannot move the physics id"*) is false on
both halves. `test/test_level0_gpu_cpu_consistency.jl` gates at `rtol` 1e-10 /
1e-8 / 1e-6, never bit-equality, and its fixtures are 1D/2D Rb87 grids that
`_resolve_backend` (`make_workspace.jl:855-864`) would never send to a GPU. The
repo's own history is the counterexample: the tabulated-LHY GPU defect ran for
months with `test_gpu_cpu_per_term_parity.jl` green. And §2.10.1's two
euler-warp Refs mean even one backend had two bit-different kernels for the same
rotation.

```julia
# backend_kind ∈ {:cpu, :cuda} is a KEY field of method_id (§2.8).
# Device model, driver and GPU UUID stay in the seal — they are observations.
#
# RESOLVED AT PLAN TIME by a pure function of declared values, so the id is
# computable before dispatch:
resolve_backend(m::Model, requested::Symbol) =
    requested === :auto ?
        (m.grid.ndim == 3 && maximum(m.grid.n_points) >= 24 ? :cuda : :cpu) :
        requested
```

`SPINORBEC_NO_AUTO_BACKEND` (`make_workspace.jl:857`) is **deleted**: an
environment variable whose mere presence flips CPU/GPU is the same defect
wearing a third hat, and its stated use (test isolation, debugging a GPU/CPU
divergence) is served better by `backend = :cpu` in the plan, which now
addresses a different artifact.

Note what `resolve_backend` drops relative to `_resolve_backend`: the
`cuda_functional()` availability check. That is deliberate and it is why the
seal is required. A plan may declare `:cuda`; a node where the CUDA extension
fails to load would silently fall back to `CPUBackend()` and stamp the result
with the `:cuda` `method_id` — *"GPU silent CPU-fallback"* is already a recorded
TSUBAME failure mode. So `backend_agrees` is an **assertion in the seal**
(§2.10.5): the observed backend must equal the declared one, or the run refuses
before the first step. Availability is not a fingerprint input; it is a
precondition.

The gain is larger than the regression it repairs. Under one `Model`, CPU and
GPU are now two named artifacts, so "GPU equals CPU" becomes an **observation
the store can express** — a comparison between two ids — rather than an axiom
the addressing assumed.

#### 2.10.4 `toolchain_id` — resolved dependency hashes, not `project_hash`

`NUMERIC_ROOTS` (§2.9) is eight paths, all inside this repo, so no dependency
can move a scope digest. That is deliberate. But the first draft's fallback
record field is broken on its own terms and the sentence in §5.3 asserting it
is corrected there: `env.manifest_project_hash` is Pkg's `project_hash`,
computed by `workspace_resolve_hash` over **dep names, uuids and compat strings
only** — its own comment says so — never resolved versions. `Project.toml`
carries `CUDA = "5, 6"`, so a `Pkg.up` anywhere inside that range leaves it
bit-identical.

```julia
# src/model/toolchain.jl  (NEW, ~40 LOC)
const NUMERIC_DEPS = ("CUDA", "FFTW", "SpecialFunctions", "StaticArrays", "JLD2")

function toolchain_id()
    parts = Tuple{String,String,String}[]
    for (_, d) in Pkg.dependencies()
        d.name in NUMERIC_DEPS || continue
        push!(parts, (d.name, string(d.version),
                      d.tree_hash === nothing ? "stdlib" : string(d.tree_hash)))
    end
    sort!(parts)
    length(parts) == length(NUMERIC_DEPS) ||
        error("NUMERIC_DEPS unresolved: got $(first.(parts))")
    cf = Base.CacheFlags()
    digest16((deps = parts,
              julia = string(VERSION), llvm = string(Base.libllvm_version),
              opt_level = cf.opt_level, check_bounds = cf.check_bounds,
              inline = cf.inline,
              cpu_target = unsafe_string(Base.JLOptions().cpu_target)))
end
```

`Pkg.dependencies()` gives a resolved `tree_hash` per dependency — the content
hash of the resolved package — which discriminates exactly what `project_hash`
cannot. Measured on this machine: `CUDA v5.11.0
tree_hash=ea6a2ab8307059b6c9ea186ff7dfcd032a13b731`, `FFTW v1.10.0
tree_hash=97f08406df914023af55ade2f843c39e99c5d969`, `JLD2 v0.5.15
tree_hash=d97791feefda45729613fafeccc4fbef3f539151`; the call is ~6 ms warm and
is memoized per process. `tree_hash` is `nothing` for stdlibs, which the code
above handles rather than assumes.

`NUMERIC_DEPS` is a hand-written tuple and would rot by default, so
**`test_numeric_deps_total.jl`** asserts every `[deps]` entry of `Project.toml`
is either in `NUMERIC_DEPS` or in a declared, reasoned `NON_NUMERIC_ALLOWLIST`.
A new numeric dependency cannot be quietly filed as non-numeric.
`Preferences.jl` — the Julia-idiomatic way to add exactly the kind of switch
§2.10.1 bans, and one that is baked at precompile time and therefore invisible
to every runtime scan — is named in that allowlist as **forbidden**, not merely
absent.

Cost, honestly: putting `toolchain_id` in the key means a `Pkg.up` of CUDA
invalidates every GPU artifact. `Manifest.toml` has been committed exactly once
in repo history, so this is roughly one mass invalidation per year, and it is
the correct behaviour — the alternative is the finding.

#### 2.10.5 The `ExecutionSeal` — what the RUNTIME reported

Everything above still only describes a plan. The seal is the other half.

The first draft's §5.5 remote assertion — *"the compute node re-plans and
asserts the fingerprint matches what was shipped"* — cannot detect the failure
it is aimed at, because **both sides read the same disk**. A PackageCompiler
`-J` image has `SpinorBEC` as a root module at startup, so `using` returns it
before any staleness path (Julia 1.12.6 `loading.jl`, `canstart_loading` returns
`maybe_root_module(modkey)` before `stale_cachefile` is ever consulted), while
`scope_digest` reads the freshly-rsynced source. Both agree, the artifact is
stamped `reproducible = true`, and the numbers came from the pre-fix kernel. The
arming route is live and documented as such:
`src/workflow/autopilot/backends_uge.jl:184` builds `-J $(sysimage_path)` and
its own comment at `:190-193` instructs the operator to *"rebuild only on
Project.toml / Manifest.toml change"*.

The seal breaks the symmetry by putting a **runtime-reported fact** on one side
of the comparison.

```julia
# src/run/seal.jl  (NEW, ~120 LOC)
struct ExecutionSeal
    # --- ASSERTED. A mismatch REFUSES before the first propagator call. ---
    image_agrees::Symbol        # :match | :MISMATCH | :from_sysimage
    backend_agrees::Bool        # observed backend == declared backend_kind (§2.10.3)
    declared_equals_observed::Bool  # every Model field with a runtime counterpart matches
    ambient_refs::Vector{Pair{Symbol,Any}}   # reflective scan; MUST be empty (§2.10.6)

    # --- RECORDED. Never a key field, never asserted. ---
    pkg_source::String          # pathof(SpinorBEC) — the tree the image CLAIMS
    pkg_build_id::UInt128       # Base.module_build_id(SpinorBEC)     — a NONCE, see below
    ext_build_id::Union{Nothing,UInt128}     # the CUDA ext has its own PkgId and build id
    in_sysimage::Bool           # Base.in_sysimage(Base.PkgId(SpinorBEC))
    image_file::String          # unsafe_string(Base.JLOptions().image_file)
    cache_flags::NamedTuple     # opt_level, check_bounds, inline, debug_level
    cpu_target::String          # requested ("native")
    cpu_name::String            # resolved  (Sys.CPU_NAME)
    blas_threads::Int; fftw_threads::Int; blas_config::String
    fft_plans::Vector{UInt64}   # hash(sprint(show, plan)) per plan on the Workspace
    device::Union{Nothing,NamedTuple}   # name, uuid, capability, nvidia_driver, cufft, cublas
end

"Is the module the RUNTIME loaded the one the CURRENT on-disk source produces?"
function image_agreement(m::Module)
    pid = Base.PkgId(m)
    Base.in_sysimage(pid) && return :from_sysimage
    src = Base.locate_package(pid); src === nothing && return :MISMATCH
    want = Base.module_build_id(m)            # what the RUNTIME loaded
    for c in Base.find_all_in_cache_path(pid)
        r = Base.stale_cachefile(src, c)      # `true` == stale against CURRENT source
        r === true && continue
        r[3] == want && return :match
    end
    :MISMATCH
end
```

**A correction to the obvious reading, because it was measured.**
`Base.module_build_id` is a **per-build nonce, not a content hash**: recompiling
byte-identical source in a fresh depot yields a different id, and a comment-only
edit moves it. It therefore can never be a key field and can never be compared
across hosts. Anyone who hashes it ships a field that differs on every rebuild
of identical code. Its role here is (a) a record field and (b) one side of a
**within-process** comparison. The discriminating power comes from the
*relation* — is the loaded build id among the build ids of the caches that
`stale_cachefile` reports as **not stale against the current source** — not from
the id itself.

**When each field is captured, and against what it is compared.**

- **At stage entry, before `make_workspace` returns and therefore before any
  payload byte.** Not at process exit: `with_reference_accuracy`
  (`accuracy_knobs.jl:170-183`) and `apply_dealias_block!`
  (`dealias_block.jl:111-112`) both restore in a `finally`, so an exit-time
  capture reads the *restored* value, not the value in force during the steps.
- `image_agrees` is compared against the caches `Base.stale_cachefile` declares
  fresh **against the current on-disk source**. `:MISMATCH` is a hard error
  before the first step, not an annotation.
- `in_sysimage == true` is a **refusal** unless the image carries
  `SpinorBEC.SYSIMAGE_SCOPE_DIGESTS`, baked by
  `scripts/build_sysimage_full.jl`, equal to the plan's active scope digests.
  Day one the builder bakes nothing, so **every `-J` run hard-errors** until
  someone implements the stamp. That is the correct default: the finding
  converts from silent-wrong-number to a loud stop. Baking the stamp is real
  work — the constant cannot live in `SpinorBEC`'s own source, since that source
  is what the image bakes — and it is listed as open in §10.2.
- `backend_agrees` and `declared_equals_observed` are compared against the plan
  (§2.10.3, §2.10.2). Both refuse on mismatch.
- `ambient_refs` must be empty at entry **and again at exit**; entry ≠ exit ⇒
  `admission = :tainted`, never servable. This catches a Ref created mid-run,
  which is the `dealias_block.jl:62-68` incident shape.
- Everything in the RECORDED block gates nothing. It is what a human reads when
  two artifacts at one id disagree.

**Cost**: ~554 ms cold, ~26 ms warm per stage (`image_agreement` is 26 ms on the
real package here, over 10 cache files; `Pkg.dependencies()` ~6 ms warm; the
reflective scan ~405 ms; an FFTW plan string 208 µs). Against a ~20 s package
load and stages measured in minutes to hours, this is free. Nothing enters a hot
loop.

**What the seal cannot catch, stated flatly and required in the schema doc.**

1. It identifies the **loaded image, not which methods were invoked**.
   `module_build_id` is one `UInt128` for all of `SpinorBEC`, so a change to an
   uncalled helper and a change to `split_step!` are indistinguishable. It is a
   *necessary* condition on the executed code, never a sufficient one.
2. The only general Julia mechanism that observes which code actually executed
   is `--code-coverage`, which forces source-level recompilation and would
   therefore destroy the very sysimage it is auditing. Rejected here on that
   ground, not deferred.
3. Nothing about **hardware, driver version, or nondeterministic kernels**.
   CUDA atomic reduction order and multithreaded BLAS / FFTW summation order are
   recorded (`blas_threads`, `fft_plans`, `device`) and never gated. The
   measured OpenBLAS level-1 effect — an L-BFGS iteration at 156.6 ms with 192
   threads against 50.2 ms with one — is a different reduction tree and
   therefore different bits; the seal tells you which one you got and nothing
   more.
4. **Dependency-internal state.** FFTW's chosen codelet tree is *recorded* by
   `fft_plans`; nothing constrains it. `toolchain_id` reads
   `Pkg.dependencies()`, i.e. the on-disk manifest, so a sysimage baking CUDA
   5.9 against a manifest resolving CUDA 5.11 is invisible to both halves. That
   is the same shape as the sysimage finding, one level down, and it is open
   (§10.2).
5. It rests on four unexported `Base` internals — `module_build_id`,
   `in_sysimage`, `find_all_in_cache_path`, `stale_cachefile` — plus a specific
   ordering in `loading.jl`. Julia 1.13 may move them. The failure direction
   matters: a changed tuple shape errors loudly, but a change in *which* caches
   are reported non-stale would degrade `image_agreement` to always-`:match`.
   `test_image_agreement_canary.jl` therefore mutates a source file under a
   running image and asserts `:MISMATCH` — the positive control, run in CI, not
   once by hand.

#### 2.10.6 The gates

Three gates, all in the FAST tier, all canaried. E1 has two arms — one static,
one reflective — and §2.10.5's `ambient_refs` runs the reflective one again at
step entry and exit, so the same predicate is both a CI gate and a runtime
assertion. The template is in-tree:
`test/oracles/test_lhy_no_bare_device_broadcast.jl` is 69 lines of `walkdir` +
comment stripping + explicit allowlist, and critically
`@test Set(sites) == allow` at `:63` — the assertion that stops an allowlist
silently ceasing to guard.

**E1 · `test/oracles/test_no_ambient_numerics.jl`.** Over `NUMERIC_ROOTS`,
RED on any **unregistered mutable module-level binding**, and RED on any
`ENV[` / `haskey(ENV` read. Registration is the cache list of E2; there is no
"numeric switch" category to register into, so a switch simply cannot be
declared. Two arms, both required:

- *syntactic* — `grep -rnE '^(const|global)? *[A-Za-z_]\w*(::.*)? *= *(Ref|Base\.RefValue|Threads\.Atomic|Dict|IdDict)'`. Measured on today's tree: finds
  11/11 numeric Refs with zero false positives (every other `const … = Ref` in
  `src/` sits outside `NUMERIC_ROOTS` and is orchestration), and the `ENV` arm
  finds exactly one site, `make_workspace.jl:857`, whose remediation is
  deletion. Cost 0.096 s over 393 files.
- *reflective* — walk `names(m; all=true)` + `getglobal` over `SpinorBEC`, **its
  real submodules** (`Units`, `Calibration`, `Optimization`, `Dashboard`;
  `names` does **not** reach submodule bindings, so the walk must recurse) and
  every loaded extension via `Base.get_extension`. This catches a binding
  created by `@eval` or a macro, which no regex sees. Two implementation
  details are load-bearing rather than defensive: the predicate must be
  `v isa Base.RefValue` and then inspect the value, because
  `Base.RefValue{Union{Nothing,Float64}}` — i.e. `DEALIAS_K_CUTOFF`, the
  flagship case — is **not** `isa Base.RefValue{<:Union{Bool,Number}}`; and
  `isassigned(v) || continue` is mandatory, because CUDA bakes an unassigned
  `Ref{CuGraphExec}` whose `v[]` throws `UndefRefError` and would take the run
  down.

Both arms are needed and neither is redundant: reflection cannot see an
extension that is not loaded, so on a CPU-only CI runner it silently
under-claims; the regex cannot see a binding that does not appear in source
form. **Canaries** (without which this is the empty gate `error_budget.jl:33`
was written to prevent): removing one entry from the expected set must turn E1
RED; `@eval`-ing a `Ref` into a fixture module under a numeric root must turn
the reflective arm RED; and after the deletion lands the expected `ambient_refs`
is the empty set, so the reflective arm carries a **permanent positive control**
— a fixture module holding one deliberate `Ref` that the scan must always find.
Without that control, a predicate matching nothing is indistinguishable from a
correct empty result.

**E2 · `test/oracles/test_cache_key_completeness.jl`.** The 27 mutated caches
are kept, so they need a rule that is mechanical rather than a review promise.
Every one must be registered with a **declared determinant list**, and the gate
asserts two things by measurement, not by judgement: (i) the declared
determinants are a **superset of the values the `get!` closure reads** — the
same `getfield`-instrumentation trick Gate C (§5.1) already uses on `Model`;
(ii) a bare `objectid(x)` in a key is RED unless `x` is retained in the key
tuple. The second rule alone closes a live defect: `_axis_broadcast`
(`src/foundation/backend.jl:60-62`) keys on
`(typeof(template), eltype(vec), length(vec), objectid(vec))` with no pin, four
lines below `_to_device_cached` whose docstring (`:32-35`) explains that the key
holds the array itself *"so it is also pinned against GC and no later array can
reuse its address and inherit its entry"*. Measured on Julia 1.12.6: 40.1 %
objectid reuse for freed `Vector{Float64}`. Its callers pass `grid.x[1..2]` /
`grid.k[1..2]`, so two scan points with the same `n_points` and a different
`box` are the collision case and `length(vec)` cannot separate them. Same shape
in `_LHY_TABLE_CACHE` / `_SPATIAL_LHY_CACHE`
(`ext/SpinorBECCUDAExt/gpu_lhy_field.jl:42-49,99-105`). The correct pattern
already exists in-tree exactly once and is the reference implementation:
`_DIAG_ZPH_KEY` (`ext/SpinorBECCUDAExt/gpu_diagonal.jl:182-208`) validates the
cached **content key** on every hit, not just the shape key.

**E3 · `test/oracles/test_numeric_deps_total.jl`** — §2.10.4.

**What the gates cannot catch, exhaustively.**

- A mutable value reached through a **struct field** rather than a module
  binding. `SCRATCH_REGISTRY` (`src/foundation/scratch.jl:23`, 10+ step-path
  callers, and its own `:20` concedes *"single-threaded by construction"*) holds
  arbitrary entries; E1 sees the registry, E2 constrains its keys, neither
  constrains what a caller puts in it.
- `task_local_storage`, a `Ref` inside a dependency, and any value baked at
  precompile time. `Preferences.jl` is the named instance and is banned at the
  dependency level (§2.10.4) rather than detected.
- **Semantics.** E1 is structural. The 11/11 precision is an *empirical
  property of today's tree*, which is why registration — not classification — is
  the mechanism: there is no way to declare a binding "numeric but fine".
- **`NUMERIC_ROOTS` itself.** Every gate is scoped to the eight roots.
  `test_scope_partition.jl` gates ownership *within* them; nothing gates that
  the roots still cover the numeric surface. `_cuda_functional_callback`
  (`src/workflow/experiments/pipeline/run_registry.jl:632`, set from
  `ext/SpinorBECCUDAExt/SpinorBECCUDAExt.jl`) is a live instance outside the
  roots — whether `import CUDA` ran before `using SpinorBEC` decided CPU vs GPU
  for every 3D grid at n ≥ 24. This revision removes it along with the auto-pick
  (§2.10.3), but the general hole stays open and is listed in §10.2.

#### 2.10.7 Declared inputs that do not reach the executed path

One more class, and it is the purest instance of the whole finding.
`seed_device_rng!` — whose docstring instructs the caller to seed the GPU stream
once per trajectory — has **zero call sites** in `src/`, `ext/`, `test/`,
`scripts/` and `bench/`; only the two definitions exist
(`src/foundation/backend.jl:96`, `ext/SpinorBECCUDAExt/gpu_rng.jl:13`). Every
GPU stochastic run therefore draws from an unseeded process-global CURAND
stream, and `src/solvers/spgpe.jl:501` says so in prose: *"seed then only
controls the CPU path."* So `seed:` is a **declared** input that the digest will
faithfully hash and that has no effect on the executed GPU path — same id,
different numbers, by construction.

The fix is one call in `run_stage!` before the first stochastic step, plus
`test_rng_declared.jl` with a **mandatory positive control**: same seed ⇒
bit-identical first draw, *and different seed ⇒ different draw*, so the gate is
not itself a null from a degenerate knob. In the same commit,
`Random.default_rng()` stops being the `seed === nothing` default at the eleven
numeric entry points that use it (`spgpe.jl:440`, `sgpe.jl:192`,
`photon_heating.jl:36`, `scalar_egpe.jl:489`, `hessian.jl:138,275`,
`stability_spec.jl:76`, `imaging.jl:81,146,258,363`) — `seed::Int` becomes
required. This must land **before** anything in §2.10 is trusted, because the
seal would otherwise faithfully certify a cache hit for a run whose numbers are
not reproducible.

#### 2.10.8 The store write protocol

§5.4 gave a layout and no write order, no completeness marker and no exclusion,
while the idiom this repo would carry in derives the temp path from the
destination — `_scratch_tmp_path` returns `final_path * ".tmp"`
(`run_registry.jl:656-664`), so two writers at one id share an inode. The same
idiom appears at nine sites, two of them in files this design keeps verbatim,
and `_move_scratch_to_final` (`:668-677`) documents that a cross-filesystem
scratch degrades `mv` to copy+delete — non-atomic, and that is the TSUBAME path.
The probe is a bare `isfile`.

```
store/<xx>/<id>/
  CLAIM/                            mkdir(2) — atomic on POSIX. holds host, pid,
                                    job_name, started_at. Stale claims reconcile
                                    through find_job_by_name (backends_uge.jl:513)
                                    and the qstat idiom scripts/eu_campaign_resume.sh:40,71
                                    already uses.
  record.toml                       the id-DETERMINED half (§2.5). Byte-identical
                                    across hosts and worktrees ⇒ committable, and
                                    two branches cannot produce a merge conflict.
  psi.jld2                          staged IN THE SAME DIRECTORY as
                                    psi.jld2.<host>.<pid>.<rand>, fsync, rename(2).
                                    Renaming within a directory is always atomic and
                                    takes the cross-filesystem degradation out of the path.
  exec/<ts>-<host>-<pid>.toml       ONE per execution: seal, completion, env, cost,
                                    guards, warnings, admission. Append-only, never rewritten.
  hits/<ts>-<host>-<pid>.toml       ONE per cache hit.
```

Write order: `CLAIM/` → payload staged, fsync, rename → `record.toml` if absent
→ `exec/<…>.toml` **last, and it is the completeness marker**. A crash before it
leaves an artifact nothing will serve. The failure mode is lost work, never a
wrong number.

```julia
probe(id, plan) -> :hit | :partial | :claimed | :absent
#  :hit      an exec/ entry with completion.state === :complete AND admission === :ok
#            AND a seal whose ASSERTED fields match this process
#  :partial  an exec/ entry exists but is :partial or :tainted  → recompute, never serve
#  :claimed  CLAIM/ exists with no complete exec/ entry         → consult the scheduler
#  :absent   nothing
```

Three-valued at minimum is not a refinement, it is the point: a `Record` is
written at completion, so a store probe cannot otherwise distinguish *absent*
from *running*, and §2.10's more precise key produces **more** cache hits, which
makes serving a truncated artifact more likely rather than less. `:partial` is
what stops that. `git rm`-ing `queue.jl` removes the only working
"don't resubmit what is already running" guard in `src/`; `CLAIM/` plus the
surviving `find_job_by_name` replaces it. Do **not** port
`queue.jl:669-695` `_try_acquire_lock` — it is check-then-act (`isfile` then
`open`) with a comment conceding O_EXCL was rejected. The correct primitives are
already in-tree three times: `_with_catalog_lock`
(`src/workflow/io/catalog.jl:41-66`, `mkdir` + stale reclaim, comment
*"mkdir is atomic on POSIX"*), `with_entry_lock` (`queue.jl:214-260`), and the
real O_EXCL claim at `test/run_chunk.jl:41-49`. A grep gate bans
destination-derived temp names across the nine sites.

`.gitattributes` gets a union merge driver for the append-only directories; the
repo has none today.

### 2.11 The layers

| Layer | src/ path | Status | Responsibility |
|---|---|---|---|
| 0 | `src/foundation/`, `src/hamiltonian/`, `src/analysis/`, `src/solvers/`, `src/validation/` | **REPURPOSED** (+1 method per term) | physics, untouched except `physics_digest` beside `sign_oracle` |
| 1 | `src/model/{model,specs,build,canonical,toml_io,with}.jl` | **NEW** ~900 | `Model` + its 14 specs + `make_workspace(::Model)` + TOML round-trip |
| 2 | `src/model/{fingerprint,scopes,code_digest,toolchain}.jl` | **NEW** ~450 | derived identity + the partition + the three gates + `toolchain_id` (§2.10.4) |
| 3 | `src/plan/{stage,method,axis,expand,realization}.jl` | **NEW** ~630 | Stage/Method/Initial/Axis/`Realization`; type-level refusal to flatten a Chain |
| 4 | `src/store/{artifact,record,format,migrate,index,protocol}.jl` | **NEW** ~850 | sharded CAS + `record.toml` / `exec/` split + claim protocol (§2.10.8) + format-versioned readers |
| 5 | `src/run/{run_stage,dispatch,resume,job,seal}.jl` | **NEW** ~720 | execute; the `ExecutionSeal` (§2.10.5); the `@noinline @nospecialize` firewall RETAINED verbatim |
| 6 | `src/run/guards.jl` | **NEW** ~300 | the ten guards, declared once, applied unconditionally |
| 7 | `src/claims/{claim,source,target,verdict,registry}.jl` + `refs/` | **NEW** ~500 | A/B/C as types; targets measured off committed fixtures |
| 8 | `src/campaign/{lane,budget,cost,schedule}.jl` | **NEW** ~350 | lanes = tag + points cap; gates are Claim nodes |
| 9 | `campaigns/` (top level, **NOT** in the package) | **NEW** | one file per campaign; `include`d by the CLI at call time |

Deleted at layer boundaries: `src/workflow/experiments/{schema,pipeline}/`,
`inspect*`, `diff_dicts.jl`, `runfactory.jl`, `experiment*.jl`,
`autopilot/{queue,queue_toml,tick,on_complete,recipes,trust,qw_history}.jl`.
Repurposed wholesale: `autopilot/{backends,backends_uge,ssh_transport,budget,
breakers,retry,observability}.jl` — the UGE knowledge (`-g` is a CLI flag not a
directive; `$HOME` is not expanded in directives) exists nowhere else.

**Campaigns live outside the package.** `campaigns/eu_2026h2/lane_b.jl` is
`include`d by `scripts/cli.jl` at call time, so tuning a scan range does not
invalidate the SpinorBEC precompile (`src/` is 384 files / 73,786 LOC, and
`docs/guides/tsubame.md:285` already lists "~10 min before any output" as a
known precompile symptom), and ~20 concurrent worktrees do not contend on a
package source file.

### 2.12 Invariants (numbered, CLAUDE.md style)

Invariants 2, 3 and 5 are amended by §2.10; 11, 12 and 13 are new there.

1. **The resolved physics is a value.** `Model` is one concrete immutable
   struct with no free-form slot. There is no `metadata:`, no `extra::Dict`, no
   `Any` field, no `Function` field. Gated by `test_model_shape.jl`.
2. **Identity is derived, never listed.** Every artifact id comes from
   `physics_digest` over the HamTerm registry + `SCOPE_OWNERS` + input ids +
   `Realization` + `backend_kind` + `dtype` + `toolchain_id`. No hand-maintained
   key list exists anywhere. *(AMENDED: the first draft's key had three
   components; it has four, and the method half now carries the realization and
   the backend — §2.8, §2.10.3, §2.10.4.)*
3. **Inactive TERM slots are omitted.** Adding physics never invalidates work
   that did not use it. *(AMENDED: the rule is licensed by Gate A's fact that an
   inactive term contributes exactly zero, so it does NOT extend to
   `Realization`, whose fields select between two non-zero alternatives —
   §2.10.2.)*
4. **The dependency relation is the only primitive.** Cache invalidation,
   parallelism legality, gate ordering, and resume are four readings of
   `Stage.inputs`. There is no `parallel:` key and no scheduling flag.
5. **Every execution writes an `Execution` — including a cache hit.** Silence
   is never an outcome. *(AMENDED: the id-determined half, `record.toml`, is
   written once per id; the execution half is one uniquely-named append-only
   file per execution or per hit — §2.5, §2.10.8.)*
6. **A number reaches a figure or a claim only through `quote!`**, which runs
   the `:prequote` guards. Guards are scoped by a predicate on the artifact,
   never by a per-campaign list.
7. **Every guard carries a canary that must trip it.** A guard that catches
   nothing does not construct.
8. **A literature number enters only via `ref(source, quantity)`.** The value
   and the argument for it cannot separate. Published targets are MEASURED off
   a committed fixture by the same metric applied to our runs.
9. **Type-A/B/C is a type.** `ModelFidelity` cannot be constructed without a
   `Target`; B and C cannot be constructed without a breaching `control`.
10. **The inference firewall is untouched.**
    `@noinline _step_dispatch!(@nospecialize(step), …)` moves verbatim from
    `pipeline/runner.jl:244` into `src/run/dispatch.jl`, with an `@inferred`
    test on the boundary.
11. **The declaration is numerically closed.** Every number the executing kernel
    reads is a field of `Model` / `Method` / `Initial`, or a frozen `const`
    covered by a scope digest. A mutable module-level binding under
    `NUMERIC_ROOTS` — `Ref`, `Dict`, `Atomic`, or an `ENV` read — is either
    a registered cache with a declared determinant list, or it is RED. There is
    no third category, so a numeric switch cannot be declared. Gated by
    `test_no_ambient_numerics.jl` + `test_cache_key_completeness.jl` (§2.10.6),
    both canaried, the reflective arm carrying a permanent positive control.
12. **Identity addresses the plan; the seal asserts the execution.** `StageId`
    is computable before dispatch and answers *what should run*. `ExecutionSeal`
    is captured **at stage entry, in the executing process**, and answers *what
    did run*: the module the runtime loaded, the backend actually resolved, the
    ambient scan, and `declared == observed` over every `Model` field with a
    runtime counterpart. Its asserted fields **refuse the run** on mismatch;
    they are never merely recorded, and `module_build_id` — a per-build nonce —
    is never a key field (§2.10.5).
13. **A hit requires completion, not just an id.** Admissibility is a separate
    axis from identity: `run_stage!` serves an artifact only when an `exec/`
    entry reports `completion.state === :complete`, `admission === :ok`, and a
    seal whose asserted fields match this process. Absent, running, partial and
    tainted are four distinguishable states, and the store write protocol
    (§2.10.8) makes the completeness marker the last thing written.

---

## 3. Worked example — Matsui et al. 2025 Fig. 4B (type C)

This is the whole reproduction. There is no YAML.

### 3.1 The paper as a value — `refs/matsui2025.jl`

```julia
const MATSUI2025 = Source(
    id       = :matsui2025,
    title    = "Einstein-de Haas effect in a spin-6 Bose-Einstein condensate",
    doi      = "10.5281/zenodo.17303925",
    tier     = :journal,                    # printed in every report; :thesis would differ
    fixtures = ["matsui2025/dataset_fig4_theo.csv",   # moved from test/fixtures/matsui2025/,
                "matsui2025/dataset_fig4_exp.csv",    #   CC-BY-4.0, checksummed
                "matsui2025/dataset_fig2_theo.csv",
                "matsui2025/dataset_fig2_exp.csv"],
    verified = Date("2026-07-30"),
)

# ---- the numbers we INFERRED rather than read. Previously 47 lines of YAML comment. ----

reconstruct!(:matsui2025, :N_atoms, 5.0e4,
    derivation = """
        The shipped `setup_parameters` carries Ntot = 3.5e4, but the published
        Fig. 2 / Fig. 4 curves total 5.0e4. We follow the paper; the deck is a
        reduced-cost variant.""",
    alternatives = [3.5e4 => "the value shipped in setup_parameters"],
    cost = "N enters c0 linearly: 3.5e4 lowers peak density 34 %, R_TF 15 %.")

reconstruct!(:matsui2025, :q_over_h_Hz, 1.0,
    derivation = "ZeemanQ is a LITERAL input in time.f90; it is NOT derived from |B|².",
    alternatives = [:derived_from_Bsq => "our default; wrong for this target"],
    cost = "1 Hz moves the m=-6 -> -5 spacing 11 Hz of 42.3, i.e. 0.68 nT of dip position.")

reconstruct!(:matsui2025, :c1_ratio, 1//36,           # Rational. ONE spelling exists.
    derivation = """
        time.f90: cc0_eff = 0.5, cc1_eff = 50 => cc1 = cc0/36 under
        c0 + 36 c1 = 4π (a_s/a_ho) N (verified: both give c0 = 2343.63).
        initial.f90 builds its ITP with cc0_eff = 1 / cc1_eff = 0 — a DIFFERENT
        Hamiltonian. We use time.f90's.""",
    alternatives = [0//1 => "initial.f90's ITP value; yields a polarised GS"])
```

`0.00909116` is never typed. `q = freq_to_angular(ref(:matsui2025, :q_over_h_Hz),
ω_ref)` is executed. The four spellings of `c1_ratio` across 160 files
(`0.02778`, `0.0277777778`, `0.027777777777777776`, plus refinement points)
collapse to one exact rational.

Their DDI kernel is our $Q \times 4\pi$ and their `cdd` absorbs $\mu_0/4\pi$,
so only the *product* is convention-independent — which is why `c_dd` is
**built** by `eu151_c_dd()` here and never transcribed.

### 3.2 The target, measured off the fixture

```julia
const FIG4B_THEO = Target(
    id      = :matsui_fig4b_theo_dip,
    source  = :matsui2025,
    fixture = "matsui2025/dataset_fig4_theo.csv",
    metric  = resonance_dip,                # the SAME function runs on the fixture and on us
    fields  = (:center_nT, :width_nT),
    arbitrates = (:width_nT,),              # ← the centre is REPORTED, never GRADED
    tol     = RelTol(width = 0.05),
    caveats = ["""
        Their SIMULATION curve is not the reference. The experimental axis carries
        a ±10 nT offset — 3× the centre — so only the WIDTH arbitrates, and it
        points at our side: exp 12.84 nT; theirs +1.8 %, ours +14 %."""],
)
```

No number is typed here either. `-2.5495` and `15.0224` are what
`resonance_dip` **returns** applied to the committed fixture — which is exactly
what `test/validation/test_matsui_fig4_dip.jl` already does today (*"Values
recomputed from the fixture at 886d03bd"*), generalised. If Zenodo issues an
erratum, we replace one CSV and every dependent claim re-measures.

`arbitrates` is the mechanism for a target that disqualifies part of itself.
The gate ABSTAINS on the centre and prints the abstention; it does not hide it
and it does not grade it.

### 3.3 The computation — `campaigns/matsui_fig4b.jl`

```julia
function matsui_model(; n::Int, Bz, secular_ddi::Bool)
    wref = 691.1504                                        # rad/s, their omega_ref
    w    = freq_to_angular.((110.0, 110.0, 130.0), wref)   # EXECUTED, not a comment
    Model(
        grid         = GridSpec(n = (n,n,n), box = (16.0,16.0,16.0)),
        atom         = ATOM_REGISTRY[:Eu151],
        interactions = contact_from_ratio(ATOM_REGISTRY[:Eu151];
                           N_atoms   = ref(:matsui2025, :N_atoms),
                           omega_ref = wref,
                           c1_over_c0= ref(:matsui2025, :c1_ratio)),
        potential    = Harmonic(w ./ w[1]),
        zeeman       = ZeemanSpec(Bz = Bz,
                                  q  = freq_to_angular(ref(:matsui2025,:q_over_h_Hz), wref)),
        ddi          = DDISpec(c_dd = eu151_c_dd(), secular = secular_ddi,
                               padded = true, pad_factor = 2),
        lhy          = NoLHY(),                            # their model has no BMF term
        loss         = NoLoss(),                           # their L3loss = L3loss_eff = 0
    )
end

function fig4b_plan(; n = 64)
    gs  = matsui_model(; n, Bz = gauss(0.0104), secular_ddi = true)   # their ITP: spin frozen
    dyn = with(gs; ddi = with(gs.ddi; secular = false))               # full MDDI drives EdH
    Stage[
      Relax(gs;  method  = ITP(dt = 0.005, n_steps = 4000, tol = 1e-10),
                 initial = FromScratch(:spin_coherent, (m = -6, sigma = 1.5), 0)),
      Evolve(dyn; method  = Strang(dt = 0.001, duration = ms(5.0, 691.1504)),
                  initial = FromArtifact(ArtifactRef(:gs, :psi)),
                  save    = SaveSpec(every = 108, psi = false)),      # 108 | 3456 exactly
      Measure(:populations), Measure(:energy_decomposition),
    ]
end

# The B ramp and the scan point are ONE substitution: the held field is what varies.
const FIG4B_SCAN = Parallel(:Bz_target, nT.(-13.0:0.5:9.0)) do plan, B
    gs, ev, m1, m2 = plan
    ev2 = with(ev; model = with(ev.model;
              zeeman = with(ev.model.zeeman;
                  Bz = ramp(gauss(0.0104) => B, tau = us(150.0, 691.1504)))))
    Stage[gs, ev2, m1, m2]
end

const CLAIM_FIG4B = Claim(
    id        = :matsui_fig4b_dip,
    kind      = ModelFidelity(:matsui_fig4b_theo_dip),   # C — will not construct without it
    lane      = :B,
    statement = "The m=-6 -> -5 EdH resonance dip reproduces Matsui et al. Fig. 4B \
                 (their SIMULATION curve).",
    evidence  = () -> expand(fig4b_plan(n = 64), FIG4B_SCAN),   # THUNK: costs nothing at load
    verdict   = recs -> begin
        all(r -> r.scalars["converged"] == 1.0, recs) ||
            return indeterminate("unconverged cells")
        compare(resonance_dip(populations_curve(recs)), FIG4B_THEO)
    end,
    requires  = [differs_only_in(:zeeman), all_cells_present()],
    control   = mutate(:zeeman, :q => 0.0),   # q=0 MUST move the dip; else :indeterminate
    caveats   = FIG4B_THEO.caveats,
)
```

Sixty lines of reviewable Julia replacing 9 YAML files, 122 lines of comment
prose, a hand-typed `q: 0.00909116`, and a report script with no caller.

### 3.4 What the researcher types

```
$ spinorbec plan   claim=matsui_fig4b
  gs        9f2c1a7b  NEW   1 cell   ~3 min  CPU
  dynamics  ×45       NEW  45 cells  2.9 pts (2.62 ms/step × 3456 steps × 45; MEASURED
                                              N=64, 4 hosts, ±3 %, history.jsonl:812-931)
  claim     matsui_fig4b   kind C   target matsui2025/dataset_fig4_theo.csv  tier :journal
  guards    10 in scope · 0 blocking
  budget    lane B: 2.9 of 4.0 pts  OK

$ spinorbec submit claim=matsui_fig4b
  preflight: 10 guards → 10 ok. 45 independent jobs, one UGE array.

$ spinorbec claim matsui_fig4b
  C :matsui_fig4b_dip
     width   ours 14.62 nT   theirs 15.0224 nT   -2.7 %  (tol 5 %)   PASS
     centre  ours -2.138 nT  theirs -2.5495 nT   +16 %              ABSTAIN
             ("the experimental axis carries a ±10 nT offset — 3× the centre —
               so only the WIDTH arbitrates")
     control q=0 → dip absent, breach 340 %                          OK
     45/45 artifacts, 0 reused, tree 9f2a1c4 clean, LHY inactive, drift 3e-9
     VERDICT: :pass on the arbitrating field
```

### 3.5 The figure

```julia
Figure(:paper_fig4b; inputs = artifact_refs(CLAIM_FIG4B), emit = :csv_py)
```

`Figure.inputs` is typed, so **a figure that cannot name its artifacts fails to
construct**. `spinorbec trace figs/paper_fig4b.pdf` walks
figure → claim → target → `refs/matsui2025/dataset_fig4_theo.csv` → DOI, and
prints each `Reconstruction` in the chain with its derivation and quantified
cost. Emitters keep the existing CSV + companion-`.py` shape from
`src/manuscript/figures/emitters.jl` — that artifact contract is correct.

### 3.6 The three defects in this campaign the design makes unrepresentable

- **The voided GS-variant arm.** `contact_from_ratio` is a function returning
  an `InteractionSpec`; there is no layer that can silently not apply it, and
  `record.model_toml` carries the resolved $c_0$/$c_1$ in plain text. On top of
  that, `differs_only_in(:zeeman)` would have named `density_c0` as an extra
  differing slot and returned `:indeterminate`.
- **The 27 silently-untilted B fields.** `ZeemanSpec` is one struct consumed by
  one builder; there is no second spelling for a field to route to.
- **The retracted 27 ms/step.** `CostRecord` is written by the runner from
  measurement into the same record as the physics.

---

## 4. Worked example — the four-lane / two-gate campaign

### 4.1 The campaign — `campaigns/eu_2026h2/campaign.jl`

```julia
const EU_2026H2 = Campaign(
    id = :eu_2026h2, cap = points(30.0),
    lanes = [ Lane(:A, CPU(threads=8),  points(0.5)),
              Lane(:B, GPU(:h100, 1),   points(4.0)),
              Lane(:C, CPU(threads=16), points(2.0)),
              Lane(:D, GPU(:h100, 1),   points(15.0)) ],   # reserve 8.5, asserted at construction
    gates = [ gate(:G1, [:bao_cai_scalar_dipolar, :fortress_f1_f2,
                         :reference_rhs_tensor_parity,
                         :lhy_closed_forms_agree_with_full_bdg,
                         :si_roundtrip_82, :ladder_all_levels]),
              gate(:G2, [:observable_information_ranking]) ],
)
```

A **gate is not a new concept**: `gate(:G1, claims)` is a `Claim`-kind Stage
whose artifact is written **only on `:pass`**. Lane B's first stages hold
`FromArtifact(ArtifactRef(:G1, :verdict))`. A red gate therefore blocks its
lane through the same dependency relation that drives the cache — no scheduler
special case, no ordering check to forget.

Lane A and Lane C hold no ref into anything and start at $t=0$ in parallel;
the CPU/GPU split falls out.

### 4.2 Lane A item A4 — the F=6 LHY oracle, first job submitted

Five papers ride on this and it is minutes of CPU.

```julia
# campaigns/eu_2026h2/lane_a.jl
const A4 = Item(
    id = :a4_lhy_closure_oracle, lane = :A, claim = :lhy_closed_forms_agree_with_full_bdg,
    plan = () -> Stage[ Measure(:lhy_closure_compare,
                                (uv_counterterm = :subtract_epsilon_k_once,)) ],
    axes = (Parallel(:F,       [1, 2, 6])          do p,F; retune(p; F);          end,
            Parallel(:density, [0.5, 1.0, 3.0])    do p,x; retune(p; n_scale=x);  end,
            Parallel(:closure, [:icosahedral, :polar_contact, :fm_contact])
                                                   do p,k; retune(p; closure=k);  end),
)

const CLAIM_A4 = Claim(
    id   = :lhy_closed_forms_agree_with_full_bdg,
    kind = PhysicsAgreement(), lane = :A,                       # B
    statement = "On the SAME uniform state, every closed-form eps_LHY agrees with \
                 full_bdg to 1e-4 relative, at F in {1,2,6} and over three densities, \
                 with the UV counterterm subtracted in exactly ONE place.",
    evidence = () -> expand(A4.plan(), A4.axes),                # 27 cells, all independent
    verdict  = recs -> begin
        unstable = filter(r -> r.scalars["max_im_omega"] > 1e-8, recs)
        isempty(unstable) || return indeterminate(
            "full_bdg dynamically unstable in $(length(unstable))/$(length(recs)) cells; \
             eps_LHY is scheme-dependent there and a PASS would not be a claim")
        bad = filter(r -> r.scalars["rel_err"] > 1e-4, recs)
        isempty(bad) ? pass() : fail("$(length(bad)) cells outside 1e-4")
    end,
    requires = [differs_only_in(:lhy)],                          # ← closes the arm-drift class
    control  = mutate(:lhy, :uv_counterterm => Scale(2.0)),      # doubling MUST breach
)
```

Three mechanisms, not prose:

- **The `indeterminate` arm is load-bearing.** The recorded gotcha is that
  `full_bdg` LHY has **no stable point in the Eu dipolar regime** — every
  nonzero $c_{dd}$ is unstable at every $c_1$/$q$/$n$. A green there would be a
  lie, so the verdict abstains and says why.
- **"UV counterterm in ONE place" is enforced.** All arms read
  `physics_digest(::LHYTerm, …)` and mix `scope_digest(:lhy)`. Two arms with
  different counterterm code carry different scope digests, which
  `differs_only_in(:lhy)` reports as the difference it is.
- **The control is mandatory.** If doubling the counterterm does not breach
  $10^{-4}$, the verdict is `:indeterminate`, never `:pass`.

### 4.3 Lane B item B3 — the serial continuation axis

```julia
# campaigns/eu_2026h2/lane_b.jl
const B3 = Item(
    id = :b3_weakfield_gs_library, lane = :B,
    claim = :weakfield_gs_library_post_q_fix,
    after = [:G1],
    plan  = () -> eu_weakfield_gs_plan(n = 64),
    axes  = (Parallel(:kappa, [0.5, 1.0, 2.0]) do p,k; set_kappa(p,k); end,
             Parallel(:c1,    C1_GRID)         do p,c; set_c1(p,c);    end,
             Parallel(:seed,  1:4)             do p,s; set_seed(p,s);  end,
             Chain(:Bz, uG.(50.0:-2.0:0.0);
                   because = """
                     Pinned continuation. Point n is a minimisation seeded from
                     point n-1's converged psi. Cold-starting each field lands on
                     the other branch of the metastable window
                     (eu_bscan_pinned_continuation, 2026-07). The B axis is a
                     PHYSICS dependency, not a scheduling preference.""") do plan, B, prev
                 gs = plan[1]
                 Stage[ Relax(with(gs.model; zeeman = with(gs.model.zeeman; Bz = B));
                              method  = gs.method,
                              initial = prev === nothing ? gs.initial :
                                        FromArtifact(ArtifactRef(prev, :psi))),
                        plan[2:end]... ]
             end),
)
```

`expand(B3.plan(), B3.axes)` returns `Vector{ChainedPlan}` of length
$3 \times |C_1| \times 4$ — that many GPU jobs, each running a 26-link serial
B-chain. A `Chain` in a non-final axis position is an `ArgumentError` at plan
time, on the login node, in milliseconds.

### 4.4 How the system refuses to parallelise a serial axis

It does not refuse. **It cannot comply**, by three independent walls, of which
only the second is load-bearing:

1. **By type.** `schedule(::ChainedPlan) -> [Job(c)]`. No method returns a
   `Vector{Job}` from a chain; `parallelise(::ChainedPlan)` does not exist.
   Asking is a `MethodError`.
2. **By content addressing — the one that survives someone bypassing the
   scheduler.** Link $k$'s `Initial` is `FromArtifact(id_{k-1})`, so
   `stage_id(\text{link}_k).inputs = \mathrm{digest}(id_{k-1})$, so **link
   $k$'s own artifact id is not computable until link $k-1$ has run**. You
   cannot name the output directory of a continuation point you have not
   reached.
3. **By guard.** `:seeded_axis_must_be_chain` (`:block`): a stage whose
   `initial isa FromArtifact` inside a `Parallel` axis is self-contradictory by
   (2), and the guard reports it as a readable message instead of a hash
   failure.

**Are axis legality and cache invalidation the same object?**

**Yes.** Both are `Stage.inputs`. The fingerprint recursion
$\mathrm{id}(s) = H(\text{physics}, \text{method}, \{\mathrm{id}(i) : i \in
\text{inputs}(s)\})$ is simultaneously (a) the cache key, (b) the topological
order the scheduler releases work in, (c) the transitive invalidation set when
a term's code digest moves, and (d) the reason a chain link is unnameable
before its predecessor. This is the whole design in one line: there is one
relation and five readings of it.

**The honest residual.** The design cannot know that a *physically* serial axis
was written as `Parallel` with cold seeds. It makes that visible instead:
`record.model_toml` shows `initial = FromScratch`, and
`CLAIM_B3.requires = [continuation_seeded_in(:Bz)]` turns it into a **failed
precondition** rather than a silent methodology error. And `Chain`'s `because`
kwarg is REQUIRED, so flattening a continuation is a visible diff
(`FromArtifact(prev)` → `FromScratch(...)`), never an omission.

**Chain budgeting is not blind.** `preview(::ChainedPlan)` knows the chain
*length* even though it cannot know the ids: cost = `length × per-link quote`,
and it walks the store from link 1 forward reporting cache hits until the first
unresolved link. So Lane B — the expensive lane — is priced before submission,
with the unresolved tail quoted as an upper bound.

### 4.5 The ten guards, declared once

`src/run/guards.jl`. `run_guards(:preflight, job, env)` runs before dispatch,
`run_guards(:postrun, record)` after, `run_guards(:prequote, artifact, obs)`
whenever a number reaches a figure or a claim — all unconditionally. The
eleventh campaign gets all ten for free and cannot opt out, because scope lives
in `applies`, not in a config.

| # | id | phase / sev | check | canary |
|---|---|---|---|---|
| 1 | `tree_contains_fixes` | preflight `:block` | every commit in `REQUIRED_FIXES` is an ancestor of HEAD | plan at `COMMIT_BEFORE_Q_FIX` |
| 2 | `clean_tree` | preflight `:block` (remote only) | tree not dirty ⇒ the provenance stamp is meaningful | dirty fixture |
| 3 | `secular_choice_deliberate` | preflight `:block` | at $\omega_L/(c_{dd}\langle n\rangle) > 100$, secular-vs-full must be DECLARED, not defaulted | ratio 1e4, undeclared |
| 4 | `energy_drift_vs_splitting` | postrun `:error` | `ErrorBudget`: drift compared to the run's OWN accepted splitting error at that `dt`, with a halve-`dt` control that MUST move it | diverged fixture |
| 5 | `lhy_energy_not_quotable` | prequote **`:redact`** | if LHY active and $\lvert E_{LHY}\rvert/\lvert E_{tot}\rvert > 0.15$, remove `E_lhy`,`E_total` from `quotable` | `E_lhy/E_tot = 0.97` |
| 6 | `converged` | postrun `:error` | `converged == true` (ITP only — the flag means nothing else) | `converged = false` |
| 7 | `ingest_run_warnings` | postrun `:warn` | the run's own `@warn` stream lands in `record.warnings` | `"full_bdg dynamically unstable"` |
| 8 | `superfluid_needs_uniform_spin` | prequote `:redact` | `spin_direction_spread > 0.05` ⇒ redact `superfluid_fraction` | spread 0.4 |
| 9 | `spatial_lhy_residual_quoted` | prequote `:block` | `SpatialLHY` used ⇒ `spatial_lhy_residual` must be present | residual missing |
| 10 | `f32_needs_f64_parity` | prequote `:block` | an F32 artifact may not feed a figure without an F64 sibling | no sibling |
| 11 | `figure_inputs_archived` | preflight `:block` | every `Figure` input must be `archive()`d (raw `psi.bin` + shape) | unarchived input |
| 12 | `cost_estimate_measured` | preflight `:block` | a job over 1 point priced from an UNMEASURED quote is refused | 32³, unmeasured |

Two of these are direct answers to judge findings. **#4 was a hardcoded
`1e-6`**, which is either vacuous at small `dt` or a false alarm at large `dt`;
it is now a *relationship* against an already-accepted error with a positive
control, per the recorded norm "derive tolerances, gate the RELATIONSHIP".
**#5 was `:error` at 15 %**, which would fire on ¹⁵¹Eu F=6 production (LHY is
~97 % of $E_{tot}$ there) and produce a scope exemption within a week — the
exact erosion the `applies` predicate exists to prevent. It is now a redaction,
which is literally what the standing instruction *"do not quote Eu F=6 LHY
energies"* is.

The table has twelve rows because the user's list of ten plus `figure_inputs_
archived` and `cost_estimate_measured` — both of which close named rot
mechanisms — is twelve. `test/oracles/test_guard_canaries.jl` runs each
`canary` and asserts the guard trips, and each clean fixture and asserts it does
not. Canaries register with **PR #198's mutation harness** rather than
reimplementing it.

`:clean_tree` (#2) is scoped `applies = (job,env) -> is_remote(job)`. Local
`scratch` runs from a dirty worktree are legal and produce
`provenance = :scratch` artifacts, which **no Claim may cite**. This is the
concession to a normal Tuesday across ~20 worktrees; without it the guard would
be passed a flag every morning and stop being read.

### 4.6 Budget

```julia
cost_quote(:eu151_ddi_split_step, 64)   # (us_per_step=2620, n=4, spread=0.031,
                                        #  src="observability/history.jsonl:812-931")
cost_quote(:eu151_ddi_split_step, 32)   # nothing  ⇒ guard #12 BLOCKS above 1 point
best(:gpu_step_us, 128) = minimum(history(:gpu_step_us, 128))   # a FUNCTION
```

`best` as a function is a two-line deletion that makes a whole class of
instrument defect impossible: `observability/best.json` currently records
20094.6 µs for `gpu_step_us/N128` while its own `history.jsonl` holds 17170 for
the same $N$. A query cannot disagree with the data it queries.

---

## 5. How each thing is handled

### 5.1 The cache-invalidation problem (the crux)

**Derived, not listed.** `physics_id` iterates the SAME `NTuple{14,HamTerm}`
the propagator dispatches on. A term cannot exist for the physics and not for
the key. `physics_digest` is written beside `sign_oracle` in the same file, so
the identity of a computation and the sign of its physics come from one
declaration site and cannot drift apart.

**Three gates, each of which fails RED rather than merely being discouraged:**

*Gate A — coherence.* `physics_digest(term, m, ws) === nothing` **iff**
`energy_contribution(term, ψ, ws) == 0` **and** `‖apply_operator!(out, term,
ws, ψ)‖ == 0`. This is what makes `_gs_cache_key`'s ten missing keys
impossible: you do not write a key list, you write a method, and the method is
audited against the term's own energy. `test/oracles/test_fingerprint_coherence.jl`.

*Gate B — teeth (the MOVE canary), driven by `fieldnames`, not by hand.* For
every term, for every **struct field** AND every **`Model` field in the
measured read-set**, perturbing it must move `physics_id`. The `Model` half is
essential: the existing `_sign_mutant` returns `nothing` for the ten fieldless
terms (its own docstring says so), which are exactly DDI, LHY and Tensor — the
terms carrying six documented defects in 2026-07. Perturbation is generated by
`fieldnames(typeof(getfield(m, slot)))`, so omitting a field from the digest is
caught unless the field is added to the Model and the canary simultaneously.
`test/oracles/test_fingerprint_teeth.jl`.

*Gate C — completeness, by MEASUREMENT.* `make_workspace(m::Model)` is a single
choke point. Instrument it once with a `getfield`-tracking wrapper over `Model`
on the oracle fixtures and **emit the measured read-set**; assert every
declared digest is a **superset**. This turns the declaration from a promise
into a measurement, and it closes the LHY case automatically — the honest
declaration reads `interactions`, `ddi`, `zeeman`, `geometry` and `lhy`, and
nobody has to remember that. `test/oracles/test_fingerprint_readset.jl`.

**Artifact scope** is `SCOPE_OWNERS` (§2.9): a total, disjoint, repo-wide
partition of every file that can change a number, including all 24 files of
`ext/SpinorBECCUDAExt/`, `src/solvers/`, `src/analysis/`, `src/foundation/`,
`make_workspace.jl` and `units.jl`. An unclaimed numeric file is RED, so a new
kernel cannot be added outside the partition.

**A bug fix inside an existing term that changes numbers without changing
declared inputs.** That is a code change inside the term's owned scope, so
`scope_digest(slot)` moves and every artifact with that slot ACTIVE
invalidates. This is the designed behaviour and it is why the 2026-07-28
`gpu_lhy_field.jl` fix invalidates the 12 affected configs — `gpu_lhy_field.jl`
is claimed by `:lhy`.

**The residual, stated honestly.** Three cases remain:
(i) a fix in `:core` (shared math, coefficients, `make_workspace`) invalidates
*everything*, which is correct but expensive — measured 10.6 % of commits;
(ii) a fix whose numeric effect crosses a scope boundary in a way the partition
does not model;
(iii) a number that reaches the kernel without being declared at all. Case
(iii) was the audit's headline and is closed **structurally** by §2.10 — the
switch is deleted, the ban is gated, and the seal asserts at entry — except for
the four holes §2.10.6 enumerates (struct-field mutables, `task_local_storage`,
dependency-internal state, and the scope of `NUMERIC_ROOTS` itself).

Case (ii) is closed *statistically*, not structurally, by
**`spinorbec verify --sample`**: a nightly job that re-runs 1 % of artifacts
(Sumatra's `smt repeat` in this codebase's idiom, ~40 CPU minutes). A mismatch
means a code change escaped the fingerprint. This is **automatic, not a manual
`promote`** — the five-year lens correctly flagged a manual escape hatch as a
rot site.

**What the sampler may assert, corrected.** The first draft had it assert
bit-equality, which this tree cannot deliver, so the only automatic detector for
case (ii) would have been permanently red. `fft_flags = FFTW.MEASURE` is the
default at the production choke point `make_workspace.jl:72` (feeding `:171`,
`:320`, `:350`) and at `src/foundation/grid.jl:50,65`,
`src/hamiltonian/terms/ddi/convolution.jl:145`, `src/solvers/ground_state.jl:128`;
MEASURE picks its codelet sequence by timing trials at plan time, so summation
order is load-dependent. The memory record `gotcha_lbfgs_grad_floor_not_
reproducible_2026_07_29` measures a 25× spread in `grad_norm` across three runs
at one commit on one cluster. The prototype asserts the opposite
(*"`MEASURE` vs `ESTIMATE` is a planner hint; it moves timing, not numbers"*);
that claim is wrong and is superseded by §2.10.2, which makes `fft_flags` a
`Realization` field and therefore a key field.

Four consequences, all of which the sampler needs before it is a gate rather
than an alarm:

1. It compares only artifacts whose **seal repro-class fields agree**
   (`cpu_name`, `cache_flags`, `blas_threads`, `fftw_threads`, `fft_plans`,
   `device.uuid`), and returns `:indeterminate` — reusing `CheckResult`
   (`src/workflow/validation/specs.jl:33-49`) — otherwise.
2. It carries a **mandatory positive control**: perturb one coefficient by
   1e-12 and assert the sampler catches it, so "nothing mismatched" is
   distinguishable from "the sampler compared nothing". This is
   `error_budget.jl:11-42`'s discipline, which has already rejected two real
   gates.
3. It **reports its own `:indeterminate` fraction**. If most nights compare
   nothing, the gate is empty and that must be visible as a number.
4. Bit-equality is not claimed achievable, and this revision does not settle it.
   The counter-evidence cuts both ways: MEASURE and ESTIMATE were measured to
   select the *identical* plan string at 64³ on the development host, while the
   L-BFGS spread above is real on the cluster. Before pinning `ESTIMATE` and
   paying the planning cost, try the dormant `save_fftw_wisdom` /
   `load_fftw_wisdom` pair (`src/foundation/grid.jl:85-90`, exported at `:3`,
   **zero callers**) — recording and replaying the plan may make MEASURE
   reproducible without giving it up. §10.2 carries this as open.

**The ceiling, quoted whenever the cache is cited as safe:** Gates B and C run
over the oracle fixtures. A `Model` field that only changes numbers at $F=6$
with full DDI and a tabulated LHY table will not be exercised by an $F=1$
fixture. The meta-test asserts every `Model` field is *active* in at least one
fixture — that is coverage of fields, not of regimes.

**Two-sided rot alarm, shipped before anything depends on the fingerprint.**
`spinorbec invalidation-report` prints, per commit over the last 30 days, how
many stored fingerprints move. Baseline: 74.3 % of commits move zero (LEDGER's
measurement; independently reproduced at 71.9 % over
`src/{hamiltonian,foundation,solvers,analysis,validation}`). Climbing toward
90 % while physics work is visibly happening $\Rightarrow$ something numeric got
filed as non-numeric $\Rightarrow$ **silent under-invalidation**. Falling toward
40 % $\Rightarrow$ `:core` absorbed something churny $\Rightarrow$
over-invalidation. Either direction is a printed number nobody has to remember
to look for.

### 5.2 Sweeps

A sweep is `expand(plan, axes)` → `Vector{Plan}` or `ChainedPlan`. Membership
is recorded on disk: each fan writes `sweep.toml` naming its axis label, its
values, and its members' ids — closing the manifest hole left when the mutable
`Batch` type was deleted (memory explicitly forbids resurrecting `Batch`; a
static TOML is not one). `differs_only_in` reads the axis declaration, so it is
$O(1)$ per pair rather than an all-pairs `spec_diff` over the store.

### 5.3 Content addressing and code-revision binding

```
id = H( physics_id(m, ws),
        method_id(method, realization, backend_kind, dtype),
        {id(i) : i in inputs},
        toolchain_id() )
```

with `physics_id` already containing per-active-scope tree digests, `method_id`
carrying the realization and the backend (§2.10.2, §2.10.3), and `toolchain_id`
carrying the resolved dependency tree hashes and the codegen flags (§2.10.4).
`record.toml` additionally carries `env.head`, `env.dirty`, `env.julia`, `host`
and the device — as *record* fields, not key fields, because they answer "what
produced this" while the key answers "what is this". When a recorded scope
digest no longer resolves in git, `reproducible = false` becomes a **queryable
field**, replacing the date heuristic that produced "191 runs predate the q 11×
fix yet read recent".

**Correction (audit finding D4).** The first draft named
`env.manifest_project_hash` as the record field that would recover dependency
versions. It cannot. Pkg's `project_hash` is computed by `workspace_resolve_hash`
over **dep names, uuids and compat strings only** — its own comment says so —
never resolved versions, so a `Pkg.up` anywhere inside `Project.toml`'s
`CUDA = "5, 6"` leaves it bit-identical. `Manifest.toml` is git-tracked here
(`.gitignore:110-117`), so `env.head` recovers versions *if the bump is
committed*, which has happened exactly once in repo history; uncommitted, all
that survives is `env.dirty::Bool`. That field is therefore **replaced**, not
supplemented, by `toolchain_id`'s per-dependency `tree_hash` (§2.10.4).

`_canonical_bytes!` (`experiment.jl:61-111`) survives verbatim into
`src/model/canonical.jl` — its determinism across dict-iteration order, Julia
version and YAML round-trip is proven and load-bearing, including the refusal
to hash non-finite floats.

### 5.4 Resume and caching

`run_stage!` walks a job's `inputs`, probes the store by id, and skips only on
an id match **plus an admissible completion plus a matching seal** — the
three-valued probe and the full write protocol are in §2.10.8, and invariant 13
is the rule. Store layout is sharded: `store/<xx>/<id>/`, so no directory
exceeds ~256 entries at $10^5$ artifacts. **A hit writes an `Execution` with
`reused = <id>` into `hits/`**, never onto the producer's file.

**Completion is not identity, and both are required.** An interrupted dynamics
run currently returns a truncated series as a *success*:
`src/solvers/simulation/run_loops.jl:203-221` catches `InterruptException`,
snapshots, and returns **without rethrowing** (identical shape at `:51-63`), so
`run_pipeline` takes its success path. `SimulationResult`
(`src/foundation/types/integrator.jl:65-71`) has no completion field at all, so
the pipeline could not record it if it wanted to, and nothing in `src/` compares
`times[end]` against the configured duration. Under a declared-inputs key the
truncated artifact takes the full run's id, because `Strang(dt, duration)` is
the *requested* duration. The ground-state half is live in production:
`itp_loop.jl:223-233` sets `interrupted = true` and returns normally with
`converged = false`, `grep -rn interrupted src/` has zero consumers outside that
file, and the `_gs_cache_key` hit branch defaults **fail-open** at
`run_step_ground_state.jl:352` (`get(d, "converged", true)`) while the key at
`:249-272` contains `n_steps`, so a solve stopped at step 3,721 is stored as
*the* artifact for the 100,000-step solve. Three submit scripts under
`runs/eu_gs_phase_c1_B_kappa/` export `SPINORBEC_STAGE_CACHE=1`.

Three edits close it, and none of them is an identity change: add `Completion`
to `SimulationResult` and to the record (§2.5); make the two interrupt handlers
rethrow after snapshotting so `runner.jl`'s `completed = false` path fires; make
the probe fail **closed** on an absent or non-`:complete` completion. A postrun
`:block` guard `series_reached_declared_extent` gets the canary "a series
truncated by one save interval". The corresponding L-BFGS facts —
`stop_reason = :line_search_stalled`, `floor_limited`, `grad_norm` — are already
computed at `run_step_ground_state.jl:586-588` and thrown away at `:568-570`;
widening one `jldopen` block carries them into `Completion`.

`_gs_cache_key` is **deleted, not ported**. It is already the derived
fingerprint in miniature and it already has the hole: a 17-entry hand allowlist
that omits `backend` and omits `dealias` (the latter because it is a `Ref`),
guarding a directory that holds 35 ground-state configs spanning six distinct
dealias settings. Replacing the hand list with `stage_id` closes the collision
by construction — and the ψ files already in `runs/_stage/gs` need retracting in
the same session, not just the design (§9).

The date-dependent normalisation bug is
structurally gone: `calibration_history` without `target_date` resolving
against `Dates.today()` cannot exist because calibration happens in a `Model`
*builder*, whose output is the resolved value that gets hashed.

`_live_status.json` and `_exit_summary.json` are written verbatim by the new
runner. They have **ten consumers** in `src/` (autopilot monitor/tick/failure_
analysis/backends/queue, dashboard `lab_live.jl`, pipeline runner/registry) and
carry the divergence-kill and `:killed_data`/`:killed_bug` classification. This
contract is preserved, not ported.

### 5.5 TSUBAME / UGE

`UGEBackend` and `ssh_transport.jl` move over unchanged. The payload is the
**resolved `Model` TOML** plus the required tree sha — no re-composition on the
remote. The compute node **re-plans and asserts the fingerprint matches what was
shipped**, converting the recorded "a `git fetch` failure silently runs the
previous commit" trap into a hard error. `-g` stays a CLI flag; `$HOME` is not
expanded in directives; `gpu_1` MIG rejects `h_rt=12h`. These are encoded as
tests, not comments.

**That assertion is necessary and not sufficient, and the first draft treated it
as sufficient.** It compares a shipped fingerprint against a recomputed one, and
**both sides read the same disk**, so under a stale `-J` sysimage they agree
while the numbers came from the old kernel — see §2.10.5 for the mechanism and
the `loading.jl` ordering that makes it silent. The remote assertion is
therefore kept *and* the `ExecutionSeal` is required on every remote stage:
`image_agrees` puts a runtime-reported fact on one side of the comparison, and
`in_sysimage == true` refuses unless the image carries baked scope digests.
Because `scripts/build_sysimage_full.jl` bakes no stamp today, **every `-J` job
hard-errors on day one** rather than certifying the wrong commit green. Both
arming routes are live: `SPINORBEC_TSUBAME_SYSIMAGE` (`tick.jl:95`) and
`docs/guides/tsubame.md:142`, which auto-arms from the mere existence of
`spinor_sysimage.so`, and `backends_uge.jl:190-193` explicitly tells the
operator not to rebuild on `src/` changes.

### 5.6 A/B/C claim taxonomy

`ClaimKind` is a type. `ModelFidelity` cannot be constructed without a
`Target`; `Target` cannot be constructed without a committed fixture and a
metric; B and C cannot be constructed without a breaching `control`. A
meta-test cross-checks any declared `kind` against `claim_kind` derived from the
target object, so **"tests pass" can no longer be reported as "matches Klaus
2022"** — the type is a consequence of what you compared against. Verdicts are
three-valued and may abstain. Today this split has **zero enforcement** in
`src/` or `test/`; grep finds it only in three physics comments about
Bogoliubov mode type-B.

### 5.7 Figures and the manuscript registry

A `Figure` is a Stage whose `inputs::Vector{ArtifactRef}` is typed. The five
`builder = nothing` registry stubs cannot exist: their declared `data_source`
run directories (`runs/sigma_mu_scan_round5`, `runs/species_scan_round6`, …)
were never committed at any point in history, so those figures simply have no
constructible inputs and the claims they served are `Retraction`s. Emitters keep
the CSV + `.py` pair. Figure-input CSVs (kilobytes) are **committed by id**
under `refs/figures/`, retiring the `figs/**/*.csv` ignore rule that forced four
scripts to paste numeric tables into `.py` files as the last surviving copy.
`docs/manuscript/shared/figures.md` stops being a second registry (it currently
assigns *different content* to `paper1_FIG-3` and `paper3_FIG-2` than the code
does).

### 5.8 The type-stability firewall

`@noinline _step_dispatch!(@nospecialize(step), …)` moves **verbatim** from
`pipeline/runner.jl:244` to `src/run/dispatch.jl`, with an `@inferred` test on
the boundary. `Model` is non-parameterised and `test_model_shape.jl`
recursively asserts no field of `Model` or any `*Spec` is a `Dict`, an `Any`, a
`Function`, or an abstract container — which structurally kills the
closure-escape / 30-minute-JIT class that today is prevented only by
discipline. `Waveform` is a two-member concrete union, never a `Function`.

### 5.9 The 147 legacy scripts — a triage policy

| Bucket | Count | Policy |
|---|---|---|
| Hard-dead | 45 | DELETE. 26 read absent `runs/` inputs, 19 name deleted symbols (`SpinorBEC.IcosahedralMod` — `src` has 5 modules; `_grad_zeeman!` — `src` has 8 `_grad_*!`, none zeeman; `normalize_rotating!`, `make_rotating_basis_ws` — defined nowhere). `build_sysimage.jl` is in this bucket. |
| Closed-arc | 91 | ARCHIVE to `BEC-simulation-archive/scripts_2026_07_31/`, **after** header-prose harvest (§6.K). `m1_*`(31), `sprint5_*`(37), `fisher_*`(11), `m2_*`(7), `sprint4_*`(3), `m0_*`(2). |
| Promote to library | ~10 | The measurement work inside them becomes `src/` capability with gates: `eu_phase_classifier.jl`'s 9 tuned thresholds (validated 2026-07-24 on 32³ imprints — irreplaceable, currently `include`d by relative path from two scripts), `eu_ramp_common.jl`'s `spin_scalars`, `preflight_invariants.jl`'s 8 invariants (→ guards), `matsui_fig4b_report.jl`'s 3 refusals (→ guards + `Measure`), `eu_gs_library.jl`'s physics-keyed index (→ store query). |
| KEEP by name | 6 + shells | `cli.jl`; `loop/verify.jl` (its isolation from the proposer **IS** its design — promoting it into `src/` destroys the contract with the out-of-repo autoresearch harness); `build_sysimage_full.jl` + `_sysimage_precompile_full.jl` (the working pair — only touches symbols that exist); `mcp/tsubame_server.py`; `viz_style.py`; `tsubame/*.sh` (37 files — the UGE knowledge and the only `git rev-parse` provenance line in the tree). |

The gate is **not** `scripts/*.jl == [cli.jl]`. It is an explicit named
allowlist with a reason per entry, because an absolute equality test would
delete `verify.jl` and the sysimage pair on day one and would be fought and
then removed.

**The bypass gradient is addressed, not wished away.** Exploration stays legal:
`spinorbec scratch <plan.jl>` runs any Stage and writes a Record with
`provenance = :scratch`, which no Claim may cite and which prints a `[scratch]`
watermark beside every number. The four capabilities that *created*
`scripts/` — the analytic gradient (31 files), a Hessian/Lanczos, multistart-
with-argmin (`find_ground_state_multistart` exists in `src` with **zero**
callers), and a time-dependent trap (`evaluate_potential(::TimeDependentTrap,
…)` has no caller that passes `t`) — ship as day-1 library surface: `Probe`,
`Multistart`, `FromAnsatz`, `TimeDepTrap` in `PotentialSpec`. If they do not,
`scripts/` regrows and the design has failed.

---

## 6. Cutover plan

Rough sizes are LOC of new code plus days of judgement work; judgement work is
the schedule risk, not the code.

**Step 0 — close the ambient leak (~600 LOC, 2–3 days). DEPENDS ON NOTHING;
land it first and separately.** Everything in §2.10.1, §2.10.2, §2.10.6 and
§2.10.7 is a defect on `main` today, is independently landable, and needs no
part of this design: delete the eleven Refs into `GridSpec` / `Realization` /
frozen `const`s; wire `make_workspace` to read the dealias spec it is handed;
ship `test_no_ambient_numerics.jl` + `test_cache_key_completeness.jl` +
`test_numeric_deps_total.jl` with their canaries; add the one missing
`seed_device_rng!` call with its two-sided positive control; delete
`SPINORBEC_NO_AUTO_BACKEND`; rewrite `ACCURACY_KNOBS`' three `:global` entries.
*Works after:* a `k_cut` sweep is N artifacts with N different numbers rather
than N ids with identical numbers; `with_reference_accuracy` measures something;
a GPU stochastic run is reproducible from its declared seed.
*Risk:* low-medium, and localised. The only medium item is dealias, because the
psi-filter runs with DDI off while the F-filter has no workspace, so the spec
must live on both `Workspace` and `DDIParams` — mitigated by the single builder
plus the `ws.dealias === ws.ddi.dealias` assertion (§2.10.2).
*Before writing any of it,* run the cheap in-repo measurement the audit lists as
its first unknown, against `_gs_cache_key` specifically: how many of the 35
ground-state configs in `runs/eu_gs_phase_c1_B_kappa/` — six dealias settings,
ten with a `backend:` key, `SPINORBEC_STAGE_CACHE=1` in three submit scripts —
already collide under that key. That turns "the derived key would collide" from
an argument into a count, and if they do collide the ψ files in `runs/_stage/gs`
need retracting in the same session.

**Step 1 — `Model` + `make_workspace(::Model)` (~900 LOC, 3 days).**
Land the struct, the 14 specs, the pure builders, the TOML round-trip, and
`test_model_shape.jl`. Rewire the **existing** YAML pipeline so its 15 passes
*terminate in a `Model`* rather than in kwargs. One typed choke point;
strict-unknown-key rejection preserved.
*Works after:* the `theta_deg` and shallow-mixin classes are gone by
construction (the resolved Model is written to disk, so `c_total: 583` either
appears or the run fails). `Model` is testable in isolation.
*Risk:* low-medium. `yaml_to_model` is a compatibility shim written knowing it
dies at step 6 — the only shim in the plan, with a stated expiry.

**Step 2 — the fingerprint and its three gates (~400 LOC, 3 days).**
`physics_digest` on all 14 terms beside their `sign_oracle`; `SCOPE_OWNERS`;
`test_scope_partition.jl` (repo-wide, RED on any unclaimed numeric file);
`test_fingerprint_{coherence,teeth,readset}.jl`. Ship
`spinorbec invalidation-report` on day one with its measured baseline.
~~**Also in this step**, not later: fix the existing cache-HIT branch~~
**SHIPPED AHEAD OF THIS PLAN (PR #236, 2026-07-31).** The cache-HIT branch
rebuilt the workspace omitting `spinor_lhy`, `lhy_opts`, `light_shift` and
`rotating_frame_omega`, all four of which the MISS branch passes. A correct
derived key makes hits *more* frequent across configs, so turning it on before
fixing that branch would have scaled up the seventh instance of the
LHY-dropped-per-path family — which is why it was pulled out of this step and
landed first, gated by `test/workflow/test_gs_cache_hit_physics.jl` (FAST tier,
canaried: reverting the fix fails all four assertions).

A related defect found while writing that gate is **not** fixed and is live:
`_resolve_derived_params!` (`parsing_blocks.jl:249`) returns early when
`interactions` lacks `N_atoms`/`omega_ref`, and it is the only caller of
`_resolve_lhy_block!`, which writes the internal `lhy_kind` slot. So a config
using the direct `interactions: {c0, c1}` form together with an `lhy:` block
has that block silently ignored on every path. It is an eighth instance of the
same family and this design kills it structurally (§2.2: `Model` has no
resolution order to be early-returned out of), but until then it is a live
footgun.
*Works after:* "which stored results are affected by this commit" is answerable
for the first time. Ground-state reuse across configs becomes safe.
*Risk:* medium. The gates will find real drift on first run — that is the
point, but land the fixtures separately so main is not red for days.
*Depends on:* step 1 (the digest takes a `Model`).

**Step 3 — store, runner, guards, seal (~2,000 LOC, 5 days).**
`Stage`/`Method`/`Initial`/`Axis`/`ChainedPlan`; `src/store/` including the
`record.toml` / `exec/` split and the claim protocol (§2.10.8); `src/run/` with
the firewall moved verbatim and `src/run/seal.jl` (§2.10.5); `Completion`
threaded through `SimulationResult` and the two interrupt handlers (§5.4); the
twelve guards with canaries. Port ONE campaign end to end — `matsui_fig4b` —
and run it on TSUBAME.
*Works after:* chains and parallel axes are expressible and enforceable; every
run passes twelve guards; resume is by artifact id **and** completion; a stale
`-J` sysimage refuses instead of certifying itself green; two concurrent writers
at one id cannot share an inode.
*Risk:* medium-high, on two axes. The firewall must move intact or the first
sweep hangs for 30 minutes with no stack trace — port it FIRST and assert with
`@inferred`. And the seal rests on four unexported `Base` internals, so
`test_image_agreement_canary.jl` (mutate a source file under a running image,
assert `:MISMATCH`) is not optional: it is the only thing that will notice a
Julia upgrade silently degrading `image_agreement` to always-`:match`.
*Depends on:* steps 0–2.

**Step 4 — the harvest (automated, ~1 day compute, 0 judgement).** See below.
*Depends on:* nothing. **Run it early, in parallel with steps 1–3.**

**Step 5 — claims, refs, targets (~500 LOC + 4–6 days judgement).**
`Claim`/`Source`/`Target`/`Reconstruction`/`Retraction`; `refs/` with Matsui,
Klaus, Prasad, Miyazawa, Roccuzzo; move `test/fixtures/matsui2025/` to `refs/`;
convert `test_matsui_fig4_dip.jl` into the first `Target`. Triage the harvest
(step 4) into the five buckets. Seed the claim ratchet with `UNBACKED_CLAIMS` in
the shape of `test_doc_run_citations_resolve.jl` so main is not red on day one.
*Works after:* A/B/C is type-enforced; `spinorbec claim <id>` answers "is this
still true" from the store; `spinorbec trace <figure>` terminates at a DOI.
*Risk:* **highest in the plan, and it is human, not technical.** ~120 of the 429
configs carry real reconstruction reasoning. A mechanical extraction would
produce plausible-looking wrong derivations.
*Depends on:* step 4.

**Step 6 — FLAG DAY (deletion, 1 day).** See §6.2.

**Step 7 — campaign, figures, scripts purge (~350 LOC + 2 days).**
`Lane`/`Budget`/`cost_quote`; `best` becomes `minimum(history)`; delete
`observability/best.json`; `Figure` as a Stage; commit figure-input CSVs by id;
execute the §5.9 script triage.
*Works after:* the four-lane campaign schedules with enforced per-lane budgets;
"is this PNG current?" is a query.
*Risk:* low. Purely additive over a working core.

### 6.1 Knowledge migration — the mechanism

The mechanism is disposable; the knowledge is not. 4,673 lines of YAML comment
prose and 481 result summaries.

**K1 — harvest (automated, zero judgement, step 4).** A script emits, per YAML
and per script header, a committed `harvest/<path>.toml` containing: every
comment line with its line number and the key it precedes; every `metadata.*`
value; every `reference:` / `generator:` / `expected:` / `claim_type:` /
`ladder_level:` token; and the four inlined-Python numeric tables (in
`figs/dipolar_supersolid/plot_{fs_curve,period_scan}.py`,
`figs/lhy_ablation/plot_eu_edh_lhy_ablation.py`,
`docs/guides/figures/eu_aspect_design_plot.py`) extracted to CSV. **This is the
safety net: nothing is deleted before it is in a committed harvest file.**
Prerequisite: 227 of 355 run directories are wholesale gitignored by the
`runs/*_<8hex>/` rule, which takes the `config.yaml` snapshot with them —
**un-ignore and commit those configs BEFORE harvesting**, or the harvest reads
an incomplete corpus.

**K2 — triage into five buckets (human + agent, step 5).** Each harvest entry
gets exactly one bucket, and the classification is itself a committed column:

1. `DERIVATION` → a `Reconstruction` in `refs/<source>.jl` (value + derivation
   + alternatives + **quantified cost**). ~120 configs.
2. `TARGET` → a `Target` measured off a committed fixture. If no fixture
   exists, the target is `:unbacked` and enters the ratchet.
3. `CAVEAT` → `Claim.caveats`, or a `Guard` when it is a refusal (the ±10 nT
   offset ⇒ `arbitrates = (:width_nT,)`).
4. `RETRACTION` → a typed `Retraction`. This is where the in-band `CORRECTION`
   blocks go (`runs/eu_k3_lhy/LHY_full_bdg.yaml` lines 16-26 refute the same
   file's line 6) and where `runs/eu_barnett_rotfield_clean/RETRACTED.md`'s
   content model becomes a type.
5. `DISCARD` → stale/superseded/duplicated, **with a one-line reason,
   committed**.

Gate: `test_harvest_triage_complete.jl` asserts every harvest entry has a
bucket and every non-`DISCARD` entry resolves to a live object. **Flag day is
blocked on this test being green.** The `Reconstruction` constructor requires a
non-empty `cost`, so an empty reconstruction record does not validate.

**K3 — the 481 summaries.** Not migrated as a store; they are derived
artifacts. Split three ways: **re-derivable** (the spec survives → becomes a
Claim whose evidence regenerates), **regenerate-or-retract** (the run dir is
gone), **retract** (43 of 70 cited dirs absent; 27 never committed at any point
— these are retractions by construction). A `Claim` stores its measured value
and verdict, so a claim outlives its artifact.

**Knowingly abandoned.** (a) The **executability** of the 429 YAMLs — the
content survives as typed records, but re-running a legacy config requires
checking out the pre-flag-day commit. (b) The 45 free-form `metadata:` keys
**as a key space** — the content migrates, the slot is deleted so a 46th cannot
accrete. (c) The terminal-scroll numbers of the 86 artifact-less scripts —
their *reasoning* is harvested from headers; their *numbers* were never
recoverable and pretending otherwise would be the overstatement this project
has already been called out for.

### 6.2 The point of no return

**Step 6.** One commit:

```
git rm -r src/workflow/experiments/ src/workflow/experiment{,_collections,_observables}.jl
git rm     src/analysis/sweep_viewspec.jl AGENTS.md observability/best.json
git rm -r  src/workflow/autopilot/{queue,queue_toml,tick,on_complete,recipes,trust,qw_history}.jl
git rm     runs/**/*.yaml            # all 429
git rm     <the 45 hard-dead scripts>
```

After this, the old system is dead. Five things must be true before crossing:

1. **`test_harvest_triage_complete.jl` is green** — every one of the 4,673
   comment lines is bucketed and every non-`DISCARD` bucket resolves.
2. **≥15 paired equivalence runs are recorded** in `etc/equivalences.toml`:
   for each ported campaign, both arms ran once and the artifact digests are
   bit-identical, with the executed evidence committed. This is the price of
   the flag day and it is ~0.3 points of GPU.
3. **The five orphaned oracle gates are re-homed and green.** They currently
   read the artifacts being deleted:
   `test_lhy_config_validity_domain.jl` (roots at `runs/`, asserts
   `!isempty(cells)`) → iterates every `Model` a campaign builds;
   `test_config_zeeman_seed_agreement.jl` (asserts `isdir(root)` and
   `n_checked > 0`) → same;
   `test_path_coverage.jl` and `test_lhy_mode_face_coverage.jl` (drive off
   `LHY_SCHEMA["kind"].enum`) → drive off the `LHYSpec` kind tuple;
   `test_spin_chain_fusion_parity.jl` (pins the `run_yaml` RTP chain shape) →
   pins `run_stage!(::Evolve, …)`.
4. **The `_live_status.json` / `_exit_summary.json` contract is written by the
   new runner** and its ten consumers are green.
5. **The 227 gitignored run directories' `config.yaml` snapshots are committed**
   (K1 prerequisite).
6. **Step 0 is green.** `git rm -r src/workflow/experiments/` deletes
   `runtime/dealias_block.jl`, the only writer of `DEALIAS_2_3_ENABLED` /
   `DEALIAS_K_CUTOFF` anywhere in `src/`. If the Refs still exist when that
   commit lands, the 75 configs carrying a `dealias:` block lose their setting
   silently and every one of them runs unfiltered — a wrong number, not a
   failure. So `test_no_ambient_numerics.jl` must be green and
   `make_workspace(m::Model)` must be reading `m.grid.dealias_*` **before** flag
   day, not as part of it. This is the one ordering constraint in the plan that
   produces a silent wrong answer if violated.

---

## 7. The five-year durability argument

### 7.1 Physics drift

**A new HamTerm touches SIX files, five of them gated:**

| # | File | Gate if omitted |
|---|---|---|
| 1 | `src/hamiltonian/terms/<new>/` — struct, sign coefficient, three faces, `sign_oracle`, **`physics_digest`** (all in one declaration block) | `physics_digest` has no fallback ⇒ MethodError at plan time |
| 2 | `src/hamiltonian.jl` include | compile error |
| 3 | `registry.jl` — `H_TERMS_CANONICAL_ORDER` + `build_h_terms_registry` | `test_registry_completeness.jl` RED |
| 4 | `src/model/model.jl` — ONE field, only if it needs new inputs | `test_fingerprint_readset.jl` RED (measured read-set ⊄ declared) |
| 5 | `src/model/scopes.jl` — one `SCOPE_OWNERS` entry | `test_scope_partition.jl` RED (unclaimed file) |
| 6 | `test/oracles/test_hamiltonian_sign_oracles.jl` — directional test | existing meta-test |

**Zero schema files. Zero YAML documentation. Zero cache-key allowlist. Zero
analyzer registration.** Compare today: the same term ALSO needs a schema
entry, an `auto_defaults` entry, a `parsing_blocks` branch, an `inspect`
predicate, a `_gs_cache_key` line and a docs update — six more files, none of
them gated. And adding slot #15 invalidates **zero** existing artifacts,
because inactive slots are omitted.

**And the term may not bring a knob with it.** The historical shape is that a
new term ships with a module-level `Ref` to switch its own fast path on and off
— that is where nine of the eleven in §2.10.1 came from. Invariant 11 forbids
it: the switch is a field of the term's spec (physics), a field of
`Realization` (realization), or a frozen `const` (neither), and
`test_no_ambient_numerics.jl` is RED otherwise. This is the one gate in the list
that fires on a file the author did not think of as identity-relevant.

- **A new atom** is one entry in `ATOM_REGISTRY` (`atoms.jl:339`). Zero model
  files, because `atom::AtomSpecies` is a value, not a string enum.
- **A new solver** is one `Method` subtype plus one `run_stage!` method. This
  is precisely why TDHFB has no pipeline integration today — `kind:` is an
  11-edit-site string enum — and would have one here:
  `Evolve(model; method = TDHFB(dt, duration, picard))`. That is the concrete
  demonstration that the extension point is real, not asserted.
- **A new observable** is one `Measure` probe with a `reads` declaration.

There is no schema to rewrite because **there is no schema**: there are typed
structs, and the type is the schema, checked by the compiler.

### 7.2 Format drift

Three formats, three lifetimes.

- **(a) The spec on disk is TOML.** `record.model_toml` holds the *resolved*
  `Model` verbatim, so what a run actually computed is readable with `cat`
  using a Julia-stdlib parser and no SpinorBEC.
- **(b) `Record` and `Execution` each carry `format::Int`** (4 — the seal and
  the record/execution split are a schema change, so 3 never ships) and readers
  dispatch on it (`read_record(::Val{4}, …)`, `read_exec(::Val{4}, …)`). Each
  historical version keeps a reader plus a **committed micro-fixture** (~50 KB),
  and `test_record_format_readers.jl` asserts every version from 1 to N has
  both. Migrations are pure functions in `src/store/migrate.jl` and are a chain,
  not a fork: `migrate(::Val{n}, ::Val{n+1})` must exist for every gap. The
  existing `open_result.jl` — which already degrades gracefully across four
  legacy jld2 layouts — becomes the `format < 4` reader, so months of legacy
  data stay readable at zero design cost.
- **(c) Arrays stay in JLD2 for working use.** `archive(artifact)`
  additionally emits `psi.bin` plus a shape/dtype/endianness declaration in the
  record, readable by numpy/C/Julia forever. `archive()` is **not** a
  convention: guard #11 `figure_inputs_archived` is a `:block` preflight with a
  canary, so a figure whose inputs are unarchived does not submit.

**A result whose producing code no longer exists** is still *interpretable*:
the record holds the resolved Model as text, the active-scope digests, the tree
sha, the environment, the guard results, the warnings and the claim it
supported. And it is **marked**: when a recorded digest no longer resolves in
git, `reproducible = false` is a queryable field, `provenance` becomes
`:archival`, and such an artifact may not serve as a type-C claim's evidence
without an explicit `archival_ok` acknowledgement. The honest boundary is
stated in the record rather than inferred from a date — which is exactly what
the "191 runs predate the q 11× fix yet read recent" incident cost.

### 7.3 Personnel drift

**The ONE document a successor reads is `campaigns/<active>/campaign.jl`** —
the campaign charter as an *executable value*. It names the lanes, the gates,
the claims, the budget and the items, and every entry is a symbol they can jump
to.

**The mechanism that keeps it true is that it is the scheduler's input.**
`spinorbec campaign <id>` prints live lane status, realised-vs-capped budget,
gate state and every claim's verdict — read from the store, not from prose. If
the charter is wrong, the campaign does not run, does not price, or does not
pass its gates. A prose charter can drift for months; this one cannot drift for
one submission. `docs/reference/architecture.md` rotted into nine dead source
paths precisely because nothing executes it.

This **complements PR #200** rather than competing: the charter PR supplies the
per-session prose *why*; this file is the executable *what*. A bidirectional
ratchet (`test_charter_campaign_agree.jl`, the same shape as the existing
doc-citation ratchet) asserts the charter names every lane in the campaign file
and vice versa.

Beneath it, seven concepts, each with a `SpinorBEC.explain(x)` method printing
the value's provenance and the guards that apply to it. Everything a newcomer
needs to know about what a stored number means is inside its own `record.toml`,
in plain text, including which paper it claimed to reproduce.

**For AI agents specifically:** `GUARDS`, `CLAIMS`, `SCOPE_OWNERS` and
`H_TERMS_CANONICAL_ORDER` are four enumerable consts, so "what can this system
do, what does it assert, what will it refuse" is four `keys()` calls rather
than a grep across 429 YAMLs, 68 ENV knobs and 147 scripts.

### 7.4 Scale drift

At 5–10× (≈4,000 plans, ≈700 store dirs) nothing in the hot path scans
everything. Three places checked:

1. **Directory fanout** — sharded `store/<xx>/<id>/`, so no directory exceeds
   ~256 entries at $10^5$ artifacts. Git-proven shape.
2. **Index** — records append to `store/index.jsonl`, read once into memory for
   query: $O(N)$ to load, $O(1)$ to query, rebuildable and safe to delete.
   Following this project's own recorded catalog principle, a real database
   graduates only past ~$10^4$ rows. **No new dependency now.**
3. **Scheduling** — the scheduler holds only the *frontier* (stages whose
   inputs are all satisfied), which for the four-lane campaign is ≤ 64 entries.
   A 4,000-node global queue never exists. `Guard.check` is typed
   `(::Job)->GuardResult` / `(::Record)->GuardResult` with **no store handle in
   the signature**, so a guard structurally cannot scan the store — the obvious
   way this would have gone $O(N)$ per submission.

**Named superlinear risks and their ceilings.** (i) The **claim gate suite**:
100 claims each wanting a re-derivation is unaffordable, so it is split by
cost — claim verdicts run against STORED artifacts on every PR (seconds), while
re-derivation is the nightly stratified 1 % sample. (ii) **UGE array shape**: a
4,000-task level against the 300 s billing floor is charged as 4,000 × 300 s;
the cost model must batch cheap nodes into array tasks. Specified, not
measured. (iii) The fingerprint gates are $O(\#\text{Model fields} \times
\#\text{fixtures})$ — constant in campaign size, which is the point of gating
the mechanism rather than the instances.

### 7.5 Anti-accretion — the most important subsection

The current design died because a general mechanism absorbed per-campaign
special cases: 45 ad-hoc `metadata:` keys, `sweep_viewspec.jl` at 1,574 LOC
(1,480 of them in ONE function with 17 nested closures, zero tests, zero
committed `viewspec.json`), and 147 bypassing scripts. Six gates, each of which
makes the recurrence fail RED rather than be discouraged.

**G1 — `Model` has no free-form slot.** `test_model_shape.jl` recursively
asserts that no field of `Model` or of any `*Spec` is a `Dict`, an `Any`, or a
`Function`. The 45 metadata keys accreted precisely because `schema.jl:402`
declared a slot to be ignored; delete the slot and the accretion has nowhere to
land. The `Function` clause additionally kills the closure-escape / 30-minute-
JIT class that today is prevented only by discipline.

**G2 — field-count ratchet.** `test_model_shape.jl` also asserts
$\sum_{\text{spec}} \#\text{fields}$ against a committed integer. Raising it is
a visible diff in the PR, reviewed like a schema change. Today's count is 14
top-level fields; the alarm threshold is stated (§7.6). This is the gate the
winner's own risk list admitted "accepts growth, it only makes it visible" —
making it *visible in a diff that must be approved* is the difference between a
metric and a gate.

**G3 — the scope partition is total.** `test_scope_partition.jl` asserts every
`.jl` under `NUMERIC_ROOTS` is claimed by exactly one scope, **and** that the
non-numeric allowlist has not grown. Adding a numeric file that nothing claims
is RED; moving one into `src/workflow/` to escape is also RED. This
mechanically enforces CLAUDE.md naming convention #9 (file name = primary
export) for the first time — today it is discipline only.

**G4 — presentation cannot reach physics, by type.** Analyzers, figures,
labels and notes live in `Measure`/`Figure`/`Claim`, whose types cannot be
constructed into a `Model` and therefore cannot enter `physics_id`.
`sweep_viewspec` grew where presentation and physics shared one `Dict`; here
they share nothing.

**G5 — campaign isolation, diffed by SIGNATURE not by count.**
`test_campaign_isolation.jl` includes each `campaigns/**/*.jl` into a fresh
module and diffs the **method tables** — the set of `(function, signature)`
pairs on SpinorBEC-owned functions — before and after. A method-*count* diff
misses the headline case (a campaign defining `SpinorBEC.to_viewspec(::Model)`
replaces the identical signature and leaves the count unchanged); a
signature-set diff catches it. So the dispatch-table-grows-per-campaign shape is
unavailable, and a campaign-specific need must become a typed field, which trips
G1/G2's review.

**G6 — every guard and every claim must have teeth.** `Guard`'s inner
constructor requires a `canary`; `test_guard_canaries.jl` runs each and asserts
the guard trips on it and does not trip on a clean fixture. `Claim`'s inner
constructor requires a breaching `control` for kinds B and C, and a control
that does not breach yields `:indeterminate`. **A gate that catches nothing does
not construct.** Both register with PR #198's mutation harness rather than
duplicating it — the judge of whether a gate has teeth is the harness the
project is already building.

Plus one boring gate that would alone have stopped `sweep_viewspec.jl`: **no
file under `src/{model,plan,store,run,claims,campaign}/` exceeds 400 lines.**
The five inference builders would have had to become five files, at which point
their zero test coverage would have been visible at review.

**What none of this stops**: someone writing a 399-line file badly. The gates
constrain the *shape of the vocabulary*, not the quality of any single
implementation.

### 7.6 Load-bearing concept count

Seven (§2.1): `Model`, `Stage`, `Axis`, `Artifact`/`Record`, `Guard`, `Claim`,
`Campaign`. `Source`/`Target`/`Reconstruction`/`Retraction` are four *record*
types a user reads and writes in `refs/`, counted under `Claim`;
`Method`/`Initial`/`ArtifactRef` are the vocabulary *inside* `Stage`.

This is an honest count of what must be held to *use* the system, and it is the
budget: if a proposed addition would make it eight, the correct move is to
express it inside an existing concept or not at all.

**Alarm thresholds, published nightly alongside the invalidation report:**
`Model` top-level field count > 20 (today 14) ⇒ nest by subsystem rather than
relax G2. Any single `campaigns/**` file > 300 LOC ⇒ a library gap wearing a
campaign costume. `SCOPE_OWNERS` entries > 30, or any entry spanning more than
one `src/` top-level directory (other than the declared `:core`) ⇒ the
partition has coarsened toward a commit hash.

### 7.7 Expected failure mode

**It rots first at the scope partition**, because that is the one place where a
text convention (file paths) carries semantic weight, and the tree WILL
reorganise — the 2026-06-06 `interactions/` + `potentials/` → `terms/` merge is
proof it happens roughly annually. When a file moves to a path no scope claims,
the gate must fail-open (a code change silently escapes the fingerprint — the
worst class) or fail-closed. **It fails CLOSED**: an unclaimed numeric file
blocks the PR. So the rot manifests as *friction*, not corruption, and the
predictable response is someone adding a blanket mapping like
`"src/**" => :core` to unblock themselves — which collapses granularity back
toward whole-commit hashing.

**Three early-warning signals, all counts, none requiring judgement:**

1. **`spinorbec invalidation-report`**, two-sided (§5.1). Climbing toward 90 %
   ⇒ under-invalidation. Falling toward 40 % ⇒ `:core` absorbed something
   churny.
2. **`SCOPE_OWNERS` entry count and span** (§7.6). A blanket mapping shows up
   here immediately.
3. **Store cache-hit rate and mean fingerprint fan-in** (average number of
   `Model` fields a `Measure` declares). A rising fan-in with a falling hit rate
   is the secondary rot signature — an analyzer author unsure which fields
   matter declares `(:psi, :model)` because that is always safe, and cache
   resolution erodes silently. It shows up months before anyone feels it as
   cost.

A secondary rot site: `spinorbec scratch` becoming the new `scripts/`. The
countermeasure is weak by construction — a `[scratch]` watermark on every
printed number and the inability of a Claim to cite one. I do not have a strong
one, and I say so.

---

## 8. What gets deleted

Backward compatibility is not required. Justification below is for what is
KEPT, not for what is cut.

| Target | LOC | Evidence it is safe |
|---|---|---|
| `src/workflow/experiments/schema/` | 2,882 | 67 of 141 keys in zero configs; 3 `light_shift` keys guaranteed to throw; `B.sources` implemented and unreachable; one flat GS/DYNAMICS schema validating steps whose handlers read disjoint subsets. Replaced by 14 concrete structs whose fields ARE what is read. |
| `src/workflow/experiments/pipeline/` | 3,856 | The 15-pass in-place rewrite, three divergent normalisations (one throws on 75 of 429 configs), the `theta_deg` dead path, the shallow mixin merge, `run_step_rotating/` (796 — its engine was retired 2026-06-21 and it drops `dynamics.B` 51× across 18 configs), `run_step_binary.jl` (182 — `kind: binary` appears in **0** of 429 configs while costing 2 of 7 `PipelineStep` types). The `@noinline @nospecialize` firewall is lifted out FIRST. |
| `inspect.jl` + `inspect_batch.jl` + `inspect_checks.jl` + `diff_dicts.jl` | 1,545 | A detective layer whose stated job is finding the drops its own normaliser causes, and which is **switched off on the production path** (`audit_loaded_data(data)` with no `raw` ⇒ `_check_input_resolved_drop` returns immediately). With one typed parse there are no drops to detect. The 4-severity ladder survives as `Guard.severity`. |
| `runfactory.jl` | 294 | **Zero call sites** in `src/`, `test/`, `scripts/`, `bench/` — verified — while CLAUDE.md claims sweeps and tests use it. Its exports occupy the generic names `config`, `B`, `save`, `analyze`, `ddi`, `loss`, `rate` in the SpinorBEC namespace for a DSL nobody calls. |
| `experiment.jl` + `experiment_collections.jl` + `experiment_observables.jl` | 921 | `CASStore` has produced **zero** 16-hex directories machine-wide; `status(exp)`'s `:stale` verdict compares mtimes satisfied by construction. `_canonical_bytes!` (61-111) and the observable *families* survive, moved. |
| `_gs_cache_key` + `_stage_cache_enabled` + `"v" => 1` + `scripts/backfill_gs_stage.jl` | ~120 | A 17-key allowlist omitting 10 parameters the same function passes to the solver; its own test certifies the hazard. Guards a store of size **1** (one stage artifact exists on the whole machine against ~1,563 payloads). |
| `src/analysis/sweep_viewspec.jl` (the five relation builders) | ~1,000 of 1,574 | Zero test references, zero committed `viewspec.json`, one producer script, and a React consumer whose empty state tells you to go run that script. The heatmap core (79-630) stays — `ext/SpinorBECMakieExt/sweep.jl` uses it. |
| `autopilot/{queue,queue_toml,tick,on_complete,recipes,trust,qw_history,profile_recommend}.jl` | ~2,500 | The queue IS the frontier of the graph; recipe lineage IS an edge. `backends*.jl`, `ssh_transport.jl`, `breakers.jl`, `budget.jl`, `retry.jl`, `observability.jl` are KEPT verbatim — the UGE knowledge exists nowhere else. |
| `runs/*.yaml` | 429 files, 29,449 lines | AFTER K1+K2. `metadata:` is declared ignored at runtime and has zero readers; all 22 cited `generator:` scripts were deleted in `3be5146d`; 104 of 151 doc-cited `runs/` paths do not exist. |
| `scripts/` — 45 hard-dead + 91 archived | ~20,000 | §5.9. Verified: `SpinorBEC.IcosahedralMod` (src defines 5 modules, none of them that), `_grad_zeeman!` (src defines 10 `_grad_*!`; `_grad_zeeman!` appears **only in a comment** at `solvers/lbfgs/energy_gradient.jl:120`), `normalize_rotating!` / `make_rotating_basis_ws` (defined nowhere in `src/` or `ext/` — this is why `build_sysimage.jl` is broken). |
| `observability/best.json` | 1 file | Records 20094.6 µs for `gpu_step_us/N128` while its own `history.jsonl` holds 17170 for the same $N$. `best(w,n) = minimum(history(w,n))` cannot disagree with its own history. |
| `AGENTS.md` | 138 lines | CLAUDE.md labels it a stale fork. Verified wrong on four counts: cites `src/rotating_basis.jl` and `hamiltonian/{interactions,potentials}/` (all absent), `TwoChannelLHY` and `apply_nematic_step!` (0 hits in `src/`), a `SlurmBackend` that never existed, and `full` as the default test tier. Replace with a one-line pointer. |
| `.gitignore` `runs/*_[0-9a-f]{8}/` + `runs/<16hex>/` + `figs/**/*.csv` | 4 rules | These ignore the run directory **including the `config.yaml` snapshot written into it** — the mechanical cause of 27 cited directories never committed at any point in history, and of four `.py` files holding pasted numeric tables as the last surviving copy. New rules: commit `record.toml` and figure-input CSVs (KB); ignore `*.jld2` (GB). |
| `templates` mechanism (`templates_block.jl`, partial) | ~60 of 146 | `__init_templates__()` registers nothing, `register_template!` has no callers, 0 of 429 configs use `template:`. The mixin half is used by 106 configs and its *content* migrates. |
| `euv3_coils.jl` | 83 | No consumer inside the layer it is filed under; zero `euv3` hits in `runs/`. |

**Total removed: ~34,000 LOC of `src/` + `scripts/`** plus 429 YAML files,
against ~4,400 LOC of new `src/`. `src/workflow/` goes from 31,636 to roughly
9,000.

---

## 9. Costs, risks, and what gets worse

**A flag day, and the judgement work is the schedule.** The mechanical part is
a week. Extracting physics intent from 4,673 lines of YAML prose and 86
artifact-less script headers is 4–6 focused days of judgement, deciding which
comment is a live derivation, which is a stale correction, and which is a
refutation of the same file's line 6. **If that is skipped or rushed, the
design ships with the knowledge lost and the mechanism intact — the worst
outcome available**, and it is the one thing the user named as unacceptable.
K1's committed harvest is the safety net; K2's gate is the enforcement.

**Hand-editing a config goes away.** A collaborator opens a Julia file instead
of a YAML. The resolved TOML *is* editable and will run, but editing it loses
every derivation (the `q` recomputation, the unit conversion, the
$c_0 + 36c_1$ constraint). The ergonomic path for anyone not comfortable in
Julia is genuinely worse, and that cost is paid by exactly the people who did
not write the code. **Accepted**, and mitigated only by campaigns living
outside the package (no recompile, no worktree contention).

**The existing store is 100 % invalidated on day one.** Nothing cache-hits.
This is not a regression of anything real (481 summaries, 0 reproducible), but
the first week after cutover is a full recompute of anything that must be
quoted. Legacy artifacts may be **ingested** as `:archival` — readable and
quotable with a vintage stamp, never a cache hit, never a type-C claim's
evidence without acknowledgement. Ingesting is a per-artifact judgement call.

**`:core` over-invalidates, measured.** 10.6 % of commits (205/1,933 over 120
days) touch shared math / coefficients / integrator and invalidate every
artifact. Chosen deliberately: a stale artifact is a wrong paper, a recomputed
one is GPU-hours. `contact/contact.jl` holding three slots means slot-GROUP
granularity there — a `tensor_interaction.jl` edit invalidates every
$c_0$/$c_1$ run. **Accepted and quoted**, rather than advertised away.

**The invalidation oracle proves an implication on fixtures, not universally**
(§5.1 ceiling). The 1 % nightly recheck is the statistical backstop; if it is
skipped for a quarter, the design's honesty about its residual class becomes a
claim rather than a measurement.

**More gates means more red.** Twelve guards on every run, four new
fingerprint/partition meta-tests, three new ambient/toolchain meta-tests
(§2.10.6), per-guard canaries, per-claim controls. Main will be red more often
than today's arrangement, which is quiet because it checks little. That is the
intended trade and it will still be annoying.

**What §2.10 costs, itemised.** The Ref deletion is ~600 LOC across ~25 files —
68 read+write sites in `src/` + `ext/`, 89 write sites in `test/` + `bench/`,
measured — of which `test/test_dealias_2_3.jl` (455 lines, ~35 direct Ref
references) is the single biggest item. Every value is `Bool` / `Float64` /
`Int` / `UInt32`, adding **zero** type parameters, so there is no measured
hot-loop or JIT cost and this is a correctness change with a bounded refactor
bill, not a speed-versus-safety trade. `src/workflow/validation/accuracy_knobs.jl`
(231 lines) plus its two test files need a real rewrite, because its three
`:global` entries are getter/setter closures over Refs that no longer exist —
that work is not optional and was not in the first draft's budget. The gates,
the seal and the canaries are ~450 LOC. The `record.toml` / `exec/` split and
the claim protocol add ~250 LOC over the first draft's store. Runtime cost is
~554 ms cold and ~26 ms warm per stage, against a ~20 s package load.

**A more precise key invalidates more, on purpose.** `toolchain_id` means a
`Pkg.up` of CUDA invalidates every GPU artifact — roughly one mass invalidation
per year, calibrated against `Manifest.toml` having been committed exactly once
in repo history. `backend_kind` in the key doubles the store for any config that
runs both arms; measured, ten configs in one campaign directory carry a
`backend:` key, so the actual duplication is small and it is the entire point.
`Realization` canonicalising all four fields (§2.10.2) means adding a fifth
switch in 2029 invalidates everything. Each of these is the correct direction
and each of them will look like an over-reaction the first time it fires.

**The store must be retracted, not just re-keyed.** `runs/_stage/gs` was written
under `_gs_cache_key`, which omits `backend` and `dealias`, in a campaign
directory holding 35 configs across six dealias settings with
`SPINORBEC_STAGE_CACHE=1` live in three submit scripts. Those ψ files are
suspect *today*, independently of whether this design ships. Retiring them
belongs to the session that discovers it.

**The seal is coupled to Julia internals, and that coupling is permanent.**
`module_build_id`, `in_sysimage`, `find_all_in_cache_path` and `stale_cachefile`
are all unexported, and `stale_cachefile`'s contract (returns `true` for stale,
otherwise a tuple whose third element is the build id) is undocumented and lives
in one of the most-churned files in `Base`. A shape change errors loudly; a
semantic change degrades the check to always-`:match`, which is the silent
direction. The canary is the whole defence and it must run in CI, not once by
hand in a scratchpad.

**Some findings are made worse before they are made better.** A more precise key
produces more cache hits, and until `Completion` lands (§5.4) a truncated
artifact is served on every one of them. Land the probe's fail-closed default in
the same step as the key, or the key is a regression.

**Six concepts is more than one Dict.** Seven, honestly. Day-1 onboarding is
steeper. The bet is that day-30 is much shallower: seven things instead of 141
schema keys, 45 metadata keys, 68 ENV knobs, 38 analyzers and three
normalisation sequences that disagree.

**Chains serialise work that is sometimes parallelisable.** If a B-scan happens
to converge from cold seeds, `Chain` forces it serial anyway. Under-
parallelising is the safe direction; the escape is to declare `Parallel` and own
the resulting physics claim, which then fails its `continuation_seeded_in`
precondition rather than passing silently.

**`spinorbec scratch` will be used, and may become the new `scripts/`.** The
countermeasure — a `[scratch]` watermark and the inability of a Claim to cite
one — is weak. I do not have a strong one.

**`plan()` builds a probe workspace, and that cost is unmeasured.**
`physics_digest` reads `ws`, so computing an id costs a `make_workspace` call —
which for `lhy = :full_bdg` builds a table (~0.41 s) and for `:spatial` runs
~12 BdG solves, and allocates $\psi$ ($13 \times 128^3$ ComplexF64 $\approx$ 350
MB). **This is the single technical assumption I would measure first, in step
2, before committing to step 3.** Two mitigations exist if it is too slow:
`fft_flags=ESTIMATE` + one process per campaign, and — if that is not enough —
digesting the LHY *table specification* (kind + knots + $n_{max}$ + the inputs
that determine it) rather than the built table. That fallback weakens the
"hash the table, not the kind" guarantee to "hash everything that determines the
table", which is strictly weaker but still catches the 2026-07-28 class,
because the GPU defect changed the *propagator*, not the table — and that lives
in `ext/.../gpu_lhy_field.jl`, which is in `:lhy`'s scope.

---

## 10. Decisions taken, and what is still open

### 10.1 Decided (anko, 2026-07-31)

**D1 — Campaign location: `campaigns/` at the repo top level, outside the
package.** Tuning a scan range is the highest-frequency action and must not
invalidate the SpinorBEC `.ji` across ~20 worktrees. The lost static check is
recovered by `spinorbec plan`, which runs the campaign as a pure function
without executing physics. This is also the only shape in which the
anti-accretion gate G5 means anything: campaign isolation is diffed as a set of
method *signatures*, which requires campaigns to be a distinct compilation
input rather than more files inside `src/`.

**D2 — The B3 library is a `Chain` over the B axis.** 26 serial links per
(κ, c₁, seed) cell. The recorded evidence is that cold starts land on the other
branch of the metastable window, so a `Parallel` arm would be fast and would
not be a continuation claim. The wall-clock cost is real and accepted; the
claim is the deliverable. Consequence to design for: a failed middle link
leaves every later link unnameable, so `Chain` needs an explicit resume-from
-link path (§5.4).

**D3 — Orphaned configs: regenerate ~30, retract the rest.** The ~30 whose
specs survive and are cheap to re-run migrate their `Reconstruction`s and are
marked `:unbacked` pending regeneration; the remainder — in particular the 27
directories never committed at any point in history, which are retractions by
construction — get a typed `Retraction` immediately. The per-claim split is
decided in K2, not in advance.

**D4 — Serial axes are enforced by type, not convention.** `Chain` link *k*'s
identity contains link *k−1*'s, so *k* cannot be named until *k−1* exists.
Parallelising a continuation is not forbidden, it is unrepresentable. This is
the same dependency relation as the cache fingerprint (§5.1) — one object, read
two ways.

### 10.2 Still open

1. **Legacy artifact ingestion.** *(a)* Ingest everything readable as
   `:archival` (quotable with a vintage stamp, never cache-hit). *(b)* Ingest
   nothing; the store starts empty.
   **Recommend (a)**, because 297 of 653 payloads carry an `env` group and are
   at least *dateable*, and a marked-archival number is strictly better than a
   number in a Slack scroll. But (a) costs a backfill pass and a judgement call
   per artifact, and (b) is defensible given 481/0.

2. **Whether `Method`/`Initial` stay open.** *(a)* Open abstract types with a
   whitelisted `run_stage!` extension point that G5 permits for
   campaign-local subtypes. *(b)* Closed unions; every new capability is a
   gated library PR.
   **Recommend (a).** (b) is cleaner and is what the winner proposed, but the
   measured fact is that 145 of 147 scripts exist because the spec layer could
   not express what they needed; a closed union reproduces that pressure
   exactly, and the escape hatch (`make_workspace` in the REPL) stays five
   lines away either way.

3. **The 1 % nightly recheck budget.** *(a)* 1 % of artifacts, ~40 CPU-minutes
   nightly. *(b)* A fixed stratified set of ~20 canonical artifacts, cheaper
   and deterministic but blind to whatever is not in the set.
   **Recommend (a)** — it is the only automatic detector for a code change
   escaping the fingerprint, and the alternative's blind spot is exactly where
   novel physics lives. Note this is now conditional on §5.1's four corrections:
   without a repro-class filter, an `:indeterminate` verdict, a positive control
   and a published `:indeterminate` fraction, (a) is a permanently-red alarm
   rather than a detector.

4. **Is bit-equality achievable at all under `ESTIMATE`?** Unresolved, and it
   decides whether the sampler is a gate or a report. Measurement: one 32³ Eu
   ITP run N = 10 times on one host with `MEASURE` and with `ESTIMATE`, counting
   bit-identical ψ; then the same across two nodes. Try
   `save_fftw_wisdom` / `load_fftw_wisdom` (`src/foundation/grid.jl:85-90`, zero
   callers) before paying `ESTIMATE`'s planning cost. Until this is measured the
   sampler ships with a declared tolerance and an `:indeterminate` arm.

5. **How to bake `SYSIMAGE_SCOPE_DIGESTS` into a PackageCompiler image.**
   §2.10.5 refuses every `-J` run until the stamp exists, which is the safe
   default but is not a working configuration for TSUBAME. The constant cannot
   live in `SpinorBEC`'s own source, because that source is what the image
   bakes; the options are a generated file written into `src/` immediately
   before `create_sysimage`, a companion `.toml` beside the `.so` whose path the
   runner checks, or a policy of "no sysimages for artifact-producing runs",
   which is defensible and has a JIT-cost consequence
   (`docs/guides/tsubame.md:285` already lists "~10 min before any output").
   Undecided.

6. **Dependency identity under `-J`.** `toolchain_id` reads
   `Pkg.dependencies()`, i.e. the on-disk manifest, while the seal binds only
   `SpinorBEC` and its CUDA extension to the loaded image. A sysimage baking
   CUDA 5.9 against a manifest resolving CUDA 5.11 is therefore invisible to
   both halves — the same shape as the sysimage finding, one level down. The
   cheap fixes (apply `image_agreement` per numeric dependency, or bake the
   dependency tree hashes into the stamp) are known and unbudgeted.

7. **`NUMERIC_ROOTS` is not gated for coverage.** `test_scope_partition.jl`
   gates ownership *within* the eight roots; nothing gates that the roots still
   cover the numeric surface. Widening them to include the runner would make
   §2.10.6's gates noisy without making them sound; the intended answer is that
   the runner has no numerics left to hold, which is an aspiration and not a
   gate. Named live instances outside the roots: `_cuda_functional_callback`
   (`run_registry.jl:632`), `SPINORBEC_SCAN_ONLY_INDEX`,
   `SPINORBEC_LIGHT_POINTS`.

### 10.3 Audit findings — closed, and left open

Against issue #250's 15 survivors. Closing means "a mechanism in this document
makes the failure unrepresentable or loud", not "a paragraph mentions it".

**Closed (8).**

| # | finding | where |
|---|---|---|
| D1 | process-global numeric switches invisible to identity | §2.10.1–2, §2.10.6 — deleted, not traced; ban gated; ambient scan asserted at entry and exit |
| D2 | stale `-J` sysimage runs old code under a new tree digest | §2.10.5 — `image_agreement` puts a runtime fact against a disk fact; `in_sysimage` refuses |
| D3 | `backend` collides CPU and GPU artifacts of one `Model` | §2.10.3 — key field, plan-time pure resolution, `backend_agrees` asserted |
| D4 | dependency versions outside the key; `project_hash` cannot discriminate | §2.10.4, §5.3 — resolved `tree_hash` per dep, totality-gated |
| S1 | interrupted dynamics returns a truncated series as SUCCESS | §2.5 `Completion`, §5.4 — rethrow, record, fail-closed probe |
| C1 | no store write protocol; two same-id writers share one temp inode | §2.10.8 — in-directory staging, fsync, rename, last-written marker, grep gate |
| C2 | resume-as-store-probe cannot see an in-flight job | §2.10.8 — `CLAIM/` plus scheduler consultation |
| C3 | a cache hit's Record lands on the producer's file | §2.5, §2.10.8 — `hits/` is a separate append-only directory |

**Partly closed (3).**

- **S2** — the *collision* half is closed (`_gs_cache_key` deleted for
  `stage_id`, which carries `backend` and `dealias`); the *admissibility* half
  needs §5.4's `Completion` and the fail-closed default, which are specified
  here but are a separate edit in a file this design deletes.
- **C4** — the add/add conflict is closed for `record.toml` by making it a pure
  function of the id (§2.5). It is **not** closed for a store committed across
  ~20 worktrees in general: `exec/` and `hits/` are conflict-free by filename,
  but nothing stops someone committing a payload path, and the union merge
  driver is specified and unwritten.
- **D5** — `fft_flags` becomes a key field and the FFTW plan digest becomes an
  instrument, so a disagreement is now diagnosable. Bit-equality is **not**
  claimed achievable; §10.2 items 3 and 4 carry it.

**Open (4), with the reason each is not an identity problem.**

- **S3 · TWA ensemble opacity.** Member survival, live status and checkpointing
  are process facts. Nothing about a complete declaration obliges a 50-member
  accumulator through `Parallel(:seed)`; `twa.jl:43` has no `isfinite` check,
  `_welford_update!` is cumulative so one NaN poisons every later member, and
  the TWA branch returns at `run_step_dynamics.jl:352` before the live callback
  is built, so the divergence reaper is blind to it. `Completion.members` /
  `finite_members` (§2.5) closes only the silent-green half: 49/50 and 50/50
  stop being indistinguishable. The rest is an aggregator refactor.
- **P1 · the kept autopilot files are typed on the deleted `QueueEntry`.**
  `exec/` (§2.10.8) is where the per-attempt state belongs and makes the port
  *possible*, but mutable scheduler state — attempt count, escalated resource
  class, `job_id`, `kill_reason` — is genuinely not artifact identity, and this
  revision does not do the port. §2.11's "repurposed wholesale" remains
  aspirational until it is done.
- **P1b · taint does not travel along `Stage.inputs`.** It cannot be closed by
  identity without breaking the system: making a guard verdict part of an id
  would make the id depend on the run's outcome, so it could no longer be
  computed before the run to decide the skip. `Execution.admission` is the right
  carrier and the propagation rule — meet the stage's own admission with the
  minimum over its inputs' admissions — is an admissibility relation over the
  same edges, i.e. the missing fifth reading of invariant 4. Specified nowhere
  yet.
- **P2 · `outcome.toml` has no producer.** A filename bug, not an identity one:
  `_write_exit_summary` (`runner.jl:126-137`) already writes exactly the keys
  `classify_failure` reads, and `retry.jl:29-32` reads the wrong name.
  Independently, `backend_failure_reason(::UGEBackend)` returns qacct strings
  that `retry.jl:41-47` never matches, so `RESOURCE_PERMANENT` escalation is
  unreachable on the production backend. Both are one-file fixes outside this
  design and neither is done.
