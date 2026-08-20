# Prior art — spgpe

Enumerated 2026-08-20 for keywords: spgpe, reservoir, damping, evaporation.

**A dated snapshot.** Nothing keeps this current; re-run
`python3 scripts/prior_art.py --topic spgpe --keywords spgpe reservoir damping evaporation`
when picking the topic up again. Existing dispositions are preserved.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/feat/evaporation-k3-trap-shaping | unrelated | branch:  | K3 / trap shaping |
| origin/feat/evaporation-ramp-optimizer | unrelated | branch:  | ramp optimiser |
| origin/feat/spgpe-full-reservoirs | read | branch:  | #351's branch |
| origin/fix/energy-damping-loss-is-one-off | read | branch:  | this work |
| origin/fix/evaporation-parameter-free | unrelated | branch:  | closed as PR #330 |
| #305 | read | issue: Two things #196 left open: the c0 = 0.19 SPGPE discrepancy, and a nightly that has been red since 08-01 | open SPGPE discrepancy at c0 = 0.19 (run is 2.29x Rayleigh-Jeans). Strong-coupling equilibrium; carried as @test_broken. Not touched here — #411 is about the projected step at zero drive, a different regime and a different quantity. |
| #334 | read | issue: research(gs): キラル基底状態はその場で核形成させるしかない — κ 依存の転移を通す SPGPE 冷却 | the campaign this arose from; closed by #404 |
| #75 | unrelated | issue: Eu evaporation-ramp optimization + parameter calibration (Miyazawa 2021 thesis) | evaporation-ramp optimisation + Miyazawa calibration; reservoir trajectory input, not the projected step |
| #351 | read | pr: feat(spgpe): the atom number, from the number-conserving constraint | the retraction this work confirms; found the ed-buffer cache key AND retracted the "energy damping is defective" reading first. #411 is downstream of it. NOT READING THIS COST A DAY. |
| #411 | read | pr: fix(spgpe): 射影付きステップの原子数損失は一度きり — 自分の「率」を撤回 | this work |
