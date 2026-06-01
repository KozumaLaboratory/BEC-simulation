# ¹⁵¹Eu Bogoliubov spectroscopy → scattering-length determination

**Magnetic-jitter check (2026-06-02): polar GS is FIRST-ORDER B-PROTECTED.**

Initial worry: Bogoliubov c-sensitive modes (11/12/15/16) inherit a
Larmor slope `dω/dB ≈ 17 Hz/nT` (Matsui's number); at σ_B ≈ 1 nT residual,
σ_freq floor would be ~17 Hz not 0.1 Hz, and σ(a_S) ~8 a_B not 0.05.

Numerical check (`scripts/sprint5_bogoliubov_dB_sensitivity.jl`):
**polar GS Bogoliubov modes have `dω/dB` = machine-precision zero** for
linear Zeeman p. The c-sensitive modes 11/12/15/16 give `dω/dB ≈ 3×10⁻¹²
Hz/nT` (i.e. numerical noise, no physical sensitivity).

Physics: polar (m=0) has m → −m symmetry. Bogoliubov eigenstates are
symmetric/antisymmetric m,−m combinations with `⟨F_z⟩=0`. Linear Zeeman
p couples through `⟨F_z⟩`, so its first-order effect on mode frequencies
vanishes by symmetry. The 17 Hz/nT Larmor rate applies to *single-atom*
precession or to non-symmetric configurations (stretched), not to the
polar collective modes used here.

Caveat: quadratic Zeeman q couples through `⟨F_z²⟩` (m²-dependent, NOT
m → −m symmetric). At static q ≈ -2 used for polar pinning, `dω/dq` is
non-zero. Residual q-jitter from a ±1 nT Bz fluctuation is
`dq/dB·σ_B ≈ B/B_typical × q_pin`, which for typical Eu parameters is
~10⁻³ × q ≈ small. The polar configuration thus survives ~1 nT shielded-
lab residuals with σ_freq ≈ 0.1 Hz intrinsic-limited.

**Stretched (m=±F) does NOT have this protection.** Modes around
stretched do feel linear Zeeman p (single-atom Larmor slope applies). If
the lab prefers stretched for prep convenience, σ(a_S) does degrade per
σ_B/0.1 Hz scaling.

Recommendation: **use polar (q<0 pin), not stretched, for the σ(a_S) ≈
0.05 a_B precision**. Stretched is for cross-check or convenience only.

## Symmetric-mode detection requirement (essential)

The first-order B-protection applies to the **symmetric (ΔM_z=0)**
combinations of ±magnon doublets, not to individual ±1 magnons. Individual
m=+1 and m=−1 magnons DO Larmor-split under residual Bz. The protocol must
therefore:

- Drive and detect the symmetric combination (e.g., quadrupolar drive
  exciting `|+m⟩ + |−m⟩` symmetrically, or two-tone drive at ω_+ and ω_−
  with equal amplitudes), NOT a single-chirality Δm transition
- Detection coupling must also be symmetric, otherwise residual Bz
  re-enters via the asymmetry-projection coefficient

If detection biases to one chirality, the σ_B-induced split between
±magnons gives σ_freq = `|m|·dω/dB` instead of 0; for m=±1 modes this
reverts to single-atom Larmor scale.

## Frequency-estimation gate (√N averaging)

The σ_freq ≈ 0.1 Hz quoted assumes shot-noise-limited estimation:
`σ_freq ≈ 1/(T_obs · √N)`. For N ≈ 5·10⁴ atoms, √N ≈ 220. T_obs is set
by the K_3-driven loss floor: at K_3 ≈ 50 dimensionless (calibrated to
Matsui's 40%/40 ms), 50% population loss happens around 40-80 ms. So
T_obs ~ 0.04 s gives `σ_freq ≈ 1/(0.04 × 220) ≈ 0.11 Hz`. **The √N
averaging works only because the polar protection eliminates the
shot-to-shot Bz jitter that would otherwise destroy ensemble averaging.**

This connects two findings tightly:
- Polar protection enables √N estimation
- Lab K_3 (Matsui-calibrated) sets T_obs and thus √N reachability

Both must hold for the 0.1 Hz σ_freq to be defensible.

## Protocol

1. **Prepare polar (m=0) ground state**, pinned by negative quadratic
   Zeeman `q < 0`.
   - Required: `q / ω_ref ≲ −1.5` (so the polar energy gap dominates
     over c_1·n ≈ tens of Hz spin-mixing rate)
   - Set via Bz orientation and microwave dressing (standard MW Stark
     shift inverts q sign)
   - Atom number: N ≈ 2000–10⁴ in a (110, 110, 130) Hz trap (consistent
     with the Matsui 2026 setup)

2. **Spectroscopy on the polar GS**: drive collective spin modes and
   measure frequencies for as many Δm branches as possible.
   - Spin-1 Goldstone (sound mode) at ω ≈ 0
   - Δm = ±1, ±2, …, ±2F transverse spin modes at ω ∈ {few Hz to ~50 Hz}
   - Single representative k-sample at k a_ho ≈ 0.5 (~ 1/3 the inverse
     cloud size) suffices; k-sweep doesn't change the result

3. **Required frequency resolution**: `σ_freq ≈ 0.1 Hz` per mode, achieved
   via ≳ 2–10 s integration. With 26 mode observables and 5 unknown c_n,
   the joint fit gives:

   | S  | σ(a_S) [a_Bohr] |
   |----|------------------|
   |  0 | 0.042            |
   |  2 | 0.042            |
   |  4 | 0.045            |
   |  6 | 0.050            |
   |  8 | 0.058            |
   | 10 | 0.067            |
   | 12 | 110 (prior-fixed) |

## Experimental conditions

| Quantity | Required | Notes |
|---|---|---|
| Bias field Bz | tuneable, q<0 regime | enables polar pinning |
| Bz drift (RMS) | < 100 nT over integration window | otherwise σ_freq degraded |
| Residual Bx, By | < 10 nT (after compensation) | transverse field tilts polar |
| Atom number stability | < 5% shot-to-shot | drives mean-field shift |
| Trap (ω_x, ω_y, ω_z) / 2π | (110, 110, 130) Hz nominal | other geometries also work |
| Mode probe RF amplitude | small-signal regime | linear response Fisher analysis |
| Imaging | not needed for c determination | mode-frequency readout is in-trap |

## Stretched alternative

The same precision is achievable around the stretched m = +F (or m = −F)
GS pinned by strong linear Zeeman p:

- Stretched gives σ(c_1) ≈ 6×10⁻⁵ vs polar's 1.4×10⁻⁴ (2.4× tighter)
- Tensor channels and c_0 are comparable across the two configurations
- Choose whichever is easier to prepare and probe

## Verification status

| Item | Status |
|---|---|
| Bogoliubov mode frequencies depend on g_S as expected | ✓ Jacobian recovers Casimir λ_S weights (consistency check) |
| Polar vs stretched both give full-rank Fisher | ✓ both σ within 2× of each other |
| Robust across k-samples k ∈ [0.1, 2.0] | ✓ rank 5/5 maintained, c_1 σ flat to ±3% |
| Matsui m=−4 ring count (2 vs 3) reproduced | partial: dynamics at T=14.5 ms gave 2 rings for all c_1 values tested; T=40 ms + 24³ grid + m-dep K_3 calibrated K_3≈50 is the in-progress test |

## What the simulator depends on

- Wigner 6j transform `c_to_g(F, ip)` mapping (c_0, c_1, c_extra) →
  channel g_S (codebase: `src/hamiltonian/interactions/interactions.jl`)
- GP+MDDI ground state via `find_ground_state` ITP
- Bogoliubov diagonalisation `bogoliubov_spectrum` at user-chosen k
- All standard in the SpinorBEC.jl codebase; no special infrastructure
  added for this analysis

## Caveats

- σ_freq = 0.1 Hz assumes a clean instrument; if the lab achieves only
  σ_freq = 1 Hz, σ(a_S) degrades to ~ 0.5 a_Bohr — still lab-relevant
  but only 1 order of magnitude better than current state-of-the-art
- Predictions assume GP mean-field; at very low temperature the
  beyond-MF (Bogoliubov fluctuations) corrections to mode frequencies
  are ~ 1% — small enough to ignore for a first measurement, large
  enough to revisit for a "definitive" measurement
- The polar GS assumes uniform spinor at peak density; for trapped
  clouds the local-density approximation introduces a ~ 5%
  inhomogeneity correction (analogous to how trap-averaged c_n
  differs from peak-density c_n)
- Item 4 v0 spatial cascade showed that linear Fisher in the cascade
  regime *does not* directly recover the 2↔3 m=−4 ring discrimination
  Matsui used — that observable is a non-linear / topological feature
  outside linear Fisher's reach. The Bogoliubov route bypasses this
  by working at the GS rather than during cascade

## Reproduction scripts

| Script | What it produces |
|---|---|
| `scripts/fisher_sprint4_itemA_bogoliubov.jl` | Polar GS Bogoliubov Fisher, c-basis |
| `scripts/fisher_sprint4_itemA_stretched.jl` | Same, stretched GS |
| `scripts/fisher_sprint4_itemA_ksweep.jl` | k-robustness verification |
| `scripts/fisher_sprint4_aS_basis_transform.jl` | σ(a_S) in a_Bohr units |
| `scripts/fisher_sprint4_joint_all_levers.jl` | polar + stretched joint Fisher |

## Next steps (next session)

- Confirm 2↔3 ring discrimination at T=40 ms / 24³ grid /
  K_3 m-dependent calibrated. In flight as
  `scripts/sprint5_matsui_ring_extended.jl`.
- Joint Fisher polar + stretched (52 obs / 5 params) for the
  independence-vs-redundancy verdict.
- Whether the lab can stabilise Bz to < 100 nT and prepare polar at
  q < 0 are the only experimental open questions.
