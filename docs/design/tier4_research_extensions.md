# Tier 4 research extensions

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

The original 50-scenario plan flagged three items as "別ロードマップ" (separate roadmap, essentially new research projects). Each of these needs a real physics + ML investment, not just engineering. This doc pins down the scope so a future contributor can pick one up.

## #61 Bayesian optimization over a YAML scan

**Goal**: replace brute-force grid sweeps (e.g. the 144-point `eu151_phase_pq_hires` scan) with sequential Bayesian search that spends compute on the most informative points.

**Use case**: locate the supersolid critical point in (p, q) space with ~30 well-chosen evaluations instead of a 12×12 grid.

**Stack**:
- `BayesianOptimization.jl` or `Surrogates.jl` for the GP-EI loop
- An "evaluation" = `run_yaml` on a single-point config + extract a scalar objective from the result `.jld2` (e.g. `analyze/bogoliubov/max_growth`)
- Async dispatch so the GP doesn't block waiting for the 4-min eval

**POC scaffold**: `scripts/research/bayesopt_skeleton.jl` (this commit). Hand-rolled placeholder, not a real BO loop — reads a known objective function and prints the next suggested point.

**Estimated effort**: 1-2 weeks of physics + GP tuning to get useful results on Eu151 (p, q).

## #62 Differentiable simulation

**Goal**: compute ∇θ E[ψ_GS(θ)] for parameters θ (interaction strengths, trap frequencies, Zeeman fields) so we can do gradient-based parameter-fitting against experimental data.

**Use case**: fit measured Faraday signals against simulated ones by Adam-stepping the interaction parameters.

**Stack**:
- `Enzyme.jl` for source-to-source AD (handles the FFT-heavy hot path better than `ForwardDiff.jl` or `Zygote.jl`)
- The hot loop must be fully type-stable + non-mutating where possible; psi_scratch (commit 8e7b607) helps.

**POC scaffold**: `scripts/research/diff_skeleton.jl` (this commit). Differentiates a 1D scalar GP toy with respect to the trap frequency. Real spinor F=6 + DDI requires Enzyme rules for cuFFT and our custom spin-rotation kernel.

**Estimated effort**: 2-3 weeks of Enzyme rule writing + validation against finite differences.

## #63 Neural Quantum States (NQS)

**Goal**: represent strongly-correlated phases (beyond mean-field GP) with a neural network ansatz trained via Variational Monte Carlo.

**Use case**: super-Tonks-Girardeau regime where Bogoliubov fails; spin liquids in a frustrated Eu151 lattice.

**Stack**:
- `Flux.jl` for the network (RBM, FNN, or transformer)
- `MCMC` sampling using Metropolis-Hastings on configurations
- Wirtinger derivatives for complex-amplitude networks

**POC scaffold**: `scripts/research/nqs_skeleton.jl` (this commit). Defines a tiny RBM ansatz for an N=4 spin chain, runs 100 Metropolis samples, prints variational energy. Not connected to the GP solver — NQS lives in a different formalism (lattice basis vs continuous ψ(x)).

**Estimated effort**: 2-4 weeks for one published-paper-quality result.

## Why these are deferred

All three are research projects that produce papers, not features. The scaffold scripts in this commit exist so the next contributor can:

1. Read the scaffold + comments to understand the intended scope.
2. Run it as a smoke test that the dependency chain installs.
3. Extend one piece at a time without re-deriving the architecture.
