# Step 5 v2 — Eu Hamiltonian-only stationary-propagation sanity (2026-05-25)

## Design changes from v1

| Aspect | v1 | v2 |
|--------|----|----|
| Bz schedule | GS at Bz=-0.01, dynamics ramp Bz: -0.01 → +2.6e-5 | GS and dynamics at SAME Bz=-0.01 (no quench) |
| Hamiltonian during dynamics | time-varying (linear ramp) | strictly time-independent |
| Energy conservation testable? | NO (ramp dominates E change) | YES (H_dyn = H_GS exactly) |
| EdH dynamics observable? | partially (asymmetric ramp + DDI) | NO (initial state is near-eigenstate) |
| Purpose | EdH transfer demo (failed cleanly) | conservation-law audit (Layer 1+2+3) |

## v1 gotcha discovery (worth keeping)

`Bz: {from: -0.01, to: 2.6e-5, duration: 0.0}` does NOT produce an
instantaneous quench. The inner `duration: 0.0` is ignored by
`_make_waveform`; the outer dynamics step's `duration` (= 0.5 ω_ref⁻¹
here) becomes the ramp duration. So Bz ramps linearly across the
entire dynamics window. ΔE_observed in v1 = +978 traces exactly to
ΔE_Zeeman = ⟨F_z⟩·Δp = -6 × (p_old−p_new) ≈ +978 with
p_dimless = g_F μ_B Bz / (ℏ ω_ref) ≈ 1.626e4·Bz[G] for Eu151
(ω_ref = 628.3 rad/s).

The same gotcha is present in `runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_*.yaml`
— their `duration: 0.0` does not produce a quench either.

## Sweep grid

* 24³ × secular=false  — fastest, baseline
* 32³ × secular=false  — first convergence step
* 48³ × secular=false  — second convergence step
* 24³ × secular=true   — DDI-secular vs non-secular comparison at fixed grid

All other parameters identical (Eu151 F=6, N=30000, box=10.0, c1_ratio=-0.005,
trap isotropic ω=(1,1,1), dt=0.005, 100 dynamics steps).

## Pass criteria

* norm drift < 1e-10 (Strang is unitary in RTP)
* energy drift < 1e-4 relative (Strang is O(dt²))
* Jz drift expected to scale ∝ 1/grid² (FFT-based Lz convergence)
* secular=true should reduce Jz drift (off-diagonal DDI removed)
