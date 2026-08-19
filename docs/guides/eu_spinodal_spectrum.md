# Does the spectrum see the spinodal? — the κ=1.8 flower branch end, measured a third way

> **PRE-REGISTRATION, written 2026-08-19 BEFORE any compute.** §1–§4 are the
> axes, the systematics, the instrument calibration and the rejection criteria,
> fixed in advance so the interpretation is not chosen after the runs finish.
> §5 is filled in by the runs and names the job that produced each row. §6 is the
> answer. This file is the campaign's contract with itself; if a number below
> moves, it moves in §5 with its run name, not in §1–§4.

## 1. What is being asked, and why it is worth the compute

#335 located the end of the κ = 1.8 flower branch by **continuation**: walking
converged cells upward in B until the branch stops existing, at
**B_sp = 68.4 ± 0.15 µG** (32³; [68.0, 68.5] at 64³ — 0.2 % agreement). That is a
statement about where a *solver* can still find a state.

A spinodal is also a statement about the **spectrum**: the metastable minimum
merges with a saddle, so the lowest eigenvalue of the constrained Hessian passes
through zero there. Generically it is a fold, giving

    λ_min ∝ √(B_sp − B)   ⇒   λ_min² is LINEAR in B with a zero at B_sp.

So the same field is predicted by two methods that share no machinery: one asks
"can L-BFGS still converge here", the other asks "is the second variation still
positive". **If they disagree, one of them is wrong**, and that is worth knowing
before either is handed to an experiment.

#339 built the instrument that makes this askable at 13 components in 3D
(`trapped_bdg_frequencies`, `trapped_bdg_low_modes`; `docs/design/trapped_spinor_bdg_spectrum.md`).

It also closes an open question. #335 §5.2 — "is the polarised branch a minimum or
a saddle?" — is marked *in flight* and is answered there by two INDIRECT
instruments, each blind in a documented way: HOLD is blind to an instability
slower than the hold, REMIN is blind to sliding along a flat direction. The
constrained Hessian answers it directly and with a two-sided certificate, and it
is blind to neither.

## 2. Axes, and what is held fixed

Every axis carries at least two points. The instrument axes are here for the same
reason as the physics ones: a λ_min near zero is exactly where a finite-difference
Hessian and an iterative eigensolver are least trustworthy, so their effect is
measured rather than assumed.

| axis | points | what it separates |
|---|---|---|
| **B** (κ=1.8 flower, up-branch) | 20, 40, 55, 60, 65, 67, 68, 68.25 µG | the spinodal approach — the axis under test |
| **branch** | flower (`branch_k1.8_up_g32*`) and polarised (`branch_k1.8_dn_g32`) | #335 §5.2: is the polarised branch a minimum at low B, where a ramp converts? |
| **κ** | 1.8 and 0.9 | the control. κ=0.9 has ONE branch (crossover), so nothing may cross zero |
| **FD step ε** | 1e-5 and 3e-5 | whether a small λ_min is physics or the Hessian's own finite-difference floor |
| **eigensolver budget** | (nev 6, max_iter 40) and (nev 10, max_iter 80) | whether λ_min is solver-limited. Per-mode `converged_modes` + Kato–Temple `widths` are recorded for every cell either way |

Held fixed, and load-bearing — these are #335's settings and they must not drift,
because **a state converged under a different Hamiltonian is not stationary under
this one** and its λ_min would be measuring that mismatch:

- 32³, box 24, κ = ω_z/ω_⊥ ∈ {1.8, 0.9}, **unpadded DDI**, secular off, q = 0,
  **LHY off**, pin ε = 0.002 p-units = 0.1352 µG (the pin is part of the
  Hamiltonian and stays in it for the Hessian).
- Cells are the #335 outputs on TSUBAME, `runs/eu335/branch_*`; each carries its
  own (B, pin) and the c₀/c₁/c_dd epoch assertion `load_cell` already enforces.

**Mean-field only.** LHY is off, matching #335. Every number here is a mean-field
spectrum and `lhy_active=false` is recorded per cell to keep that attributable.

## 3. Systematics, stated before residuals

- **Field axis:** the published residual-field systematic is ±10 nT = **0.1 µG**.
  No B_sp claim from this campaign may be quoted tighter than that, no matter what
  the fit's formal error says.
- **Continuation's own resolution:** ±0.15 µG (the 0.25 µG step that bracketed
  [68.25, 68.50]). The comparison target is therefore a **0.15–0.3 µG band**, not
  a point.
- **DDI kernel:** unpadded carries a 2–5 % field error, but #335 measured it as
  common-mode in exactly this difference — B_eq moved 0.20 µG (0.33 %) between
  kernels. It is inside the band above, so it does not decide anything here.
- **Finite-difference floor:** the Hessian is a central difference of the gated
  gradient, so λ_min has a noise floor of order the `hessian_symmetry_defect`
  reported per cell. A λ_min below its own cell's floor is not a measurement of a
  small number; it is the floor.

## 4. Instrument calibration and rejection criteria — fixed before launch

**Calibration (the run refuses to write results without it).** A stability
instrument that can only return "stable" proves nothing — the degenerate-knob trap
in yet another costume, and #335's own stability script says so in as many words.
So the driver first measures a state whose answer is known:

- **positive control** — F=1 polar at c₁ < 0 is a stationary SADDLE (the FM branch
  is lower; a pure m=0 seed keeps L-BFGS on the polar critical point). λ_min must
  come back **< −0.1**. If it does not, this instrument cannot currently detect
  instability and no verdict below is quoted.
- **negative control** — the same fixture at c₁ > 0 is a genuine minimum. λ_min
  must come back **≥ −1e-6**. If it does not, the instrument calls minima saddles
  and its "unstable" verdicts are worthless too.

**Rejection criteria.**

1. **Stationarity gate.** A cell is quoted only if `‖g − 2μψ‖ < 1e-4`. On a
   non-stationary ψ neither μ nor λ_min means anything — this is the
   `stability_verdict_from_nonstationary_point` class and `StabilitySpec` already
   refuses it. Failing cells are reported as `:indeterminate`, never dropped
   silently.
2. **Convergence gate.** λ_min is quoted only with `converged_modes[1] == true`;
   otherwise the Kato–Temple `width` is reported in its place and the cell counts
   as unresolved. #50's failure was a still-falling λ_min hidden inside a
   plausible value.
3. **The softening claim.** "The branch end is visible in the spectrum" requires
   λ_min at 68.25 µG to be **smaller than λ_min at 20 µG by ≥ 3×**, and monotone
   in between to within each cell's certified width. If it is not, the claim
   FAILS and that is the reported result.
4. **The agreement claim.** Fit λ_min² = a(B_sp − B) over the flower cells with
   B ≥ 55 µG. The spectrum agrees with the continuation if
   `|B_sp_fit − 68.4| ≤ 0.3 µG`. Between 0.3 and 1.0 µG is a soft disagreement and
   is reported as one. **> 1.0 µG is a finding**, not a fit to be improved: two
   methods sharing no machinery would then be saying different things about the
   same branch.
5. **The κ = 0.9 control.** λ_min must stay positive across 35–80 µG with no
   softening trend (< 2× variation). If the crossover control also softens toward
   zero, the attribution of the softening to the branch END has failed, and that
   is the result.
6. **The polarised-branch answer (#335 §5.2).** Report λ_min's SIGN per cell with
   its certificate. A negative λ_min at any field says the branch is a saddle
   there and #335's ramp-edge reading changes; a positive λ_min with a converged
   certificate says it is a genuine minimum and the 27.4 µG conversion was barrier
   crossing, exactly as §5.1 argues.
7. **Which axis, every time.** `λ_min` is the ENERGETIC axis (minimum vs saddle).
   `growth` is the DYNAMICAL axis (does a perturbation grow). They are orthogonal
   and both are recorded; no row may be summarised with one word.

**Cost discipline.** Smoke first: one cell, `nev=4`, `max_iter=15`, on the GPU, to
measure the per-cell wall time before sizing the full scan. Nothing above 10
minutes is launched without it.

## 5. Results

*(filled in by the runs; each row names its job)*

## 6. Answer

*(after §5)*
