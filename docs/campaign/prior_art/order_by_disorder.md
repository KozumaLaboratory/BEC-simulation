# Prior art — order_by_disorder

> **FROZEN 2026-08-25.** A snapshot of the open work on order_by_disorder as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: goldstone, bdg, degeneracy, lhy, 455, 457. Regenerate with
`python3 scripts/prior_art.py --topic order_by_disorder --keywords goldstone bdg degeneracy lhy 455 457`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/claude/spinor-lhy-correction-OXkxG | superseded | branch: 9 commits ahead, tip `bff0c3af` "CI Julia 1.10 removal" | The spinor-LHY work it opens with (`e2677a0b`) landed in main long ago; the rest is an unrelated grab-bag (J_z projection, quasi-2D rescaling, continuation). Nothing here is a live LHY path. |
| origin/feat/fm-lhy-general-F | superseded | branch: **0 commits ahead of main** | Already merged — "FM closed forms work at any F", the change CLAUDE.md's design-boundaries section records for 2026-07-27. |
| origin/feat/lhy-block-wiring-spatial | superseded | branch: 7 ahead, incl. `de816075` "LBFGS gradient was exactly zero for every tabulated LHY" and `34db34b7` "SpatialLHY gradient was missing its polarisation piece" | **Checked rather than assumed, because a zero LHY gradient would make this topic's whole measurement an artefact.** Both fixes ARE in main under different SHAs — `_grad_lhy!` carries the tabulated table (`lhy_term.jl:281`) and `_grad_lhy_spatial!` carries the polarisation piece (`:295`). The branch is stale, not a missing dependency. |
| origin/test/gpu-bdg-instrument-parity-400 | unrelated | branch: 1 ahead, `f8538695` GPU gate for #339's instruments | Device gate for the BdG instruments. This topic runs in a CPU uniform box; it would matter the moment any of it moves to a device. |
| #455 | read | issue: research(bdg): FM 枝の擬 Goldstone ギャップ — ラベル遷移として測る (②a-1) | The topic itself. Preconditions closed 2026-08-26 (PR #493); the label-transition method in its body is superseded by the excess over `bdg_expected_zero_modes` (labels are per degenerate BLOCK). Its premise — that uniform g_S is an ACCIDENTAL continuous degeneracy — is what the current probe tests. |
| #456 | depends | issue: test(oracles): FM 枝マグノンの LHY 補正はスキーム感受か (②a-2) | Same premise, one layer out: its 2×2 (r × scheme) asks whether the magnon LHY correction moves. If the uniform-g_S manifold turns out to be a U(2F+1) symmetry orbit, #456's r axis is unaffected (it sweeps the PHYSICAL g_S spread) but the framing "gap the would-be Goldstone" that it inherits from #455 is not. Read this row before writing #456's test. |
