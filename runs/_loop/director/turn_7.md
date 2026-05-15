# Turn 7 — Director Report

## 1. Project state snapshot

- **T5→T6 cascade landed cleanly**: T5 researcher (`runs/_loop/research/turn_5.md`)
  proposed a Nambu-doubling mechanism for the F=6 polar FullBdGLHY 3000×
  bug; T6 critic (`runs/_loop/judge/turn_6_critic_audit.md`, VERDICT=FAIL,
  status `CRITIC_FAIL`) **REJECTED** the mechanism with high confidence,
  citing the textbook Bose pseudo-Hermitian symmetry $(\lambda,
  -\lambda^*)$: imaginary physical Bogoliubov eigenvalues stay imaginary in
  the Nambu 2D×2D matrix — they do NOT get re-cast as large positive reals.
  T5's "C1 + C2" claim is wrong, T5's recommended F-α gate is built on a
  wrong picture (it may be empirically curative but for the wrong reason
  and is therefore **not paper-safe**).
- **Critic explicitly hands off to theorist**: §RECOMMENDED ACTION in
  `runs/_loop/judge/turn_6_critic_audit.md` last paragraph reads
  verbatim: *"Reject, return to theorist with: 'Derive the eigen-spectrum
  of H_bdg = [[L,M],[-M*,-L*]] for a Bose mean-field-unstable GS.
  Specifically, prove or disprove ... Provide the citation chain
  (Castin-Dum / Colpa / Blaizot-Ripka) for the pseudo-Hermitian
  eigenstructure.'"* My T6 dispatch's `if_fails_next_step` field
  pre-committed: *"If critic returns REJECTED with a clear alternative
  mechanism, T7 dispatches implementer-julia ... ; if INDETERMINATE, T7
  dispatches theorist."* The critic's verdict is REJECTED **with an
  ambiguous correct mechanism** (three competing hypotheses (i)/(ii)/(iii)
  in §Corrected mechanism statement, none ratified) — closer to
  INDETERMINATE-with-targeted-question than REJECTED-with-clean-alternative.
  Theorist is the correct route, not implementer.
- **Manuscript pulse (unchanged from T6)**: Paper #1 LaTeX-ready;
  Paper #3 Lemma 1 reach F=3-14 (T4 branch `auto/turn_4_lemma1-f14-extension`
  / commit `be6a472` still UNMERGED); Paper #4 still blocked by the
  FullBdG F=6 polar bug. The T7 theorist output, if it produces a
  citation chain + corrected eigen-spectrum, becomes a Paper #4 method
  note artifact (high value).
- **Hard environment constraint, unchanged**: seed.md (2026-05-15 light-mode)
  forbids julia process spawn. Anko's Klaus phi-magnetostir sweep still
  running (~18 GB RAM, 4 julia processes). Theorist is Read/Write only —
  julia-safe per seed §"Director MAY dispatch".
- **Rotation status**: T0-T4 implementer-shape, T5 researcher, T6 critic.
  Theorist last fired at T3 (compute_sympy infra) — not in the last 3 turns.
  Per §B4 "no more than 2 same-subagent in a row" + seed stop conditions:
  theorist is cleanly available (the *opposite* of the §B4 trap, since
  the prior 3 turns are researcher/critic — wholly different shapes).
- **Phase 2 directive-shape coverage as of T6**:
  `modify_code` ✅ (T0-T4),
  `compute_sympy` ✅ (T3 + T4),
  `researcher` ✅ (T5),
  `critic` ✅ (T6),
  `run_experiment` ❌ (forbidden this session),
  pure-theorist-Read/Write ❌ (T0-T3 all routed through implementer;
  T7 would be the first standalone-theorist dispatch).

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T4 | Lemma 1 General-S F=14 O:A_1 extension (compute_sympy) | PASS | `auto/turn_4_lemma1-f14-extension` / `be6a472`: Paper #3 +1 row, S=20 exact-zero node footnote, falsification CONFIRMED. **Branch still unmerged.** | Yes — manuscript-extending, infra-exploiting. |
| T5 | FullBdGLHY F=6 polar literature audit (researcher) | RESEARCHER_ONLY | `runs/_loop/research/turn_5.md`: 8 refs (5 DOI + 3 arXiv), convention table, **Nambu-doubling mechanism hypothesis (later rejected)**, 5-step implementer directive. Q1/Q2 high confidence, Q3/Q4/Q5 partial / paywalled. | **Partially yes**: lit-side closed (citation chain useful for Paper #4); mechanism claim turned out wrong. The audit value was preserved precisely *because* T6 critic was run before T5's recommendation cashed into julia code — exactly the layered routing the protocol design wants. |
| T6 | Critic audit of T5's Nambu-doubling claim | **CRITIC_FAIL** | `runs/_loop/judge/turn_6_critic_audit.md`: Verdict REJECTED w/ high confidence. Cited textbook pseudo-Hermitian (λ, -λ*) symmetry (Castin-Dum / Blaizot-Ripka / Colpa not in T5 cache). Listed 3 competing alternative mechanism hypotheses (i)/(ii)/(iii). Explicit handoff prompt to theorist. | Yes — first critic dispatch, first non-PASS verdict in loop history. Validates Phase 2 critic-axis: it caught a load-bearing wrong claim before it cascaded. Saved at least one wasted implementer turn post-sweep. |

**Trajectory check (§B4)**: 3 different subagent shapes in T4/T5/T6
(implementer / researcher / critic). No same-subagent-twice-in-a-row. T7
naturally rotates to theorist — the one shape not yet exercised
standalone-mode. **This is not "default to theorist after 3 theorist
PASS" — this is "the prior turn explicitly handed off to theorist with a
specific derivation prompt".** The critic-said-do-theorist signal is
the strongest possible dispatch signal in the protocol.

## 3. Bottleneck analysis

Top candidates by (project value × p(this-turn-moves-it) / cost),
filtered to julia-safe moves per seed.md:

- **B-1: T6 critic explicitly requested theorist follow-up to settle
  the eigen-spectrum of `eigen([[L,M],[-M*,-L*]])` for an unstable Bose
  mean field.**
  *Issue*: Critic identified that T5's claim "imaginary physical
  eigenvalues become large-positive-real Nambu eigenvalues" is wrong
  (textbook (λ, -λ*) pseudo-Hermitian symmetry preserves the imaginary
  structure). But critic listed 3 distinct *alternative* mechanisms
  (i) real residual from LAPACK noise + miscalibrated mu_b UV
  subtraction, (ii) real ±|λ| pairs from real-but-negative stiffness
  eigenvalues, (iii) c_star = argmax(|u_part|²) label being ill-defined
  on near-degenerate unstable eigenvectors — **without ratifying any
  one**. Theorist's job: pick the load-bearing mechanism via a tight
  derivation (or sympy-backed eigenstructure calculation on a toy
  D=2 or D=3 BdG matrix that reproduces the structural pathology),
  and produce a corrected mechanism statement + citation chain
  (Castin-Dum 1998 / Blaizot-Ripka 1986 / Colpa 1978 are explicitly
  named by critic as load-bearing-but-not-yet-cached).
  *Category*: physics gap (correct LHY treatment) + verification gap
  (load-bearing-mechanism for the existing 3000× bug) + manuscript
  gap (Paper #4 method note).
  *Leverage*: **5**. Closes the remaining "what is actually wrong"
  question that gates the post-sweep julia implementer turn. The output
  is publishable — Bose Bogoliubov pseudo-Hermitian eigenstructure for
  a spinor mean-field-unstable GS is a Paper #4 method-note-grade
  result. Cost is bounded (Read + Write + optionally one
  `compute_sympy` step on a 2×2 or 4×4 toy BdG).
  *What moves it*: **theorist** — Read/Write only (julia-safe). Can
  optionally embed a `compute_sympy` directive to verify the eigenvalue
  structure of a 2×2 or 4×4 symbolic [[L,M],[-M*,-L*]] matrix at
  symbolic L, M — that exercises infrastructure validated in T3/T4.

- **B-2: phi_1_reg analytic continuation as the canonical fix
  (held over from T6 §3 B-2).**
  *Issue*: T5 §Q5 noted that `PolarContactLHY` (which works) uses
  `phi_1_reg(t)` saturating at t=−1 (Petrov plateau, 0.3177); this is
  the closed-form analytic continuation for imaginary modes.
  FullBdGLHY's numerical path lacks the analog.
  *Category*: physics gap.
  *Leverage*: **3 now (was 4 in T6)**. Demoted because T6 critic
  showed the Nambu spurious-positive-real mechanism is *not* what's
  happening — so the "replace the threshold with the phi_1_reg analytic
  continuation per Nambu eigenvalue" recipe is now built on a wrong
  premise too. Until B-1 resolves the actual eigen-structure, B-2
  cannot be specified correctly. Conditional on B-1.

- **B-3: Cache the load-bearing citations T6 critic named
  (Castin-Dum / Blaizot-Ripka / Colpa) into `.claude/knowledge/`.**
  *Issue*: T6 critic flagged these as load-bearing for the corrected
  mechanism but NOT in T5's cached set. A researcher rotation could
  pull them. But §B4 + seed: T5 was researcher one turn ago (not
  two-in-a-row, but the critic's prompt is for *theorist* derivation,
  not literature accumulation — the citation pull can ride along inside
  the theorist's own WebFetch use).
  *Category*: infra gap (citation cache).
  *Leverage*: **2** as standalone; absorbed into B-1 as a sub-task.

- **B-4: Merge T4 `auto/turn_4_lemma1-f14-extension` to main.**
  *Issue*: F=14 extension on branch but not landed; tracked since T5.
  *Category*: housekeeping. Not director-shaped.
  *Leverage*: **1**.

- **B-5: noop.**
  Token budget tight? No — T6 spent 1.26M effective, T5 was researcher,
  T4 was 1.74M. Rolling cost healthy. Cheap bottleneck available (B-1).
  noop fails §F2 test.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | Theorist derives eigen-spectrum of [[L,M],[-M*,-L*]] for Bose mean-field-unstable GS; ratifies one of critic's three competing mechanisms (i)/(ii)/(iii); pulls Castin-Dum/Colpa/Blaizot-Ripka citations | **theorist** | NOW (critic explicit handoff, julia-safe, cheap) | ≤ 2.0M effective, ≤ 25 min |
| 2 | Researcher pulls Castin-Dum/Colpa/Blaizot-Ripka explicit equations | researcher | weaker — answers the *citation* question but not the *which-mechanism* question | ≤ 1.5M, ≤ 15 min |
| 3 | Implementer text-only design doc encoding T6 critic's verdict + three competing hypotheses | implementer (text) | inferior — encodes ambiguity rather than resolving it; would let the wrong mechanism leak back in | ≤ 1.0M, ≤ 10 min |
| 4 | Critic again? | critic | NO — T6 already gave a clean verdict; second critic on the same artifact has no new value | n/a |
| 5 | noop | n/a | not justified (quota healthy, cheap move available) | 0 |

**Pick: Option 1 (theorist).**

Why:
- **§B3 theorist routing rule applies cleanly**: "Dispatch when the
  bottleneck needs a new derivation / sign argument / BCH analysis /
  sympy-backed closed form that no existing source provides." T6
  critic's REJECTED-with-three-alternatives places the bottleneck
  *exactly* there — the literature (T5) doesn't ratify any of (i)/(ii)/(iii),
  and the answer requires deriving the eigenstructure of a non-Hermitian
  pseudo-Hermitian matrix at a specific physical regime (Bose
  unstable GS).
- **Critic's explicit handoff prompt** is the strongest possible
  dispatch signal. The critic's last paragraph reads almost as a
  pre-written theorist brief; the director's job is to forward it
  (with cost cap + falsification criteria + protocol formatting).
- **§B4 anti-default-theorist passes**: theorist hasn't fired since
  T3 (compute_sympy infra), and T3's theorist work was infra not
  physics. T4-T6 used implementer/researcher/critic. No "3 theorist
  PASS in a row" pattern; this is exactly the cascade the protocol
  wants (theorist → researcher → critic → theorist on a different
  layer of the same problem).
- **§A5 value test**: hits (a) closes manuscript TODO (Paper #4
  method note),(b) closes verification gap (load-bearing mechanism
  for F=6 polar 3000× bug), (d) reduces bug blast radius (post-sweep
  implementer can now ship a fix on the *right* mechanism).
- **julia constraint satisfied**: theorist uses Read/Write only per
  seed.md (with optional WebFetch for Castin-Dum / Colpa); may emit
  a `compute_sympy` directive — also julia-free per seed §"Director
  MAY dispatch ... implementer for compute_sympy via uv run --with
  sympy".
- **Cost-bounded**: theorist Read T5 + T6 critic + dispatch.jl
  + 2 cached refs + 1-2 new refs (Castin-Dum); write the report.
  Optional sympy step on a 4×4 symbolic BdG would add ~30 s.
  ≤ 2.0M effective (heavier than T6's 1.26M because of derivation
  + WebFetch, but well under T4's 1.74M).

Why NOT researcher (Option 2) today:
- The Castin-Dum eigenstructure result is a *textbook fact*, not a
  literature-extraction problem. Theorist with WebFetch (Read tool)
  can pull it inline. The bigger value-add is the *derivation* /
  ratification of which alternative mechanism is correct — that's
  theorist-shaped.
- §B4 rotation tolerates researcher again (T5 was 2 turns ago, not
  consecutive), but the bottleneck shape favors theorist.

Why NOT implementer-text-only (Option 3):
- A design doc that uncritically encodes the three competing
  alternative mechanisms would *increase* future blast radius by
  leaving the open question visible without resolving it. Strictly
  weaker than theorist resolution.

Why NOT critic-again (Option 4):
- T6 critic already issued a definitive verdict. Second critic would
  audit either the critic's own audit (recursion, low value) or
  re-audit T5 (T5 is already rejected). No new value.

Why NOT noop (Option 5):
- Quota healthy (rolling burn well under cap), cheap bottleneck
  available, seed.md explicitly enumerates theorist as julia-safe.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness | **at risk** | F=6 polar FullBdGLHY 3000× bug: T5 mechanism rejected by T6, **correct mechanism still TBD** — T7 theorist would close. TwoChannelLHY F=6 30-70% (design boundary). Klaus 2022 — anko's sweep, not loop-driven. No physics effects added T0-T6. |
| Verification depth | **on track** (T5+T6+T7 chain). | T5 closed lit-side of D2-axis LHY verification (Lima-Pelster + Petrov + Bisset + UKU + Zhang refs). T6 closed mechanism-side (rejected Nambu-doubling hypothesis). T7 (this turn) closes derivation-side (corrected eigenstructure + citation chain). T8 (post-sweep) cashes into julia code. Wheel turning. |
| Manuscript | **on track for Paper #1, #3; improving for Paper #4** | Paper #1 LaTeX-ready. Paper #3 Lemma 1 reach F=14 (branch unmerged). Paper #4 specifically: the T7 theorist's corrected mechanism + Castin-Dum citation chain becomes a publishable §Method note. |
| Reproducibility | **on track** | YAML schema, lab-units, resumable. No regression T0-T6. |
| Loop infrastructure | **mature**: 4 of 6 axes exercised (modify_code, compute_sympy, researcher, critic). T7 would be first standalone-theorist (no embedded implementer directive) — `run_experiment` still untouched but forbidden this session anyway. |

**Mark**: Verification-depth wheel is the actively-turning one this
session. T5→T6→T7 is the correct sequencing; T8 (post-sweep) lands
the fix.

## 6. Dispatch decision

```json
{
  "subagent_type": "theorist",
  "rationale": "T6 critic (`runs/_loop/judge/turn_6_critic_audit.md`, VERDICT FAIL, last paragraph) explicitly handed off to theorist with a verbatim derivation prompt: 'Derive the eigen-spectrum of H_bdg = [[L,M],[-M*,-L*]] for a Bose mean-field-unstable GS ... Provide the citation chain (Castin-Dum / Colpa / Blaizot-Ripka) for the pseudo-Hermitian eigenstructure.' The critic REJECTED T5's Nambu-doubling claim (imaginary physical Bogoliubov eigenvalues becoming large-positive-real Nambu eigenvalues is contradicted by the textbook (λ, -λ*) pseudo-Hermitian symmetry of bosonic BdG) but offered three competing alternative mechanisms (LAPACK noise + miscalibrated mu_b / real-negative stiffness pairs / ill-defined c_star) without ratifying any. This is the canonical §B3 theorist trigger: 'derivation / sign argument / sympy-backed closed form that no existing source provides.' julia-safe per seed.md (theorist Read/Write only). Rotation clean: theorist hasn't fired since T3 (compute_sympy infra); T4 implementer / T5 researcher / T6 critic; no §B4 'theorist 4th in a row' violation. Project value: closes the load-bearing mechanism question that gates the post-sweep julia implementer turn (T8) AND produces a Paper #4 method note artifact. Cost-bounded: Read T5/T6/dispatch.jl + 1-3 WebFetch on Castin-Dum/Colpa/Blaizot-Ripka + Write theorist/turn_7.md; optional embedded compute_sympy step on a 4×4 symbolic BdG.",
  "brief": "Goal: settle the load-bearing mechanism for the F=6 polar FullBdGLHY 3000× spurious offset by deriving the eigen-spectrum of the Bose-Bogoliubov matrix H_bdg = [[L,M],[-M*,-L*]] at a mean-field-unstable GS. Ratify ONE of the three competing alternative mechanisms listed by T6 critic, or introduce a fourth if the derivation reveals it. Pull the Castin-Dum 1998 / Blaizot-Ripka 1986 / Colpa 1978 citation chain that T5 missed. Output is a theorist report at `runs/_loop/theorist/turn_7.md` (NOT a code edit). NO julia execution (seed.md hard constraint, anko's Klaus sweep is running). compute_sympy via `uv run --with sympy` IS permitted if it sharpens the derivation (e.g. symbolic eigenvalues of a 4×4 model H_bdg).\n\n## Context to read first (in this order)\n\n1. `runs/_loop/judge/turn_6_critic_audit.md` — THE critic verdict + handoff prompt. Pay specific attention to:\n   - §Corrected mechanism statement: three competing hypotheses (i)/(ii)/(iii) at the end.\n   - §Code-level prediction: '~24 imaginary ±iΩ pairs ... plus ~2 real ±λ pairs ... real parts at LAPACK noise floor 1e-12 to 1e-8.'\n   - §RECOMMENDED ACTION (last paragraph): verbatim derivation prompt — your job is to answer it.\n2. `runs/_loop/research/turn_5.md` — T5's full literature scan. Note: T5's *Nambu-doubling mechanism* is REJECTED, but T5's literature citations (Lima-Pelster, Petrov, Bisset, UKU, Zhang) and §Convention table remain useful for the corrected mechanism's framing.\n3. `src/hamiltonian/interactions/lhy/dispatch.jl` lines 200-242 (the `_compute_lhy_at_density` BdG body). Specifically: line 214-218 constructs H_bdg = [[L, M_sc], [-conj(M_sc), -conj(L)]] (non-Hermitian, pseudo-Hermitian under η = diag(I_D, -I_D)). Line 225 calls `eigen(H_bdg)` — standard LAPACK eigendecomposition, NOT a symplectic / Colpa diagonalization.\n4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/full_bdg_F6_polar_broken.md` — empirical observation: F=6 polar `:scalar` GS = -880.5 vs `:full_bdg` = -2.527e6 (3000× larger negative); ψ shape identical between modes. Treat as starting empirical fact, not as mechanism.\n5. The PolarContactLHY closed form (works for F=6 polar) at `src/hamiltonian/interactions/lhy/polar_contact.jl` (or wherever `phi_1_reg` lives — Glob for it). The contrast 'closed form works, numerical BdG breaks' suggests the closed form encodes a specific analytic-continuation prescription for imaginary modes that the numerical path lacks. Your derivation should explain what.\n\n## Derivation targets (priority-ordered)\n\nD1 (load-bearing, answers C1 from T6 critic). **Eigen-spectrum of H_bdg = [[L, M], [-M*, -L*]] when L, M are D×D and the corresponding physical Bogoliubov problem has imaginary frequencies (mean-field unstable).** Specifically derive (with citation, ideally Castin-Dum 1998 sec 2 or Blaizot-Ripka §3.6 or Colpa 1978 §3):\n  (a) The pseudo-Hermitian symmetry η H_bdg η = H_bdg^† where η = diag(I_D, -I_D).\n  (b) The (λ, -λ*) eigenvalue pairing this implies (real → ±|λ| pairs; complex → quartet ±λ, ±λ*; purely imaginary → ±iΩ pairs).\n  (c) What `eigen(H_bdg)` (standard LAPACK, non-Hermitian) actually returns for case (b) — does it preserve the (λ, -λ*) structure to floating-point accuracy, and if not, what *real* residual does numerical noise produce on what should be a purely-imaginary eigenvalue?\n\nD2 (mechanism resolution, answers C5 from T6 critic). Given D1, decide which of the three critic hypotheses is load-bearing for the 3000× factor:\n  (i) LAPACK residual `real(ev)` from purely-imaginary eigenvalues passing the `> 1e-10` threshold, with `mu_b` UV miscalibration amplifying.\n  (ii) Genuine real ±|λ| pairs from real-but-negative stiffness eigenvalues of L (i.e. modes that are *unstable* but not *imaginary* in the Bose Bogoliubov sense).\n  (iii) c_star = argmax(|u_part|²) being ill-defined on degenerate-unstable eigenvectors, making mu_b a wrong UV asymptote.\n\nA tight order-of-magnitude argument: which alternative is *quantitatively* consistent with 3000× = ratio(`:full_bdg` / `:scalar`) at F=6 polar, n0 ~ Eu151 typical density, ~12/13 modes unstable? If multiple contribute, rank them.\n\nD3 (citation chain). Pull explicit equations / page references from at minimum 2 of {Castin-Dum 1998 PRA 57, 3008 'Low-temperature Bose-Einstein condensates in time-dependent traps' (or the Castin-Dum lecture notes that are open-access); Blaizot-Ripka 'Quantum Theory of Finite Systems' MIT Press 1986 §3.6; Colpa Physica A 93, 327 (1978)}. WebFetch is fine. The goal is one canonical citation per claim, not exhaustive review. Cache the refs in your report (or note 'see runs/_loop/research/turn_5.md' for already-cached ones).\n\nD4 (optional but high-value — sympy verification). Set up a *symbolic* 4×4 H_bdg with D=2: L = [[a, b], [b*, c]] and M = [[d, e], [e, f]] with `a, b, c, d, e, f` Hermitian-compatible symbols, then symbolically diagonalize and verify (b) from D1. Or set up a *parameterized* case where L produces one imaginary and one real Bogoliubov pair, and check what `eigen` returns. Embed this as a `compute_steps[]` directive in your §6 implementer brief (NOT this turn — for a future text-only directive that lands the corrected mechanism into a design doc / docstring).\n\nD5 (constructive bridge to fix shape). Given D2's answer, sketch the correct fix (one of T6's F-α / F-β / F-γ or a fourth):\n  - F-α: count imaginary modes of the upper-D physical Bogoliubov block (T5's wrong-mechanism but possibly-right-recipe). Justify or refute.\n  - F-β: switch from `eigen(H_bdg)` to a Colpa / Bogoliubov-de-Gennes proper diagonalization using the symplectic η metric, then handle imaginary-eigenvalue modes per a citation-backed convention (Lima-Pelster 'drop imaginary part' OR phi_1_reg analytic continuation OR error-out).\n  - F-γ: auto-route F=6 polar to `PolarContactLHY` based on GS purity heuristic; retain the `@warn` for `:full_bdg`. Documented in `full_bdg_F6_polar_broken.md` already.\n  - F-δ (your contribution if D1+D2 reveals a cleaner cut).\n\n## Deliverable schema (write to `runs/_loop/theorist/turn_7.md`)\n\n1. **§0 Convention declaration**: η = diag(I_D, -I_D); Bose vs Fermi Nambu sign convention (this matters — fermionic style is +conj(κ[c,c']), bosonic is +conj(κ[c,c']) per MEMORY.md `tdhfb_gpu_port_status.md`; SpinorBEC uses the bosonic form at dispatch.jl line 217's `.-conj.(M_sc)`).\n2. **§1 Context summary**: 1 paragraph on T5→T6 cascade + the open question.\n3. **§2 Derivation**: §2.1 D1 (pseudo-Hermitian symmetry + spectrum types), §2.2 D2 (mechanism resolution at F=6 polar), §2.3 D3 (citations in line), §2.4 D5 (recommended fix shape).\n4. **§3 Sanity checks**: at least 3 independent checks (e.g. limit: L Hermitian and M=0 reduces to standard Schrödinger; symmetry: η-conjugation reproduces (λ, -λ*); dimensional: ω has units of energy; or order-of-magnitude: estimated 3000× factor from your chosen mechanism vs observed).\n5. **§4 Calibrated claims**: each claim marked [Established] or [Plausible] or `<RESEARCH_NEEDED: query>` with sources.\n6. **§5 Open questions**: anything that needs another loop turn to settle (e.g. paywalled equations, F-specific algebraic structure).\n7. **§6 Directive for implementer** (text-only OR julia, marked as **POST-SWEEP** if julia): the corrected fix shape + a regression-test sketch (julia would be deferred per seed.md). May include a `compute_steps[]` block for a sympy verification of D1 (symbolic 4×4 eigenstructure) if it sharpens the audit trail.\n7. **§7 Research queries**: empty if D3 was answered in-line; otherwise list the paywalled / not-found refs.\n\n## Falsification / out-of-scope\n\n- If the derivation reveals that NONE of T6's three hypotheses (i)/(ii)/(iii) is load-bearing and a fourth is needed, say so plainly in §2.2. The §6 directive then takes shape F-δ.\n- If after WebFetching Castin-Dum / Colpa / Blaizot-Ripka the derivation cannot be closed without a graduate-textbook-level Bogoliubov-de-Gennes calculation that would take >1 turn, escalate: §5 'open questions' lists the missing step, §6 directive is INDETERMINATE 'theorist needs a second turn on D1 with a specific compute_sympy 6×6 example'.\n- Out-of-scope: writing julia code, running julia experiments, modifying `dispatch.jl`. The post-sweep implementer turn does that.\n- Out-of-scope: a new literature scan beyond Castin-Dum/Colpa/Blaizot-Ripka. T5 already covered LHY-convention literature; this turn is *eigen-structure derivation*, not lit-scan.\n\n## Cost\n\n- Token budget: ≤ 2.0M effective tokens (T4 was 1.74M with heavier compute; T6 critic was 1.26M; this turn sits between).\n- Wall-clock: ≤ 25 min. Theorist reads ~5 files (≤ 5 min), WebFetches ≤ 3 refs (≤ 5 min), derives (≤ 10 min), writes (≤ 5 min).\n- No julia execution. compute_sympy via `uv run --with sympy` permitted (≤ 30 s per step, ≤ 2 steps).\n- Output: `runs/_loop/theorist/turn_7.md` per loop schema.",
  "expected_outcome": "(1) `runs/_loop/theorist/turn_7.md` exists with §0-§7 per schema; §2.2 ratifies one of {(i), (ii), (iii), (iv-new)} as the load-bearing mechanism for the 3000× factor with a quantitative argument; §2.3 cites at minimum 2 of {Castin-Dum 1998, Colpa 1978, Blaizot-Ripka 1986} with explicit page or equation references; §2.4 picks one of F-α / F-β / F-γ / F-δ as the recommended fix shape; §6 directive is text-only (a design-doc / docstring write) OR julia-deferred-post-sweep. (2) Judge PASS (theorist output is read+write only, no code regression risk). (3) state.json T7 history records theorist agent_hash. (4) Optional: 1-2 compute_sympy steps in §6 with status OK / TIMEOUT / FAILED visible. (5) The post-sweep T8 implementer dispatch now has a ratified mechanism + citation chain, avoiding a wasted julia turn on a wrong fix.",
  "expected_cost": "≤ 25 min wall-clock, ≤ 2.0M effective tokens. Theorist Read (5 files) + WebFetch (≤ 3 refs) + Write (1 report) ± compute_sympy (1-2 steps). No julia JIT cost.",
  "if_fails_next_step": "If theorist returns INDETERMINATE ('cannot close D1 without graduate-textbook-level BdG calc'), T8 dispatches a researcher to specifically extract Castin-Dum 1998 §2 or Colpa 1978 §3 equations (sharper than T5's general LHY scan). If theorist closes D1 with a clean mechanism + fix shape but the fix is julia-blocked (anko's sweep still running), T8 is implementer-text-only writing a design doc `docs/design/fullbdg_F6_polar_fix_spec.md` that captures the theorist's verdict for the eventual julia implementer turn. If anko's sweep has finished by T8 (light-mode constraint relaxed), T8 dispatches implementer-julia with the ratified fix.",
  "consumed_seed_md": true
}
```

`consumed_seed_md`: **true**. seed.md (2026-05-15 morning, light-mode)
enumerates three director-safe alternatives when implementer-with-julia
is forbidden: extend lit audit, **critic-audit T5's Nambu mechanism**
(consumed by T6), **theorize phi_1_reg properties** (T7 generalizes
this to the full eigen-structure derivation per critic's explicit
handoff). T7 satisfies the seed's spirit (julia-safe, advances
verification depth via derivation rather than blind theorizing per the
goal-continuation quote) and uses the critic's own handoff prompt as
the operational starting point. If anko writes a fresh seed.md before
T8 with a different priority, that supersedes.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=7, last_judge=CRITIC_FAIL,
      T6 critic dispatch recorded, agent_hashes include critic for
      first time).
- [x] Read `runs/_loop/seed.md` (2026-05-15 light-mode, julia-forbidden,
      explicit director-safe options including theorizing).
- [x] Read `runs/_loop/director/turn_6.md` (my T6 dispatch's
      `if_fails_next_step` field pre-committed theorist if REJECTED
      with ambiguous alternative — this turn cashes that contract).
- [x] Read `runs/_loop/director/turn_5.md` (T5 researcher rationale +
      brief — confirms the lit-side citations are usable but the
      mechanism step needs theorist closure).
- [x] Read `runs/_loop/director/turn_4.md` (continuity — Lemma 1 F=14
      branch still unmerged; not the right time to merge from
      director).
- [x] Read `runs/_loop/judge/turn_6_critic_audit.md` (full verdict +
      explicit theorist handoff prompt). This file *is* the dispatch
      signal.
- [x] Read `runs/_loop/research/turn_5.md` (T5's literature scan + the
      rejected Nambu-doubling claim; both the convention table and the
      §Q5 phi_1_reg note remain useful inputs for theorist).
- [x] Read `runs/_loop/theorist/turn_3.md` (last theorist; infra-
      verification work — sets a template for §0-§7 schema).
- [x] Read `runs/_loop/theorist/turn_2.md` (T2 derivation showing
      what a clean theorist §2 looks like with separate (A)/(B)
      prongs — analog of separating T6 critic's three (i)/(ii)/(iii)
      mechanisms).
- [x] Read `runs/_loop/sim/turn_4.md` (last sim — modify_only;
      orchestrator records compute_results[] format).
- [x] Read ≥1 memory: `full_bdg_F6_polar_broken.md` (2 days stale —
      flagged at top of file; the empirical 3000× factor is
      the starting fact theorist must explain).
- [x] Verified source line citations: `src/hamiltonian/interactions/
      lhy/dispatch.jl` lines 190-246 (BdG body), 214-218 (Nambu
      matrix construction), 225 (`eigen(H_bdg)`), 230-231 (T5's
      identified threshold), 236 (UV subtraction).
- [x] Considered NOT dispatching theorist — challenged with researcher
      (Option 2, citation-only — weaker because the bottleneck is
      mechanism resolution not citation accumulation), implementer-
      text-only (Option 3, encodes ambiguity rather than resolves it),
      critic-again (Option 4, no new value). Theorist wins on §B3 +
      critic's explicit handoff signal.
- [x] §6 brief is specific: file paths, T6 critic paragraph references
      (3 verbatim hypothesis quotes), 5 priority-ordered D-targets
      (D1-D5), 4 candidate fix shapes (F-α / F-β / F-γ / F-δ),
      8-section deliverable schema (§0-§7), falsification criteria
      (INDETERMINATE allowed; out-of-scope explicit), cost cap, julia
      constraint reinforced. Theorist does not need clarifying questions.
- [x] Justified why THIS turn — the critic's explicit handoff is the
      strongest dispatch signal in protocol; deferring would waste the
      cascade momentum and leak T6's mechanism-resolution value.
- [x] `consumed_seed_md: true` — seed enumerates this exact move
      (theorize properties of the LHY mechanism / phi_1_reg) as a
      julia-safe alternative; T7 generalizes it per critic's handoff.
