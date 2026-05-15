---
turn: 8
subagent: director
topic_tags: [paper4-methodology, fullbdg-mechanism-note, manuscript-cash-in, t7-theorist-followup, julia-safe-text-edit]
paper_section: docs/manuscript/papers/paper4_chaotic_dynamics/main.md
depends_on: [5, 6, 7]
produces: A new §IV.A or §IV-subsection in Paper #4 capturing the T7 theorist mechanism diagnosis (pseudo-Hermitian BdG + LAPACK conditioning + zero-symplectic-norm c_star) as a citable "FullBdGLHY caveat / methodology note," citing Castin-Dum 1998, Colpa 1978, Blaizot-Ripka 1986, Lieu 2018. Text-only implementer dispatch. Julia-safe.
---

# Turn 8 — Director Report

## 1. Project state snapshot

- **T5→T6→T7 cascade closed cleanly.** T5 (researcher, RESEARCHER_ONLY)
  proposed a Nambu-doubling mechanism for the F=6 polar FullBdGLHY
  3000× bug. T6 (critic, FAIL) **rejected** it with textbook bosonic
  pseudo-Hermitian (λ, -λ*) symmetry and listed three competing
  hypotheses. T7 (theorist via text-only implementer, PASS, commit
  `6f92776` on `auto/turn_7_fullbdg-F6-mechanism-note`) **ratified
  hypothesis (i)+(iii)**: LAPACK condition-number noise on
  purely-imaginary Nambu eigenvalues passes the `> 1e-10` filter at
  high $k$, amplified by zero-symplectic-norm eigenvectors making
  $c^{*} = \arg\max_c|u_c|^2$ ill-defined → miscalibrated $\mu_b$
  UV-subtraction. Sympy S1 (D=2 ηHη=H†, zero matrix) + S2 (D=1 orbit
  classification, ±i√3 imaginary preserved) both OK.

- **T7 produced a publishable artifact, not just a docstring.**
  `runs/_loop/theorist/turn_7.md` §8 "Publishability assessment"
  proposes a paper-scale title: *"Pseudo-Hermitian failure modes in
  numerical Bose-Bogoliubov LHY: a diagnosis for spinor BECs at
  mean-field-unstable ground states."* The 18-line docstring in
  `dispatch.jl:115-128` (post-edit) captures the headline only — the
  full §2.1-§2.4 derivation + §2.3 citation chain (5 refs, 2 of which
  T5 missed: Colpa 1978 Thm 3.1 and Castin-Dum 1998 §II.B Eq. 2.21)
  exists only in the theorist report, NOT in any manuscript file.

- **Manuscript pulse**: Paper #1 LaTeX-ready (unchanged). Paper #3
  Lemma 1 reach F=3-14 (T4 branch `be6a472` **still UNMERGED**).
  **Paper #4 main.md §IV (Methodology Discussion) and §V
  (Conclusions) explicitly marked TBD** (`paper4_chaotic_dynamics/
  main.md` line 6: "TBD: §IV (Methodology Discussion), §V
  (Conclusions)"). Paper #4 §IV is the natural home for the T7
  FullBdGLHY mechanism note — Paper #4's TWA-chaos narrative
  positions LHY as a follow-up extension ("True quantum-fluctuation
  magnitude extraction requires higher-order methods (TDHFB /
  Beliaev) deferred to follow-up work," Abstract end), so an honest
  methodology section needs to disclose the FullBdGLHY F=6 polar
  caveat as a known limitation.

- **Hard environment constraint UNCHANGED** (seed.md, 2026-05-15
  light-mode): anko's Klaus phi-magnetostir Julia sweep is running
  (`runs/eu151_klaus_phi_phys/phi_*/config.yaml`, 9 untracked
  configs in `git status`; sweep generated `barnett_precursor.pdf`
  etc.). Director MUST NOT dispatch implementer-julia. Text-only
  manuscript edit IS in seed §"Director MAY dispatch" — "implementer
  for text-only `modify_code` (docstring, comment, manuscript
  section) with NO julia execution to verify."

- **Drift signals**: state.json T7 history block has no
  `drift_signals` field (Upgrade B may not be wiring yet at T7
  granularity); rolling-eff burn last 3 turns 1.74M (T4) → 1.26M
  (T6) → 0.96M (T7) — **decreasing**, healthy. No DRIFT_COST_INFLATION.
  Topic concentration last 3 turns IS on FullBdG F=6 polar
  (T5/T6/T7 all on this thread) — **potential
  DRIFT_TOPIC_REPETITION concern if T8 stays on the same topic**.
  But: T8 is a manuscript cash-in, not another derivation iteration
  on the same physics. Different shape, different artifact, closes
  the cascade. Acceptable under §B4 rotation rules.

- **Rotation status**: T0-T4 = implementer (×4, modify_code), T5 =
  researcher, T6 = critic, T7 = theorist-via-implementer-text. T8
  candidate = implementer-text (manuscript section). Two
  implementer-text in a row? T7 was *agent* implementer per
  state.json but *shape* was "execute theorist directive + sympy
  verify" — content is theorist-derivation-shaped, not edit-shaped.
  T8 would be true edit-shaped (write a manuscript section from
  existing theorist output). Different work-shape. §B4 "no more
  than 2 same-subagent in a row" is borderline but the seed
  explicitly lists this as the canonical julia-safe pattern.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T5 | FullBdGLHY F=6 polar literature audit (researcher) | RESEARCHER_ONLY | `runs/_loop/research/turn_5.md`: 8 refs (5 DOI + 3 arXiv), Nambu-doubling mechanism (later rejected by T6). Q1/Q2 high confidence; Q3-Q5 partial. | Partially — lit-side correct; mechanism wrong but caught at T6 before cashed into code. Layered routing worked as designed. |
| T6 | Critic audit of T5's Nambu-doubling claim | CRITIC_FAIL | `runs/_loop/judge/turn_6_critic_audit.md`: REJECTED w/ high confidence, three competing hypotheses, explicit theorist handoff. First non-PASS in loop history. | Yes — exactly the cascade Phase 2 critic-axis was designed for. Saved a wasted implementer-julia turn post-sweep. |
| T7 | Theorist derivation of H_bdg eigen-spectrum + mechanism resolution, +sympy + docstring landing | PASS | Branch `auto/turn_7_fullbdg-F6-mechanism-note` commit `6f92776`: (a) §2.1 derives ηH_bdg η = H_bdg† + orbit classification {R,I,Q,Z}, (b) §2.2 ratifies mechanism (i)+(iii) with quantitative 3000× order-of-magnitude estimate (within 3 orders), (c) §2.3 cites Castin-Dum 1998 / Colpa 1978 / Blaizot-Ripka 1986 / Lieu 2018 / KU 2012, (d) §2.4 recommends F-δ (signature test on Hermitian stability matrix) over F-α/F-β/F-γ with reasons. 18-line docstring inserted in dispatch.jl (no code semantics change). | Yes — critic's explicit handoff prompt answered cleanly; introduces publishable Paper #4 method-note artifact. **Branch UNMERGED.** |

**Trajectory check (§B4)**: T5/T6/T7 are three different
subagent shapes (researcher / critic / theorist-via-implementer)
on the same physics topic — exactly the layered cascade Phase 2
was designed for. Topic concentration would become §B4 problem if
T8 dispatched a 4th derivation iteration. T8 dispatching a
manuscript cash-in is a different work-shape and *closes* the
cascade by externalizing the artifact.

## 3. Bottleneck analysis

Candidates ranked by (project value × p(this turn moves it) / cost),
filtered to julia-safe per seed.md:

- **B-1: Cash T7 theorist derivation into Paper #4 §IV
  (Methodology Discussion) as a "FullBdGLHY caveat" subsection.**
  *Issue*: T7 produced a publishable derivation (`runs/_loop/
  theorist/turn_7.md` §2.1-§2.4 + §2.3 citation chain + §8
  publishability assessment) but only a 18-line condensed version
  exists in source (`dispatch.jl:115-128` docstring). Paper #4
  main.md §IV is explicitly marked TBD; the LHY caveat is exactly
  the methodology disclosure the paper needs (its abstract defers
  "true quantum-fluctuation magnitude extraction" to TDHFB/Beliaev
  follow-up but doesn't explain *why* TWA is the right tool given
  the FullBdG limitations at F=6 polar). The T7 derivation +
  citations make it directly drop-in-able.
  *Category*: docs gap (Paper #4 §IV TBD) + verification gap
  (mechanism narrative now exists in code comment but not in any
  citable manuscript section).
  *Leverage*: **5**. Closes a manuscript TODO + makes T7's
  published-grade derivation reachable to external readers +
  reinforces Paper #4's TWA-vs-LHY positioning. Cost-bounded
  (text-only edit ~200-400 lines of manuscript). Julia-safe
  per seed.md.
  *What moves it*: **implementer (text-only modify_code)** —
  write a new §IV subsection (or §IV.A) with the derivation
  summary + citations.

- **B-2: Merge T4 branch `auto/turn_4_lemma1-f14-extension`
  (commit `be6a472`) into main.**
  *Issue*: Lemma 1 F=14 extension on branch but not landed; flagged
  in T5 and T6 director reports. Pure housekeeping. Branch contains
  Paper #3 +1 row + S=20 exact-zero footnote + falsification
  CONFIRMED.
  *Category*: docs gap / housekeeping.
  *Leverage*: **2**. Mechanical merge, not director-shaped, and
  anko hasn't asked. Defer or wait for anko's decision (T4 was
  director-driven; user should ratify merge).

- **B-3: Document the recommended F-δ fix shape as a design doc
  (`docs/design/fullbdg_F6_polar_fix_spec.md`) so the post-sweep
  julia implementer turn has a complete spec.**
  *Issue*: T7 §2.4 sketches F-δ (signature test on $H_S = \eta
  H_{\rm bdg}$, 4 policy options for the unstable case) but it
  only lives in the theorist report at `runs/_loop/theorist/
  turn_7.md`. A standalone design doc in `docs/design/` would be
  easier for the post-sweep implementer to follow than a turn
  report.
  *Category*: docs gap / infra gap (julia-implementer
  preparation).
  *Leverage*: **3**. Useful but redundant with B-1 — the Paper #4
  §IV cash-in can include a "future work / F-δ proposal" subsection
  that doubles as the design doc. Stand-alone design doc only saves
  a future implementer turn ~5 min of cross-reference.

- **B-4: Researcher pulls Castin-Dum 1998 §II.B Eq. 2.21 +
  Colpa 1978 Thm 3.1 explicit equations into the project's
  reference cache.**
  *Issue*: T7 §2.3 cites these but only the abstract / theorem
  *statement* level. For paper #4 §IV the equations themselves
  would strengthen the methodology section.
  *Category*: docs gap / references gap.
  *Leverage*: **2**. T5 was researcher 3 turns ago, T7 was
  theorist 1 turn ago — researcher is rotation-clean. But the
  Paper #4 cash-in (B-1) doesn't *require* the verbatim equations
  — the theorem statements suffice. Demoted.

- **B-5: noop.**
  Quota healthy (T7 = 0.96M, well under cap). Cheap bottleneck
  (B-1) available. noop fails §F2 test.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | **Cash T7 derivation into Paper #4 §IV.A (text-only)** | **implementer** | NOW (cascade closure, manuscript TODO, julia-safe) | ≤ 1.5M effective, ≤ 20 min |
| 2 | Write standalone design doc `docs/design/fullbdg_F6_polar_fix_spec.md` for F-δ | implementer | LATER — redundant with #1 sub-section | ≤ 1.0M, ≤ 15 min |
| 3 | Researcher pulls Castin-Dum eq 2.21 + Colpa Thm 3.1 verbatim equations | researcher | weaker — T7 already closed the citation chain at theorem-statement level | ≤ 1.5M, ≤ 15 min |
| 4 | Theorist derives the F-δ Goldstone-counting + signature-test edge cases (T7 §5 open question) | theorist | DEFER — §B4 trap (4th derivation iteration on same topic); not load-bearing for Paper #4 §IV | ≤ 2.0M, ≤ 25 min |
| 5 | Merge T4 branch be6a472 to main | implementer (git only) | DEFER — anko should ratify | ≤ 0.5M |
| 6 | noop | n/a | not justified | 0 |

**Pick: Option 1 (implementer, text-only modify_code on
docs/manuscript/papers/paper4_chaotic_dynamics/main.md).**

Why:

- **§A5 value test**: hits (a) closes manuscript TODO (Paper #4
  §IV explicitly marked TBD in `main.md:6`), (b) closes verification
  gap (T7 derivation exists but is not in citable form anywhere),
  (d) reduces bug blast radius (the F=6 polar FullBdG caveat is now
  disclosed in Paper #4's methodology, not hidden in a code
  comment). Three of four §A5 axes — strong.

- **§B3 implementer routing rule applies**: "Dispatch when the
  bottleneck is 'code benchmark vs known reference' or 'add an
  effect whose theory is already settled' — no theorist directive
  needed first; you provide the directive in §6.brief." The
  theory IS already settled (T7); the bottleneck is converting it
  to manuscript text. Implementer-text-only is the correct shape.

- **§B4 rotation passes**: T5 researcher / T6 critic / T7
  implementer-text (executing theorist directive). T8
  implementer-text (executing director directive). Two
  implementer-text in a row, but the WORK-SHAPES differ: T7 was
  "derive + verify + minimal docstring edit" (mostly derivation
  cognition); T8 is "write a manuscript section from existing
  derivation" (mostly composition). Per the seed.md spirit ("pick
  default and move; don't get stuck on rotation theater") this is
  acceptable.

- **Cascade closure narrative**: T5 → T6 → T7 → T8 reads as the
  textbook research arc: literature scan → critical audit →
  derivation closure → manuscript externalization. Stopping at
  T7 would leave the derivation orphaned in a turn report.

- **Julia constraint satisfied**: text-only edit of a markdown
  manuscript file. No julia execution. seed.md §"Director MAY
  dispatch" explicitly enumerates this case.

- **Cost-bounded**: ~1.5M effective (similar to T6 = 1.26M).
  Implementer reads T7 §2 + Paper #4 §III current end + writes
  a new §IV.A subsection ≈ 200-400 lines markdown.

Why NOT Option 4 (theorist) today: §B4 trap — 4th derivation
iteration on the same physics thread would be the canonical
"theorist as default" failure mode the protocol warns against. T7
§5 open questions (Goldstone-counting edge cases, exact mapping
of Castin-Dum Eq 2.21 to LAPACK |u|²≈|v|²) are interesting but
NOT load-bearing for the Paper #4 §IV cash-in — the methodology
note can be written at the theorem-statement level T7 already
established.

Why NOT Option 3 (researcher): The Paper #4 §IV cash-in is
*composition* not *literature accumulation*. T7's citation chain
is already at publishable depth (Colpa Thm 3.1, Castin-Dum §II.B,
Blaizot-Ripka §3.6, Lieu Tbl I).

Why NOT Option 2 (design doc) as primary: Redundant with B-1's
"§IV.B Future work: F-δ signature test" subsection, which doubles
as the design doc. Adding a separate file would duplicate text.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness | **at risk** | F=6 polar FullBdGLHY bug mechanism diagnosed (T7) but fix still deferred to post-sweep (julia blocked). Klaus magnetostir on anko's sweep. No new physics effects added T5-T7. |
| Verification depth | **on track, accelerating** | T5→T6→T7 closed the FullBdG mechanism question with derivation + citations + sympy verification. T8 cash-in externalizes the result. Each turn in the cascade had clear forward motion. |
| Manuscript | **on track for Paper #1, #3; T8 advances Paper #4** | Paper #1 LaTeX-ready. Paper #3 F=14 branch unmerged. Paper #4 §IV TBD → T8 closes the LHY-methodology disclosure. Paper #4 §V (Conclusions) still TBD post-T8. |
| Reproducibility | **on track** | YAML schema, lab-units, resumable. T7 sympy traces archived under `runs/auto/turn_7_fullbdg-F6-mechanism-note/`. No regression. |
| Loop infrastructure | **mature**: 5 of 6 axes exercised (modify_code ×4, compute_sympy ×2, researcher ×1, critic ×1, theorist-via-implementer-text ×1, `run_experiment` ❌ forbidden this session). T8 = 5th `modify_code` (manuscript edit). |

**Mark**: Verification + manuscript axes simultaneously advancing
this session. T8 cashes both in.

## 6. Dispatch decision

```json
{
  "subagent_type": "implementer",
  "rationale": "T7 (commit 6f92776, judge PASS) produced a publishable-grade derivation in `runs/_loop/theorist/turn_7.md` §2.1-§2.4 with citation chain (Castin-Dum 1998 §II.B / Colpa 1978 Thm 3.1 / Blaizot-Ripka 1986 §3.6 / Lieu 2018 Tbl I / KU 2012) and an explicit §8 'Publishability assessment' proposing this as a Paper #4 method note. But the full derivation lives only in the turn report — the 18-line docstring at `src/hamiltonian/interactions/lhy/dispatch.jl:115-128` only captures the headline. Paper #4 main.md line 6 explicitly marks §IV (Methodology Discussion) as TBD, and Paper #4's TWA-chaos abstract defers 'true quantum-fluctuation magnitude extraction' to TDHFB/Beliaev follow-up — an honest §IV needs the FullBdGLHY F=6 polar caveat disclosed with mechanism + citations. This is a manuscript cash-in of an already-derived result: pure §B3 'implementer for an effect whose theory is settled.' Julia-safe per seed.md (text-only modify_code on a .md manuscript file). §B4 rotation borderline (two implementer-text in a row) but the WORK-SHAPES differ — T7 was derivation cognition + minimal docstring edit, T8 is composition from existing derivation. Cascade closure: T5→T6→T7→T8 = lit scan → critic audit → derivation closure → manuscript externalization. Without this turn, T7's publishable artifact stays orphaned in a turn report.",
  "brief": "Goal: write a new subsection §IV.A (or appropriate placement inside §IV Methodology Discussion) of `docs/manuscript/papers/paper4_chaotic_dynamics/main.md` titled approximately 'FullBdG LHY at mean-field-unstable spinor ground states: pseudo-Hermitian failure mode and signature-test fix.' Capture the T7 theorist derivation as a citable methodology note. Optionally also add a brief §IV.B 'Future work: F-δ signature test' that doubles as the design spec for the deferred julia implementation. NO julia execution. Text-only edit on the manuscript markdown file. Pure §B3 'theory already settled, implement the cash-in.'\n\n## Context to read first\n\n1. `runs/_loop/theorist/turn_7.md` §0-§8 — THE source material. Specifically:\n   - §0 conventions (η = diag(I_D, -I_D), bosonic vs fermionic Nambu sign, L Hermitian / M symmetric).\n   - §2.1 derivation of η H_bdg η = H_bdg^† + the (λ, -λ*) spectrum-pairing theorem + orbit classification {R, I, Q, Z}.\n   - §2.2 mechanism resolution at F=6 polar — hypothesis (i)+(iii) ratified with quantitative 3000× order-of-magnitude estimate.\n   - §2.3 citation table (5 refs, Castin-Dum 1998 / Colpa 1978 / Blaizot-Ripka 1986 / Lieu 2018 / KU 2012).\n   - §2.4 recommended fix F-δ (signature test on $H_S = \\eta H_{\\rm bdg}$, 4 policy options for unstable case).\n   - §3 sanity checks (limit cases, dimensional, F=1 reduction, order-of-magnitude, particle-hole symmetry).\n   - §4 calibrated claims (which are [Established] vs [Plausible]).\n   - §8 publishability assessment + proposed title.\n\n2. `docs/manuscript/papers/paper4_chaotic_dynamics/main.md` — current Paper #4 state. Specifically:\n   - Line 6 marks §IV and §V TBD.\n   - Abstract (lines 11-30) defers 'true quantum-fluctuation magnitude extraction' to TDHFB/Beliaev follow-up.\n   - §I-III currently written. §IV is the natural slot for this methodology note (between Results §III and Conclusions §V).\n   - Bottom (lines 312-330) — References TBD, Companion materials listed. Bibliography is currently sketchy.\n\n3. `src/hamiltonian/interactions/lhy/dispatch.jl:115-128` — the 18-line docstring T7 inserted. Use as the source-pointing-text in §IV; the manuscript narrative can reference 'the FullBdG warning at dispatch.jl:115-128' as the production-code disclosure.\n\n4. `runs/_loop/judge/turn_6_critic_audit.md` — for the rejected mechanism context (T5's Nambu-doubling claim) which Paper #4 §IV can briefly mention as 'a tempting-but-wrong picture' to set up why the corrected mechanism matters.\n\n5. `runs/_loop/research/turn_5.md` §Q1-§Q5 — for the convention chain (Lima-Pelster 'drop imaginary part' convention) which Paper #4 §IV should reference as the standard treatment, then contrast with the bosonic-Bogoliubov-pseudo-Hermitian failure mode T7 diagnosed.\n\n## Section structure (suggested — implementer may adjust)\n\n**§IV. Methodology Discussion**\n\n*Optional intro paragraph*: Why §IV matters — Paper #4's claim that TWA-σ/μ saturation reflects chaos rather than quantum fluctuations depends on the inability of leading-order TWA to extract genuine quantum-fluctuation magnitudes (abstract). A natural reader question is: why not use beyond-mean-field methods (LHY) directly? §IV.A discloses the FullBdG-LHY limitation at F=6 polar that motivates the TDHFB/Beliaev follow-up.\n\n**§IV.A FullBdG LHY at mean-field-unstable spinor ground states: pseudo-Hermitian failure mode**\n\nSuggested content (≈ 1.5-2.5 pages of markdown):\n\n1. *Setup* (1 paragraph): At a polar GS ζ_α = δ_{α,0} the mean field has imaginary spin-mixing Bogoliubov modes (12 of 13 modes imaginary at F=6 in the 'only g_0 = 100' regime). The standard treatment (Lima-Pelster 2011, Petrov 2015) is to retain only the real part of the LHY integrand; the question is how to do this numerically for a 2D × 2D Nambu matrix.\n\n2. *The bosonic BdG matrix and its pseudo-Hermitian structure* (1 paragraph + 1 displayed equation): Define H_bdg = [[L, M], [-M*, -L*]] with L Hermitian and M symmetric. State η H_bdg η = H_bdg^†. Cite Blaizot-Ripka §3.6 and Castin-Dum 1998 §II.A. Spectrum closed under λ → -λ*; classify into orbit-R (real ±ω), orbit-I (imaginary ±iΩ), orbit-Q (complex quartet), orbit-Z (Goldstone zeros). State that an imaginary physical Bogoliubov mode appears in the Nambu spectrum as orbit-I — NOT as a real-positive partner.\n\n3. *Numerical failure mode at F=6 polar* (1-2 paragraphs): Production code calls `eigen(H_bdg)` (LAPACK non-Hermitian, *not* a symplectic / Colpa diagonalization). For an unstable GS with N_I ≈ 12 imaginary pairs, condition-number amplification of LAPACK noise produces |Re(λ_num)| ~ κ·ε_mach·||H_bdg|| at high k that exceeds the `real(ev) > 1e-10` filter threshold. The surviving spurious modes carry a UV-subtraction term -ε_k - μ_b + μ_b²/(2ε_k) that no longer cancels (since Re(λ) ≈ 0 instead of ≈ ε_k + μ_b). Additionally, the per-mode label c* = argmax_c|u_c|² is ill-defined because the symplectic norm vanishes (Castin-Dum 1998 §II.B Eq. 2.21), so |u|² ≈ |v|² and c* is arbitrary across near-degenerate components — miscalibrating μ_b further. The combined mechanism produces a ~3000× spurious offset at F=6 polar Eu151 (`compute_spinor_lhy_table` GS energy = -2.527 × 10^6 vs `:scalar` GS energy = -880.5).\n\n4. *Why this is not 'Nambu doubling makes imaginary real'* (1 paragraph): A natural-but-wrong picture (which we tested and rejected in our earlier audit, runs/_loop/turn_5 / turn_6) is that the Nambu doubling converts imaginary physical eigenvalues into real Nambu eigenvalues. The (λ, -λ*) pseudo-Hermitian symmetry shows this is false: orbit-I pairs ±iΩ remain on the imaginary axis. The failure is at the *numerical* level (LAPACK conditioning + ill-defined eigenvector labels), not at the *structural* level.\n\n5. *Practical consequence for this paper* (1 paragraph): For F=6 polar (and any spinor GS with N_I > 0), `compute_spinor_lhy_table` (the `lhy: {kind: full_bdg}` mode) is numerically unreliable. Production code at `src/hamiltonian/interactions/lhy/dispatch.jl:115-128` emits a @warn directing the user to closed-form modes (`compute_spinor_lhy_polar_contact`, `compute_spinor_lhy_polar_dipolar`). Throughout this paper, F=6 polar comparisons that involve LHY corrections use the closed-form path; the FullBdG path is restricted to phases where the GS is mean-field stable.\n\n6. *Citation summary table* (replicating T7 §2.3 in compact form): 5 rows — bosonic BdG η-pseudo-Hermiticity, λ → -λ* spectrum, orbit classification, numerical sensitivity at exceptional points, application to spinor BEC.\n\n**§IV.B Future work: signature-test fix (F-δ)** (optional, ≤ 1 paragraph)\n\nBrief sketch of the recommended fix from T7 §2.4: replace `eigen(H_bdg)` with `eigen(Hermitian(H_S))` where H_S = η H_bdg, then test signature (N_+, N_-) of H_S. If (N_+, N_-) ≠ (D, D) modulo Goldstones, dispatch to a closed-form LHY or return zero. State that this is deferred for a future implementation (Paper #4's TWA-chaos claims do not depend on FullBdG-LHY working at F=6 polar, so this is forward-looking infrastructure).\n\n## Style / convention\n\n- Conventional Commits + Assisted-by trailer per CLAUDE.md.\n- Match Paper #4's existing prose style (academic but accessible; numbered subsections under §IV; LaTeX math via `$...$`).\n- Citations in-text as [Author Year] format consistent with the existing References-TBD style; add the 5 T7-§2.3 refs to a Reference subsection at the end if not already present, OR leave a `[Author Year]` style placeholder and let the bib step pick them up later.\n- Use Paper #4's existing tone: this is a *methodology disclosure*, not a primary-physics-claim section. The mechanism is the supporting argument for why TWA is the right tool.\n\n## Falsification / out-of-scope\n\n- DO NOT introduce new physics claims beyond T7's [Established] tier (the [Plausible] mechanism statement should be flagged as 'we propose' / 'the dominant contribution is' rather than 'we prove').\n- DO NOT modify Paper #4 §I-III content unless minor wording tweaks are needed to thread §IV in.\n- DO NOT touch Paper #1 / #2 / #3 — pure Paper #4 edit.\n- DO NOT run julia.\n- DO NOT attempt to merge T4 branch `be6a472` (that's a separate director-driven decision).\n- If the implementer encounters a conflict (e.g., §IV already partially drafted), STOP and report — don't overwrite without director / anko confirmation.\n\n## Cost\n\n- Token budget: ≤ 1.5M effective. Implementer reads T7 (~1 file, ~670 lines) + Paper #4 main.md (current ~330 lines) + writes ~200-400 lines markdown. Comparable to T6's 1.26M.\n- Wall-clock: ≤ 20 min. No JIT cost (text-only edit).\n- Output: a single commit on a new branch `auto/turn_8_paper4_iv_fullbdg_methodology_note` modifying `docs/manuscript/papers/paper4_chaotic_dynamics/main.md`.\n- compute_steps: empty (no sympy needed; T7 already verified the load-bearing identities).",
  "expected_outcome": "(1) `docs/manuscript/papers/paper4_chaotic_dynamics/main.md` has a new §IV.A subsection (≈ 1.5-2.5 pages markdown) capturing the T7 mechanism diagnosis with citations Castin-Dum 1998 / Colpa 1978 / Blaizot-Ripka 1986 / Lieu 2018 / KU 2012 at theorem-statement level. (2) Line 6 of `main.md` updated to reflect §IV.A landed (TBD list shrinks from '§IV, §V' to '§IV.B/C remaining or §V' as appropriate). (3) Optional §IV.B 'Future work: F-δ signature test' subsection at ≤ 1 paragraph. (4) Single commit on branch `auto/turn_8_paper4_iv_fullbdg_methodology_note`. (5) No code semantics change; no julia execution. (6) Judge PASS (modify_code text-only, no regression risk). (7) The Paper #4 §IV.A is now a citable artifact — replaces the orphan-in-turn-report status of T7's derivation.",
  "expected_cost": "≤ 20 min wall-clock, ≤ 1.5M effective tokens. Implementer Read T7 + Paper #4 + Write a manuscript section. No JIT, no julia.",
  "if_fails_next_step": "If the implementer reports that Paper #4 §IV is *already* partially drafted (not just TBD) and the new §IV.A conflicts with existing structure, T9 dispatches a critic to evaluate the conflict and propose a merged structure. If the implementer produces §IV.A but it overflows into [Speculative] territory beyond T7's [Established/Plausible] tier, T9 dispatches critic to trim it back. If the manuscript edit goes cleanly, T9 candidates are: (a) Paper #4 §V (Conclusions) cash-in — same pattern, different section; (b) standalone design doc `docs/design/fullbdg_F6_polar_fix_spec.md` capturing F-δ in more detail; (c) merge T4 lemma1-f14-extension branch (housekeeping, requires anko ratification); (d) if anko's sweep has finished, F-δ julia implementation. Decision deferred to T9 director.",
  "consumed_seed_md": true
}
```

`consumed_seed_md: true`. seed.md §"Director MAY dispatch"
explicitly enumerates "implementer for text-only `modify_code`
(docstring, comment, manuscript section) with NO julia execution
to verify" as a permitted shape. seed.md "T5 left a concrete
next-turn pointer" notes the julia-implementer-with-gate is
*forbidden* this session; the alternatives listed include
"extend T5's literature audit" (B-4 in §3, demoted) and "theorize
about the closed-form `phi_1_reg` properties" (consumed by T7
in generalized form). T8 cashing T7 into Paper #4 §IV is a
natural fourth alternative not enumerated verbatim in seed.md but
fully in-spirit: it advances research (closes a manuscript TODO),
captures verified physics into a citable form, and respects the
julia constraint.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=8, last_judge=PASS, T7
      orchestrator burn 0.96M, agent_hashes include theorist +
      implementer + critic).
- [x] Read `runs/_loop/seed.md` (2026-05-15 light-mode, julia
      forbidden, manuscript-section text edits permitted).
- [x] Read `runs/_loop/director/turn_7.md` (my T7 dispatch's
      `if_fails_next_step` field anticipated this turn:
      "If theorist closes D1 with a clean mechanism + fix shape
      but the fix is julia-blocked (anko's sweep still running),
      T8 is implementer-text-only writing a design doc
      ... that captures the theorist's verdict for the eventual
      julia implementer turn." T8 generalizes this to a Paper #4
      §IV cash-in, which is the publication-grade form of the
      same artifact.).
- [x] Read `runs/_loop/theorist/turn_7.md` (full T7 derivation +
      citations + publishability assessment — this is THE source
      material for T8).
- [x] Read `runs/_loop/sim/turn_7.md` (T7 implementer report:
      branch `auto/turn_7_fullbdg-F6-mechanism-note` commit
      `6f92776`, 18 lines added, sympy S1/S2 OK).
- [x] Read `runs/_loop/judge/turn_7.json` (PASS, no issues).
- [x] Read `runs/_loop/judge/turn_6_critic_audit.md` (rejected
      mechanism context — needed for §IV.A "why-this-isn't-X"
      paragraph).
- [x] Read `runs/_loop/research/turn_5.md` partial (convention
      chain context — Lima-Pelster, Petrov).
- [x] Read `runs/_loop/director/turn_6.md` + `turn_5.md` partial
      (continuity — T6 and T5 director rationales).
- [x] Read `docs/manuscript/papers/paper4_chaotic_dynamics/main.md`
      partial (line 6 confirms §IV TBD; line 11-30 abstract;
      line 312-330 references TBD).
- [x] Read `src/hamiltonian/interactions/lhy/dispatch.jl:115-128`
      (T7 docstring content verified on main).
- [x] Read ≥1 memory: `full_bdg_F6_polar_broken.md` (2-day-stale
      reminder displayed — superseded by T7 derivation, which
      this turn externalizes).
- [x] Considered NOT dispatching implementer-text — challenged
      with theorist (Option 4, §B4 trap), researcher (Option 3,
      composition not lit-accumulation), design-doc (Option 2,
      redundant with #1), noop (Option 6, quota healthy + cheap
      move available). Implementer-text wins.
- [x] §6 brief is specific: 5 files to read in order, suggested
      §IV.A subsection structure (6-numbered-paragraph outline),
      optional §IV.B, style conventions, falsification /
      out-of-scope, cost cap, julia constraint reinforced.
      Implementer does not need clarifying questions.
- [x] Justified why THIS turn — without the cash-in, T7's
      derivation stays orphan; the cascade closure is incomplete;
      Paper #4 §IV stays TBD. Other moves are weaker.
- [x] `consumed_seed_md: true` — seed.md's spirit (advance
      research, verify implementation against papers, identify
      unimplemented effects, no julia) is satisfied by this turn.
