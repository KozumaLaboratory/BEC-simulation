# Ueda lab comparison — status: BLOCKED_EXTERNAL

**As of 2026-05-26.**

## Status

```
Status:   BLOCKED_EXTERNAL
Reason:   No active communication channel with the Ueda lab.
Fallback: Self-contained validation chain (analytic / conservation /
          literature benchmark / independent reference RHS / convergence).
```

## Decision

External code comparison with the Ueda lab simulator is **paused
indefinitely**. The project does not gate any milestone on
Ueda-side sign-off until communication is restored.

All claims about the correctness of this codebase are now made
relative to the self-contained validation chain documented in
`docs/validation/validation_report.md` and the validation matrix in
`docs/validation/validation_matrix.csv`. Comparison with an external
code is **not** part of the current validation evidence.

## What this changes

- **Validation ladder Level 10** (`memory:validation_ladder_2026_05_22`):
  rewritten from "Ueda operator-RHS comparison" to "independent
  reference-RHS comparison". The reference RHS is a minimal CPU-only
  term-by-term Hψ implementation inside this repository
  (`src/validation/reference_rhs_*.jl`, planned). Production Hψ is
  compared against it on small grids (8³ / 16³).
- **Next-session priorities Step 6** (`memory:next_session_priorities_2026_05_25`):
  rewritten from "Ueda contract lock-in" to "Self-contained validation
  report" (this document tree).
- **Eu production claim shape**: from "this run matches Ueda" to
  "results are robust across DDI convention factorial, grids
  {64, 96, 128}, dt scan, and seed ensemble, under the documented
  conventions."
- **K3 framing**: K3 is no longer cited as a candidate explanation for
  a Ueda-vs-ours discrepancy. K3 is the experimentally-motivated
  dissipative model axis; its effect is studied via control runs
  (DDI off, K3 off, K3 on, K3 + γ_dr), not via external-code diff.

## What this does NOT change

- The existing parameter contract document
  (`docs/validation/parameter_contract_with_Ueda.md`) is **paused, not
  deleted**. The convention-by-convention enumeration in that file is
  also the canonical convention reference for the independent
  reference-RHS implementation, and is signed off on the SpinorBEC.jl
  side. If Ueda communication reopens, that document becomes the
  starting point of the joint sign-off as originally intended.
- The export tool `scripts/validation/export_operator_rhs.jl` and the
  `operator_rhs.jld2` artefacts under
  `runs/verification_suite/L4_eu_matsui_hamiltonian_only_*` remain
  intact. They are usable for the day Ueda-side comparison resumes.
- The L4 cross-grid convergence result (ΔF_z = 0.00886 at
  k_cut = 16, agreeing to 5 digits across N = {64, 96, 128}) is
  unchanged and remains the canonical Eu Hamiltonian-only prediction
  for this codebase.

## How the validation chain works without Ueda

Each numbered layer is independent. A claim about correctness should
cite WHICH layers it rests on, not "validated" in the abstract. See
the strategic-pivot memory for the discipline of naming layers
explicitly.

1. **Analytic solutions** — scalar free-particle plane wave, harmonic
   oscillator ground state, Zeeman-only phase factor exp(-i(-pm+qm²)t),
   uniform-density K3 decay n(t) = n₀/√(1+2K₃n₀²t).
2. **Conservation laws** — norm, energy (under Hamiltonian-only
   dynamics), F_z under purely Zeeman+contact, J_z under DDI+rotation
   (EdH conservation), M_z under spin-mixing dynamics.
3. **Literature benchmarks** — spin-1 polar / ferromagnetic ground
   state, spin-2 cyclic / nematic, DDI spherical cloud E_DDI = 0,
   prolate / oblate sign, canonical EdH transfer.
4. **Independent reference-RHS** (planned) — minimal CPU-only Hψ
   kernels per term: scalar / Zeeman / contact / DDI / loss. Compare
   production Hψ vs reference Hψ on small grids. Tolerances: scalar
   < 1e-10 rel, Zeeman < 1e-12 rel, contact < 1e-10 rel, DDI
   1e-6..1e-8 (grid/cutoff bound), loss = analytic rate.
5. **Grid / dt / box / seed convergence** — at production parameters.

For Eu production, additional **robustness layer**: factorial over
DDI on/off, loss on/off, K3 on/off, γ_dr on/off, scalar LHY on/off,
grid {64, 96, 128}, dt scan, seed ensemble. Conclusions reported only
where they are invariant across this factorial.

## Reopening criteria

This document moves out of BLOCKED_EXTERNAL when ANY of:

1. anko explicitly states communication with the Ueda lab is restored.
2. An alternative external code (not Ueda's) is identified for
   cross-comparison and acquired.
3. A peer-reviewed published numerical benchmark covering the Eu
   Hamiltonian-only short-time regime becomes available with enough
   parameter detail to reproduce.

Until then, do not re-introduce "matches Ueda" as a milestone, and
do not interpret any Eu run as "validated against the Ueda code."

### Concrete candidates for criteria 2 / 3 (2026-05-26 research)

Survey in `runs/_loop/research/cross_code_benchmark_alternatives_T1.md`.
None covers the F=6 + DDI + 3D setting fully, but partial cross-checks
are feasible:

| Candidate | Covers | Effort | Status |
|---|---|---|---|
| FORTRESS (Bao group, Fortran 90, CPC 279 (2022), arXiv:2002.04365) | F=1, F=2 contact, 3D ITP + RTP | Install + port a few days | UNATTEMPTED; recommended first cross-check |
| Matsui et al. 2026 supplementary (Science, DOI:10.1126/science.adx2872, arXiv:2504.17357) | Eu-151 F=6 EdH, full physics | Acquire Science supplement OR email Kozuma/Miyazawa Science Tokyo group | UNATTEMPTED; primary Eu target; effort blocked on supplement acquisition |
| Bao+Cai numerical benchmarks (Commun.Comput.Phys., arXiv:1504.02897) | Scalar (single-component) dipolar GP, tabulated GS energies / widths vs ε_dd | Few days, our scalar path | UNATTEMPTED; cleanest DDI-kernel cross-check |
| Adhikari/Muruganandam OpenMP dipolar GPE (CPC 286 (2023)) | Scalar dipolar 1D/2D/3D | Few days | Subset of Bao+Cai coverage |
| GPELab MATLAB (CPC 185/193, 2014/2015) | General GPE; DDI requires hand-wiring | Medium-to-high; MATLAB toolbox | Less maintained; UNATTEMPTED |

**No Julia-native competitor exists** for F=6 spinor + DDI + 3D. We are
the only F=6+DDI+3D public spinor BEC simulator known as of 2026-05.

**Known literature gaps** (not search failures — genuine open problems):

- Eu-151 channel-resolved scattering lengths a_S (S=0, 2, ..., 12)
  have never been measured. Matsui 2026 explicitly assumes Δa is small
  and uses a_s = 110 a_B uniformly across channels.
- No published numerical benchmark of secular vs full DDI as a function
  of ω_L / (c_dd ⟨n⟩). The criterion `> 100` in CLAUDE.md is internal
  engineering policy, not literature.
- Klaus 2022 magnetostir paper reference in project memory was NOT
  located via this 2026-05-26 search. The paper may exist (memory
  cites it) but the precise arXiv/DOI is not in our records — open
  to the user to supply.

## References

- `memory:strategic_pivot_self_contained_validation_2026_05_26` — full
  decision context
- `memory:validation_ladder_2026_05_22` — current 13-level ladder
- `memory:next_session_priorities_2026_05_25` — Step 6 rewrite
- `docs/validation/parameter_contract_with_Ueda.md` — paused contract
- `docs/validation/validation_report.md` — running internal report
- `docs/validation/validation_matrix.csv` — test/physics/expected/result/status
