# Term property oracles — derivative bootstrap, symmetry declarations, canary harness

Status: **adopted 2026-06-05**. Companion to
`docs/design/hamiltonian_layered_architecture.md`: this executes Stage 0
items 1–3 and pulls two pieces of Stage 1 forward to day-0 — the symmetry
trait and the two-argument operator action — because they are data-model
constraints that cannot be retrofitted onto an API that shipped without
them.

Layering rule that resolves "design D vs implement A first": **D is the
data-model constraint the operator API carries from day 0** (the
declaration part is what cannot be retrofitted); **the derivative-oracle
bootstrap is the first executable code** (the root of the oracle chain).
The bootstrap therefore bakes the symmetry declaration into its term
fixture as a required field, and both land together.

Everything here is seconds-tier and gates every commit.

## 1. Canonical gradient pin (one convention, stated once)

All derivative comparisons in this codebase reduce to ONE canonical
object. Factor-of-2 and conjugation bugs live exclusively in ambiguity
about it, so it is pinned here and the harness enforces it:

- **Canonical gradient** `g ≡ δE/δψ̄` as a **per-voxel density** — no
  `dV`, no Wirtinger ×2. This is what `apply_operator!` returns and
  `add_gradient!` accumulates (spine-A convention; `‖∇E‖ =
  √(Σ_k |g_k|² dV)`).
- **Dynamics**: `i ∂_t ψ = g` (GP form, ℏ = 1).
- The LBFGS driver's ×2 (real-parametrization Wirtinger scaling) is a
  *driver* property, covered by its own one-line oracle — never folded
  into a term face.
- **Discrete FD relation** (the harness formula; `E` is the discrete
  energy, `dV` the cell volume):

  ```
  g_k = [ ∂E/∂Re ψ_k + i · ∂E/∂Im ψ_k ] / (2 · dV)
  ```

  Derivation: `E` real ⇒ `∂e/∂ψ = conj(∂e/∂ψ̄)`; discrete
  `∂E/∂ψ̄_k = g_k · dV`. **The `dV` clause is load-bearing**: on test
  grids with `dV ≠ 1` an unpinned `dV` is exactly the kind of factor a
  sloppy tolerance silently absorbs.
- **Complex-step differentiation is excluded**: `E = ⟨ψ|H|ψ⟩` contains
  conjugation and is not holomorphic. FD uses real central differences
  on Re/Im separately.
- **Directional form used in practice** (cheap — 2 energy evaluations
  per h per direction, never componentwise): for a random direction δ,

  ```
  dE/dh |_{ψ+hδ, h=0} = 2 · dV · Re⟨g, δ⟩
  ```

  compared against central differences of `E(ψ ± h δ)`.

## 2. Estimator set (reference-agnostic harness; AD off the critical path)

The harness compares members of an **estimator set** rather than
hard-wiring "AD vs hand":

| estimator | source | availability |
|---|---|---|
| `handgrad` | production `apply_operator!` | day 0 |
| `FD` | ε-swept directional central differences (§3) | day 0, dependency-free |
| `reference` | the **dumb reference** (arch doc §1: full energy/RHS, explicit loops, dense matrices, no FFTW, independent at both statement and execution level); until it lands, `validation/reference_rhs/` Zeeman-family slots + closed-form anchors | dumb reference: build-order Day 0-2; reference_rhs interim after the transverse sign fix (arch doc App. A defect 4) |
| `AD` | Enzyme (optional plug-in) | admitted only after passing its own §3 valley |

Pairwise tolerance classes:

- **identity-class** (`rtol ~ 1e-10..1e-12`): pairs that compute the
  same mathematical object through independent code on the same grid —
  `handgrad` vs `reference`; later `AD` vs `handgrad`. An identity that
  only agrees to 1e-6 is a different formula or a bug.
- **valley-class**: any pair involving `FD` — primary oracle
  `min_h rel_err < 1e-7`, diagnostic slope ≈ +2 (§3).

Why AD is a plug-in and not the cornerstone of week 1: production energy
bodies mutate (`fft_buf`, in-place reductions) ⇒ **Zygote cannot
differentiate production faces**; Enzyme is the candidate but carries
FFTW-plan + 23-type-param-Workspace risk. The original bootstrap logic
("step0 makes the reference trusted, so later disagreement convicts the
hand side") is preserved and strengthened: the ε-scaling valley is
computed **per comparison**, so plateau-vs-valley separates real bug from
truncation in *every run*, not only at bootstrap time. Enzyme's
admission gate is §3 verbatim, run against `AD` instead of `FD`.

## 3. step0 — derivative-reference trust bootstrap (ε-scaling valley)

A single-h FD comparison mixes truncation error with real bugs. Sweep h
over decades and classify the shape:

- **healthy reference**: `|ref_dir_deriv − FD(h)|` is
  truncation-dominated at large h (central differences ⇒ log-log slope
  ≈ +2, decreasing as h→0), reaches a roundoff floor near
  `h ~ ε_mach^{1/3}` with minimum `~ ε_mach^{2/3} ≈ 4e-11` — a
  **valley**.
- **bugged reference**: the disagreement is a true derivative mismatch ⇒
  h-independent **O(bug) plateau**, no valley (a 2× factor plateaus at
  ~0.5 rel, a sign flip at ~2).

Oracles (both cheap):

1. primary: `min_h rel_err < 1e-7` (4 decades of margin over the F64
   floor).
2. diagnostic: slope fitted over the large-h band `≈ +2` (asserts the
   valley exists, i.e. the comparison is in its trust region).

Scope: per term, on **off-manifold random complex fields** (unnormalized
— manifold projection is the optimizer's concern and is tested there,
not here), plus a small set of structured states (FM, polar seeds) so
symmetry-canary floors (§6) have guaranteed signal. Fixed RNG seed.

## 4. step1 — derivative consistency per term (functorial over the registry)

Quantified as a single property over the registry — adding a term makes
it apply automatically; "1 covered, 10 silently no-op" is structurally
impossible:

- identity-class: `handgrad` vs `reference` (rtol 1e-10).
- valley-class: `FD(E)` vs `handgrad`.

This is where the quartic factor-of-2 class dies: for
`E_int = (g/2)∫|ψ|⁴`, the derivative is `g|ψ|²ψ` (the ½ and the 2
cancel); a hand side of `(g/2)|ψ|²ψ` is immediately red against either
reference. Energy is the Source of Truth; the hand gradient is its
mirror — never invert that direction.

**Documented blindness (this is why §8 exists).** Post-B1 several
`energy_contribution` bodies are *derived from* `apply_operator!`
(e.g. `contact.jl:43-48`). For such terms `FD(E)`-vs-`handgrad`
verifies the homogeneity structure but is **blind to the shared
coefficient**: `E = ½c⟨ψ, nψ⟩dV` derived from `g = c·n·ψ` satisfies the
variational identity *for any c, including the wrong sign*. The
independent anchor of §8 is therefore load-bearing, not decorative.

## 5. step2 — operator symmetry (SUPERSEDED MECHANISM, same property)

> **Superseded 2026-06-06 by the flat revision** (arch doc §2): the
> dumb reference builds the frozen-field operator as a **dense matrix**
> (column-by-column on the tiny grid), so Hermiticity, pairing
> structure, and second-variation symmetry become literal matrix
> checks — `‖H − H†‖`, complex-symmetry of the anomalous block,
> symmetry of the FD Hessian. Consequences:
>
> - the **two-argument `apply_operator!` protocol addition is
>   dropped** — no production API change needed; the dense dumb
>   matrix carries the oracle role;
> - the **`operator_class` trait is dropped** — dense checks classify
>   empirically (Hermitian / conjugate-linear / dissipative emerge
>   from the matrix, not from a declaration that could lie);
> - the physics content stands: mean-field potentials (`n`, `f`,
>   `Φ_DDI`, LHY densities) are real ⇒ frozen H Hermitian; the singlet
>   pairing action is conjugate-linear (`δE/δψ̄_m ∝
>   A(r)·(−1)^m ψ̄_{−m}`) ⇒ test second-variation symmetry, not
>   sesquilinear Hermiticity; Loss is non-Hermitian by spec ⇒
>   directional oracle `d‖ψ‖²/dt ≤ 0` at positive rates.
>
> The standing mean-field step2 failures in the existing 4-step chain
> were a classification problem (it compared `H[ψ]ψ` against `H[φ]φ` —
> different frozen fields); the dense-matrix mechanism dissolves the
> problem instead of taxonomizing it.

## 6. Symmetry declarations + conservation derivation (D burned into the data model)

Trait (production side; type-stable tuple, evaluated against ws because
some declarations are value-dependent — e.g. trap isotropy):

```julia
symmetries(term::HamTerm, ws) -> Tuple{Vararg{Symmetry}}
```

Day-0 catalog (deliberately small; Parity / Translation / TimeReversal
deferred):

| Symmetry | generator / action | derived invariant |
|---|---|---|
| `GlobalPhase` | `ψ → e^{iθ}ψ` | norm |
| `SpinZ` | `e^{−iθF_z}` | M_z |
| `OrbitalZ` | `e^{−iθL_z}` | L_z |
| `TotalZ` | `e^{−iθ(L_z+F_z)}` | **J_z** |

Load-bearing declarations:

- **`LossTerm` does not declare `GlobalPhase`** ⇒ the norm-conservation
  spec auto-disables when loss is active. The "add a symmetry-breaking
  term and the suite starts lying" failure mode dies in the same
  mechanism for norm as for M_z.
- **Full DDI declares `TotalZ` only** (conserves J_z, neither F_z nor
  L_z). **Secular DDI additionally declares `SpinZ` and `OrbitalZ`** —
  separate F_z conservation *is* the physical content of the secular
  approximation. The declaration difference between the two DDI modes
  is the approximation, made machine-checkable.
- Isotropic trap declares `OrbitalZ`; anisotropic does not
  (ws-dependent branch — acceptable type instability, oracle/cold path
  only).

Derivation consumed by `ConservationSpec` (which already carries
`norm_drift` / `energy_rel_drift` / `Jz_drift`): an invariant is active
iff **every active term declares the corresponding symmetry** —
intersection over the active registry. Energy is bounded-drift iff no
term is explicitly time-dependent and the integrator is symplectic.

Two-sided oracle (the declaration is test-backed; a false declaration
is red):

```
declared g:    |E_T(e^{−iθĝ}ψ) − E_T(ψ)| < TOL          ∀ sampled θ, ψ
undeclared g:  ∃ sampled ψ, θ:  |ΔE_T| > FLOOR            (canary side)
```

**Energy-invariance under the exact group action is the primary form**,
not the operator commutator: for nonlinear terms `[T, ĝ]` is
ill-defined, and the frozen-field commutator is *not* the conservation
statement (frozen H may commute at special ψ while the energy is not
invariant). The group action is exact and cheap (spin rotations via the
existing rotation builders; L_z rotations via grid rotation on tiny
grids or the derivative variant). Fast derivative variant:
`|2·dV·Im⟨ĝψ, g⟩| < TOL`. Linear terms may additionally run the
operator commutator (tighter).

## 7. step3 — mutation canaries (anti-tautology)

Mutants are wrapper terms over production terms
(`MutatedTerm{T}(term, mutation)`) delegating with a face-level
mutation. **Fixture: an all-terms-active workspace with O(1)
coefficients** — a term contributing zero in the fixture makes its
mutants invisible (the historical "term contributes zero in aggregate
test" blind spot).

| mutation | must turn red |
|---|---|
| coefficient sign flip | step1 identity pair + symmetry canary (one side) |
| **coefficient ×2** | step1 identity pair — *not* FD-consistency for derived-energy terms (§4 blindness; this row is the regression test for that blindness) |
| transpose / stray conjugation in off-diagonal blocks | step2 |
| term drop (face returns 0) | step1 + symmetry oracle |
| `F_x ↔ F_y` swap | step2 + symmetry |
| `dV` dropped in energy | step1 valley-class |
| conj-swap (`ψ ↔ ψ̄` in one face) | step1 (the Wirtinger class) |

The harness owns the `mutation → expected_red` map and asserts both
directions: every expected oracle fires, and — the meta-alarm — **a
mutant that turns nothing red fails the suite as a no-op-oracle
detection** (the generalization of the weakened-parity-test incident).

## 8. Independence rule + completeness meta-oracle

**Independent anchor** := an oracle whose reference value is computed
**without executing any production face of the term**. Qualifying:
`validation/reference_rhs/` slot, closed-form analytic value (Gaussian /
known-state energies), directional physics oracle. Not qualifying:
FD-of-derived-energy (§4), registry-vs-registry comparisons (the B1
tautology), any pair whose both sides flow through `apply_operator!`.

`meta_completeness` asserts, over the registry:

1. every term has ≥ 1 independent anchor;
2. every file under `test/oracles/` appears in exactly one
   `test/runtests.jl` tier list (absorbs arch-doc D5 — an unregistered
   oracle is a failing meta-test, not a silent orphan).

## 9. Collapse gate

A term may *collapse* (its legacy kernel deleted, a face derived, a
trinity migration shipped) iff:

```
step1 ∧ step2(class-appropriate) ∧ symmetry(two-sided) green
∧ all of its canary mutants fire as expected
∧ it has an independent anchor (§8)
```

The gate is a pure function over property results, asserted in CI per
term — the term-level smart constructor, and the rehearsal for the
atomic `{ψ, E, ∇E, gate}` object (spine G).

## 10. Consolidation map (do not write a fifth harness)

ε-scaling, Hermiticity, and a canary existed in
`test_operator_trinity_four_step_chain.jl` (e1001d30) — **absorbed and
DELETED 2026-06-06**: its step0 monotone heuristic was
roundoff-fragile for exactly-quadratic energies (superseded by
`valley_scan`'s `:exact_floor` classification), its step1 used the
pick-closer factor heuristic (superseded by the Euler-derived factor +
master-oracle identity), its step2 blanket Hermiticity was
conceptually wrong for mean-field terms (compared `H[ψ]ψ` against
`H[φ]φ`; linear-face Hermiticity now lives in the master oracle,
mean-field/pairing second-variation symmetry per §5 is an open item),
and its two canaries are covered by the harness canaries here
(registry-wide mutant table per §7 is an open item). The FD harness
previously existed in four near-copies (`test_operator_trinity_per_term.jl`,
`test_term_consistency.jl`, `test_magnetic_gradient_gap.jl`, the
deleted chain). Week 1 is **consolidate + complete + register**, not
greenfield:

- new `src/validation/fd_gradient.jl` — directional FD estimator with
  ε-sweep + valley/slope diagnostics (reusable by scripts;
  `scripts/m1_per_term_gradient_audit.jl` becomes a thin caller).
- new `test/helpers/oracle_fixtures.jl` — random/structured state
  generators, the all-terms-active workspace, `TermFixture`, mutant
  wrappers.
- new `test/oracles/test_term_properties.jl` — steps 0–3 + symmetry +
  collapse gate + `meta_completeness`, registered in the `ci` tier.
- each absorbed property deletes its old statement **in the same
  commit** (no-alias rule applies to tests too).

Production-side additions are traits only — `operator_class`,
`symmetries`, the two-argument `apply_operator!` — as plain functions on
HamTerm subtypes. **No `Function` fields, no `Vector{Term}`, in
anything that flows toward Workspace** (oracle-side `TermFixture` may
hold closures; it lives in test code, cold path).

## 11. Week-1 execution order

1. `fd_gradient.jl` + fixtures + step0 valley on three representative
   terms (Kinetic and LinearZeemanZ — quadratic, expect exact-floor;
   DensityC0 — quartic, expect a slope-2 valley). The Pairing class has
   no step0 pair (gradient face KNOWN-LIMIT nil) and enters at step2
   via second-variation symmetry.
2. Canonical-pin oracles: driver ×2 (one line) + a deliberate-`dV≠1`
   grid in the fixture set.
3. step1 across the registry. Known defects will trip here — LHY/Tensor
   `apply_step!` undefined calls, Raman `TimeDependentRaman`
   MethodError (arch doc §2 defects 1, 2, 4): fixing them is part of
   going green; that is the gate working, not a detour.
4. `reference_rhs` transverse sign fix (after confirming nothing
   silently compensates) + Zeeman-family identity pairs live. (The
   14-slot extension is dropped — the mechanical all-term anchor is
   the dumb reference, arch doc §1 + §6.)
5. step2 with `operator_class` + the two-argument protocol addition.
6. `symmetries` trait + two-sided oracle + `ConservationSpec`
   derivation.
7. Canary harness + `meta_completeness` + collapse gate; register
   everything; the runtests meta-test.

## 12. Budgets

Tiny grids (1D/2D allowed; ≤ 8³ spatial × D = 13), directional FD only
(2 energy evals per h), ~8 h-decades, tens of random + 4 structured
states, per term. Target: **whole suite < 60 s CPU at `ci` tier**; the
representative-term step0 subset < 10 s for the `fast` tier. Gates
every commit.

## 13. What this unlocks

- Trusted derivative references with per-run bug/truncation separation
  → later optimizer (C), preconditioner (D), composer (E) oracles have
  ground truth.
- The hand-grad factor-2 / conjugation class is dead on arrival.
- Conservation laws are declared + verified data (`symmetries` ∩ active
  registry → `ConservationSpec`), so adding a symmetry-breaking term
  reconfigures the checks instead of invalidating them — including the
  secular-vs-full DDI distinction and loss-vs-norm.
- No-op oracles cannot recur: unregistered files, mirror-collapsed
  comparisons, and never-firing canaries are each a failing meta-test.
- Enzyme/AD can be admitted later through the same valley gate without
  re-architecting anything.
