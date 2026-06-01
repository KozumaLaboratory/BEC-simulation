# Eu polar-magnon spectroscopy proposal — Kozuma/Matsui group

Companion to `eu_sbi_handoff.md`. This document is a measurement
proposal addressed to the experimental group, summarising what the
simulator predicts and what the lab would need to do to extract the
six unknown spin-6 ¹⁵¹Eu scattering lengths `a_S` (S = 0, 2, 4, 6,
8, 10) to ~ 0.05 a_Bohr per channel.

The technical handoff document (`eu_sbi_handoff.md`) carries the
detailed Fisher analysis, residual magnetic-channel accounting, and
caveats. This document is the operational summary.

## What you would do

1. **Prepare polar ground state** (m = 0 condensate), pinned by a
   negative effective quadratic Zeeman `q < 0`. Strongest practical
   approach: microwave dressing on the F=6 → F'=7 transition (or any
   convenient quadratic Stark shift) to engineer `q < 0` directly,
   leaving the static Bz field as small as possible (case (a) in the
   handoff). Fallback: static-Bz q-pinning at ~ 12 μT requires
   simultaneous common-mode rejection of ±magnon doublets — see
   handoff for the protocol requirements.

2. **Spectroscopy of the Bogoliubov spin-mode (magnon) spectrum**
   around the polar GS. Drive and detect a symmetric (ΔM_z = 0)
   superposition of ±m magnon branches (quadrupolar drive or two-tone
   equal-amplitude). Avoid single-chirality projection; that
   re-exposes Larmor shifts.

3. **Integrate per mode for ~ 1-10 s** to reach σ_freq ≈ 0.1 Hz.
   With N ~ 5×10⁴ atoms and T_obs ≤ 40 ms (set by the 3-body loss
   floor), shot-noise-limited estimation gives σ_freq ≈ 1/(T_obs·√N)
   per shot ≈ 0.1 Hz once ~ 10² shots are averaged. The polar
   m → −m symmetry is what enables that ensemble average — without
   it, shot-to-shot Bz jitter would destroy the averaging.

4. **Compare** the measured mode frequencies against the simulator's
   prediction (we provide the forward map `c → ω_n` for any candidate
   {c_n}). Six measured modes (k=0.5 ω_ref·a_ho⁻¹, branches Δm = ±1,
   ±2 dominantly) suffice to invert in the 5-parameter c-basis.

## What you would get

| S  | σ(a_S) [a_Bohr] |
|----|------------------|
|  0 | 0.04             |
|  2 | 0.04             |
|  4 | 0.05             |
|  6 | 0.05             |
|  8 | 0.06             |
| 10 | 0.07             |
| 12 | 110 (existing prior; not measured here) |

Two to three orders of magnitude tighter than current state-of-the-art
scattering-length precision in cold atom experiments. Direct input
to: the ¹⁵¹Eu phase diagram (which phase is the GS?), the
fluctuation-selected near-degenerate-phase question (Paper #3
candidate), and the vortex/Barnett follow-up experiments.

## What the simulator handles

- Forward map c → ω_n: GP+MDDI ground state via ITP, Bogoliubov
  diagonalisation at user-chosen k, output is 2D = 26 mode frequencies
  per spinor branch. Validated against the Casimir λ_S = (S(S+1) -
  2F(F+1))/2 weights on the c_1 column (physics consistency check).
- Mode-frequency precision: at the given (N, trap, k, c-magnitudes),
  predictions include the per-mode dω/dc Jacobian → posterior σ(a_S)
  via Fisher inversion + 6j basis change.
- Magnetic-jitter analysis: first-order Bz, second-order via q,
  Bx-first-order, and gradient channels — all evaluated. Polar config
  is structurally first-order Bz-protected (`dω/dB ≈ 0` machine
  precision); second-order q channel gives ≤ 0.025 Hz at the
  c-sensitive modes (case (b)) or 1e-8 (case (a)).

Scripts:
- `scripts/fisher_sprint4_itemA_bogoliubov.jl` — polar Bogoliubov
  Fisher (single-config)
- `scripts/fisher_sprint4_aS_basis_transform.jl` — σ(a_S) translation
- `scripts/sprint5_bogoliubov_dB_sensitivity.jl` — polar vs stretched
  magnetic protection
- `scripts/sprint5_polar_dq_residual.jl` — quadratic-Zeeman channel
  closure

## What the simulator does NOT yet handle (experimentally relevant)

- Mode linewidth / lineshape: assumed Lorentzian, but at the Hz scale
  the lab will see physical decoherence sources (technical noise on
  the dressing field, trap-frequency jitter, residual K_3 losses
  affecting effective T_obs). We assume `σ_freq = max(0.1 Hz,
  lab-measured floor)`.
- Detection: we assume σ_freq is the operating point; the actual
  detection chain (RF/microwave drive amplitude, fluorescence /
  absorption imaging integration, fringe-noise floor) must independently
  hit that floor. The handoff lists the per-shot SNR requirement.
- Trap-averaging: the polar BdG is computed at peak-density spinor;
  the lab cloud has spatial inhomogeneity giving ~ 5% LDA correction
  to mode frequencies. This is a systematic, not a precision question.

## Status

- Theory: c-determination protocol mathematically closed
  (`sprint3_static_gate_baseline_2026_06_01.md` + `eu_sbi_handoff.md`).
- Open experimental questions: (i) can you reach σ_freq ≈ 0.1 Hz
  per mode at T_obs ~ 40 ms in your trap? (ii) can you implement
  symmetric-doublet drive/detection? (iii) is the q-pin engineering
  (microwave-dressed) cleanly available?

If (i)-(iii) are all yes, the protocol is run-ready. If any is
"no" or "depends", the simulator can re-evaluate σ(a_S) at the
realistic σ_freq the lab can deliver, so the precision claim adjusts
honestly rather than being abandoned.

## Open theory items (not blocking this proposal)

- Phase-diagram localisation of Eu (Track A in the North Star plan):
  whether σ(a_S) ≈ 0.05 a_B is needed to pin the phase, or insurance.
- Fluctuation-selected phases in near-degenerate regions: Track B
  (Paper #3 LHY / TDHFB) ladder; lab data would directly constrain.
- Vortex and Barnett predictions: Track C; the Bogoliubov c-decisions
  feed the GS used in vortex-nucleation TWA ensembles.

These are theory-side and can run on whatever c values the lab
provides; they don't gate the proposal.

## Contact

Theory side: anko (KozumaRoom / SpinorBEC.jl project)
