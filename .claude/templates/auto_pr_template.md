# auto(loop) → main: turn N PR template

Use this when promoting an `auto/turn_N_<label>` branch to a real PR
on main (typically via `gh pr create` after `cleanup_branches.sh`
flags it as "KEEP (anko review)").

---

## Summary

- **Turn**: N
- **Directive action**: `modify_code` | `run_experiment` | `analyze_existing`
- **Theorist directive label**: `<short-label>`
- **Judge verdict**: `PASS` | `FAIL_PHYSICS` | `SUSPICIOUS_NOVEL → critic PASS`
- **Critic verdict** (if dispatched): `PASS` | `FAIL` | `INCONCLUSIVE`
- **Force critic by anko**: yes | no

## Scientific record (already on main via `auto(loop):` commits)

- Theorist analysis: `.claude/reports/theorist/turn_N.md`
- Implementer report: `.claude/reports/sim/turn_N.md`
- Judge verdict: `.claude/reports/judge/turn_N.json`
- (if any) Research brief: `.claude/reports/research/turn_N.md`
- (if any) Critic verdict: `.claude/reports/judge/turn_N_critic.md`

## Code changes on this branch

(Filled from `git diff main..HEAD --stat`.)

## What this PR promotes

1. **Physics finding** (1-3 sentences):
2. **Test/code addition** (file list):
3. **Why merge to main** (anko's reasoning, not the loop's):

## Falsification status

- **Directive's falsification_criterion**: <copied from turn_N.md §6>
- **§7 of sim/turn_N.md says**: CONFIRMED | REFUTED | INCONCLUSIVE
- **Reviewer's independent assessment**:

## Token cost

(From `.claude/reports/judge/turn_N.json` → `metrics.tokens_used.total`)

## Risks / open questions

- [ ] Does this break any pinned regression?
- [ ] Does this conflict with the "do NOT fix" list in `CLAUDE.md`?
- [ ] Does this depend on a `<RESEARCH_NEEDED>` query that's still
      open?

## Notes for future-anko

(Anything that the loop turn report doesn't capture — context,
intuition, follow-up ideas.)
