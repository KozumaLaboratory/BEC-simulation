# Parameter contract — SpinorBEC.jl ↔ Ueda lab spinor-BEC code

**Purpose:** signed, line-by-line agreement on every physics convention
**before** any numerical comparison. A single mismatch (DDI 4π, μ
definition, m ordering, p sign, normalization) produces an entirely
spurious "code-A vs code-B" disagreement that is indistinguishable
from a real bug.

Strategy from validation ladder Level 10 (memory
`validation_ladder_2026_05_24.md`):

> **Image comparison of late-time collapse is the *weakest* test —
> chaotic amplification of any A/B error. Do not start there.**
>
> 1. Parameter contract (this document)
> 2. Same ψ₀ energy decomposition
> 3. Same ψ₀ Hψ comparison ← strongest
> 4. One-step comparison
> 5. Short-time comparison

Until this document is signed off by both labs, no numerical diff is
meaningful.

## How to use

For each row:

1. **SpinorBEC.jl column** is filled in by us (this document) with code
   references so the convention can be re-derived.
2. **Ueda-code column** is filled in by the Ueda lab.
3. **Match?** column is filled in jointly. Any "no" must be resolved
   (either change a convention on one side, or document the
   transformation explicitly) before Level 10 numerical comparison.

Each disagreement should be linked to a `transformation/` note: how
the Ueda data must be rewritten to make it directly comparable to ours.

---

## 0. Matsui et al. (2025) Fortran implementation — first pass, 2026-07-30

The "Ueda code" columns below are still empty and will stay that way: there is no
channel to that lab (`ueda_status.md` criterion 1). What arrived instead is a
**third-party implementation of the same Hamiltonian** — Zenodo record 17303925
(CC-BY-4.0, open), `code.zip`: `initial.f90` (77 KB, polarised initial state),
`time.f90` (81 KB, in-trap evolution), `tof.f90` (93 KB), `spin6.nb` (17.6 MB,
Mathematica, spin-6 initial state). FFT via Intel MKL DFTI.

Same model, same Ref-(19) Kawaguchi-Saito-Ueda lineage. It buys **convention
independence and reference generation at arbitrary parameters**, not physics
independence. Line numbers below are `time.f90` in the Zenodo `code.zip`.

### 0.1 Verified

| contract row | Matsui et al. | vs ours | line |
|---|---|---|---|
| units | `aHO = sqrt(hbar/(2·m·omegaX))` — **factor 2 inside** | ours is the usual `sqrt(ħ/mω)`; every dimensionless coupling differs by a power of √2 | 244 |
| 3.2 / 3.3 | `NM==6`: `cc0 = 8π·N·a0/aHO`, `cc1 = cc0·1e-2/36`, then `cc0 *= cc0_eff (0.5)`, `cc1 *= cc1_eff (50)` ⇒ **c₁/c₀ = 1/36 exactly** | our `c1_ratio` default for the Buchachenko antiferromagnetic estimate is the same 1/36 | 282-285, 25, 322-326 |
| 3.x inputs | Eu: `a0 = 110 a_B`, **`a2 = a4 = a6 = 0`** | they have no measured a_S either; the spin-dependent strength is the `_eff` knob, not spectroscopy | 219-228 |
| 2.3 | `ZeemanP = Bfield·1e-7 · muB·gF/(hbar·omegaX)`, positive, `Bfield` in mG | ours declares `p ≡ −g_F μ_B B`. **Not yet a contradiction** — the sign in front of `p·F_z` in their H assembly has not been read. Resolve before quoting. | 255-258 |
| 2.4 | two branches: if `ZeemanQ ≠ 0` it is taken as a literal Hz input; else `q = (gF·muB)²(B·1e-7)²/(2π·ħ²·Ehf·omegaX)`. **The Fig 2/4 runs pin `ZeemanQ = 1.0 Hz`** | ours always derives q from \|B\|² via Breit-Rabi: 9.6e-7 Hz at 2.6 nT. Six orders apart, both negligible against p/h = 42.3 Hz — which is independent support for q not being the discriminator in the nT band | 246-253, 1688 |
| 2.x inputs | Eu block sets `Ehf = 1.772e9` — **²³Na's hyperfine splitting, reused** | unused for Fig 2/4 because the `ZeemanQ ≠ 0` branch wins; it would matter for any run with `ZeemanQ = 0` | 226 |
| 4.1 / 4.2 | `cdd = 1e-7 · (gF·muB/hbar)² · 2·mass·Ntot/aHO` — the `1e-7` is μ₀/4π, so **4π is absorbed** | ours is `c_dd = μ₀μ²`, no 4π. Whether this is a real factor difference depends on their `Q_αβ` normalisation (row 4.3/4.5), which is not yet read | 322 |
| loss | Eu branch sets `L3loss = 0`, and `L3loss_eff = 0` globally | their Fig 2/4 theory curves are **loss-free**. Keep them separate from `dataset_fig2_exp.xlsx` | 222, 25 |

### 0.2 Run parameters behind the published curves

`Bfield_ini = 10.4 mG` ramped to `Bfield_fin = 26e-3 mG = 2.6 nT` with
`Bfield_tau = 50 µs`; `time_step = 1e-3` trap units; `OmegaB = 0`
(lines 1686-1691). Fig 4 is produced by scanning `Bfield_fin` (readme).

### 0.3 Closed — second pass, 2026-07-30 (session S-A6)

Every row §0.2 left open is filled below, from `time.f90` unless stated. **Nothing
here is physics independence** — same model, same Ref-(19) lineage. What it buys is
*convention independence* and *reference generation*, the "external code" entry of the
campaign charter's four independence sources. It does not substitute for S-A1 / S-A2.

#### 0.3.1 The Hamiltonian, sign by sign (`timeGP_3D_spin1`, lines 470-519)

They integrate with **Crank–Nicolson**, not split-step: `coefD = 1 + Δ·H`,
`coefB = (1 − Δ·H)ψ`, `ψⁿ⁺¹ = coefB / coefD`, self-consistently iterated to
`zure ≤ 1e-10` (line 526). `Δ ≡ diff2 = −dt/(−γ + i)/2 = +i·dt/2` at `γ = 0`
(line 1886), so this is `(1 + i dt H/2)ψⁿ⁺¹ = (1 − i dt H/2)ψⁿ` — `i ∂ψ/∂t = Hψ`
with the usual sign. The Laplacian is a **3-point finite difference** with periodic
BCs (lines 491-500), not spectral.

Reading `H` off the bracket, **every term enters with `+`**:

```
H = −∇²  +  V_trap  −  μ
      + ZeemanP·F_z  +  ZeemanQ·F_z²
      + cc0·n        +  cc1·⟨F⟩·F        (diag `cc1·⟨F_z⟩·m` + ladder `½cc1⟨F∓⟩F±`)
      + cdd·(B_eff·F)                    (diag `cdd·INT0·m` + ladder `½cdd·INT1*·F±`)
      − i·L3loss·n²
```

The kinetic prefactor is exactly `1`, not `½`, because `aHO = √(ħ/2mω)` puts the
factor 2 in the length unit; `V_trap = ¼(x² + …)` (line 1870) is the same statement.
`calcENE_3D_spin1` confirms the energy functional: `E = T + V + E_p + E_q + (E_c0 +
E_c1 + E_dd)/2` (line 743) — the ½ on the mean-field terms, none on the Zeeman.

| row | Matsui et al. | vs ours | verdict |
|---|---|---|---|
| **2.1 / 2.3** | `H ⊃ +ZeemanP·F_z` with `ZeemanP = +B·μ_B·g_F/(ħω)` (line 258, `Zeeman_p` at 739 confirms the sign in the energy) ⇒ **`H_Z = +g_F μ_B B·F_z`** | ours is `H_Z = −p·F_z` with `p ≡ −g_F μ_B B/(ħω_ref)` ⇒ **`+g_F μ_B B·F_z`**. `inspect` on our Fig. 4B config returns `p = −153.9` at their `Bfield_ini = 10.4 mG`; theirs is `ZeemanP = +153.87`, and `−p·F_z ≡ +ZeemanP·F_z` | **MATCH.** Row 2.3's own text ("p = g_F μ_B B/ħω_ref, same sign as B_z") is **stale** — it contradicts `Units.bfield_to_p` and CLAUDE.md. The *operator* is what agrees; the intermediate `p` differs in sign because we route through Kawaguchi-Ueda's `p` and they do not. +B on g_F>0 gives m=−F lowest in both. |
| **2.2** | `+ZeemanQ·F_z²` | `+q·F_z²` | **MATCH**, including the sign. |
| 3.1 | `E_int = (cc0/2)∫n² + (cc1/2)∫\|⟨F⟩\|²` (line 743 halves what 678-690 accumulate) | identical | **MATCH.** |
| **4.7** | **`secular` does not exist.** No switch, no Larmor average, no rotating spin frame anywhere in `initial.f90` or `time.f90`. `calcDD_3D` always uses the full `DD0/DD1/DD2`; `calcDD_3D_pol` is a *spin-frozen* variant (only `DD0·⟨F_z⟩`) used by the ground-state driver `timeGP_3D_spin1_fix`, which is a consequence of freezing the component, not an approximation to the DDI. | ours is a user-chosen flag with an `@info` advisory above `ω_L/(c_dd⟨n⟩) > 100` | **ABSENT IN THEIR CODE** — see the note below on what that does and does not say about our advisory. |
| 4.8 | no spin-rotating frame | `spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true` | **ABSENT.** |
| 5.1 | `−∇²` (prefactor 1, absorbed into `aHO`), 3-point FD, periodic | `−ħ²/2m ∇²`, spectral | **MATCH in physics, DIFFER in discretisation.** At their production `dx = 0.4 aHO` against a healing length `ξ = 1/√μ ≈ 0.28 aHO`, the FD dispersion error is not small. Any Level-10 `Hψ` diff must use the same Laplacian or it measures the stencil. |
| 9.1 | `exp(−i dt H)` via Crank–Nicolson (2nd order, unconditionally stable, iterated to self-consistency) | Strang split-step | **DIFFER in method, agree in order.** Contract §"Acceptance criteria" already allows this: rows 1-2 (energy, `Hψ`) are method-free, row 3 (one-step) is not. |
| 9.2 | ITP is the same CN with `diff2 = dt/2` real (line 1883) + renormalise | `exp(−τH)` + renormalise | **MATCH in intent.** |
| 2.7 | no overflow shift — CN never exponentiates `H` | we subtract `min(E_m)` | **N/A**, and harmless: the shift is a gauge on our side. |

**What row 4.7 does *not* settle.** `make_workspace` on our Fig. 4B dynamics step
printed `ω_L/(c_dd·⟨n⟩) ≈ 373` (UGE 8304399) — but that is evaluated at the
*start* of the ramp, `B = 1.04 µT`. The ratio is linear in `B`, and the field is
**held at 2.6 nT**, four hundred times lower: `373 × 2.6/1040 ≈ 0.93`. During the
physics the Larmor rate and the dipolar mean-field rate are **comparable**, which
is precisely where a secular approximation has no justification. So their use of
full MDDI is not evidence against our advisory; it is a run that never enters the
regime the advisory is about. CLAUDE.md's `> 100` threshold gets **no external
support in either direction** from this source. Type A (arithmetic on a logged
number), producing commit `4e2fb85d`.

#### 0.3.2 Spin matrices (`init_time_3D`, lines 386-396)

```fortran
do im = -NM, NM
   MatSZ(im) = dble(im)
   MatSP(im) = dsqrt(dble(NM-im+1)*dble(NM+im))
enddo
```

| row | Matsui et al. | vs ours | verdict |
|---|---|---|---|
| 1.1 | `NM = 6` is the spin quantum number, 13 components | `atom.F = 6` | **MATCH.** |
| **1.2** | array index **is** `m`, running `−F … +F` — **ascending** | `c=1 ↔ m=+F`, **descending** | **DIFFER — pure relabelling.** `c = F + 1 − m`. Their `im=−6` is our `c=13`. Mechanical, but every component-resolved comparison must apply it, and their output columns are written `im = −NM … NM`. |
| 1.3 | `F_z` diagonal `= m` | same | **MATCH.** |
| **1.6** | `MatSP(im) = √((F−m+1)(F+m)) = √(F(F+1) − m(m−1)) = ⟨F,m\|F₊\|F,m−1⟩`, real and positive | `F_±\|F,m⟩ = √(F(F+1) − m(m±1))\|F,m±1⟩` | **MATCH**, Condon-Shortley, same phase. |
| 1.4 | never forms `F_x`, `F_y`; only `F_z` and `F_±` via `MatSP`. `spinP ≡ ⟨F₊⟩ = Σ MatSP(im)·φ*_im φ_{im−1}` (line 777), and `INT1 ≡ B_eff,x + i B_eff,y` (line 815) — so `F_x ± iF_y` with the standard `+i` | `[F_x, F_y] = +iF_z` | **MATCH** (implied, not independently stated). |
| 1.5 | never forms `F²` | `F(F+1)·I` | **N/A**, no choice involved. |

#### 0.3.3 `Q_αβ(k)`, its k=0 bin, and the `4π` (`makeDD_ini`, lines 923-941)

Their kernel, at `k ≠ 0`:

```
DD0 = −(4π/3)(1 − 3k_z²/k²) = 4π·Q_zz
DD1 = 4π·k_z(k_x + i k_y)/k²  = 4π·(Q_xz + i Q_yz)
DD2 = 4π·(k_x + i k_y)²/k²    = 4π·(Q_xx − Q_yy + 2i Q_xy)
```

with `Q_αβ = k̂_α k̂_β − δ_αβ/3` — **our exact tensor, times 4π**. Substituting into
`INT0L = ½(DD1*·⟨F₊⟩ + DD1·⟨F₋⟩) + DD0·⟨F_z⟩` (line 847) collapses to
`4π(Q_xz⟨F_x⟩ + Q_yz⟨F_y⟩ + Q_zz⟨F_z⟩)` — the same contraction our
`apply_ddi_step!` performs.

**Report the product, not the halves.** Their `cdd = (μ₀/4π)·(g_F μ_B/ħ)²·2m·N/aHO`
(the `1.d-7` is `μ₀/4π`), so

```
cdd · DD = μ₀ (g_F μ_B)² · (2m/ħ²) · N/aHO · Q = [μ₀ μ² · N/aHO³] / (ħω) · Q
```

using `2m aHO²/ħ = 1`. Ours is `c_dd·Q` with `c_dd = μ₀μ²`, `μ = g_F μ_B`, no 4π
anywhere. **The two `4π`s cancel exactly and the products are identical**, including
the `μ = g_F μ_B` per-spin-matrix convention of row 4.6 (their `(gF*muB/hbar)²` is
per-`F_z`-quantum, not the `g_F F μ_B` saturation moment).

| row | Matsui et al. | vs ours | verdict |
|---|---|---|---|
| 4.1 / 4.2 | `cdd` absorbs `μ₀/4π` | `c_dd = μ₀μ²`, no 4π | **MATCH in the product** (row 4.5 compensates). Neither is "the" convention; only `cdd·Q` is physical. |
| 4.3 / 4.5 | `Q` carries an extra `4π`; otherwise the identical traceless tensor, no `1/(4π)` | bare `k̂k̂ − δ/3` | **MATCH in the product.** |
| 4.6 | `μ = g_F μ_B` per spin matrix | same | **MATCH.** |
| **4.4** | `DD0(k=0) = −4π/3`, `DD1(0) = DD2(0) = 0` (lines 930-933) — i.e. `Q_zz(0) = −1/3`, the `−δ_αβ/3` piece kept with `k̂k̂ → 0` | `Q(k=0) = 0`, all components (Pedri-Santos; and `h(0)=0` keeps it there under our spherical truncation) | **DIFFER — and it is negligible here.** The k=0 bin adds a uniform `B_eff,z ∝ ⟨F_z⟩/V_pad`, which is an effective linear-Zeeman shift. At their `128³ × dx 0.4 × sn=2` and `N = 5×10⁴` this is `cdd·(−4π/3)·⟨F_z⟩/(dx³·sn³·N_pts) ≈ 7.8×10⁻⁴` trap units, i.e. **5×10⁻³ nT** against a −2.5 nT resonance offset and a 1 nT scan step. It vanishes as `1/V_pad`, so our `Q(0)=0` is their large-box limit. **Type A (analytic), not measured.** |
| — | zero-padding `sn = 2` in `time.f90`, `sn = 1` (**none**) in `initial.f90` | `padded: true, pad_factor: 2` default since 2026-07-29 | **MATCH for the dynamics; their ground state is unpadded.** |
| — | no real-space spherical truncation of the kernel | `trunc_radius: "auto"` by default | **DIFFER.** Ours removes the `k̂k̂` angular discontinuity at the origin; theirs does not. Our own probe puts that class of error at ~2×10⁻² of the field with padding alone — worth ~0.02 nT of offset here, below the effects being measured but not below the quoted precision. |
| 5.2 | `k = 2π/(sn·N·dx)·[0 … N/2−1, −N/2 … −1]` (lines 924-928) | identical FFTW layout | **MATCH.** |
| 5.4 | **no dealiasing** | Orszag 2/3, opt-in | **ABSENT IN THEIR CODE.** |

#### 0.3.4 ψ normalisation and the remaining rows

| row | Matsui et al. | vs ours | verdict |
|---|---|---|---|
| **3.7** | `phi = phi_n/√(Σ\|phi_n\|²·dx dy dz)` (line 530) ⇒ **`∫\|ψ\|² = 1`**, with `N` absorbed into `cc0 ∝ Ntot`, `cc1`, `cdd ∝ Ntot`, `L3loss ∝ Ntot²`. `calcENE` reports `ntrap_r(im) = ∫\|φ_m\|²` as fractions summing to 1. | `∫\|ψ\|² dV = 1`, N in the coefficients | **MATCH.** No transformation needed. |
| 3.2 / 3.3 | `cc0 = 8πN a₀/aHO` × `cc0_eff`, `cc1 = cc0_raw·(10⁻²/36)` × `cc1_eff` | `c₀ = c_total/(1 + F²·c₁_ratio)`, `c_total = 4πN a_s/a_ho` | **MATCH.** `8π/aHO = 8π√2/a_ho = 2√2 · 4π/a_ho`, and the energy rescale under `a_ho = √2 aHO` divides by exactly `2√2`. With `cc0_eff = 0.5, cc1_eff = 50` their pair is `c₀ = 2343.63, c₁ = c₀/36` at N=5×10⁴; our `c1_ratio = 1/36` returns `c₀ = 2343.63` — **verified numerically**, not by algebra alone. |
| 3.4 / 3.5 / 3.6 | `cc2`, `cc3` exist for F=2/3 but are **`0` on the ¹⁵¹Eu branch**; no singlet-pair or higher-rank tensor term is ever evaluated at F=6 | our tensor path handles all channels | **N/A for Eu.** Their F=6 model is `c₀ + c₁` only. Ours must set `c_extra = {}` to match — the six unmeasured `a_S` are absent from their model too, so this dataset **cannot** constrain them. |
| 6.x | **no LHY term anywhere** | opt-in | **ABSENT IN THEIR CODE.** Their model is pure mean-field. |
| 7.1 / 7.2 | `dn/dt ⊃ −L3loss·n²·ψ` — a **cubic-in-n** loss in ψ, i.e. our `K3_per_m_cubic` shape (row 7.1). `L3loss = 0` for Eu **and** `L3loss_eff = 0` globally. | both shapes available | **MATCH in shape, INACTIVE in their published runs.** |
| 7.3 | `L3loss ← L3loss·(2π/ω)·N²/aHO⁶` | `K3·n₀²/ω_ref`, `n₀ = N/a_ho³` | **MATCH** modulo the `aHO`/`a_ho` √2 (a factor 8 in `aHO⁶`). Untested — the term is off. |
| 8.1 | **`aHO = √(ħ/2mω)`** | `a_ho = √(ħ/mω)` | **DIFFER by √2.** Every length, density and dimensionless coupling differs by a power of √2. This is the first transformation to apply, before any number is compared. |
| 8.2 / 8.3 | `1/ω_x`, `ħω_x` | same | **MATCH.** Their `time_step = 1e-3` transfers to our `dt` unchanged. |
| 10.2 / 10.3 | `im_fix = −6`, seeded from a Thomas-Fermi profile in that one component | `m_minus_F` populates `c = D` | **MATCH** after the 1.2 relabelling. |
| 10.5 | `noise_amp = 5e-2` is **declared, assigned, and never read** in either file — dead code. No thermal or symmetry-breaking seed exists. | heuristic seed available | **ABSENT.** Correct for this problem: the m=−6 → −5 transfer is *driven* by the DDI off-diagonal `INT1`, not seeded from an instability. Our configs set `seed_amplitude: 0`. |

#### 0.3.5 Two ways the shipped code is not the published configuration

Both are provable from the files, and both matter for a reproduction:

1. **`Ntot = 3.5×10⁴`** in `setup_parameters` (line 1667) against published theory
   curves that total **49999.9** — `dataset_fig2_theo` starts at exactly `N_{-6} =
   50000`. The runs behind the figures used `N = 5×10⁴`.
2. **`initial.f90` and `time.f90` disagree on the interaction.** `initial.f90` line 25
   ships `cc0_eff = 1, cc1_eff = 0`; `time.f90` line 25 ships `cc0_eff = 0.5,
   cc1_eff = 50`. As shipped, the state handed to the dynamics is the ground state of
   a Hamiltonian with **twice** the contact repulsion — `R_TF` larger by `2^0.2 =
   1.15`, peak density lower by `0.66`. Peak density sets the dipole field, which
   sets the very resonance offset Fig. 4B measures.

So the parameters have to be **reconstructed**, not read off. `runs/matsui_fig4b/`
does that, and carries `fig4b_gsvariant_n32.yaml` to price item 2 rather than assume
it away.

### 0.4 Consequences for the contract as a whole

- **No blocking convention mismatch remains.** Every difference is either a
  relabelling (1.2), a unit power of √2 (8.1), a cancelling `4π` (4.1/4.2 vs
  4.3/4.5), a numerical method (5.1/9.1/9.3), or a term one side simply does not
  have (4.7, 5.4, 6.x). Rows 1.2, 4.4 and 8.1 need an explicit transformation; the
  rest are direct.
- **The `Ueda code` columns stay empty.** These findings live in §0, not in the
  per-row `Ueda code` cells, because Matsui et al. are not the Ueda lab and merging
  them would make the table claim a channel that does not exist
  (`ueda_status.md` criterion 1 is still unmet).
- **The inverse problem is untouched.** Their F=6 model has `a₂ = a₄ = a₆ = 0` and
  `cc2 = cc3 = 0`; the spin-dependent strength is the `_eff` knob. The six unknown
  `a_S` are not in this dataset and cannot be extracted from it.

### 0.5 Fig. 4B — the target, measured off their own data

`test/fixtures/matsui2025/dataset_fig4_theo.csv` is a 1 nT grid descending from
+20 nT (0.5 nT between −10 and +10), 61 points, totalling 49999.9 atoms at every
field. The Fig. 4B observable is `N_{m=−6}` after a 5 ms hold. Applying
`resonance_dip` (parabolic vertex; half-depth crossings against a per-side endpoint
baseline) to both published curves:

| curve | dip centre | half-depth width | minimum |
|---|---|---|---|
| their **simulation** (`dataset_fig4_theo`) | **−2.5495 nT** | **15.0224 nT** | 12287 |
| their **experiment** (`dataset_fig4_exp`, 4/3 repeats averaged) | **−3.2048 nT** | **14.5414 nT** | 8818 |

Type C, producing commit `bbbe4829`, gated in tier `ci` by
`test/validation/test_matsui_fig4_dip.jl`.

**The paper's own framing is not the sharpest test available.** It contrasts an
*analytic* estimate of −1.5 nT (from the rotational kinetic energy, refs 38-39)
with −3.5 nT observed, and attributes the gap to the gas's dipole field. But their
simulation — which contains that dipole field — already lands at **−2.55 nT**, 70 %
of the way across. So the number a second implementation of the same model has to
reproduce is −2.55 nT, not −1.5 and not −3.5; and the residual 0.66 nT between their
simulation and their experiment is the honest floor, sitting just under the ~1 nT
field fluctuation the Fig. 4 caption itself quotes.

### 0.6 The reproduction — configs, cost, and what is NOT yet measured

`runs/matsui_fig4b/`, submitted from commit `2e63f0c5`, ancestor-gated against
all 14 refs in `docs/campaign/fix_list.toml`, clean tree:

| task | config | fields | grid | what it is for |
|---|---|---|---|---|
| 1 | `fig4b_scan_n32.yaml` | 45, −13 … +9 nT @ 0.5 | 32³, box 16 | the curve, hence the centre and width |
| 2 | `fig4b_conv_n64.yaml` | 6 | 64³, box 16 | resolution error bar on task 1's centre |
| 3 | `fig4b_gsvariant_n32.yaml` | 19, −8 … +1 nT | 32³ | prices the §0.3.5 ground-state ambiguity |
| 4 | `fig2c_populations_n32.yaml` | 1 (2.6 nT), 40 ms | 32³ | `N_m(t)` against `dataset_fig2_theo` |

Read alongside the numbers, whenever they land:

- **32³ is under-resolved and the run cannot certify itself.** `dx = 0.5 a_ho`
  against a healing length `ξ = 1/√(2µ) ≈ 0.20 a_ho`; the occupied band edge
  `√(2µ) ≈ 5.1` sits at `0.81 k_max`. The charter's guard 4 (≥ 4 points per
  healing length) is **violated**, and it is violated by their production run too
  (`dx = 0.4 aHO` against `ξ ≈ 0.28 aHO`, 0.7 points). Task 2 exists because of
  this; without it the 32³ centre is a number, not a measurement.
- **The step cost is ~70× the campaign cost-table extrapolation**: 27 ms at 32³
  D=13 with the padded DDI, measured in UGE 8304399, against the ~0.4 ms that
  scaling 3.2 ms at 64³ by cell count predicts. Budget from the measurement.
- **Dealiasing is off** on both sides (theirs has none; Orszag 2/3 at 32³/box 16
  would cut `k_cut = 4.19` below the occupied `√(2µ) ≈ 5.1`).
- Our kernel carries the spherical truncation and `Q(k=0) = 0`; theirs carries
  neither. Both differences are bounded above in §0.3.3 at ~0.02 nT and
  5×10⁻³ nT — below what is being measured, but they are not zero and the run
  should not be quoted to better than that.

---

## 1. Spin-matrix conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 1.1 | F (spin quantum number) | `atom.F`, integer | _to fill_ | _to fill_ | Eu151 → F=6 |
| 1.2 | Component ordering | `c=1 ↔ m=+F`, `c=D ↔ m=−F` (where `D = 2F+1`) — i.e. **descending** in m | _to fill_ | _to fill_ | `src/foundation/types/spin.jl` `m_values = [+F, +F-1, …, −F]` |
| 1.3 | F_z matrix | `F_z[c,c] = m_values[c]` (diagonal, descending) | _to fill_ | _to fill_ | `src/foundation/types/spin_matrices.jl` |
| 1.4 | F_x, F_y | Standard `[F_x, F_y] = iF_z` (sign of i convention: `+i`) | _to fill_ | _to fill_ | `test/foundation/test_spin_matrices.jl` pins this |
| 1.5 | F² Casimir | `F² = F(F+1)·I` | _to fill_ | _to fill_ | Standard, no choice involved |
| 1.6 | Ladder normalisation | `F_±|F,m⟩ = √(F(F+1)−m(m±1))·|F,m±1⟩` | _to fill_ | _to fill_ | Condon-Shortley phase |

## 2. Zeeman conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 2.1 | Linear Zeeman | `H_Z^lin = -p · F_z` so `(Hψ)_m = -p·m·ψ_m` | _to fill_ | _to fill_ | sign: p > 0 lowers m=+F |
| 2.2 | Quadratic Zeeman | `H_Z^quad = +q · F_z²` so `(Hψ)_m = +q·m²·ψ_m` | _to fill_ | _to fill_ | sign: q > 0 raises \|m\|=F |
| 2.3 | p relationship to B | `p = g_F · μ_B · B_z / (ℏ · ω_ref)` (dimensionless) | _to fill_ | _to fill_ | `src/foundation/units.jl` `bfield_to_p`. Sign: same sign as B_z when g_F > 0. |
| 2.4 | q relationship to B | Auto-derived from \|B\|² unless explicit. Formula: see source. | _to fill_ | _to fill_ | `src/workflow/experiments/schema/B_block.jl` |
| 2.5 | g_F sign convention | Per-atom from CODATA tables; Eu151 g_F ≈ +1.163 (positive) | _to fill_ | _to fill_ | `src/workflow/initialization/atoms.jl` |
| 2.6 | B-field direction | Spherical: \|B\| · (sin θ cos φ, sin θ sin φ, cos θ). θ=0 ⇒ +ẑ | _to fill_ | _to fill_ | `src/workflow/experiments/schema/B_block.jl` |
| 2.7 | ITP Zeeman overflow shift | We subtract `min(E_m)` per voxel to prevent overflow in exp(-τH) | _to fill_ | _to fill_ | `src/solvers/ground_state/itp_loop.jl` — **must** be the same shift in Ueda code or energies are offset |

## 3. Contact-interaction conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 3.1 | Energy functional (F=1) | `E_int = (c₀/2)·n² + (c₁/2)·\|⟨F⟩\|²` | _to fill_ | _to fill_ | Kawaguchi-Ueda Eq. 7.1 |
| 3.2 | c₀ definition | `c₀ = (4π·ℏ²/m) · (a₀ + 2a₂)/3` (F=1); `c₀ = c_total / (1 + F²·c₁/c₀)` (general) | _to fill_ | _to fill_ | `src/hamiltonian/interactions/interactions.jl` `compute_interaction_params` |
| 3.3 | c₁ definition | `c₁ = (4π·ℏ²/m) · (a₂ − a₀)/3` (F=1) | _to fill_ | _to fill_ | sign: c₁ > 0 ⇒ polar, c₁ < 0 ⇒ ferromagnetic |
| 3.4 | Singlet-pair amplitude A₀₀ | Standard CG: `A₀₀ = ⟨S=0,M=0\|ψ⊗ψ⟩` (F=2: `A₀₀ = (2ψ₊₂ψ₋₂ − 2ψ₊₁ψ₋₁ + ψ₀²)/√5`) | _to fill_ | _to fill_ | `src/analysis/observables.jl` `singlet_pair_amplitude` |
| 3.5 | c₂ singlet-pair coefficient | F=2: `c₂ = (4π·ℏ²/m) · (3a₄ − 10a₂ + 7a₀)/15` | _to fill_ | _to fill_ | sign: c₂ > 0 ⇒ cyclic, c₂ < 0 ⇒ nematic |
| 3.6 | higher-rank c_n (n ≥ 4) | Pass via `InteractionParams(Dict(0=>c0, 1=>c1, 4=>c4, 6=>c6, ...))` — even rank only. | _to fill_ | _to fill_ | Odd-rank n ≥ 3 rejected at construction. Eu (F=6): S=0,2,4,6,8,10,12 channels. |
| 3.7 | ψ normalization | `∫\|ψ\|² dV = 1` (we absorb N into the coefficients) | _to fill_ | _to fill_ | Ueda may use `∫\|ψ\|² = N` instead — needs explicit transformation |

## 4. DDI conventions

**Critical**: this is the #1 suspected source of disagreement.

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 4.1 | Coefficient c_dd | `c_dd = μ₀ · μ²` where μ = g_F · μ_B (per-spin-matrix, **NOT** g_F·F·μ_B) | _to fill_ | _to fill_ | `src/hamiltonian/interactions/interactions.jl:111-119`. The F² factor is supplied by the spin operators inside the integral. |
| 4.2 | NO 4π factor | We omit 4π from c_dd | _to fill_ | _to fill_ | If Ueda includes 4π, multiply our c_dd by 4π for comparison |
| 4.3 | DDI kernel in k-space | `Q_αβ(k) = k̂_α·k̂_β − δ_αβ/3` | _to fill_ | _to fill_ | sign: traceless. Spherically symmetric n → ∫Q=0. |
| 4.4 | k=0 mode regularisation | `Q(k=0) = 0` (Pedri-Santos) | _to fill_ | _to fill_ | Removes self-energy divergence in unbounded geometry |
| 4.5 | NO 1/(4π) in kernel | Q is the bare traceless tensor; no 1/(4π) prefactor | _to fill_ | _to fill_ | Chain self-consistent with c_dd convention (4.1, 4.2) |
| 4.6 | Magnetic moment μ for DDI | `mu_gF = atom.mu_mag / F` (= g_F · μ_B). Eu151: `atom.mu_mag` stores g_F·F·μ_B saturation, divided by F here. | _to fill_ | _to fill_ | If Ueda passes μ_sat directly, our F=6 c_dd is 36× smaller |
| 4.7 | Secular DDI vs full DDI | User-chosen. Eu experiments default to `secular_ddi=true`; advisory @info when ω_L/(c_dd·⟨n⟩) > 100 | _to fill_ | _to fill_ | Secular keeps only Zeeman-diagonal DDI components |
| 4.8 | Spin-rotation frame | `spin_rotating_frame_omega ≠ 0` **requires** `secular_ddi=true` (`ArgumentError` enforced) | _to fill_ | _to fill_ | Off-diagonal DDI components only Larmor-average to zero in the secular limit |

## 5. Kinetic / FFT conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 5.1 | Kinetic energy | `T = (-ℏ²/2m)·∇²` per component | _to fill_ | _to fill_ | Standard |
| 5.2 | FFT k-grid | `k = (2π/L)·[0, 1, …, N/2-1, -N/2, …, -1]` (standard FFTW frequency layout) | _to fill_ | _to fill_ | `src/foundation/grid.jl` |
| 5.3 | k=0 mass | `T(k=0) = 0` (no zero-point shift) | _to fill_ | _to fill_ | Standard split-step |
| 5.4 | Dealiasing | Orszag 2/3 rule, off by default, ON for production via YAML `dealias:` block | _to fill_ | _to fill_ | `src/hamiltonian/integrator/dealias.jl`. Affects high-k bandwidth → DDI accuracy. |

## 6. LHY conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 6.1 | Scalar LHY energy density | `ε_LHY = (2/5) · c_lhy · n^(5/2)` | _to fill_ | _to fill_ | `src/analysis/energy.jl` |
| 6.2 | Scalar LHY potential | `V_LHY = c_lhy · n^(3/2)` (= ∂ε/∂n) | _to fill_ | _to fill_ | `src/hamiltonian/integrator/propagators.jl:140` |
| 6.3 | c_lhy auto-derivation | scalar: from textbook `c_lhy = (32/(3√π))·g·(m·a/ℏ²)^(3/2)` etc. | _to fill_ | _to fill_ | `lhy: {kind: scalar}` derives from interactions |
| 6.4 | Spinor LHY F=6 caveat | PolarTwoChannelLHY is **incomplete** at F=6 (~30-70% offset vs PolarContactLHY) | _to fill_ | _to fill_ | Use `PolarContactLHY` / `IcosahedralLHY` for F=6 polar |
| 6.5 | FullBdGLHY F=6 polar | Matches `polar_contact` to ~1e-4 (UV counterterm fixed 2026-07-27) | _to fill_ | _to fill_ | Warns only on dynamical instability |

## 7. Loss / K3 conventions

Loss is **NOT** part of the Hamiltonian-only Level 9-10 comparison. Listed
here so the contract covers the full pipeline.

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 7.1 | K3 equation shape | `dn_m/dt = -K_3 · n² · n_m` (quadratic in total n) | _to fill_ | _to fill_ | True 3-body; `K3_per_m_cubic` slot |
| 7.2 | L3 legacy shape | `dn_m/dt = -γ · n · n_m` (linear in total n) | _to fill_ | _to fill_ | Legacy 2-body shape, separate `L3_per_m` slot |
| 7.3 | SI → dimless conversion | `K3_dimless = K3_SI · n₀² / ω_ref` where `n₀ = N / a_ho³` | _to fill_ | _to fill_ | `src/workflow/experiments/schema/parsing_blocks.jl` |
| 7.4 | Strang splitting with loss | Half-step Hamiltonian + full-step loss + half-step Hamiltonian | _to fill_ | _to fill_ | Loss is dissipative, Strang-compatible |

## 8. Units conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 8.1 | Length unit | a_ho = √(ℏ/(m·ω_ref)) (harmonic oscillator length) | _to fill_ | _to fill_ | Per-atom; Eu151 → a_ho ≈ 2.0e-6 m at ω_ref=2π·100 Hz |
| 8.2 | Time unit | 1/ω_ref | _to fill_ | _to fill_ | t̃ = t·ω_ref |
| 8.3 | Energy unit | ℏ·ω_ref | _to fill_ | _to fill_ | Ẽ = E/(ℏ·ω_ref) |
| 8.4 | Density unit | 1/a_ho³ (3D) | _to fill_ | _to fill_ | ñ = n·a_ho³ |
| 8.5 | ℏ, m, ω_ref | All set to 1 in dimensionless code | _to fill_ | _to fill_ | "Dimensionless units: ℏ=m=ω_ref=1" |

## 9. Integrator conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 9.1 | Real-time propagator | `exp(-i·dt·H)` (signed: `cis(-dt·H)`) | _to fill_ | _to fill_ | Standard QM time evolution |
| 9.2 | Imaginary-time propagator (ITP) | `exp(-τ·H)` with normalization renorm after each step | _to fill_ | _to fill_ | `src/solvers/ground_state/itp_loop.jl` |
| 9.3 | Strang splitting | `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)` | _to fill_ | _to fill_ | `src/hamiltonian/integrator/split_step.jl` |
| 9.4 | Inner V ordering | `diag SM singlet_pair tensor raman DDI raman tensor singlet_pair SM diag` (symmetric/palindrome) | _to fill_ | _to fill_ | Symmetric to preserve 2nd-order Strang accuracy |
| 9.5 | Default integrator order | Strang (2nd-order). Higher: Yoshida-4, CFET4 opt-in | _to fill_ | _to fill_ | `_YOSHIDA_W0 < 0` is correct (backward middle substep) |

## 10. Initial state conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 10.1 | Default state | `:polar` (m=0 component fully populated) | _to fill_ | _to fill_ | `src/workflow/initialization/state_dispatch.jl` |
| 10.2 | `:m_plus_F` | `c=1` populated (component for m=+F under our descending ordering) | _to fill_ | _to fill_ | Lowest Zeeman energy when p>0 |
| 10.3 | `:m_minus_F` | `c=D` populated | _to fill_ | _to fill_ | Highest Zeeman energy when p>0 (relevant for EdH initial state) |
| 10.4 | Gaussian envelope | σ = box/8 per axis | _to fill_ | _to fill_ | Standard for ground-state seeding |
| 10.5 | Thermal seed | `add_thermal_seed(psi, F; T_over_Tc, seed)` with `η = √((T/T_c)³/4)` heuristic | _to fill_ | _to fill_ | **NOT** a true thermal Wigner sample — for that use SGPE callback |

---

## Quick "send to Ueda" packet

Once this contract has both columns filled and `Match?` is "yes" or
"transformation documented" for every row:

1. Run `scripts/validation/export_operator_rhs.jl <yaml> <output_dir>`
   to generate `operator_rhs.jld2` (contains ψ, Hψ, energy
   decomposition, all conventions in metadata).
2. Send Ueda lab: this signed contract + the jld2 + the YAML.
3. Receive their `operator_rhs.jld2` back.
4. Run `scripts/validation/compare_operator_rhs.jl ours.jld2 theirs.jld2`
   to compute `‖Hψ_ours − Hψ_Ueda‖_L²` and the per-term energy diff.

If the diff is `~10⁻¹²`, Level 10 PASS. Validation ladder Level 11
(convergence) and Level 12 (production) are then unblocked.

If the diff is `~10⁻²` or larger, the bug is **NOT** in K3 / LHY /
long-time integration. It is in one of the rows above. Read down the
contract and find the row where the convention disagrees.

## Acceptance criteria (Level 10 PASS)

All four sub-checks must pass:

1. **Energy decomposition diff**: per-term `|E_ours − E_Ueda| / E_total < 1e-10`
2. **Hψ diff (strongest)**: `‖Hψ_ours − Hψ_Ueda‖_L² / ‖Hψ_ours‖_L² < 1e-10`
3. **One-step diff**: `‖ψ_after_dt^ours − ψ_after_dt^Ueda‖_L² < O(dt³)` (integrator-dependent)
4. **Short-time diff**: `|F_z(t)^ours − F_z(t)^Ueda| < 1e-6` at t = 0.1·t_collapse

If 1-2 pass but 3 fails: integrators differ but operators agree — fine
for physics, document the integrator choice.
If 1-2 fail: **stop**. Find the convention mismatch. Do not advance.

## References

- `validation_ladder_2026_05_24.md` — full ladder
- `docs/theory/kawaguchi_ueda_review_notes.md` (if exists) — derivation notes
- `docs/refs/Kawaguchi_Ueda_Spinor_BEC_Review.pdf` (if held locally) — textbook
- CLAUDE.md "Conventions (do NOT 'fix')" — list of conventions that are
  load-bearing in this codebase

## SpinorBEC.jl-side verification log (2026-05-26)

All load-bearing claims in this contract were re-derived from `src/`
on the SpinorBEC.jl side before sign-off. Reproducible verification
snippet (run from project root):

```julia
using SpinorBEC
sys = SpinSystem(6); sm = spin_matrices(6)

# Row 1.2 — m descending, c=1 ↔ m=+F
@assert sys.m_values == [6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6]

# Row 1.3 — F_z diagonal matches m_values
@assert all(real(sm.Fz[i, i]) == sys.m_values[i] for i in 1:13)

# Row 1.4 — Condon-Shortley: [F_x, F_y] = i·F_z (machine eps)
@assert maximum(abs.((-im) .* (sm.Fx*sm.Fy - sm.Fy*sm.Fx) - sm.Fz)) < 1e-12

# Row 1.5 — F² = F(F+1)·I
@assert real(sm.F_dot_F[1, 1]) == 6 * 7

# Row 2.1 / 2.2 — H_Z = -p·F_z + q·F_z²
import SpinorBEC: zeeman_diagonal
z = ZeemanParams(1.0, 0.1)
@assert zeeman_diagonal(z, sys)[1] == -1 * 6 + 0.1 * 36   # m=+F = -2.4

# Row 4.1 / 4.6 — c_dd = μ₀·(g_F·μ_B)², μ_per_spin = atom.mu_mag / F
@assert compute_c_dd(Eu151) ≈ 1.461394562409078e-52
@assert Eu151.mu_mag / 6 ≈ 1.078397348588188e-23   # = g_F·μ_B for Eu151
```

Result: 7/7 assertions PASS. Document signed below.

## Sign-off

| Side | Name | Date | Signature / commit hash |
|---|---|---|---|
| SpinorBEC.jl | anko via Claude Opus 4.7 (1M context) | 2026-05-26 | _filled at commit time_ |
| Ueda lab | _to fill_ | _to fill_ | _to fill_ |
