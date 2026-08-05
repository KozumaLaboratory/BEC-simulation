# 符号バグ構造的防止アーキテクチャ — 設計提案

> **FROZEN 2026-06-04.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

## 1. 問題の正確な診断

2026-06-02 から 2026-06-04 の 3 日間で 4 つの符号 / 欠落項バグが
発生した:

| 日付 | バグ | 失敗 path | 検出方法 |
|---|---|---|---|
| 06-02 | Barnett shift `p−Ω → p+Ω` | `_shift_zeeman_for_rotating_frame` | EdH オラクル |
| 06-03 | Coriolis 3-shear flip (false alarm) | `_apply_coriolis_step!` | 6-sign audit |
| 06-04 | GPU energy 欠 Coriolis+light_shift | `_energy_decomposition_gpu` | per-term FD audit |
| 06-04 | Transverse Zeeman `+bx → -bx` | `_apply_transverse_zeeman_step!` + `combined_spin_step.jl` | static +Bx 物理 oracle |
| 06-04 | `_zeeman_energy` + `_grad_zeeman!` 欠 transverse | energy.jl + energy_gradient.jl | systematic audit |

**共通パターン**:

```
同じ物理量を表す式が手書きで N 箇所に複製されている
        ↓
N 箇所間の sync は人手で維持される
        ↓
1 箇所だけドリフトしても他のテストは通る
        ↓
directional 物理 observable が initially missing
        ↓
バグ発見が遅れる
```

具体例 — 線 z-Zeeman は **8 箇所**で別々に書かれている:

| ファイル:行 | 内容 |
|---|---|
| `zeeman.jl:9-11` | `zeeman_energies` = `[(-z.p * m + z.q * m^2) for m]` |
| `zeeman.jl:17-20` | `zeeman_diagonal` (`ZeemanParams`, `SpinSystem`) — `-z.p * m` |
| `zeeman.jl:36-40` | `zeeman_diagonal(..., omega_R)` — `-(p - omega_R) * m` |
| `propagators.jl:332` | `psi[c] *= exp(-(zeeman_diag[c] - shift) * dt)` |
| `propagators.jl:342` | `psi[c] *= cis(-zeeman_diag[c] * dt)` |
| `energy.jl:164-178` | `_zeeman_energy` — `(-p*m + q*m²) * \|ψ_m\|²` |
| `gpu_energy.jl:113` | `E_zee = SpinorBEC._zeeman_energy(psi, ...)` (delegates) |
| `energy_gradient.jl:152-160` | `_grad_zeeman!` — `zee_vals[c] * psi[c]` (uses `zeeman_energies`) |

各々が「-p·m + q·m²」の論理を独立に表現している。1 箇所で
sign が flip しても他は通る。`_zeeman_energy` と `_grad_zeeman!` が
transverse を欠いていることに 4 か月誰も気付かなかった理由は、
**N 箇所複製の中の漏れは scope の外で発生し外部から見えない**から。

## 2. 設計目標

符号バグを起こしうる構造を撤去:

- **G1**: 各 H 項の符号は 1 ファイル 1 行で宣言される。他は自動派生。
- **G2**: propagator / energy CPU / energy GPU / gradient の 4 path 間
  の consistency は、宣言から自動 derived された関数によって CI で
  数値検証される (FD vs gradient, CPU vs GPU)。
- **G3**: directional 物理 oracle は宣言と同じ場所に書く。新項を
  追加すると oracle test も追加する flow が文法的に強制される。
- **G4**: 既存の手書き実装を壊さない (incremental migration が可能)。

## 3. 提案アーキテクチャ

### 3.1 `HamTerm` プロトコル

```julia
# src/hamiltonian/terms/base.jl
abstract type HamTerm end

# Each concrete HamTerm subtype MUST implement these methods.
# A subtype that doesn't will fail the consistency test.

"Add this term's contribution to grad += δE/δψ* (no factor of 2)."
function add_gradient!(grad, term::HamTerm, psi, ws) end

"Compute this term's contribution to total energy E = ⟨ψ|H|ψ⟩."
function energy_contribution(term::HamTerm, psi, ws) end

"Apply this term's propagator step exp(-i·dt·H) (real time) or
exp(-H·dτ) (imaginary time)."
function apply_step!(term::HamTerm, psi, dt, imaginary_time, ws) end

"Directional sign oracle. Returns (test_name, condition::Bool)."
function sign_oracle(term::HamTerm, ws) end
```

### 3.2 具体例: 線 z-Zeeman

すべての sign 情報を 1 行に集約:

```julia
# src/hamiltonian/terms/zeeman_z.jl
struct LinearZeemanZ <: HamTerm
    p::Float64    # +p ⇒ +Bz ⇒ low E at +F_z
end

# THE ONE LINE. The user-spec H_z = -p·F_z lives here exclusively.
_diag_coefficient(term::LinearZeemanZ, m) = -term.p * m

# All four implementations are AUTO-DERIVED from _diag_coefficient.
# Cannot drift relative to each other.

function add_gradient!(grad, term::LinearZeemanZ, psi, ws)
    F = ws.spin_matrices.system.F
    D = 2F + 1
    for c in 1:D
        m = F - (c-1)
        coef = _diag_coefficient(term, m)
        view(grad, _component_slice(...), c) .+= coef .* view(psi, ...)
    end
end

function energy_contribution(term::LinearZeemanZ, psi, ws)
    F = ws.spin_matrices.system.F
    D = 2F + 1
    dV = cell_volume(ws.grid)
    E = 0.0
    for c in 1:D
        m = F - (c-1)
        coef = _diag_coefficient(term, m)
        E += coef * sum(abs2, view(psi, ..., c)) * dV
    end
    return E
end

function apply_step!(term::LinearZeemanZ, psi, dt, imaginary_time, ws)
    F = ws.spin_matrices.system.F
    D = 2F + 1
    for c in 1:D
        m = F - (c-1)
        coef = _diag_coefficient(term, m)
        if imaginary_time
            view(psi, ..., c) .*= exp(-coef * dt)
        else
            view(psi, ..., c) .*= cis(-coef * dt)
        end
    end
end

function sign_oracle(term::LinearZeemanZ, ws)
    # User spec: +p (positive Bz) prefers +F_z.
    # ITP from FM_z + small Bx parity breaker should give ⟨F_z⟩ > 0.
    ("LinearZeemanZ: +p ⇒ ⟨F_z⟩ > 0", _itp_fz_check(term, ws))
end
```

**この設計の sign-bug-proof 性**:

- `-p·m` の sign は `_diag_coefficient` の **1 か所だけ**に存在
- propagator/energy/gradient はすべて同じ関数を呼ぶ
- sign を 1 箇所で flip すれば 4 path **全部**が同じ方向に動く
- → 「path A だけ flip」型のバグは構造的に発生不能

### 3.3 Transverse Zeeman (今回直したバグ)

```julia
# src/hamiltonian/terms/zeeman_transverse.jl
struct TransverseZeeman <: HamTerm
    bx::Float64
    by::Float64
end

# THE ONE PLACE. Off-diagonal coefficients of H_transverse_Zeeman.
# User spec: H = -bx·F_x - by·F_y.
function _matrix(term::TransverseZeeman, sm::SpinMatrices)
    -term.bx * sm.Fx - term.by * sm.Fy
end

# Auto-derived:
add_gradient!(grad, term::TransverseZeeman, psi, ws) =
    _apply_matrix_to_grad!(grad, _matrix(term, ws.spin_matrices), psi)

energy_contribution(term::TransverseZeeman, psi, ws) =
    real(_matrix_expectation_value(_matrix(term, ws.spin_matrices), psi, ws))

apply_step!(term::TransverseZeeman, psi, dt, it, ws) =
    _apply_spin_matrix_propagator!(psi, _matrix(term, ws.spin_matrices), dt, it)

sign_oracle(term::TransverseZeeman, ws) =
    ("TransverseZeeman: +bx ⇒ ⟨F_x⟩ > 0", _itp_fx_check(term, ws))
```

`-bx·F_x - by·F_y` の sign は `_matrix` の **1 行だけ**。`-bx`
が `+bx` になれば、propagator・energy・gradient **全部が同時に**
反転する。 一致した反転は sign oracle test の `⟨F_x⟩ > 0` で
即座に CI fail する。

### 3.4 自動 consistency check (CI gate)

```julia
# test/oracles/test_term_consistency.jl

const ALL_HAM_TERMS = HamTerm[
    LinearZeemanZ(0.5),
    QuadraticZeemanZ(0.1),
    TransverseZeeman(0.3, 0.2),
    Coriolis(0.4),
    LightShift(0.05),
    # ...
]

@testset "Every HamTerm: energy ≡ ∂(gradient) (FD oracle)" begin
    ws = _build_reference_workspace()
    psi_ref = _build_reference_state(ws)
    for term in ALL_HAM_TERMS
        @testset "$(typeof(term))" begin
            # FD: dE/dε along a random direction
            δψ = _random_state_perturbation(psi_ref)
            E_0 = energy_contribution(term, psi_ref, ws)
            E_ε = energy_contribution(term, psi_ref .+ 1e-7 .* δψ, ws)
            fd_slope = (E_ε - E_0) / 1e-7

            # Gradient inner product
            grad = zero(psi_ref)
            add_gradient!(grad, term, psi_ref, ws)
            inner = 2 * real(sum(conj.(grad) .* δψ))  # factor of 2 from Wirtinger

            @test isapprox(fd_slope, inner; rtol=1e-3)
        end
    end
end

@testset "Every HamTerm: propagator preserves norm (RT) / monotone (IT)" begin
    for term in ALL_HAM_TERMS
        # ...
    end
end

@testset "Every HamTerm: directional sign oracle" begin
    for term in ALL_HAM_TERMS
        name, passed = sign_oracle(term, ws)
        @test passed
    end
end

@testset "Every HamTerm: CPU/GPU energy/gradient agreement at Ω≠0" begin
    # ...
end
```

CI gate: 新 HamTerm を `ALL_HAM_TERMS` に追加せずに導入すると、
そもそも propagator/energy が無いので make_workspace で error。
追加した瞬間に上記 4 つの test が自動で走る。1 つでも fail
すれば CI red、merge できない。

### 3.5 既存コードとの統合

既存 split_step! は `for term in ws.h_terms; apply_step!(term, ...); end`
のように書き換える。但し大規模 refactor を避けるため
**adapter pattern**:

```julia
# 既存の specialized routine をそのまま使う wrapper
struct _LegacyZeemanZ <: HamTerm
    p::Float64; q::Float64
end
apply_step!(t::_LegacyZeemanZ, psi, dt, it, ws) =
    _legacy_diagonal_step!(...)  # 既存コード
```

その上で新規追加項は **必ず HamTerm として書く**規約を確立。
incremental migration を 1 項ずつ。各 migration は (a) 既存 routine
削除前に new HamTerm が consistency check 通る確認、(b) split_step!
内の switch で legacy → new に置き換え、の 2 step。

## 4. Migration plan

### Phase 1 (本セッション末: 設計確立)
- ✅ この設計ドキュメント
- 1 つの worked example (LinearZeemanZ) の reference implementation
- 1 つの consistency test 自動走行 (FD oracle for LinearZeemanZ)

### Phase 2 (1-2 セッション)
- 全 16 H 項を HamTerm として実装 (まだ既存 routine と並列)
- `ALL_HAM_TERMS` registry + 全項目に対する 4-test 自動 CI
- 既存 directional test を `sign_oracle` メソッドに統合
- 全項目 CPU/GPU 一致確認

### Phase 3 (2-3 セッション)
- split_step! / `_outer_operators_fwd!` を `for term in ws.h_terms`
  ループに refactor
- 各既存 routine を HamTerm method に置き換え (1 項ずつ、CI 通り
  ながら)
- 既存の per-term FD audit script を retire (自動 CI に置き換わる)

### Phase 4 (architecture が固まったら)
- 残り 11 項の directional oracle 追加
- DDI / Coriolis のような spatial-derivative 含む項の HamTerm 化
- F=2/F=6 で全 HamTerm consistency 拡張

## 5. 各歴史的バグがこの設計でどう不可能になるか

| バグ | 設計でどう防がれるか |
|---|---|
| Barnett shift `p−Ω → p+Ω` | `BarnettShift <: HamTerm` は `_shift(term, p) = p + term.Ω` を 1 行で持つ。同じ shift を `apply_step!` + `energy_contribution` + `add_gradient!` 全部が呼ぶ。flip すれば 3 全部が flip + `sign_oracle` (`+Ω→⟨F_z⟩>0`) が CI fail |
| Coriolis substep flip | `Coriolis <: HamTerm` の `apply_step!` は単一 routine。`energy_contribution` は同じ routine から導出 (k-space sum)。consistency CI が FD で immediately 検知 |
| GPU energy 欠 Coriolis | `_energy_decomposition_gpu` が `for term in ws.h_terms; E += energy_contribution(term, ...)` ループになるので、登録ミス以外で項が漏れない。CPU/GPU parity CI で即座に検知 |
| Transverse Zeeman flip | `TransverseZeeman` の `_matrix` で sign を 1 か所宣言。3 path が同期して flip するため `sign_oracle` (`+bx→⟨F_x⟩>0`) が CI fail |
| [GAP-1] `_zeeman_energy` + `_grad_zeeman!` 欠 transverse | LinearZeemanZ と TransverseZeeman が**別の HamTerm として登録**されるため、energy/gradient が片方の項だけ含むことが構造的に不能。registry-driven dispatching が「漏れ」を不能にする |

## 6. コスト見積もり

- Phase 1: 4-6 時間 (この設計＋ worked example 1 つ)
- Phase 2: 16-24 時間 (16 項 × 2 path 並列実装)
- Phase 3: 8-16 時間 (refactor split_step を loop に)
- Phase 4: 12-20 時間 (残り test, F=2/F=6 拡張)

合計約 1-2 週間相当の effort。それに見合うか:
- 過去 3 日で同 class 4 バグ。1 バグあたり ~4-8 時間 debugging。
  reactive で対応続けると今後も継続的 cost。
- migration 完了後、新 H 項追加は **設計上** 符号バグが起きない。
  Eu の未実装項 (multi-channel scattering, full spinor LHY,
  arbitrary axis DDI, ...) を追加するたびに 4-8 時間 ÷ 何回 か削減。

## 7. このセッションでの結論と次セッションへの引き継ぎ

- 設計案 (本ドキュメント) を commit。
- Phase 1 で `LinearZeemanZ` だけ proof-of-concept として実装する
  ことを次セッション開始時の選択肢に。
- user の判断:
  - (a) 設計だけ採用、コード変更は次セッション以降の sprint で。
  - (b) 今ターン Phase 1 だけ着手 (LinearZeemanZ worked example +
    consistency check 1 つ自動化)。
  - (c) Phase 2 まで進めて 16 項全部 HamTerm 化 (この regime は
    複数セッション)。

私の推奨は **(b)**: Phase 1 まで進めて proof-of-concept を残し、
それが動くことを確認してから Phase 2 をまとめて planning。reactive
fix の連続を止める唯一の方法は architecture を変えること。但し
急いで全部書き換えると新規バグを入れる risk、incremental が安全。
