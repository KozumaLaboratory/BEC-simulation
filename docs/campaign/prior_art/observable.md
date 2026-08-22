# Prior art — observable

> **FROZEN 2026-08-21.** A snapshot of the open work on observable as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: observable, breathing, radial, expansion, weff. Regenerate with
`python3 scripts/prior_art.py --topic observable --keywords observable breathing radial expansion weff`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/research/edh-breathing-phase | read | branch: merged (PR #443) | **This is #444's premise.** The 10.4 nT result: `ω_eff` structure is a breathing PHASE, not a cascade resonance — the quench excites a breathing mode, `ω_eff` sets its frequency, and a fixed-length hold makes the endpoint cloud size a function of phase. Its registered prediction (double the hold and the ratio moves) came true. #444 re-applies the same test at 5.2 nT. Already on main, so it is the current state rather than parallel work. |
| origin/research/edh-observable-invariance | read | branch: merged | **Supplies the window discipline #444 must inherit, and one of its open rows.** Established that at 10.4 nT the peak reads the PRE-HOLD TRANSIENT for 16 of 20 arms unless the window is taken inside the hold, and that under a reading with no free parameter both fields lose their optimum. `edh-104nt-observable-not-window-robust` is still open and is exactly why #444 says to look at a DIFFERENT QUANTITY (the cloud) rather than re-read populations. Merged; not competing work. |
| #289 | unrelated | (no longer open) | CI mutation-testing walltime and sharding. Matched "hold" inside "holds ... hostage" — the keyword is the protocol's hold step, this is English. Nothing about how an observable is extracted. |
