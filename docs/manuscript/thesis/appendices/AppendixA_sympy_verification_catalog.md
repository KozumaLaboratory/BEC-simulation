# Appendix A: Sympy / 数値 verification scripts catalog

本 appendix では、本修論で実行した polyhedral phase verifications + Sign Pattern
analysis の reproducibility chain を catalog する。全 scripts は repository に track
され、`julia --project=.` で再現可能。

---

## A.1 Concept: verify-first reproducibility chain

本研究の verify-first protocol (Chapter 7 §7.6.1) に従い、paper3 v3 の全 polyhedral
closed-form は **2 つの independent methodology** で cross-verified:

1. **Original sympy derivation** (paper3 main.md, Round 4 + Round 5 parallel sessions):
   spinor construction + Hamiltonian projection + symbolic factorization
2. **Independent group-projection numerical reconstruction** (本修論 Round 7,
   2026-05-11): 群論的 projector + Clebsch-Gordan summation + numerical $\beta_S^{c_0}$
   coefficient extraction

両 paths が同じ closed-form rational coefficients を再現 → 6+ decimal places 一致を
confirm (`audit_result_2026-05-11.md`).

---

## A.2 Script inventory

### A.2.1 `scripts/manuscript/paper3_audit.jl`

**Purpose**: paper3 v3 の 5 polyhedral cases (F=3 octa A_2, F=4 cube, F=6 ico, F=8
cube-octa Dy, F=10 dodec) を independent reconstruction で audit する。

**Method**:
1. F-spin matrices $F_x, F_y, F_z$ を direct construction (raising/lowering operator
   eigenvalue 公式)
2. Wigner D-matrix を $e^{-i\theta \mathbf{F}\cdot \hat{n}}$ の eigendecomposition で
   compute
3. Polyhedral group 生成: $\{T, O, I\}$ それぞれ 2 generators (C_4/C_5 + tilted C_3)
   から group closure
4. Irrep character 算出 (A_1 trivial, A_2 sign rep for $O$, A for $I$)
5. Projection $P = (1/|G|) \sum_g \chi^*(g) D^F(g)$ を random vector に適用
6. ζ structural sanity (norm, ⟨F²⟩, Schur isotropy, ⟨F⟩=0, group invariance) を
   verify
7. $\beta_S^{c_0} = |\langle S | \zeta \otimes \zeta\rangle|^2$ を Clebsch-Gordan
   summation で compute
8. paper3 stated closed-form rational coefficients と numerical 一致を check

**Expected output**: 5 cases 全部 PASS、各 case で Schur isotropy < 1e-12、
$\beta_S^{c_0}$ が paper3 stated に 6+ decimal places 一致。

**Runtime**: ~5 min on CPU.

### A.2.2 `test/manuscript/test_f12_icosahedral.jl`

**Purpose**: F=12 icosahedral I:A 新 instance の verification (paper3 §IX.B follow-up,
predictive test for Sign Pattern conjecture)。

**Method**: A.2.1 の framework を F=12 specifically に適用。

**Result** (`F12_verification_result.md`):
- ⟨F²⟩ = 156 (exact)
- Schur isotropy 1e-13 (machine precision)
- ζ sparse on m ∈ {±10, ±5, 0} (consistent with $C_5^z$ invariance)
- **Selection rule [2, 4, 8, 14] excluded — matches F=6, F=10 icosahedral exactly**
  → F-universality of I_h selection rule に third instance (paper3 §V.G)
- 全 13 channels の $\beta_S^{c_0}$ computed numerically

$\beta_S^{\lambda_{\rm spin}}$ closed-form derivation は deferred (sympy 大規模 25×25
BdG factorization が必要、post-修論 D-thesis Year 1 candidate).

**Runtime**: ~3 min on CPU.

### A.2.3 `test/manuscript/test_sign_pattern_6j.jl`

**Purpose**: Sign Pattern Systematic の **Anomalous Identity** 数値 verification
(Strategy A Step 4):

$$\text{sign}(\beta_S^{(\lambda_{\rm spin})}) \stackrel{?}{=} \text{sign}\left(\text{Re}\left[\langle S | F_a \zeta \otimes F_a \zeta\rangle \cdot \langle \zeta \otimes \zeta | S\rangle^*\right]\right)$$

**Method**: paper3 audit framework を再利用、各 case で:
1. ζ を group projection で構築
2. $F_z \zeta$ を compute (any $F_a$ choice、Schur isotropy で同値)
3. 各 $S$ channel で 3 quantities を tabulate:
   - $\beta_S^{c_0} = |\langle S | \zeta\otimes\zeta\rangle|^2$
   - $X_S^{(HF)} = |\langle S | F_a \zeta \otimes \zeta\rangle|^2$
   - $X_S^{(\rm anom)} = \text{Re}\sum_M \langle S, M | F_a \zeta \otimes F_a \zeta \rangle \cdot \langle \zeta\otimes\zeta | S, M\rangle^*$
4. sign($X_S^{(\rm anom)}$) vs paper3 stated sign($\beta_S^{\lambda_{\rm spin}}$) を比較

**Result** (`sign_pattern_anomalous_identity.md`):
- F=4 cube: sign match all 4 channels ✓
- F=6 icosa: sign match all 4 channels ✓
- F=8 cube-octa: sign match all 8 channels ✓
- F=10 dodec: sign match all 7 channels ✓
- F=3 octa A_2: one-step offset (A_2 sign convention issue)

**Conclusion**: Anomalous Identity が paper3 cases で機能、Sign Pattern conjecture
を computable structural identity に refine.

**Runtime**: ~5 min on CPU.

---

## A.3 Reproducibility commands

全 scripts は同じ Julia environment (`julia --project=.`) で実行:

```bash
# Repository clone + setup
git clone <repo-url> BEC-simulation
cd BEC-simulation
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Audit paper3 v3 polyhedral cases (5 cases, ~5 min)
julia --project=. scripts/manuscript/paper3_audit.jl

# F=12 icosahedral verification (~3 min)
julia --project=. test/manuscript/test_f12_icosahedral.jl

# Sign Pattern Anomalous Identity numerical (~5 min)
julia --project=. test/manuscript/test_sign_pattern_6j.jl
```

各 script の stdout に detailed table が output される。Random seed (42) で結果 deterministic。

GPU 不要 — 全 scripts は CPU で実行 (matrix dimensions D=7 to D=25 で十分 fast)。

---

## A.4 paper3 main.md original sympy scripts (parallel sessions)

paper3 v3 main.md の closed-form derivations は parallel sessions (Round 4 + Round 5)
で sympy で実行された。本修論期間の audit は **independent reconstruction** であり、
両 path の crossing が paper3 reliability の独立 evidence。

Round 4 (F=4 cube + F=10 dodec) + Round 5 (F=3 octa A_2 + F=8 cube-octa Dy) sympy
scripts は paper3 supplementary material として archived。本修論 audit は SpinorBEC.jl
infrastructure only で実行 (sympy 不要)、Julia + LinearAlgebra + SpinorBEC.clebsch_gordan
で完結。

---

## A.5 Verification framework limitations

本 audit framework が cover していないこと (= follow-up scope):

1. **$\beta_S^{(\lambda_{\rm spin})}$ explicit closed-form derivation**: A.2.3 では
   sign のみ verified、coefficient の rational value は paper3 stated を citation。
   Full re-derivation には sympy + 50×50 BdG factorization が必要 (D 論 Year 1).
2. **F=2 cyclic ($T_d$ residual)**: A.2.1-3 は $T_d$ group を実装していない (O, I のみ)。
   F=2 cyclic は別途 Chapter 3 で扱う (Paper #1 で sympy verified).
3. **Axial F=2 BN ($D_4$)**: A.2.1-3 は polyhedral group のみ。BN ($D_4$ residual)
   は Chapter 4 §4.7.4 で扱う (10×10 BdG direct diagonalization with sympy).
4. **F=12 closed form**: A.2.2 で spinor 構築 + selection rule のみ、closed-form
   coefficients は post-修論 deferred.

これら limitation の resolution roadmap は Appendix E + D 論 Year 1 plan (post-修論)
を参照。

---

## A.6 Future audit framework extensions

D 論 Year 1 で planning される verification extensions:

1. **Sympy full-coverage**: F=12 closed form + Anomalous Identity rigorous proof
2. **F=5, 7, 9, 11 odd-F polyhedral** systematic completion (Chapter 6 master table
   extension to all $F \leq 12$)
3. **Dipolar generalization audit**: Lima-Pelster $Q_5$ for polyhedral phases
4. **Multi-species (binary BEC) J=2 cross-channel framework** verification

各 extension は本 Appendix A の framework に increment 追加可能、reproducibility chain
は consistent に保たれる。

---

## A.7 Summary table

| Script | F values | Group | Verified | Status |
|---|---|---|---|---|
| `paper3_audit.jl` | 3, 4, 6, 8, 10 | O, I | $\beta_S^{c_0}$ closed forms | ✓ PASS 6+ decimals |
| `f12_icosahedral_verification.jl` | 12 | I | spinor + selection rule | ✓ structural sanity |
| `sign_pattern_6j_numerical.jl` | 3, 4, 6, 8, 10 | O, I | sign($\beta_S^{\lambda_{\rm spin}}$) | ✓ 4/5 cases match |
| (deferred D 論) | 12 | I | $\beta_S^{c_0/\lambda_{\rm spin}}$ closed form | sympy required |
| (deferred D 論) | 5, 7, 9, 11 | O | spinor + closed forms | systematic completion |

本 catalog は修論 reviewer が verify-first audit を独立 reproduce するための full
reference であり、Verify-first methodology (Chapter 7 §7.6) の operational instance。

---

(Appendix A 終了)
