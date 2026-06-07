# M1 sweep — gate (1) ground-state-ness audit (2026-06-08)

First physics-gated extraction from the on-disk 30-cell rotating-frame
sweep (`runs/sprint5_M1_multistart_groundstate/`, B × Ω, Eu F=6, 24³,
50k atoms). Produced by `scripts/m1_groundstate_audit.jl`.

Gate (1) of the phase verdict: the gradients are gated (master oracle)
and the BdG is anchored (`test_bogoliubov_anchor.jl`), but "gradient
correct" ≠ "this ψ is the ground state". This audit extracts that gate
— fresh re-eval ‖∇E‖ from the saved winner ψ + basin reproducibility
from the (reliable) candidate energies. It is gate (1) only;
saddle-rejection (gate 2, BdG stability) and vortex-resolution (gate 3,
the monopole resolution lesson) are pending.

## Findings

**Save-bug absent for this sweep.** `‖∇E‖_disk ≈ ‖∇E‖_fresh` in every
cell — the spine-G atomic finalization (`3c3c3887`, merged before this
Jun 5-7 run) resolved the two-basin ψ/grad_norm drift; the disk values
are authoritative here.

**Ω=0 column (static phase diagram): SOLID.** All 6 cells converged
(5 GS_confident, multi-seed-reproduced; 1 B=0 Goldstone manifold
floor). The lowest-E basin among 6-7 independent seeds progresses with
the in-plane field:

| B [nT] | Ω=0 winner | seeds→basin | ‖∇E‖ fresh |
|---|---|---|---|
| 0   | polar              | 6→3 | 1.0e-5 (Goldstone) |
| 1   | polar              | 6→4 | 9.8e-6 |
| 2.6 | polar              | 6→4 | 1.0e-5 |
| 5   | antiferromagnetic  | 6→6 | 9.3e-6 |
| 10  | polar_core_vortex  | 7→7 | 1.0e-5 |
| 100 | polar_core_vortex  | 7→7 | 1.0e-5 |

→ **polar → AFM → polar-core-vortex** as B increases (gate-1 confident).
The phase *identity* (these are seed labels of the winning basin) still
needs gate 2 (stability: minimum vs saddle) before it is a phase
verdict.

**⟨L_z⟩ flag — the PCV is legitimate (not suspicious).** Every
converged Ω=0 cell has ⟨L_z⟩ = 0 AND ⟨F_z⟩ = 0 (per-atom), **including
the B≥10 PCV winners**. A mass-circulation vortex winning at Ω=0 would
be suspicious (it costs energy with no rotation to pay for it) and show
⟨L_z⟩ ≠ 0; the measured ⟨L_z⟩ = 0 means the PCV here is a **coreless
spin texture** (Mermin-Ho-like, zero net circulation) — a legitimate
non-rotating ground state. So the polar→AFM→coreless-texture
progression is a clean Ω=0 phase sequence; "polar_core_vortex" is a
seed-label, the physics is a coreless texture. (Ω>0 cells show ⟨L_z⟩
ramping with Ω — the Barnett response — but they are unconverged /
single-seed, not yet trustworthy.)

**Ω>0 columns (the Barnett map): BLOCKED.** 18/30 cells unconverged
(‖∇E‖ ~ 1-4) — the vortex-soft-mode conditioning floor. Only the
high-B/high-Ω corner (B=100 all Ω; B≥5, Ω=0.6) converged, and only
single-seed (GS-ness unverified). The Barnett map is **not extractable
from this sweep** — it needs the preconditioning work (Riemannian /
Noether, spine C/D), a real methodological blocker, not tooling gravity.

## Partition

```
GS_confident       5 / 30   (Ω=0, B≥1)
converged_single   6 / 30   (high-B/high-Ω corner, GS unverified)
goldstone          1 / 30   (B=0, Ω=0)
unconverged       18 / 30   (Ω>0 mid-range, conditioning floor)
```

## Next

1. Gates 2-3 on the Ω=0 column → turn the polar→AFM→PCV progression
   into a stability- and resolution-gated static Eu phase diagram.
   (BdG saddle-rejection needs the F=6+DDI FD-Hessian anchor first.)
2. Preconditioning for the Ω>0 Barnett map before re-running it.
