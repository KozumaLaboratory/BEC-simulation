# Superfluidity & dipolar supersolidity — what we know, what we don't

**As of 2026-07-28** (revised same day: four open questions closed). Knowledge-state map for one domain: measures of
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
| For an **untextured** spinor, the scalar $f_s$ is the whole story | **measured** | 1D spin-1 GP, twisting all components together (mass) vs $+q,0,-q$ (spin): both agree with the density-only $f_s$ to 4 digits across polar, ferro and $c_1=0$ |
| For a **textured** spinor it is not: the density-only $f_s$ overestimates by ~2.6× | **measured** | winding field $B(x)=B(\cos kx,\sin kx,0)$: mass-twist $f_s = 0.136$ vs density-only $0.351$ |
| A textured state carries a **spin current**, so a scalar "spin $f_s$" is not even defined by the twist formula | **proven** | $E(q)$ for the $+q,0,-q$ twist is *linear*, not quadratic: $+2.53, +1.26, 0, -1.25, -2.50$ (×10⁻³) — perfectly antisymmetric. $2(E(q)-E(0))/q^2$ then diverges as $q\to0$ |

The practical upshot: **an $f_s$ from a GP ground state may be quoted as *the*
mean-field superfluid fraction**, not merely a bound on it. That is a stronger
statement than the metric shipped with, and it is gated.

### Not known

- **How large the beyond-mean-field correction is for a dipolar BEC.** The
  solid-⁴He factor of ~20 is the only calibration point in the literature, and it
  is a strongly correlated solid, not a dilute gas. Nothing here bounds the gap
  for a dipolar supersolid. *Would settle it:* QMC for the same tube geometry, or
  a Bogoliubov-level estimate of the backflow contribution.
- ~~Whether $f_s$ means the same thing for a spinor texture.~~ **Answered
  2026-07-28, and the answer is no** — moved to "known" below.
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
| **11 droplets is the energy minimum**, not just the wavelength noise selects | **measured** | period imposed at $L/n_d$ for $n_d = 8\ldots14$, each converged separately: $E$ has a clean minimum at $n_d=11$, rising $+3.3\times10^{-3}$ at 12 and $+1.2\times10^{-3}$ at 10 |
| The preferred droplet count **drops as $\epsilon_{dd}$ rises** | **measured** | minimum moves 11 → 9 going from $\epsilon_{dd}=1.45$ to 1.55; the paper's 11 is quoted at 1.45 |
| Tube images converge as $1/L_t^{2}$, not $1/L_t^{3}$ | **measured** | three ratios match $1/p^2$ to four decimals, exclude $1/p^3$; physically, images are parallel *lines* of dipoles and line–line energy per unit length falls as $1/R^2$ (#118) |
| Transverse padding by $p$ is exactly a box $p$ times wider | **proven** | agreement to $\le3\times10^{-12}$ across FFTs of different sizes |

### Not known

- ~~Whether the droplet count is the ground state or a local minimum in droplet
  number.~~ **Answered 2026-07-28** — moved to "known" below. What remains open is
  narrower: the scan varies the period at fixed *shape*, so a qualitatively
  different modulated state (unequal droplets, a defect) is still not excluded.
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
| The `c_lhy` fix does **not** change the LHY-sensitivity verdicts | **measured** | A/B in *identical* code (old 630.9 vs new 2442): K3=0 gives peak_max 0.005656 → 0.005775, K3=200 gives 0.004505 → 0.004654. 2–3 %, same classification in both |
| It does make LHY ~11× more consequential for peak density than the old runs showed | **measured** | LHY off vs on in current code: peak_max 0.006834 → 0.006448, i.e. 5.6 % suppression, against 0.5 % in the stored May rows |
| No other auto-derived dimensionless coupling is mis-scaled | **proven** | SI anchors for `c_total` ($g=4\pi\hbar^2a_s/m$), `c_dd` ($2\epsilon_{dd}$ along B̂), `p` ($g_F\mu_BB$), `q` ($(g_J\mu_BB)^2q_{geom}/\Delta_{hf}$), each with exponents pinned separately |

### Not known / outstanding

- ~~Whether any other auto-derived coefficient has the same disease.~~
  **Answered 2026-07-28: no.** `test_dimensionless_coefficient_si_roundtrip.jl`
  gates `c_total`, `c_dd`, `p` and `q` against convention-free SI anchors, plus
  their $N$ and $\omega_{ref}$ exponents separately. 82/82.
- ~~Which conclusions from the LHY-sensitivity configs change.~~ **Answered
  2026-07-28: none of them** — see below.
- **The stored results under `runs/` are stale against current `main`**, and by
  much more than the coefficient fix. Re-running `eu_k3_lhy_control` LHY=scalar
  in current code gives peak_max 0.005775 where the stored May row says 0.007487,
  and the classification moves `delay` → `marginal_arrest`. The A/B below shows
  only 2 % of that is `c_lhy`; the rest is accumulated code change since May
  (full_bdg UV counterterm, LHY quadrature, FM closed forms, …). **Nothing has
  audited which stored verdicts still hold.** *Would settle it:* re-run the
  stored suites in current code, or stamp each stored summary with the commit
  that produced it.

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
| every derived dimensionless coupling vs SI | `test/oracles/test_dimensionless_coefficient_si_roundtrip.jl` | fast |

Detail and reproduction instructions: [`dipolar_supersolid_tube.md`](dipolar_supersolid_tube.md).
Figures: `figs/dipolar_supersolid/fs_curve.png` ($f_s$ vs $\epsilon_{dd}$),
`figs/dipolar_supersolid/period_scan.png` (energy vs imposed droplet count).

## Cheapest next steps, in order

The four listed on 2026-07-28 were all executed; see the "Answered" entries
above. What they left:

1. **Decide what `superfluid_fraction` should return for a spinor.** The scalar
   is now known to be wrong by ~2.6× on a textured state, and the spin channel
   needs a definition that minimises over the twist first (a state with a texture
   carries a current, so $E(0)$ is not the parabola's vertex). Until then, the
   function should arguably refuse — or at least warn — on a spinor whose local
   spin direction varies. **Nothing warns today.**
2. **Audit which stored `runs/` verdicts still hold** in current code, or stamp
   each stored summary with its producing commit. The May results differ from
   current code by far more than the coefficient fix.
3. **Vary the modulated state's shape, not just its period** (unequal droplets, a
   defect) — the period scan fixes the shape and so does not exclude those.
4. **A cylindrically truncated dipolar kernel** to remove the residual $1/L_t^2$
   tail in absolute $E_{dd}$ (§2).
