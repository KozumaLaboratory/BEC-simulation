# Superfluidity & dipolar supersolidity — what we know, what we don't

**As of 2026-07-28.** Knowledge-state map for one domain: measures of
superfluidity in this simulator (`superfluid_fraction`) and the dipolar
supersolid physics they are used on. Organised by *claim*, each with the
evidence that supports it and the confidence that evidence buys — followed by
the open questions and the model's structural limits.

Not a changelog. Where a claim came from a specific PR the number is given as a
pointer, but the point of each row is what it licenses you to say.

Confidence vocabulary, used strictly:

| tier | meaning |
|---|---|
| **proven** | exact/analytic identity, or agreement to round-off; a violation would be a code bug |
| **measured** | numerical agreement with an independent calculation, within a stated tolerance |
| **indicated** | one calculation, no independent check; could survive or not |
| **assumed** | inherited from the model or the literature, not tested here |

---

## 1. The measure itself

### Known

| Claim | Confidence | Evidence |
|---|---|---|
| $f_s$ from the phase-twist free energy is well-defined on a periodic box and equals 1 for uniform density, $\sqrt{1-A^2}$ for a cosine of contrast $A$ | **proven** | analytic; `test_superfluid_fraction.jl` (#99) |
| The Leggett plane-average form and the full variational relaxation are the same number when the density varies along the flow axis only | **proven** | both branches implemented independently; agree to $O(dx^2)$ with the relaxed branch's error sign and order pinned |
| **Rigid density is exact within mean field** — not an upper bound | **measured** | direct twisted-BC GP minimisation, independent code path, $f_s$ from $1.5\times10^{-4}$ to 0.53, agreement 5e-3 relative; residuals verified *not* one-sided (#121) |
| Beyond mean field, $f_s$ *is* an upper bound (one-body phase cannot carry correlated backflow) | **assumed** | standard argument; the solid-⁴He gap (Leggett ~20 % vs experiment ~1 %) is the known instance |
| $f_s \approx 0$ for a trapped cloud is geometry, not state | **proven** | no phase rigidity across a box with vacuum at the edge; the code warns rather than returning a bare 0 |
| `:relaxed` costs 1.8 s at 128³ and is flat in density contrast | **measured** | 0.21 → 0.25 s from contrast 0.2 to 0.99 at 64³; no preconditioner needed |

The practical upshot: **an $f_s$ from a GP ground state may be quoted as *the*
mean-field superfluid fraction**, not merely a bound on it. That is a stronger
statement than the metric shipped with, and it is gated.

### Not known

- **How large the beyond-mean-field correction is for a dipolar BEC.** The
  solid-⁴He factor of ~20 is the only calibration point in the literature, and it
  is a strongly correlated solid, not a dilute gas. Nothing here bounds the gap
  for a dipolar supersolid. *Would settle it:* QMC for the same tube geometry, or
  a Bogoliubov-level estimate of the backflow contribution.
- **Whether $f_s$ means the same thing for a spinor texture.** Everything
  validated is scalar (single component, or a spinor collapsed to its total
  density). For a multi-component state with spin textures there are additional
  superfluid modes — spin superfluidity, and a matrix $f_s^{ij}$ rather than a
  scalar per axis. The current implementation reduces the spinor to $n(\mathbf r)$
  and answers only the mass-flow question. Whether that is the interesting
  question for an F=6 texture is untested. *Would settle it:* a twisted-BC
  calculation on a spinor state, twisting each component's phase independently.
- **The comoving-frame vs plane-average definitions beyond $O(q^2)$.** Roccuzzo &
  Ancilotto define $f_s = 1 - \langle P_x\rangle/(Nmv_x)$; we use the Leggett
  closed form. They agree at $O(q^2)$ in mean field — measured, not assumed — but
  the higher-order structure has not been compared, and neither has any
  Josephson-junction-style definition (Biagioni 2024).

---

## 2. Dipolar supersolid in a periodic tube

### Known

| Claim | Confidence | Evidence |
|---|---|---|
| A modulated ground state exists above $\epsilon_{dd}\approx1.4$ for the ¹⁶⁶Er tube cell, and does *not* below | **measured** | both branches relaxed to convergence, energies compared; bracketed to $(1.41,1.44)$ against the paper's $\approx1.40$ (#120) |
| The transition is first-order in the sense the reference means | **measured** | at $\epsilon_{dd}=1.41$ the modulated branch *exists* but sits $+8\times10^{-5}$ above uniform (metastable window); below 1.38 it relaxes onto uniform to round-off, i.e. no second branch |
| $f_s$ jumps at the transition and decays to ~0 in the droplet regime | **measured** | 1.0 → 0.733 (1.44) → 0.309 (1.48) → 0.0024 (1.65); matches the reference's Fig. 2 structure |
| The droplet count is a prediction of the model, not of the seed | **measured** | three broadband-noise seeds all select 11 droplets at $d=1.443\ \mu$m, the reference's value |
| The dipolar kernel and realized $\epsilon_{dd}$ are correct | **proven** | measured from the code's own kernel at two independent angles: $k\parallel B\to+2\epsilon_{dd}$, $k\perp B\to-\epsilon_{dd}$, both exact |
| $Q_5(\epsilon_{dd})$ is correct | **proven** | $Q_5(0)=1$, $Q_5(1)=3^{5/2}/6$ analytic, $1+\tfrac32\epsilon^2$ small-$\epsilon$ |
| Tube images converge as $1/L_t^{2}$, not $1/L_t^{3}$ | **measured** | three ratios match $1/p^2$ to four decimals, exclude $1/p^3$; physically, images are parallel *lines* of dipoles and line–line energy per unit length falls as $1/R^2$ (#118) |
| Transverse padding by $p$ is exactly a box $p$ times wider | **proven** | agreement to $\le3\times10^{-12}$ across FFTs of different sizes |

### Not known

- **Whether the modulated state at larger $\epsilon_{dd}$ is the ground state or
  metastable.** The reference says so of its own results ("we cannot exclude that
  for higher values of $\epsilon_{dd}$ the solution we find is a metastable state
  rather than the ground-state"), and our calculation has the same limitation: we
  compare two seeded branches, not an exhaustive search. The droplet count could
  be a local minimum in the number of droplets. *Would settle it:* scan the
  imposed period around $d=L/11$ and confirm 11 is the energy minimum, not just
  the noise-selected attractor. **This is cheap and has not been done.**
- **Absolute $E_{dd}$ for the isolated tube** is extrapolated ($1/L_t^2$
  Richardson), not exact. The unpadded $L_t=16$ value is 3.6 % low. *Would settle
  it:* a cylindrically truncated kernel — which has no closed-form Fourier
  transform, unlike the spherical Ronen–Bortolotti–Bohn cut (and that spherical
  cut is the wrong tool here: it would cut the axial direction and destroy the
  ring periodicity the geometry depends on).
- **Whether the LDA treatment of LHY is valid across the modulated state.** The
  quantum-fluctuation term is applied as a local function of density. In the
  droplet regime the density varies on the scale of the healing length, which is
  where LDA is questionable — and that is exactly the regime where LHY is what
  stabilises the state. Both we and the reference make this assumption. *Would
  settle it:* a full BdG evaluation of $\epsilon_{LHY}$ on the modulated state
  (the machinery exists as `FullBdGLHY` for the spinor path, not the scalar one).
- **Three-body loss** is absent from the supersolid calculation. Droplet peak
  densities are where $K_3$ matters most; the state may not be experimentally
  reachable even if it is the T=0 ground state.
- **Finite temperature.** Everything is T=0. The reference likewise.
- **No spinor DDI path was validated by any of this.** The scalar eGPE is a
  separate code path with its own kernel; the production spinor path (`ws.ddi`,
  `make_ddi_padded`) shares only conventions with it.

---

## 3. The coefficient chain that feeds both

### Known

| Claim | Confidence | Evidence |
|---|---|---|
| The dimensionless scalar LHY coefficient is $\frac{128\sqrt\pi}{3}\tilde a^{5/2}N^{3/2}Q_5$ in this repo's per-particle convention | **proven** | fixed by the SI ratio $\mu_{LHY}/\mu_{contact}=\frac{32}{3}\sqrt{n a_s^3/\pi}$, which has no convention freedom; gated at three densities × three species (#108) |
| The previously shipped value was short by $\pi\tilde a\sqrt N$ | **proven** | same oracle; 11.7× for ¹⁶⁴Dy, 6.8× for ¹⁵¹Eu at their production parameters |
| That error is a few per cent of the contact energy for the affected Eu runs, not a regime change | **measured** | TF peak density estimate; LHY/contact goes 1.56 % → 3.6 % at $N=10^4$, 0.78 % → 5.8 % at $N=10^5$ |
| The error changes sign below $N\approx1100$ | **proven** | $\pi\tilde a\sqrt N$ crosses 1 there; it is an $N$ vs $N^{3/2}$ exponent error, so it is not uniformly one-signed |
| Our LHY convention matches the reference's | **proven** | their $\gamma=(32/3\sqrt\pi)ga^{3/2}F(\epsilon_{dd})$ with $F=Q_5$ is our `scalar_lhy_coefficient` |
| The scalar eGPE energy functional now matches its propagator | **proven** | FD identity with $\gamma\ne0$; canaried — removing $E_{LHY}$ fails by 164 % and flips the derivative's sign (#110) |

### Not known / outstanding

- **Which conclusions from the ~60 affected configs change.** Absolute impact is
  a few per cent, so most are probably unaffected — but the runs that *measured
  LHY sensitivity* were comparing against a term ~4× weaker than intended, and
  their verdicts are not yet re-derived: `eu_k3_lhy`, `eu_k3_lhy_control`, the
  LHY0/LHY1 arms of `eu_robust_factorial`. `twa_N_scan` at $N=10^5$ has the
  largest relative change. **Not re-run as of 2026-07-28.**
- **Whether any *other* auto-derived dimensionless coefficient has the same
  disease.** The `c_lhy` bug was invisible to units checks and to every test that
  passed the coefficient in explicitly. Nothing systematic has audited the other
  auto-derivations (`c_dd`, `c0`/`c1` from scattering lengths, $q$ from $B$)
  against convention-free SI statements the way `test_scalar_lhy_si_roundtrip.jl`
  now does for this one. *Would settle it:* one SI-ratio oracle per derived
  coefficient.

---

## 4. ¹⁵¹Eu-specific: what blocks quantitative claims

This is the production target, and it is where the unknowns are worst.

| Quantity | State |
|---|---|
| $a_s$ (mean) | **measured**: 110(4) $a_0$ (Miyazawa 2022) |
| The 7 channel-resolved $a_S$ ($S=0,2,\dots,12$) | **unknown**. Tomza's Eu+Eu ab initio work fixes only the long range ($C_6=3610$ a.u. ⇒ $R_6=178\,a_0$) and treats $a_{S=7}$ as a free scaling parameter. There is no theoretical value to quote |
| $g_F$, $\mu$, $q$-geometry | **proven** from $(F,I,J,g_J)$; $q/h=1.43$ kHz/G² at 1 G |
| $K_3$ | **measured** but with a ~2.6× systematic between direct and BEC-fit determinations |
| Near-threshold bound states | **unknown** — which is what blocks any type-C claim for RF/MW-dressed scattering (#101): without a free–bound detuning there is no $a_S(\text{RF})$ curve to produce |
| $a_s$ for ¹⁵³Eu | **unknown**; the registry entry carries the ¹⁵¹Eu value as an explicit placeholder |

Consequence: for Eu, **type A (code correctness) is achievable now and type C
(model fidelity) is blocked on atomic-physics inputs** for anything that depends
on channel-resolved interactions. Claims that turn only on $q$, on $\epsilon_{dd}$,
or on geometry are quotable today.

---

## 5. Method knowledge — things that are easy to get wrong

Recorded because each cost time, and each is a trap independent of the code.

- **"Does a small seed survive imaginary time" measures the spinodal, not a
  first-order transition point.** Inside the metastable window a small seed dies
  even though the modulated branch is lower. Both branches must be converged and
  their energies compared — which requires the energy functional to be the one
  actually minimised.
- **ITP is minimisation, not smoothing.** Perturbations decay as
  $e^{-\varepsilon_k\tau}$ with $\varepsilon_k$ the Bogoliubov energy; where a mode
  is unstable, imaginary time *grows* it. A modulated seed dying means the uniform
  state is locally stable, which is information.
- **Checking a derived quantity against its own construction proves nothing.**
  Setting `c_dd = 12π(a_dd/a_ho)N` and then verifying $c_{dd}/(3g)=\epsilon_{dd}$
  is self-referential. Measuring the kernel at two independent angles is not.
- **A trial state must be resolvable before its energy means anything.** A droplet
  seed at 1.6 grid points per $\sigma$ produced $\Delta E=+35.7$ of pure
  representation error, which imaginary time then flattened.
- **Read §II for the species, not the introduction.** Roccuzzo & Ancilotto
  simulate ¹⁶⁶Er; the ¹⁶⁴Dy in their introduction is a cited experiment. With Dy
  no supersolid forms below $\epsilon_{dd}=1.75$.
- **Extrapolate with the right exponent.** Tube images fall as $1/L^2$ (line–line),
  not $1/L^3$ (point–point). Using $1/L^3$ gives a wrong limit from correct data.

## Instruments

| What it gates | File | Tier |
|---|---|---|
| $f_s$ analytic + branch consistency | `test/analysis/test_superfluid_fraction.jl` | fast |
| $f_s$ exact within mean field (type B) | `test/analysis/test_superfluid_fraction_gp_twist.jl` | fast |
| $f_s$ on device arrays (F64 + F32) | `test/gpu/test_superfluid_fraction_gpu.jl` | full, gated |
| scalar $c_{lhy}$ vs SI | `test/oracles/test_scalar_lhy_si_roundtrip.jl` | fast |
| padding ≡ box enlargement, $1/L^2$ exponent | `test/solvers/test_scalar_ddi_transverse_pad.jl` | fast |
| supersolid regime + species + $Q_5$ (type C) | `test/validation/test_dipolar_supersolid_tube.jl` | ci |

Detail and reproduction instructions: [`dipolar_supersolid_tube.md`](dipolar_supersolid_tube.md).
Figure: `figs/dipolar_supersolid/fs_curve.png`.

## Cheapest next steps, in order

1. **Scan the imposed droplet period** around $d=L/11$ to confirm 11 is the energy
   minimum rather than the noise-selected attractor. Closes the largest open
   question in §2 and costs a handful of ITP runs.
2. **Re-run the LHY-sensitivity configs** listed in §3 and re-derive their
   verdicts.
3. **SI-ratio oracles for the remaining auto-derived coefficients** (§3), since
   the one bug found was invisible to every other kind of check.
4. **Twisted-BC calculation on a spinor state** to find out whether the scalar
   $f_s$ is the quantity of interest for an F=6 texture at all (§1).
