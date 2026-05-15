# T9 Critic Audit — T8 Paper #4 §IV.E + §IV.F (commit 2bceceb)

## Result

**VERDICT: WEAK_PASS**

Anko may merge `2bceceb` → `main` on the manuscript content itself.
Four pre-submission improvements should be addressed before PRR/PRX
submission; none affect technical correctness of the manuscript text.
The most important follow-up is a small docstring edit at
`dispatch.jl:115-121` to resolve a documentation/manuscript narrative
inconsistency (T7's planned mechanism-audit comment block was deferred
out of T8's text-only scope).

## First dispatch attempt — INCONCLUSIVE (procedural blocker, resolved)

The first critic dispatch could not read commit `2bceceb` via the Read
tool (git object store inaccessible to `Read`). Orchestrator materialized
the diff and full file:

- `runs/_loop/_local/turn8_paper4_diff.txt` (226 lines) — `git show 2bceceb` diff.
- `runs/_loop/_local/turn8_paper4_full.md` (531 lines) — full Paper #4 main.md at commit 2bceceb.

Orchestrator also confirmed via `git show --stat 2bceceb` that T8 commit
ONLY modified the manuscript file (202 +); no `dispatch.jl` changes.

## Second dispatch attempt — full audit

### Per-audit verdicts

| Audit | Verdict | Brief |
|---|---|---|
| Audit-1 (claim-tier fidelity) | PASS | 3000× attribution framed as [Plausible] / order-of-magnitude estimate; matches T7 §4 tiers. |
| Audit-2 (η H η = H†) | PASS | Eq. E1, orbit R/I/Q/Z table, orbit-I stays imaginary — all faithful to T7 §2.1. |
| Audit-3 (mechanism i+iii, 3000×) | PASS | Three-step mechanism enumerated; empirical ratio 2.527e6/880.5 ≈ 2870× cited; (ii) correctly noted as structurally absent. |
| Audit-4 (T5 rejected mechanism) | PASS | T5 Nambu-doubling described as tempting-but-wrong via orbit-I theorem (not ad-hoc). |
| Audit-5 (citations) | WEAK_PASS | One minor over-attribution: Colpa Thm 3.1 conflated with van Hemmen 1980 §II for spectrum pairing. Other 4 citations consistent. |
| Audit-6 (F-δ spec, §IV.F) | PASS | H_S = η H_bdg, eigen(Hermitian), signature test (D, D), deferred to post-sweep — matches T7 §2.4. |
| Audit-7 (placement coherence) | PASS | §IV.D → §IV.E → §IV.F → §V flow preserved; intro motivates TWA-vs-LHY framing. |
| Audit-8 (PRR/PRX referee acceptance) | WEAK_PASS | Two concerns: (a) §IV.E.3 omits T7 §3 Check 4 overshoot caveat; (b) §IV.F "independently publishable" claim self-promotional. |
| Audit-9 (dispatch.jl cross-reference) | PASS w/ caveat | T8 quotes existing @warn verbatim (consistent). But docstring narrative at lines 115-121 still describes T5-rejected mechanism. Doc-hygiene fix needed. |

### Specific findings (numbered)

1. **(Audit-9) Source/manuscript narrative inconsistency.** `dispatch.jl:115-121` comment still says "λ<0 BdG modes breaking Petrov's UV regularisation" (T5-rejected mechanism), while Paper #4 §IV.E.3 says "orbit-I pairs ... real(ev) is zero modulo LAPACK noise — does not become a large positive real number via Nambu doubling." T7's directive §6 explicitly anticipated inserting a `## Mechanism (turn 7 audit)` 5-10 line comment block at this location to *supplement* the @warn — but T8 deferred this code edit (scope: text-only manuscript edit). Recommendation: a follow-up turn lands T7's comment block at `dispatch.jl:115-121`.

2. **(Audit-5) Minor citation conflation.** §IV.E.5 attributes spectrum pairing λ → -λ* jointly to Colpa 1978 Thm 3.1 and Lieu 2018 Tbl I. T7 §2.3 attributed the spectrum-pairing theorem to Colpa + van Hemmen 1980 §II (with van Hemmen being the more precise source). Pre-submission fix: add van Hemmen 1980 to References or narrow Colpa's attribution to the symplectic diagonalization precondition.

3. **(Audit-8) Honesty caveat on order-of-magnitude estimate.** T7 §3 Check 4 noted the §2.2(i) estimate overshoots empirical by ~1000× ("not all 24 modes exceed the threshold simultaneously"). §IV.E.3 says "~10^6, consistent in sign and scale" without mentioning the overshoot caveat. Pre-submission fix: add one sentence noting the ~10^6 is upper-bound; precise mode-decomposition deferred.

4. **(Audit-8) "Independently publishable" claim in §IV.F.** Line 204-205 calls F-δ "an independently publishable numerical-methods result." Overly self-promotional for a Methods subsection. Pre-submission fix: soften to "an implementable infrastructure upgrade and natural follow-up."

### Merge recommendation

Anko **may merge with confidence** on the manuscript content itself
(Audits 1, 2, 3, 4, 6, 7, 9 pass; Audit 5 minor citation tightening;
Audit 8 pre-submission polish items don't affect correctness).

Before PRR/PRX submission, address Findings 1-4. Finding 1 (source
docstring narrative) is the most important and can be a small follow-up
implementer turn — either an editorial replacement of `dispatch.jl:115-121`
with T7's `## Mechanism (turn 7 audit)` comment block, or an explicit
pointer from the docstring to Paper #4 §IV.E. Documentation hygiene,
not physics.

### Out-of-scope notes

- Did not WebFetch any cited papers (per protocol).
- Did not propose new physics; all findings are at editorial / cross-reference / citation-precision level.
- Did not audit Paper #4 §I-IV.D (pre-T8 content out of scope).
- Did not execute julia (per protocol).
- MCP Figma system reminders ignored as off-task throughout audit.

### Files referenced (absolute paths)

- `/home/suzume/workspace/BEC-simulation/runs/_loop/_local/turn8_paper4_diff.txt`
- `/home/suzume/workspace/BEC-simulation/runs/_loop/_local/turn8_paper4_full.md`
- `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_7.md`
- `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_6_critic_audit.md`
- `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_5.md`
- `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_8.md`
- `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy/dispatch.jl` (lines 110-140)
