# Prior art — reanalysis_entrypoint

> **FROZEN 2026-08-25.** A snapshot of the open work on reanalysis_entrypoint as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: reanalyze, vintage, provenance, cache, stale_points, snapshot, seeding, runs.toml, canonical-grid. Regenerate with
`python3 scripts/prior_art.py --topic reanalysis_entrypoint --keywords reanalyze vintage provenance cache stale_points snapshot seeding runs.toml canonical-grid`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/ci/trim-fast-tier-and-cache | superseded | branch: fast-tier demotion + committed root Manifest for the precompile cache | Already in `main` — `git branch -r --contains 8a75ae13` lists `origin/main`. Nothing to take from it. |
| #478 | read | issue: research(ops): キャッシュミスを (a) 値 / (b) バイト / (c) provenance に分解する — 計算ゼロの step 0 | Measured here. The remaining question — is the 32 % same-basename tail really (a)? — is answered by `store_census`: **0 recoverable, 15 basenames parity arms, 19 physics**. Its one on-disk (b) example is retracted. |
| #483 | read | issue: feat(io): 保存済みランの再解析エントリポイント — vintage を記録し、campaign evidence への昇格を拒む | Implemented here: `reanalyze` + `ObservableDefinition` + `reanalysis_record`, positive control differenced against `peak_padj`. |
| #55 | depends | issue: feat(solvers): unified snapshot + spectral/real-space seeding mechanism | Mostly landed already (`upsample_spinor`, `seed_from:`, `gs_library`) — read the code before planning it. This PR gates the phase/winding claim it rests on; the 64³-from-32³ step-count acceptance is NOT discharged. |
