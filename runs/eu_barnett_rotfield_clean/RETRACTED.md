# RETRACTED — superseded by `runs/eu_barnett_redo/`

Every quantitative result produced in this directory is withdrawn. The physics
questions it asked were the right ones and the answers largely survive; the
**numbers do not**. Use `runs/eu_barnett_redo/` instead.

The scripts, figures and CSVs have been removed from the working tree. They
remain in git history (`git log -- runs/eu_barnett_rotfield_clean`) — this is a
retraction, not a deletion, and the record of what was measured is intact.

## Why the numbers are withdrawn

Four defects, each found in the 2026-07-28/31 redo and each affecting every run
made here.

### 1. The ±Ω arms were not mirror images

`run_rebuild.jl` selected the rotation sense with `RB_STIR_BXPHASE = ±π/2` on
`Bx`, with `By` at phase 0. The recorded sign check reasoned with **cos**;
`SinusoidalWaveform` evaluates **sin** (`src/foundation/waveform.jl`). Measured:

| arm | B(0) |
|---|---|
| `+π/2` (+Ω, the headline) | **+x̂** |
| `−π/2` (−Ω) | **−x̂** |

The rotation senses were right, but the ground-state spin sits along **−x̂**
(`⟨F⟩ = (−5.999, 0, 0)`; `p < 0` for `g_F > 0`, so the spin is anti-parallel to
B). So `+Ω` began 180° anti-aligned — a maximal-torque kick — while `−Ω` began
aligned. The two arms differ by an initial condition on top of the rotation
sense, so the reported asymmetry (+2.10 vs −0.42, written up as
"chirality-selective depolarisation") **has an untested alternative
explanation**.

Correct construction: the setup is symmetric under reflection in the xz-plane,
so the mirror arm negates **By** and leaves Bx identical. Both arms then start
at B(0) = −x̂, aligned. Done this way the arms are mirror images to four digits
in every column.

### 2. Scalar LHY was 3.87× too weak

Every run here used `lhy: {kind: scalar}` with no explicit `c_lhy`, which took
the auto-derive path that PR #108 later corrected (short by `π(a_s/a_ho)√N`).
LHY was 1.6% of the mean field instead of 6.2%.

### 3. The J_z ledger never closed, and the reason was misidentified

The residual was closed here as "time discretisation, converges as dt→0". It is
not: at fixed geometry, halving dt reproduces the leak to six digits. It was the
**xy box**. Enlarging it 28 → 35 at identical dx cuts the leak 13× (0.243 →
0.018). Only xy matters — `J_z` is angular momentum about z, so wrapping in x or
y corrupts it while density through the z faces does not, which is why the z-box
fix attempted here changed nothing.

### 4. `compute_gamma_lhy` was undefined

The `kind: rotating_basis` ground-state auto-path called a function the engine
retirement had deleted, so that path raised `UndefVarError` for every Eu run.

## What survives

- **The protocol.** Two stages (stir, then quench to B = 0) and a transverse
  `F_z = 0` start are both necessary, and the redo kept them unchanged.
- **The controls as a design.** Ω = 0 and DDI-off were the right controls; the
  redo reran them and they are now the cleanest results in the study
  (`J_z ≡ 0` with leak 7.5e-07; `L_z ≡ 0` with leak 2.1e-12).
- **The TSUBAME operational recipe** (ControlMaster socket, node-local NVMe
  scratch, sparse snapshots), which is folded into memory.

## What replaced the headline

The headline here was an absolute conversion, `F_z → +2.08`. The redo shows that
**the absolute conversion is a transient**: it rises through the entire quench
and rises with the box (0.92 / 1.01 / 1.06 at box 35 / 42 / 46.7 with dx held
exactly), because the cloud expands freely once the field is off. Quoting it
means quoting the observation window.

The converged quantity is the **efficiency**:

> **ΔF_z / |ΔL_z| = 0.991** — box-independent and time-independent.
> Of the orbital angular momentum lost, ~99% becomes spin.

See `runs/eu_barnett_redo/README.md`.
