# Weak-field ¹⁵¹Eu ground-state library (reuse guide)

> **FROZEN 2026-07-27.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

The pinned B-scan (`scripts/eu_bscan_pinned_continuation.jl`) produces a
**reusable dataset of converged ground states** ψ(B) across 0–90 µG, not just
animation frames. Each `frame_NNN/psi.jld2` is a self-describing state that
seeds finer runs, dynamics, and analysis — so this region is computed once and
reused, not re-solved every time.

## Layout

```
figs/eu_bscan_pin_tight/          # canonical store (64³, tol=1e-5, pin b_x=2e-3)
├── frame_001/ … frame_046/
│   ├── psi.jld2                   # the converged GS ψ + full metadata
│   ├── density_xy.csv fx_xy.csv … # z-midplane fields (animation)
│   └── populations.csv
├── frames.csv                     # frame ↔ B_uG + E, |∇E|, Fz, F⊥
└── library.csv                    # physics-keyed index (built by eu_gs_library.jl)
```

Each `psi.jld2` carries: `psi`, `B_uG`, `pin_bx`, `grid_n_points`,
`grid_box_size`, `atom_name`, `c0`, `c1`, `c_dd`, `E_total`, `grad_norm`,
`converged`, `last_step` — and (new-schema runs) the full `load_state` keys
(`t`, `step`, `zeeman_q`, `c_dict`, `c_lhy`, `dt`, `imaginary_time`).

## Reuse recipes

```julia
using SpinorBEC   # gs_library/load_gs/merge_gs_library live in src since
                  # 2026-08-18 (src/workflow/io/gs_library.jl); the former
                  # scripts/eu_gs_library.jl + eu_merge_library.jl are retired.

# 1. Discover — index all states (writes library.csv), sorted by B.
lib = gs_library("figs/eu_bscan_pin_tight")

# 2. Load the converged GS nearest a field.
e = load_gs("figs/eu_bscan_pin_tight"; B_uG=50)     # e.psi (host array), e.meta

# 2b. Or from the MERGED physics-keyed library (built by merge_gs_library()).
e = load_gs(; κ=1.8, B_uG=61)                        # figs/eu_gs_library/
```

**Seed a finer / different run** (same grid → straight seed; different grid →
`upsample_spinor` first):

```julia
find_ground_state_lbfgs(; grid=g, atom=Eu151, interactions=..., c_dd=e.meta.c_dd,
    zeeman=static_zeeman(Bz=..., Bx=e.meta.pin_bx), enable_ddi=true,
    psi_init=e.psi, tol=1e-5)
```

**Feed a dynamics run** — upgrade the current run once, then use `load_state`:

```julia
make_load_state_compatible("figs/eu_bscan_pin_tight")   # add t/step/… in-place
s = load_state("figs/eu_bscan_pin_tight/frame_020/psi.jld2")
# s.psi, s.grid_n_points, s.c0, s.c1, s.c_dd, s.zeeman_p → make_workspace(psi_init=s.psi, …)
```

## Notes

- **Never resume across a changed B-grid.** `frame_NNN ↔ B` depends on
  `(BMAX, NB)`; point a new B-range at a FRESH output dir (the resume logic keys
  on `frame_NNN/psi.jld2` presence, not on B).
- The scan is itself resumable: re-running the same `BS_OUT` reloads existing
  frames and continues from the first missing one.
- `converged=-1` in the index = an older-schema file (pre-`converged` key); run
  `make_load_state_compatible` to normalise, or just use `load_gs` (schema-tolerant).
