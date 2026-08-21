# Prior art — observable

> **FROZEN 2026-08-21.** A snapshot of the open work on observable as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: observable, peak, hold, window, transient, extraction, P_adj, metric. Regenerate with
`python3 scripts/prior_art.py --topic observable --keywords observable peak hold window transient extraction P_adj metric`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| #289 | unrelated | issue: nightly: the mutation job still exhausts its timeout after the 1/7 sharding, and it holds the heavy-YAML result hostage | CI mutation-testing walltime and sharding. Matched "hold" inside "holds ... hostage" — the keyword is the protocol's hold step, this is English. Nothing about how an observable is extracted. |
