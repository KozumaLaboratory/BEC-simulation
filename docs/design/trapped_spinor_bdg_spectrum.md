# Excitation spectrum of a trapped spinor condensate — the ω instrument

Closes #339. What was missing was not a sweep but an instrument: no BdG path in
this repo could produce the excitation spectrum of a trapped 13-component
texture, so "the Bogoliubov excitations of the chiral / magnetic-vortex phase and
a Bragg prediction" had no way to be computed. This document records what was
built, the two decisions #339 required to be written down, what is certified, and
what is not.

Instruments: `trapped_bdg_frequencies` (`src/solvers/bdg_frequencies.jl`) and
`bragg_response` (`src/solvers/bragg_response.jl`).
Gates: `test/oracles/test_trapped_bdg_frequencies.jl`,
`test/oracles/test_bragg_response_spectrum.jl`.

## 1. The wall, and the category error behind it

Three BdG paths existed:

| path | why it cannot answer |
|---|---|
| `bogoliubov_spectrum` | uniform spinor only — its signature has no spatial argument, so a flower / chiral spin-vortex texture is not representable |
| `trapped_bdg_spectrum` | dense, `dim_cap = 4000` against `2·32³·13 = 851,968` |
| `trapped_bdg_low_modes` | the only 3D/D=13 path, but it returns eigenvalues of the constrained HESSIAN, and those are not frequencies |

The third row is the one that matters, and #339's first acceptance criterion —
"the low eigenvalues of `trapped_bdg_low_modes` must agree with
`bogoliubov_spectrum` near k = 0" — cannot be satisfied as literally written,
because the two are different objects.

`energy_gradient!` is `2·δE/δψ̄`, so the gated `hessian_vector_product` is
`Hδ = 2(L_op δ + M_op δ̄)` and the constrained operator is `A = P(H−2μ)P`. For a
real background the sectors decouple: `A₊ = 2(L−μ+M)` on real δ (density-like,
stiff), `A₋ = 2(L−μ−M)` on imaginary δ (phase-like, soft). In the uniform scalar
limit

    λ₊ = 2(εk + 2gn),   λ₋ = 2εk,   ω = √(εk(εk+2gn)) = √(λ₊λ₋)/2.

So `λ₋ ∝ k²` where `ω ∝ k`. Reading the Hessian's soft eigenvalue as a spectrum
does not report a slightly wrong phonon branch, it reports a QUADRATIC one. No
tolerance reconciles that, which is why it is a category error and not an
approximation. Both halves are pinned in the `λ is NOT ω` testset: the identity
`ω = √(λ₋λ₊)/2` (0.467436 out of λ₋ = 0.616850 and λ₊ = 1.416850, F=1 polar box)
and the exponents (doubling k multiplies λ₋ by exactly 4 and ω by less than 2.5).

## 2. Decision 1 — how the ω axis is reached

The linearised GP in the frame of `ψe^{−iμt}` is `i∂_tδ = ½Aδ`, i.e.
`∂_tδ = J(½A)δ` with `Jδ = −iδ`. Under the Hessian's own real inner product
`⟨a,b⟩_R = Re∫ā b`, `J` is antisymmetric and `A` symmetric: a real Hamiltonian
system, eigenvalues in `±iω` pairs. Two facts make the reduction cheap:

1. `J` is multiplication by `−i`, so ANY complex-linear span is J-invariant. The
   complexification `span_R{X_k, iX_k}` of the soft Hessian eigenvectors carries
   the symplectic structure exactly.
2. A soft mode's stiff partner is `i ×` itself — exactly so in the uniform limit,
   since the phase mode `i·e^{ikx}ζ` and the density mode `e^{ikx}ζ` differ by
   `i`. **The complexification supplies the `λ₊ ≈ 4c₀n` partner without the
   eigensolver ever climbing to `λ ≈ 4c₀n`**, which at Eu production
   (`c₀n ≈ 2343`) it cannot.

So: solve for `n` soft Hessian modes with the existing preconditioned LOBPCG,
complexify, orthonormalise, and diagonalise the `m×m` real generator
`M_ij = ½⟨Sᵢ, J A Sⱼ⟩_R = ½ Im ∫S̄ᵢ(A Sⱼ)`. Eigenvalues are `γ ± iω`: `ω` the
frequency, `γ` the dynamical growth rate. Cost above the Hessian solve: `m ≤ 2n`
operator applications. One complex inner product per matrix element gives both
the reduced Hessian (real part) and the generator (imaginary part).

**What is certified.** The Hessian side keeps its per-mode Kato–Temple two-sided
bounds. The symplectic reduction has none: what is reported per mode is a
FULL-SPACE residual of the mode equation — a necessary condition, not an
interval. Say "residual", not "error bar". Three further necessary-not-sufficient
diagnostics are reported and are the things to read before trusting a number:
`j_min` (is the subspace really J-closed), `pair_residual` (did the `λ ↦ −λ`
symmetry survive), `hessian_symmetry_defect` (the finite-difference floor of the
whole construction, since the operator is a central difference of the gated
gradient).

## 3. Decision 2 — S(k, ω) by real time, not by BdG linear response

#339 requires one path and the reason. **Real-time impulse response.** Reasons,
in order of weight:

1. The BdG route needs the eigenbasis COMPLETE in ω at fixed k. A Bragg peak sits
   on the stiff density branch `√(εk(εk+2c₀n))`, far above what an iterative
   low-mode solver certifies; building `S(k,ω)` from `trapped_bdg_frequencies`
   would silently truncate the spectral weight. The complete eigenbasis is the
   dense path, i.e. the `dim_cap` wall again.
2. Real time needs no new operator, no eigensolver, no convergence certificate:
   one unitary kick, then the already-gated propagator. D=13 in 3D works because
   `split_step!` works.
3. It is what the experiment measures — a phase grating imprinted, the density
   response read out — so a disagreement with the lab is physics, not a
   difference of definitions.

Method: the δ-pulse limit of a Bragg lattice, `exp(−i·A·cos(k·r)·O)` applied
once at `t=0`, then evolution under the unperturbed Hamiltonian and a Fourier
transform of `δn_k(t)`. Every ω in one run. `O = 1` probes the density channel,
`O = F_z` the longitudinal spin channel (both diagonal, so the kick stays a
per-voxel phase).

The price is spectral resolution instead of eigenvalue precision: the peak is
located to `Δω = 2π/T`. `omega_resolution` is returned and **a quoted peak must
carry it**; with the default Hann window the effective main lobe is ~2 bins. The
two instruments therefore split the axis: the eigen path owns the soft end (where
`Δω` would need an impractical `T`), real time owns the Bragg window.

`_analyze_bragg_spectroscopy` stays as it was — static `S(k)` — with a docstring
that now says it is the ω-integral and that a roton cannot be read off it.

## 4. Acceptance criteria, with the measurement

All numbers from the gate files, F=1 polar uniform box (n=16, L=8, c₀=1, c₁=0.2,
n₀=1, `dk = 2π/L`), 2026-08-19.

| #339 criterion | status | measurement |
|---|---|---|
| positive control first: uniform limit ≡ `bogoliubov_spectrum` | done, on the ω axis | every trusted ω matches a homogeneous box-mode eigenvalue to < 1e-6; spin branch 0.467436 (4-fold, ±k × 2 magnons) and density 0.843787 (2-fold) reproduce the closed forms exactly |
| `nev` extended, residuals reported | done, PER MODE | `converged_modes`, `widths`, `residuals`; at nev=8 the whole block is < 1e-6 and modes 9–10 of a nev=10 run come back at residual 0.61 / 0.99 — the reduction reports its own edge instead of hiding it |
| F=1 polar spin branch vs a known closed form | done | `√(εk(εk+2c₁n))`, exact to 1e-6; the DDI arm additionally shows the anomalous block moving the branch (a polar state has ⟨F⟩ = 0, so nothing else can) |
| Goldstone handling stated per mode | done | the polar box gives exactly TWO ω≈0 modes, labelled `zero_mode_spin_x/y` with overlap 1.0 on both degenerate generators; the gauge column is < 1e-6 for every mode, which is the evidence `P` deflated `ψ` and `iψ` rather than the labeller mistaking them for physics |
| one S(k,ω) path, gated, with the reason | done | real time (§3); peak lands on the analytic branch within one bin in both channels, with channel selectivity (cross-channel weight < 1e-15 of on-channel), linearity (weight ×4 for amplitude ×2, peak unmoved to < 0.1 bin) and a zero-kick control |
| which phase, what prediction | §7 | κ = 1.8 flower branch vs κ = 0.9, at the #335 spinodal |

Labels are computed on DEGENERATE BLOCKS, not per mode: inside a multiplet the
eigenvectors are basis-arbitrary, and the F=1 polar zero block is 4-dimensional
(two broken generators × their symplectic partners), so a per-mode overlap there
is an artefact of what LAPACK returned. `blocks[k]` says which modes share a
label, and that is the resolution the classification has.

### 4.1 Scale — measured at D = 13 in 3D

The claim that motivated the whole issue is that neither existing path reaches a
trapped 13-component 3D texture. Measured 2026-08-19, ¹⁵¹Eu F=6 (D=13), uniform
polar `e₀` in a periodic 3D box (L=8, c₀=1, c₁=0.2, n₀=1), `nev=6`,
`max_iter=25`, CPU:

| grid | BdG dim `2NP` | `trapped_bdg_frequencies` | `bragg_response` (T=100) |
|---|---|---|---|
| 8³ | 13,312 | 17.7 s | 14.1 s |
| 16³ | 106,496 | 60.8 s | 33.4 s |
| 24³ | 359,424 | 199.3 s | 145.7 s |

The dense path's `dim_cap` is 4,000, so 24³ × 13 is 90× past that wall and both
instruments run there. `j_min = 1.0000` and `pair_residual ≤ 4.5e-12` at every
size. `bragg_response` returned peak `0.838621` at ALL THREE grids — identical,
against the analytic 0.843787 with `Δω = 0.06283`, i.e. 0.08 bins off and
grid-independent (norm drift 2.1e-14 at 8³ to 1.1e-12 at 24³).

**These numbers are a MEASUREMENT, not a gate.** The CI oracles run at F=1 in 1D;
nothing in the suite exercises D=13 in 3D for either instrument, so the scale
claim rests on the table above and re-measuring it is a manual step. Gating it
would cost ~18 s (8³) for `bragg_response`, and for the eigen path it also needs
the F=6 null manifold dealt with first — which is the next paragraph.

**And the eigen path found a physics obstacle worth stating.** At F=6 the polar
`e₀` state has a LARGE k=0 Hessian null manifold — far larger than F=1's
two-dimensional one — so `nev=6` lands entirely inside it: six modes at ω < 1e-5
and nothing physical. The reduction did not hide this (the residuals came back
enormous), but it means **an F=6 polar spectrum needs the null manifold dealt with
first**: raise `nev` past it, deflate it via `extra_nullspace`, or gap it with
`q > 0`. This is also what exposed the residual-scale degeneracy fixed in §5 —
when every returned mode is a zero mode, the block's spectral scale is itself
zero, and the floor `max(|A_red|)/2` is what keeps the number meaningful.

## 5. A bug this found in the existing LOBPCG

`A = P(H−2μ)P` annihilates its own projector's null space (`ψ`, `iψ`) exactly. So
if that direction re-enters the working basis, the solver reports it as an
eigenvalue 0 with a residual of ~1e-10 — **a spurious mode carrying a perfect
convergence certificate**, which `trapped_bdg_frequencies` would then have
published as a physical Goldstone.

It did re-enter. `_mgs_ortho`'s normalising division `w ./ nw` is an amplifier,
and the LOBPCG basis `[X, W, X_prev]` becomes near-dependent as it converges
(‖W‖ → 0, X ≈ X_prev). Measured on the uniform F=1 polar box, `max|⟨ψ,S⟩|` ran
3e-16 → 1.5e-14 → 2.3e-13 over six iterations — geometric, reaching O(1) well
inside `max_iter = 80`. The polar box then reported **4 null modes where it has
2**, all four with residuals ~1e-10, plus one junk mode at residual 1.1.

Invisible at `nev=1` on a gapped state, which is all the existing gate asked for.
The fix re-projects each normalised basis vector (`_mgs_ortho(...; refine=…)`),
holding the leak at roundoff for one projection per vector. Regression:
`no spurious null-space modes at large nev / max_iter`.

The same restructuring moved the Rayleigh–Ritz pass to the END of the LOBPCG
loop, so the reported `(λ, residuals)` always describe the RETURNED vectors; the
previous for-form expanded the block after its convergence test and a run that
ended at `max_iter` returned values one step behind its own basis.

## 6. KNOWN-LIMITs

**The homogeneous DDI BdG disagrees with the gated operator.** Under DDI the
uniform-limit containment against `bogoliubov_spectrum` fails by ~3 %: at
c_dd = 0.05 the trapped spin quartet splits to 0.456306 / 0.488935 where the
homogeneous path gives 0.451721 / 0.474220. The two TRAPPED paths — dense
`trapped_bdg_spectrum` and the new reduction, independent solvers over the same
gated operator — agree with each other to 3.7e-7, so the disagreement is not in
the new instrument. `test_bogoliubov_anchor.jl` states its own KNOWN-LIMIT: it
gates the CONTACT BdG only. Deriving the second variation of
`E_DDI = (c_dd/2)∫∫Q(M,M)` with `M_a = ψ†F_aψ` gives a normal block with two
terms,

    c_dd Q_ab M_a⁽⁰⁾(F_b)  +  2c_dd Q_ab (F_aψ)_m conj((F_bψ)_m′),

and `_bdg_ddi_matrices` carries only the first. For a polar state `M⁽⁰⁾ = 0`, so
the homogeneous normal DDI block is entirely absent exactly where a spin-roton
prediction would look. Not fixed here: that path feeds the phase-diagram
stability verdicts (`triple_point.jl`, `test_level4_*`), so a factor change needs
its own campaign. Recorded as `@test_broken` in the gate, so whoever fixes the
homogeneous side is told by an unexpected pass. Filed as #361.

**Which axis.** `growth` (Re λ of the reduced generator) is the DYNAMICAL axis —
does a perturbation grow. The Hessian's `λ_min` sign is the ENERGETIC axis — is
ψ a minimum. A state can be energetically marginal and dynamically unstable. Say
which one a claim is about, every time.

**LHY.** The spectrum inherits `∂²ε_LHY/∂n²`. `lhy_active` is reported so a
spectrum cannot be silently attributed to a mean-field Hamiltonian it was not
computed with. #337 closed with the scheme ambiguity bounded at ≤ 6 % in
ε_LHY itself, but that bound is on the energy, not on its second derivative —
quote a spinor-LHY spectrum as scheme-dependent until someone measures the
curvature.

**The soft manifold is still the adversary.** Weak-field Eu + DDI has
`κ ≥ 4.7e3` with `λ_min ≤ 3.0e-2` still falling. The low modes are a CLUSTER, so
raising `nev` degrades the Hessian side first: `hessian_converged` is the gate on
a production number, not `omega` looking reasonable. The kinetic-only
preconditioner does not capture interaction-dominated stiffness (`c₀n ≈ 2343`)
and its advantage is NOT realised at Eu production scale — that limitation is
unchanged by this work.

**Trap-broken symmetries.** `bdg_symmetry_generators` includes translations and
rotation about z. For a uniform state the translation generator is identically
zero (`∂ψ = 0`), so that column is 0 for a reason that has nothing to do with
orthogonality. Do not read a zero overlap there as a measurement.

## 7. What to predict, and where

#335 closed with the κ-dependent hysteresis loop replaced by a discrete
deliverable: sweep `B_z` DOWN (≈90 → ≈20 µG, ≳17 ms) at two trap aspect ratios
and count occupied Zeeman levels — κ ≈ 1.8 spreads over 6–7, κ ≈ 0.9 stays at
3–4, no overlap across five rates. The falling leg was chosen because `J_z` is
conserved there for both κ. That fixes the target for a spectrum:

**Target: the κ = 1.8 flower branch just below its spinodal, B = 68.4 ± 0.15 µG
(32³; [68.0, 68.5] at 64³), against the κ = 0.9 single branch at the same field.**

Two predictions, both discrete, in the spirit of preferring an observable with no
error bar:

1. **A mode crosses zero at the spinodal.** #335 located 68.4 µG by continuation
   — the field at which the flower branch ceases to exist. The spinodal of a
   metastable branch IS where its lowest excitation reaches zero, so
   `trapped_bdg_frequencies` must find `ω → 0` (and the Hessian `λ_min → 0`) at
   that same field, on a branch located by a completely different method. Same
   number from continuation and from the spectrum, or one of the two is wrong.
   The κ = 0.9 branch must NOT show a zero crossing anywhere in the window (it is
   a single branch — nothing to lose stability to).
2. **The spin-channel line count follows the level count.** A state spread over
   6–7 Zeeman levels supports more resolvable magnon lines than one confined to
   3–4. Count lines above a fixed `peak_contrast` in `bragg_response`'s spin
   channel at fixed k, on both branches.

Neither has been computed. Both need production-scale runs (32³ × 13 with a
converged flower seed from the #335 library) and belong to their own campaign;
what #339 delivers is the instrument that makes them computable, plus the
statement of which (κ, B, branch) they are about — so the next session does not
have to rediscover the target.

Before either is quoted, the five pre-compute gates apply, and one of them binds
hard here: the field axis carries a ±10 nT (0.1 µG) published systematic, so a
prediction pinned to 68.4 µG must state that its resolution claim is 0.15 µG at
32³ and that the systematic is comfortably below it. Prefer a statement about
the *existence* of the zero crossing over its exact field.
