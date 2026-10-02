# Prior art — ci-latency

> **FROZEN 2026-10-01.** A snapshot of the open work on ci-latency as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: nightly, workflow, CI. Regenerate with
`python3 scripts/prior_art.py --topic ci-latency --keywords nightly workflow CI`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/anko9801/speed-up-ci | read | branch:  | Merged as #510; 6m37s measured despite restored cache. This work fixes repeated precompilation. |
| origin/ci/trim-fast-tier-and-cache | read | branch:  | Historical fixes inspected; already merged into main. |
| origin/fix/nightly-mutation-sizing | read | branch:  | Historical fixes inspected; already merged into main. |
| #506 | read | issue: Nightly heavy YAML is failing | Existing heavy-YAML failure remains tracked; green smoke does not certify nightly. |
