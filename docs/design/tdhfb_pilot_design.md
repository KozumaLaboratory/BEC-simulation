# TDHFB pilot — design document for SpinorBEC.jl

**Date**: 2026-05-11
**Status**: design document; implementation post-修論 (D-thesis Year 2 candidate).
**Bridge**: Chapter 5 §5.8 → D-thesis Ch.4 (beyond-mean-field methods) primary candidate.

## Motivation

Chapter 5 demonstrated that TWA leading-order in the F=6 ¹⁵¹Eu post-quench dipolar
collapse regime measures **classical chaos onset** ($\sigma/\mu \approx 0.4$-$0.8$), NOT
controlled quantum fluctuations. The 1/√N scaling fails by order-of-magnitude at
Sinatra-clean conditions (`twa_N_scan_pinned_16g`).

For controlled beyond-mean-field claims (e.g., "does quantum fluctuation stabilize Eu
collapse?"), TDHFB (Time-Dependent Hartree-Fock-Bogoliubov) is the natural next-order
treatment. TDHFB tracks **pair amplitudes** $\langle \hat\psi \hat\psi\rangle$ alongside
the mean field $\langle\hat\psi\rangle$, providing quantum-fluctuation content beyond
leading-order TWA without the chaos-trajectory divergence pathology.

## TDHFB formalism — recap

For Bose field $\hat\psi_m(\mathbf{r})$, define:

- **Mean field**: $\phi_m(\mathbf{r}) = \langle \hat\psi_m(\mathbf{r}) \rangle$
- **Normal density**: $\rho_{m m'}(\mathbf{r}, \mathbf{r}') = \langle \hat\psi^\dagger_m(\mathbf{r}) \hat\psi_{m'}(\mathbf{r}') \rangle - \phi^*_m(\mathbf{r}) \phi_{m'}(\mathbf{r}')$
- **Anomalous density**: $\kappa_{m m'}(\mathbf{r}, \mathbf{r}') = \langle \hat\psi_m(\mathbf{r}) \hat\psi_{m'}(\mathbf{r}') \rangle - \phi_m(\mathbf{r}) \phi_{m'}(\mathbf{r}')$

Coupled TDHFB equations (schematic, dropping spatial labels):

$$i\hbar \partial_t \phi_m = h^{\rm HF}_{m m'}[\phi, \rho, \kappa] \phi_{m'} + g_{m m_1 m_2 m'}^{(2)} \kappa^*_{m_1 m_2} \phi^*_{m'} + \ldots$$

$$i\hbar \partial_t \rho_{m m'} = [h^{\rm HF}, \rho]_{m m'} + (\text{anomalous coupling terms})$$

$$i\hbar \partial_t \kappa_{m m'} = (h^{\rm HF} + h^{\rm HF, T}) \kappa + (\text{condensate-pair coupling})$$

The HF Hamiltonian $h^{\rm HF}$ depends on all of $\phi, \rho, \kappa$ self-consistently.

**Conservation**: total particle number $N = \int [|\phi|^2 + \text{tr}\rho]$, energy
$\mathcal{E}$ conserved by symmetric Strang-split integration.

## SpinorBEC.jl integration plan

### Phase 1: type definitions + storage layout (~1 week)

```julia
# src/foundation/types/tdhfb_state.jl
struct TDHFBState{N, D, A}
    phi::Array{Complex{Float64}, ?}    # condensate: psi[x..., c=D]
    rho::Array{Complex{Float64}, ?}    # normal: rho[x..., c1=D, c2=D]
    kappa::Array{Complex{Float64}, ?}  # anomalous: kappa[x..., c1=D, c2=D]
    # rho, kappa are non-local in general (depend on r, r')
    # For uniform mean-field + small-deviation regime, approximate as local
    # → rho[x..., c1, c2], kappa[x..., c1, c2]
    t::Float64
end
```

Computational cost: $D^2 + D^2 + D = 339$ fields per voxel for F=6 (D=13). 32³ grid =
1.1e7 fields = 175 MB ComplexF64. **Feasible on 16 GB GPU**.

### Phase 2: TDHFB equation kernels (~2 weeks)

```julia
# src/hamiltonian/tdhfb/
# - hartree_fock_matrix.jl   # h^HF[phi, rho, kappa] construction
# - condensate_step.jl        # phi evolution kernel
# - normal_density_step.jl    # rho evolution kernel
# - anomalous_step.jl         # kappa evolution kernel
```

Each kernel: FFT-based kinetic + matrix-multiplied potential + dispatch on F, D.

### Phase 3: TDHFB integrator (~1 week)

Strang-split for TDHFB:

```julia
function tdhfb_step!(state::TDHFBState, dt::Float64)
    # V(dt/2): point-wise potential
    apply_V_to_phi!(state, dt/2)
    apply_V_to_rho!(state, dt/2)
    apply_V_to_kappa!(state, dt/2)

    # K(dt): kinetic via FFT
    apply_K_to_phi!(state, dt)
    apply_K_to_rho!(state, dt)
    apply_K_to_kappa!(state, dt)

    # V(dt/2): point-wise potential
    apply_V_to_phi!(state, dt/2)
    apply_V_to_rho!(state, dt/2)
    apply_V_to_kappa!(state, dt/2)
end
```

Symmetric splitting → 2nd order. Higher-order (Y4-midpoint) for production.

### Phase 4: YAML integration (~1 week)

```yaml
dynamics:
  duration: 3.0
  dt: 0.001
  tdhfb:
    enabled: true
    initial_rho: vacuum  # or "thermal" with T/T_c < 1
    initial_kappa: zero  # or initialize from Bogoliubov GS modes
    save_pair_correlations: true
```

Pipeline runner extension to handle TDHFB state alongside regular mean-field workspace.

### Phase 5: TWA → TDHFB upgrade path (~1 week)

The existing TWA infrastructure (`src/solvers/twa.jl`) can co-evolve with TDHFB on
the same `runs/<config>` directory. Specifically:

- TWA: stochastic ensemble of $N_{\rm traj}$ GP trajectories
- TDHFB: deterministic evolution of $(\phi, \rho, \kappa)$

Direct comparison: at the same physical configs (Eu post-quench), compute σ/μ from TWA
vs $\sqrt{\langle\rho\rangle / |\phi|^2}$ from TDHFB. Difference = quantitative measure
of chaos vs quantum fluctuation.

## Computational cost estimates

### Eu 32³ grid

- Mean field $\phi$: 32³ × 13 = 425,984 ComplexF64 = 6.5 MB
- Normal density $\rho$: 32³ × 13² = 5,537,792 ComplexF64 = 84 MB
- Anomalous $\kappa$: same as $\rho$ = 84 MB
- **Total ~175 MB** for state. Plus FFT buffers, scratch space (~ 2x) → ~350 MB
- 16 GB GPU = ample headroom for one config; ~45 concurrent configs possible

### Per-step cost

- FFT-based kinetic: ~25 ms / 32³ / GPU (F=6 ComplexF64) → ~25 ms × 3 (phi, rho, kappa)
  ≈ 75 ms per step
- Matrix-multiplied potential: $D^3 = 2197$ flops per voxel × 32³ = 70M flops → ~5 ms
- **Total ~80 ms per step on RTX 4090 or equivalent**
- For $T = 3 \omega^{-1}$ with $dt = 0.001$ → 3000 steps × 80 ms = 240 s = 4 min per
  config
- Production sweep (10-20 configs) ~1-2 GPU hours

### Comparison with TWA

TWA (50 trajectories, 32³): each trajectory = mean-field GP cost ≈ 25 ms/step. Total
for 50 traj × 3000 steps = 50 × 75 s = 3700 s ≈ 1 hour.

**TDHFB ~ 4 min vs TWA ~ 1 hour per config**. TDHFB is **substantially faster**
because it's deterministic (single trajectory) and the only cost overhead is the larger
state vector ($D^2$ fields).

## Expected outcomes on Eu post-quench collapse

Three possible TDHFB outcomes for Eu post-quench at $N = 10^4$ (marginal collapse):

### Scenario A: TDHFB stabilizes (quantum fluctuation suppresses collapse)

- $|\phi|^2$ density profile: stable filament shape, no super-collapse
- $\langle\rho\rangle/|\phi|^2$ ratio: ~0.05-0.1 (= 5-10% non-condensed fraction)
- Physical interpretation: pair correlations stabilize against MF collapse, similar to
  LHY droplet mechanism but with non-uniform spinor structure

This would be the **quantum-fluctuation-driven Eu droplet** prediction, analog to Dy
droplets but mediated by TDHFB pair amplitudes.

### Scenario B: TDHFB re-renormalizes (chaos with reduced amplitude)

- $|\phi|^2$ density profile: still collapses, but to softer filament than MF
- $\sigma_{\rm TDHFB}/\mu$ effective fluctuation: ~0.1-0.2 (less than TWA chaos = 0.42)
- Physical interpretation: quantum fluctuations partially smooth out the classical
  chaos but don't prevent collapse

This is the most likely outcome based on TWA results indicating LHY-insufficient (§5.2).

### Scenario C: TDHFB diverges (TDHFB breakdown in chaotic regime)

- TDHFB integration fails to converge, pair amplitudes blow up
- Physical interpretation: TDHFB approximation itself breaks down because pair-pair
  correlations matter — need higher-order (Beliaev or full quantum) treatment

Scenario C would be a strong "negative result" indicating Eu chaos requires full
quantum treatment.

## Validation protocol

1. **Reproduce LHY limit**: in low-density limit, TDHFB should recover LHY droplet
   physics (= Dy droplet scaling). Test on F=6 polar phase at small $a_s$ where LHY
   matters → compare $\rho$ density profile with Lima-Pelster prediction.

2. **Reproduce TWA at large $N$**: TDHFB at large atom number → should match TWA
   averaged trajectory dynamics in the controlled regime.

3. **Energy conservation**: TDHFB total energy $\mathcal{E}$ should be conserved to
   $10^{-8}$ over $T \sim 10 \omega^{-1}$ with Strang splitting + Y4 (= same
   integrator family as Y4-midpoint of D-thesis Ch.3).

4. **Particle number conservation**: $N = \int (|\phi|^2 + \text{tr}\rho)$ exactly
   conserved (test: 32-bit relative drift $< 10^{-10}$).

## Implementation timeline

| Phase | Duration | Deliverable |
|---|---|---|
| 1 | 1 week | TDHFBState + storage layout |
| 2 | 2 weeks | HF kernels (phi, rho, kappa evolution) |
| 3 | 1 week | Strang TDHFB integrator |
| 4 | 1 week | YAML pipeline integration |
| 5 | 1 week | TWA-TDHFB comparison + validation |
| 6 | 1 week | Eu post-quench production runs |

**Total**: ~7 weeks dedicated work. **D-thesis Year 2 Q1 candidate** (= 2027-04 onwards).

## Risks + mitigations

### Risk 1: TDHFB non-convergence in chaotic regime

Even with proper TDHFB framework, if pair amplitudes blow up (Scenario C), the
calculation fails. **Mitigation**: implement adaptive timestep + L2 amplitude
monitoring; revert to mean-field if $\kappa$ amplitude exceeds threshold.

### Risk 2: Memory pressure on multi-config sweeps

84 MB per $\rho$ field × 50 configs = 4 GB GPU memory just for state. **Mitigation**:
serial config execution + JLD2 streaming snapshot save (similar to existing TWA
infrastructure).

### Risk 3: TDHFB self-consistency convergence

HF iteration (= update $h^{\rm HF}$ from $\phi, \rho, \kappa$, then re-evolve) may
not converge for Eu deep-collapse regime. **Mitigation**: damped iteration + Anderson
acceleration; fallback to predictor-corrector with truncated HF.

## Publication target

If TDHFB pilot succeeds (Scenarios A or B), the work is publication-ready as
**Paper #5** (post-修論, D-thesis-era output):

- Title: "TDHFB analysis of post-quench dipolar instability in F=6 spinor BEC"
- Target: PRA or PRR
- Length: ~10-12 pages
- Content: TDHFB formalism + Eu post-quench + comparison with TWA chaos + droplet
  prediction (if Scenario A) or chaos renormalization (Scenario B)

## Connection to other D-thesis work

TDHFB pilot directly connects to:

1. **D-thesis Ch.3 integrator modernization** (= post-修論 paper from this session):
   TDHFB benefits from Y4-midpoint integrator + Strang-midpoint kernels (= same
   infrastructure)

2. **D-thesis paper3 v4** (= Sign Pattern proof completion): TDHFB on polyhedral inert
   states could verify the Anomalous Identity at finite-N, providing experimental
   connection beyond mean-field

3. **D-thesis Year 3 experimental synthesis** (= 上妻研 collaboration): TDHFB density
   profile + pair correlation predictions are direct observables for Eu post-quench
   imaging experiments

## Summary

TDHFB pilot is a **7-week dedicated D-thesis Year 2** project that:
- Extends Chapter 5 TWA chaos finding to controlled beyond-mean-field treatment
- Tests three scenarios (stabilize / renormalize / breakdown) for Eu post-quench
- Provides direct experimental observables (density profile + pair correlation)
- Connects to D-thesis Ch.3 integrator work + paper3 Sign Pattern + Year 3 experimental
  synthesis

Cost: ~175 MB GPU state, ~4 min per config, ~7 weeks dev effort. Publishable as
Paper #5 (PRA / PRR target) regardless of which scenario realizes.
