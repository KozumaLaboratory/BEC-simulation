# The Ledger — one name, one lookup, one register

**Status:** design, 2026-08-02. This is the front of the spec/provenance
architecture. The 950-line
[`research_spec_and_provenance_architecture.md`](research_spec_and_provenance_architecture.md)
becomes the **record behind it** — the measurements, the cutover log, the four
step-2 deviations, the six step-3 corrections, and the canary passes. Nothing in
that file is retracted by this one. This file says what the whole of it means,
in one idea.

**Reading time.** Sections 1-3 are the researcher-facing part: 418 lines, about
1,700 words of prose plus eight short code blocks, roughly ten minutes. They are
the whole model — if you stop after them you can predict the system. Sections
4-6 are the proof of coverage, the honest gaps, and the tree diff; read them when
you are changing the layer, not when you are using it.

---

## 1. The one sentence

> **A name must determine its value.**

Everything the system can hand you is a binding in **one ledger** from a **name**
— the complete, closed, byte-canonical statement of everything the value was
derived from — to that value. Every operation is the **one lookup**
`held(name)`. Every "no" it can say is a **tag** from one closed vocabulary, and
every tag is a **row in one register** giving its locus, its disposition, its
written reason, and its **measured** cost.

Everything else is that law meeting a specific way a name can fail. There are
five ways, plus one thing the system may do instead of refusing. They are not a
list to memorise: each one forces exactly one mechanism, so you derive the
mechanism from the failure.

```
(A)  the name cannot be FORMED — the source does not determine the value
     ⇒ refuse to form it, never guess.  No name, no entry, never a hit.

(B)  the name is formed and NO ENTRY exists
     ⇒ recompute, and say which of: nothing was ever written / the name moved /
       another process holds it / reuse was never switched on.

(C)  an entry exists and the BINDING IS A LIE — the bytes are not that name's value
     ⇒ the entry is committed by a statement written LAST that names the bytes;
       a writer that knows it failed leaves a tombstone; the migration window
       has a date.

(D)  an entry exists, but the caller asked MORE THAN THE NAME DETERMINES
     ⇒ refuse for that use, not for all uses.

(E)  something OUTSIDE the name moved the value
     ⇒ put it in the name, fix it so it cannot vary, or declare it open —
       and an open influence must carry a MEASURED cost against a budget.

(F)  not a failure: you may be SERVED UNDER A WEAKER RULE than the law.
     ⇒ that is a caveat, it is attached to the value, and it travels.
```

**What you can predict after reading only this.** A run reuses a stored answer
if and only if you already hold that declaration's answer. So it will *not*
reuse if you changed anything in the name — including any byte of `src/` or
`ext/` — if the run that produced it did not finish, if the declaration cannot
be formed at all, or if something outside the name is switched on. Those are not
four rules. They are (E), (A), (C) and (B), which is one rule seen from four
sides.

Four consequences worth stating because they surprise people, and all four are
(D) — the caller asked more than the name determines:

- A published number whose window is not ours does not determine our comparison,
  so it is quotable and refused as a target.
- A solve that stopped at its own floor does not determine a convergence claim,
  so it is served by default and refused to a caller that asks for `converged`.
- A claim with no control does not determine whether the physics or the plumbing
  produced the result, so it is refused — which is the same rule as a check with
  no control returning `:indeterminate` and never `:pass`.
- A gate with no canary does not determine the property it names, so it is
  refused as evidence.

---

## 2. What the researcher holds

Four things. The fourth is a verb.

1. **A NAME** is everything the answer depends on, written down: the physics, the
   numerics, what it started from, which machine class, and the code. If it is
   not in the name it cannot change the answer — or it is in the register and you
   can read what it costs.
2. **The LEDGER** binds names to answers. An answer is in it only if the run that
   produced it finished; the statement saying so is written last and names the
   bytes.
3. **The REGISTER** is the list of everything a name does *not* determine: every
   ambient knob, every capability this design drops, every reason a config cannot
   be named, every reason a published number cannot decide. Each row has a locus,
   a disposition, a written reason, and a measured cost against a budget.
4. **`why(x)`** is the only question.

### The names you type

```
model   stage   sweep   claim   ref   run!        6 — to write a declaration
held    why                                       2 — to interrogate one
```

Eight. Two more (`Ledger.register`, `Ledger.limits`) stay qualified, because
`register` is exactly the kind of generic export that has already bitten once:
the test runner's private `claim(dir, i)` shadowed `SpinorBEC.claim` and made
`test/validation/test_matsui2025_ref.jl` green run directly and red under
`SPINORBEC_TEST_WORKERS=auto`. The shadow gate now covers `function` as well as
`struct`/`const`/`abstract type` (`test/test_tier_membership.jl:117`), which is
what that collision bought.

**The count that matters is not eight.** It is *how many independent models you
must hold to predict what the system does*. Today that is at least eleven, with
five different delivery mechanisms — a returned `Admission`
(`src/model/complete.jl:673`), a thrown `ArgumentError` (`src/model/ref.jl`,
`src/model/claim.jl:85`), a `nothing` from a swallowed throw
(`run_step_ground_state.jl:362`), a `@warn` to stderr
(`run_step_ground_state.jl:345`), and a red assertion in a test file
(`test/model/test_no_ambient_module_refs.jl`, `test_corpus_resolves.jl`). The
vocabularies are `Admission.provenance` (4), `no_artifact_id_reasons`
(free-form), `CORPUS_UNRESOLVED` (9 categories), `MARKER_CUTOVER_UNIX` (a dated
boundary), `MarkerVerdict` + `require_converged`, `REF_PROVENANCES` (3),
`REF_DISQUALIFIERS` + `arbitrates` (3), `CLAIM_KINDS` + the control/target rules
(3), `ALLOWED` + `AMBIENT_REFS` (16 pins, `:moves`/`:blind`), `code_tree_hash`
moving, and section 4's eleven dropped capabilities in prose.

**Eleven models with five delivery mechanisms becomes one model with one.** The
names go 6 → 8.

### The model, concretely

```julia
# A NAME is the declaration, and `preimage` is exactly the table its id digests.
# `artifact_id` already builds this table (src/model/identity.jl:156-167) and
# then throws it away. Keeping it costs nothing and is the whole diagnostic.

preimage(s::Stage) = Dict{String,Any}(
    "model"    => model_toml_dict(s.model),   # the resolved physics, losslessly
    "kind"     => String(s.kind),             # :relax | :evolve | :measure
    "method"   => String(s.method),
    "backend"  => String(s.backend),          # CPU and GPU are two names
    "params"   => _enc(s.params),             # numerics, hashed BY CONSTRUCTION
    "from"     => s.from === nothing ? nothing : artifact_id(s.from),
    "code_rev" => code_tree_hash(),           # one hash of src/ + ext/
)
artifact_id(s) = content_id(preimage(s))      # unchanged; no id moves

# THE ONE LOOKUP. One concrete struct, not a union — this crosses the
# make_workspace inference barrier, which is why `Admission` is already shaped
# this way (complete.jl:280) and why it stays that way.
struct Held
    ok::Bool                     # did you get the thing you asked for?
    tag::Symbol                  # one of REASONS, or :held when unqualified
    why::String                  # the specific slot, file, or bound
    caveats::Vector{Symbol}      # REASONS tags you were served UNDER
    detail::Dict{String,String}  # two ids, two sizes, a path, the row's value
end

held(x) -> Held      # x is a Stage, a RefRow, a Claim, or a Gate
why(h::Held)         -> (row::Row, instance::String)   # the class, and this case
why(a::Stage, b)     -> Vector{Divergence}             # first differing leaf
Ledger.register()    -> Vector{Row}                    # everything not determined
Ledger.limits()      -> the :dropped rows              # = design section 4
```

`REASONS` is closed and its members are grouped by the six letters above. Its
tags are **read, never memorised** — you get one back and you look it up. The
groups are what you hold.

`REGISTER` rows carry seven dispositions: `:named` (it is a slot of some name),
`:fixed` (it cannot vary at run time), `:open` (it can, and is in no name),
`:session` (a cache, a registry, a callback slot — cannot change a number),
`:recorded` (written beside the value, gates nothing), `:dropped` (a capability
this design does not provide), `:retracted` (values under these names are
wrong). Two floats decide everything about an `:open` row:

```
cost >  budget   ⇒  a binding written while this is exercised is REFUSED
cost <= budget   ⇒  served, with this row as a CAVEAT
isnan(cost)      ⇒  RED AT BUILD.  Unmeasured is not "small" — and therefore an
                    influence nobody has measured cannot be filed as :open at
                    all. It is :dropped, naming the measurement that would
                    promote it.
```

That pair is what stops "everything outside the name must be declared" from
refusing every run. `FFTW.MEASURE` is the default at the production choke point
(`src/workflow/initialization/make_workspace.jl:72`) and the OpenBLAS level-1
team is sized from core count; neither is going away, and a rule that refused
every open influence would cache nothing. Measured-against-a-declared-budget is
the repo's existing `NegligibleErrorSpec` discipline, reused rather than
reinvented.

### Worked example — Matsui Fig. 4B

The point of writing this one out is that it **ends in refusals**, and every
refusal names a real blocker in the tree today.

```julia
using SpinorBEC

# The parameters are QUOTED, not typed. Every one of these is a row in
# refs/matsui2025.toml with its provenance, its locus and, where the shipped
# source does not contain it, the alternative it was chosen over and the cost.
N   = ref(:matsui2025, :N_atoms).value          # 50_000  (reconstructed; the
                                                #  shipped setup_parameters says
                                                #  35_000, priced at 1.4286x in
                                                #  c_0 + 36 c_1)
fx  = ref(:matsui2025, :omega_x_Hz).value       # 110.0 Hz -> omega_ref
fz  = ref(:matsui2025, :omega_z_Hz).value       # 130.0 Hz
r1  = ref(:matsui2025, :c1_over_c0).value       # 1/36 exactly, by their design rule

eu = model(; grid = (n=(64,64,64), box=(10.0,10.0,10.0)),
             atom = :Eu151,
             interactions = (N_atoms=N, omega_ref=2pi*fx, c1_ratio=r1),
             potential = (kind=:harmonic, omega=(1.0, 1.0, fz/fx)),
             ddi = (secular=true, padded=true),
             zeeman = (Bz=0.0, theta=0.0))

gs = stage(:relax; model=eu, method=:lbfgs, tol=1e-8, n_steps=20_000)

held(gs)
#  ok      true
#  tag     :held
#  why     "marker verified 1 file(s)"
#  caveats []
```

That much works today: `gs_stage` (`run_step_ground_state.jl:310`) is a real
`Stage` producer, `artifact_id` is what admits (cutover step 3), and
`admit_payload` is the marker check (cutover step 2).

```julia
ev    = stage(:evolve; model=eu, method=:strang, from=gs,
              dt=2.0e-4, steps=150_000, save_every=500, backend=:gpu)
cells = sweep(ev; over = :Bz => range(-13e-9, 9e-9; length=45))

held(cells[23])
#  ok      false
#  tag     :absent
#  why     "no :evolve producer exists: run_step_dynamics.jl declares no Stage"
```

`gs_stage` is the **only** `Stage` producer in `src/`. So the 45 evolve cells and
their control are not nameable, and the design does not pretend otherwise.

```julia
target = ref(:matsui2025, :dip_width_exp_scanwindow_nT)
held(target)
#  ok      true
#  tag     :held
#  caveats []
#  detail  value  = 12.838286496502 nT   (RE-MEASURED off the committed fixture,
#                                          on this call; the stored number is a
#                                          cross-check that throws on disagreement)
#          window = [-13.0, 9.0]         (our own scan: 45 fields at 0.5 nT)
#          digits = 2                    (moving the left edge one sample to
#                                          -12.5 changes this by 0.32 nT)

held(ref(:matsui2025, :dip_centre_exp_nT))
#  ok      false
#  tag     :axis_offset
#  why     "the Fig. 4 caption admits an offset of up to 10 nT on a 3.2 nT centre"
```

The width arbitrates and the centre does not, because an axis offset shifts a dip
and does not stretch one. That is a property of *their* axis, decidable without
looking at our number — which is why `arbitrates` is derived from
`disqualified_by` (`src/model/ref.jl:73`) and is not a free Bool somebody sets
while watching the comparison.

```julia
fig4b = claim("the m = -6 depletion resonance reproduces Matsui Fig. 4B in WIDTH";
              kind     = :C,
              evidence = cells,
              control  = with(ev, ddi=(c_dd=0.0,)),   # the arm that must FAIL
              target   = target)

held(fig4b)
#  ok      false
#  tag     :absent
#  why     "45 evidence stages and the control have no entry (no :evolve producer)"
```

Reading that back: the claim is refused for the same reason as one of its cells,
with the same tag, through the same lookup. There is no separate story to learn
about claims. And it is refused rather than being satisfied by offering the
ground-state stage as evidence for a dip-width claim — which is precisely the
substitution the `control` field exists to name.

---

## 3. The single diagnostic

One shape. `x` is whatever surprised you.

```julia
h   = why(result)     # the Held, or the caveats a value came with
h.tag                 # the class
h.why                 # the specific slot, file, or bound
row = why(h)          # the register row: locus, disposition, written reason,
                      # MEASURED cost, budget — plus this instance's detail
why(mine, theirs)     # when the tag is :name_moved — the first differing leaf
```

**Surprise 1 — "it recomputed and I did not expect it to."**

```
julia> why(run!(gs))
  tag     :name_moved
  why     "code_rev"

julia> why(gs, previous)
  code_rev   a91e5c1f… -> 4d0b1773…
  (1 leaf differs; model and params are byte-identical)
```

Five unrelated answers to that question become five tags of one enum:

```
no marker            -> :uncertified   (or served with a :grandfathered caveat)
a tombstone          -> :unfinished
no artifact_id       -> :unresolvable  (h.why names the slot the YAML did not give)
the code moved       -> :name_moved    (why(a,b) says which leaf; code_rev is a leaf)
the toolchain moved  -> a :recorded register row that says plainly it gates nothing
```

Two properties make this work rather than merely read well. The **pre-image is
kept**: `artifact_id` is a pure function of it, so writing it down costs nothing,
and *not* writing it down is exactly what makes the question unanswerable
afterwards — the run that could have answered is always already gone. Four
unrelated systems arrived at this independently (AiiDA's `get_objects_to_hash`
with "load both nodes and diff the dicts"; ccache's `.ccache-input-text`;
Nextflow's advice to leave `-dump-hashes` on for every run; nix-diff, which
exists because Nix shipped none). Bazel built the diagnostic one level short —
`--explain` says "One of the files has changed." without naming it — and has been
criticised for that across three open issues since 2017. And **the cascade is
folded**: `code_rev` moves on 53% of commits here, so a diff that reported every
downstream difference would be a wall. `why` descends to the first divergence and
squashes the stairs, which is nix-diff's other distinguishing feature.

**Surprise 2 — "it did NOT recompute and I expected it to."**

```
julia> why(run!(cells[23]))
  reused, with caveats:
    :grandfathered   "no completion marker; written before 2026-08-01T19:33:52+09:00"
```

Or the caveat is `:open_influence` — an ambient knob is set, its measured cost is
under its budget, so you were served and told. Or it is `:shallow` — you were
handed an endpoint whose intermediates were never materialised, so the
certification covers the endpoint and the terminal inputs and nothing between.

**Surprise 3 — "I cannot quote this number."**

```
julia> why(held(ref(:matsui2025, :dip_width_sim_nT)))
  tag          :window_not_covered
  locus        refs/matsui2025.toml [quantity.dip_width_sim_nT]
  disposition  :dropped
  reason       "no SpinorBEC scan spans [-20, +20] nT, and a width measured over a
                window our runs do not cover is not the same measurement"
  cost         1.95 nT   budget 0.41 nT
  instance     "six configs under runs/matsui_fig4b/ quote this in their headers
                as 'the target' while the comparison used the scan-window row"
```

The tag is the class, the row is the instance. That is what makes
`CORPUS_UNRESOLVED`, `REF_DISQUALIFIERS`, `Admission.provenance`,
`no_artifact_id_reasons`, `admission_counts`, `ALLOWED` and design section 4 one
table instead of seven — which matters, because seven hand-maintained lists is
the very disease (`_gs_cache_key`'s 19 entries) this campaign exists to delete,
reproduced seven times inside the campaign's own gates.

**Surprise 4 — "is this gate real?"** A gate is a name for a property, and its
name is *the corruption that must redden it*. A gate whose canary was never run
is `:uncanaried`; one whose canary came back green is `:vacuous`; one that reads
its expectation out of the thing it checks is `:circular`. A broken gate surfaces
in the same place and the same shape as a broken cache.

**And the counters are the same enum.** `ledger_counts()` is a histogram over
`REASONS` plus the provenances, process-cumulative with its scope labelled,
stamped into `_exit_summary.json` on the success path **and** the failure path
(`runner.jl:144-179`). So "how many artifacts did this campaign serve without a
verified certificate" is answerable from a finished run's own files, by someone
who did not capture stderr. That is ccache's per-reason counters and sccache's
documented silent-total-disablement failure, answered once instead of per
subsystem.

**What the shape cannot tell you**, stated so it is not trusted past its edge: it
names the *first* divergence, not every divergence; it cannot detect a lying
host; and where a tag's row carries `cost = NaN`, the honest answer is "this
influence is UNMEASURED", which is a build failure rather than a reassurance.

### The whole vocabulary, once

Printed here so that "closed" is checkable, not so that you memorise it. You get
a tag back and you look it up; what you hold is the six letters.

```
(A) the name cannot be FORMED
    :unresolvable  :seed_dependent  :dropped_physics  :misdeclared
    :ambiguous     :not_on_this_path  :undeclared_input  :undeclared_resume
    :realised_only
(B) a name exists; an entry does not
    :absent  :name_moved  :in_flight  :not_attempted
(C) an entry exists and the binding is NOT HONEST
    :unfinished  :uncertified  :bytes_disagree  :unreadable  :retracted
(D) the caller asked MORE THAN THE NAME DETERMINES
    :verdict_short  :not_re_derivable  :chosen
    :axis_offset  :window_not_covered  :absolute_population
    :no_control  :no_target  :no_evidence
    :uncanaried  :vacuous  :circular
(E) an influence OUTSIDE the name
    :open_influence
(F) served under a WEAKER rule — caveats, never refusals
    :grandfathered  :shallow

33 tags, plus the affirmative :held when a lookup succeeds unqualified.
Plus four provenances on a served value:
    :computed  :reused  :quoted  :replayed
```

Twenty-two of the 33 have a producer in the tree today. The eleven that do not —
`:name_moved` (the behaviour exists; the tag needs the stored pre-image),
`:in_flight`, `:not_attempted`, `:undeclared_resume`, `:realised_only`,
`:retracted`, `:no_evidence`, `:uncanaried`, `:vacuous`, `:circular`, `:shallow`
— plus the `:replayed` provenance are named in section 6 as not built. A
meta-gate asserts that every tag is reachable by some fixture: a tag nothing can
produce is as red as a refusal with no tag.

---

## 4. How every requirement follows

The scaffolding is the specification. The inventory behind this design is **622
requirements** across five areas — the 950-line design document and its gates
(173), issue #250's two audit passes (101), the 23 commits on
`feat/model-resolved-physics` (115), the 23 gate suites those commits added
(172), and the external prior-art reconciliation (61). Requirement ids repeat
across areas, so each is qualified `A1:` (design doc + gates), `A2:` (#250),
`A3:` (commits), `A4:` (gate suites), `A5:` (prior art).

Coverage: **608 of 622**. The 14 requirement ids that are not covered are named
in section 5, with the reason.

Each sub-table below is one mechanism, and every mechanism is a consequence of
the law meeting one of the six cases.

### M0 — the law itself

| requirements | consequence |
|---|---|
| A1:R-ROOT-01, A3:R-ID-01, A4:R-ID-01, A5:R-QUADRANT-00 | The named object is the resolved physics as a value, not a text whose parsing produces the physics as a side effect. The design states its cell: deep constructive trace at n = infinity, topological scheduler — Buck's cell — so the three consequent losses are one placement, not three surprises. |
| A1:R-ID-01, A1:R-KEY-01/02, A2:R-ID-01, A3:R-ID-02/13/14, A4:R-ID-02, A5:R-BAZEL-01, A5:R-CCACHE-07 | Identity is the whole declaration with no selection step; the physics half is a pure function of the same resolved object the solver reads; exactly one key admits; when the name cannot cover what the run read, the system declines to store rather than storing weakly. |
| A2:R-INV-04, A2:R-INV-09, A2:R-ID-06, A2:R-OPEN-04, A3:R-ID-10, A4:R-ID-11 | No hand-maintained allowlist is load-bearing for a name. There is no partition over files at all, so misfiling a shared file is unrepresentable and activation-totality is automatic — every code byte is in every name, including `vacuum_noise.jl`, which was the one already-identified instance of a numeric file no scope claimed. `_enc` refuses fieldless types outright (`io.jl:67-77`), so an unencodable value cannot launder into `{}` past the hasher. |
| A5:R-BSALC-01, A5:R-BSALC-05 | Determinism is the law restated: if two executions of a name are not interchangeable for the claim it supports, an influence is outside the name, so it is `:open` and its cost decides refuse-or-caveat. Self-tracking must be pessimistic — whole-tree — because tasks here are Julia functions, not comparable data, and CLAUDE.md commitment 3 refuses a physics-codegen layer. |
| A5:R-BSALC-04, A5:R-BAZEL-03 | A run must not modify its own declared inputs; an input reached by path is not named, so it must be content-pinned or refused. |

### M1 — the pre-image is kept

| requirements | consequence |
|---|---|
| A5:R-AIIDA-01, A5:R-CCACHE-02/03, A5:R-NF-03, A5:R-NIX-02, A5:R-REAPI-02, A5:R-XCUT-01 | `preimage(s)` is exactly the table `artifact_id` digests, stored beside the value at write time, unconditionally. Artifact → declaration becomes a lookup, not a reconstruction. |
| A5:R-BAZEL-04, A5:R-NIX-08, A5:R-GRADLE-02 | `why(a,b)` descends both pre-images to the first differing leaf and folds the cascade — naming the leaf and both values, not the category; and reporting one line that declares itself the *first* difference, with the full per-field table behind it. |
| A2:R-CHAIN-02 | "Same physics, different discretisation" is a query on the kept pre-image (`preimage(a)["model"] == preimage(b)["model"]`), so issue #250's factored (physics, numerics, input) triple is unnecessary rather than dropped: three ids where one will do. |
| A1:R-REC-01/02/04/08, A4:R-SITE-01/02/03/04 | Every writer a real run passes through records the id and the code revision, per cell, and the reader lets both through; the on-disk record IS the entry directory, and the pre-image file is the part that was missing. The researcher never opens it: `held` and `why` are what `run!` hands back. |
| A5:R-NF-01 | Pre-image, payload, certificate and attempts share one entry directory and one lifecycle, so neither half can be backed up or pruned without the other. |

### M2 — group (A): the name cannot be formed

Seven tags, each with configs behind it and a gate in `test_corpus_resolves.jl`
(78 non-resolving configs, 9 categories, both directions).

| tag | requirements | consequence |
|---|---|---|
| `:unresolvable` | A1:R-RES-18, A1:R-KEY-08, A2:R-FAILSAFE-01, A2:R-CORPUS-01, A3:R-RES-02, A3:R-ID-17, A4:R-FAIL-01/05, A4:R-RES-05, A4:R-CORP-09 | A required slot the source does not give (16 configs with no `N_atoms`; 5 Rb87 q-autoderive refusals). Refuse by name with the config path; no name, no entry, never a hit. The run still solves. |
| `:seed_dependent` | A1:R-RES-19, A1:R-KEY-12, A3:R-RES-04, A3:R-NOT-16, A4:R-CORP-08, A4:R-HIT-02 | A slot whose default is a function of the initial state (22 tabulated-LHY configs with no `n_max`). Refusing it is also what makes rebuilding the table from a cached psi legitimate. `:full_bdg` still taking its spinor from `psi_init` is a `:seed_dependent` register row — named, not closed. |
| `:dropped_physics` | A1:R-RES-20, A2:R-CORPUS-02, A3:R-RES-05, A4:R-RES-06/07 | The declaration names physics the executor drops (2 configs with a tilted `B` on the spinor path). Refused rather than modelled — and not over-fired: a trivial axial field written in tilted form still resolves. |
| `:misdeclared` | A1:R-KEY-10, A2:R-MODEL-01, A3:R-RES-03, A4:R-RES-08 | The name would be WRONG about the run, not merely under-specified (`lhy: {kind: none, c_lhy: 5.0}` builds a `ScalarLHY`). A distinct refusal from under-specification. |
| `:ambiguous` | A1:R-RES-21, A3:R-RES-07, A4:R-CORP-10/11 | The source offers two and the choice must be made (5 configs with two ground-state steps; `index=1` resolves all five, asserted). The genuine limit — step 2 inherits from step 1's live workspace — is recorded as a limit and is the shape a chain design must confront. |
| `:not_on_this_path` | A1:R-RES-22, A3:R-RES-06, A4:R-CORP-12/13/14/15 | Another executor's declaration or an upstream refusal, reproduced from the same function the executing path calls and attributed to that layer (15 rotating-basis, 9 schema-strict, 4 non-configs). |
| `:undeclared_input` | A1:R-KEY-09, A2:R-FAILSAFE-02, A3:R-ID-16, A4:R-FAIL-02, A5:R-BSALC-04 | A warm start from bytes at a path (19 `seed_from` configs). `from` is the slot it belongs in and the predecessor is not a `Stage`, so it is refused rather than mis-declared as from-scratch. |
| (all of group A) | A1:R-RES-14/15/16/17, A2:R-CORPUS-01, A3:R-RES-08/09, A3:R-ADM-11, A4:R-CORP-01..07, A4:R-FAIL-06 | No name, no entry, never a hit — the run still produces its answer, it just cannot be reused. The corpus table is a register checked in both directions, with literal reason substrings, an independent re-reading of each config's own YAML (5,255 checks), coverage of every live spelling (`B: {p: …}` is 36 configs and its own arm), and floors on configs-checked and assertions-per-config. Warnings are keyed per distinct reason, so a 45-point scan emits one line and a second, different gap still breaks the silence. |

### M3 — group (B): a name exists, an entry does not

| tag | requirements | consequence |
|---|---|---|
| `:absent` | A1:R-ADM-10, A4:R-ADM-06, A3:R-ADM-03 | No payload. Distinct from a refused one: an absent payload is history not yet made, a disagreeing marker is corruption. |
| `:name_moved` | A1:R-ID-13, A3:R-ID-07/18, A4:R-CODE-09, A1:R-KEY-13/15 | The name moved and moving it back restores it, so invalidation is reversible and attributable. Backfilling into a code-digested name is forbidden — it files an old revision's value under the current name. |
| `:in_flight` | A2:R-CONC-02, A2:R-DROP-10, A1:R-NOT-10, A4:R-SCOPE-05, A5:R-REAPI-05 | The store probe becomes three-valued via a first-written attempt file, which is dedup-at-dispatch. Stale-claim reclaim needs the scheduler query and is a stated residual. |
| `:not_attempted` | A5:R-NF-04, A5:R-SNAKE-03 | Reuse was never switched on (`SPINORBEC_STAGE_CACHE` unset). The first thing a researcher hits, answered by the same list as every other why. |
| | A5:R-AIIDA-02, A5:R-AIIDA-08 | Reuse is a choice with a scope, read on the executing node and recorded in the attempt; and no branch of `held` returns a bare `Held` from a refusal condition — every failure direction loses a hit, none serves a value. |

### M4 — group (C): the binding is not honest

| tag | requirements | consequence |
|---|---|---|
| `:unfinished` | A1:R-ADM-13/20/21/22/23, A2:R-ADMIT-01/02/03, A2:R-MARK-03/05/06, A3:R-ADM-02, A3:R-EXE-01/02/06, A4:R-ADM-07..15 | The tombstone: a statement by a writer that knows it failed, checked FIRST, out-voting the grandfather allowance and any stale marker; cleared by a later success; the partial payload kept as the forensic record. Three swallowing loops, not one, each its own gate. The partial snapshot row is trimmed so the forensic path stays total under interruption. Nothing is written into a shared content-addressed store when a run did not finish. The realised extent has somewhere to be recorded, and a completion-relevant event reported only through a `println` is a name with no reader — the binding consumes the interrupted flag directly, so the channel has a consumer by construction. |
| `:uncertified` | A1:R-ADM-14/15/16, A2:R-MARK-02, A3:R-ADM-05, A4:R-MIG-02..05, A5:R-NF-02 | The dated bound (`MARKER_CUTOVER_UNIX = 1_785_580_432`, verified against `git log -1 --format=%ct ce9721cb`), pinned as a literal in the gate, asserted in the past, exclusive on its instant, applying only to the unmarked arm. This is the one place an mtime is load-bearing, and the row states its failure direction: a reset mtime makes an old payload look new, and new is REJECTED, i.e. recomputed. Never the reverse. |
| `:bytes_disagree` | A1:R-ADM-02/03/04/09, A2:R-MARK-01, A3:R-ADM-01/03, A4:R-ADM-01..05, A4:R-ADM-20, A5:R-NIX-01 | The certificate names each byte by a relative path and a size, is written last, and is what the probe tests. A symlinked payload is diagnosed as a stale link, not as truncation, with a negative control proving the truncation reading still fires. |
| `:unreadable` | A1:R-ADM-05, A4:R-ADM-21 | Unparseable, unknown format version, unknown key — all refusals, the same accretion rule as the declaration. |
| `:retracted` | A2:R-IMPROVE-04, A2:R-TAINT-01, A5:R-AIIDA-04, A5:R-REAPI-04, A1:R-REF-16, A3:R-REF-08 | A typed retraction distinct from "recompute this", keyed on name id so an entry becomes inadmissible without changing any name or deleting bytes; `held` walks `from` and `evidence`, so it travels every declared edge; a `namespace` field (REAPI's salt, omitted at its default) disowns a poisoned set without knowing which entries they were. |
| | A1:R-ADM-01/06/07/08, A4:R-ADM-22, A5:R-BAZEL-02, A5:R-REAPI-02 | Write order is the mechanism: attempt, pre-image, payload (unique temp in the same dir, then rename), certificate LAST. Nothing enters the ledger before every check that could reject it has run. The sidecar sorts after its payload under alphabetical rsync. |
| | A1:R-ADM-24/25/26, A3:R-EXE-04/05, A4:R-GATE-06/07/08 | The control must reach the swallow path (`schedule(task, InterruptException(); error=true)`, not `kill -INT`, which `exit_on_sigint` makes green before *and* after), must wait on a deterministic phase signal, and a lost race must name itself rather than abort the file. Refuted mechanisms are recorded so they cannot be substituted back. |
| | A1:R-ADM-27, A4:R-ADM-15 | The recomputation claim is a physics statement (ITP energy decreases monotonically) plus a positive control that a finished run is still served quickly. |
| | A1:R-ADM-28/29/30/31, A2:R-NAME-01, A2:R-GATE-06, A3:R-ADM-08, A3:R-EXE-03, A4:R-ADM-16..19, A4:R-GATE-09 | One lookup means every admission site IS the gated site — a site reverted to `isfile` is a second lookup, which is structurally red. A refusal poisons the name rather than falling through to an alias of the same bytes; one writer per published name, with the alias still published into an unclaimed name; a corruption probe corrupts the certificate so a wrong admission is a clean assertion failure. |
| | A1:R-ADM-11/12, A2:R-MARK-04, A3:R-ADM-04, A4:R-MIG-01, A5:R-SNAKE-05, A5:R-AIIDA-07 | Grandfathering is a visible caveat, warned once per store, never a silent promotion — and an operation that admits without recomputing records that it did so. When the name function itself changes, the defined operation on the existing store is `:name_moved` plus `why(a,b)`: a function of the name, so it re-runs on every copy of the store, unlike a one-shot backfill of a directory that is not in git. |
| | A4:R-MIG-06/07, A1:R-KEY-13 | A retired name is deleted, not aliased; reading is by name, so an artifact carrying unknown datasets is fine. |

### M5 — group (D): the caller asked more than the name determines

| tag | requirements | consequence |
|---|---|---|
| `:verdict_short` | A1:R-ADM-17/18/19, A2:R-ADMIT-04/05, A3:R-ADM-06/07, A4:R-ADM-23..29, A5:R-BAZEL-02 | The certificate carries the solve's own four fields verbatim; `require_converged` is per call and the default path is byte-for-byte unchanged; floor-limited stays admissible because it is the best the method can produce; a partial verdict is an error; `:grandfathered` carries none so it cannot satisfy the demand; bytes outrank opinion; `gs_verdict` is the one place the keys are named. |
| `:not_re_derivable` | A1:R-REF-08, A3:R-REF-04, A4:R-REF-09 | A `read_off` row: located in a content-pinned source, served with a caveat. |
| `:chosen` | A1:R-REF-08, A2:R-REF-03, A4:R-REF-08 | A `reconstructed` row owes the alternative, its locus, and the cost in units by a stated method, all-or-nothing — half a cost is an argument started and abandoned. |
| `:axis_offset` / `:window_not_covered` / `:absolute_population` | A1:R-REF-10, A2:R-REF-04, A3:R-REF-07, A4:R-REF-10, A5:R-CCACHE-04 | `REF_DISQUALIFIERS` verbatim; `arbitrates` derived from it; `Claim` refuses a disqualified target. Every entry is a property of the REFERENCE, so there is no field to set while looking at our result — which is also why no maintainer-chosen silent relaxation can exist here. |
| `:no_control` / `:no_target` / `:no_evidence` | A1:R-REF-01/02/03/04/17, A1:R-ERG-05/06, A2:R-CLAIM-01/02, A3:R-REF-02/09, A4:R-CLAIM-01..07, A2:R-GATE-01, A5:R-AIIDA-09 | The A/B/C taxonomy is this lookup, not a type hierarchy; the control is the physics switched off; `:A` needs neither; the `evidence = Stage[]` hole becomes an executable refusal; `CheckResult`'s `:indeterminate` (`specs.jl:33-48`) IS `:no_control` in the check domain, so one law covers two places. A claim the tree cannot yet support is refused with `:absent` on its evidence plus a tripwire that fires the day the blocker disappears, never satisfied by substituting a different observable. And an aggregate over stored entries must NAME its members: a selection by query is not determined by the name and is refused, which is why AiiDA forbids caching workflow nodes outright. |
| `:uncanaried` / `:vacuous` / `:circular` | see M10 | A gate is a name for a property. |
| `:shallow` | A5:R-BSALC-08 | Serving an endpoint without its intermediates certifies the endpoint and the terminal inputs only, and the caveat travels. The light-point path (a `gs_ref` pointer instead of psi) is exactly this shape. |
| | A1:R-REF-05/06/07/09/11, A2:R-REF-01/02, A3:R-REF-01/03/05/06, A4:R-REF-01..07/11..13 | A measured row's NAME is the recipe (fixture sha256, metric, metric field, endpoint-baseline convention, window), so `held` re-runs it and the stored value is a cross-check that throws on disagreement; window and `quotable_digits` are required fields; the schema is closed on both sides per provenance; the whole row crosses the boundary with a fixed shape; asking a non-re-measurable row for a measurement is an error. |

### M6 — group (E): an influence outside the name

| requirements | consequence |
|---|---|
| A1:R-DECL-10/11/12, A2:R-ID-01/02, A2:R-AMBIENT-01, A3:R-AMB-01/02/03/04, A4:R-AMB-01..05, A5:R-NIX-03 | Every module-level mutable binding is a register row with a disposition, a written reason, and a MEASURED cost, both directions gated. The scanner covers exactly `CODE_TREE_DIRS` (asserted equal, not restated), matches `Ref(` / `Ref{` / `Base.RefValue`, and carries a synthetic positive control. "We grep that nobody sets it" is not one of the admissible dispositions. |
| A1:R-DECL-13, A4:R-AMB-04, A2:R-ID-03, A3:R-AMB-09 | Whether a binding reaches the name is measured per binding with `:moves`/`:blind` both pinned; the harness asserts the flip flipped and that restoring returns the base id. Today: 7 bindings on kernel paths, 2 `:moves` and 5 `:blind`, with effects spanning nine orders (`test/model/test_ambient_refs_vs_artifact_id.jl:30-35`). An audit arm that flips knobs must either name them (a different id) or be refused — the instrument returning the production artifact verbatim is unreachable, and the pinned degeneracy is a row so that fixing it turns the testset red. |
| A1:R-DECL-14/15/16/17, A2:R-AMBIENT-02, A2:R-INV-07, A3:R-AMB-05/06, A4:R-AMB-06, A4:R-FAIL-03/04, A5:R-BSALC-06 | An over-budget `:open` influence makes the *binding* refuse, not the solver — so a test instrument stays settable and cannot file a production artifact. Where a legacy path is the oracle, the selector becomes an argument rather than dead code. Deleting a row means carrying its measurement into the deletion. This is `do_not_cache` / `__impure` expressed as a disposition. |
| A1:R-RES-08/09, A2:R-PURE-01, A3:R-AMB-07/08, A4:R-AMB-09 | Resolution is pure in the ambient globals and restores them on the throwing path, or the name is not a function of its source. A later default overwriting an earlier deliberate override is an ordering defect in the resolver, pinned with its measured before/after ids. |
| A2:R-EXEC-01, A2:R-ID-05, A1:R-NOT-04, A3:R-ID-06 | `bind!` compares the sysimage's baked tree hash with `code_tree_hash()` and refuses on disagreement, closing the stale-sysimage half of D2; `backend` is a preimage key, so CPU and GPU are two names — Level 0's rtol gates (1e-10 / 1e-8 / 1e-6 on 1D/2D Rb87 fixtures a GPU would never see) are not the bit-parity a collapse would need. |
| A2:R-ID-04, A4:R-AMB-07/08/10 | A migration that deletes the only writer of a recorded field is red; a binding whose home is a stage that does not exist is `:open` blocked-on-that-stage; session state is its own disposition with a reason per entry, so the rule does not forbid all module-level mutability; separate physics gets separate name fields (the Orszag switch and the physical-k cutoff are two `GridSpec` fields and 71 configs set `k_cut`). Thread count and FFTW planning are named unmeasured and filed `:dropped` — see section 5. |

### M7 — serving under a weaker rule, and caveats travel

| requirements | consequence |
|---|---|
| A5:R-NIX-04, A2:R-TAINT-01, A1:R-NOT-07 | Caveats travel: a value derived from a caveated one inherits it, so declared non-reusability is infectious along declared edges. Undeclared edges — a number copied out of a figure — are a `:dropped` row that says so. |
| A1:R-REC-05/06, A5:R-AIIDA-03, A2:R-CONC-03 | A hit is a first-class result flagged as one, appended as a new attempt, never rewriting the producer's record — so a hit cannot launder the producer's ingested warning stream, host, or environment. |
| A5:R-SNAKE-04, A5:R-AIIDA-02 | `accept=` per call and an explicit per-name acceptance, both reporting whether they changed anything, because a silent override is Snakemake's `--cleanup-metadata` failure. `accept` converts a refusal into a `Held` carrying that refusal as a caveat — the only way a weakened serving happens, and it is visible in the value. |

### M8 — the register, both directions

| requirements | consequence |
|---|---|
| A1:R-GATE-06/08, A4:R-AMB-03, A5:R-XCUT-02, A5:R-SNAKE-02 | Both directions everywhere: an influence found by the scanner and not in the register is red, and a row naming nothing real is red. Every row's reason is asserted non-trivial. This is the one registry that replaces `CORPUS_UNRESOLVED`, `ALLOWED`, `REF_DISQUALIFIERS`, `Admission.provenance`, `no_artifact_id_reasons`, `admission_counts` and section 4 as instances of one pattern. |
| A1:R-NOT-01..12, A2:R-DROP-01..11, A3:R-NOT-01..16, A4:R-SCOPE-01..08, A1:R-OPEN-01/02/03, A2:R-OPEN-06, A2:R-HON-05, A3:R-DOC-03, A5:R-BSALC-07 | Every dropped capability is a `:dropped` row with its written reason and measured cost, so `Ledger.limits()` IS section 4, generated rather than remembered — including the 52.7% partial-invalidation price, the measurement that would settle it (re-solve hours), and the instruction that re-adding an ownership map is inadmissible because it restores the wrong-number class. |
| A2:R-HON-01, A2:R-INV-08, A3:R-ID-09, A1:R-NOT-03, A1:R-REC-03, A5:R-CCACHE-04 | `:recorded` means "gates nothing", and the row is where that is said out loud: `manifest_project_hash` covers dep names, uuids and compat strings only, so it cannot discriminate a bump inside a compat range and does not pretend to; `[env]` is read by a human when two artifacts at one id disagree, and gates nothing either. |
| A5:R-BSALC-02/02B, A5:R-CCACHE-05, A5:R-AIIDA-06, A5:R-XCUT-03, A2:R-INV-05 | Code strictness, trace completeness, and false-positive tolerance are ONE dial with named settings and stated costs — `:tree` today, `:declared` (the `Change` class) as the only admissible alternative — so section 7's open question stops collapsing into "keep or delete the ownership map". Over-invalidation is a defect of the same standing as under-invalidation, which is why no per-build nonce enters the pre-image and dependency versions are `:recorded` rather than named. AiiDA ran this experiment and reversed in v2.6; the row records that both sides have been paid for. |
| A5:R-BSALC-09, A5:R-NIX-06, A2:R-DESIGN-01, A1:R-KEY-14, A3:R-DOC-04/07 | Eviction is a register row (safe where the derivation is deterministic, unsafe exactly where an `:open` influence exists — the Frankenbuild condition); `verify(name)` re-derives, keeps both, and the row's budget decides error-versus-caveat; budgets are register fields; the cost of a flip is measured on the actual campaign before flipping, not assumed; and every measurement states its scope. |
| A5:R-NIX-05, A5:R-REAPI-01 | A `read_off` row is a fixed-output derivation, admitted because the SOURCE is content-pinned, named individually. Budgets that TRUNCATE an answer (steps, tol, iteration cap) are `params` slots; budgets that only ABORT (walltime, the reaper threshold) produce no entry at all, so a run they end cannot answer for another — and putting them in the name would over-discriminate. Both are register rows. |

### M9 — one histogram over the one vocabulary

| requirements | consequence |
|---|---|
| A1:R-OPEN-03 (W4), A2:R-MARK-07, A3:R-ADM-09, A5:R-CCACHE-01/06, A5:R-SNAKE-03 | `ledger_counts()` is one named counter per REASONS member, process-cumulative with its scope labelled, stamped into `_exit_summary.json` on both exit paths (`runner.jl:144-179`). Total silent disablement is visible without anyone suspecting it, and `register(; tag=…)` is the per-reason list — the query set is 1:1 with the vocabulary. |
| A5:R-GRADLE-01 | Failure-shaped members (`:absent`, `:not_attempted`) live in the same list as the ordinary ones, which is what makes them derivable rather than separate explanations. |

### M10 — the gate domain: a gate is a name for a property

| requirements | consequence |
|---|---|
| A1:R-GATE-01/02/03/04, A2:R-GATE-02/03, A2:R-INV-03, A3:R-GATE-01/02/03, A4:R-GATE-01/02/03 | A gate's name is the corruption that must redden it, plus the observed result and the byte-identical restore. `observed = :unrun` is `:uncanaried`; `observed = :green` is `:vacuous` and is reported, not quietly strengthened; `expectation = :derived_from_subject` is `:circular`, so a gate cannot move both sides together; `positive_control` is a required field, so "nothing was wrong" and "nothing was measured" are different results — which is what would have refused to trust the dead `:cuda` branch. |
| A1:R-GATE-05/07, A3:R-GATE-04/05/06/07/08/09/10, A4:R-GATE-04/05/10/13, A2:R-GATE-04 | A scanner needs a synthetic positive control with decoys; a fixture must be proven to be one; "no other place does X" is checked against code, not file text; a reachability walk must follow keyword forwarding and prove it saw something; a comparison that can collapse to self-comparison through dispatch is `:circular`; a gate's numeric range must stay inside its dtype; an assertion no edit can break is `:vacuous`; constants a gate depends on are pinned literals. |
| A1:R-GATE-09, A4:R-GATE-11/12, A2:R-GATE-05, A5:R-SNAKE-01 | Tier membership is a register row per file; test files stay dependency-free units and must give the same verdict under the parallel runner; ordering-sensitive arms are ordered in the row; every partition is asserted total AND disjoint. The completion mechanism's own canary must be red, which is Snakemake 3808 made visible. |
| A1:R-GATE-10/11/12/13/14/15/16, A3:R-GATE-11/12/13/14, A3:R-DOC-06/09/12, A2:R-INV-01/02, A3:R-DOC-02 | A null needs the companion assertion that something different WOULD have been written; a specified gate found defective records the defect and the replacement in place; a missing cutover step is a hole in the plan; deviations are rows with "as landed"; a surfaced-but-unfixed defect is a `:dropped` row with its blast radius; two true counts are two rows; a superseded measurement is `:retracted` in the same pass; every invariant carries a file:line and a canary, so one false on the day it is written cannot be load-bearing; "it loads" is a name that determines nothing. |
| A1:R-REF-12/13/14/15/18, A3:R-INS-01/02/03, A4:R-INST-01..04, A4:R-REF-14 | An instrument is a gated property: `resonance_dip`'s canary is a manufactured solution with an exact answer, on the actual non-uniform grid geometry, with probe points asserted to straddle the spacing change and interior controls that stay green; the row's cost is the instrument's error against the effect it measures (0.25 nT against 0.41 nT). A gate that mutates committed data declares that it is the only reader, with a tripwire. |
| A1:R-REC-07, A3:R-DOC-10/11, A2:R-NAME-02, A1:R-REF-19/20 | A structured slot with no readers is a name nothing looks up: `schema.jl`'s `metadata:` — 45 keys, zero readers — is deleted, and the closed decode stops it re-forming one level down. A private helper may not take a package export's name; `Ledger` is a submodule with only `held`/`why` re-exported; machine-read reference data lives where it is gated, and its fixtures stay outside `CODE_TREE_DIRS`. |

### M11 — the name must be a value (encoding discipline)

| requirements | consequence |
|---|---|
| A1:R-DECL-01/02/03, A3:R-ID-12, A4:R-DECL-01/02/03 | No leaf reachable from the declaration is `Any`, a `Function`, or an open abstract type — stated on leaves reached by transitive decomposition, which is what reaches `AtomSpecies.scattering_lengths` one level below a `subtypes`-only walk. Time dependence is a closed union of concrete immutables. |
| A1:R-DECL-04/05, A3:R-VAL-04/05, A4:R-DECL-04/05 | NaN breaks reflexivity and takes the inactive branch, so it throws at construction, before the activity branch; a name mutable through a caller's handle is not a name. |
| A1:R-DECL-06/07/08/09, A3:R-VAL-01/02/03/06, A4:R-SER-01..05 | Serialisation is lossless and idempotent; omission is decided by a VALUE predicate the decoder reproduces, never by the physics `active` predicate; a tolerance must be dimensionally meaningful for what it bounds; unknown keys are refused at every level; the comparison reports which field differs. |
| A1:R-ID-02/07, A2:R-ID-06, A2:R-INV-06, A3:R-ID-11, A4:R-ID-07/08/11/12, A5:R-REAPI-03 | The one hash-ordered container is encoded as sorted parallel arrays; two spellings of one physics encode identically; a field at its inactive value is omitted and the defaults are frozen by the code hash, so adding a field or a term invalidates ZERO entries and "equal to the default" is stable over time; an empty parameter set is legitimate; total ordering is a MUST of the encoding, not a convention. |
| A1:R-ID-03/04/05/06/14, A3:R-ID-03/04, A4:R-ID-03/04/05/06/09 | One assertion per slot, enumerated from the type and continuing below the slot boundary into the atom's fields; a perturbation must survive the constructor and not reach a sibling; "derived" is a pinned literal with a reproducibility assertion and is not also written to disk. |
| A1:R-ID-15/16/17, A3:R-ID-05, A4:R-ID-10/13 | `from` carries the predecessor's id, not a presence flag; `kind` is closed and `backend` is validated by CALLING `_resolve_backend` (`backend.jl:98-106`), so `:cuda` — which looks admissible and throws — cannot pass. |
| A1:R-ID-08/09/10/11/12/18/19, A3:R-ID-07/08, A4:R-CODE-01..09, A2:R-OPEN-07 | Code identity is one content hash of everything that can execute, computed on the node from the actual bytes (rsync ships without `.git`); content/add/delete/rename move it, location and mtime do not; the path set is cross-checked against git including untracked-but-loaded files; the length prefix earns its keep only on a fixture whose file counts differ; memoised at load, which is the more correct reading; and the record writer degrades rather than inventing a revision. |
| A1:R-RES-10/11/12/13, A2:R-REPR-01, A3:R-ID-15, A4:R-DECL-06/07/08/09, A4:R-CORP-16 | Three physical states get three representations, the non-numeric one outside the numeric domain; the vocabulary conversion is declared once and asserted non-identity in both directions; the distinction is anchored in the kernel the two states build; an inactive term has exactly one representation. Zero committed configs exercise `trunc_radius`, so no corpus-derived gate can canary it: where the corpus exercises nothing, the fixtures are synthetic and each carries its own positive control. |
| A1:R-ERG-02/03/04, A2:R-DROP-09, A1:R-NOT-09 | The ~21 spec types are maintainer-facing; `params::NamedTuple` puts numerics in the name by construction with no list to edit; a sweep axis is a declaration so `differs_only_in` reads it directly; shape-gating stops at the resolved physics and says so. |

### M12 — `Change`: the one thing a hash cannot classify

| requirements | consequence |
|---|---|
| A2:R-IMPROVE-01/02/03/04/05, A3:R-NOT-12, A5:R-AIIDA-05 | The code hash moves identically for a speed-up, a looser contract, and a bug fix, so the class is DECLARED and CI demands the declaration the day `code_tree_hash` moves. `:performance` is refused unless its evidence names a green bit-identity gate; `:accuracy` carries the contract and the knob's measured cost; `:correction` writes `:retracted` rows. An entry whose producing code no longer exists stays readable and classifiable, and the register says plainly it is not re-derivable. |

### M13 — one resolver, one reader

| requirements | consequence |
|---|---|
| A1:R-RES-01/02/03/04/05/06/07, A2:R-MODEL-02, A3:R-RES-01, A4:R-RES-01..04 | Exactly one resolution of each physics block, gated three ways that do not reduce to each other (lowered code names it; the runner's source calls no physics parser; both consumers reproduce the same pinned literals), with a positive control that the structural walk follows keyword forwarding, idempotence on the mutated params, and everything the model needs carried out of the single resolution. Introducing the layer changes what no run computes — verified byte-identical across ten scenarios. |
| A1:R-KEY-03/04/05/06/07, A2:R-GATE-05, A4:R-RES-09/10/11/12/16 | Every schema key is bucketed exactly once into a partition asserted total AND disjoint; "not on this path" is checked in both directions; one assertion per input, never a bundle; the deleted key's coverage is a pinned literal; the gate asserts by VALUE that its id equals the one the production site reports. |
| A1:R-KEY-11, A2:R-MODEL-01, A3:R-ADM-10, A4:R-HIT-01 | A hit rebuilds the same Hamiltonian the name promises — every digested slot reaches the rebuilt workspace, or the name is lying about its own artifact. |
| A1:R-RES-23/24/25, A4:R-RES-13/14/15 | The reverse translator covers every buildable kind, refuses what it has no slot for, routes a term belonging to another slot there, is gated against the evaluator rather than against restated algebra, and where parameters are lost the two readings must at least agree on whether the term exists. |
| A2:R-CORPUS-03, A3:R-RES-10/11, A1:R-GATE-14/15 | Silent key precedence (`_parse_gs_interactions`, `parsing_blocks.jl:363-391`) makes a config not do what it says; it is a `:dropped` row with its blast radius and the retraction its fix would require, and the two true corpus counts are two rows. |
| A2:R-PROC-01, A2:R-CONC-01/04, A5:R-REAPI-05 | `Attempt` is the durable home for mutable process state, distinct from the finished binding; `name.toml` is a pure function of the name, so two branches running one declaration write byte-identical pre-images and the add/add conflict cannot form. |
| A2:R-CHAIN-01/04/05/06/07/08, A1:R-NOT-05, A2:R-DROP-05 | `from` makes a shared prefix reusable by construction; a replayed state comes back as `:replayed` unless bit-identity is established; the random stream position is `:named` or `:open`; `:realised_only` covers an operation sequence chosen from the state; `:undeclared_resume` refuses a method that has not declared what a fork must carry, and that lesson lives in the register rather than hard-coded where it was found. |
| A2:R-ENS-02, A2:R-HON-02 | The first attempt file is written by the binding, not by the step, so liveness does not depend on which kind of step is running and the reaper can see a TWA run. Files with different reliabilities are different rows with different producer statuses, so a gate cannot pass by counting them together. |
| A2:R-HON-03/04, A3:R-DOC-05/08, A5:R-XCUT-04/05 | The name count is stated honestly (6 → 8) and the model count is the claim; uncommitted code is marked as such at the point of citation; "records only, changes nothing" is a checkable structural claim; identity, admissibility and quotability stay three separable predicates — fusing them for elegance is the recurring error, and no surveyed system has both halves of the diagnostic, so this is a claim to attack, not prior art. |

---

## 5. What is genuinely not covered

Fourteen requirement ids, across twelve items. Each is stated with the reason,
because a hidden gap is worse than a stated one.

**Status, 2026-08-03.** Three of the fourteen are closed with measurements —
A2:R-OPEN-03 / A5:R-NIX-03B (item 1, which this document called its largest
single unknown) and A2:R-OPEN-01 (item 2). Eleven remain. Both closures cost
almost nothing to obtain, which is itself the lesson worth recording: item 2 was
never a compute measurement at all — it is resolution and hashing, and it sat
open because it was filed alongside a genuinely expensive one.

**Three measurements the design demands and this document did not perform —
TWO OF THEM HAVE SINCE BEEN MADE (2026-08-03).** They are kept in place, with
the numbers, because the reason they were listed is the useful part: `isnan(cost)`
is red at build, so a `:dropped` row names the measurement that promotes it, and
this is what promotion looks like.

1. **A2:R-OPEN-03 / A5:R-NIX-03B — the FFTW planner and the OpenBLAS team size.**
   `fft_flags = FFTW.MEASURE` is the default at `make_workspace.jl:72`, and the
   planner picks its codelet sequence by timing trials, so summation order is
   load-dependent; the OpenBLAS level-1 team is sized from core count. The
   measured evidence that this moves numbers is a 25x spread in `grad_norm`
   across three runs at one commit on one cluster. Neither had been measured *on
   psi*, so neither could be classified refuse-class or caveat-class. This was
   named the largest single unknown in the design.

   **MEASURED 2026-08-03** (TSUBAME jobs 8339392 and 8339525, 24^3 Eu151, 400
   ITP steps, cpu_16). Five conditions — planner default vs `MEASURE`, and
   `OPENBLAS_NUM_THREADS` 1 / 4 / 16:

   | quantity | result |
   |---|---|
   | energy | `1.8857610302635` under **all five**, identical to 15 printed digits |
   | psi hash | **differs under all five** |
   | psi, same process, twice | bit-identical, `max\|dpsi\| = 0` |
   | psi, three separate processes, identical env | three hashes, `max\|dpsi\| ~ 1e-16`, `dE/E ~ 3e-16` |

   So the classification is **caveat-class, not refuse-class**: neither knob
   moves an energy at this size, and what they move in psi is last-ulp. The
   sharper consequence is about the instrument rather than the knobs — **a psi
   hash is an oracle only WITHIN a process.** Two byte-identical invocations
   (`smoke` and `blas1` in job 8339392) produced different hashes. Any gate,
   parity job or bisect that compares psi hashes across processes is measuring
   the process, not the code.

   One mechanism was hypothesised and then **refuted**: memory alignment. A 64^3
   in-place complex FFT gives a bit-identical result from a 64-byte-aligned and a
   16-mod-64 buffer, under both `ESTIMATE` and `MEASURE`. The cause of the
   cross-process variation is still unidentified; it is bounded at 1e-16, which
   is what the row needed.
2. **A2:R-OPEN-01 — how much a derived key collapses the corpus.** Distinct
   derived ids against distinct whole-file hashes over every config under
   `runs/`. It decides whether the concurrent-write path is hot or theoretical.

   **MEASURED 2026-08-03**, by resolution and hashing only — no physics, so this
   was always a reading-cost measurement rather than a compute one:

   | | |
   |---|---|
   | configs under `runs/` | 446 |
   | resolve to a `Model` | 367 (79 listed with their reason) |
   | distinct whole-file hashes | 444 |
   | **distinct derived ids** | **116** |
   | collapse | **3.16x** |
   | names claimed by more than one config | 44 |
   | largest group | **59 configs on one name** |

   **The path is HOT.** Fifty-nine configs under `runs/klaus_quench/` resolve to
   `4607507a826b1363`; sixteen verification-suite configs share another.

   The number inverts if the collapse is a BLIND SPOT rather than genuine
   sharing, so that was checked rather than assumed. Two members of the
   59-config group (`klaus_quench_om0p0.yaml` and
   `klaus_quench_omm0p2_holdonly_delay2ms_refine.yaml`) have `ground_state`
   blocks with no key unique to either and no shared key holding a different
   value — byte-identical GS physics — while their `dynamics` blocks differ. The
   sharing is real: those 59 runs genuinely want one ground state, which is the
   stage cache's entire purpose. So the concurrent-write path is hot *because
   the design is working*, not because the id is blind to something.
3. **A2:R-OPEN-05 — write amplification of per-attempt records.** This design
   commits to an append-only `attempts/` shape without the
   executions-per-artifact measurement the requirement says must come first. If
   the mean is 3 or more, the index needs sharding and "rebuildable and safe to
   delete" has to go.

**Two things the register names but does not build.**

4. **A2:R-OPEN-02 — whether the truncation path fires outside the interactive
   REPL on UGE.** The tombstone plus the dated bound make the answer safe either
   way, but S1's severity is still unmeasured. `kill -INT` is verified
   uncatchable in Julia script mode; whether UGE delivers something catchable at
   the `h_rt` boundary is not.
5. **A2:R-ENS-01 — the TWA ensemble.** `grep -n isfinite src/solvers/twa.jl`
   returns nothing, and `_welford_update!` is in-place and cumulative, so one
   diverging member NaNs the mean for every later member. The ledger gives each
   member a name and the diverging member a refusal — but that requires a change
   inside `twa.jl` that this document specifies only in shape, not in detail.
   33 configs under `runs/` use `twa:`.

**Two mechanisms the register records rather than repairs.**

6. **A2:R-CLASS-01/02 — `outcome.toml` has no producer.** Verified today: five
   readers treat it as authoritative and the only writer in `src/` is the dry-run
   synthetic at `tick.jl:607`, whose own comment ("Real runs overwrite this file
   at process exit") is false. `queue.jl:13` still asserts the producer. And
   `backend_failure_reason(::UGEBackend)` returns qacct strings, never the SLURM
   `OUT_OF_MEMORY` / `TIMEOUT` that `retry.jl` matches, so the resource-permanent
   escalation is unreachable on the production backend. Both become both-directions
   register rows; neither is fixed here.
7. **A2:R-MIG-01 — the keep/delete partition against actual type usage.** The
   autopilot's kept files are typed on the deleted ones. The register can express
   it; this design does not perform that audit.

**Three where the mechanism is weaker than the requirement asks.**

8. **A2:R-CHAIN-03 — the fork-resolution policy.** The policy (replay from the
   nearest held ancestor) is stated, but the per-method materialisation costs
   that would make it real — 54 MB for psi against roughly 2.1 GB of L-BFGS
   two-loop memory at 64^3 x 13 — are quoted from issue #250, not measured under
   this design.
9. **A5:R-NIX-07 — trusted producers.** `require` is verdict-shaped, not
   host-shaped. The capability is not designed out, but it is not built, and the
   day a stale-sysimage TSUBAME artifact enters a shared store is when it is
   needed.
10. **A5:R-BSALC-03 — within-build deduplication.** Identical names within one
    `run!` are asserted to be one lookup; nothing enforces it yet, and the
    frontier releases up to 64 stages.

**Two the design cannot mechanise, or fails outright.**

11. **A3:R-DOC-01 — no LaTeX, with a check that covers inline expressions and
    macros, not only display math.** Complied with here as an author. But the
    gate domain is over *code* properties, not prose, so this design supplies no
    mechanism that would keep a future document honest, and the requirement asks
    for a check.
12. **A1:R-ERG-01 — the name budget is violated.** The requirement is that a
    researcher can run the whole system knowing six names. This design needs
    eight, plus 33 REASONS tags, 7 dispositions and a `Row` schema. The defence
    is that the tags are read and never memorised and that the *model* count
    falls from eleven to one — but a reader who counts nouns will count more
    nouns than before, and that is a real cost, not a rhetorical one. (33 tags,
    enumerated at the end of section 3.)

**Stated rather than solved — which is what those requirements ask.** A1:R-NOT-01
through A1:R-NOT-12, A2:R-DROP-01 through A2:R-DROP-11, A3:R-NOT-01 through
A3:R-NOT-16 and A4:R-SCOPE-01 through A4:R-SCOPE-08 are `explicitly-not-solved`
requirements: their content is "name this capability as absent, with its cost".
They are counted as covered because `Ledger.limits()` is exactly that naming and
carries the cost as a field. The sharpest of them is worth repeating here rather
than leaving in a table: **partial invalidation is not provided, so any commit
under `src/` or `ext/` stops the whole store hitting** — 1018 of 1931 commits
(52.7%) at `bc23d150`, 1032 of 1931 (53.4%) at this branch's HEAD, against a
finest-defensible-partition ~33%, i.e. roughly 5x more full re-solves. What that
bought is the deletion of five hand-maintained ownership lists and, with them,
the only failure in that family that serves a *wrong* number rather than losing a
hit. Revisit it by measuring re-solve hours, never by re-adding the map. And
A1:R-NOT-08 — nothing mechanically stops someone typing a literal instead of
quoting `ref` — is likewise met by saying so; the mechanisms that do exist are
the only-reader tripwire and the required derivation per row.

**Two corrections to claims in the tree, found while verifying this document.**

- `src/model/complete.jl:595` and `test/model/test_cache_stats_reported.jl:10`
  both say "28 named uncacheable counters" for ccache without pinning a version.
  The external audit measured 20 uncacheable-flagged plus 8 error-flagged (28) at
  v4.9-v4.11 and 21 plus 8 (29) at master. The claim needs its version. Reported
  second-hand and labelled as such — I did not read ccache's source.
- The 52.7% partial-invalidation price was measured at `bc23d150`: 1018 of the
  last 1931 commits. Re-measured on this branch's HEAD it is 1032 of 1931
  (53.4%). Both are true of their scope; quote the scope.

---

## 6. What changes in the tree

Steps 1-5 landed real machinery: 13 files under `src/model/` plus its umbrella
`src/model.jl`, one extracted resolver
(`src/workflow/experiments/pipeline/resolve_gs.jl`), one TOML
(`refs/matsui2025.toml`), 23 test files, 23 commits, and roughly 8,000 inserted
test lines. Almost all of it survives. The Ledger is a **re-facing plus two
additions**, not a rewrite — which is the point: if a unifying idea required
throwing the campaign away, it would not be the idea the campaign was paying
for.

### Survives as-is

| what | why |
|---|---|
| `src/model/identity.jl` — `code_tree_hash`, `CODE_TREE_DIRS`, the length-prefixed walk, the memo, `_code_rev_or_nothing` | The code half of a name, already total by construction and already a content hash computed on the node. Untouched. |
| `src/model/model.jl`, `specs.jl`, `field_specs.jl`, `environment_specs.jl`, `potential_spec.jl`, `model_waveform.jl`, `active.jl`, `io.jl` | The name must be a value; the encoder must refuse what it cannot represent. `_enc`'s fieldless-type refusal (`io.jl:67-77`) and `_enc_atom`'s enumeration from `fieldnames` are exactly M11. |
| `src/model/stage.jl` | `params::NamedTuple` hashed by construction; `backend` validated by calling `_resolve_backend`; `kind` closed. |
| `src/workflow/experiments/pipeline/resolve_gs.jl` and its three gates | One resolver, two consumers. M13 in full. |
| `test/model/*` (20 files), `test/analysis/test_resonance_dip_nonuniform.jl`, `test/validation/test_matsui2025_ref.jl`, `test/gpu/test_gpu_euler_warp_parity.jl` | Every one encodes a requirement that must stay true. None is deleted. |
| `src/workflow/validation/{specs,error_budget}.jl` — `CheckResult`, the control rule | `:indeterminate` IS `:no_control` in the check domain. No new guard type. |
| `_write_exit_summary`'s `"cache"` payload (`runner.jl:144-179`) | Already the histogram, already stamped on both exit paths. It widens; the shape is right. |
| `refs/matsui2025.toml` and `src/model/ref.jl` | 27 quantities (8 measured, 17 read-off, 2 reconstructed); `arbitrates` derived from a closed reference-side vocabulary since `633e74f4`. The three disqualifiers become three REASONS tags without moving a byte of the file. |

### Reinterpreted — same code, one name, one vocabulary

| what | becomes | why |
|---|---|---|
| `Admission` (`complete.jl:280`) | `Held` | It is *already* the one concrete struct that carries "did you get it / under what provenance / why". Renamed because when the same object answers "may I quote this" and "is this gate real", `Admission` is the wrong word. Renamed, not aliased, in one commit — CLAUDE.md convention discipline. |
| `Admission.provenance`'s 4 values | 4 members of `REASONS` | `:marked` → `ok` with no caveats; `:unmarked` → `:grandfathered` (group F); `:rejected` → the specific group-C tag; `:absent` → `:absent` (group B). The four-way split survives; it stops being its own vocabulary. |
| `no_artifact_id_reasons()`'s free-form strings | group-A tags | The set was already keyed per reason — better than "warns once" — but the reason was a message. It becomes a tag plus a `why` string, and the list becomes a slice of `ledger_counts()`. |
| `CORPUS_UNRESOLVED`'s 9 categories | 9 group-A tags, asserted a subset of `REASONS` | The per-config table stays in the test — it is data about the corpus, not about the design. Only the vocabulary is shared, which deletes the divergence risk without moving 78 rows. |
| `REF_DISQUALIFIERS` (3), `REF_PROVENANCES` (3) | group-D tags and caveats | `arbitrates` stays derived. `ref` keeps throwing at the quote boundary; the thrown object carries the `Held`. |
| `MarkerVerdict` + `require_converged` | `:verdict_short` | The knob is per call and the default stays byte-for-byte. |
| `MARKER_CUTOVER_UNIX` | the bound on the `:grandfathered` caveat | Verified: `git log -1 --format=%ct ce9721cb` = 1785580432. Unchanged. |
| design §4's 11 dropped items | `:dropped` rows | Section 4 becomes `Ledger.limits()`, a query. The prose becomes the row's `reason`. |
| `test_ambient_refs_vs_artifact_id.jl`'s `:moves` / `:blind` | `:named` / `:open` dispositions | Same measurement, same 7 rows, same pinned effects. |

### Must change

| what | change | cost |
|---|---|---|
| `src/model/identity.jl` | Factor `preimage(s::Stage)` out of `artifact_id`; `artifact_id(s) = content_id(preimage(s))`. **The dict is byte-identical to what is hashed today — no key added, none renamed, so no id moves and no artifact is invalidated.** | ~10 lines. This is the single highest-value change in the design. |
| the three marker writers | Write `<payload>.name.toml` (the pre-image) beside the payload, before the payload, after the attempt file. | One call per writer; the sidecar sorts after the payload under rsync exactly as the marker does. |
| `test_no_ambient_module_refs.jl`'s `ALLOWED` (16 rows) | Moves to `src/ledger/register.jl` as `REGISTER`, because an over-budget `:open` row must be readable at run time to refuse a binding. The scanner stays in the test and compares against it in both directions. | Editing the register now moves `code_tree_hash`, i.e. invalidates the store. That is **correct** — a change to what the system considers ambient is a change to what a run means. 16 rows, edited rarely. This is not circular: the scan is an independent statement derived from the source text, gated against a declaration, which is CLAUDE.md commitment 3's day-0 gated redundancy. |
| `src/model/claim.jl` | Gains the `:no_evidence` refusal. The file itself pins the hole at `claim.jl:33-40` and says closing it must be "a decision someone makes with the gap in front of them". | Four lines, and it makes `evidence = Stage[]` — the shape someone reaches for to declare a claim done before the computation exists — impossible. |
| all four `admit_payload` sites | Call `held`. | Mechanical rename; the sites are `experiment.jl:253`, `run_registry.jl:517`, `run_registry.jl:746`, `run_step_ground_state.jl:453`. |
| `_ADMISSION_COUNTS` (4 keys) | becomes `ledger_counts()` over the whole vocabulary | The lock, the copy-on-read and the process-cumulative scope are already right. |

### Not built here, and named as such

`:in_flight` and the atomic claim file; `Attempt` as a persisted append-only
record; `Change` as the declared performance/accuracy/correction class; the gate
domain (`GateDecl`) as executable rows rather than test-file discipline; and any
`:evolve` `Stage` producer — which is why the worked example in section 2 ends in
a refusal.

### One thing to keep in view

`held` returns one **concrete** struct, deliberately. `Union{Held, Refusal}` at
the GS admission site would put a small union in the return type of a function
whose result feeds `make_workspace` — the exact barrier where
`_gs_artifact_id` is annotated `@noinline` with `::Union{Nothing, String}`
(`run_step_ground_state.jl:362`) and where CLAUDE.md commitment 8 names the
30-minute inference hang. The existing `Admission` already has the right shape.
Do not widen it.

---

## Anchors

- Record behind this file:
  [`research_spec_and_provenance_architecture.md`](research_spec_and_provenance_architecture.md)
  — measurements, cutover log, deviations, corrections, canary passes.
- Adversarial audit: GitHub issue **#250** (two comments plus the seven-surface
  pass; 47 candidates, 15 survivors).
- Machinery: `src/model/` (13 files) plus `src/model.jl`,
  `src/workflow/experiments/pipeline/resolve_gs.jl`, `refs/matsui2025.toml`,
  `test/model/` (20 suites), `test/validation/test_matsui2025_ref.jl`,
  `test/analysis/test_resonance_dip_nonuniform.jl`.
- Verified against `633e74f4` on `feat/model-resolved-physics`, 2026-08-02.
  Every file:line in this document was opened.
