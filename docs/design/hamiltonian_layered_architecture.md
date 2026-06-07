# Hamiltonian architecture — flat core: dumb reference + AD (SSoT)

Status: **adopted 2026-06-05, reoptimized + FROZEN 2026-06-06**.
This document is the single source of truth for the `src/hamiltonian/`
redesign. **Freeze discipline: further changes to this design require a
bug or a measurement** — not a framing preference. (Three full
revisions in 24 h was itself a defect; the substance was ~80% invariant
across all three, and the churn was in packaging.)

Ruling on architectural commitment #3 (anko, 2026-06-06; CLAUDE.md
amended): the runtime-speed target *forces* the mechanism choice —
interpreter evaluation cannot reach production speed, and a
physics-codegen layer is a thesis-scale detour with a new whole-system
bug surface. Therefore: **guarantee preserved (zero silent drift),
mechanism updated** (single declaration → day-0 gated redundancy). Not
an abandonment of #3 — the same guarantee by a different mechanism.

The generative/categorical packaging of the previous revision
(initial-algebra/catamorphism framing, atom signature, profunctor-optics
θ-views, declaration-interpreter) is **removed on amortization
grounds**: the physics is fixed, the project is thesis-scale, and terms
are added a few times in a lifetime — the generative machinery never
pays for itself. Every bug-catching *discipline* it carried survives in
flat form (§7 continuity table).

Empirical ground for the pivot: every historical bug in this codebase
(Barnett, Coriolis, GPU-energy omission, transverse inversion,
GAP-1/2, B1 self-referential parity, B3 no-op coverage, 220× gradient,
warm-restart, reference-rhs rot) was caught — or would have been — by
five flat disciplines: **independent oracle, per-term granularity,
canary, order/parity slopes, convergence gating**. None by abstraction.

Companion (executable): `docs/design/term_oracle_bootstrap.md` — §1–§3
(canonical gradient pin, estimator set, FD ε-valley) remain authoritative
and are shipped (`test/oracles/test_term_properties.jl`); its later steps
re-base onto the dumb reference below.

Scope ruling (2026-06-05): main Workspace path. `rotating_basis_*`,
`combined_spin_step`, `force_gradient`, scalar/binary GP, TDHFB are
oracle-obligated design boundaries, not part of this core.

## 0. Mission pull

- **SBI (spine H)**: infer 7 unknown ¹⁵¹Eu scattering channels. The
  forward map must carry zero *structural* uncertainty — the residual
  uncertainty is exactly the physical uncertainty of θ_free.
- **c₁ calibration (thesis-blocking)** + σ(c₁): needs ∂(observable)/∂θ
  and Fisher information.
- **Bogoliubov/BdG**: currently a fifth hand-restatement of H; should
  derive from one trusted statement.
- **Papers + thesis**: quoted numbers must be structurally unable to
  bypass convergence + oracle gates.

## 1. Trust architecture: redundancy is the oracle

Three artifacts, one chain:

```
physics anchors  →  dumb reference (+ AD)  →  production fast kernels
(closed forms,       (blatantly correct,        (FFT / fused / GPU,
 directional          tiny grid, pure)            hand-tuned)
 oracles)
```

- **Production**: the fast kernels — FFT-based, fused diagonal, GPU.
  Hand-tuned; untouched by default.
- **Dumb reference**: the full energy, RHS (H_eff·ψ), and propagator
  written in the most obviously-correct way — explicit loops, dense
  matrices, direct convolution sums, no FFTW, no shared helper code
  with production. Tiny grid only; zero performance budget. **Trusted
  because dumb.** Writing each term twice (dumb + fast) is not a DRY
  violation — in numerical kernels *redundancy is the oracle*; DRY
  (single declaration) deletes exactly the redundancy that catches
  sign/factor/omission bugs. Flat + duplicated beats elegant + DRY in
  this domain.
- **AD over the dumb energy** `E(ψ, θ)` supplies the generativity the
  previous revision sought structurally: gradient (LBFGS parity),
  Hessian (BdG linearize), ∂/∂θ (SBI / Fisher Jacobians) — automatic
  for every term, because AD does not care about term count. The dumb
  side is pure and mutation-free **by design**, so AD applies where it
  never could on production (mutation, FFT plans). Engine:
  **ForwardDiff-first** (reinterpret ψ to a real vector; loop-robust,
  no adjoint rules; gradient at n ≈ 3×10³ real dims ≈ seconds — fine
  for test tier). Zygote is the optional fast path, not the
  foundation — it is fragile on scalar-indexed loops, which is exactly
  what dumb code is. Hessians restricted to ≤ 1D-8 / 2³ grids
  (ForwardDiff-of-grad or FD-of-grad). All test-tier; **production
  gradients stay hand-written** (AD is too slow at production scale on
  either side) and are gated against AD-on-dumb at tiny grids.
- **Master oracle**: dumb vs fast agree per-term AND in total on random
  tiny inputs at tight tolerance. This single check kills the sign,
  factor-of-2, missing-term, and fusion bug classes — the majority of
  the historical record.

Two hard rules that keep the chain honest:

1. **Discretization pinning.** Dumb implements the *same discrete
   mathematics* as production: spectral kinetic via a dense DFT matrix
   built from first principles (`exp(−2πi·jk/N)`, same fftfreq
   convention), the same Q(k) DDI kernel on the same k-grid, the same
   m-ordering (c=1 ↔ m=+F). Independence lives in the **expression**
   (loops, dense, no shared helpers), never in the math — otherwise
   tolerances rot into "approximately agrees" (the historical LHY
   5e-2 disease).
2. **Day-0 CI gating.** `validation/reference_rhs` — the previous
   dumb-ish artifact — rotted (transverse sign) precisely because its
   comparison never ran gated. The dumb reference is registered in a
   runtests tier from its first commit; disagreement with fast is red
   the moment it appears.

And one honest caveat: "dumb ⇒ trusted" has exactly one failure mode —
confidently stating the wrong convention. The existing
declaration-independent physics anchors cover it (user-spec Zeeman
sign oracles, Larmor precession, Gauss-Hermite ground state, the
directional suite). They pin the dumb side to physics; the dumb side
pins production to the dumb side.

## 2. Propagator reference

- **Linear-term subsets: dense `expm`.** Build the full Hamiltonian
  matrix on the tiny grid and exponentiate. Exact — catches Strang
  ordering, basis, and fusion bugs simultaneously.
- **Full nonlinear evolution: dumb RK4** at tiny dt as the reference
  trajectory. Frozen-H expm is only O(dt²)-consistent when H depends
  on ψ, so the two are paired, not conflated: expm for exactness on
  linear subsets, RK4 for the nonlinear update path.
- **Order slopes**: split-step global error vs the RK4 reference,
  slope ≈ 2 (Strang) / 4 (Yoshida) on the log-log fit — the order bug
  class (MPS-4 collapse) is a slope assertion.
- **Dense H_eff[ψ] dividend**: building the frozen-field operator
  matrix column-by-column makes Hermiticity and pairing structure
  *literal matrix checks* (‖H − H†‖, second-variation symmetry as
  matrix symmetry). The operator-class taxonomy and the standing
  four_step_chain step2 mean-field puzzle dissolve at the dense level.

## 3. Flat structure

- **θ**: one plain concrete struct {c-couplings, B⃗, Ω, trap ω's, c_dd,
  loss rates, …} owned by the Workspace; coefficient use is `coeff(θ,
  t)`. SBI free/fixed split = an index mask over θ. No optics, no lens
  laws. Provenance and hashing stay at the spec layer
  (`content_id(spec)`); θ never gets its own hash (a second hash
  source is a dual-SSoT smell). SBI proposals flow `θ_free → spec
  override → content_id`, reusing CAS.
- **Registry**: the existing term list (one `Vector`/tuple of names);
  dumb and fast both key off it by name. **Set-equivalence meta-test**
  (one assertion): dumb and fast each cover every registry term ∧
  every term has ≥ 1 independent oracle ∧ every `test/oracles/` file
  appears in exactly one runtests tier. This is the anti-B3 /
  completeness guarantee — no initial algebra required. **In a
  detection design this meta-test is the single load-bearing beam**
  (an ungated statement = the old rotted reference_rhs), so it is
  itself canaried: removing a term from the dumb side in a sandbox
  must turn the meta-test red, asserted in the suite.
- **Oracles**: a flat list of checks, looped per term, **reported per
  term** (aggregate green hides per-term rot).
- **Gate**: any pipeline that produces a paper-bound number asserts
  `converged ∧ oracle-green` and throws otherwise — a thin wrapper,
  not a type system.

## 4. Disciplines (all cheap, all design-independent)

**Two comparison classes — never conflated.** Identity-class: fixed
input, tight tolerance (energy, RHS, gradient, fused == unfused —
commuting-diagonal fusion is mathematically exact). Limit-class: the
propagator face — split-step *legitimately* differs from dense expm /
RK4 by its O(dt²) Strang error, so the oracle is a **dt-valley**:
slope ≈ order on the log-log fit = healthy, plateau = bug (the
fd_valley machinery lifted from h-space to dt-space). Writing the
propagator gate as tight-tol would make normal O(dt²) and a sign bug
look identical. Side benefit: a fwd/bwd V-chain asymmetry (a term
added to one mirror only) breaks time-reversal symmetry and collapses
the measured order — the slope test gates the hand-mirrored pair
end-to-end without consolidating it.

Equally not conflated: **correctness thresholds vs performance
thresholds.** `fused == unfused` is tight-tol correctness; **±2% is a
performance criterion** for whether a fusion is worth keeping — they
share nothing.

| discipline | instrument |
|---|---|
| dumb-vs-fast, per-term + total | master oracle (§1), identity-class |
| AD-vs-FD ε-valley; AD-vs-hand parity | `test_term_properties.jl` (shipped: valley, driver ×2, dV both sides) |
| canaries | harness canaries (shipped: planted ×2, sign flip) + mutant table: sign, ×2, conj-swap, drop, F_x↔F_y, dV-drop — each with expected-red mapping; a mutant turning nothing red fails the suite; meta-test canary (§3) |
| order slopes | split-step vs dumb RK4 / dense expm (§2), limit-class dt-valley |
| parity | resume == straight; CPU == GPU per term (tolerance, not bit); F32 == F64 (~1e-5); alloc == 0 in hot loops; basis round-trips |
| conservation, commute-gated | norm / energy / M_z / J_z checked **iff every active term commutes** (boolean per term): full DDI → J_z only; secular DDI → + F_z (the secular approximation's content, machine-checked); Loss → norm gate off |
| KNOWN-LIMIT gaps, loud | AD-on-dumb produces gradients production lacks (Tensor, Raman) — the dumb-vs-fast gradient gate *legitimately* fails there, so the gap is declared per term and `energy ≠ 0 ∧ gradient ≡ 0` is a loud error at LBFGS entry, never a silent wrong landscape. AD makes the gap visible; the policy makes it loud |
| Euler factor | `energy_factor = 2/d` derived from homogeneity degree; guarded by the scaling oracle `ε(λψ) = λ^d ε(ψ)` (free, F-independent; mixed-degree terms fail by construction) |
| convergence gating | quoted numbers require `‖∇E‖`-gated states (never disk-cached gate status — fresh re-eval; M1 lesson) |

## 5. Magnitude + identifiability (non-retrofittable; design-independent)

**dumb-vs-fast cannot catch absolute coefficient errors** — both sides
consume the same θ, so a magnitude-rotted c_S agrees consistently. More
generally, dumb-vs-fast is blind to **convergent errors** (both sides
written from the same wrong belief). The honest trust ledger has three
columns:

| column | terms / regime | what protects them |
|---|---|---|
| dumbness = obviousness | kinetic, trap, Zeeman family, c₀/c₁, local LHY | master oracle alone (the "80% dies here" claim is true HERE) |
| dumb is still subtle | DDI (Q(k) kernel, zero mode), Coriolis (shear), Raman (phase), frame conventions (ω_R) | physics anchors — directional/closed-form, **regime-limited to known analytics** (EdH, prolate-oblate, secular limit, Larmor) |
| **no independent anchor exists** | the unknown 7 channels — the SBI target regime itself | **Fisher identifiability is the only guard.** No oracle of any class reaches here; a convergent error in this column survives everything except a well-conditioned I(θ) and the CG structure gate |

The third column is the bottom of the blind spot and the reason the two
instruments below are non-retrofittable and early:

- **CG projection-structure oracle — SHIPPED**
  (`test/oracles/test_cg_projection_oracle.jl`, 16/16): the structure
  of `coeff(θ) → c_S` triple-anchored — literature inverse forms (Ho /
  Ohmi-Machida F=1, Kawaguchi-Ueda F=2), KU-λ_S vs Wigner-6j
  cross-route, and channel_kernel (TDHFB CG statement) ≡ GP mean field
  at F ∈ {1,2,3,6}. Kills the rank-vs-channel class (`ip[n] ≠ g_S`
  gotcha). Absolute a_S stay unknown — that is physics (the SBI
  target), not a bug.
- **Fisher identifiability — the instrument PREEXISTED**:
  `src/analysis/fisher.jl` (`fisher_jacobian` / `fisher_information` /
  `identifiable_directions`), written for the Eu SBI Sprint-2 question
  and carrying the prior-aware absolute cutoff (the relative-cutoff
  trap) + Cramér-Rao posterior σ. A duplicate was briefly created and
  deleted 2026-06-06 (caught by the repo sweep; lesson: grep for prior
  art first). Preflight anchors:
  `test/oracles/test_fisher_identifiability.jl` — linearity
  identities, θ-valley certification, degenerate-protocol detection
  (E_total-only ⇒ rank 1), channel-space chain through the T-CG map.
  Catches "the experiment cannot constrain the physics" — a protocol
  bug no code oracle sees. Dynamic observables: 2·n_θ forward runs per
  protocol point, TSUBAME-parallel.

## 6. Build order

1. **Day 0–2**: θ struct + registry keying + **dumb reference** (full
   energy + RHS, tiny grid, dense DFT matrix; dense expm + RK4
   propagator references).
2. **Day 2–3**: AD over dumb → grad/step; **master oracle** (dumb vs
   AD; dumb vs fast per-term as fast hooks in) + canaries. The
   majority of the historical bug classes die here.
3. Next: order slopes / parity / conservation-with-commute-gate +
   convergence-gate wrapper.
4. Next (early, non-retrofittable): **Fisher identifiability** (CG
   already banked).
5. Consumers as plain functions, each shipped with an independent
   anchor: Bogoliubov = AD-Hessian (anchor: FD-Hessian + uniform-gas
   closed form ω(k)=√(ε_k(ε_k+2gn)) + Goldstone zero modes); Fisher =
   AD-∂θ (anchor: FD-in-θ valley; coefficient-linearity `∂H/∂c = H/c`
   is *checked*, never declared — ω_trap enters as ω² and must plateau
   to the FD anchor).

Stage 0 of the audit era (oracle registration, the 9 live defects,
GPU host-shadow energy adapter, padded-DDI verdict, perf baseline)
remains valid and proceeds alongside; the dumb reference subsumes the
role previously assigned to a `reference_rhs` 14-slot extension.

**Sequencing note for the dumb reference**: build the 11
non-subtle terms first and collect the master-oracle payoff; dumb DDI
(dense DFT + Q-tensor restatement + zero mode + m-ordering) is its own
1–2-day unit, paired with its physics anchors (§5 ledger column 2) —
it is the one term where "Day 0–2" was optimistic.

**The performance architecture is the next design layer** (own doc):
this document fixed correctness; the speed target itself — GPU
split-step, memory layout, fusion plan, KernelAbstractions
single-sourcing (which collapses the most expensive duplication,
CPU-vs-GPU, reducing effective statements to ~2: dumb + KA kernel),
N_cells batching, F32 stepping + F64 reductions — is designed
separately, with the §4 performance-layer oracles (dt-valley,
fused==unfused, F32==F64, alloc==0, CPU==GPU) as its gates. First
decision there: memory layout (highest retrofit cost).

## 7. Continuity — what survives from previous revisions

| survives (substance) | removed (packaging) |
|---|---|
| independent-oracle hierarchy / canary / per-term coverage | catamorphism, initial algebra, atom signature |
| AD as derivative source (grad / Hessian / ∂θ) | profunctor optics, lens laws |
| order / parity / round-trip checks | "everything is a functor" framing |
| dumb reference as the mechanical anchor | declaration-interpreter (E1) — replaced by dumb ref, which is independent at BOTH statement and execution level (strictly stronger) |
| θ single struct + convergence gate | θ-view algebra |
| Euler 2/d + scaling oracle | energy_factor as a declared trait |
| CG oracle (shipped) + Fisher identifiability | — |
| conservation commute-gate (boolean per term) | Symmetry type hierarchy |
| canonical gradient pin + dV clause + FD valley (shipped) | — |

Shipped artifacts unaffected by the pivot:
`test/oracles/test_term_properties.jl`,
`test/oracles/test_cg_projection_oracle.jl`,
`test/helpers/{fd_gradient,oracle_fixtures}.jl`, the four_step_chain
comment fix, the audit + defect list (Appendix A).

## 8. Constraints carried

- Registry stays type-stable on the production side (`NTuple`); no
  `Dict{Symbol,Any}`, no closures toward Workspace; θ is a concrete
  struct. Test-side fixtures may hold closures (cold path).
- `@noinline _step_dispatch!(@nospecialize(step), …)` firewall
  untouched. D=13: `Matrix`/`MVector` in hot loops.
- Production kernels replaced only behind a **correctness gate**
  (tight-tol / bit-identity, class-appropriate per §4) AND a
  **performance gate** (≤ baseline +2% measured at 24³×D=13) — two
  separate gates, never one mixed criterion.
- Dumb reference: tiny grid only, exempt from performance discussion,
  pure (AD-able), no FFTW dependency, no helper sharing with
  production.
- N_cells = runtime axis; F32 = realization parameter (dumb stays F64).

## 9. Out of scope

- TDHFB ↔ GP engine unification (parallel by design). The coefficient
  layer is shared and now CG-oracle-backed.
- Error-optimal splitting schedules from measured commutator norms
  (spine E horizon).
- Full BdG-consumer migration beyond Bogoliubov (follows the AD-Hessian
  consumer, scheduled by physics arcs).

---

## Appendix A — audit verdict + live defects (2026-06-05, Stage-0 inputs)

**Verdict**: trinity real on energy (CPU, B1) and gradient (B2/B3.5);
fictional on the propagator face (12/14 terms via legacy
`_outer_operators_fwd!/bwd!` + fused diagonal; per-term `apply_step!`
test-only); GPU energy still the hand-enumerated ext fork
(`gpu_energy.jl:88-211`, shape drifted: CPU has `:loss`, GPU lacks it);
trinity oracle suite was unregistered (fixed for
`test_term_properties.jl` + `test_cg_projection_oracle.jl`; 5 files
remain, each registered with its fix commit); registry-parity tests
self-referential post-B1. Dead decorations: `_h_matrix`,
`_density_sign`, `_spin_sign`, `_kinetic_sign`, `EnergyContext` (zero
callers); `fd_directional_grad` half-written.

**Verified live defects** (status as of 2026-06-06: 1-8 FIXED with
day-0 gates, 9 open):

1. FIXED — `LHYTerm.apply_step!` → `apply_lhy_step!` undefined
   (`terms/lhy.jl:13`); `TensorTerm` → `apply_tensor_step!` undefined +
   stale singlet signature (`contact.jl:259,262`).
2. FIXED — GPU + active c2/tensor crashes on `psi_mf` kwarg
   (`split_step.jl:672-688` vs `gpu_singlet_pair.jl:39`).
3. FIXED — `RamanTerm.energy_contribution` MethodErrors on
   `TimeDependentRaman` (raw `ws.raman`, no `raman_at` resolution).
4. FIXED — `reference_rhs` transverse Zeeman sign opposite to
   production. Triply unseen: bx=by=0 test defaults AND
   `reference_total_energy` summed the diagonal only AND a stale file
   header. Gate: transverse-active regression in
   `test_reference_rhs.jl` (energy + operator level).
5. FIXED — ω_R ≠ 0: registry energy/gradient evaluated lab-frame H
   while the propagator applies the rotated H. Registry and dumb
   reference now apply the RF model independently (p_eff = p − ω_R;
   (bx, by) rotated at t). Gates: master-oracle fixture R, RF
   dt-valleys, and the end-to-end `split_step!` one-step residual vs
   `dumb_rhs_total` (the dt-valley alone does NOT reach the production
   propagator — pre-fix both its faces were lab-frame and it passed).
6. FIXED — ITP propagated without MagneticGradient (`mg_active=false`)
   while the registry gradient includes it. Gate: ITP displacement
   regression in `test_magnetic_gradient_gap.jl`.
7. FIXED — CPU/GPU `energy_decomposition` shape divergence (`:loss`).
8. FIXED — `zeeman_at(::TimeDependentZeeman)` lossy collapse —
   `combined_spin_step` transverse path structurally dead. Gate:
   directional d⟨Fy⟩/dt = bx⟨Fz⟩ regression in
   `test_combined_spin_step.jl`, red-check measured (pre-fix revert
   fails exactly the fix-dependent assertions).
9. FIXED — padded-DDI 2D/3D crop. CONFIRMED bug (10-agent numeric
   workflow, both refutations stood): commit `fc937c69` (2026-05-10
   batched-gemm rewrite) replaced `for I in CartesianIndices(n_pts)`
   with linear `phi_x[i]` in `_ddi_compute_angles!`, so the CPU
   propagator read the first `N_spatial` linear elements of the
   2×-padded Φ — full padded columns into the pad region for ndim ≥ 2
   (2D error 0.255, 3D 0.264; 1D accidentally correct; GPU and the
   padded energy face crop correctly). Root fix: `_ddi_crop_phi`
   (rotation.jl) crops Φ to psi's `[1:n...]` corner before the angle
   loop — zero-copy on the unpadded hot path (size == n_pts). Method 2's
   latent CPU-scalar branch switched to the crop views. Gates: 2D/3D
   marker-parity (padded-Φ rotation ≡ cropped-Φ rotation) + a dumb
   zero-padded RHS dt-valley (`dumb_rhs_ddi_padded` /
   `dumb_ddi_potential_padded`), both red-checked. Blast radius zero:
   no YAML key, default `false`, no `runs/` config enables it.
   SCOPED KNOWN-LIMIT (not silently wrong, just half-plumbed): with
   `ddi_padding=true` the padded convolution reaches only the
   propagator — the CPU/GPU energy faces and the LBFGS gradient face
   use the unpadded kernel, and `split_step_combined!` now REFUSES a
   padded context loudly rather than silently running unpadded. Full
   energy/gradient padding is deferred until a caller needs it.

**Post-audit additions (2026-06-07).** The redundancy audit upheld an
absorbing-boundary live bug (loss+absorbing epilogue applied on
`split_step!` but OMITTED by the leapfrog / Yoshida / adaptive drivers;
`run_simulation!` → leapfrog, so a production `dynamics:
{absorbing_boundary}` built the mask and discarded it). Root fix:
`apply_rt_dissipation!` binds loss+absorbing inseparably; all 7 sites
route through it. **Blast radius ADJUDICATED = ZERO** (provenance, not
assumed): no `runs/` config enables `absorbing_boundary` (the
matsui_edh baseline configs don't), the turn_15 "absorbing-boundary at
m=−6" is the analytic master-equation spin-ladder terminal (unrelated
to the spatial mask), and the turn_74/t81 mentions are the schema
validator's key-list in error messages from runs that FAILED config
validation (no jld2). The earlier commit-message claim that
"Matsui-EdH runs configured an absorber" was an overstatement (grepped
"absorbing", assumed spatial) — corrected here.

**SpinC1 single-source defect (found by the master-oracle self-canary).**
Gradient face `_grad_c1_spin!` read `ws.interactions[1]` while the
energy face used `term.c1` — a coefficient-SOURCE violation (distinct
from the sign class). Blast radius ZERO: `build_h_terms_registry`
(registry.jl:102) and the legacy energy path always construct
`SpinC1Term(ws.interactions[1])`, so the two sources are equal in every
production path; the gradient always read the right value. Mechanism
worth recording: **FD-valley sees energy↔gradient consistency at the
test point** (green where both sources hold the same value); **the
self-canary sees responsiveness to the canonical source** (flip
`term.c1` ⇒ must propagate). A single-source violation where both
sources agree at the test point is FD-valley-invisible, canary-visible.
The canary is a CLASS guard (every active numeric-field term gets the
source-responsiveness check; CoriolisTerm exempt as ws-locked; fieldless
terms read one ws source so no parallel-source risk exists).

**Resume scope-corrections (verifier, 2026-06-07):**
- The F32 reduction measurement (pairwise sum ~1.6e-8) and the parity
  gate (`test_mixed_precision.jl`) are **CPU**. P2's real body is the
  **GPU** reduction (tree vs atomic differs by orders); the CPU "no
  problem" does NOT inherit. When P2 is built, measure the GPU reduction
  on a production grid under the same c0=200 cancellation stress.
- **Stage 3 defer rationale**: NOT "no target bug" — the SpinC1
  single-source violation IS the motivating bug a type-enforced
  single-source would PREVENT. The correct rationale is the same
  detection-not-prevention trade as commitment #3: the self-canary
  already gives detection, and the 23-param-Workspace JIT-cascade risk
  of inner-constructor enforcement outweighs the prevention benefit.

**Design tensions** (resolution targets): verification vacuum; GPU
energy fork; fictional propagator face; protocol expressiveness
(psi_mf / t_eval / dt-cache); coefficient residence (→ θ); +4%
fused-kernel trap (master oracle pins the fused kernel instead of
deriving it); five parallel propagator universes (scope ruling); flat
namespace + objectid-keyed global caches; KNOWN-LIMIT policy
inconsistency (loud/silent/crash → one gated rule: energy ≠ 0 with
gradient ≡ 0 must be loud under LBFGS entry); docs one era behind.
