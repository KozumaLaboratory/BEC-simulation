# Loop seed — 2026-05-15 morning, light-mode (Julia parallel sweep running)

## Hard memory constraint (active this session)

Anko's Klaus phi-magnetostir sweep is running 4 julia processes
in parallel (~18 GB RAM used). The loop MUST NOT spawn additional
julia processes — would push memory to OOM and crash the sweep.

**Director MUST NOT dispatch**:
- `implementer` for `run_experiment` (spawns julia)
- `implementer` for `modify_code` if the directive includes
  running `julia --project=. -e ...` or `Pkg.test()` to verify
  the change (analytical / regex / sympy verification is fine)
- `implementer` for `analyze_existing` if the analyzer is a
  julia script

**Director MAY dispatch**:
- `researcher` — WebFetch / WebSearch / Read only, ~100 MB
- `theorist` — Read / Grep / Glob / WebFetch / Write only
- `implementer` for text-only `modify_code` (docstring, comment,
  manuscript section) with NO julia execution to verify
- `implementer` for `compute_sympy` via `uv run --with sympy`
  (~100 MB python)
- `critic` — Read only
- `noop` — when no julia-safe move has leverage

If the director would naturally choose implementer-with-julia, it
MUST instead pick noop or switch to researcher/theorist/critic.

## Goal continuation

Anko's stated goal (still active):

> 研究が最も進む方向性はどれかを考えた上で理論を詰める。
> 盲目に理論をやらない。様々な論文を読んだり verify したり、
> まだ実装してない効果を入れたりとかそういうのを総合的に考えて。

Translation: pick direction that advances research most; verify
implementation against papers; identify unimplemented effects.

## T5 left a concrete next-turn pointer

T5 (researcher, completed before halt) recommended:

> Implementer adds fraction-of-unstable-modes gate to
> `src/hamiltonian/interactions/lhy/dispatch.jl` line 231 area,
> with @warn directing F=6 polar users to closed-form
> `PolarContactLHY`. Citable refs: Lima-Pelster 2011/2012,
> Petrov 2015, Zhang 2023.

This is exactly the implementer-with-julia case the constraint
above forbids. Director should defer this to **post-Julia-sweep**
and pick something else this turn — e.g. extend T5's literature
audit, or critic-audit T5's Nambu-doubling mechanism explanation,
or theorize about the closed-form `phi_1_reg` properties.

## Stop conditions

Same as previous seed: cost cap 3M effective, consecutive-fail 4/5,
no more than 2 same-subagent in a row.
