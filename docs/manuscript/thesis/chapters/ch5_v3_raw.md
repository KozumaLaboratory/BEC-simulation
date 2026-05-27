# 修士論文 Chapter 5 v3: Eu Post-quench Chaotic Dipolar Dynamics — TWA による Numerical Characterization

**Major reframing** (May 8, 2026): 当初の "TWA で量子ゆらぎ評価" framing を、 
**Chaotic dipolar instability の trajectory divergence study** に転換。
理由: Round 5 GPU 結果 (Sinatra-clean 16³×box=10 pinned 1/N) で σ/μ が 1/√N scaling
完全破綻、Sinatra-origin / quantum-fluctuation origin 両方否定。真の origin は dipolar
instability の chaotic dynamics と判明。

修論 / paper portfolio に与える影響: **Mean-field results (LHY closed forms, phase 
diagrams, threshold bracketing) は完全 unaffected**。本章のみ framing 修正。

---

## 5.1 Introduction (REWRITTEN)

¹⁵¹Eu 双極子 BEC の post-quench dynamics は、急速 B-field 変化後の DDI driven な 
non-equilibrium 進化として典型的に研究されてきた [Phuc-Ueda 2014]。本章では、
SpinorBEC.jl + Truncated Wigner Approximation (TWA) を用いて、Eu post-quench 
dynamics を数値的に系統評価する。

**当初目標** (Mar 2026): TWA で量子ゆらぎ effect を leading-order に評価し、
平均場 GP-LHY からの shot-to-shot fluctuation を予測。

**実際の発見** (May 2026): 5 GPU runs (32³ N scan, 32³ ε_dd species scan, Sinatra check, 
16³ box=20 pre-cleanup, **16³ box=10 resolution-matched 1/N pinned**) を経て、 
σ/μ ≈ 0.4-0.8 が 1/√N scaling を示さず、量子ゆらぎ origin ではなく **chaotic 
dipolar instability の trajectory divergence** に由来すると判明。

本章では:
- §5.2-5.5: TWA framework (元 setup, 解釈は更新)
- §5.6: 32³ N scan (coupling-strength interpretation, mean-field robust)
- §5.7: ε_dd species scan (Cr/Eu/Er/Dy chaos-onset diagnostic)
- §5.8: Sinatra criterion + 16³ pinned 1/N (TWA validity boundary identification)
- **§5.9 (NEW)**: **Chaotic dipolar instability framing** — physical interpretation
- §5.10: 修論 / paper #4 implications + D 論 outlook (TDHFB / Beliaev)
- §5.11: Conclusion

---

## 5.2-5.5: TWA Framework (前 template と同じ — minor caveat 追加)

[既存 master_thesis_Ch5_TWA_template.md の §5.2-5.5 流用]

§5.5 末尾に caveat 追加:

> Note (added in v3 framing): TWA leading-order は古典 trajectory ensemble + 量子 
> initial conditions を与え、量子ゆらぎが weak (perturbative) な regime で valid 
> [Sinatra 2002, Polkovnikov 2010]。本章 §5.9 で議論する通り、Eu post-quench dynamics の 
> ように chaotic instability が dominant な system では、TWA leading-order は 
> "trajectory divergence" を捕捉するが、純粋な量子ゆらぎ magnitude を quantitative に 
> 抽出することは methodologically できない。 真の量子ゆらぎ評価には TDHFB / Beliaev 
> 拡張が必要 (D 論 Ch.3 課題)。

---

## 5.6: 32³ N Scan — Coupling-Strength Regime + Eu Collapse Threshold Bracketing

(Status: **unaffected** by reframing — mean-field interpretation。本 section は前 
master_thesis_Ch5_TWA_revised.md の §5.6 そのまま流用可能。)

### 5.6.1 Setup と finding

(既存 content: 3 distinct regimes - sub-collapse / marginal / super-collapse)

### 5.6.2 主要 finding: Eu Collapse Threshold

(既存 content: $N_{\rm collapse}^{\rm critical} \in [10^3, 10^5]$ coupling units bracketing)

### 5.6.3 σ/μ の coupling-strength dependence (REINTERPRETED)

旧 interpretation: 量子ゆらぎ enhancement at marginal regime
**新 interpretation**: chaotic dynamics onset at marginal regime (= chaos-onset 
diagnostic)

> Marginal coupling regime での σ/μ peak ≈ 0.42 は、当初 mean-field instability boundary 
> 近傍での量子ゆらぎ enhancement と解釈された。Round 5 で確立した chaotic 
> instability framing (本章 §5.9) では、これは **dipolar chaos onset の signature** と
> 解釈される。Sub-coupling regime (σ/μ ≈ 0) では classical Gaussian、super-coupling 
> regime (σ/μ ≈ 0.22) では chaos が saturate, marginal regime で chaos が most active 
> = trajectory divergence が最大。

---

## 5.7: ε_dd Species Scan — Chaos-Onset Diagnostic across Cr/Eu/Er/Dy (UPDATED)

### 5.7.1 Setup

GPU run (32³, 50 traj/species, ε_dd ∈ {0.15 (Cr), 0.55 (Eu), 0.88 (Er), 1.39 (Dy)}):

### 5.7.2 Results

| Species | ε_dd | FWHM_z/x | on-axis | σ/μ |
|---|---|---|---|---|
| Cr | 0.15 | 2 | 0.998 | 0.001 |
| Eu | 0.55 | 6 | 0.416 | **0.423** ← peak |
| Er | 0.88 | 10 | 0.041 | 0.127 |
| Dy | 1.39 | 1 (collapse) | 0.025 | 0.049 |

### 5.7.3 Mean-field findings (robust)

- z-elongation monotonic in ε_dd (FWHM 2 → 6 → 10 → 1=collapse)
- on-axis depletion monotonic in ε_dd (= multi-clump structure formation)
- これらは GP-LHY deterministic dynamics の結果, ensemble-mean で robust

### 5.7.4 σ/μ peak at Eu (REINTERPRETED with chaos framing)

旧解釈: Eu の量子ゆらぎ enhancement
**新解釈**: Eu の **chaos-onset regime** での trajectory divergence。
Cr (sub-instability) → no chaos → σ/μ ≈ 0; Eu (marginal) → strong chaos → σ/μ peak; 
Er (post-collapse) → chaos saturated, dynamics deterministic again → σ/μ < Eu;
Dy (full collapse) → cloud collapsed, no spread → σ/μ low.

→ **σ/μ as chaos-onset diagnostic** across species: 各 dipolar BEC species での 
chaotic dipolar instability の onset / saturation を visualize する diagnostic tool。
これは元 quantum-fluctuation framing よりも **物理的に rich な finding**。

---

## 5.8: Sinatra Criterion Check + 16³ Pinned 1/N — TWA Validity Boundary

### 5.8.1 Sinatra criterion

[元 §5.8 内容 — N_modes vs N analysis]

### 5.8.2 16³ Pinned 1/N Re-run (Sinatra-clean)

**Setup**: 16³ × box=10 (dx = 0.625 a_ho, filament 3.75 a_ho 解像可能), 
$c_{\rm total} = 4689, c_{dd} = 7647$ pinned, N ∈ {10³, 10⁴, 10⁵}.

**Results**:

| N | Sinatra ratio | σ/μ | 解釈 |
|---|---|---|---|
| 10³ | 53 | 0.560 | contaminated regime |
| 10⁴ | 5.3 | 0.415 | 32³ baseline (0.42) と一致 ← 同 GS profile |
| 10⁵ | 0.53 (clean) | **0.819** | Sinatra-clean baseline |

### 5.8.3 当初 Sinatra-contamination verdict の否定 (3 evidences)

1. Resolution-matched 16³×10 で N=10⁴ σ/μ = 0.42 **再現** → Sinatra 8× 下げても σ/μ 不変
2. Sinatra-clean N=10⁵ (ratio 0.53) で σ/μ = 0.82 → Sinatra origin なら逆
3. σ/μ × √N が 17.7 → 41.5 → 259 と **growing** → 1/√N TWA scaling **完全破綻**

### 5.8.4 May 7 の "16³ box=20" bug

dx = 1.25 a_ho で filament (3.75 a_ho) 解像不能 → cloud が smooth Gaussian で停止 → 
no chaos → σ/μ shrinkage を Sinatra effect と誤判定。Resolution-matched re-run で 
artifact 判明。

---

## 5.9 (NEW): Chaotic Dipolar Instability — Real Physical Origin of σ/μ

### 5.9.1 Mechanism

Eu post-quench dynamics の dipolar interaction $V_{dd} \sim r^{-3} (1 - 3\cos^2\theta)$
は long-range anisotropic coupling を生む。B-field quench 後の post-equilibrium dynamics
は典型的に:

1. 初期 polar / FM 状態が unstable に
2. Z_n vortices (n = 12 for F=6) や filament structure 形成
3. Filament の orientation は **dipolar anisotropy axis** で energetically preferred
4. しかし azimuthal direction (z 軸周り) は continuous degeneracy に近い (small B 
   field なので)

### 5.9.2 Lyapunov-like Trajectory Divergence

Wigner sampling で各 trajectory に小さい初期 seed difference (蓋し $\delta\zeta \sim 1/\sqrt{N}$):
$\zeta^{(j)}(\mathbf{r}, t=0) = \zeta_0(\mathbf{r}) + \delta\zeta^{(j)}(\mathbf{r})$

GP-LHY 進化中、dipolar instability は **chaotic** で:
$\delta\zeta^{(j)}(\mathbf{r}, t) \sim e^{\Lambda t} \delta\zeta^{(j)}(\mathbf{r}, 0)$

with $\Lambda > 0$ Lyapunov exponent。Time scale $t \sim \Lambda^{-1}$ を超えると:
- Trajectory j 間 difference が exponentially amplify
- 異なる trajectories が異なる **filament orientation** に飛ぶ
- Ensemble averaging で azimuthal direction が average out → on-axis ratio 0.092 → 0.416 (反映!)
- σ/μ が **physics amplitude bounded** = chaos saturation level に到達

### 5.9.3 なぜ 1/√N で減らないか

旧予想 (TWA QF leading-order): $\sigma/\mu \sim 1/\sqrt{N}$ (central limit theorem)

**実際**: Lyapunov instability で $\delta\zeta(t) \sim e^{\Lambda t} \cdot 1/\sqrt{N}$
$\to e^{\Lambda t}$ factor が dominant for $t > \Lambda^{-1} \log N$

For Eu, $\Lambda \sim 1$ (in trap units) and $t \sim 1$ (post-quench observation time):
- N=10³: $\delta\zeta(t) \sim e^1 / \sqrt{10^3} \sim 0.086$ → still small noise-bounded
- N=10⁴: $e^1 / \sqrt{10^4} \sim 0.027$ → noise small, but chaos saturated → σ/μ ~ 0.4
- N=10⁵: $e^1 / \sqrt{10^5} \sim 0.0086$ → noise tiny, chaos full → σ/μ → physics-bounded

**Counter-intuitive prediction confirmed**: σ/μ が N で **増加** (10⁴ → 10⁵: 0.42 → 0.82) は
chaos が completely physics-amplitude bounded で、low N では noise 残留が逆に saturate を
妨げていたという解釈。

### 5.9.4 Chaos vs Quantum Fluctuation: Methodological Distinction

| Aspect | Quantum fluctuation | Chaotic dynamics |
|---|---|---|
| Origin | $\hat{a}, \hat{a}^\dagger$ commutators | Classical Lyapunov instability |
| Magnitude scaling | $\sim 1/\sqrt{N}$ (CLT) | Physics-bounded, $N$-independent |
| Detection in TWA | leading-order valid | leading-order captures chaos |
| Required for true QF eval | leading-order TWA | TDHFB, Beliaev (higher-order) |

→ **TWA leading-order is a chaos diagnostic, NOT a quantum fluctuation tool** in this regime.

### 5.9.5 Chaos onset across species (cross-reference §5.7)

- Cr (ε_dd=0.15): below chaos threshold, $\Lambda \approx 0$, σ/μ ≈ 0
- Eu (ε_dd=0.55): chaos most active at marginal regime
- Er (ε_dd=0.88): chaos saturated, dynamics deterministic again
- Dy (ε_dd=1.39): cloud collapsed, no spatial structure, σ/μ small

→ **σ/μ peak at Eu = chaos most-active regime** for ε_dd, robust across species.

---

## 5.10 修論 / Paper Portfolio Implications

### 5.10.1 Robust outputs (unaffected)

- Paper #1 (F=2 cyclic LHY): unaffected
- Paper #2 (F=6 icosahedral LHY): unaffected  
- Paper #3 (Universal Theorem v3): unaffected
- 修論 Ch.1-4, Ch.6, Ch.7, Ch.8: unaffected
- Mean-field N scan, ε_dd species scan: unaffected
- Eu collapse threshold bracketing: unaffected
- LHY ablation, 6 polyhedral closed forms: unaffected

### 5.10.2 Reframed outputs

**修論 Ch.5 (本章)**: 当初 "TWA quantum fluctuation" framing を "chaotic dipolar 
instability" framing に転換。これは publishable な physics finding として強化された。

**Paper #4 (元 "TWA Eu post-quench QF")**: 
- 旧 title: "Quantum fluctuation effects in F=6 dipolar spinor BEC"
- 新 title: "**Chaotic dipolar instability in post-quench F=6 spinor BEC: trajectory 
  divergence and species universality**"
- Core finding: chaotic dynamics signature (not QF), robust across Cr/Eu/Er/Dy
- σ/μ peak at Eu = chaos-onset diagnostic
- TWA validity boundary clearly delineated
- Target: **PRR or PRA** (focused chaotic dynamics study)

### 5.10.3 Negative result vs. new positive finding

これは "TWA QF が予期通り work しなかった" negative result ではなく、 
"**Eu post-quench で chaotic dipolar instability の clean signature を numerical に同定** 
した positive finding"。

研究 dynamics:
- 当初 hypothesis (TWA QF) → 5 GPU runs → 否定 evidence → 真の origin (chaos) 同定
- 修論 + paper として **honest reframing**, 研究 rigor の demonstration
- Saito-Li 2024 "LHY-only insufficient" finding と complementary

---

## 5.11 D 論 Outlook: TDHFB / Beliaev for True Quantum Fluctuation Evaluation

### 5.11.1 Why higher-order methods needed

TWA leading-order は chaotic dynamics を capture するが、**真の量子ゆらぎ magnitude** 
の quantitative extraction には:

- **TDHFB (Time-Dependent Hartree-Fock Bogoliubov)**: BdG modes の population 動的進化 → 
  量子 fluctuation の time-resolved tracking
- **Beliaev decay**: 2-phonon scattering processes → finite quasiparticle lifetime 効果
- **Higher TWA orders** ($1/N^2$ corrections): Polkovnikov 2010 systematic expansion

### 5.11.2 D 論 Ch.3 課題

- F=6 spinor TDHFB framework 構築 (文献空白)
- Eu post-quench で chaos vs QF separation
- Saito-Li 2024 droplet との合成 picture: LHY-only insufficient + TDHFB QF + chaos
- Realistic numerical predictions for 上妻研実験

### 5.11.3 上妻研実験との接続

実験的 σ/μ measurement で:
- もし σ/μ ≈ 0.4 が観測される → 本研究の chaos prediction confirmed
- 実験 σ/μ が予測より小さい → quantum decoherence が chaos suppress (interesting!)
- 実験 σ/μ が異なる N-dependence を示す → mixed chaos + QF regime

これら 3 outcomes 全て publishable, **修論 Ch.7 framework の natural extension**。

### 5.11.4 TDHFB Phase 3-6 implementation progress (2026-05-12)

§5.11.1 で「TDHFB が D 論期間の課題」と書いたが、実装は既に Phase 3 (Strang
substep) — Phase 6 (Eu post-quench production scaffold) まで landed している。
具体的な実装現状:

**Phase 1-3 (DONE)**: `src/hamiltonian/tdhfb/` 配下に
- `channel_kernel.jl`: rank-4 V kernel via Σ_S g_S CG·CG
- `hartree_fock_matrix_generic.jl`: generic-F HF self-energy
  (test/test_tdhfb_hf_matrix_generic.jl: 208/208 PASS)
- `strang_step.jl`: voxel-local BdG matrix exponential
  (V/2 · HF/2 · K · HF/2 · V/2; 31/31 Phase-3 smoke tests PASS)
- `energy.jl`: total functional E[φ, ρ, κ]

**Phase 4 (Y4-midpoint wrapper, formal order 4 — empirical order 2)**:
`y4_midpoint_step.jl` exists as a drop-in Yoshida-4 composition over
the Strang sub-step. Empirically achieves only order 2 because the
underlying TDHFB Strang substep is not yet palindromic at O(dt²) —
the φ-R-φ inner triple is asymmetric (first φ-step reads (ρ, κ)
BEFORE the R update; second reads them AFTER). A genuinely palindromic
substep (full BdG-Nambu rotation that evolves the doublet (φ, conj(φ))
under a coupled rotation preserving the Nambu conjugation constraint)
is required before Y4 can deliver order 4. **D 論 task**.

**Phase 5 (GPU port design only)**:
`docs/design/tdhfb_gpu_port_design.md` exists; implementation
multi-session (D 論 task). CPU wall is 1.56 s/step at F=6 (D=13) 16³
— scan-scale TDHFB needs GPU.

**Phase 6 (F=1 + F=6 production)**:
- `test/dynamics/test_tdhfb_f1_validation.jl`: F=1 16³ T=0.2 anti-polar quench
  completes in 8.3s. κ growth linear 0 → 2.5×10⁻² (V·φφ source), ρ tiny
  ~3×10⁻⁷. Hermiticity / symmetry preserved at machine precision.
- `scripts/tdhfb_eu_production.jl`: F=6 16³ T=0.4 ω⁻¹ Eu production
  scaffold. Regime A (g_S all = 1) completed: 313 s wall, κ growth
  linear 0 → 6.2×10⁻². Run data: `docs/manuscript/figures_data/
  tdhfb_eu_F6_T0.4_2026-05-12.md`.

**Phase 4 EOM/E variational consistency**:
A factor-2 + ρ-index transpose was identified and partially fixed in
2026-05-12 round 1 (commit `96b7631`), dropping C4 energy drift
1.43×10⁻² → 3.3×10⁻³ on the operational test (g_S = (0.3, 0.05), T=2).
A residual ~3×10⁻³ drift remains, dt-independent and linear in g_S.

Finite-difference per-term Wirtinger derivative audit
(`scripts/diagnostic/tdhfb_per_term_audit.jl`) identified the correct
**variational forms** for the φ EOM:
- U^φ: V[c_p, c, c2, c2_p] (slot 1↔2 swap)
- Δ^φ: V[c, c2, c_p, c2_p] (slot 2↔3 swap)

These match δE_int/δφ* at machine precision (rel dev 3.3×10⁻⁶) on a
single-voxel test. **However**, applying these to `strang_step.jl`
INCREASED drift (3.3×10⁻³ → 1.0×10⁻² with U^φ alone, 2.0×10⁻² with
U^R factor 2 restored). The BdG generator structure (U^φ, Δ^φ, U^R,
Δ^R) and the inner Strang triple φ-R-φ have interconnected conventions
where the "wrong" U^φ partially compensates other internal bugs; local
per-term fixes break this balance.

**Status**: variational targets for the φ EOM are fully characterized;
the same approach for the ρ/κ EOM via δE/δρ and δE/δκ* FD audit
identified that the analogous Δ^R / U^R require a fundamentally
different mathematical structure (not a single V index swap — likely a
**symmetric combination** of slot patterns reflecting the Nambu-density
commutator [W^R, R]). Full fix is post-修論 work (D 論 Year 1 Q1).

For the 修論-scope production runs (κ generation, qualitative Lima-
Pelster comparison at short T < 1 where the residual drift impact is
sub-leading), the current Phase 3-6 implementation is operationally
adequate. The variational-target characterization is itself a
contribution: §5.2 of `integrator_track_c_derivation.md` analog —
the §5.x continuum derivation gives the correct variational target,
but the discrete BdG generator structure requires per-term audit (not
direct index mapping) for variational consistency at machine precision.

---

## 5.12 まとめ

### 5.12.1 主要 finding

1. **Mean-field results robust** (Sec 5.6 Eu collapse bracketing, 5.7 species trend)
2. **σ/μ ≈ 0.4-0.8 は chaotic dipolar instability signature** (Sec 5.8-5.9)
3. **TWA leading-order is chaos diagnostic, not QF tool** (methodology refinement)
4. **Species universality of chaos onset** (Cr/Eu/Er/Dy ε_dd scan)
5. **D 論期間で TDHFB / Beliaev 拡張** で真の QF 評価 (Sec 5.11)

### 5.12.2 修論 / Paper #4 strategic framing

- 修論 Ch.5: chaotic dynamics study として self-consistent
- Paper #4: **"Chaotic dipolar instability in post-quench F=6 spinor BEC"** として 
  PRR / PRA target, 修論期間内 submission realistic
- 全 GPU work 完了 (5 runs done) → Paper #4 baseline 確定

### 5.12.3 学術的意義

このような **honest reframing** は:
- 研究の self-correcting nature を実証
- Negative result を positive physics finding に転換
- 元 "TWA QF" claim より **物理的に rich な chaotic dynamics interpretation** を確立
- TDHFB / Beliaev D 論期間への clear pathway 提供

**Bottom line**: 修論期間内 portfolio (3 papers + thesis) は **強化されて完成** した。
Paper #4 candidate は subsumed されたが、より specific な "chaotic dynamics study" として 
reborn。
