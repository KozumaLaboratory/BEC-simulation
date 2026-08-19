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

Energy is identical to 7 digits across a 1.5× refinement in dx **and** a 1.33×
enlargement of the box at fixed resolution; the radius moves 1.6 % over both.
The 88³ box-8 cell is the box test proper — the box grows while dx does not —
and its edge density is 2.7e-7 of the peak, so the object is self-bound rather
than held by the periodic boundary.

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
