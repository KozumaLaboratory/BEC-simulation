# L4 Eu Hamiltonian-only — grid convergence diagnostic (2026-05-22)

## Symptom

L4 Eu (151) Hamiltonian-only EdH at four grid resolutions on box L=12,
duration t=6.28, dt=0.01, Bz quench 0.01→2.6e-5 Gauss, c1_ratio=-0.005,
DDI on/secular=false, LHY=none, ITP 1500 steps:

| t   | 32³        | 48³        | 64³        | 96³        |
|-----|------------|------------|------------|------------|
| 0.0 | -5.999995  | -5.999995  | -5.999995  | -5.999995  |
| 2.5 | -5.999964  | -5.999964  | -5.999298  | -5.997036  |
| 5.0 | -5.999874  | -5.999874  | -5.991714  | -5.991142  |
| 6.0 | -5.998089  | -5.998088  | -5.987657  | -5.988782  |

32³ and 48³ are identical to 6 sig figs at every observed t.
64³ and 96³ each diverge differently.

## Hypotheses ruled out

### H1: Random-noise seed pattern grid-dependence — RULED OUT
**Test L4 vs L4det**: replace `seed_amplitude=1e-6` + `seed_k_cut=2.5`
random seed with deterministic single-mode `seed_mode: {k_vec=[0,0,0.524], amplitude=1e-6}`.
Result: trajectories identical to 4×10⁻⁵ to L4 (with RNG-based seed)
across all grids. The seed spectrum is NOT the convergence culprit.

### H2: ITP-leakage initial condition — RULED OUT
**Test L4poldet**: hard-polarize ψ to exact m=-F (Fz=-6.0 to 16 digits)
before dynamics. Result: trajectories agree with L4 / L4det to ~10⁻⁴,
SAME 32≡48≪64<96 pattern. Initial 5×10⁻⁶ Fz floor is NOT the driver.

### H3: Noise-amplitude rescale convention — RULED OUT
**Test bake** RMS-rescale vs max-rescale for spectral-truncated noise.
Trajectories identical. The amplitude convention is physically correct
(grid-invariant total power), but the convergence problem is independent.

### H4: DDI padded kernel Q(k) discretisation — RULED OUT
**Inspection**: `make_ddi_padded` uses `dk = π/L` (grid-independent in
N for fixed box L). Q(k) is continuous, k=0 explicitly zero. Same k-grid
sample points across all N. No grid dependence in the kernel.

## Hypothesis identified — H5: spin-density BILINEAR aliasing

`_compute_spin_density!` computes
    F_z(r) = Σ_c m_c · |ψ_c(r)|²
    F_x(r) + i F_y(r) = Σ_c sqrt(F(F+1)−m(m+1)) · conj(ψ_{c−1}(r))·ψ_c(r)

These are BILINEAR in ψ. If ψ has Fourier content up to k_Nyq_N, then
F_α has content up to 2·k_Nyq_N. But F_α is **stored on the original
N-grid**, so the high-k content (k_Nyq_N < |k| < 2·k_Nyq_N) folds back
into low-k modes via periodic-boundary aliasing.

The existing `ddi_padded` zero-pads F_α from N to 2N *AFTER* the bilinear
computation. This prevents wrap-around aliasing during the F_α ⊗ Q
convolution itself but does NOT undo the bilinear sampling aliasing
that already occurred at the spin-density step.

### Why 32 ≡ 48 exactly?

Both N=32 and N=48 are well above the meaningful k-content of the
initial Eu Gaussian σ=1.5 (k_max ≈ 3-5). Both grids resolve ψ identically
in the low-k regime that dominates ITP-converged ψ. The bilinear
high-k content (which gets aliased) folds into the SAME low-k modes at
both grids — hence identical trajectories. The difference 64↔96 reflects
the additional resolved physics + the (smaller but still present)
aliasing pattern.

### Why 64 ≪ 32/48?

At N=64, k_Nyq=16.76 exceeds the EdH spin-wave instability scale
k_healing ≈ 1/ξ ≈ 2.5. The unstable modes are now resolved AS
spin waves, not just aliased low-k contributions. EdH transfer
accelerates because the unstable modes drive Fz→0 dynamics directly.

## Fix candidates

### Path A: 2× k-space pad ψ before bilinear (Orszag-style dealiasing)

1. Add ComplexF64 buffer `psi_pad` of shape (2N..., D) to `DDIPaddedContext`.
2. Add complex FFT plans for ψ-pad.
3. Per dynamics step: ψ (N) → FFT(ψ_c) → zero-pad to 2N → IFFT → ψ_pad (2N).
4. Compute F_α on 2N grid via existing `_compute_spin_density!` (no
   aliasing because ψ_pad has k_Nyq_2N effective max k).
5. Existing rFFT/Q kernel/inverse FFT on 2N grid.
6. Sample U_α back to N grid for application to ψ.

Memory: 8× ψ at 32³ (54 MB extra); 1.5 GB extra at 96³.
Compute: ~50 FFTs/step extra (D=13 components × 4 plans + bilinear cost).
Expected: 32³ ↔ 96³ trajectory agreement within Δx²·k_physics² truncation.

### Path B: Set production grid ≥ 96³ in Eu YAML templates

Document that Eu DDI EdH Hamiltonian-only is bilinear-aliased at 32/48
and use ≥ 96³ for production. This works IF 96 and 128 agree (test in
progress as of this writeup).

### Path C: Orszag 2/3 rule on ψ (filter ψ before bilinear)

1. Each dynamics step: filter ψ to |k| ≤ (2/3) k_Nyq_N (zero high-k modes).
2. Compute F_α on N grid — aliased content folds into the (2/3, 1) band
   we've already zeroed.
3. Filter F_α similarly, then DDI convolution.

Cost: modifies ψ in-place every step. Slight nonconservation, but
manageable. Less invasive than Path A. Convergence "in the band" only —
each grid has 2/3 of its raw k_Nyq as usable bandwidth.

## Decision pending

L4_128 in flight. If 96 ≈ 128, Path B (use ≥ 96³) is the minimal fix.
If 96 differs from 128 substantially, Path A is needed for proper
continuum-limit convergence.
