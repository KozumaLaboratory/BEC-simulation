# ¹⁵¹Eu finite-temperature trap-shape optimization

The definitive, finite-temperature version of the $T=0$ trap-shape study
(`eu_shape_optimization.md`). At $T>0$ the shape optimum is governed by a
competition the $T=0$ Gross–Pitaevskii picture cannot see, so we evolve the
**Stoof-form (full-Hamiltonian) Stochastic Projected Gross–Pitaevskii equation**.

Driver: `docs/guides/figures/eu_shape_finite_t.jl`. Runs on TSUBAME H100 via
`scripts/eu_shape/submit_finite_t.sh` (modes `probe | campaign | equilibrium | kcut | shape`).

## Physics

Three-body loss favours expansion (lower density $\Rightarrow$ less loss,
$\langle n^2\rangle\propto\bar\omega^{12/5}$). At finite $T$ the counter-force is
the condensate itself: $T_c\propto\hbar\bar\omega N^{1/3}$ drops as the trap
loosens, so at fixed $T$ the condensate melts. The resolution — and the reason
expansion still wins — is adiabaticity: an adiabatic expansion cools the gas
($T\propto\bar\omega$) in step with $T_c\propto\bar\omega$, so $T/T_c$ is
**preserved** and the condensate survives while the density (and loss) fall.

Model: a single stretched $|m=-6\rangle$ component (scalar-equivalent), physical
$K_3$ loss, and the SGPE dissipative + thermal sub-step
$\psi\leftarrow\psi-\gamma(\hat H[\psi]-\mu)\psi\,dt + \sqrt{2\gamma T\,dt/dV}\,\xi$,
which relaxes toward the interacting thermal state at $(\mu,T)$.

## Two normalization/physics points that must be right

**Norm-N.** The FDR noise amplitude $\sigma=\sqrt{2\gamma T\,dt/dV}$ assumes
$|\psi|^2$ is the *physical* density ($\int|\psi|^2=N$). The $T=0$ driver uses
norm-1 ($\int|\psi|^2=1$, with $N$ folded into $c_0=\tilde g N$); running the SGPE
there makes the noise $\sqrt N$ too large and the thermal cloud $\sim N\times$ too
heavy. The finite-T driver therefore runs **norm-N**: seed $\psi_N=\sqrt N\,\psi_1$
and use the bare couplings $c_0=\tilde g$, $K_3=\tilde K_3$. The mean field
$\tilde g|\psi_N|^2=\tilde g N|\psi_1|^2$ and the loss $n=|\psi_N|^2$ are then both
correct, and $\int|\psi|^2$ is the physical atom number.

**Closed-system ramp.** A fixed-$\mu$ Stoof bath is grand-canonical: when the trap
loosens, the GP fixed point at that $\mu$ holds more atoms, so the bath *pumps*
the condensate — unphysical for an atom-survival question. So the bath ($\gamma$,
noise) runs only during the **preparation** phase; the shape ramp is evolved as a
**closed system** ($\gamma=0$, loss on), where the gas cools adiabatically as it
expands.

**Condensate measure.** $N_0=\int|\langle\psi\rangle|^2\,dV$, the phase-fixed
ensemble mean of the stretched component (thermal fluctuations cancel across
trajectories). This is the coherent condensate; it coincides with the
Penrose–Onsager condensate up to amplitude-fluctuation ($\langle|a_0|\rangle^2$ vs
$\langle|a_0|^2\rangle$) corrections, which are second order and small away from
$T_c$.

**Classical-field cutoff.** The noise populates every mode, so a projection at
$k_\mathrm{cut}$ with $\varepsilon(k_\mathrm{cut})-\mu\approx T$ (i.e.
$k_\mathrm{cut}=\sqrt{2(\mu+T)}$) defines the classical region; the grid must
resolve it ($k_\mathrm{max}=\pi/dx>k_\mathrm{cut}$, hence $\ge 48^3$).

## Validation (falsifiable, not hand-waved)

| Check | What | Where |
|---|---|---|
| **V-FDR** | Rayleigh–Jeans equilibrium $\langle|\hat\psi(k)|^2\rangle=T/(\tfrac12k^2-\mu)$ | existing `test_sgpe_fdr.jl` |
| **V-Stoof** | $T\to0$ relaxes to the interacting GP ground state | existing `test_sgpe_stoof.jl` |
| **V-key** | condensate fraction $f\to1$ as $T\to0$ | `ft_equilibrium` |
| **V-mono** | $f$ monotone decreasing, $\to0$ near $T_c$ | `ft_equilibrium` |
| **V-kcut** | condensate $N_0$ **independent** of $k_\mathrm{cut}$ (only the thermal cloud scales) | `ft_kcut_convergence` |

V-kcut is the direct rebuttal to "the classical-field temperature is just a
control parameter": the *thermal* population is indeed cutoff-dependent, but the
*condensate* — an infrared, macroscopically-occupied quantity — is not.

Reference: $f$ vs the ideal-Bose $1-(T/T_c)^3$. The SGPE sits below it, the
expected signature of classical-field (Rayleigh–Jeans) thermal over-occupation
plus interactions; it is not a fit.

## Results

Figures (from the TSUBAME campaign): `eu_ft_equilibrium.png` (V-key/V-mono),
`eu_ft_kcut.png` (V-kcut), `eu_ft_shape.png` (HOLD vs DECOMPRESS vs BOX condensate
survival). Numbers are filled in when the campaign completes.
