# Yan–Li–Saito Barnett proposal at physical ¹⁵¹Eu (F=6) — issue #338

Target: Yan, Li & Saito, *Barnett effect in rotating spinor dipolar quantum
droplets*, [arXiv:2605.11670v1](https://arxiv.org/abs/2605.11670) (12 May 2026).
Full text, appendix and figures read for this campaign; the paper's own Fig. 4 is
load-bearing for the verdict below.

## Answers

| # | question | answer |
|---|---|---|
| **1** | does the self-bound-droplet premise hold at the physical Eu value ε_dd = 0.54? | **No — by a theorem, at any atom number.** Confirmed by eGPE: the cell expands to 297 D₀ from a 92000 D₀ droplet seed. The proposal cannot be moved to physical Eu as a droplet. |
| **2** | does the macroscopic Larmor precession survive F=1 → F=6? | **Yes, and the magnetization is 4.07× larger**: ⟨f_z⟩ = 0.1678 at F=6 vs 0.0412 at F=1 (paper 0.04). The conservation structure m + v_m = ℓ holds for all 13 components. But F=6 needs **1.56× more atoms** to bind, and at the paper's own N = 15000 it is below threshold. |
| **3** | the precession frequency an experiment would look for | **f_L ≈ 2.6 Hz/nT (F=1 eff) and 2.7 Hz/nT (F=6)** — nearly equal, because F=6's 4× larger f_⊥ almost cancels its 3.9× smaller g_F. Against the published **± 10 nT** field-offset systematic that is **± 27 Hz of uncontrolled precession**, so the field must be zeroed well below 1 nT before the signal means anything. |

Type-A (code correctness) and type-B (physics agreement) results below are
labelled; the anchors against published figures are type-C.

---

## Gate 1 — premises, from the primary source

| premise | the paper |
|---|---|
| **ε_dd and how it is reached** | ε_dd ≡ a_dd/a_s with `a_dd = μ₀(gμ_B)²M/(12πℏ²)`. Reached by lowering `a_s`, not by changing μ: for ¹⁵¹Eu they assume "the F=1 hyperfine state … with a magnetic moment of 9/2 Bohr magneton and ε_dd = 1.2", i.e. a_s ≈ **20.6 a₀** (reproduces their L₀ = 16.35 µm to 4 digits). |
| **vortex imprint** | `ψ_m(r) = e^{iℓθ} ψ_{0,m}(r)`, θ = arg(x+iy), on the ℓ=0 ground state, "followed by energy relaxation with total angular-momentum conservation". Component vorticities are `v_m = ℓ − m`, so `m + v_m = ℓ` for every m and ⟨L_z⟩+⟨f_z⟩ = ℓ is conserved automatically — **no constrained-J_z machinery is needed** (the `target_Jz` plumbing that the old `runs/yan_li_saito_f1_torus_gs/README.md` called a blocker is not required). Confirmed: J_z − ℓ = 2e-9 (F=1) and 3e-8 (F=6). |
| **"rotates without changing its shape"** | Stated qualitatively only. The paper quantifies the rotation (Fig. 2b,c) but never the shape invariance. `c_larmor_rtp.jl` supplies a criterion: the **sorted eigenvalues of the second-moment tensor** ⟨r_a r_b⟩, invariant under rigid rotation while ⟨x²⟩ and ⟨z²⟩ individually swap. |
| **trap** | None. "free space without a trap potential", zero temperature. |
| **F-dependence** | "The following results are qualitatively independent of F; for simplicity, we study the case of F=1." True of the mechanism, **false of the stability window** — see Q2. |
| **spin-dependent contact** | Deliberately absent: DDI is assumed to dominate it, the spin is fully polarized everywhere, the contact term reduces to one spin-independent `4πℏ²a_s/M ρ` with `a_s` the S=2F channel. So `c₁ = 0` is the paper's model, not a convenience. |
| **LHY** | Single-component dipolar (Lima–Pelster) with `χ(ε_dd) = Re∫₀^π sinθ[1+ε_dd(3cos²θ−1)]^{5/2}/2 dθ` — exactly the repo's `lima_pelster_Q5`; and `scalar_lhy_coefficient` is algebraically identical to the paper's third eGPE term including χ (verified to 0.04 %). |
| **numerics** | Pseudospectral, dx ≃ 10⁻³, dt ≃ 10⁻⁷ (paper units) — i.e. ≈ 5e6 steps for one Fig. 2 trajectory. |
| **anchors** | ℓ=0: ρ_max = **13000 D₀**, ⟨L⟩=⟨f⟩=0, f/ρ ≃ 1. ℓ=1: ρ_max = **8900 D₀**, ⟨L_z⟩ ≃ **0.96**, ⟨f_z⟩ ≃ **0.04**, populations (¼,½,¼). Fig. 2c: ω_L/2π ≈ 9.5 at B_y = 1200; f_⊥ 0.0415 → 0.049 over that range. Fig. 4(a): stability boundary on an ε_dd axis spanning **1.05–1.55**. |

### Unit system, rebuilt from the repo's own constants (`a1_paper_units.jl`)

| | ours | paper | dev |
|---|---|---|---|
| L₀ = a_s N | 16.353 µm | 16.35 | 0.02 % |
| T₀ = M L₀²/ℏ | 0.6355 s | 0.64 | 0.7 % |
| D₀ = 1/(a_s³N²) | 3.4302 µm⁻³ | 3.43 | 0.00 % |
| B₀ = ℏ²/(M a_s²N² gμ_B) | **0.0398 µG** | **0.2 µG** | **80 %** |

Three of four match. **The published B₀ contradicts the paper's own definition by
the factor g = 9/2**: dropping g from `gμ_B` gives 0.179 µG, which rounds to the
quoted 0.2. So the physical field axis of Fig. 2(c) is ambiguous by 4.5×, and the
whole scan B_y ∈ [0,1000] B₀ is either **3.98 nT** (definition) or **20.0 nT**
(quoted) — **0.4× to 2× the ±10 nT** field-offset systematic on this apparatus.

---

## Q1 — physical Eu cannot host this proposal

**Theorem.** For any fully polarized, divergence-free (flux-closure)
magnetization `M = μ_tot ρ n̂`,

```
E_ddi = -(c_dd/6)∫|f|² = -(a_dd/a_s) E_s = -ε_dd E_s      (a_dd from the TOTAL moment)
```

because `∇·M = 0 ⇒ k·M_k = 0` kills the transverse part of the dipolar kernel and
only the −δ_αβ/3 trace piece survives. This is the paper's Eq. (S7), derived there
for its torus ansatz; it is ansatz-independent.

1. `E_s + E_ddi = (1−ε_dd)E_s`, so for **ε_dd < 1 every energy term (kinetic,
   contact+DDI, LHY) is positive**, and each falls strictly under a dilation
   r → αr (as α⁻², α⁻³, α⁻⁴·⁵). E(α) decreases monotonically to 0⁺: **no
   stationary point at any N, F or ℓ.** `a2` confirms N_c = ∞ for
   ε_dd ∈ {0.30, 0.54, 0.80, 0.95, 0.999}, F ∈ {1,6}, ℓ ∈ {0,1,2}, up to N = 10⁷.
2. Physical ¹⁵¹Eu (a_s = 110 a₀ measured, μ = 6.977 µ_B) gives a_dd = 59.4 a₀ and
   **ε_dd = 0.540** — the wrong side of a hard threshold, not a weak-binding case.
3. The paper agrees implicitly: Fig. 4(a)'s ε_dd axis bottoms out at 1.05 and the
   curves diverge as ε_dd → 1⁺; its closing paragraph asks for "ε_dd ≳ 1".
4. **eGPE confirmation (type B).** Cell A1 seeded with a genuine ε_dd=1.2 droplet
   (ρ_max = 91568 D₀) relaxes to **297 D₀**, σ_x 0.013 → 0.045 L₀, edge fraction
   7.9e-2, polarization dropped to 0.71 and the component windings scrambled — a
   cloud disintegrating into the box, not a droplet.

**So the ε_dd 1.2 vs 0.54 difference between the two registry entries is not a
convention detail: it is the difference between the proposal existing and not.**
Moving it to physical Eu requires a trap, which is a different prediction and one
this paper does not make.

### Exact closed form for the boundary

Reducing Eqs. (S4)–(S8) gives `E(s,λ) = P/s² − Q/s³ + R/s^{4.5}` and an existence
criterion with no search: a stationary point exists iff
`max_λ Q^{5/2}/(P^{3/2}R) ≥ 4.5/(1.2·0.9^{3/2})`. ε_dd factors out of that
maximization, so

```
N_c(ε_dd, F, ℓ) = C(F, ℓ) · χ(ε_dd) / (ε_dd − 1)^{5/2}
```

— F- and ε_dd-dependence **factorize exactly**, which is why the F=6/F=1 ratio
below is a pure number.

---

## Q2 — the mechanism survives F=6 and is four times stronger; the window does not

F enters the paper's variational energy in exactly one place: the azimuthal
spin-winding cost ⟨S_z²⟩ = F/2, i.e. the `(F + 2ℓ²)/λ` term of E_kin, which at
ℓ=1 goes **3 → 8** from F=1 to F=6. Hence

| ε_dd | N_c (F=1, ℓ=1) | N_c (F=6, ℓ=1) | ratio |
|---|---|---|---|
| 1.05 | 4.83e5 | 7.53e5 | 1.559 |
| 1.20 | 1.35e4 | 2.11e4 | 1.559 |
| 1.50 | 1.23e3 | 1.91e3 | 1.559 |

**F=6 needs 56 % more atoms.** At the paper's own N = 15000, ε_dd = 1.2, ℓ=1:
F=1 sits at N/N_c = 1.11 and F=6 at 0.71. So the campaign runs F=6 at N = 40000
(N/N_c = 1.90) as well; moving *only* the atom, as the issue proposed, would have
confounded F with ε_dd **and** with the stability margin.

### eGPE cells (all L-BFGS, grad_norm ≤ 4e-7, n=64, box 2.5σ)

| cell | atom | F | ε_dd | N | ℓ | N/N_c | ρ_max [D₀] | ⟨L_z⟩ | ⟨f_z⟩ | J_z−ℓ | edge |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **P0** | F=1 eff | 1 | 1.2 | 15000 | 0 | 1.72 | **12714** (paper 13000, **−2.2 %**) | 0 | 0 | 3e-15 | 4e-9 |
| **P1** | F=1 eff | 1 | 1.2 | 15000 | 1 | 1.11 | **8584** (paper 8900, **−3.6 %**) | **0.9588** (paper 0.96) | **0.04123** (paper 0.04) | 2e-9 | 1e-9 |
| **C1** | Eu151 | 6 | 1.2 | 40000 | 1 | 1.90 | 92501 | 0.8322 | **0.16776** | 3e-8 | 3e-13 |
| C0 | Eu151 | 6 | 1.2 | 40000 | 0 | 2.17 | 98101 | 0 | 0 | 5e-15 | 5e-13 |
| B1 | Eu151 | 6 | 1.2 | 15000 | 1 | 0.71 | 1150 (expanded) | 0.233 | 0.751 | 2e-2 | 3e-2 |
| A1 | Eu151 | 6 | **0.5402** | 15000 | 1 | 0 (N_c=∞) | 297 (expanded) | 0.025 | 0.944 | 3e-2 | 8e-2 |
| P1m | F=1 eff | 1 | 1.2 | 15000 | −1 | 1.11 | 8584 | −0.9588 | −0.04123 | 2e-9 | 1e-9 |
| C1m | Eu151 | 6 | 1.2 | 40000 | −1 | 1.90 | 92501 | −0.8322 | −0.16776 | 3e-8 | 3e-13 |

**The positive control passes**: every published Fig. 1 anchor within 3.6 %, and
⟨L_z⟩ to **0.13 %**, ⟨f_z⟩ to **3 %**.

Additional structure reproduced (type B):
* `m + v_m = ℓ` for **all 13 components** at F=6, exactly as at F=1 — the paper's
  conservation argument is F-generic.
* The Barnett imbalance is visible component by component at F=6:
  n(+1)/n(−1) = 0.2165/0.1856, n(+2)/n(−2) = 0.1333/0.1021, …, while the ℓ=0 cell
  C0 is exactly symmetric (0.2023 at both m=±1) and gives ⟨f_z⟩ = 0.
* Fully polarized everywhere: |f|/(Fρ) = 0.998 for every bound cell.
* Flux closure preserved: (E_contact+E_ddi)/E_contact = −0.1981 … −0.1991 against
  the exact −0.2000 — so the theorem's premise holds on the converged states, to
  under 1 %.
* **Chirality is a symmetry, not a measurement**: the ℓ → −ℓ mirrors reproduce
  −⟨L_z⟩ and −⟨f_z⟩ to every printed digit and mirror the populations exactly.

**⟨f_z⟩ = 0.168 at F=6 vs 0.041 at F=1 — a factor 4.07.** The spin channel has
6× the per-atom capacity and takes up 17 % of the total angular momentum instead
of 4 %. For detectability this is the opposite of the worry in the issue: the
effect is *stronger* at F=6 — provided the droplet exists at all, which requires
ε_dd ≳ 1 and therefore not physical Eu.

---

## Q3 — the frequency, and whether an experiment can see it

The paper's mechanism claim is its Eq. (4), `d⟨J⟩/dt = γ⟨f⟩×B`, from which its
Fig. 2(c) line follows. Reproducing Fig. 2(c) directly costs ≈ 5e6 steps per field
point (the paper's own dt and window). The claim *is* the torque law, so
`f_larmor_torque.jl` measures the torque instead: apply B_y = 1000 (in-regime) to
the converged ℓ=1 state and compare d⟨J⟩/dt with γ⟨f⟩×B component by component.

| cell | d⟨J_x⟩/dt measured | γ(⟨f⟩×B)_x | ratio | d⟨J_z⟩/dt (law says 0) |
|---|---|---|---|---|
| P1 (F=1) | +41.03 | −41.23 | **−0.9953** | −6.02 |
| C1 (F=6) | +167.78 | −167.76 | **−1.0001** | −2.17 |

**Box convergence** (each row re-converged in its own box; the ratio is the
quantity that must converge, since ⟨L_z⟩ is ill-defined on a periodic box):

| cell | box [L₀] | ratio | f_⊥ |
|---|---|---|---|
| P1 | 0.2111 / 0.3518 / 0.4925 | −0.99531 / −0.99532 / −0.99485 | 0.04124 / 0.04123 / 0.04123 |
| C1 | 0.0964 / 0.1606 / 0.2249 | −0.99995 / −1.00010 / −0.99807 | 0.16777 / 0.16776 / 0.16771 |

So over a 2.3× box range the torque ratio is stable to 0.05 % (F=1) and 0.2 %
(F=6), and f_⊥ to 0.04 %.

**Two findings from the sign and the residual.**

1. **The magnitude of Eq. (4) is confirmed to 0.5 % (F=1) and 0.01 % (F=6), but
   the sense of rotation is opposite to Eq. (4) as printed.** With the Zeeman term
   of the paper's own Eq. (1), `+gμ_B(B+B_dd)·S` (which is also this repo's
   Kawaguchi–Ueda convention), the exact commutator gives
   `d⟨F_x⟩/dt = +B̃⟨F_z⟩ = +41.23`, which is what we measure (+41.03); Eq. (4) as
   written gives −41.23. Eq. (1) and Eq. (4) of the paper are mutually
   inconsistent by a sign — equivalently Eq. (4) should read `γ B×⟨f⟩`. |ω_L| is
   unaffected; the direction the cloud turns is. This matters precisely because
   the chirality sign is supposed to be guaranteed by symmetry rather than
   measured.
2. **A residual z-torque where the law predicts zero**: −6.02 (15 % of the
   x-torque) at F=1, −2.17 (1.3 %) at F=6. It is **box-independent to 0.6 %**, so
   it is *not* the periodic-box ⟨L_z⟩ leakage that dominated the Barnett REDO.
   Its origin is not established here; the untested axis is the **grid** (the
   cubic lattice breaks continuous rotational symmetry, so the DDI's internal
   torque need not cancel exactly). A grid scan at fixed box is the next probe.

**Frequency, in lab units** (`physical_table`):

| cell | F | ε_dd | N | a_s [a₀] | L₀ [µm] | T₀ [s] | B₀ [nT] | B_y at B̃=1000 | f_L [Hz] | period [ms] |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 1 | 1.2 | 15000 | 20.60 | 16.35 | 0.6355 | 0.00398 | **3.976 nT** | **10.32** | 96.9 |
| C1 | 6 | 1.2 | 40000 | 49.52 | 104.82 | 26.11 | 0.000375 | 0.375 nT | 1.02 | 978 |

Note the two cells have different a_s and N, so the same B̃ is a different lab
field. Reduced to the field-referred slope,
`f_L = [f_⊥/(L_⊥+f_⊥)]·g_F µ_B B/h`:

* **F=1 effective: 2.59 Hz/nT** (f_⊥/(L_⊥+f_⊥) = 0.0412, g_F = 4.5)
* **F=6 physical moment: 2.73 Hz/nT** (0.1678, g_F = 1.163)

They are within 5 % of each other: F=6's 4.07× larger f_⊥ nearly cancels its
3.87× smaller g_F. **So the experiment does not gain or lose frequency by going to
F=6** — it gains a 4× larger magnetization at the same precession rate.

**Systematics verdict.** At 2.6–2.7 Hz/nT, the published ±10 nT field-offset
systematic is **±27 Hz of uncontrolled precession frequency** — larger than the
entire predicted signal at the fields the paper scans. The precession is
resolvable only if the residual field is zeroed to well under 1 nT. This is a
property of the proposal, and it holds whichever reading of B₀ is meant.

---

## Framework results found on the way

### 1. Wiring calibration: the flux-closure DDI identity (type A)

The theorem is also the sharpest gate on the repo's dipolar normalization, since
it fixes `E_ddi/E_s` to a pure number.

| probe | result |
|---|---|
| flux-closure torus, F=1 and F=6, ε_dd ∈ {1.2, 0.5402}, n ∈ {48,64,80} | `E_ddi/E_s = −ε_dd` to **1e-12 relative** on every row |
| negative control: same density, spins uniformly ‖ z (∇·M ≠ 0) | **+0.433** — wrong sign and magnitude, so the gate can fail |
| unpadded periodic kernel | deviation 3.75e-7, **identical at n = 32/48/64** — resolution-flat ⇒ periodic images, not truncation; small only because a flux-closure texture has no net dipole moment |

Holds: `c_dd = μ₀(g_Fμ_B)²` (no 4π), the F² coming from the spin *operators* and
not from c_dd, the ε_dd bookkeeping (total moment in a_dd), and
`c₀ = 4π(a_s/a_ho)N`. **Does not hold** the transverse k̂k̂ part of the kernel,
which cancels identically for this state — that is what the negative control
exercises. Landed as `test/oracles/test_flux_closure_ddi_identity.jl` (ci tier).

### 2. ITP's fixed point is displaced by the time step in the droplet regime

**This invalidates imaginary-time relaxation as the tool for free-space dipolar
droplets, and the convergence flag does not warn you.**

Seeded with the paper's variational droplet, `find_ground_state` (ITP) relaxed to
ρ_max = 7101 D₀ at E = −654, *above* the energy of its own seed (−770) — energy
rising monotonically over 20000 steps to a fixed point with dpsi = 3e-6. A plain
`split_step!` + renormalize loop reproduced the same fixed point to 4 digits, so it
is not a fused-stepper artifact. L-BFGS on the FD-gated energy gradient instead
gives E = −885 and ρ_max = 12714 (the paper's 13000 to 2.2 %) with
grad_norm = 1e-7.

Diagnosis (`a7_itp_drift_from_stationary.jl`): started **at** the L-BFGS stationary
point, ITP drifts away with |dE|/t = 177 / 128 / 16.8 / 0.53 at
dt = 4e-3 / 2e-3 / 5e-4 / 1.25e-4 — an **O(dt^≈2.5) splitting artifact** that
vanishes as dt → 0, not a propagator/energy face mismatch. In a harmonic trap the
same terms agree with L-BFGS to ~1e-6 for contact, contact+LHY, contact+DDI and
contact+LHY+DDI (`a6_which_term_disagrees.jl`); it is the free-space
**cancellation** that exposes it — contact +31340 against DDI −37608 for a net
−6268, so the splitting error is large compared with the binding energy.

Consequences:
* `run_itp` in this campaign defaults to `method=:lbfgs`, with the measurement in
  the comment.
* At dt = 2e-3 the ITP answer was **44 % wrong in peak density while reporting
  dpsi = 3e-6**, and it was **grid-independent to 0.4 % and box-independent to
  2 %** — every convergence indicator except dt looked clean.
* `runs/saito_li_torus/` (issue #336) is the same regime and will hit this.

### 3. Instrument added

`orbital_angular_momentum_vector` in `src/analysis/currents.jl` — the repo had only
⟨L_z⟩, and mechanical Larmor precession turns the cloud about **B**, so ⟨L_z⟩
alone reads as a decay rather than a rotation. Gated by
`test/analysis/test_orbital_angular_momentum_vector.jl` (fast tier), which pins
axis assignment by imprinting the same vortex about x, y and z.

### 4. A defect in my own reduction, caught by a second statement

The closed form for `P(λ)` first read `(K/2)^{4/3} + ½(K/2)^{2/3}` instead of
`(3/4)(K/2)^{2/3}` — substituting `e^{-2v} = (K/2)^{+1/3}` for `(K/2)^{-1/3}`.
That inflated P by 14 % and with it N_c, σ_r and E, and it made the ℓ=1 positive
control read "unbound". It was caught by `a4_variational_vs_code_terms.jl`, which
implements Eqs. (S6)–(S8) *directly* and compares them with the repo's own energy
functional term by term (agreement 1e-5, improving with resolution). Two
independent statements of the same algebra, compared — the deliberate redundancy
this repo's oracle discipline is built on.

---

## Files

| file | what |
|---|---|
| `a1_paper_units.jl` | paper unit system from repo constants; the B₀ discrepancy; nT systematics |
| `a2_variational_stability.jl` | Eqs. (S4)–(S8) in closed form; the ε_dd>1 theorem; Fig. 4(a); the F=6 boundary |
| `a3_flux_closure_ddi_identity.jl` | wiring gate `E_ddi/E_s = −ε_dd` with a failing negative control |
| `a4_variational_vs_code_terms.jl` | the repo's energy functional vs the paper's closed forms, term by term |
| `a5_itp_is_descending.jl` | ITP descent probe; plain-`split_step!` loop; L-BFGS cross-check |
| `a6_which_term_disagrees.jl` | ITP vs L-BFGS per term, in a trap |
| `a7_itp_drift_from_stationary.jl` | the dt-scaling that identifies the artifact |
| `b_egpe_cells.jl` | the cells (one protocol) + the shared observable reader |
| `c_larmor_rtp.jl` | full Fig. 2 protocol (ramp, ω_L by extremum spacing **and** fit, shape invariance by moment-tensor eigenvalues, mirror arm) — **written and unrun**: ≈5e6 steps per field point |
| `d_convergence_scan.jl` | one-knob-at-a-time dt / box / grid, edge fraction on every row |
| `e_campaign.jl` | all cells in one session |
| `f_larmor_torque.jl` | the Eq. (4) torque test, its box scan, and the physical-unit table |

Numerical unit choice: `a_ho = L₀/S` with S set so the variational σ_r lands at
1.5 a_ho, keeping dt ~1e-3 instead of the ~1e-7 that `a_ho = L₀` forces.
Conversions: `n/D₀ = |ψ|²S³`, `E[ℏ²/ML₀²] = E[ℏω]·S²`, `t[T₀] = t[1/ω]/S²`,
`B̃ = −b_y·S²`.

## Reproducing every number above

`out/*.jld2` is gitignored (310 MB), so the scripts are the artifact. Each jld2
records its producing `git_hash`; each table below names the script that emits it.
All of it runs on one consumer GPU in well under an hour.

```bash
# analytic / no GPU  (seconds each)
julia --project=. runs/yls_barnett_f6/a1_paper_units.jl            # unit system, B0 defect, nT systematics
julia --project=. runs/yls_barnett_f6/a2_variational_stability.jl  # theorem, Fig 4(a), F=6 boundary
julia --project=. runs/yls_barnett_f6/a3_flux_closure_ddi_identity.jl
julia --project=. runs/yls_barnett_f6/a4_variational_vs_code_terms.jl

# GPU  (prefix LD_LIBRARY_PATH=/usr/lib/wsl/lib on WSL2; `import CUDA` first)
julia --project=. -e 'import CUDA' -e 'include("runs/yls_barnett_f6/e_campaign.jl");
    main_campaign(["cells=P0,P1,C1,B1,A1,C0,P1m,C1m","n=64","box_sigma=2.5"])'   # ~4 min, the cell table
julia --project=. -e 'import CUDA' -e 'include("runs/yls_barnett_f6/f_larmor_torque.jl");
    torque_box_scan("P1"); torque_box_scan("C1"); physical_table(["P1","C1"])'   # ~8 min, Q3
julia --project=. -e 'import CUDA' -e 'include("runs/yls_barnett_f6/a7_itp_drift_from_stationary.jl");
    drift_probe("P0")'                                                          # ~6 min, the ITP finding
julia --project=. -e 'import CUDA' -e 'include("runs/yls_barnett_f6/a6_which_term_disagrees.jl"); main_a6()'
julia --project=. -e 'import CUDA' -e 'include("runs/yls_barnett_f6/d_convergence_scan.jl"); main_scan(["P0"])'
```

Landed gates (run without a GPU):

```bash
julia --project=. -e 'using SpinorBEC; include("test/oracles/test_flux_closure_ddi_identity.jl")'
julia --project=. -e 'using SpinorBEC; include("test/analysis/test_orbital_angular_momentum_vector.jl")'
```

## What is not done

* **Fig. 2(c) itself.** `c_larmor_rtp.jl` implements the paper's ramp protocol and
  both frequency readouts, but a single field point is ≈5e6 steps. The mechanism
  was tested via the torque law instead; the frequency comes from the paper's own
  formula with our measured f_⊥ and L_⊥.
* **The origin of the residual z-torque** (15 % at F=1, 1.3 % at F=6). Shown
  box-independent; the grid axis is untested.
* **A grid scan on the F=6 cells.** The convergence scan was run on P0 (F=1);
  ρ_max there was grid-independent to 0.4 % over n = 64/96/128, and the F=6 cells
  run at dx = 2.4e-3 L₀, but that was not re-verified per cell.
* **The quadratic Zeeman control arm** the issue asked for. It is unnecessary and
  would be unmeasurable — measured, not asserted: with q/h = 1.43 kHz/G² for
  Eu F=6, at the C1 field of 0.375 nT the quadratic term is q/h = 2.0e-8 Hz
  against a linear Zeeman of 6.10 Hz, a ratio of **3.3e-9** (and 9.0e-9 at the P1
  field of 3.976 nT). An on/off arm at that level returns "no difference" by
  construction, which is not a measurement.
  Also note `ZeemanTerm` implements `q F_z²` only, while the paper's geometry puts
  **B** along y, so a faithful arm needs the problem rotated to put **B** ‖ z.
  Quoting the ratio is the honest form of that control.
* **The chiral bound-state pair** (paper Fig. 3). Out of scope for #338.
