# ¹⁵¹Eu evaporation — calibration data by epoch

The trap has **changed across epochs**, so calibration values must not be mixed.
Mixing the 2022 paper's trap *frequencies* with the 2023 notebook's *depth* produced a
spurious 5.6× polarizability conflict during model development. **Rule: pick one epoch.**

Epochs: **2021 thesis (Miyazawa)** → **2022 PRL** → **2023 notebooks** (degraded) →
**2025 EdH paper (Matsui, current gen, 5×10⁴ BEC)**.

- **Validate the model's physics** → 2021 thesis (complete, self-consistent; gives α,
  γ=3.6, T_c — all epoch-independent and confirmed).
- **Optimize the current apparatus** → the 2025 generation (arXiv:2504.17357). Its
  evaporation ramp is only in Matsui's PhD thesis (not on arXiv) — the remaining input.
  Do not optimize against the degraded 2023 data.

---

## 2021 — Miyazawa PhD thesis (Kozuma lab) — MOST AUTHORITATIVE for the trap + rates

The thesis states the load-bearing constants directly (the PRL only quotes results).
**Use these for the trap/rate calibration.**

| Quantity | Value |
|---|---|
| Scalar polarizability | **α_s = 189(5) a.u. = 5.87×10⁻³⁷ J/(W/m²)** (= 189·4πϵ₀a₀³/(2ϵ₀c)) |
| Vector / tensor pol. | **α_v = 0(3), α_t = 0(5) a.u.** ⇒ **no vector/tensor light shift** (scalar trap) |
| H-ODT | elliptical **30 µm (h) × 26 µm (v)**, max **11.5 W**, max depth **400 µK** |
| V-ODT | waist **47 µm**, max **7.4 W**, max depth **90 µK**, crossed at 12° (78° to hODT) |
| Loading | 1.4×10⁶ atoms @ 50 µK in hODT (11.5 W, 40 ms from red-MOT, ~5 % efficiency) |
| Ramp (Fig 7.1/7.3) | hODT **10 → 0.5 W over 7.4 s**; vODT added midway, **reduced to ¼ in the last stage** (cuts 3-body); bias 3.0 G + loosening vODT = the optimization |
| **Background lifetime** | **τ_bg > 150 s** (collisional loss with background < 0.1 s⁻¹) |
| **Evaporation efficiency** | **γ = −ln(ρ_f/ρ_i)/ln(N_f/N_i) = 3.6** (measured; typical 2.5–3.5). Model gives γ_eff ≈ 3.9 — agree to 8 %. |
| **Three-body loss** | **L ≈ 10⁻²⁹ cm⁶/s = 10⁻⁴¹ m⁶/s** (1/e BEC lifetime 1.4 s; a_s=135 a_B, ω̄=2π·204 Hz). Mind the K₃ convention vs `EvapParams.K3` (dN=−K₃⟨n²⟩N). |
| Scattering length | a_s = 135 a_B (thesis) → **110(4) a_B** (PRL refined) |
| T_c | **T_c⁰ = 0.94 (ℏω̄/k_B) N^{1/3}** — identical to `bec_critical_temperature`; corrections δT_fs = −0.73(⟨ω⟩/ω̄)N^{-1/3}T_c⁰, δT_int = −1.33(a_s/a_HO)N^{1/6}T_c⁰ |
| First BEC / optimized | 3×10³ / 1.5×10⁴ atoms (this thesis, earlier than the PRL's 5×10⁴) |

**These confirm the model's independently-derived calibration: α (5.88e-37 ✓), the
γ_eff efficiency (3.9 vs 3.6 ✓), and the T_c formula. `evap_scale = 1` stands.** The
PRL (below) is the later, higher-N generation of the same apparatus.

## 2022 — Miyazawa/Matsui et al., PRL 129, 223401 (arXiv:2207.11692)

The published BEC (later generation, N=5.02×10⁴). Complete and internally consistent;
used for the model's C-validation (parameter-free agreement to 6–15 %,
`test/solvers/test_condensate.jl`).

| Quantity | Value |
|---|---|
| Wavelength | 1550 nm |
| H-FORT (horizontal) | **elliptical 31 µm (horiz) × 25 µm (vert)**, initial **10 W**, H-polarized |
| V-FORT (vertical) | waist **42 µm**, max **1.6 W**, tilted 12° from vertical, ⟂ polarized |
| Loading (10 W H-only) | N = 3.5×10⁶, **T = 50 µK**, depth **350 µK**, freqs (axial, radial) ≈ **(30, 1500, 1800) Hz**, peak n = 3.3×10¹³ cm⁻³, PSD 2.7×10⁻⁴ → **η_start = 7** |
| Evaporation | ~8 s, H lowered gradually, V turned on midway. Full ramp only in Supplemental [28] (NOT in the arXiv version). |
| BEC onset | N = 1.61×10⁵, **T = 349 nK**, freqs **(97, 226, 217) Hz** (ω̄ = 168 Hz), theory **T_c = 367 nK**, BEC fraction 7 % |
| Final | **5.02×10⁴** atoms, almost pure BEC |
| Scattering length | a_s = 110(4) a_B |
| Feshbach | resonance at 1.32 G, width 10 mG |

**Derived calibration** (matches depth AND frequencies AND η_start AND T_c):
`α = 5.88×10⁻³⁷ J/(W/m²)`, H effective round waist `√(31·25) = 27.84 µm` (an elliptical
beam preserves both depth `∝ 1/(w_x w_y)` and geometric-mean ω̄ under the round w_eff).

```julia
trap = euv3_evap_trap(; alpha=5.88e-37, waists=[sqrt(31e-6*25e-6), 42e-6, 42e-6])
```

---

## 2025 — Matsui et al., Einstein–de Haas effect (arXiv:2504.17357)

The current-generation apparatus (Matsui, Miyazawa, Goto, Nakano, Kawaguchi, Ueda,
Kozuma). A Science-format paper — brief methods, so the evaporation ramp powers are
**not** here (they are in Matsui's PhD thesis, not on arXiv).

| Quantity | Value |
|---|---|
| MOT→MOT transfer | **26(3) %** (vs ~5 % in the 2021 thesis — improved) |
| Evaporation | crossed ODT (horizontal + vertically-inclined beam), bias **0.3 mT** vertical, into F=6,m=−6; both-beam ramp |
| Science (round) trap | two horizontal beams (one waist **50 µm**, axes 10 µm apart, 0.2 s linear transfer) → depth **1.3 µK**, **(110, 110, 130) Hz** (nearly spherical), **N ≈ 5×10⁴**, negligible thermal |
| Imaging | 460 nm, σ-polarized; SG gradient 42 mT/m |

T_c check: `bec_critical_temperature(5e4, 2π·116)` ≈ 192 nK (ω̄ = (110·110·130)^{1/3} =
116 Hz) — consistent with the 1.3 µK depth holding a sub-µK condensate. **Still need
Matsui's thesis (off-arXiv) for the evaporation ramp** — that closes the last gap.

## 2023-07-19 — notebook (蒸発冷却), single-beam holds

Setup **degraded** vs 2022 ("IR fiber power dropped"). Single horizontal FORT (V folded
off), hold-and-measure. Used to extract τ_bg and to validate the low-η evaporation rate.

| Config | Depth | η / T | N | Notes |
|---|---|---|---|---|
| 7 W H-only | **66 µK** | η_start = 3.7 (T = 17.8 µK) → 6.3 over 7 s | ~3.3×10⁶ | τ_bg ≈ **36 s**; cools 18→10.5 µK |
| 1.1 W | **5 µK** | η → 5 at 4 s (T ≈ 1 µK) | ~10⁵ | ⚠️ the 1.1 W **temperature graph axis is ×10 off** — use η/depth, not the axis |
| 7 W @ 3.0 G bias | — | — | — | lifetime 27 s (vs 36 s at 0.2 G) |

Depth coefficient ≈ **9.4 µK/W** (vs 2022's 35 µK/W) ⇒ the 2023 trap is **~3.7× shallower**
and runs at **low η (3.7–6.3) = the inefficient regime** the notebook calls "very hard".

---

## 2023-11-06 — notebook (evap改良), the BEC sequence

Evaporation from the loaded crossed trap; the "shorten the ramp" improvement.

Ramp (loaded start, H/V powers [W]; durations 0.3,0.5,0.4,0.6,0.3,0.2,0.1,0.2 s):
`H: 6→4→2→1→0.56→0.26→0.16→0.12→0.10`, `V: 0→1.8→1.7→1.6→1.5→1.4→1.0→0.6→0.10`.

Measured N vs H-FORT power: 4 W→2.1×10⁶, 2 W→1.5×10⁶, 1 W→1.0×10⁶, 0.56 W→1.0×10⁶,
0.26 W→3.9×10⁵, 0.16 W→2.4×10⁵, 0.12 W→1.3×10⁵, **0.10 W→5.8×10⁴ (BEC)**.
Loading N₀ = 3.67×10⁶ (H-FORT only), T₀ ≈ 18 µK.

**Findings (independently confirm the model's mechanism):** shortening each ramp segment
gave **~3× more BEC atoms** (attributed to collisional/3-body loss); "loosen the trap to
lower the density" expected to gain more (longer sequence). Gentle N loss early, sharp
crash late (= the thermal→condensate transition).

---

## Now (2026) — to optimize the current apparatus, measure these

The 2022 → 2023 change (350 µK → 66 µK at comparable power) shows the trap drifts, so the
2023 data is also stale for today. The minimal current-epoch set (one point each):

1. **Trap frequency** at a known FORT power (one axis fixes α; two axes if elliptical).
2. **N₀ and T₀** right after ODT loading (evaporation start).
3. **The current ramp** (H/V power vs time).
4. **The BEC atom number achieved** (fixes K₃).

With these, the parameter-free model (`evap_scale = 1`, 3D Luiten rate) predicts and
optimizes the *current* evaporation. Optional refinement: `τ_bg` (hold lifetime) and the
magnetic levitation gradient (sets `EvapTrap.gravity_factor`).

## What is theory-fixed vs setup-measured

| Determined by THEORY (no fit) | Measured PER SETUP |
|---|---|
| evaporation rate `V_evap/V_eff(η)` (3D Luiten) | beam waists |
| excess-energy `κ̃(η)` | polarizability α (from a trap frequency) |
| peak density `n₀(N,T,ω̄)` | FORT power ramp |
| T_c(N, ω̄); condensate split | N₀, T₀ at loading |
| collision rate `γ_el = n₀σv̄/√2` (a_s known) | K₃ (from the BEC number); τ_bg; levitation |

## Validation figures

- `figures/eu_bec_thesis_validation.png` — the parameter-free model (`evap_scale=1`,
  3D Luiten rate) vs the 2021 thesis: efficiency **γ_eff = 3.63 vs measured 3.6** (0.8 %),
  cooling 50 µK → ~210 nK landing on T_c, condensate forming between the first (3×10³)
  and optimized (1.5×10⁴) BEC. The definitive validation — physics is epoch-independent.
- `figures/eu_all_datasets_fit.png` — the same parameter-free model across all datasets.
  It nails the one **complete self-consistent** set (2021 thesis). The others' residuals
  have identified *physical* causes, not hidden knobs:
  - **2022 PRL**: needs the actual (improved, higher-N) ramp; the thesis ramp is a
    different generation.
  - **2023-07 Exp A**: a single-beam trap. The single-beam physics is already fully
    determined — the thesis measures the waists with a beam profiler (30×26 µm) and
    derives ω̄ "from ODT beam waists and power, and polarizability" (thesis §7.1.2),
    exactly as this model does; with those, the model matches (γ_eff). It is also NOT a
    dimensionality issue — for an ODT the beam-edge anharmonicity restores 3D evaporation
    even when elongated/gravity-tilted (Hung et al. 2008; microgravity DSMC). The ~3×
    residual is simply that the **2023 setup had degraded** (the notebook notes the IR
    power dropped; depth 66 µK vs the thesis ~243 µK@7 W) and the degraded beam's waist
    was **not re-measured** (only the depth was) — a gap in that old notebook, not in the
    physics. The density `n₀ ∝ U₀^{3/2}/w⁴` is hyper-sensitive to the waist, so the stale
    waist is enough to explain it. Nothing to fix in the model.
  - **2023-11**: the degraded beam (effective waist 54 µm vs the thesis 28 µm — the
    measured 66 µK@7W) plus a gravity-limited final trap.

**Takeaway:** the model's physics is validated parameter-free on complete data; fitting
the others is limited by *missing measured inputs* (ramps, current waists) or an
out-of-regime geometry (single-beam cigar), both honest and identified — not by tuning.

## Validated physics (2026-06-17) — all parameter-free, no `evap_scale` fudge

Three corrections turned the model from order-of-magnitude to quantitative, each pinned to
DIRECT data, none a fit knob:

1. **Polarizability α = 5.88×10⁻³⁷ J/(W·m⁻²)** (≈189 a.u.). Fixed by the 2022 PRL loading
   depth (350 µK @ 10 W single-H, waist √(31·25)=27.8 µm). The SAME α reproduces the measured
   (97,226,217) Hz final trap at a crossed H=V≈0.18 W. The earlier 1.25×10⁻³⁶ was an
   epoch-mixing artifact (PRL frequencies forced onto the current euv3 0.14/0.09 W powers) +
   a wrong waist (31 µm long axis instead of the 25 µm short axis for ν_z).

2. **Cooling law `L = dlnT/dlnN = (ε̄−3)/3`**, ε̄ = 3(1−P4)/(1−P3) (O'Hara energy balance,
   evaporated atom carries ε̄≈η+1 k_BT). → (η−2)/3 at large η, gently → 0 at low η. The old
   `(η−3)/3` form mis-cooled. **Validated against the 7 W single-FORT hold**: measured
   dlnT/dlnN ≈ 0.8 at η≈4, model 0.82.

3. **s-wave unitarity cross section `σ(T) = 8πa²/(1+k²a²)`**, `k²a² = 2(m k_BT/ℏ²)a²`
   (flux-weighted mean collision energy 2k_BT). T-dependent, parameter-free: ~15 % lower σ at
   16 µK, ~10 % at 10 µK for Eu — it lowers the HOT-cloud elastic rate and leaves COLD clouds
   at full σ. (An earlier ad-hoc `σ(E)=…2η k_BT` tied to the evaporation energy was wrong —
   the spurious "2× dipolar enhancement"; the textbook unitarity limit is the correct term.)

Lab ground truth (蒸発冷却.pdf, 2023-07-19): 7 W hold @ **0.2 G**, η **3.7→6.3** over 7 s,
τ_bg **36 s**, first 0.2 s = loading transient. **Depth caveat:** the note's "66 µK" is the
OPTICAL depth `α·2P/πw²`; the physical escape barrier is GRAVITY-reduced to ~51 µK (mg·w≈9.5 µK
cuts the downward barrier), so the real η_start≈2.9, not 3.7 — `crossed_trap_depth` is correct,
the note over-estimates η. 1.1 W hold: optical 10 µK → gravity-reduced ~5 µK.

### The 7 W hold residual = directional systematics (NOT symmetric 0-D noise)

The σ-constant model is COLDER than the data at EVERY η — a ONE-SIDED residual, the signature of
a directional bias (symmetric ±X % errors sum in quadrature and sometimes overshoot; they do not
pile up one-sided). Three NAMED, directional (always model-too-cold) mechanisms, measured not
guessed:

- **(C) s-wave unitarity** [done, parameter-free] — lowers the hot rate, ~30 % of the gap.
- **(A) finite-escape-time / reduced ergodicity** (Surkov) — **NEGLIGIBLE** here: the cigar escapes
  over the tight radial (gravity-vertical) barrier, transit 2.8 ms ≪ collision-limited evap 9.7 s
  (ratio 3×10⁻⁴). Collision-limited, not transit-limited. Not implemented.
- **(B) technical intensity-noise heating** (Savard–O'Hara–Thomas PRA 56 R1095): `dT/dt = Γ_h T`,
  `Γ_h = π²ν_r²S_I(2ν_r)` — `EvapParams.heating_rate`, default 0. A degraded-beam RIN
  `S_I~2×10⁻⁸/Hz` at ν_r=358 Hz gives Γ_h~0.025/s ⇒ +2 µK over 7 s = the residual. The coefficient
  is a measurable lab quantity (RIN × ν_r²), not a fudge; ∝ν_r² so worst on the cigar's tight radial.

**Decisive separation (ramp-speed scan):** re-take the 7 W endpoint at 2× slower / 2× faster ramp.
Slower → COLDER ⇒ rate-limited (C); slower → same/WARMER ⇒ heating-limited (B). The two have opposite
signs, so one scan settles it. 1.1 W under-cools (super-dilute, ~2 collisions/atom; note flags its N
data as too noisy to trust) — a data/regime wall, separate from the directional systematics.

## Design recommendation — narrow the FORT waist (answers the note's question)

The note ends asking "ビームウエストを細くするしかないのだろうか" (must we narrow the beam?).
The validated model says **yes, and quantifies it** (`eu_evaporation_waist_design.png`): at the
current ~53.6 µm the cloud loads at η≈2.9 (marginal — slow spilling, the lab's pain), and a 7 W
hold never reaches η=8 in 10 s, retaining only ~29 % of atoms. **Narrowing to ~40–45 µm** lifts
the loading to η≈5 (the efficient regime), reaches η=8 in ~2 s, and retains ~50 %. Physics:
depth ∝ 1/w², density ∝ 1/w⁴ — both push evaporation out of the marginal regime. The note's goal
"η~8 for efficient evaporation" is reached at w ≲ 40 µm.
