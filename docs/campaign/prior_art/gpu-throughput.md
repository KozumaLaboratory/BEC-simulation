# Prior art — gpu-throughput

> **FROZEN 2026-10-02.** A snapshot of the open work on gpu-throughput as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: performance, optimization, batched, fft. Regenerate with
`python3 scripts/prior_art.py --topic gpu-throughput --keywords performance optimization batched fft`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| origin/perf/h100-optimization | read | branch:  | Inspected unique commits and current tensor/energy implementations; inactive-tensor guard and fused energy/gradient already exist in HEAD, so do not replay the old branch. |
| origin/perf/rtp-deep-optimization | read | branch:  | No commits outside HEAD; existing RTP fusion and FFT benchmark drivers form the baseline. |
