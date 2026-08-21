# Rotation-assisted EdH quench — what to set in the lab

**LIVE.** This is the maintained prescription for the ¹⁵¹Eu EdH-quench protocol.
It exists because `docs/manuscript/klaus_protocol_sheet.md` is a **frozen**
2026-05-26 record that nevertheless carried a numbered lab protocol, so a reader
following it set values that had been refuted. That sheet is history; this page
is the instruction.

Authority for every number here: `docs/campaign/edh_quench_polarisation_decision.md`
(§9–§11) and the per-claim status in `docs/campaign/claims.toml`. If the two
disagree, the ledger wins — it is the only one with a machine-checked status field.

**Type B**, not C. Nothing here is compared to a published measurement.

---

## 1. The preparation is the whole ballgame

> **Prepare the stretched state ANTI-ALIGNED with B — the Zeeman-HIGHEST state.**

Not "m = ±F". The `m` label means the opposite thing at the opposite field sign,
and reading an `m` without its field is the error that produced issue #343 twice.
State the relative orientation; derive the label.

Under the project convention (B_z > 0, g_F > 0, `H = −p·F_z` with `p ≡ −g_F μ_B B`)
the anti-aligned seed is **m = +F**. Every *other* Eu arc in this project prepares
a Zeeman ground state and is aligned; the two families are not in conflict, they
ask different questions.

Get this wrong and the effect is not merely smaller — it is **absent**: the
rotation contrast is +16.5 % at the anti-aligned preparation and −0.45 %, of the
wrong sign, at the aligned one.

## 2. Do not rotate the trap

> **Weaken the radial trap to ω_⊥,eff / ω_⊥ = 0.71 at B = 2.6 nT.** No rotation.

A *static* radial trap at that frequency reproduces the entire "rotation-assisted"
enhancement to **0.06 %** across the sampled range. The mechanism is
**centrifugal, not Coriolis**: the rotating frame's −½Ω²ρ² term is what acts, and
it is even in Ω.

Three consequences worth stating separately, because each retires a piece of
older advice:

- **Chirality is irrelevant.** The response is even in Ω to ≤ 0.124 %, and Ω = 0
  is the *minimum* — both senses enhance identically. Any instruction to
  "counter-rotate against the stretched-spin direction" is void, and the whole
  "map the simulation's Ω sign onto a lab rotation direction" caveat disappears
  with it.
- **The variable is radial confinement, not density.** Weakening ω_z instead, to
  the same mean trap frequency ω̄, lands *below* baseline — it recovers −36 % of
  the gain. Same density scaling, opposite sign of effect.
- **The upper bound is physical.** The cascade collapses as |Ω| → ω_⊥, where the
  effective radial trap vanishes. The window is bounded by the centrifugal limit,
  not by a resonance.

Equivalently in the old variable, if you must: |Ω*|/ω_⊥ = 0.68 ± 0.04. Two
significant figures. The fit gives δ ≈ 0.042; a third digit is not supportable at
one seed.

## 3. The field is not a free knob — the prescription does not transfer

| B | what to set | status |
|---|---|---|
| **1.3 nT** | — | **No operating window exists.** +1.8 % across a flat range in ω_eff ∈ [0.65, 1.0]. This is an absence, not a gap: there is nothing to relocate the old `≈ 0.3` to. **Do not re-fit it.** |
| **2.6 nT** | **ω_⊥,eff / ω_⊥ = 0.71** | The prescription. +24.9 % over the unweakened trap. |
| **5.2 nT** | — | **Nothing is quotable.** Old `[0.5, 0.6]` **REFUTED**, and so is the `two branches` reading that replaced it: the ω_eff ordering **INVERTS with hold duration** (ω_eff 0.650 is 5.05 % *below* 0.550 at 8 ms and 6.2 % *above* it at 16 ms). Do not set a value at this field from simulation yet. §11.5. |

Three fields, three different kinds of answer, and only one of them is a number.
That is the finding, not a failure to converge.

**At 10.4 nT** the ω_eff response is a **clean single peak at ω_eff = 0.650,
+49.5 %** over ω_eff = 1 — the largest *relative* enhancement of any field
measured, on the *smallest absolute* transfer (0.30 against 0.66 at 2.6 nT).
Zeeman re-pinning costs a factor 2 in absolute signal but does not close the
channel, and weakening the trap helps proportionally more where it is nearly
closed. **Quote both numbers or neither**: the relative figure alone sends an
experimentalist to the worst field.

> An earlier version of this paragraph said **+22.4 %** over a flat baseline of
> 0.27574. That is **SUPERSEDED**: the peak had been taken over the whole
> trajectory, which at this field reads the pre-hold transient rather than the
> hold. Read inside the hold the baseline is 0.20139. §12.1, §12.2.

Not a prescription: 32³, one seed, no grid check at this field.

## 4. What bounds these numbers

Read this before quoting any value above.

- **Everything is one seed, 32³, `lhy: none`, one hold duration, CPU** (64³ where
  stated). The directional findings are far outside the measured floors; the
  *values* are not converged results.
- **Grid is the dominant uncertainty: ±2.5 %**, one-signed (32³ under-resolves the
  cascade rather than scattering about it). It dwarfs everything else.
- **dt/2 reproducibility floor: 0.029 %.**
- **Seed floor: 0.000 %** over 5 seeds — and the seed was *proved live* (state
  overlap 0.9999997, growing to 1.9e−5 by the end), so this is a measured zero and
  not a dead knob. The observable is deterministic on this protocol and duration.
  Do not read that as generally true: the cascade amplifies the seed by two orders
  over the run, and a longer hold may reach the observable.

## 5. What to measure

`P_adj` — the population two rungs down the cascade **from the prepared state**,
not from component D. Hard-coding it to (D−1, D−2) is correct only for an m = −F
seed and produced `P_adj = 0.00000` on the one arm built to test for a null.

At Matsui-scale N ≈ 5×10⁴ the cascade is already saturated (P_exc = 0.816), so
**P_exc has no headroom** and the enhancement shows up on P_adj (+6.4 %). An
older acceptance gate asking for "P_exc rises ~30 %" is refuted as posed: Ω does
not create excitation, it *concentrates* it.

## 6. Four traps that all print a clean, plausible number

None of these announces itself. Check each before trusting a repeat.

1. **`result.jld2["psi"]` is the state at the START of the dynamics**, not the end
   — for a multi-step pipeline it is the ground state. Reading it makes every arm
   look like a null for a signal that reaches 0.76. Use the streamed snapshots.
2. **The quoted observable is a PEAK**, and the run's last frame is far past it.
3. **`gauge_fix: false` means two ITP runs differ by a global phase**, so a raw
   `|a − b|` comparison of ground states reads ≈ 1.4|a| and looks like a live
   knob. Use an overlap.
4. **`P_adj` must be defined relative to the prepared state** (trap 4 above).

## Superseded predecessors

- `docs/manuscript/klaus_protocol_sheet.md` — **frozen 2026-05-26.** Historical
  record; its numbered protocol no longer issues instructions.
- `docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md` — frozen; same.
- `docs/archive/klaus_quench_protocol_pivot_2026-05-26.md` — archived.
