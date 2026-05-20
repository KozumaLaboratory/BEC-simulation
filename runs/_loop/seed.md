# Loop seed — 2026-05-19 late (restrict-mode portfolio)

## Portfolio for restrict-mode period (~2026-05-19 → 2026-05-26)

Anko's reviewer derived from 6-day retrospective: **20+ turn deep
F=6 physics-sim investments are structurally bad ROI (4-5× cost of
clean Tier-3, often unfinished). F-ladder math-route is cheap (4-5 turns
to clean Tier-3) and Sonnet-friendly.** Restrict-mode period is for
F-ladder work + minimal Matsui paperwork + preparation, NOT new F=6
deep investments.

### Investigation pick priority (director_pick.py applies this in order)

**1. `sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19`** (NEW at T122)
   F-ladder math route, T122 already at Hypothesize stage. Continue.

**2. NEXT F-ladder extension** (F=12 or fill F=10 if gap)
   Cheap algebra/Racah CG task, Sonnet-friendly, manuscript-anchored
   (Kawaguchi-Ueda) — same template that produced clean F=2 cyclic
   Tier-3 (T94, 4 turns).

**3. `edh-eu151-vortex-vs-matsui-science-2026` — finalize tier promotion ONLY**
   F1 CORROBORATE already achieved at T117 (in falsifier.result). The
   stuck T118-T122 paperwork loop is the only thing blocking 2.5 → 3.0.
   Dispatch ONE critic_lite turn to confirm state + ONE director turn
   to emit tier_becomes=3.0. Total 2 turns max. Do NOT relaunch deep
   audit; the science is done.

**4. `yan-li-saito-2026-reproduction` REPLAY with new gate** (test 1 inv)
   22 turns spent, halted at Tier 0.4. The new central-falsifier +
   FORM B raw-artifact gate may produce a Matsui-style rescue
   (T117 pattern). Dispatch critic to inspect existing `runs/yan_*` /
   `runs/auto/turn_3*` artifacts. ONE turn test; if rescue works,
   resume; if not, BLOCKED_PENDING_FRONT_LOAD.

**5. (Optional, low priority) Sign-pattern-f9-ta-multiplicity continuation**
   80% retry_ratio so far. Continue ONLY if turns 1-4 above are done.

### Hard constraints during restrict-mode

- **NO new F=6 deep simulation investments.** Eu EdH, F=6 dipolar
  dynamics, anharmonic trap quench studies — all on hold. Reason: 26t
  Matsui + 22t yan-li-saito = 48t / 72M tokens already spent on F=6/dipolar
  with high retry-burn. Front-loading (theorist.md addendum) must precede
  next deep dive.
- **NO new investigations OUTSIDE the F-ladder math route or rescue tests
  above.** seed.md is the picker's hard-lock; director_pick.py honors it.
- **daily_turn_cap=6 (schedule.yaml).** Cap is structural — do not
  attempt to bypass.

### Expected outcomes

- 2-3 new Tier-3 trajectories from F-ladder route (F=11, F=12, possibly F=10)
- 1 Tier-3 finalization (Matsui paperwork)
- 0 or 1 rescue from yan-li-saito (test)
- 0 false closures (central-falsifier gate active)

### When restrict-mode expires (2026-05-26)

- Review F-ladder Tier-3 count + cost data
- Decide on F=6 Eu front-loading scope (theorist.md addendum)
- Decide on TSUBAME first-job (phase diagram sweep)
- Resume normal cadence with portfolio re-balanced

---

# (Archived) Loop seed — 2026-05-19 morning (Matsui re-open priority)

Superseded by the portfolio above on 2026-05-19 late. The Matsui rescue
already succeeded (F1 CORROBORATE at T117); only tier promotion
paperwork remains. Original directive:

**Investigation `edh-eu151-vortex-vs-matsui-science-2026` is re-opened**
(was wrongly closed at T76-T86 on F3 alone; F1 ring formation was
NOT reproduced). Director MUST pick this as next active investigation.

The honest Tier-3 path is **NOT** a new from-scratch simulation. Per
§B1.0:
- `runs/eu151_edh_K3_long/trajectory.png` (May 13, 14.5 ms dynamics,
  K3 + gamma_dr + noise seed, 32³, clean cascade m=+F → m=+5/+4/+3,
  all 13 m states populated in log) is **the primary evidence on
  disk**.
- `runs/eu151_edh_loss_factorial/` has the 4-panel comparison
  (K3 off/on × gamma_dr off/on) with `extract_and_plot.jl`.

(F1 CORROBORATE achieved at T117 via critic independent audit of
`runs/eu151_edh_K3_long/trajectory.csv` — pop_c2 peak 17.08% at
t=4.34 ms, within factor-2 of Matsui t_ring=5 ms.)

---

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
