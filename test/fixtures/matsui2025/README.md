# Matsui et al. (2025) EdH published datasets — CSV extracts

## Source and licence

H. Matsui, Y. Eto, T. Hirano *et al.*, *Observation of the Einstein–de Haas
Effect in a Bose–Einstein Condensate* (2025).
Deposited data: **Zenodo record 17303925**, licensed **CC BY 4.0**
(<https://creativecommons.org/licenses/by/4.0/>). Licence verified 2026-07-30.

These `.csv` files are verbatim extracts of the depositors' `.xlsx` sheets —
same rows, same columns, same values, no filtering or rescaling. Regenerate
with:

```
julia --project=. scripts/validation/matsui_dataset_to_csv.jl <dir-with-xlsx>
```

The `.xlsx` originals and `dataset_raw.zip` (1.81 GB of absorption images) are
**not** committed. Do not unpack `dataset_raw.zip` inside this repository.

## Contents

| file | rows | abscissa | columns 2–14 |
|---|---|---|---|
| `dataset_fig2_exp.csv` | 160 | `Time, t (ms)` | `N_{-6}` … `N_{6}` |
| `dataset_fig2_theo.csv` | 2766 | `Time, t (ms)` | `N_{-6}` … `N_{6}` |
| `dataset_fig4_exp.csv` | 227 | `Magnetic field, B (nT)` | `N_{-6}` … `N_{6}` |
| `dataset_fig4_theo.csv` | 61 | `Magnetic field, B (nT)` | `N_{-6}` … `N_{6}` |

`dataset_fig4_exp.csv` is **eight concatenated scans**, not one: rows 1–93 are
three repeats over `B ∈ [0, 17.5] nT` and rows 94–227 are four-and-a-bit
repeats over `B ∈ [−17.5, 0] nT`, each on a 0.5833 nT step. Fig. 4B plots the
per-field mean (4 shots on the negative side, 3 on the positive), so average
over repeats before doing anything with it.

`dataset_fig2_theo.csv` and `dataset_fig4_theo.csv` are **loss-free** — the
shipped Fortran sets `L3loss = 0` for ¹⁵¹Eu *and* `L3loss_eff = 0` globally.
The experimental sheets are not. Do not overlay them as if the same model
produced both.

`_theo` totals are 49999.9, so the published simulations used `Ntot = 5×10⁴`.
The `setup_parameters` shipped in `code.zip` carries `Ntot = 3.5×10⁴`; it is
not the parameter set behind the published curves.

## What is gated

`test/validation/test_matsui_fig4_dip.jl` (tier `ci`) pins the Fig. 4B dip
centre and half-depth width measured off these files by `resonance_dip`, for
both the simulated and the measured curve. See
`docs/validation/parameter_contract_with_Ueda.md` §0.5.
