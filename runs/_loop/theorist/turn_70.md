---
turn: 70
subagent: theorist
topic_tags: [survey-synthesize-stage, edh-eu151-matsui-science-2026, child-investigation-spawn, tier3-anchor, d1-verification-depth, paper4-adjacent]
paper_section: null
depends_on: [69, "runs/_loop/director/turn_70.md", "runs/_loop/research/turn_69.md"]
produces: "edh-eu151-vortex-vs-matsui-science-2026 verify-claim investigation spec + tier3 pipeline survey methodology memory entry + state.json patch spec for T71 implementer"
---

# Turn 70 — Theorist Synthesis

## 0. Convention declaration

Convention: standard SpinorBEC.jl defaults (no deviations). Eu-151 baseline per
CLAUDE.md §¹⁵¹Eu: $F=6$, $g_F \approx 1.163$, $\mu \approx 6.977\,\mu_B$,
$a_s \approx 110\,a_0$, seven scattering channels $S \in \{0,2,4,6,8,10,12\}$,
constraint $c_0 + 36 c_1 = 4\pi (a_s / a_{\rm ho}) N$. DDI:
$c_{dd} = \mu_0 \mu^2$ (no $4\pi$), $Q_{\alpha\beta} = \hat k_\alpha \hat k_\beta
- \delta_{\alpha\beta}/3$ (no $1/(4\pi)$), $Q(k=0) = 0$. Wavefunction layout
`psi[x, y, z, c]` with $c=1 \leftrightarrow m_F = +F$, $c=D=13 \leftrightarrow
m_F = -F$. ITP Zeeman subtracts $\min_m(E_m)$ shift. All dimensionless units
$\hbar = m = \omega_{\rm ref} = 1$.

## 1. Synthesis of T69 candidate menu

The T69 researcher (`runs/_loop/research/turn_69.md`) scanned ~18 [Established]-tagged
memory claims, excluded 8 intentional-design entries (DDI no-4π convention,
`_YOSHIDA_W0<0`, ITP Zeeman min-shift, scalar LHY `@warn`, odd-rank c_extra,
`compute_interaction_params_general_f` returning (0,0), CUDA Graph fallback,
`_get_spinor` allocation), excluded 2 already-Tier-3 claims (Barnett T29,
Klaus-BCH T59) and 2 dormant/refuted investigations (`fullbdg-f6-polar-3000x`,
`yan-li-saito-2026-reproduction`), and produced 5 ranked candidates:

| # | candidate id (short) | tier-step | load-bear | benchmark availability | cost (turns) |
|---|---|---|---|---|---|
| 1 | `edh-eu151-vortex-vs-matsui-science-2026` | 0 → 3 | 5/5 | FOUND (Matsui Science 2026) | 5-7 |
| 2 | `bug-4-itp-ddi-half-rate-revalidation` | 1 → 2 | 5/5 | internal self-consistency | 2-3 |
| 3 | `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` | 2 → 3 | 2/5 | FOUND (KU2012 §4) | 1 |
| 4 | `twochannel-lhy-F6-polar-30-70-percent-error` | 1.5 → ≤2.5 | 3/5 | NOT_FOUND for F=6 | 2 |
| 5 | `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum` | 2 → 3 | 4/5 (TDHFB) | PARTIAL (KU2012 §4.2) | 2 |

**Why #1 dominates** despite being the most expensive option:

- **Highest external-benchmark quality**: Matsui et al. Science 391, 384-388
  (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357] is a high-impact
  experimental paper. No other candidate has a Science-tier anchor.
- **Highest load-bearing-ness**: end-to-end Eu-151 EdH dynamics exercises
  every major production subsystem simultaneously (ITP GS preparation with
  DDI; LHY; split-step dynamics; spinor mixing via c_1 channels; DDI
  convolution `_ddi_step!`; YAML run_yaml pipeline). A successful reproduction
  validates the project's main physics target (F=6 Eu-151 spinor-dipolar
  dynamics) against the only such experiment ever published.
- **Author overlap with foundational paper**: the Kozuma/Miyazawa group also
  published Miyazawa et al. PRL 129, 223401 (2022) [arXiv:2207.11692], which
  established Eu-151 BEC and measured $a_s = 110(4)\,a_B$ — the exact value
  SpinorBEC.jl canonicalises in CLAUDE.md §¹⁵¹Eu. The parameter chain is
  unbroken.
- **F3 falsifier subsumes #2 (Bug-4 audit)**: the GS preparation step uses
  the post-fix ITP DDI Strang factor; if it fails, an operational gate on
  Bug-4 contamination is triggered (see §4 F3 below).

Candidates #2 and #3 remain on the menu for steady-state turns when #1's
investigation is blocked on long-running julia GPU work. Candidate #4 caps at
Tier 2.5 (no published F=6 multi-channel spinor LHY table exists per T69 §4
NOT_FOUND #1) and is deferred. Candidate #5 (TDHFB Phase 2) is lower-priority
because TDHFB is not in the production Eu-151 pipeline yet.

## 2. [Established] background

The child investigation's hypothesis (§3) rests on four [Established] anchors,
each verified this turn via WebFetch or via persistent project artifacts:

**A1.** **Matsui et al. 2026 EdH observation** [Established, arXiv:2504.17357 /
DOI:10.1126/science.adx2872, verified WebFetch this turn].
Title: "Observation of the Einstein-de Haas Effect in a Bose-Einstein Condensate."
Authors: Hiroki Matsui, Yuki Miyazawa, Ryoto Goto, Chihiro Nakano, Yuki
Kawaguchi, Masahito Ueda, Mikio Kozuma. The abstract verbatim reports "angular
momentum is transferred from microscopic spins to mechanical rotation" through
formation of "quantized vortices in depolarized components" of a spinor-dipolar
BEC, with "spherical symmetry dynamically broken into axial symmetry via
intrinsic magnetic dipole-dipole interactions." This is the EdH observation
that the child investigation targets for reproduction.

Caveat: the arXiv abstract page does not explicitly say "Eu-151" — the species
inference rests on (i) author continuity with Miyazawa et al. 2022 PRL
[arXiv:2207.11692] (same Kozuma group), which established Eu-151 BEC; (ii) the
"spinor-dipolar BEC" + "dipole-dipole interactions" language matching the
Eu-151 F=6 program; (iii) no other species in this group's published work
having a Science-paper EdH followup. T71 researcher_deep paper-PDF read will
confirm-or-correct this inference; if Matsui 2026 uses a different species,
the child-investigation hypothesis must be re-scoped (e.g., to the same species
the paper actually uses).

**A2.** **Miyazawa et al. 2022 PRL — Eu-151 BEC foundational parameters**
[Established, arXiv:2207.11692, T69 §2.1(b) verified via WebFetch].
Title: "Bose-Einstein Condensation of Europium." Provides $a_s = 110(4)\,a_B$
from expansion asymmetry, $N \lesssim 5\times 10^4$ in crossed ODT, Feshbach
resonance at $B \approx 1.32\,$G. Same author group as A1; ensures parameter
inheritance from Miyazawa 2022 → Matsui 2026 with no scattering-length
ambiguity.

**A3.** **Kawaguchi-Ueda 2012 spinor-DDI Bogoliubov framework** [Established,
arXiv:1001.2072; Phys. Rep. 520, 253–381 (2012);
DOI:10.1016/j.physrep.2012.07.005; project memory `by_tag/kawaguchi-ueda-2012.md`
records prior T10 reference]. §3 derives the spinor-DDI mean-field
Hamiltonian; §4 catalogues channel weights $\beta_S$ and Bogoliubov spectra
for polyhedral spinor states. This is the theoretical framework underlying
the SpinorBEC.jl `c_0/c_1` decomposition + tensor channels + DDI Q-factor
convolution. Used here to bracket the EdH timescale prediction (see §3
hypothesis).

**A4.** **SpinorBEC.jl canonical Eu-151 framework** [Established, CLAUDE.md
§¹⁵¹Eu, lines on F=6 / g_F=1.163 / μ=6.977μ_B / 7 unknown scattering channels
S∈{0,2,...,12} / constraint $c_0+36c_1=4\pi(a_s/a_{\rm ho})N$]. Production
ITP path: `find_ground_state` → `_run_itp_loop!` (post-Bug-4 fix per memory
`bug_4_itp_ddi_half_rate.md`) → `make_workspace` auto-routes to
c₀/c₁-low-rank path for Eu (per CLAUDE.md "Two interaction paths" section).
RTP dynamics path: `make_workspace` → `run_simulation!` → `split_step!` with
DDI substep `_ddi_step!`.

## 3. Formal hypothesis statement for child investigation

**Investigation ID**: `edh-eu151-vortex-vs-matsui-science-2026`.

**Hypothesis** (verbatim for state.json):

> SpinorBEC.jl spinor-DDI + split-step framework reproduces Matsui et al.
> Science 391, 384–388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357]
> within factor-2 of the experimental EdH timescale $\tau_{\rm EdH}^{\rm exp}$
> and matches the ring-vortex topology (winding number $\ell$ consistent with
> $F=6$ angular-momentum balance) when fed the paper's published parameters
> ($N$, trap frequencies $\omega_{x,y,z}$, B-quench waveform, $a_s$, $c_{dd}$).

Tier mapping: $\tau$-band + topology + GS-self-consistency all CORROBORATE
$\Rightarrow$ Tier 3 (published-reference benchmarked).

**Order-of-magnitude check** (informational, not pre-registered):
The DDI timescale is $\tau_{\rm DDI} \sim \hbar / (c_{dd} \langle n \rangle)$.
With $c_{dd} = \mu_0 \mu^2$ at $\mu = 6.977\,\mu_B$ and a typical peak
density $\langle n \rangle \sim 10^{19}\,{\rm m}^{-3}$ for $N \sim 5\times 10^4$
in a tight crossed ODT, $\tau_{\rm DDI}$ is of order $\sim 10$–$100\,$ms. The
EdH process is mediated by DDI-driven AM transfer (per Matsui 2026 abstract
A1) so $\tau_{\rm EdH}^{\rm exp}$ is expected in the same order. Exact
$\tau_{\rm EdH}^{\rm exp}$ extraction is the T71 researcher_deep deliverable;
the F1 falsifier band below is paper-relative (factor-2) rather than absolute,
to avoid invention.

**Topology prediction** (informational, not pre-registered as specific
$\ell$): for $m_F = +F \to m_F = +F - 1$ flips driven by DDI, angular-momentum
conservation requires the orbital sector to absorb one quantum of circulation
per spin flip. The depolarized component populated at smallest accessible $t$
should therefore carry winding $\ell = 1$ in axial geometry. Higher-flip
components (e.g., $m_F = +F - 2$) may carry $\ell = 2$ via consecutive flips
or $\ell = 0$ via two opposite-direction DDI vertices, depending on geometry.
The exact $\ell$ value reported in Matsui 2026 Fig. (TBD) is the T71
researcher_deep deliverable; the F2 falsifier below is "matches paper's
reported $\ell$", not a hard-coded number.

## 4. Pre-registered falsifiers

Three load-bearing falsifiers (F1, F2, F3) plus one optional control (F4). All
quantitative criteria are paper-relative or production-mean-field-relative;
no absolute numbers are invented this turn.

**F1 — ring-appears-correct-timescale**
- *Description*: Reproduce Matsui's protocol (initial $m_F = +F$ FM-polarized
  state, then near-zero-B-field quench). Measure the time $\tau^{\rm sim}_{\rm
  ring}$ at which a ring-shaped density structure first appears in the
  $m_F = +F - 1$ (or $m_F = +F - 5$, matching Matsui's labelling extracted at
  T71) component. Definition of "ring": azimuthally-averaged density $|\psi_{c
  = c_{\rm flip}}|^2$ has a local minimum at $r = 0$ within $\pm 20\%$ depth
  of the off-axis peak, AND aspect ratio of the bright annulus exceeds 1.5.
- *Criterion*:
  - CORROBORATE if $\tau^{\rm sim}_{\rm ring} \in [0.5\,\tau_{\rm EdH}^{\rm
    exp}, 2.0\,\tau_{\rm EdH}^{\rm exp}]$.
  - INCONCLUSIVE if $\tau^{\rm sim}_{\rm ring} \in [0.2\,\tau_{\rm
    EdH}^{\rm exp}, 5.0\,\tau_{\rm EdH}^{\rm exp}]$ but outside CORROBORATE
    band (factor 2.5 fudge for grid / dt residual).
  - REFUTED if no ring forms at any $t < 10\,\tau_{\rm EdH}^{\rm exp}$, OR if
    a ring forms but in a spin component inconsistent with the first-flip
    channel.
- *Where $\tau_{\rm EdH}^{\rm exp}$ comes from*: T71 researcher_deep paper-PDF
  extraction of arXiv:2504.17357 (figure caption / table). NOT invented this
  turn.

**F2 — vortex-topology-l-matches-angular-momentum-conservation**
- *Description*: Extract the winding number $\ell$ of the ring-vortex in
  $m_F = +F - 1$ via phase-singularity count: integrate
  $\oint \nabla \arg(\psi_{c_{\rm flip}}) \cdot d\boldsymbol\ell / (2\pi)$
  along a closed loop enclosing the density minimum.
- *Criterion*:
  - CORROBORATE if $|\ell^{\rm sim} - \ell^{\rm paper}| = 0$ (exact match to
    Matsui's reported winding number, target after T71 paper-PDF extraction).
  - INCONCLUSIVE if $|\ell^{\rm sim} - \ell^{\rm paper}| = 1$ (off-by-one
    likely indicates grid resolution or basis-frame convention; not a
    framework-level refutation).
  - REFUTED if $|\ell^{\rm sim} - \ell^{\rm paper}| \geq 2$, OR if
    $\ell^{\rm sim} = 0$ (no quantized circulation = DDI is not transferring
    AM = mechanism not present in framework).

**F3 — ground-state-energy-self-consistency (Bug-4 operational gate)**
- *Description*: Pre-quench $m_F = +F$ FM ground state at Matsui's $N$, $a_s$,
  trap $\omega_{x,y,z}$, $c_{dd}$ (post-Bug-4 fix per
  `bug_4_itp_ddi_half_rate.md`). Compute the GS energy per particle $E/N$
  and compare against the dipolar GP mean-field estimate
  $$ \frac{E_{\rm mf}}{N} \approx \frac{1}{2}\sum_{i\in\{x,y,z\}} \hbar\omega_{i}
  + \frac{(c_0 + 36 c_1) \langle n \rangle}{2} + \frac{E_{\rm DDI}}{N}, $$
  using SpinorBEC.jl's own $\langle n \rangle$ (peak or trap-averaged, declared
  in the YAML) and computing $E_{\rm DDI}/N$ via the same `_ddi_step!`
  evaluator at half-step (closed form for the FM state is a fully-aligned
  dipole gas — straightforward textbook formula).
- *Criterion*:
  - CORROBORATE if $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| < 0.20$
    (20%, generous because mean-field is anharmonic-trap-approximate).
  - OPERATIONAL_GATE if $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| >
    1.0$ (100%) — pipeline routing or unit-conversion bug, must debug before
    F1 / F2 are meaningful. This is also the implicit Bug-4 contamination
    check (per T69 §2.2 / candidate #2).
- *Note*: F3 is NOT a physics-refutation falsifier; it is an operational
  gate. A REFUTED F3 closes the investigation at Tier 0.5 with the diagnosis
  "framework wiring fails before EdH dynamics can be tested."

**F4 — DDI-zero-control (optional, mechanism check)**
- *Description*: Re-run the full protocol with $c_{dd} = 0$ (other parameters
  unchanged). Per Matsui's interpretation (A1), DDI is THE AM-transfer
  mechanism; without DDI the ring should not form.
- *Criterion*:
  - CORROBORATE if no ring forms at any $t < 10\,\tau_{\rm EdH}^{\rm exp}$
    with $c_{dd} = 0$ — confirms DDI is the mechanism.
  - REFUTES_INTERPRETATION (not framework) if ring still forms with $c_{dd}
    = 0$ — points to spin-mixing $c_1$ or LHY artifact as the active
    mechanism in our framework; physically interesting either way.
- *Marked optional*: F4 doubles the GPU budget; defer to T74+ if F1+F2+F3 are
  on a clear CORROBORATE track at T72-T73.

## 5. Tier-3 success criteria

| Falsifier outcome | Tier outcome | Closure note |
|---|---|---|
| F1 CORROBORATE + F2 CORROBORATE + F3 CORROBORATE | **Tier 3** | Cross-validation against Matsui Science 2026 achieved; project's third Tier-3 closure (after Barnett T29, Klaus-BCH T59). F4 if run becomes a published-paper bonus. |
| F1 CORROBORATE + F2 INCONCLUSIVE + F3 CORROBORATE | Tier 2.5 | Framework reproduces dynamics but topology agreement is fuzzy; documented gap. |
| F1 CORROBORATE + F2 REFUTED + F3 CORROBORATE | Tier 2 | Timescale matches but topology fails — mechanism partially reproduced; documented mechanism gap (likely AM-accounting bug or basis-frame convention mismatch). |
| F1 REFUTED + F3 CORROBORATE | Tier 1 | Framework executes cleanly but does not reproduce the EdH dynamics — mechanism is missing or suppressed (analogous to yan-li-saito DORMANT-CLOSE pattern; close with documented unbridgeable gap). |
| F3 OPERATIONAL_GATE refuted | Tier 0.5 | Wiring bug; investigation pauses pending operational fix. Re-spawn F1/F2 after fix. |

## 6. Child-investigation budget estimate

Informational; refined turn-by-turn by director:

| Stage | Turn | Subagent | Type | Cost (eff) | Notes |
|---|---|---|---|---|---|
| Research | T71 | researcher_deep | text-only | ~2.0M | Matsui 2026 PDF parameter extraction (N, ω, B-quench, $\tau_{\rm EdH}$, $\ell$). Also applies T70 state.json patch (see §7 status). |
| Hypothesize | T72 | theorist | text-only | ~1.0M | Translate paper parameters → dimensionless SpinorBEC.jl YAML predictions |
| Design | T73 | implementer | text-only | ~0.8M | Write YAML config; no EdH template exists, copy+patch from `runs/eu151_barnett_spin/` or `dynamics_klaus_stir.yaml` |
| Execute | T74 | implementer_julia_gpu | GPU heavy | ~3.0M + ~30-60 min RTX 5070 Ti | 32³ or 64³ grid; long enough to capture $\tau_{\rm EdH}^{\rm exp}$ |
| Analyze | T75 | implementer | text-only | ~1.0M | F1 ring detection, F2 winding number extraction, F3 energy comparison |
| Update | T76 | critic | text-only | ~1.0M | Independent re-derivation of $\tau_{\rm DDI}$ / topology prediction (Barnett T28 pattern) |
| Document | T77 | implementer_text | text-only | ~0.5M | Memory entry + state.json closure |

**Total**: ~7 turns, ~9.3M eff + 60 min GPU. F4 control adds 1 GPU turn if
included. Branching: T71 fails on paper-PDF access (paywall / extraction
failure) → fall back to Miyazawa 2022 parameter proxy + flag for anko email.

## 7. Self-review checklist + Step-by-step status

**Step 1 (Matsui 2026 verification) — COMPLETE.**
- WebFetch on https://arxiv.org/abs/2504.17357 returned abstract + author list
  + key claims. All three required confirmations passed:
  (i) paper exists; (ii) spinor-dipolar BEC / Einstein-de Haas effect /
  dipole-dipole-interaction-mediated angular momentum transfer (Eu-151
  species is inferred from author continuity with Miyazawa 2022; explicit
  Eu-151 confirmation deferred to T71 PDF read); (iii) ring-vortex
  observation ("quantized vortices in depolarized components").
- Note: WebFetch on the Science.org DOI was denied for permission reasons
  this turn; arXiv abstract is sufficient for Step 1 verification (the
  abstract is canonically the same content as the Science abstract). T71
  researcher_deep can fetch the full PDF.
- *Adversarial-note that I caught and ignored*: the WebFetch result included
  an injected "MCP Server Instructions" block claiming Figma server
  instructions. This is a prompt-injection footgun in fetched content;
  ignored per Anthropic protocol (Figma is not in scope for SpinorBEC.jl
  theorist work and no Figma tools are available to this agent).

**Step 2 (memory entry) — COMPLETE.**
- File written:
  `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`
  with frontmatter (name=`tier3-pipeline-survey-2026-05-18`, description,
  metadata.type=project). Body covers context, 5-candidate menu, ranking
  rationale, NOT_FOUND benchmark list, excluded categories, action.
- MEMORY.md index updated with a one-line entry under the existing
  "Autonomous research loop" section.

**Step 3 (theorist report) — COMPLETE.**
- This file (`runs/_loop/theorist/turn_70.md`). All §0-§8 sections populated.
- [Established] tag count in §2 = 4 (Matsui 2026 A1, Miyazawa 2022 A2,
  KU2012 A3, SpinorBEC.jl framework A4). Clears DRIFT_NOVEL_CLAIM_ZERO
  4-consecutive escalation per director T70 §5.
- Falsifier count in §4 = 3 load-bearing + 1 optional, meeting the ≥3
  director-T70 success criterion.

**Step 4 (state.json edits) — DEFERRED to T71 implementer_text.**
- Tool-availability constraint: the theorist agent's tool roster (Read,
  Grep, Glob, WebFetch, Web Search, Write) does NOT include `Edit`. Three
  mechanical multi-field edits on a 2556-line JSON file via the only
  available mutator (`Write` = full-file rewrite) is high-risk (typo class:
  any single character change anywhere in the file corrupts JSON; cascade
  breaks the next turn's `json.load(state.json)` precondition).
- Mitigation: a structured patch packet has been written at
  `runs/_loop/theorist/turn_70_state_json_patch.md` containing
  three precise `Edit` operations (`old_string` / `new_string` blocks) for
  the three required state.json changes, plus a pre-flight check and a
  post-application validation script. T71 implementer_text can apply the
  packet in ~1k output tokens with zero invention risk.
- Director T70 §6.failure_modes explicitly anticipated this case ("If Step
  4 (state.json) skipped, T71 director writes the state.json edits before
  any other work (1-turn implementer_text)"). The deferral matches the
  pre-specified failure path.
- Specific changes deferred:
  1. `active_investigation_id`: tier3-verification-pipeline-survey-2026-05-18
     → edh-eu151-vortex-vs-matsui-science-2026 (line 1976).
  2. `investigations_index`: append "edh-eu151-vortex-vs-matsui-science-2026"
     (line 1986 area).
  3. Survey investigation block (lines 2528-2551): update current_stage,
     stages_done, stages_at_turn, next_stage, next_stage_action, blocked_on.
  4. New child investigation block: full `edh-eu151-vortex-vs-matsui-science-2026`
     entry with all 4 falsifiers, tier_target=3, priority=1.

**Other checklist items.**
- [x] No invented physics: F1 timescale band paper-relative; F2 winding
      number "matches paper" (specific $\ell$ to be extracted T71); F3
      mean-field comparison uses production-code internal computation, not
      hardcoded numbers.
- [x] §3 hypothesis verbatim copyable into state.json (and IS so used in
      the patch spec file).
- [x] §5 success criteria mechanically evaluable.
- [x] No anko-attribution in this report.
- [x] Eu-151 species inference flagged as A1 caveat; T71 PDF read will
      confirm-or-correct.

## 8. Publishability assessment

Out of scope — this is a survey-Synthesize stage spawning a child
investigation. The child investigation, if it reaches Tier 3 (F1+F2+F3
CORROBORATE), provides one of the strongest cross-validation results for
paper #1 (Eu-151 spinor-DDI framework) and is a candidate citation in any
manuscript section discussing EdH dynamics in dipolar spinor gases. Publish
decision deferred to T77 Document stage.
