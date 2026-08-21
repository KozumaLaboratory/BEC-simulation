# 64³ long-time endpoint ensemble

**Status: NOT RUN.** Configs and submit script are committed; the compute was
deliberately not spent on 2026-08-21 (see *Cost*). Nothing in this directory has
produced a number yet.

## The one question these arms answer

At a 100 ω_ref⁻¹ hold, does the statically weakened trap beat no-intervention
**at the endpoint**?

The **peak** ordering is already established and nothing here can move it:

| arm (64³, 100 ω_ref⁻¹) | hold-peak P_adj | endpoint P_adj |
|---|---:|---:|
| baseline ω_eff = 1.000 | 0.37973 | 0.15112 |
| static ω_eff = 0.714 | **0.49081** | 0.17952 / 0.27262 |
| rotating Ω = −0.70 | 0.40102 | **0.40013** |

Static beats baseline by **+29.3 %** at the peak, with gaps 35–100× the seed
scatter. That is the result. The endpoint is a separate row and is `open`.

## Why an ensemble and not a finer grid

**64³ is already the refined grid.** The 32³ → 64³ refinement inverted both
orderings, which is why §15 retracted the long-time claim — but refining again
answers a question nobody asked. What is missing is **n**.

The static arm's **endpoint moves 34.2 %** between two seeds (0.27262 → 0.17952)
while its **peak stays identical to five decimals** (0.49081 both). §10.3
measured five seeds agreeing to five decimals *and proved the knob live* — at
**14.5 ω⁻¹**. That result does not reach 100 ω⁻¹, and its own `scope` field said
so before this was measured.

So the seed is the axis carrying the uncertainty here, and it is the axis to
sample.

## Sizing — fixed before launch

| | |
|---|---|
| measured static endpoint sd | **0.0658** (n = 2, so one degree of freedom) |
| difference of means vs the single baseline point | **0.0750** |
| SE_diff | sd · √(2/n) |
| **n = 7 per arm** | 2.13 σ ← threshold |
| **n = 8 per arm** | 2.28 σ ← what is committed here |

**Fewer than 7 per arm cannot answer the question.** A cheaper version of this
run is not a cheaper answer, it is no answer.

`rotating` gets 4 rather than 8: its endpoint is 2.23× static and already far
outside the scatter, so these seeds check that its own scatter stays small
(0.85 % at n = 2) instead of assuming it.

## Rejection criterion — fixed before launch

> **ESTABLISHED** if `|mean(static) − mean(baseline)| ≥ 2 · SE_diff`, using the
> standard deviation **pooled from these runs** — not the n = 2 estimate above.
>
> **NOT ESTABLISHED** otherwise. The ledger row `edh-longtime-endpoint-ordering-
> unresolved` stays `open`, and the measured SE is reported.
>
> If the pooled sd comes back much larger than 0.0658, **n = 8 does not reach
> 2 σ**: say so and quote the n it would need. **Do not re-fit the criterion to
> whatever landed**, and do not report a difference without the SE beside it.

Written down here because a run that finishes and *then* has its interpretation
chosen is not a measurement.

## Cost, and why it was not spent

20 arms × `cpu_16` × ~5 h actual / 8 h reserved:

```
0.060 × 20 × (0.7×5 + 0.1×8) ≈ 5.2 points
```

On 2026-08-21 the group balance was **19.24** — about **27 %** of it — with
another session spending concurrently on the ω_eff third-field scan. anko chose
not to spend it then. Check `t4-user-info group point` before submitting.

## Running it

```bash
# from the TSUBAME worktree root
qsub -g tga-kozuma-kouhi -t 1-20 scripts/submit_lt64_endpoint_ensemble.sh
```

Task → config mapping is in the submit script: 1–8 baseline, 9–16 static, 17–20
rotating.

**There is no `--smoke` flag and no `--only-point` flag.** Both were written into
a first draft of the submit script from memory and neither exists: `cli.jl
launch` takes `[<batch>] <run_name>`, and `run_yaml` has no point selection. To
smoke one arm, submit `-t 1-1` with a short `h_rt` and expect it to be **killed**
— that proves the config compiles, the 64³ grid allocates and the first
snapshots land. It does **not** prove an arm finishes; the local 64³ arms ran
3.8–4.9 h.

## Collecting

Each arm writes its own run directory (content-addressed on the config bytes).
The hold-peak must be taken **inside the hold**, not over the whole trajectory —
a whole-trajectory argmax reads the pre-hold transient and at 10.4 nT blinded 7
of 10 arms (§12.1).
