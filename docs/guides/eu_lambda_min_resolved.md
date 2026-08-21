# λ_min on the weak-field Eu branches — resolvable, and what actually limits it

> **FROZEN 2026-08-21.** A record of what was measured on that date, not a
> maintained document. Reproducible from the jobs named in §3 and the driver
> `scripts/eu_spectrum/precond_ab.jl`; the cells are #335's, under
> `runs/eu335/` on the TSUBAME group area (untracked).
>
> **Read §5 first if you want the answer.** The short version is that the
> eigensolver stopped being the limit and the *operator* became it — and the
> first pass of this campaign printed two "SADDLE — proven" lines that the
> finite-difference control then inverted.

Closes the measurement halves of #397 (which consumer owns the preconditioner
default) and #399 (can λ_min be certified on the polarised branch). Both were
opened by #383, which could not resolve λ_min with either solver and said so.

## 1. What was asked, and the premise that did not survive

#397 asked for an A/B of `trapped_bdg_low_modes`' preconditioner default
"across gate-2's consumers", on the stated ground that the function "is on
gate-2's stability verdict (`stability_spec.jl`, alongside
`trapped_bdg_lowest_eigenvalue`)".

**It is not.** `check(::StabilitySpec, ws, ψ)` calls
`trapped_bdg_lowest_eigenvalue` — a bare Lanczos, which takes **no `precond`
keyword at all** — and `trapped_bdg_low_modes` has exactly one consumer under
`src/`: `trapped_bdg_frequencies`, which uses its eigenVECTORS as a reduction
subspace and never reads the sign of λ. Changing the default therefore cannot
move a gate-2 verdict.

A grep is not a measurement, so the driver re-establishes it by **execution**:
the verdict is unchanged by the block's own knob, and it *does* move when the
Lanczos is starved (`pass` at `niter=120` → `indeterminate` at `niter=1`). The
script **refuses to draw the conclusion** if that positive control fails,
because "the block is not read" and "nothing is read" print the same negative.

## 2. Axes, and what is held fixed

¹⁵¹Eu F=6, κ = 1.8, 32³ × 13, box 24 a_ho, transverse pin ε = 0.002, DDI
unpadded, dealiasing off — i.e. exactly the Hamiltonian #335's cells were
converged in, because a stored ψ is only stationary under the one it came from.
Six cells: the polarised branch at **5, 20, 25, 60, 100 µG** (#399's list) and
the flower cell at **68.25 µG**, the last one before #335's continuation loses
the branch.

| axis | values |
|---|---|
| `precond` | `:kinetic`, `:combined` |
| `max_iter` | 200, 2000 |
| `nev` / `block` / `tol` | 4 / 10 / 1e-6 |
| FD step `ε` | **1e-5 and 3e-5** — the control §4 turns on |
| reference arm | Lanczos `niter=300`, no preconditioner — what gate-2 runs |

Every row carries `converged` and `width` beside `λ`. #383's lesson was that a
value one tenth of its own uncertainty is not a number, and this campaign is a
direct descendant of that.

## 3. The preconditioner A/B (#397)

Job 8453358, H100, same seed, `max_iter = 2000`:

| B [µG] | `:kinetic` | `:combined` |
|---:|---|---|
| 5 | not converged, 760 s | not converged, 763 s |
| 20 | not converged, 810 s | **converged, 1479 it, 584 s** |
| 25 | not converged, 812 s | **converged, 1241 it, 492 s** |
| 60 | converged, 1508 it, 605 s | **converged, 525 it, 202 s** |
| 100 | converged, 647 it, 271 s | **converged, 264 it, 103 s** |
| 68.25 | converged, 1288 it, 518 s | **converged, 401 it, 167 s** |

**5 cells certified against 3, 1.4–3.1× faster where both certify, never
slower.** Where both converge they agree — 15 digits at 100 µG, 7 at 68.25, 5 at
60 — so the "a preconditioner changes the iteration and not the spectrum" claim
that `test_bdg_low_modes_lobpcg.jl` gates on a 16-point 1D fixture also holds at
production scale.

**The gapped small problem, which was the one reason to expect a loss**
(`:combined` costs 2 extra FFTs and 2 multiplies per application, and on a
gapped state the kinetic metric is already the right one): 16 iterations /
0.041 s against 30 / 0.089 s. It wins there too.

The default moved to `:combined` on this evidence.

## 4. THE CONTROL THAT MATTERED: the solver is no longer the limit

The widths above go to ~1e-14. **That is the ITERATION converging on the
operator it was handed** — and that operator is a central difference of the
gated gradient with `ε = 1e-5`, whose own accuracy is nothing like 1e-14. So the
binding uncertainty moved from the solver to the discretisation, and a sign read
at |λ| ~ 1e-9 is a sign read below the instrument's floor.

Job 8453845 re-ran the converged arm at **ε = 3e-5**, everything else identical:

| B [µG] | λ_min @ ε = 1e-5 | λ_min @ ε = 3e-5 | \|Δ\| | \|λ\| / \|Δ\| | verdict |
|---:|---|---|---|---:|---|
| 5 | −3.77e-08 (not conv.) | −3.21e-08 (not conv.) | — | — | solver does not certify |
| 20 | **+4.004393e-07** ± 7e-15 | **+4.071208e-07** ± 2e-14 | 6.7e-09 | **60** | **MINIMUM** |
| 25 | **−1.7726e-09** ± 1e-14 | **+5.4713e-09** ± 2e-14 | 7.2e-09 | **0.8** | **UNRESOLVED — the sign inverts** |
| 60 | **−8.8764e-09** ± 6e-15 | **+8.4580e-09** ± 7e-15 | 1.7e-08 | **0.5** | **UNRESOLVED — the sign inverts** |
| 100 | +7.159467e-02 ± 7e-08 | +7.159481e-02 ± 3e-07 | 1.4e-07 | 5×10⁵ | **MINIMUM** |
| 68.25 (flower) | **+7.621335e-08** ± 3e-10 | **+8.366418e-08** ± 3e-10 | 7.5e-09 | **11** | **MINIMUM** |

**The first pass printed "SADDLE — proven" for 25 and 60 µG. Both inverted.**
They were not saddles; they were numbers below the finite-difference floor being
read as though they were above it, by a driver whose own convergence line said
`converged = true` — truthfully, about the solver.

The `|λ| / |Δ|` column is the whole content of this section. A `converged`
eigenvalue whose ε-sensitivity exceeds it carries no sign.

## 5. Answers

**#399 — can λ_min be certified on the polarised branch?** Yes, with the
distinction the control forces:

- **The SOLVER certifies 5 of the 6 cells** (all but 5 µG), with widths of
  1e-14 to 3e-10. That is new: #383 had λ_min = +1.68 with a Kato–Temple width
  of 5.7 from the block and +0.056 ± 0.47 from 300 Lanczos iterations, i.e. a
  value one tenth of its uncertainty in both instruments.
- **The OPERATOR resolves the SIGN at three of them**: 100 µG (λ_min =
  7.1595e-02, unambiguous), 20 µG (60× the ε-spread) and the 68.25 µG flower
  cell (11×). All three are **minima along every direction the block resolves**.
- **25 and 60 µG stay unresolved**: |λ_min| ≲ 1e-8 against an ε-spread of the
  same size. They are consistent with λ_min = 0 — a Goldstone direction, which
  is what a pinned polarised state should have — and are **not** evidence of a
  saddle.
- **5 µG is out of reach** of a 2000-iteration block: the softest cell, and the
  one where `:combined`'s advantage also vanishes.

So **#335 §5.2's two-sided form is answered where the curvature is large enough
to see, and the answer is MINIMUM** — at 20 and 100 µG. Nothing here supports
the polarised branch being a saddle at any field measured. The one-sided result
#383 already had (⟨d,Ad⟩ = +0.908 at 25 µG toward the flower branch, i.e. a
barrier) is unaffected: it needs no certificate.

**#398 — is 68.4 µG a spinodal?** This campaign's most useful by-product. At
68.25 µG, the last flower cell before the continuation loses the branch,
**λ_min = +7.6e-08 to +8.4e-08, converged, positive, and 11× its own
ε-sensitivity.** At a saddle-node the state's lowest curvature passes through
zero; here it does not. Together with #383's three non-softening quantities
(branch-tangent curvature extrapolating to 78.2 µG, escape direction +3.403
uphill, lowest ω flat to 1.4 %), the ledger row
`eu335-68p4-is-a-mean-field-spinodal` stays **superseded**, and the replacement
— *the field at which a warm-started continuation loses the flower branch* —
now has a converged λ_min behind it rather than only an inference.

**#397 — whose default is it?** Nobody's, in the sense the issue meant: no
gate-2 verdict can move. It is a question about `trapped_bdg_frequencies` and
about which Hessian modes get resolved, and on that question `:combined` wins on
every cell and on the gapped fixture. Default changed; `:kinetic` kept as the
other side of the equivalence gate.

## 6. What this does NOT settle

- **The FD floor itself is not characterised**, only bounded by a two-point
  comparison. Two ε values give a difference, not a convergence order; a third
  would say whether the O(ε²) scaling the central difference promises is what is
  actually seen here, and until then the `|Δ|` column is a sensitivity and not
  an error bar.
- **`nev = 4`.** Every "MINIMUM" above is *along every direction the block
  resolved*. A negative direction outside a 4-dimensional subspace would be
  missed, and the Ritz spreads (6.7e-4 at 5 µG rising to 6.9e-2 at 100 µG) show
  the bottom is a cluster at low field — which is exactly where a larger `nev`
  is both more necessary and more expensive.
- **One seed, one grid (32³), one pin (ε = 0.002).** #383's own systematics
  section applies unchanged.
- **The 5 µG cell has no answer at all**, and is the honest floor of the method
  as it stands.
