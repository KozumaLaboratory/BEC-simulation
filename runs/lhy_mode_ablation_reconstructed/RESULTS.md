# Five-mode LHY ablation, reconstructed 2026-07-31

Reconstruction of the Ch.5 §5.2 ablation whose config
(`runs/lhy_mode_ablation/`) has never existed in any commit. **Not a
reproduction** — see the header of any config here for which parameters are
recovered and which are assumed, and for the one stated parameter (`box=10`)
that contradicts the sibling report and was not silently resolved.

TSUBAME job 8308113, cpu_16, `OPENBLAS_NUM_THREADS=1`. ITP to `tol=1e-9`,
all five arms `converged = true`.

| mode | `lhy_kind` stored | E | peak n | peak n / off |
|---|---|---:|---:|---:|
| `none` | `none` | −881.0854 | 0.0100710 | 1.000 |
| `scalar` | `ScalarLHY` | −880.9929 | 0.0096307 | **0.956** |
| `polar_contact` | `PolarContactLHY` | −880.9812 | 0.0095781 | **0.951** |
| `polar_dipolar` | `PolarDipolarLHY` | −880.9804 | 0.0095749 | **0.951** |
| `full_bdg` | `FullBdGLHY` | −880.9857 | 0.0095982 | **0.953** |

## LHY is active in every arm this time

Each arm stores a distinct `lhy_kind`, a distinct energy and a distinct peak
density. That is the check the original comparison could not pass: three of its
five rows ran with the tabulated table silently zeroed, so "all five agree" was
guaranteed regardless of the physics. Here the arms differ from `none` and from
each other, so the comparison could have come out otherwise.

(`interactions_c_lhy = 0` for the tabulated kinds is expected — they carry a
table, not a scalar coefficient. The scalar arm stores 529.4.)

## What it says about §5.2

**The qualitative conclusion survives.** A 4.9 % suppression of peak density is
not an LHY-balanced droplet; mean-field DDI still dominates. §5.2's
"LHY is sub-leading" holds, and so does its "closure choice barely matters" —
the four LHY closures agree to **0.58 %** among themselves.

**The number that carried it does not.** §5.2.3 lists peak-density ratios of
0.998 / 1.005 / 0.999 / 1.001 against `off` — LHY as a sub-1 % effect. Under
current code the ratios are 0.956 / 0.951 / 0.951 / 0.953: **~4.9 %, five times
larger**, and consistently one-signed. The old table's agreement *with* `off` was
the vacuous part, and it is the part §5.2 quoted.

## What this does NOT settle

- §5.2.3 also tabulates **filament length in μm**. This is a ground-state ITP
  ablation and produces no filament; those five numbers remain unchecked.
- `box=20` was used. §5.2.2 says `box=10`. A 1-voxel filament claim is
  resolution-dependent, so neither box should be quoted for the other.
- Assumed parameters (trap, c₁, B, DDI treatment) come from the sibling report,
  not from the lost config. A different assumption set could move these numbers.
