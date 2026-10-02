# Prior art — agent_instructions

> **FROZEN 2026-10-01.** A snapshot of the open work on agent_instructions as of that
> date. Re-run the generator when picking the topic up again; existing
> dispositions are preserved.

Keywords: agents, claude, documentation, instructions. Regenerate with
`python3 scripts/prior_art.py --topic agent_instructions --keywords agents claude documentation instructions`.

Dispositions: `unread`, `read`, `unrelated`, `superseded`, `depends`

| ref | disposition | what | note |
|---|---|---|---|
| #510 | read | PR: shorten development checks with explicit smoke tests | Open CI-latency work overlaps CLAUDE.md, ci.yml, and test/_tiers.jl. Keep this branch's documentation-input detection and audit regression gates when reconciling; this change does not adopt that PR's smoke/nightly policy. |
| origin/claude/document-capabilities-JGXFC | read | branch:  | Tip fa4ff554 documents capabilities; no unmerged diff against main. Current README and execution code were checked. |
| origin/claude/implement-tdhfb-mx4kV | unrelated | branch:  | Tip 78892872 fixes TDHFB operator continuations; no agent configuration change is proposed here. |
| origin/claude/spinor-lhy-correction-OXkxG | unrelated | branch:  | Tip bff0c3af changes CI Julia support and a DDI constructor, not active role instructions. Current LHY authority is retained. |
| origin/claude/stoic-edison-mt7myi | unrelated | branch:  | Tip e040e261 concerns rotating-basis retirement and Hamiltonian relocation, not the instruction entry points. |
| origin/claude/thorough-refactoring-3XkYO | unrelated | branch:  | Tip 5f8549de and branch diff concern analysis sweep extraction and test tiering; they do not change agent instructions. |
