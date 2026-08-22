# Prior art — eu_evaporation

> **FROZEN 2026-08-22.** A snapshot of the open work on eu_evaporation as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: evaporation, evaporative, cooling, ramp, k3, spgpe. Regenerate with
`python3 scripts/prior_art.py --topic eu_evaporation --keywords evaporation evaporative cooling ramp k3 spgpe`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/feat/evaporation-k3-trap-shaping | read | branch: K₃ × trap-shaping dense maps (#58) | **NOT merged** (`git merge-base --is-ancestor` false, 38 files / 43k lines ahead). Its 4-axis scan CSVs and `scripts/evaporation_k3_*.jl` exist only there; main's trap-shaping figures come from `docs/guides/figures/eu_evaporation_*`. Do not cite its numbers as re-derivable from a main checkout — same shape as `gotcha_an_exclusion_list_can_rest_on_an_instrument_that_never_landed`. |
| origin/feat/evaporation-ramp-optimizer | read | branch: 3-param BO + per-beam monotone + coordinate-descent ramp optimisers | MERGED into main. `optimize_ramp_monotone` / `optimize_ramp_coordinate` / `scan_ramp_param` live in `src/solvers/evaporation/evaporation_optimize.jl`. |
| origin/feat/spgpe-full-reservoirs | read | branch: full SPGPE (growth + energy damping), reservoir bridge, number-conserving constraint | MERGED (PRs #351/#442/#446). The current state of the arc: `docs/guides/spgpe.md`. |
| origin/fix/evaporation-parameter-free | superseded | branch: exact LRW rate, ab-initio K₃, re-anchored T₀, robust optimiser | PR #330 **CLOSED without merge** ("partially superseded by main"). Its `evaporation_robust.jl` is not in the tree, but `param_uncertainty_ensemble` + `optimize_ramp_monotone(...; ensemble=)` and the ⟨n²⟩ = 8/21 correction did land by another route — verified by grep, not by the PR title. |
| #305 | read | issue: Two things #196 left open: the c0 = 0.19 SPGPE discrepancy, and a nightly that has been red since 08-01 | OPEN. Strong-coupling SPGPE equilibrium runs 2.29× Rayleigh–Jeans at c₀ = 0.19; carried as `@test_broken`. A known limit on absolute c-field equilibria — quote it beside any equilibrium N₀, but it does not touch the ramp verdict (which is a ratio and a null). |
| #32 | unrelated | issue: EdH vs Flower 判定 — smooth ramp vs Matsui-quench at 63 µG | OPEN, but it is the EdH/flower quench decision; it shares only the K₃ = 10⁻⁴⁰ value. The preparation stage it consumes is this arc's output, not its subject. |
| #418 | read | issue: full SPGPE が #334 のランプで凝縮しない — 3 候補を除外済み、原因未決 | OPEN and directly load-bearing. Projector number loss, cutoff motion and energy damping *in general* are excluded; the remaining suspects are the spinor structure, the DDI, and the drive 2γ(μ_res − μ_ψ) collapsing as μ_ψ tracks the reservoir. The Eu evaporation c-field null shares this failure mode. |
| #75 | read | issue: Eu evaporation-ramp optimization + parameter calibration (Miyazawa 2021 thesis) | OPEN — the parent issue for this whole arc. Its headline "~2–3×10⁵ at ~50 nK" is the 0-D dilute-attractor prediction and is **not** what the number-conserving constraint now says (peak 4.41×10⁴ at t = 1.70 s); the issue body has not been updated. |
