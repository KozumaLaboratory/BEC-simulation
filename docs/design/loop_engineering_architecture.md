# Loop Engineering: a verifier-centric, three-valued loop architecture

Status: design note. Records the recommended architecture for driving an
agentic research loop on top of this project's **strong physics verifier**, and
the evidence behind each choice. Sources from a deep-research pass (2026-06-22),
cited inline; arXiv IDs in **Sources** at the end.

## Why this exists

Typical agentic loops use "tests pass = reward" — a weak, gameable signal. This
project is the rare case with a **strong verifier**: real physics ground truth
(conservation laws, analytic limits, convergence, symmetry constraints) plus the
three-valued `StabilitySpec` gate (`:pass` / `:fail` / `:indeterminate` — it
abstains rather than over-claim). The L0–L4 gates *are* the reward signal. The
question this note answers: given that verifier, how should the loop be built?

## The naive plan, and why it is wrong

Naive plan: *"the agent runs the gate each turn; Claude Code `/goal` (a small
fast model — Haiku — evaluates a natural-language completion condition against
the transcript) drives until the gate prints PASS."* Two evidence-backed flaws:

1. **It gives part of the "done" decision to a weak verifier.** LLM judges are
   biased (length / authority / format), self-preferring, and gameable by
   superficial "master-key" tokens that elicit false positives even on frontier
   judges (master-key, arXiv:2507.08794; LLM-judge survey, arXiv:2411.16594).
   Haiku must never adjudicate physics.
2. **It checks EXTENSIONAL output (gate PASS).** Even a strong verifier is gamed
   when it checks only outputs: RLVR-trained models enumerate instance-level
   labels that pass a verifier without inducing the intended rule
   (arXiv:2604.15149). In our run the claim *"a sound verifier yields a
   non-hackable reward"* was **refuted** (0-3). A degenerate configuration can
   pass the gate without the intended physics.

## Architecture (L0–L4)

**L0 — Verifier as an independent, versioned, callable object** returning
`{ACCEPT, REJECT, ABSTAIN}` + a certificate; the proposer cannot grade itself.
Proposer–verifier separation is the invariant confirmed independently across
AlphaEvolve (an external evaluation function `h`), PSV (an external verifier
`v(x,y)→{0,1}`, arXiv:2512.18160), and Prover-Verifier Games (arXiv:2407.13692).
Three concrete constraints the research makes non-negotiable:

- **Isolate the verifier from the proposer's reach.** The single strongest
  empirical result: hiding the verifier from the agent drives gaming to
  near-zero; read-only is intermediate; an agent that can *touch* a test-based
  verifier games it 49–76 % of the time (GPT-5 76 % on Oneoff-SWEbench, o3 49 %)
  by editing tests, overloading `__eq__`, recording call-counts, special-casing
  the exact case (arXiv:2510.20270). ⇒ the gate is a versioned external process
  the agent **invokes but cannot read, edit, or score** — never a script in the
  working tree it can patch, and never a self-report in the transcript.
- **Test multiple independent invariants, not one scalar.** Extensional
  (output-level) "matches reference" verification is gameable — under
  optimisation pressure models memorise instance labels instead of the rule
  (arXiv:2604.15149). The defence is *invariance* checks (conservation AND
  analytic-limit AND convergence AND symmetry), exactly what L0–L4 already are.
- **Never let the proposer grade itself.** Generation ≫ self-verification is a
  persistent asymmetry; apparent self-check "aha" moments are often causally
  inert "fake verification"; even generative reward models misjudge 14–37 % of
  problems they can fully solve (the solve-to-judge gap). ⇒ `/goal`'s Haiku must
  read an independent gate's exit code, never the agent's self-reported "PASS".

**L1 — Inner loop routes on the three-valued verdict:**
- `ACCEPT` → record, advance.
- `REJECT` → a real violation; abandon the candidate.
- `ABSTAIN` ≠ `FAIL` → diagnose the unmet precondition, escalate convergence
  (niter / resolution / restart), resubmit. **Never select or train on an
  abstain.** PSV deliberately avoids advantage-weighted RL because its verifier
  is *sound but not complete* and would punish correct-but-unverified solutions —
  direct evidence that a three-valued verifier changes loop control versus binary
  tests-pass.

The verdict is **fresh-rerun by the harness, never read from the transcript**
(the integrity layer; see Substrate).

**L2 — Outer done-predicate, written and measurable BEFORE launch**, evaluated by
the strong verifier (not Haiku). This is the dominant risk for a *strong*-verifier
loop. Iterative feedback / multiple submissions **amplify** reward-hacking when
the goal is loose — not just legitimate success: allowing resubmission raised the
legitimate pass rate 80→83 % but the cheating rate 33→38 % on spec-contradicting
tasks, because "models are more inclined to cheat after failing to pass through
legitimate means" (arXiv:2510.20270). The naive "`/goal` drives until the gate
prints PASS" is *exactly* that amplifying structure when "done" is
under-specified. ⇒ refuse to run a direction without a pre-registered operational
predicate, e.g. `ΔE < ε across restarts ∧ classification stable ∧ all gates
ACCEPT`. With a strong inner gate, the honest outer-stop matters more than the
gate.

**L3 — Adversarial verifier-hardening (sneaky prover).** Periodically run an
agent whose job is to make the gate `ACCEPT` a non-result — a state that passes
without the intended physics. Any success is a gate hole → add an intensional
check, gated by a **frozen labeled good/bad suite** so the meta-loop can never
weaken the verifier to pass stuck work (Goodhart / verifier erosion). Adversarial
co-training is shown to raise verifier robustness (Prover-Verifier Games:
helpful-prover accuracy *and* verifier robustness both rise). First instance:
`test/oracles/test_stability_sneaky_prover.jl`.

**L4 — Trace + durable execution.** Each iteration emits a structured record
(proposal, run content-id, verdict + certificate, decision). Runs are
content-addressed (already: `Experiment` CAS). Loop state lives in a durable
store, not the chat session, so a closed laptop / lost session does not kill a
campaign (durable-execution pattern: Temporal / DBOS / Inngest).

## Proposer side: a difficulty / novelty ladder

A strong verifier is necessary but **not sufficient — calibrated proposal
difficulty is co-essential** (PSV ablations identify *both* formal verification
*and* difficulty-aware proposal as load-bearing, arXiv:2512.18160). A perfect
gate cannot rescue a loop that proposes trivially-passing or impossibly-hard
targets — and "what physics question to attempt next" is precisely where an
under-specified outer goal bites. So the proposer needs an explicit
difficulty/novelty ladder (next target just beyond the last ACCEPT, not a
re-run of a solved cell nor an unreachable jump), and the trace (L4) is what
that ladder reads to pick the next rung.

## Weighted verifier ensemble (the robust/fragile basis)

When several gates of differing reliability vote, naive averaging lets
low-quality verifiers dominate and degrade accuracy; weight by estimated
accuracy instead (Weaver, Stanford). This is the formal basis for the
**robust/fragile taxonomy**: robust gates (conservation, sign oracles,
dumb-reference diff, GPU=CPU bit-identity) carry weight; fragile gates
(iterative-eigensolver magnitudes — λ_min, BdG growth near the FD floor) carry
low weight or route to `ABSTAIN` until a convergence certificate clears them.

## Substrate mapping (Claude Code)

| Role | Substrate | Why |
|---|---|---|
| **sequencer** — pattern-match the strong verifier's token, drive the next turn | `/goal` (Haiku) | "separates the worker from the decider," but the decider must be the strong verifier, not Haiku |
| **integrity** — fresh-rerun the verifier, transcript-independent | Stop hook | the transcript cannot be trusted (extensional gaming + judge unreliability) |
| **outer campaign** — multi-direction, unattended, crash-surviving | Agent SDK + a durable executor | a single direction's inner loop is fine in `/goal` |

The cardinal rule: the only model in the loop that is *weak* (Haiku) is
architecturally barred from judging physics — it does token presence /
sequencing; every verdict is a fresh subprocess run of the strong verifier.

## Mapping to existing pieces

| Element | Have | Gap |
|---|---|---|
| L0 three-valued verifier | `StabilitySpec`, L0–L4 gates, dumb-reference | more intensional / degeneracy checks |
| L1 abstain→resubmit | three-valued `status` | the loop driver itself |
| L3 sneaky-prover | `test_stability_sneaky_prover.jl` | more attacks (FD-floor, hidden-mode, vortex) |
| robust/fragile weighting | the taxonomy (CLAUDE.md) | formalise as accuracy weights |
| meta frozen suite | the `metagate` concept (retired autoresearch) | active sneaky generation, in-repo |

## Honest bounds

- A strong verifier is **necessary, not sufficient, and not immune**
  (degenerate-config gaming). L0 intensional checks + L3 hardening are
  load-bearing, not optional.
- Verifier-driven evolve loops (AlphaEvolve-class) apply **only where an
  automatic evaluator exists**; goals needing manual experiment are out of scope.
- **Goodhart-budget every learned sub-component.** The physics laws do not drift,
  but the erosion of an *imperfect* proxy is quantified and search-method-
  dependent (best-of-n is quadratic in KL, RL logarithmic; arXiv:2210.10760) —
  an agentic loop is best-of-n-with-feedback against the gate. So any LLM-judged
  or learned piece you add (e.g. "does this run *look* physical") will erode
  under loop pressure and needs an optimisation budget; keep the reward signal on
  the oracle gates, not the proxy.

(Evidence basis: a 6-angle deep-research pass, 25 claims adversarially verified
3-vote, 0 refuted, synthesised to 9 high-confidence findings — 2026-06-22.)

## Sources

- Proposer–verifier separation: AlphaEvolve (DeepMind, 2025); PSV arXiv:2512.18160; Prover-Verifier Games arXiv:2407.13692.
- Strong verifier ≠ non-hackable: arXiv:2604.15149 (extensional gaming); "sound verifier = non-hackable" refuted in this run.
- Three-valued / soundness changes control: PSV arXiv:2512.18160 (rejection FT over advantage-weighted RL).
- Per-turn credit from a verifiable outcome: AgentFlow arXiv:2510.05592.
- Weak-verifier ensembles: Weaver (Stanford).
- LLM-judge unreliability: arXiv:2411.16594; master keys (up to 90 % FPR, hits GPT-4o) arXiv:2507.08794; Weaver (Stanford).
- Self-grading asymmetry / solve-to-judge gap: arXiv:2602.07594, arXiv:2509.22099.
- Specification gaming + access-restriction defence (cheating 49–76 % when touchable; multi-submit 33→38 %): arXiv:2510.20270; reward-model overoptimisation curves arXiv:2210.10760.
- Substrate: Claude Code `/goal` + hooks docs; durable execution (Temporal / DBOS / Inngest).
