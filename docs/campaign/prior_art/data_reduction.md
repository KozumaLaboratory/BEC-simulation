# Prior art — data_reduction

> **FROZEN 2026-08-20.** A snapshot of the open work on data_reduction as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: storage, disk, reduction, tier, archive, prune, retention, jld2, catalog. Regenerate with
`python3 scripts/prior_art.py --topic data_reduction --keywords storage disk reduction tier archive prune retention jld2 catalog`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/ci/trim-fast-tier-and-cache | unrelated | branch:  | test tier membership + CI precompile cache; "cache" matched the keyword but it is the Julia compile cache, not run output |
| origin/fix/oracles-tier-red | unrelated | branch:  | a citation gate going red on an archive import; matched "archive" as a word |
| origin/fix/result-jld2-duplication | read | branch:  | PR #195, CLOSED 2026-07-30 unmerged. anko: the duplication is INTENTIONAL, result.jld2 is a SUMMARY artifact — so that PR's premise (unintended bug) was wrong. But its measurement stands and is the starting point here: result.jld2 is 9.71 GB against point_001 10.25 GB because it carries all 753 frames, i.e. it is NOT functioning as a summary. The change left on record for a decision — drop dynamics/psi_snapshots_streamed from result.jld2 — serves the stated design AND recovers the space. That is what this work does. |
