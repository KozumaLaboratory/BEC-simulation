# Mixed-precision (ComplexF32) simulation — design sketch

Target: run the full split-step pipeline with ψ ∈ ComplexF32 to halve VRAM
and roughly double FFT throughput on GPUs, enabling 256³–384³ grids on an
H100. Not yet implemented — this note captures the plan.

## Scope of the refactor

The hot path (split-step, FFT, DDI convolution, spin-matrix applications)
is fully parameterised on backend via `AbstractBackend`. Precision is NOT
parameterised — every buffer is allocated as `ComplexF64` through
`make_workspace`. The refactor has to:

1. Add a type parameter `T<:AbstractFloat` to `Grid`, `Workspace`,
   `InteractionParams`, `DDIField`, `FFTPlans` so `psi::Array{Complex{T}}`
   propagates cleanly.
2. Adjust spin-matrix tables and Clebsch-Gordan constants to use `T`
   (these are compile-time; trivial).
3. Adjust the FFT plan factories (`plan_fft!`, `plan_rfft`) to accept
   `T` and produce typed buffers.
4. Adjust all math kernels in `split_step.jl`, `ddi.jl`,
   `spin_mixing.jl`, etc. — most will be type-generic already, but
   hard-coded `ComplexF64` literals and `Float64` constants need
   conversion.
5. The analyzers (energy, observables, stability, Bogoliubov) need to
   either accept `T` or explicitly promote inputs to `Float64` for
   numerical robustness (several use small-eigenvalue solves).

## Risk areas

- **DDI FFT padding**: `ddi_padded` and the padded-convolution Fourier
  coefficients need careful tolerance checking at F32. On a 256³ grid the
  accumulated error over 1e6 time steps could erode norm conservation.
- **ITP (imaginary-time propagation)**: energy convergence thresholds
  like `tol: 1e-10` are below F32's unit roundoff (~1.2e-7). Users will
  need guidance on realistic F32 tolerances (`tol: 1e-6` typical).
- **LBFGS polish**: F32 gradient norms may floor at ~1e-6; current
  convergence check (`grad_norm < tol` with tol=1e-8) needs relaxation.
- **Observables crossing precision boundary**: `magnetization`,
  `component_populations` should keep Float64 accumulation to avoid
  drift on long runs.

## Suggested rollout

Phase 1 (low risk) — **started**:
  - `Grid{N,T<:AbstractFloat}` parameterised; `make_grid` takes an
    optional `dtype::Type{<:AbstractFloat} = Float64` kwarg that
    threads through x, dx, k, dk, k_squared. Backward compat via
    the fact that `Grid{N}` is still a valid where-unbound spelling
    that accepts any T, so existing method signatures keep
    working; the 17/17 test_grid suite passes without edits. ✓
  - Next in this phase: FFTPlans{P,IP,T} with a matching dtype
    kwarg on `make_fft_plans` and `make_rfft_plans`.
  - Dual-dtype tests: run a 32³ smoke test in F32 vs F64 and verify
    observables agree to ~1e-5 relative.

Phase 2:
  - Parameterise `Workspace{...,T}`. Update `make_workspace` with a
    `dtype::Type{<:AbstractFloat}` kwarg, default `Float64`.
  - YAML knob: `dtype: float32` at the pipeline level.
  - Convert split-step and DDI kernels to be `T`-generic. Run
    regression suite.

Phase 3:
  - Analyzer audit: which ones can run at T, which must promote.
  - Tighten ITP convergence semantics at F32 (warn + cap tolerance).

Phase 4:
  - GPU benchmarking on 256³ F32 vs 128³ F64 to quantify the win
    (expected: ~2× throughput, ~½ VRAM).

## Escape hatch

If the refactor proves too invasive, the compromise is to keep the
simulation at F64 but write snapshots at F32 (already done via
`dynamics/psi_snapshots_streamed`). That gives the disk saving without
touching the hot path — at the cost of still needing F64 VRAM budget
for the live ψ.
