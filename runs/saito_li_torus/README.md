# Saito–Li magnetic-vortex torus droplet at ¹⁵¹Eu F=6 — issue #336

Target: Li & Saito, *Quantum droplets with magnetic vortices in spinor dipolar
Bose-Einstein condensates*, [arXiv:2402.18885](https://arxiv.org/abs/2402.18885)
(v1, 29 Feb 2024). Local copy:
`docs/refs/Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf`.

The cell is **Fig. 1(d) third panel / Fig. 2(a) cyan curve**:
(F, N, ε_dd) = (6, 15000, 1.3), B = 0, free space.

## Verdict

**Reproduced, type-C, to within 1.3 % on every published anchor.** The config
that had been sitting here unrun since `9c0e54f0` would not have produced it:
five independent defects, listed below, two of which cancelled in the one
number a reader would have checked.

| Fig. 2(a) anchor | ours (96³) | paper | dev |
|---|---|---|---|
| peak ρ/N | 0.516 μm⁻³ | 0.509 | **+1.3 %** |
| torus radius r_peak | 0.817 μm | 0.815 | **+0.2 %** |
| FWHM inner edge | 0.527 μm | 0.528 | **−0.2 %** |
| FWHM outer edge | 1.106 μm | 1.109 | **−0.3 %** |
| ρ(r=0)/N | 0.007 | 0.011 | hole, both |

Paper values are digitised from Fig. 2(a) by `g3_digitise_fig2a.py`. That
extractor refuses to report until its **positive control** — the F=1 N=15000
curve — reproduces the *independent* Fig. 1(c) panel of the same paper (it gives
2.955 at r = 0.286 μm against 2.97 at 0.29, i.e. 0.5 % and 1.4 %), and until a
colour not present in the figure returns no curve.

Producing commit: `9924e181` (dirty tree; the config and the winding detector in
this branch). Normalisation: the paper's own, ρ/N in μm⁻³ against r in μm, with
`a_ho = 0.78029 μm` from ω_ref = 2π·110 Hz.

### Supporting measurements

* **Per-component winding is v_m = −m for all 13 components** (m = +6 … −6),
  measured per component at r = r_peak, each with the detector's own
  convergence flag. This is Fig. 1(b) — which shows m=+1 winding −2π, m=0 flat,
  m=−1 winding +2π — generalised to F = 6.
* **|f|/ρ = 5.998 against F = 6** at the density peak, with the in-plane
  fraction 1.0000: fully polarised and purely azimuthal. That is the
  assumption Eq. (1) of the paper rests on, so it is checked rather than
  assumed.
* **Flux-closure identity**: E_ddi/E_s = −1.2970 against −ε_dd = −1.3000
  (0.23 %). For a divergence-free fully polarised magnetisation this is exact,
  so it is the sharpest available gate on the DDI prefactor and the ε_dd
  bookkeeping *simultaneously*.
* **J_z = L_z + F_z = 0** to 1e-6, as the paper's B = 0 state requires.
* **Self-bound inside the box**: edge density is 1e-4 of the peak.
* Norm ∫|ψ|²dV = 1.00000000.

### Energy budget

| term | value (per particle) | share of Σ\|E_term\| |
|---|---|---|
| kinetic | +3.749 | 4.0 % |
| contact | +36.951 | 39.2 % |
| DDI | −47.926 | 50.8 % |
| LHY | +5.650 | 6.0 % |
| **total** | **−1.575** | — |

The campaign guard disqualifies runs whose LHY exceeds 15 % **of the total**;
here that ratio is 359 %, because the total is a small residue of large
cancelling terms. Quoted against the gross budget it is 6.0 %. Neither number is
a pass — a droplet is an LHY-stabilised object and is expected to sit here — so
both are stated rather than one being chosen.

The cancellation ratio R = |E_total|/Σ|E_term| = **0.0167**, inside the band
where `find_ground_state`'s advisory fires and the imaginary-time fixed point is
set by dt rather than by the Hamiltonian. This is why `method: lbfgs`.

### Convergence in grid and in box

| cell | dx | E | peak ρ/N | r_peak | edge/peak |
|---|---|---|---|---|---|
| 64³ box 6 | 0.0732 μm | −1.5754124 | 0.513 | 0.812 μm | 1.0e-4 |
| 96³ box 6 | 0.0488 μm | −1.5754124 | 0.516 | 0.817 μm | 9.4e-5 |
| 88³ box 8 | 0.0709 μm | −1.5754118 | 0.513 | 0.825 μm | 2.7e-7 |
| **128³ box 6** | **0.0366 μm** | **−1.5754124** | **0.516** | **0.819 μm** | **8.8e-5** |

Energy is identical to 7 digits across a **2.0× refinement in dx** and a 1.33×
enlargement of the box at fixed resolution; the radius moves 1.6 % over all four.
The 88³ box-8 cell is the box test proper — the box grows while dx does not —
and its edge density is 2.7e-7 of the peak, so the object is self-bound rather
than held by the periodic boundary.

The 128³ cell was added 2026-08-22 (#376) and is the flat fourth point it was
expected to be: same energy to 7 digits, peak ρ/N and r_peak inside the spread
the other three already showed. It also re-checks the two structural facts at
the finest grid — every one of the 13 components winds with **v_m = −m** at
r_peak, and **J_z = L_z = F_z = 0** — so flux closure is not a coarse-grid
artefact. Against the published profile it sits at peak ρ/N +1.5 %, r_peak
+0.5 %, FWHM_hi 0.0 %.

**WHERE THIS STOPPED, stated rather than implied.** dx = 0.0366 μm. The paper's
grid is ≈ 0.01 μm, which at box 6 a_ho would need n ≈ 468 — not run and not
planned. So this is a four-point convergence line down to **3.7× coarser than
the paper**, and the phrase "converged" is not claimed at the paper's spacing.
The F = 6 object is ~3× the size of the F = 1 one, which is the reason to expect
the coarser grid to suffice, and that is an expectation, not a measurement.

Every cell reaches the L-BFGS energy-comparison floor at |∇E| ≈ 3e-6 and so
reports `converged=false`. That flag means "tol=1e-9 was below what the method
can resolve", not "unconverged"; the driver's own warning says exactly that.

**A convergence scan is not by itself evidence here.** In this regime an ITP
answer is grid-independent to 0.4 % and box-independent to 2 % while being 44 %
wrong, so the scan certifies whatever the solver settled on. The load-bearing
checks are the ones that do not depend on the solver: the flux-closure identity
(0.23 %) and the agreement with the published profile.

### Bistability at B = 0 — the cigar seed falls into the torus

`cells/cigar_n96_box6.yaml` seeds `m_plus_F`: spin uniformly along z, no
winding, the Fig. 3(a) branch. It descends from E = +53.07 through +0.68 and
converges at **E = −1.5754125** — the torus energy, and all four energy terms
agree with the torus cell to 6 digits.

That is not a coincidental degeneracy. At B = 0 with c₁ = 0 the Hamiltonian is
invariant under *simultaneous* space+spin rotation, so the converged droplet may
sit anywhere in an SO(3)-degenerate family, and the **sorted eigenvalues of the
second-moment tensor** are what identify the object (the axis does not):

| cell | sorted ⟨r_a r_b⟩ | symmetry axis | COM |
|---|---|---|---|
| torus 96³ | [0.10383, 0.69018, 0.69018] | (0, 0, 1) | (0, 0, 0) |
| cigar 96³ | [0.10398, 0.69016, 0.69018] | (0.707, −0.707, 0) | (−0.65, −0.66, −0.01) |

Same object, axis rotated into the xy-plane and the centre of mass drifted
(free space is translation-invariant). Profiled about *its own* axis the cigar
cell reproduces the paper as well as the torus cell does: peak 0.515 (+1.2 %),
r_peak 0.828 (+1.6 %), identical FWHM.

**So at B = 0, on this cell, there is no cigar branch** — the uniform seed is
unstable and relaxes into the magnetic vortex. That is consistent with Fig. 3(b),
where the cigar becomes unstable *below* a critical field and the bistability
window is B_z ≃ 0.03–0.17 mG. It is not a reproduction of Fig. 3, which is
published at F = 1, ε_dd = 1.2.

Two measurement traps this cell walked into, both fixed in `g6_measure.jl`
rather than worked around:

* profiling on a fixed z = 0 slice reported the rotated droplet as a centre-peaked
  blob at r = 0.029 μm with ρ(0)/N = 0.482 — a completely wrong state. The
  profile is now taken about the *measured* axis;
* `v_m = −m` is a statement in the basis quantised **along the torus axis**. For
  a tilted cell the components mix and the z-basis windings are not −m. The
  report now says so instead of counting 13 disagreements.

## What was wrong with the config

The file had never been executed. `find runs/saito_li_torus -type f` returned
the config alone, and it had been carried across two schema epochs.

1. **`c_dd: 152` double-counted ε_dd.** ε_dd ≡ a_dd/a_s, and a_dd is fixed by
   the atom (μ = 6.977 μ_B ⇒ a_dd = 59.43 a₀). The paper reaches ε_dd > 1 by
   assuming a *smaller a_s*, so exactly one knob moves. Scaling c_dd as well
   multiplies the ratio a second time by 2.407.
2. **The step-level `interactions:` block silently dropped the mixin's
   `c_total: 583`.** `use:` layering is shallow (`_apply_step_mixins`): a
   step-level block replaces the mixin's wholesale. Resolved, `c_total` read
   back absent, so the run would have used the registry-derived 1406.
3. **(1) and (2) cancelled.** 152·36/(3·1406) = 1.297 ≈ 1.3 — the right ratio,
   reached at 2.4× the paper's absolute interaction scale (a_s = 110 a₀ rather
   than 45.71 a₀). The one number a reader would have checked was right, and
   the system was not the paper's.
4. **The scalar LHY coefficient did not follow either override.** It
   auto-derives from the registry a_s *and* the registry ε_dd = 0.5402,
   giving c_lhy = 972.56 where 2473.56 would have been consistent with the rest
   of that Hamiltonian — 0.39× — while the correct run needs 276.28. LHY is what
   stabilises a droplet, so this is not a peripheral error.
5. **`polar_core_vortex` is the wrong topology.** Its outer region is
   (|+F⟩e^{iφ} + |−F⟩e^{−iφ})/√2, which has ⟨F⟩ = 0 — an unmagnetised
   polar-core vortex, carrying no magnetic vortex, and violating the
   fully-polarised premise of Eq. (1). The paper's state is
   √ρ·e^{−iS_zφ}·ζ^(y): `spin_coherent` with θ=π/2, φ-offset=π/2, charge 1.
6. **`box: [3,3,3]` cut the droplet in half.** `box_size` is the FULL width
   (`grid.jl`: `dx = box_size/n_points`), so 3 a_ho is a half-width of 1.17 μm
   against a cloud that reaches 1.4 μm.
7. **ITP at dt = 5e-3 is the known droplet-regime trap** — see the R = 0.0167
   above.

The trap that made this hard to see: item 3. A config can be wrong in two
places and right in the ratio those two places determine.

## Two defects fixed in `src/` rather than here

* `_resolve_derived_params!` printed the run banner's `c_total` and `ε_dd`
  recomputed from the registry, unconditionally — so a run that *correctly*
  honoured `c_total: 584.37` announced `c_total=1406.2 ε_dd=0.5402`. The
  banner is what a reader checks a config against. It now reports the honoured
  value and the effective ε_dd, naming the registry value alongside.
* `component_phase_winding` (new, `src/analysis/topology.jl`). Neither existing
  detector can read a spin-F magnetic vortex: `winding_number_field` resolves
  at most ±1 per plaquette, and `non_abelian_holonomy` returns `cis(phase_acc)`,
  which is ≈1 for *every* integer winding. The new one refuses rather than
  guessing when under-sampled — required, because an under-sampled loop returns
  `ℓ − n·round(ℓ/n)`, a clean and plausible wrong integer.
  Gated by `test/analysis/test_component_phase_winding.jl` (fast tier).

## Reproducing

Run-output directories are not tracked in this repo (no content-addressed run
dir is), so the `runs/torus_n96_box6_<hash>/` names quoted above do not resolve
from a fresh checkout. What IS tracked is `cells/`, and `run_yaml` keys the
output directory on the raw bytes of the config — so the same file reproduces
the same directory name:

```bash
julia --project=. runs/saito_li_torus/g5_make_cells.jl        # regenerate cells from config.yaml
julia --project=. -e 'import CUDA; using SpinorBEC; run_yaml("runs/saito_li_torus/cells/torus_n96_box6.yaml")'
julia --project=. runs/saito_li_torus/g6_measure.jl runs/torus_n96_box6_3014e1e20ffcd4d9
```

Start with `smoke.yaml` (32³, ~1 min) before anything larger.

## Files

| file | what |
|---|---|
| `config.yaml` | the production cell, 128³ box 6 |
| `smoke.yaml` | 32³, 25 iterations — every code path, ~1 min |
| `cells/` | convergence + bistability cells, generated from `config.yaml` |
| `g1_units_and_premises.jl` | gate 1: every asserted number recomputed |
| `g2_resolved_coefficients.jl` | what the YAML resolves to, before/after |
| `g3_digitise_fig2a.py` | Fig. 2(a) digitiser with its controls |
| `g4_what_the_solver_built.jl` | what `_parse_gs_interactions` actually returns |
| `g5_make_cells.jl` | cell generator (one physics source of truth) |
| `g6_measure.jl` | the type-C measurement above |

## Not done, and why

* **The field-driven transition (Fig. 3) and the Einstein-de Haas rotation
  (Fig. 4) are published at F = 1, ε_dd = 1.2 — not at this cell.** Running them
  here is an extrapolation beyond the paper, not a reproduction of it, and must
  be labelled that way. The B = 0 half of the bistability question IS answered
  above; anything on the field axis should follow the #335 discipline of naming
  both states by energy at each field, and should expect the ±10 nT class of
  systematic to matter at 0.03–0.17 mG.
* **The 128³ cell did not run.** It was launched, thrashed a GPU that a
  concurrent session had half-allocated, and was killed in favour of the
  bistability and box cells. 64³/96³/88³-box-8 already agree to 7 digits in
  energy, so it would have been a fourth point on a flat line rather than new
  information — but it is absent, not passed.
* The paper's own numerics use dx ≈ 0.01 μm; this cell is 0.049 μm at 96³. The
  F = 6 object is ~3× larger than the F = 1 one the paper's step was chosen for,
  and the 64³→96³ agreement above is the evidence that it is resolved.

---

# 続き: 磁場軸 — Fig. 3（双安定）と Fig. 4（Einstein–de Haas）

上の「Not done, and why」が挙げていた2件。**論文の再現ではなく、論文が
F=1, ε_dd=1.2 で示した構造をこのセル (F=6, N=15000, ε_dd=1.3) へ外挿した
予言**として読むこと。#335 の規律に従い、**各磁場で両状態をエネルギーで
名指し**している。

スクリプトは `h1_`–`h7_`（`g1_`–`g6_` の静的再現に続く番号）。
eGPE は全て L-BFGS、GPU、`grad_norm ≤ 5e-6`。

## 静的セルの独立再現（corroboration）

`h3_cells.jl` は `g5/g6` とは別の driver（自前の seed 構成・箱・observable）
だが、同じ数値に着地する:

| | この driver | `g6_measure.jl`（上） |
|---|---|---|
| ρ_max | 0.5164 ± 0.002 N µm⁻³ | 0.516 |
| r_peak | 0.802–0.816 µm | 0.817 |

さらに `E_ddi/E_s = −1.296956` を厳密値 −1.3 に対して 0.23 % で満たす
（flux closure 恒等式 = ε_dd 帳簿の最も鋭いゲート）。

## 変分理論を2実装で突き合わせ（type B）

`h1_variational_cross_check.jl`。論文の Eqs. (2)–(3), (S2)–(S10) を
**閉形式**（`runs/yls_barnett_f6/a2_variational_stability.jl` の ℓ=0 メンバ）と
**直接求積**（閉形式を使わない Gauss–Legendre）で独立に実装し、
**worst deviation 0.088 %**。論文自身の Fig. S1(a)–(d) と Fig. 2(b)（N_c が
F=1..6 で単調増加）を再現し、陰性対照として ε_dd < 1 では N ≤ 1e6 まで
どこでも束縛しないことを確認。

Supplement の PDF から復元する際の落とし穴2件:
密度は **`r^{2λ}`**（`r^λ` ではない — 規格化の Γ(λ+1)、S4 の F/λ、S10 の
A(λ) が3つとも独立にそれを要求）、S7 の分母は **`√2·π`**（`√(2π)` ではない）。

目標セルの予言: σ_r = 0.5883 a_ho、A = 4.2097、⟨r⟩ = 1.2202 a_ho、
n_peak = 0.52220 N µm⁻³、N_c = 7501（停留点）/ 9189（E<0）⇒ N/N_c = 1.6–2.0。

## Fig. 3 — 双安定と交差磁場

箱ゲート（最外殻ボクセルの規格占有 > 1e-4 で `*** UNUSABLE`）を通ったセルのみ:

| B_z [µG] | トーラス E/N | シガー E/N | 基底状態 |
|---|---|---|---|
| 0 | −1.575563 | （磁気渦に崩れる） | トーラスのみ |
| 3 | −1.575846 | （磁気渦に崩れる） | トーラスのみ |
| **16** | **−1.583638** | −1.539958 | **トーラス**（0.0437 差） |
| **18** | −1.585788 | **−1.715940** | **シガー**（0.1302 差） |
| 30 | −1.604089 | **−2.772653** | シガー（1.1686 差） |
| 50 | −1.654561 | — | トーラス健在（edge 7.2e-5） |
| 70 | 完全偏極して崩壊（edge 22 %） | — | トーラス枝は消えた |

**16 → 18 µG で符号が反転する。交差は内挿ではなく測定。**

```
B_× = 16.50 µG                     (両枝の実測から)
トーラス枝の上部臨界 B_c ∈ (50, 70) µG
```

当てはめは**走らせる前に値を出して4回照合**した（E_torus(16) 予言
−1.583650 対 実測 −1.583638 など、最大 2.5e-3）。

論文の F=1, N=50000 は双安定域 0.03–0.17 mG で交差 0.14 mG。
**F=6 では 1 桁低い磁場で同じ構造が起きる。**

### 偏極枝は箱を3回倍にして初めて確立した

B_z = 30 µG で box_z を 8 → 16 → 32 a_ho:
σ_z が 2.190 → 3.435 → **3.491**、edge が 8.3e-3 → 1.3e-3 → **3.9e-5**。
最後の倍化で σ_z は +1.6 %、E/N は +0.065 % しか動かない。
**1 回目の倍化では発散か収束か判定できない**（σ_z が 1.57 倍動いた）。

### なぜシガーは浅くしか束縛しないか

Zeeman 項は完全偏極では形に依らないので束縛に寄与しない。差し引くと
トーラス −1.5466 に対しシガー **−0.1279**（12 倍浅い）。理由は DDI 異方性:
flux closure では `E_ddi = −ε_dd E_s` が形に依らず厳密だが、z 偏極では
`E_ddi/E_s = −ε_dd f(κ)` で有限の形では必ず `f < 1`（実測 0.9973 vs 0.9589）。
**論文の変分理論は flux closure 前提なのでシガー枝には適用できない。**
別途ガウス+f(κ) で解くと N_c(偏極, ε_dd=1.3) = 17441 > 15000（上界）で、
閾値ぎりぎりという eGPE の結果と整合する。

## Fig. 4 — Einstein–de Haas 回転

論文のプロトコル: 対称軸を **y** に向けた B=0 基底状態を用意し、
B_z を t=0 で on にする。

**一般化 seed のゲートは回転不変性**: B=0 では H が z 軸回転で不変なので、
axis=y の基底状態は axis=z のものと一致しなければならない。

```
axis=y : E/N = −1.57556285   固有値 [0.10382, 0.69013, 0.69013]  軸 = (0,+1,0)
axis=z : E/N = −1.575563     固有値 [0.10382, 0.69013, 0.69013]  軸 = (0,0,+1)
```

エネルギー 8e-8 一致、形は 5 桁一致、軸だけが回っている。

磁場は 15 / 30 µG（論文は F=1 の限界 0.17 mG に対し 0.05 / 0.1 mG。
F=6 の限界は 50–70 µG なので同じ割合。論文の 0.1 mG では物体が壊れる）。

| B_z | 回転角 | 移った角運動量 | corr(f_z,L_z) | max\|J_z\| | edge |
|---|---|---|---|---|---|
| 15 µG | **163.0°** | 0.11720 | **−0.999861** | 5.8e-4 | 1.8e-4 |
| 30 µG | **325.6°** | 0.23450 | **−0.998260** | 3.9e-3 | 7.1e-4 |

28.94 ms、n=64、cube box 6.5 a_ho、J_z(0) = −1.9e-13、norm drift ≤ 1.9e-11。

1. ⟨f_z⟩ が負に、⟨L_z⟩ が**同じ大きさだけ**正に振れる（swing が 5 桁一致）。
2. 対称軸の方位角が実際に z 軸まわりを回る（90° → 253° / 416°）。
3. **磁場に厳密に線形** — 2 倍で移動量ちょうど 2 倍、回転角 2.00 倍。
   トルク則 d⟨J⟩/dt = γ⟨f⟩×B の直接の帰結。
4. 「形を変えずに回る」は近似的: モーメント固有値 e1 の振れは 5.1 %（15 µG）/
   19.1 %（30 µG）。quench が呼吸モードを励起している。論文はこの主張を
   定量化していない。

### dt 収束と J_z 残差

dt を半分にして**粗い側のサンプル時刻で**比較: f_z / L_z / 回転角の差は
**≤ 1.3e-5**（5.79 ms までの回転角は 65.312° で一致）。
逆向きに内挿すると 4.3 % の「差」が出るが、これは疎な側を振動信号に
線形内挿した比較手続きの産物。

**max|J_z| は dt でほぼ動かない**（3.074e-3 → 3.076e-3）ので、
残差は時間積分ではない。edge が 3.9 倍で J_z 残差が 6.7 倍になることから、
**周期箱の ⟨L_z⟩ leak** が第一容疑。帰属の確定は未了。

### 一般化 seed で踏んだ罠

教科書どおり Condon–Shortley の (−1)^{F−m} を入れると、この repo の
`spin_matrices` 規約では磁化が (−n_x, −n_y, +n_z) になる（方位角が π ずれ）。

- **axis=z では隠れる**: θ≡π/2 なので一様反転 = 縮退した逆キラリティ。
- **axis=y では ⟨f̂·φ̂⟩ が 0.000 に落ちる。しかも密度は完璧なトーラスのまま、
  固有値も軸も正しく、エネルギーすら 1e-5 で正解に来る。**

`h2_seed_texture_gate.jl` が **3 軸すべてで循環を測る**。

## 追加ファイル

| file | 内容 | GPU |
|---|---|---|
| `h1_variational_cross_check.jl` | 変分 2 実装の突き合わせ + Fig. 2(b) 陽性対照 | 不要 |
| `h2_seed_texture_gate.jl` | 係数・箱・solver・seed テクスチャ（3 軸）のゲート | 不要 |
| `h3_cells.jl` | eGPE セル（1 プロトコル）+ observable + 箱ゲート | 必要 |
| `h4_shape.jl` | 二次モーメント固有値で torus/cigar を回転不変に判定 | 不要 |
| `h5_ladder_plot.py` | Fig. 3 相当（`out/fig3_ladder.png`） | 不要 |
| `h6_edh.jl` | axis=y GS → B_z quench → J_z 台帳 | 必要 |
| `h7_edh_plot.py` | Fig. 4 相当（`out/fig4_edh.png`） | 不要 |
| `run_field_ladder.sh` `run_bistability_v2.sh` `run_cigar_boxscan.sh` `run_crossing{,2}.sh` `run_edh2.sh` | 各アーム | 必要 |

```bash
julia --project=. runs/saito_li_torus/h1_variational_cross_check.jl   # 0.088 % 一致
julia --project=. runs/saito_li_torus/h2_seed_texture_gate.jl         # ALL CHECKS PASS
bash runs/saito_li_torus/run_field_ladder.sh
bash runs/saito_li_torus/run_crossing.sh && bash runs/saito_li_torus/run_crossing2.sh
bash runs/saito_li_torus/run_edh2.sh
julia --project=. runs/saito_li_torus/h4_shape.jl
python3 runs/saito_li_torus/h5_ladder_plot.py
python3 runs/saito_li_torus/h7_edh_plot.py
```

## この続きでやっていないこと

- EdH の J_z 残差（交換量の 0.5–1.7 %）の帰属確定。dt 非依存までは示した。
- 論文 Fig. 5 の supersolid（surfboard トラップ、F=1, N=4×10⁵）。

---

# 続き2: 論文自身のセル（F=1）と Fig. 5

上は F=6 への外挿だった。**論文が実際に磁場軸を公開しているのは F=1** なので、
そちらを直接回して**再現**に格上げする。原子は registry の
`Eu151_f1_effective` がそのまま Table S1 の F=1（µ = 9/2 µ_B）で、
**a_dd = 24.722 a_B は論文の 24.72 と 0.01 % 一致**。

`h8_f1_sizing.jl` が全セルを事前に見積もる（gate 2）。

## Fig. 3 — 双安定（type C、論文の N=50000, ε_dd=1.2）

論文が出している数値は 2 つ:
**双安定域 0.03–0.17 mG**、**エネルギー交差 0.14 mG**。

共通の箱（5×5×20 a_ho、n=56×56×224）で両 seed を独立収束:

| B_z [mG] | トーラス E/N | edge | シガー E/N | edge | 基底状態 |
|---|---|---|---|---|---|
| 0.020 | −6.952641 | 2.6e-8 | −2.076676 | 4.9e-4 ✗ | トーラス |
| 0.050 | −6.970729 | 2.9e-8 | −3.645339 | 1.7e-4 ✗ | トーラス |
| 0.100 | −7.038167 | 6.0e-8 | −6.382190 | 6.8e-5 | トーラス（0.656） |
| **0.110** | **−7.058034** | 8.2e-8 | −6.937141 | 6.1e-5 | **トーラス（0.121）** |
| **0.120** | −7.080429 | 1.2e-7 | **−7.493610** | 5.4e-5 | **シガー（0.413）** |
| 0.130 | −7.105676 | 2.1e-7 | −8.051365 | 4.9e-5 | シガー |
| 0.140 | −7.134275 | 4.1e-7 | −8.610221 | 4.5e-5 | シガー |
| 0.170 | −7.253932 | 1.5e-5 | −10.292067 | 3.6e-5 | シガー（トーラスは aspect 1.25 に扁平化） |
| 0.180 | トーラス種が**シガーになる**（aspect 0.108, ⟨f_z⟩=−0.982） | | | | トーラス枝消滅 |
| 0.200 | 完全崩壊（edge 50 %） | | −11.979891 | 3.1e-5 | |

**2 つの公開値との比較:**

| | 論文 | 実測 | |
|---|---|---|---|
| トーラス枝の上限 | ~0.17 mG | **(0.170, 0.180) mG** | **刻み幅内で一致** |
| エネルギー交差 | 0.14 mG | **0.108 mG** | **23 % 低い**（箱・格子とも収束済）|

上限は当たり、交差は 20 % 低い。**両方を報告する。**
交差は 0.110 と 0.120 のあいだで符号が反転しており（内挿ではなく測定）、
線形内挿で 0.1123 mG。

#### 横方向格子も収束している — 交差の 23 % 差は解像度ではない

`sigma_x = 0.34 a_ho` に対し wide box の dx = 0.0893 は **3.8 点**しかなく、
論文の dx ≈ 0.013 a_ho より 7 倍粗い。ここが最後の候補だったので詰めた
（`run_cigar_grid.sh`、B_z = 0.120 mG、box_xy = 10）:

| n | dx [a_ho] | σ_x あたりの点数 | E/N | edge |
|---|---|---|---|---|
| 112 | 0.0893 | 3.8 | −7.726500 | 2.564e-8 |
| **160** | **0.0625** | **5.4** | **−7.726500** | 2.560e-8 |
| 224 | 0.0446 | 7.6 | **OOM**（15.9 GiB 超） | — |

**1.43 倍の細分で E は 7 桁不変**（σ_x, σ_z も 5 桁不変、edge だけが
2.564e-8 → 2.560e-8 と動くので別の run であることは確か）。
スペクトル収束なので「点数が少ない」という直感は外れていた。

⇒ **交差 0.108 mG は解像度の産物ではない。**

#### 論文側も digitise した — 差は「シガー枝の束縛エネルギー 1 個」に落ちた

Fig. 3(c) の縦軸は `E / (Nℏ²M⁻¹µm⁻²)`、つまり**この repo が計算している
per-atom の `M E/(Nℏ²)` そのもの**。だから交差磁場だけでなく**曲線全体**を
比較できる（換算は a_ho² = 0.6088471 µm² で割るだけ、×1.64245）。

`h11_digitise_fig3c.py`。較正 3 点（枠の自動検出 / **トーラス枝が −11.5 付近で
平ら**という論文側だけで決まる陽性対照 / パネルに無い色は 0 列という陰性対照）
を通らないと結果を出さない。

```
陽性対照: トーラス 0 < B < 0.10 mG で −11.58 ± 0.35   （論文の描画 ≈ −11.5）
陰性対照: 不在の色は 0 列                              OK
論文の交差（digitise した fit の交点） = 0.1460 mG    （本文の記載 0.14）
```

**digitise が論文自身の 0.14 を再現するので、読み取りは妥当。** その上で:

| | 論文 | こちら | |
|---|---|---|---|
| トーラス枝の水準 | −11.58 ± 0.35 | −11.42 … −11.91 | **一致** |
| シガー枝の傾き | −89.4 /mG | −91.9 /mG | **2.7 %** |
| シガー枝のオフセット | — | **−3.08** paper units | **こちらが深い** |

傾きは Zeeman 項（g_F と f_z で決まる）なので合って当然。**トーラス枝も
合っているので、残る食い違いは「シガー枝が磁場に依らず一定量だけ深い」
1 つだけ。** −3.08 paper units = **−1.875 ℏω_ref/atom**。

閉じるか確かめる:

```
トーラス傾き −7.0/mG、シガー −89.4/mG ⇒ 差が閉じる速さ +82.4/mG
一定オフセット −3.08 は交差を −0.0374 mG 動かす
0.1460 − 0.0374 = 0.1086 mG   対  実測 0.108 mG
```

**交差の 23 % 差は、この 1 個の定数で完全に説明できる。**
「交差が 23 % 低い」は記述として誤りで、正しくは
**「偏極枝の束縛エネルギーが 1.88 ℏω_ref/atom 深く、他は何も食い違っていない」**。

どちらが正しいかはここでは決められない。候補: (a) 完全偏極枝に χ(ε_dd) の
LHY をそのまま当てる扱い、(b) solver（論文自身が「安定線の近くでは虚時間の
収束が遅い」と書いている。こちらは L-BFGS）、(c) 箱。
こちら側は箱（edge 2e-8）と格子（1.43 倍で 7 桁不変）を潰してある。

交差が低い側にずれる候補として最初に疑ったのは**シガー枝の箱**だった。トーラス側は edge ~1e-7 で
完全に箱収束しているが、シガー側は 5–6e-5（ゲートは通るが桁が違う）で、
しかも磁場とともに伸び続けている（σ_z 2.88 → 2.92 over 0.11 → 0.13 mG）。
交差は 2 つのエネルギーの差なので、動いている方の箱を疑うのが筋。

### 箱ゲートは正しく鳴ったが、私は違う軸を広げた

低磁場のシガーセル（0.02/0.05 mG）が edge 4.9e-4/1.7e-4 でゲートに落ちたので
**box_z を 20 → 40 a_ho に倍にした。結果は E_solver が 9 桁まで不変**
（−2.07667649 の両方）**で edge も 4.864e-4 のまま。**

エネルギーが動かず edge も動かないなら、伸ばした分は空だったということ。
σ_x = 0.46 a_ho に対し xy 半箱は 2.5 = 5.4σ で、ガウスなら 1e-13。
つまり **4.9e-4 は xy 方向の広く薄いハローで、細長い形に気を取られて
z を広げたのは誤診**だった。ゲートは正しく「箱が不足」と言っていた。
xy を広げた確認は `run_crossing_box.sh`。

## Fig. 4 — F=1 EdH は**成立しなかった**（報告する）

論文の Fig. 4 セル（F=1, N=15000, ε_dd=1.2, B_z = 0.05 / 0.1 mG）を同じ
プロトコルで回したが、**初期条件が自分のチェックに 3 つとも落ちた**:

```
edge          = 4.6e-4 (box=4.0) / 2.3e-3 (box=6.0)   ゲートは 1e-4
GS grad_norm  = 7.0e-3                                （F=6 は 1.1e-6）
対称軸        = (0.0001, −0.0391, +0.9992) ≈ ẑ        （プロトコルは ŷ）
COM の移動    = 0.76 a_ho                              （F=6 は 6.1e-3）
```

B=0 では向きが厳密に縮退しているので、収束しきらない柔らかい基底状態は
自由に回ってしまう。**軸が z なら B_z を入れてもトルクが立たない**ので、
これは論文のプロトコルを実行できていない。得られた
「336.8° 回転」「corr = −0.9966（0.05 mG）/ −0.787（0.1 mG）」は
**回転角に COM のドリフトが混ざっており、採用しない**。

F=1 のドロップレットは F=6 より小さく（σ_r 0.395 対 0.588 a_ho）
閾値に近い（N/N_c = 1.72 対 1.6–2.0）ので向きのモードが極端に柔らかい。
向きを拘束した基底状態か、もっと収束させた GS が要る。

**F=6 の EdH（上）はこの 3 つをすべて通っている** — COM 6.1e-3、
軸は厳密に ŷ、grad_norm 1.1e-6、edge 1.8e-4/7.1e-4。

### COM を引かない二次モーメントは形を捏造する

この失敗を見つけたのは、`h6_edh.jl` の `moment_axis` が
**⟨r_a r_b⟩ を COM を引かずに**計算していたから。0.76 a_ho ずれた
ドロップレットは 0.649 のモーメントを報告する（形の寄与は 0.055）ので
**扁平なトーラスが「細長いシガー」に見える**。

気づいた手がかりは「**形が違うのにエネルギーが 6 桁一致していた**」こと。
別の形が同じエネルギーを持つことはない。修正後の固有値
[0.05488, 0.14576, 0.14576] は独立に測った z 軸セルの
σ_x=0.38178, σ_z=0.23395（⇒ 0.14576, 0.05473）と一致する。

**F=6 の結果は影響を受けない**: 修正前の固有値が `h4_shape.jl`（COM を引く）
の値と厳密一致していた時点で COM ≈ 0 であり、再測定でも
COM = 5.9e-3 a_ho、回転角 65.31°（修正前と同一）。

## Fig. 5 — 1D supersolid

F=1, N=4×10⁵, ε_dd=1.4, トラップ 2π×(100, 1500, 6000) Hz
（= ω/ω_ref (0.909, 13.64, 54.55)）、n=192×48×48、box (16, 2.4, 1.2) a_ho。

**「基底状態は周期的」はどちらが低いかの主張**なので、単一渦の対照も回す:

| seed | E/N | contrast | 内部ピーク | grad_norm |
|---|---|---|---|---|
| chain n_drop=3 | −63.671376 | 0.5512 | 12 | 6.0e-5 |
| chain n_drop=4 | −63.872139 | 0.3963 | 8 | — |
| chain n_drop=5 | −63.671376 | 0.5512 | 12 | 5.2e-5 |
| **chain n_drop=6** | **−64.044153** | 0.4486 | 10 | 3.3e-5 |
| **single（対照）** | −63.671376 | 0.5512 | 12 | 4.9e-5 |

**単一渦の種からでも周期構造に落ちる**（n_drop=3, 5, single が
エネルギー・contrast・ピーク数まで完全に一致 = 同一状態）。
これが論文の主張そのもの — このトラップでの基底状態は 1 個の大きな
ドロップレットではなく配列。全セルで |f|/(Fρ) = 0.9997–0.9998、
⟨f⟩ = 0（flux closure）、edge ≤ 3.6e-8。

`out/fig5_supersolid.png` に線プロファイル。深い密度の谷ではっきり分かれた
ドロップレット列になっている。

**ただし周期は収束していない**: n_drop=4 と 6 は別の（より低い）状態に
落ちており、最低は n_drop=6 の −64.044。**「generic な種から到達する状態は
基底状態ではない」** ので、周期の確定にはもっと広い種の走査が要る。
ここで言えるのは「変調した状態が単一渦より低い」までで、
論文の言う交互キラリティの周期は**測っていない**。

## J_z 残差 — dt でも格子でもない

3 軸すべて潰した（B_z = 30 µG, t_end=4, F=6）:

| 変えたもの | max\|J_z\| | 回転角 | edge |
|---|---|---|---|
| 基準 n=64, box 6.5 | 3.076e-3 | 65.31° | 5.29e-4 |
| **dt 半分**（2.5e-4） | 3.074e-3 | 65.31° | — |
| **格子** n=84（dx 0.102→0.077） | 3.074e-3 | 65.31° | 4.07e-4 |
| **箱** 8.5（1.31 倍） | 2.890e-3 | 65.24° | 3.99e-4 |

**dt と格子は完全に除外**（0.07 % 以内）。動くのは箱だけで、1.31 倍で −6 %。
これでは弱いので**箱を 2 倍**にした:

| 箱 [a_ho] | dx | max\|J_z\| | 回転角 | edge |
|---|---|---|---|---|
| 6.5 | 0.1016 | 3.076e-3 | 65.31° | 5.29e-4 |
| 8.5 | 0.1012 | 2.890e-3 | 65.24° | 3.99e-4 |
| **13.0** | 0.2031 | **7.052e-4** | 66.06° | 4.46e-4 |

**箱を 2 倍にすると max|J_z| が 4.4 倍下がる**（3.076e-3 → 7.052e-4）。
回転角は 1.1 % しか動かない（65.31 → 66.06）。

⇒ **J_z 残差は周期箱の境界。** dt 非依存・格子非依存で、箱だけが効く。

注意: 2 倍の箱は GPU メモリの都合で n=64 のまま（dx が 2 倍粗い）走らせた。
n=128 は OOM で落ちた（rc=137）。ただし格子非依存は先に示してあり、
**粗い格子はもし影響するなら対称性の破れを増やす方向**なので、
それでも 4.4 倍下がったことは箱効果の下限になっている。

（`h6_edh.jl` の既定の箱 6.5 は静的セル用に決めたもので、quench 中の
呼吸を見込んでいなかった。残差 1.3 % は交換された角運動量に対する比。）

## main の 128³ セル（"Not done" の 2 件目）

main が起動して kill したセルを回した。`g6_measure.jl`（main の計器）で:

```
peak rho/N   0.516 vs 0.509 um^-3   +1.5 %
r_peak       0.819 vs 0.815 um      +0.5 %
FWHM         0.517 / 1.109 vs 0.528 / 1.109 um
rho(r=0)/N   0.007 vs 0.011
v_m = -m     13 成分すべて
edge/peak    8.8e-5      |f|/rho = 5.9979 (F=6)   in-plane 1.0000
二次モーメント [0.10383, 0.69018, 0.69018]   軸 = (0,0,1)   COM = 0
```

main の予想どおり「平らな線の 4 点目」で、96³ の +1.3 % と整合。
二次モーメントは私の `h4_shape.jl` の [0.10382, 0.69013, 0.69013] と
5 桁一致（完全に独立な 2 つの計器）。

## 追加ファイル（続き2）

| file | 内容 | GPU |
|---|---|---|
| `h8_f1_sizing.jl` | 論文 F=1 セルの事前見積もりと Table S1 照合 | 不要 |
| `h9_supersolid.jl` | Fig. 5（chain / single 対照、変調 contrast） | 必要 |
| `h10_fig5_emit.jl` / `h10_fig5_plot.py` | Fig. 5 の線プロファイル | 不要 |
| `run_f1_fig3.sh` `run_f1_refine.sh` `run_crossing_box.sh` | Fig. 3 のラダーと絞り込み | 必要 |
| `run_rest.sh` `run_final.sh` | F=1 EdH・Fig 5・J_z 軸潰し・128³ | 必要 |

---

# 続き3: 残り 3 件の決着

## Fig. 4（F=1）— 向きは厳密回転で解決、大きさは 2 倍ずれる

### 柔らかいゼロモードは「収束させる」のではなく「回避する」

B=0 では向きが**厳密なゼロモード**なので、y 軸に種を置いて緩和させると
柔らかい F=1 ドロップレットは勝手に z へ回ってしまう（前節）。
反復を増やしても箱を広げても直らない — 縮退そのものが原因だから。

代わりに **収束済みの z 軸状態を厳密に 90° 回転**する（`rotate90_x`）:

```
R_x(90°): (x,y,z) → (x,−z,y)   ⇒   ψ'(r) = U ψ(R⁻¹r),  U = exp(−i(π/2)F_x)
```

FFT 格子 x_k = −L/2 + k·dx では −x_k がちょうど x_{n−k} なので、
空間部分は**添字の置換**で厳密（補間なし）。n_y = n_z と box_y = box_z を
assert している。回転後の状態は**反復ではなく対称性によって定常**。

ゲート（合わなければ error を投げる）:

```
E(z 軸)   = −2.0155400944
E(回転後) = −2.0155395944      dev 2.5e-7
軸 = (0.0000, +1.0000, +0.0000) = ŷ 厳密
```

箱は 8.0 a_ho / n=80 で edge 9.3e-5（1e-4 のゲート内）。
COM ドリフトは 0.76 → **0.10 a_ho** に改善。

### 結果 — 構造は合う、大きさは 1.9–2.4 倍

論文 Fig. 4(b) は 0.05 と 0.1 mG の L_z, F_z, F_z+L_z を 0–50 ms で描く。
両者とも振動するので、比べるべきは**過渡のあとの平均**（終端値ではない）。

| B_z | \|f_z\| こちら | \|L_z\| こちら | 論文 \|F_z\| | 比 | max\|J_z\| | edge |
|---|---|---|---|---|---|---|
| 50 µG | 0.03750 ± 0.00073 | 0.03722 ± 0.00075 | ~0.020 | **1.87** | 7.7e-4 | 6.1e-4 |
| 100 µG | 0.09698 ± 0.00420 | 0.09175 ± 0.00431 | ~0.040 | **2.42** | 9.8e-3 | **3.1e-3** ✗ |

**構造は正しい**: ⟨f_z⟩ と ⟨L_z⟩ が同じ大きさで逆向き（50 µG で swing が
0.04384 / 0.04386 と 4 桁一致）、corr = −0.9959、J_z(0) = 1.6e-8、
軸は厳密に ŷ。回転も起きる（337.7° / 779.0°）。

**大きさは 1.9–2.4 倍大きい**。しかも比が磁場とともに増えるので定数倍ではない。
100 µG セルは edge 3.1e-3 で**自分の箱ゲートに落ちている**ので、この点は
採用しない。論文値は印刷パネルからの目視読み取り（±20 % 程度）で、
Fig. 3(c) のように digitise していない — そこは詰めていない。

## Fig. 5 — 変調は再現、交互キラリティは**再現できていない**

種を 1（単一渦）と 3–10 で走査:

| n_drop | E/N | contrast | ピーク |
|---|---|---|---|
| 3, 5, 7, 9, **single** | −63.671376 | 0.5512 | 12 |
| 10 | −63.671619 | 0.5539 | 11 |
| 4 | −63.872139 | 0.3963 | 8 |
| **6** | **−64.044153** | 0.4486 | **10** |
| **8** | −64.041780 | 0.4553 | 10 |

**最低は 10 ピーク状態**（−64.0442）で、独立な 2 つの種（6 と 8）が
2.4e-3 以内に到達するので頑健なアトラクタ。奇数種と単一渦は 12 ピーク状態に
落ちる（種の交互性のパリティが効いている）。

**単一渦の種から変調状態に落ちる**ことは論文の主張どおり。

### しかし交互キラリティは無い

論文の具体的主張は「**交互の**循環」で、これは離散量（符号の列）。
`h12_fig5_chirality.jl` が線密度の極小で分割し、各区画の重心まわりの
⟨f̂·φ̂⟩ を測る。**磁気渦なら ±1。**

```
全 9 セルで min|C| ≤ 0.033、最大でも |C| ≈ 0.74、strictly alternating は 0 件
最低エネルギー（10 ドロップレット）: 符号 −+−++−−+−+  min|C| = 0.033
```

**どの区画も清潔な磁気渦になっていない。** さらに雲の長さは
**x = −2.50 … 2.57 µm（5.1 µm）**で、論文 Fig. 5(b) のパネル（10 µm 幅、
目視で ~9 ドロップレット）の**約半分**。

⇒ **Fig. 5 は「変調した基底状態が単一渦より低い」までしか再現していない。**
論文が描く「交互キラリティの磁気渦列」ではない。区画分割が悪いのか状態が
違うのかを分けるため密度+磁化マップも出した（`out/fig5_map.png`）:
循環のループは見えるが、雲の長さが半分という差は分割の問題では説明できない。

## 3 つの食い違いは同じ向きを向いている

| 比較 | 構造 | 定量 |
|---|---|---|
| Fig. 1(d)/2(a) トーラス（低密度） | ✓ | **ρ_max −1.1 %、r_peak +0.5 %** |
| Fig. 3(c) トーラス枝 | ✓ | **一致**（−11.58 対 −11.42…−11.91） |
| Fig. 3(c) シガー枝（高密度） | ✓ 傾き 2.7 % | **束縛が 1.88 ℏω/atom 深い** |
| Fig. 4 EdH | ✓ corr −0.996 | **磁化応答が 1.9–2.4 倍** |
| Fig. 5 supersolid（高密度） | 部分的 | **雲が半分の長さ、渦が清潔でない** |

**トーラス（この論文の主題）は定量的に合っている。**
合わないのは偏極枝・磁化応答・トラップ中の高密度状態で、
いずれも「こちらの方が強く結合している」向き。単一の原因があるかは
ここでは決められないが、**低密度のトーラスだけが 1 % で合う**という
パターンは記録しておく価値がある。

## 追加ファイル（続き3）

| file | 内容 | GPU |
|---|---|---|
| `h11_digitise_fig3c.py` | 論文 Fig. 3(c) の digitise（較正 3 点） | 不要 |
| `h12_fig5_chirality.jl` | ドロップレットごとの循環（交互か） | 不要 |
| `h13_fig5_map.py` | Fig. 5(b) 相当の密度+磁化マップ | 不要 |
| `h14_fig4_compare.py` | Fig. 4(b) との比較（過渡後の平均） | 不要 |
| `run_last.sh` | F=1 EdH（回転）・Fig 5 種走査・J_z 箱 2 倍 | 必要 |

---

# 続き4: 食い違いを潰しにいく

「シガー枝が 1.88 ℏω/atom 深い」「EdH 磁化応答が ~2 倍」「supersolid が半分の
長さ」— これらの原因候補を一つずつ潰した。**結論から言うと、こちら側の
数値的な原因はすべて排除できたが、真因は特定できていない。**

## 1. Fig. 4(b) も digitise した — 比は 1.75 で、私の目視より小さい

目視で「0.02 と 0.04」と読んで比を 1.87 / 2.42 と書いていたが、
Fig. 3(c) と同じ較正つき digitiser（`h16_digitise_fig4b.py`）にかけると:

```
較正: 論文自身の保存量 F_z + L_z が median |0.0003| / |0.0002| で 0
      不在の色は 0 px
0.05 mG:  F_z = +0.0214   L_z = −0.0210   （等しく逆向き）
0.10 mG:  F_z = +0.0493   L_z = −0.0490
```

**論文自身が 0 に保つ量で縦軸が較正される**のがこのパネルの利点。

| B_z | 論文 \|F_z\| | こちら | 比 |
|---|---|---|---|
| 0.05 mG | 0.0214 | 0.03750 | **1.75** |
| 0.10 mG | 0.0493 | 0.09698 | 1.97（箱ゲート落ち、不採用） |

**箱収束している 0.05 mG で 1.75 倍。** 目視の 2.42 は私の読み取り誤差だった
（0.1 mG の論文値は 0.040 ではなく 0.0493）。

なお quench 後に落ち着く ⟨f_z⟩ は**スピン剛性**（flux-closure 面から傾ける
コスト）で決まる: 回転慣性だけなら f_z = p·I = 0.574 になるはずで、実測
0.0375 はその 1/15。つまり比 1.75 は「こちらのスピン剛性が 1.75 倍柔らかい」
という意味になる。

## 2. DDI 異方性ではない

**仮説**: トーラス（flux closure）は `E_ddi/E_s = −ε_dd` が**形に依らず厳密**
で、これは横方向カーネル k_a k_b が**打ち消える**ケース。シガー（偏極）は
`−ε_dd f(κ)` で、**その横方向カーネルが f(κ) を供給する**。
つまり横方向カーネルの欠陥はトーラスを無傷のままシガーだけを動かす —
観測されたパターンそのもの。

`h15_ddi_anisotropy.jl` で収束状態から直接測った:

```
flux closure セル（|f_z|/F ≈ 0）: E_ddi/E_s = −1.19876…−1.19906 対 厳密 −1.2  (0.08 %)
                                              −1.29655…−1.29702 対 厳密 −1.3  (0.23 %)
偏極セル C1@0.120（|f_z|/F = 0.976, κ = 0.112）:
    実測 E_ddi/E_s = −1.17332   ⇒  f_eff = 0.978
    ガウス閉形式  −ε f(0.112) = −1.11288  ⇒  f = 0.927
```

**差は 5.4 % で、しかも向きが正しい**: f(κ) はガウス用の式で、実際の
ドロップレットは flat-top なので**より円柱に近く、f は 1 に近づく**。
⇒ **横方向カーネルは正常。DDI 異方性は原因ではない。**

## 3. LHY 係数でもない

同じ `c_lhy` を両枝が使っている。もし c_lhy が小さすぎれば両方が過剰束縛
されるはずだが、**トーラスは |E_LHY|/|E_total| = 3.6 と LHY に極めて敏感で、
それでいて論文と 1 % で合う**。⇒ c_lhy は正しい。

## 4. 箱でもない — 横方向も収束した

シガーの箱は 3 軸すべて潰した:

| 変えたもの | E/N の変化 |
|---|---|
| box_z 20 → 40 | **9 桁不変**（−2.07667649 の両方） |
| box_xy 5 → 10 | −0.23（ここは効いた） |
| **box_xy 10 → 16** | **−0.0024**（0.03 %、edge 3.7e-8） |
| 横方向格子 n 112 → 160 | **7 桁不変** |

**box_xy 10 → 16 の変化 0.0024 ℏω は、論文との差 1.875 ℏω の 1/780。**
⇒ 箱は原因ではない。

## 5. 残るもの

こちら側で調べられる数値的原因（箱・格子・dt・DDI 異方性・LHY 係数）は
**すべて排除**した。残る候補は:

- **論文側の収束**。論文自身が「安定線の近くでは虚時間の収束が遅い」と
  書いている（Fig. 2(b) の議論）。こちらは L-BFGS で `grad_norm ≤ 5e-6`。
  #338 の作業では、同じ自由空間ドロップレットで **ITP の不動点が dt でずれ、
  ピーク密度 44 % 誤りながら dpsi = 3e-6 と収束を報告した**実例がある。
- **モデルの差**。どちらの Hamiltonian も同じはずだが、確認していない項が
  あるかもしれない。

**どちらが正しいかは、この作業では決められない。**
ただし「トーラス（低密度・flux closure）は 1 % で合い、偏極枝・磁化応答・
高密度配列だけがずれる」というパターンと、上の排除リストは記録した。

## 追加ファイル（続き4）

| file | 内容 | GPU |
|---|---|---|
| `h15_ddi_anisotropy.jl` | 収束状態の E_ddi/E_s を flux-closure / f(κ) と比較 | 不要 |
| `h16_digitise_fig4b.py` | 論文 Fig. 4(b) の digitise（F_z+L_z=0 で較正） | 不要 |

---

# 続き5: 食い違いは論文側にある — 変分上限で決着

続き4 で「こちら側の数値的原因はすべて排除したが真因は不明」と書いた。
その後、**どちらの eGPE も信用せずに決められる測定**を見つけた。

## 1. まず y 軸の単位を物理で固定した（係数 2 の曖昧さを排除）

「シガー枝が 1.875 ℏω/atom 深い」という主張全体が、Fig. 3(c) の縦軸
`E/(N ℏ² M⁻¹ µm⁻²)` の読み方に乗っている。ところが PDF のテキスト抽出は
これを `E / (Nh 2Mm )` と返す — **ℏ²/(Mµm²) と ℏ²/(2Mµm²) の区別がつかない**。
まさに報告している数字の上に係数 2 が乗る。

高解像度で描画すると `M⁻¹` で 2 は無い。だが**描画したグリフは測定ではない**。
そこで物理でアンカーした（`h17_zeeman_slope_anchor.jl`）:

シガー枝は完全偏極なので、**その B 依存の傾きは線形 Zeeman そのもの**で、
ドロップレットも DDI も LHY も収束も入らない:

```
原子定数から (Units.bfield_to_p_gauss 経由)   -94.04 paper units/mG
論文、digitise                                -89.40   (+4.9 %)
こちら、実測                                  -91.90   (+2.3 %)

陰性対照: 軸が ℏ²/(2Mµm²) なら傾きは -188.08 ⇒ digitise 値を 110 % 外す
```

⇒ **軸は ℏ²/(Mµm²)。1 paper unit = 0.60885 ℏω_ref、−3.08 paper units =
1.875 ℏω_ref/atom で確定。** 縦軸の原点も目盛（上から 0, −5, −10, −15）を
描画して確認した。

## 2. DDI 横方向カーネルを初めて測った — 正常

memory は「flux closure ゲートは横方向カーネルを**測っていない**」と警告して
いた（k·M_k = 0 がその項を厳密に消すので、原理的に測れない）。
偏極ガウシアンなら閉形式 `E_ddi/E_s = −ε_dd f(κ)` が使え、しかも f は
**定数でなく関数**なので、どんな一律スケールでも吸収できない。
`h19_ddi_fkappa_oracle.jl`:

| κ | 基準 5幅/128 | 箱 8幅/128 | 格子 5幅/192 |
|---|---|---|---|
| 1.000 | 0.000 | 0.000 | 0.000 |
| 0.500 | −0.000 | −0.000 | −0.000 |
| 0.200 | −0.138 | **−0.001** | −0.138 |
| 0.112 | −0.853 | **−0.080** | −0.853 |
| 0.070 | −1.613 | **−0.321** | −1.613 |

（単位 %。κ=1 の f=0 は「球は c_dd がいくら大きくても双極子エネルギー 0」
という最も鋭い点。）

**ずれは箱を広げると消え、格子を細かくしても 1 桁も動かない。**
⇒ カーネルは正常（κ=0.5 で 6 桁一致）。ずれは**双極子場の打ち切り**。

### 運用上の教訓（これは一般に効く）

基準の箱で**端の密度は 5e-12** — 端密度ゲートでは完全に収束している —
のに κ=0.112 で双極子エネルギーが 0.9 % 誤る。
**双極子場は密度が死んだ先まで届くので、端密度ゲートは DDI の箱を保証しない。**
本番のシガーセルは box_xy=10 a_ho に対し a≈0.34 なので半幅 14.7 幅 ⇒ 問題なし
（続き4 の box_xy 10→16 で 0.03 % しか動かなかったことと整合）。

これで続き4 の h15 の読み（偏極セルの f_eff=0.978 対 ガウス 0.927 の 5.4 %
超過は flat-top であってカーネル欠陥ではない）も、初めてきちんと裏付けられた。

## 3. 決着: 論文のシガー枝は自分の汎関数の最小値ではない

**試行波動関数は厳密な上限を与える。** そこで論文自身の汎関数を偏極
ガウシアンで評価し、2 つの幅について最小化した（`h18_cigar_variational_bound.jl`）。
汎関数は**2 通りに独立に書いて**照合した:

- **(A)** 論文の式から直に導いた閉形式（レポの場のコードを一切通らない）
- **(B)** 同じガウシアンに production の `energy_decomposition`

```
(A) a = 0.394, b = 5.615 a_ho (κ=0.070)
    kin +3.22618  s +31.94759  ddi -36.99482  lhy +1.93096  zee -8.01604
(B) kin +3.22618  s +31.94759  ddi -36.87690  lhy +1.93096  zee -8.01604
```

**運動・接触・LHY・Zeeman は 6 桁一致**。差は DDI のみで、しかも §2 の箱効果
（κ=0.070 は 8 幅でも 0.3 % 残る）。**2 つのうち束縛の緩い方**を上限に採るので、
どちらが正確かに結論は依存しない。

**判定は 1 点ではなく枝全体で出す。** 開いた四角のマーカーを 1 点読むと
digitise の散らばり（残差 rms **0.674**）が効果の半分を占めてしまうので、
論文側は 1473 列の**フィット直線**を使う。ガウシアンは完全偏極なので内部
エネルギーが B に依らず、上限は `E_int + p(B)·F` で枝全体に伸びる:

| B_z/mG | 変分上限 | 論文フィット | こちら | 差 |
|---|---|---|---|---|
| 0.110 | −9.969 | −8.899 | −11.77 | **+1.070** |
| 0.120 | −10.910 | −9.794 | −12.69 | **+1.116** |
| 0.130 | −11.850 | −10.688 | — | +1.162 |
| 0.140 | −12.790 | −11.583 | −14.53 | **+1.208** |
| 0.160 | −14.671 | −13.372 | — | +1.300 |
| 0.180 | −16.552 | −15.160 | — | +1.392 |
| 0.200 | −18.433 | −16.949 | — | +1.484 |

**論文のシガー枝は、描かれている全ての磁場で変分上限より上**（1.07–1.48、
digitise の散らばり 0.674 より大きい）。試行関数は収束した基底状態を
上回れない。
⇒ **論文の Fig. 3(c) のシガー枝は、論文自身が書き下した汎関数の最小値では
ない。** こちらは上限の 1.74 下、収束解のあるべき場所にいる。

なお**この上限は弱い**（ガウシアンは flat-top ドロップレットに対して悪い
ansatz で、実際こちらの eGPE は上限の 1.74 下にいる）。弱い上限を超えている
ことが、かえって強い主張になる。

### 読みやすい形: 束縛エネルギー

完全偏極枝では Zeeman が厳密に定数なので、**フィットの切片がそのまま
B=0 の内部エネルギー**（F_z パネルは要らない）:

```
E_int = E − E_Zeeman   [paper units]
  論文のシガー枝   +0.939   （フィット切片）
  ガウシアン最適   +0.376
  こちらの eGPE    -1.364
  自己束縛には E_int < 0 が必要。満たすのはこちらだけ。
```

ただし切片は 0.05–0.2 mG からの外挿で、傾きの理論値との差 4.9 %
（−89.44 対 −94.04）が切片を ~0.57 動かす ⇒ **正なのは ~1.5σ**。
頑健な主張は上の上限比較のほうで、こちらは読みやすい言い換え。

これで続き4 の排除リストと合わせて食い違いの所在が決まった:

| 候補 | 判定 |
|---|---|
| 箱（3軸）・格子・dt | 排除（続き4） |
| DDI 異方性 / 横方向カーネル | 排除（§2 で初めて実測、6桁） |
| LHY 係数 | 排除（トーラスは LHY 比 3.6 で 1 % 一致） |
| y 軸の単位・原点 | 排除（§1、陰性対照が 110 % 外す） |
| **論文側のシガー枝の収束** | **これ。変分上限を 1.79 上回る** |

論文自身が「安定線の近くでは虚時間の収束が遅い」と書いており、
#338 では同じ自由空間ドロップレットで **ITP の不動点が dt でずれ、ピーク密度
44 % 誤りながら dpsi=3e-6 と収束を報告した**実例を測っている。整合する。

## 4. やろうとして撤回したもの: binding ledger

「E_int = E_total − E_Zeeman < 0 でなければ自己束縛でない」という原点不要の
判定を Fig. 3(c) の F_z パネルからやろうとしたが、**F_z の digitise が
信用できない**（列平均が 2 枝を混ぜる）。較正が捕まえた:

```
torus F_z 小 B = 0.032  (OK)
torus F_z 大 B = 0.263  (上昇はしている)
cigar F_z 平均 = 0.663  ⇒ 論文本文の "almost fully polarized" と矛盾
F_z CALIBRATION FAILED: cigar F_z is not near 1
```

最初の版は小 B のトーラスだけ見て**通した**うえで、トーラス F_z を
0.621 → 0.373 → 0.085（B 上昇に対して**減少**）と出した。
単調性と偏極度のゲートを足して**拒否させた**。この節の結論は使っていない。
§3 の変分上限は F_z を必要としないので影響なし。

## 追加ファイル（続き5）

| file | 内容 | GPU |
|---|---|---|
| `h17_zeeman_slope_anchor.jl` | Fig. 3(c) 縦軸単位を線形 Zeeman 傾きで固定（陰性対照つき） | 不要 |
| `h18_cigar_variational_bound.jl` | 偏極ガウシアン変分上限、汎関数 2 実装で照合 | 不要 |
| `h19_ddi_fkappa_oracle.jl` | DDI 横方向カーネルの f(κ) 差分オラクル | 不要 |
| `h11_digitise_fig3c.py` | +F_z パネル + binding ledger（較正で拒否） | 不要 |

---

# 続き6: EdH の 1.75 倍は箱ではない

続き5 で「双極子場は密度が死んだ先まで届くので端密度ゲートは DDI の箱を
保証しない」と判ったので、EdH の磁化応答が論文の 1.75 倍という食い違いが
箱由来かどうかを**観測量そのもので**直接試した。

## 結果: 箱を 1.5 倍にしても 0.1 % しか動かない

dx = 0.10 a_ho、dt = 2e-4、t_end = 10、`orient=rotate` を固定し、箱だけを変える:

| | mean \|f_z\| (t > 3 ms) | sd | max edge | max\|J_z\| |
|---|---|---|---|---|
| box = 8, n = 80 | **0.03750** | 0.00073 | 6.08e-4 | 7.74e-4 |
| box = 12, n = 120 | **0.03746** | 0.00037 | 3.88e-4 | 6.73e-4 |
| 変化 | **−0.1 %** | | | |

論文 Fig. 4(b)（`h16`、論文自身の保存量 F_z+L_z=0 で較正）は 0.05 mG で
**0.0214**。比はどちらの箱でも **1.75**。
**論文に届くには \|f_z\| が 43 % 落ちる必要があり、実際には 0.1 % しか動かない。**
⇒ **箱は原因ではない。**

箱を広げた側は sd も edge も小さく（より収束しており）、答えは同じ。

## 途中で2回間違えた

**(1) dt のせいにした（誤り）。** 最初のスキャンが max edge 9.2e-2・f_z→−0.40 で
壊れたのを既定 dt=5e-4 のせいだと書いたが、**dt=2e-4 で再現した**ので違った。
真因は `orient=rotate` の渡し忘れ。B=0 では向きが**厳密なゼロモード**なので、
y 軸シードを直接緩和すると

```
本来のトーラス  固有値 [0.055, 0.146, 0.146]  oblate  E/N = -2.0155  自己束縛
落ちた先        固有値 [3.92,  3.92,  5.19 ]  prolate E/N = +0.114   非束縛
```

という**別のベイスン**（約5倍大・非束縛）に落ち、膨張して壁に達する。
`_assert_is_the_torus` を追加して拒否させた（oblate か + 自己束縛か。
**縮退だけでは区別できない** — prolate 側も縮退ペアを持つ）。

**(2) 端フラクションの列を間違えて読んだ。** 「元のランは max edge 3.1e-9 で
健全」と書いたが、`awk` が**6 列目（`Ly`）を読んでいた**。edge は 15 列目で、
実際は **6.08e-4**。つまり元のランも `EDGE_MAX=1e-4` を超えている。
「box=12 のほうが edge が大きい（逆転）」という私の疑問も、この列ミスの産物
だった（実際は 3.88e-4 < 6.08e-4 で、大きい箱のほうが小さいという当然の向き）。

## ゲートを緩めた — 測って決めた値に

**クエンチは輻射する**ので、静的セル用の `EDGE_MAX = 1e-4` はここでは
**きつすぎる**（正しいラン2本が両方とも赤くなる）。memory の
「ゲートで危ないのは緩すぎでなく『きつすぎ』— 正しい仕事で赤くなるゲートは
切られる」に該当する。

`EDGE_MAX_DYNAMICS = 1e-3` は**選んだのではなく測った値**:
箱を 1.5 倍（壁面積 2.25 倍）にしても観測量は 0.1 % しか動かず、その間 edge は
6.08e-4 → 3.88e-4。この水準の輻射は観測量に触っていない。
一方**捕まえ続けねばならない失敗**（非束縛で壁に膨張）は 9.2e-2 で、**2 桁上**。
4 例すべてで確認: 良好2本 ok、prolate 9.2e-2 と canary 1.15e-1 は UNUSABLE。

## 残るもの

| 候補 | 判定 |
|---|---|
| 箱（EdH） | **排除**（1.5 倍で 0.1 %） |
| 格子・dt | 固定して比較（同一） |
| 基底状態が別物 | 排除（固有値・エネルギーとも元のランと一致） |
| **1.75 倍の原因** | **未特定** |

シガー枝のほうは続き5 で決着している（論文側が自分の汎関数の変分上限を
超えている）。EdH の 1.75 倍がそれと同じ原因かは**まだ言えない** —
EdH はトーラス枝の量で、そのトーラスはエネルギーで論文と 1 % 一致している。

## 追加ファイル（続き6）

| file | 内容 | GPU |
|---|---|---|
| `h6_edh.jl` | `_assert_is_the_torus` ゲート + `EDGE_MAX_DYNAMICS` + banner をセルから導出 + タグに box | 必要 |
