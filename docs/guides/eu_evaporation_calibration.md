# ¹⁵¹Eu evaporation — calibration data by epoch

The trap has **changed across epochs**, so calibration values must not be mixed.
Mixing the 2022 paper's trap *frequencies* with the 2023 notebook's *depth* produced a
spurious 5.6× polarizability conflict during model development. **Rule: pick one epoch.**

- **Validate the model** → use the **2022 paper** (complete, self-consistent, published).
- **Optimize the current apparatus** → use **fresh measurements** (the setup is shallower
  now; see below). Do not optimize against old data.

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
