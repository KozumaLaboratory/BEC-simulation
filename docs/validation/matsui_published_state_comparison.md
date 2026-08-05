# Their published 5 ms state is in the deposit, and our cloud has the same shape

> **FROZEN 2026-07-31.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

2026-07-31. Found while looking for the run parameters that `setup_parameters`
does not carry. Type A (code-to-code) unless marked.

## `dataset_fig1/F.txt` is their simulation's own output

Buried in `dataset_raw.zip` (which is otherwise absorption images) are four
MATLAB analysis scripts and two 4.65 MB text files. `F.txt` opens with their
Fortran's own writer header:

```
#dimm=====         3
#Nx=======       128
#Ny=======       128
#Nz=======       128
#dx======= 4.000E-01
```

so **the published simulation ran at 128³, `dx` = 0.4 aHO** — confirmed, not
inferred from `setup_parameters`.

The body is a y-integrated column density, 13 components, `im = −6 … +6`. Its
sum × `dx²` is 2.4999955 = `1/dy`, i.e. the writer omits the `dy` factor and the
state is normalised to `∫|ψ|² = 1`. Integrating gives:

| m | −6 | −5 | −4 | −3 | −2 | −1 | 0 |
|---|---|---|---|---|---|---|---|
| `F.txt` | 0.4273 | 0.2352 | 0.1562 | 0.0989 | 0.0523 | 0.0214 | 0.0067 |
| their Fig. 2C at **5 ms** | 0.4290 | 0.2352 | 0.1561 | — | — | — | — |

**`F.txt` is the 5 ms state of the run behind Fig. 2C**, at B = +2.6 nT. So the
spatial structure of the state we are trying to reproduce is in hand — not the
integrated populations, but every component's column density.

(`G.txt` is the same run released: norm 0.008, filling the whole 51.2 aHO box.)

## The two clouds have the same shape to 0.4 %

Assumption-free second moments of the y-integrated density, about the centroid:

| | `⟨x²⟩/⟨z²⟩` |
|---|---|
| theirs, `m = −6` at 5 ms | **0.7737** |
| **ours, ground state** | **0.7767** |

A bare harmonic trap with `ω_z/ω_x = 130/110` demands **1.3967** — the cloud
should be *shorter* along the tight axis. Both codes give 0.78, and the reason is
**magnetostriction**: a z-polarised dipolar gas stretches along z because dipoles
attract head-to-tail. At `ε_dd ≈ 0.54` that is enough to invert the aspect ratio.

Two independently written codes agreeing to **0.4 %** on this is the strongest
spatial agreement found in the whole campaign, and it constrains the trap, the
DDI and `c_total` jointly at that level.

## Same shape, different size

| observable | theirs | ours | difference |
|---|---|---|---|
| shape `⟨x²⟩/⟨z²⟩` | 0.7737 | 0.7767 | **0.4 %** |
| size, rms radius [a_ho] | 2.619 | 2.849 (5 ms) / 2.927 (GS) | **8 %** |
| transfer, `m = −6` fraction | 0.4273 | 0.2661 | 38 % |

**Shape agreeing while size does not is the signature of a different `N`.** `N`
sets `c_total`, which moves the size (`R ∝ c^{1/5}`) and barely touches the
aspect ratio. A trap or DDI discrepancy would break the shape first, and it does
not. Thomas-Fermi puts our measured 2.927 at `N = 5×10⁴` (predicts 2.860) and
their 2.619 nearer `N = 3.5×10⁴` (predicts 2.663) — which is the value shipped in
`setup_parameters` while the published curves total 49999.9.

## Two inversions retracted

- **A Thomas-Fermi fit to their 5 ms column density** returned `N ≈ 1.6×10⁴`,
  inconsistent with the rms-based estimate. The 5 ms state is a multi-component
  cloud with vortex rings and does not follow `(1 − r²)^{3/2}`. Retracted.
- **`N` inferred from the transfer** (`≈ 4.3×10⁴`) came from a broken scan.
  `N_atoms` lives in three places in these configs — `defaults.interactions`,
  the `ground_state` block, and by injection into `dynamics` — and the scan
  overrode only the second. The `N = 3.5×10⁴` arm ran a 3.5e4 **ground state**
  under 5e4 **dynamics** couplings. It was caught by a positive control on the
  cloud size: that arm's 5 ms rms came out **3.121 a_ho against 2.948 at
  N = 5×10⁴**, when a smaller `N` must give a *smaller* cloud. An
  out-of-equilibrium state expands. Retracted.

  The irony is the finding: that is exactly the initial-state/dynamics mismatch
  hypothesised for *their* code, reproduced by accident in ours because one knob
  lives in three places. `fig4b_natoms_fixed_n32.yaml` moves all three in
  lockstep and drops `N_atoms` from `defaults` so nothing can be injected behind
  the scan.

## Resolved

`N = 3.5×10⁴` reproduces all three at once (UGE 8310027 task 14):

| at +2.5 nT, 5 ms | Matsui | ours N = 3.5×10⁴ | agreement |
|---|---|---|---|
| `m = −6` fraction | 0.4273 | 0.4158 | 2.7 % |
| rms radius [a_ho] | 2.619 | 2.687 | 2.6 % |
| shape `⟨x²⟩/⟨z²⟩` | 0.899 | 0.877 | 2.4 % |

and the full 45-field dip follows: centre −2.510 against their −2.549, width
12.89 against 12.75, every field within 1.1 % (UGE 8310846 task 15).
`matsui_residual_root_cause.md` carries the resolution.
