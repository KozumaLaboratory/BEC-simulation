# Loop seed — Turn 0

This is the initial seed for the autonomous research loop, written
by anko as the first turn's task brief.

## Context built up by Phase 0

The Phase 0 calibration runs (both `phase0_test.md` and the v2 re-run
`phase0_test_v2.md`) established:

- The Chin–Krotscheck force-gradient correction sign flips under
  Wick rotation: imaginary-time +Δτ²/48 → real-time −dt²/48 in the
  Ṽ form.
- There are **two coefficient conventions in circulation**:
  - α₂ = −1/48 on the modified potential Ṽ_real = V + α₂·dt²·[V,[T,V]]
  - α₃ = −1/72 on the exponent of the middle-slot correction
    operator at weight w = 2/3 (Algorithm 4A form)
  - Map: α₃ = w·α₂ = (2/3)·(−1/48) = −1/72.
- The project memory `gotcha_fg_correction_sign_wick_rotation.md`
  records that `scripts/bench/track_c_v4_a11_alpha_sweep.jl`
  performs an α sweep on autonomous F=1 Chin 4A and observes that
  only one specific α value collapses to the F64 floor (~1e-12).

## Turn 0 task

Verify which of the two conventions (α₂ = −1/48 vs α₃ = −1/72) is
actually used in `scripts/bench/track_c_v4_a11_alpha_sweep.jl`.
Determine whether the codebase elsewhere (e.g. `src/hamiltonian/`)
implements the FG correction with the same convention or with the
other. If there is a mismatch — i.e. the bench tests one convention
but production code uses the other — that is a load-bearing finding
and should be surfaced explicitly.

## Constraints on this turn

- **No new experiments.** This is a code-reading and small-test
  turn. The directive issued should be `action: "analyze_existing"`
  or `action: "modify_code"` (add a regression test asserting the
  observed convention), not `run_experiment`.
- **Time budget**: ≤ 5 minutes of implementer wall-clock. No GPU
  required.
- **Falsification criterion** should be concrete and machine-
  checkable (e.g. "the rational literal `1/72` appears in the bench
  with explicit Wick-rotation sign tracking").

## Stop conditions for this turn

- Judge emits PASS → turn 1 receives free rein for next direction.
- Judge emits FAIL_PHYSICS or SUSPICIOUS_NOVEL → halt for anko review.
- Implementer emits REJECTED → halt; theorist directive was too vague.
