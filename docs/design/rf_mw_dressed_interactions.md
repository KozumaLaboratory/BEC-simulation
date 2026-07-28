# RF/MW-dressed interactions — where the physics lands in the code

Status: **design only, no implementation.** Written to answer one question before
any code is added: *does an effective $a_S(\text{RF})$ fit into
`TimeDependentInteractions`, or does it need a new `HamTerm`?*

Short answer: **three separable effects hide under "RF/MW dressing", and only one
of them needs new machinery.** Building them as one feature would fuse a
coefficient map, a one-body operator, and a DDI knob into a single confused
block.

## The three effects

Driving near a hyperfine transition changes the gas in three ways that are
independent and enter at different layers.

**(A) Dressed one-body structure.** The drive mixes the $F$ and $F'$ manifolds.
In the dressed basis the effective $g_F$, $q$, and the whole intra-manifold
level structure shift. Far off resonance ($\Omega \ll |\delta|$) the upper
manifold adiabatically eliminates and leaves an AC-Zeeman shift acting inside
$F$: a spin-space matrix $\sum_k \beta_k (\mathbf{F}\cdot\hat{e})^k$ multiplied
by the drive intensity profile. Near resonance it does *not* reduce, and the
state lives in $F \oplus F'$.

**(B) Dressed two-body scattering, $a_S(\omega,\Omega)$.** When the drive
frequency approaches a free-bound transition, virtual spin-flip transitions of
the colliding pair produce a Fano-Feshbach resonance and the scattering length
picks up a dispersive term (Papoular–Shlyapnikov–Dalibard). At GP level the
output is *only* a modified set of channel scattering lengths. No new operator —
a parameter map.

**(C) Time-averaged DDI.** A field whose orientation rotates fast compared with
the trap and the dipolar mean-field time-averages the dipole-dipole interaction
to $c_{dd} \to c_{dd}\,(3\cos^2\theta - 1)/2$, tunable across
$[-1/2, 1]$ including zero (Giovanazzi–Görlitz–Pfau).

## Where each lands

| Effect | Layer | Existing machinery | Gap |
|---|---|---|---|
| (A) far-detuned AC-Zeeman | one-body operator | `LightShift` — per-voxel spin matrix `(U, eigvals, profile, is_diagonal)`, already an exact fit | builder only; **naming debt** (see below) |
| (A) near-resonant $F \oplus F'$ | state representation | none | out of scope — needs a 24-component ($F{=}6 \oplus F{=}5$) state |
| (B) $a_S(\text{RF})$ | coefficient map | `feshbach_ramp` pattern + `hamiltonian/coefficients.jl` ($c \leftrightarrow g$) | `TimeDependentInteractions` truncates at $c_0, c_1$ |
| (C) rotating-field DDI | existing term | `secular_ddi` + `spin_rotating_frame_omega` | no explicit $(3\cos^2\theta-1)/2$ knob |

## Decision: `TimeDependentInteractions` is not enough

Three concrete gaps, all in effect (B):

1. **Channel truncation.** `interactions_at(::TimeDependentInteractions, t)`
   returns `InteractionParams(Dict(0 => …, 1 => …))`. For ¹⁵¹Eu at $F=6$ there
   are 7 channels ($S = 0, 2, \ldots, 12$); a dressing field detuned near one
   free-bound transition moves *that* channel, not $c_0$ and $c_1$ uniformly.
   The struct carries two waveforms where it needs a waveform per active channel.

2. **The tensor path is not on the time-dependent route at all.** With
   channel-resolved scattering lengths, `make_workspace` takes the tensor path
   ($c_0 = c_1 = 0$, `TensorInteractionCache` handles everything) and the
   propagator reads `ws.tensor_cache` directly — `interactions_at` never touches
   it. For Eu this is the *only* path that matters.

3. **Cache rebuild cost.** `TensorInteractionCache` is
   `(F, D, cg_table, active_channels, g_values)`. The expensive part is
   `cg_table`; `g_values::Vector{Float64}` is a plain mutable vector holding
   exactly the per-channel couplings. So the update is an in-place write of
   `g_values` per substep, not a cache rebuild. This is the design lever that
   makes per-step channel-resolved time dependence affordable.

## Proposed shape (not yet built)

**Carrier.** Replace the two-waveform struct with one that carries the whole
channel vector, keeping `interactions_at` as the single evaluation point:

```
struct TimeDependentInteractions
    channels::Vector{Int}          # 0, 1, or S-channel labels
    waveforms::Vector{Waveform}    # one per channel, pre-sampled
end
```

Concrete `Waveform` elements only — never closures. Rule 2 of the type-stability
firewall: a `t -> a_S(t)` closure escaping into `Workspace` is the 30-minute-JIT
failure mode. The dressing law gets pre-sampled to `PiecewiseLinearWaveform`
exactly as `feshbach_ramp` already does, which is the precedent to copy
verbatim.

**Dressing law.** A pure function, no state:

```
dressed_scattering_lengths(a_S::Dict{Int,Float64}, drive) -> Dict{Int,Float64}
```

with the same dispersive shape the Feshbach helper already uses,
$a \to a_{bg}(1 - \Delta/(\delta - \delta_0))$, per channel. Placing it beside
`hamiltonian/coefficients.jl` keeps the $a_S \to g_S \to c_n$ algebra
single-declaration.

**(A) far-detuned branch.** One operator, two builders. The AC-Zeeman shift from
an RF/MW drive is the same mathematical object as an optical light shift — a
per-voxel spin matrix times a spatial profile — and `LightShift` already stores
and propagates exactly that. Duplicating the kernel would be ungated duplication
of the kind commitment #3 forbids.

The cost is a naming violation: a type called `LightShift` carrying an RF shift
breaks "function name = what the body computes". 75 occurrences across 42 files,
mechanical. Recommendation: **do the rename in the same commit** that adds the
second builder, rather than accruing the debt — the repo has no
backward-compat-alias policy to soften it later.

**(C)** needs no structural work; the missing piece is a documented
$\theta$-to-$c_{dd}$ helper and a note that
`spin_rotating_frame_omega ≠ 0` already requires `secular_ddi = true`
(`ArgumentError`, by design — the off-diagonal DDI components Larmor-average to
zero only in the secular limit).

## Why Eu specifically

The distinguishing number is the hyperfine splitting. ¹⁵¹Eu has
$\Delta_{hf}(F{=}6 \leftrightarrow F{=}5) = 121$ MHz and ¹⁵³Eu has 53 MHz
(6·|a_hf|, a_hf = −20.052 / −8.853 MHz), against 6.8 GHz for ⁸⁷Rb. Consequences:

- The manifold-mixing drive is **RF, not microwave** — cheap, agile, easy to
  ramp and phase-control.
- Strong dressing needs a modest Rabi frequency, since what matters is
  $\Omega/\Delta_{hf}$.
- The drive is well separated from intra-manifold dynamics at the fields this
  project runs at: $g_F \mu_B B/h \approx 1.6$ MHz/G, so at the µG–G fields of
  the Eu phase-diagram work the Larmor frequency is kHz–MHz while the dressing
  sits at 121 MHz. Manifold mixing and spin dynamics are addressable
  independently.
- The same small $\Delta_{hf}$ is why the quadratic Zeeman is large
  ($q \propto 1/\Delta_{hf}$): 1.43 kHz/G² for ¹⁵¹Eu, ≈ 3.3 kHz/G² for ¹⁵³Eu.
  Any dressing scheme has to be evaluated against $q$, not only against the
  linear Zeeman.

## What is *not* known

The code layer is buildable and testable today; the physics input is not. For
Eu the seven $a_S$ are unmeasured — Tomza's Eu+Eu potential fixes only the long
range ($C_6 = 3610$ a.u. ⇒ $R_6 = 178\,a_0$) and treats $a_{S=7}$ as a free
parameter scaled by $\lambda \in [0.97, 1.03]$. Without the near-threshold bound
states there is no free-bound detuning to quote, so no quantitative
$a_S(\text{RF})$ curve for Eu can be produced from the literature.

This splits cleanly along the repo's validation axes: a parameterized dressing
law can be gated at **type A** (code correctness — units, limits, $\Omega \to 0$
recovers the bare $a_S$, GPU=CPU) immediately. **Type C** (model fidelity)
stays blocked until either a coupled-channel calculation or a measurement fixes
the Eu near-threshold structure. A design that reports a dressed Eu $a_S$ as a
prediction before that would be a type-C claim with no anchor.

## Non-goals

- Near-resonant $F \oplus F'$ dynamics. That is a different state space, not a
  parameter change, and `Workspace` is single-$F$ by construction.
- Floquet-exact treatment. Everything above is the time-averaged / adiabatically
  eliminated limit; a drive period comparable to the split-step `dt` breaks it.
  Worth an explicit guard when implemented: warn when
  $2\pi/\omega_{\text{drive}} \lesssim \text{dt}$.
- Molecular-state population and dressing-induced loss. Fano-Feshbach dressing
  buys tunability at the cost of an inelastic rate that this design does not
  model; the existing `loss` term would carry it as a phenomenological channel.

## Open questions before writing code

1. Does any planned experiment need channel-*resolved* dressing, or is a single
   overall $a_s$ scaling enough? Gap (1) only matters for the former, and it is
   the bulk of the work.
2. Is the far-detuned AC-Zeeman branch (A) actually wanted, or is (B) alone the
   target? (A) alone is a builder plus the rename; (B) alone is the carrier
   redesign. They share nothing.
3. Should `dressed_scattering_lengths` and `feshbach_scattering_length` collapse
   into one dispersive-resonance helper? They are the same functional form with
   different arguments ($B - B_0$ vs $\delta - \delta_0$), and the existing
   docstring already notes optical Feshbach resonances reuse it.

## References

- D. J. Papoular, G. V. Shlyapnikov, J. Dalibard, "Microwave-induced
  Fano-Feshbach resonances", Phys. Rev. A **81**, 041603(R) (2010),
  doi:10.1103/PhysRevA.81.041603, arXiv:0909.4633. Mechanism for (B); computes
  the effect for ⁷Li, ²³Na, ⁴¹K, ⁸⁷Rb, ¹³³Cs.
- S. Giovanazzi, A. Görlitz, T. Pfau, "Tuning the dipolar interaction in quantum
  gases", Phys. Rev. Lett. **89**, 130401 (2002),
  doi:10.1103/PhysRevLett.89.130401, arXiv:cond-mat/0204352. Origin of (C).
- Y. Tang, W. Kao, K.-Y. Li, B. L. Lev, "Tuning the dipole-dipole interaction in
  a quantum gas with a rotating magnetic field", Phys. Rev. Lett. **120**,
  230401 (2018). Experimental realization of (C) in Dy.
- K. Zaremba-Kopczyk, P. S. Żuchowski, M. Tomza, "Magnetically tunable Feshbach
  resonances in ultracold gases of europium atoms and mixtures of europium and
  alkali-metal atoms", Phys. Rev. A **98**, 032704 (2018),
  doi:10.1103/PhysRevA.98.032704, arXiv:1806.02800. Eu hyperfine constants
  (Table I), Eu+Eu $C_6 = 3610$ a.u., $R_6 = 178\,a_0$, and the statement that
  $a_S$ is set by scaling the potentials rather than predicted.
- H. Miyazawa et al., "Bose-Einstein condensation of europium", Phys. Rev. Lett.
  **129**, 223401 (2022), arXiv:2207.11692. $a_s = 110(4)\,a_0$ for ¹⁵¹Eu.

Related in-repo: `docs/reference/dynamics.md` (time-dependent knobs),
`docs/conventions/adding_new_hamiltonian_term.md` (if (A) ever needs its own
term), `src/workflow/experiments/runtime/feshbach_ramp.jl` (the pre-sampling
pattern to copy).
