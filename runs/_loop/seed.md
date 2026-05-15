# Loop seed — 2026-05-15 morning session (director-autonomous)

## Anko's stated goal (2026-05-15 07:30 JST)

> 研究が最も進む方向性はどれかを考えた上で理論を詰める。
> 盲目に理論をやらない。さまざまな論文を読んだり verify したり、
> まだ実装してない効果を入れたりとかそういうのを総合的に考えて試してほしい。

Translation: "After considering which direction advances the research
most, drill into theory. Don't do theory blindly. Read papers, verify
implementation, add unimplemented effects — think comprehensively and
try."

## Director freedom this session

This seed deliberately **does not specify a single turn's task**.
Director picks autonomously each turn from:

- **Verification gaps** (physics in code vs published reference)
- **Physics gaps** (effects derived but not implemented)
- **Code gaps** (known bugs / refactor / smell)
- **Manuscript gaps** (chapters / sections / forward citations)
- **Infra gaps** (loop architecture, untested paths)

T4 (Lemma 1 F=14 extension) was a successful first director-driven
turn — pivoted from FG/theorist sequence to manuscript-extending
implementer work. Continue that pattern: each turn, pick the
highest-leverage move from project state.

## Constraints

- `force_critic: false` (default; director can dispatch critic on its
  own judgment).
- Time/cost: ≤ 15 min wall, ≤ 3M effective tokens per turn (cost cap).
- Stuck check (4/5 consecutive FAIL → auto-halt) is the safety net.
- If 3 consecutive turns dispatch the SAME subagent type without
  closing a bottleneck, director should rotate routes (§B4).

## What "good" looks like over a multi-turn session

- Each turn advances at least one of: manuscript section, capability,
  verification, bug-resolution.
- Token spend per turn: ≤ 2M effective typical.
- No more than 2 consecutive theorist-only turns (rotation rule).
- At least one researcher dispatch within 5 turns (Phase 2 D2
  exercise gap).
- Critic dispatched only when load-bearing claim is paper-scale.

## What director should NOT do

- Re-run theorist on already-settled FG questions (T0-T3 closed).
- Dispatch implementer for noise/cosmetic edits without bottleneck rationale.
- Launch a `run_experiment` with ≥ 1 hour wall time (cost cap risk).
- Skip the §5 calibrated progress check (must articulate what's on/off track).
