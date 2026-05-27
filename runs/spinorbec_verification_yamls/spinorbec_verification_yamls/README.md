# SpinorBEC verification YAML suite

Purpose: fast, low-resolution benchmark configurations for checking that the simulator reproduces analytic or literature-standard physics before running expensive Eu-151 production jobs.

This is not a performance suite. Keep grids small, disable GPU-only assumptions, and compare conserved quantities / phase labels / qualitative spectra first. A failure here means the production physics is not trustworthy.

## Run pattern

From the repository root:

```bash
julia --project=. -e 'using SpinorBEC; run_yaml("path/to/yamls/00_scalar_free_uniform_stationary.yaml")'
```

For syntax-only expansion, use:

```julia
using SpinorBEC
run_yaml("path/to/file.yaml"; dry_run=true)
```

## Recommended order

1. Run `00` and `01`. These isolate scalar split-step, FFT normalization, harmonic trap units, and norm/energy drift.
2. Run `02` and `03`. These verify the spin-1 contact-interaction sign convention: polar for c1>0, ferromagnetic for c1<0.
3. Run `04`. This verifies the spin-2 singlet-pair/cyclic/nematic sector.
4. Run `05`. This checks diagonal Zeeman phase evolution without any population transfer.
5. Run `06`. This checks coherent spin-exchange dynamics and conservation of total magnetization.
6. Run `07`. This checks the Bogoliubov analyzer against a stable polar spin-1 state.
7. Run `08`. This checks the DDI kernel convention in a spherical spin-polarized cloud.
8. Run `09`. This is a toy EdH / spin-orbit transfer sanity check, not a quantitative Matsui reproduction.

## Acceptance targets

See `checks/expected_observables.yaml`. The tolerances are intentionally loose enough for coarse grids, but tight enough to catch sign mistakes, missing half steps, FFT normalization errors, or wrong c1/c2/DDI conventions.

## Notes

- These use `backend: cpu` so they can run on laptops and CI. Change to `cuda` only after CPU passes.
- The suite uses the unified `B:` block, not the older `zeeman:` / `B_hat:` user-facing syntax.
- When a test says “phase should be polar/ferromagnetic/cyclic,” use the `phase_classify` result and also inspect spin order and magnetization density. Do not rely only on the string label.
- The spin-mixing test is intentionally a conservation and qualitative oscillator test. For a strict SMA period test, fit populations from `dynamics/component_populations` and compare with the analytic SMA ODE for the chosen `c1`, `q`, and density.
