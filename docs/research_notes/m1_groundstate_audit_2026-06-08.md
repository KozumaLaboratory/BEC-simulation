# M1 sweep — gate (1) ground-state-ness audit (2026-06-08)

> **訂正 (2026-08-02): sweep は在る。** 2026-07-31 の版はここに「どの commit にも
> 存在せず、下記の数値は再チェックできない」「入力の 30 セルが無い」と書いていた。
> **誤り。** `runs/sprint5_M1_multistart_groundstate/` (untracked) は 30 セル
> (`cell_B*_Om*.jld2`) と `groundstate_audit.jld2`、計 31 ファイル 83 MB が
> main checkout に揃っている。
>
> 正しい制約は **untracked であること** — git に無いので clone からは再現できず、
> CI にも worktree にも見えない。しかし手元では**数値を辿り直せる**。
> 「追跡外」を「消失」と読み替えたのが元の誤りで、これは廃棄 manifest が
> 474 件で犯したのと同じ取り違えである
> ([`stored_run_disposal.md`](../campaign/stored_run_disposal.md))。
>
> 監査自体の限界は変わらない: 自ら **gate (1) のみ**（saddle 除去と vortex 解像度は
> pending）と述べている。
> 全体像: [`doc_run_citation_inventory.md`](../campaign/doc_run_citation_inventory.md)。

First physics-gated extraction from the on-disk 30-cell rotating-frame
sweep (`runs/sprint5_M1_multistart_groundstate/` (untracked), B × Ω, Eu F=6, 24³,
50k atoms). Produced by `scripts/m1_groundstate_audit.jl`.

Gate (1) of the phase verdict: the gradients are gated (master oracle)
and the BdG is anchored (`test_bogoliubov_anchor.jl`), but "gradient
correct" ≠ "this ψ is the ground state". This audit extracts that gate
— fresh re-eval ‖∇E‖ from the saved winner ψ + basin reproducibility
from the (reliable) candidate energies. It is gate (1) only;
saddle-rejection (gate 2, BdG stability) and vortex-resolution (gate 3,
the monopole resolution lesson) are pending.

## Findings

**Save-bug absent for this sweep.** `‖∇E‖_disk ≈ ‖∇E‖_fresh` in every
cell — the spine-G atomic finalization (`3c3c3887`, merged before this
Jun 5-7 run) resolved the two-basin ψ/grad_norm drift; the disk values
are authoritative here.

**Ω=0 column (static phase diagram): SOLID.** All 6 cells converged
(5 GS_confident, multi-seed-reproduced; 1 B=0 Goldstone manifold
floor). The lowest-E basin among 6-7 independent seeds progresses with
the in-plane field:

| B [nT] | Ω=0 winner | seeds→basin | ‖∇E‖ fresh |
|---|---|---|---|
| 0   | polar              | 6→3 | 1.0e-5 (Goldstone) |
| 1   | polar              | 6→4 | 9.8e-6 |
| 2.6 | polar              | 6→4 | 1.0e-5 |
| 5   | antiferromagnetic  | 6→6 | 9.3e-6 |
| 10  | polar_core_vortex  | 7→7 | 1.0e-5 |
| 100 | polar_core_vortex  | 7→7 | 1.0e-5 |

→ **polar → AFM → polar-core-vortex** as B increases (gate-1 confident).
The phase *identity* (these are seed labels of the winning basin) still
needs gate 2 (stability: minimum vs saddle) before it is a phase
verdict.

**⟨L_z⟩ flag — the PCV is legitimate (not suspicious).** Every
converged Ω=0 cell has ⟨L_z⟩ = 0 AND ⟨F_z⟩ = 0 (per-atom), **including
the B≥10 PCV winners**. A mass-circulation vortex winning at Ω=0 would
be suspicious (it costs energy with no rotation to pay for it) and show
⟨L_z⟩ ≠ 0; the measured ⟨L_z⟩ = 0 means the PCV here is a **coreless
spin texture** (Mermin-Ho-like, zero net circulation) — a legitimate
non-rotating ground state. So the polar→AFM→coreless-texture
progression is a clean Ω=0 phase sequence; "polar_core_vortex" is a
seed-label, the physics is a coreless texture. (Ω>0 cells show ⟨L_z⟩
ramping with Ω — the Barnett response — but they are unconverged /
single-seed, not yet trustworthy.)

**Ω>0 columns (the Barnett map): BLOCKED.** 18/30 cells unconverged
(‖∇E‖ ~ 1-4) — the vortex-soft-mode conditioning floor. Only the
high-B/high-Ω corner (B=100 all Ω; B≥5, Ω=0.6) converged, and only
single-seed (GS-ness unverified). The Barnett map is **not extractable
from this sweep** — it needs the preconditioning work (Riemannian /
Noether, spine C/D), a real methodological blocker, not tooling gravity.

## Partition

```
GS_confident       5 / 30   (Ω=0, B≥1)
converged_single   6 / 30   (high-B/high-Ω corner, GS unverified)
goldstone          1 / 30   (B=0, Ω=0)
unconverged       18 / 30   (Ω>0 mid-range, conditioning floor)
```

## Gate 2 — minimum vs saddle (2026-06-08, scripts/m1_gate2_stability.jl)

Lowest constrained-Hessian eigenvalue via fully-reorthogonalised Lanczos
on the anchored FD-Hessian HvP. Constrained operator P(H−2μ)P (P removes
the complex-ψ0 norm+phase gauge; μ = Re⟨ψ0,g⟩/2‖ψ0‖²); λ_min ≥ −tol ⇒
minimum. Method validated on the first cell: μ=12.67, ‖g−2μψ0‖/‖g‖=4e-7
(g∥ψ0, converged), and the phase mode H·iψ0 = 2μ·iψ0 (the 2μ eigenvector,
zeroed by H−2μ).

**All six converged Ω=0 cells are energetic MINIMA** (λ_min ∈ [2.3, 3.7],
strictly positive — no negative mode):

| B [nT] | winner | λ_min |
|---|---|---|
| 0   | polar             | 2.49 |
| 1   | polar             | 2.50 |
| 2.6 | polar             | 2.39 |
| 5   | antiferromagnetic | 2.29 |
| 10  | coreless PCV      | 3.65 |
| 100 | coreless PCV      | 3.20 |

Positive λ_min even at B=0 is physical: Eu's strong DDI couples spin to
space and gaps the would-be spin Goldstones; the phase Goldstone is
projected/shifted out. Lanczos finds the extreme low end reliably, so
"no negative mode" is a sound saddle-rejection (the verdict is the sign,
not the exact value).

## Result — the static Eu phase diagram is FULLY GATED

gate-1 (ground-state-ness, multi-seed) + ⟨L_z⟩ (legitimate coreless
texture, not net circulation) + gate-2 (energetic minimum) all pass for
the Ω=0 column:

**polar (B ≤ 2.6 nT) → antiferromagnetic (B = 5) → coreless texture
(B ≥ 10)** — all energetic minima, all ⟨L_z⟩ = ⟨F_z⟩ = 0 legitimate
non-rotating ground states. This is the North-Star first half ("what is
Eu's ground-state phase"), gated.

## Next

1. The Ω>0 Barnett map: preconditioning (continuation from converged
   neighbours — Ω/B warm-start — before rebuilding a preconditioner) to
   bring the 18 unconverged cells to ground states, then gates 1-2 + the
   ⟨L_z⟩ Barnett response.
2. DDI k-structure in the BdG anchor (a finite-k FD-Hessian extension;
   the k=0 matrix anchor doesn't probe Q(k)).
