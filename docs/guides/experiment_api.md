# Experiment / Batch — the unified workflow API

`Experiment` is the unit object of SpinorBEC. A pair

```
(spec, store)   →   outdir derived via SHA-256 of canonical spec bytes
```

owns the full simulation lifecycle: define → persist → run → observe.
Users never name an outdir — the spec uniquely determines it
(content-addressable storage, Nix-derivation style). `Batch` is a
`Vector{Experiment}` paired with the sweep axis they vary over.
Together they subsume the scattered `run_yaml + skip-if-cached loops +
RunResult + free observable functions` patterns that used to live
across `scripts/`.

This guide is a reference. For the REPL-first builder DSL
(`config / B / ddi / lhy / loss / save / ramp / rate / ground_state /
dynamics / analyze`) see `docs/reference/yaml_schema_reference.md`.

---

## Quick start

```julia
using SpinorBEC

spec = config([
    ground_state(
        atom="Eu151", grid=32, trap=(1.0, 1.0, 0.25),
        interactions=Dict("N_atoms"=>30_000, "omega_ref"=>628.3,
                          "c1_ratio"=>-0.005),
        ddi=ddi(secular=false), lhy=lhy(:none),
        B=B(Bz="-0.01 Gauss"),
        initial_state=:m_minus_F, init_sigma=1.5,
        dt=0.005, n_steps=2000, tol=1e-9,
    ),
    dynamics(
        duration=20.0, dt=0.005,
        B=B(Bz=ramp(0.01, 2.6e-5)),
        loss=loss(K3_si=1e-41),
        save=save(every=50, psi=true),
    ),
    analyze(:phase_classify, :winding_map, :energy_decomposition),
])

exp = Experiment(spec)       # outdir auto-derived: runs/<16hex>/
outdir(exp)                  # e.g. "runs/12174e883326ecac"

write_run!(exp)              # writes config.yaml into outdir
run!(exp)                    # runs (idempotent — no-op if result.jld2 exists)

exp.times                    # Vector{Float64}, snapshot time axis
exp.peaks                    # max(total_density) per snapshot
exp.Fz_t                     # ⟨F_z⟩ trajectory
exp.classification           # :delay  / :collapse / :stable_arrest / …
exp.density_at(20.0)         # 3D density at t≈20 (closest snapshot)
exp.density_stats_at(20.0)   # (peak, fwhm_x, fwhm_z, on_axis, σ/μ)
```

The Experiment is cheap to construct (no I/O until you touch an
observable). Repeated property access is O(1) cache hits. Identical
specs share an outdir automatically — re-running the cell finds the
cached result.

---

## Content-addressable storage (CAS)

A spec hashes to a 16-hex content id via SHA-256 of its canonical bytes
(`{sorted_key:value,...}` recursively, Float64 in `%.17g`, NaN/Inf
errors). The id is the cell's directory under the store root:

```julia
content_id(spec)             # "12174e883326ecac"
outdir(exp)                  # "<store.root>/12174e883326ecac"
```

Store root defaults to `runs/`, overridable via `ENV["SPINORBEC_STORE"]`
or an explicit `CASStore("/data/runs")` passed as `store=`.

Properties this gives:

| Class of bug | After CAS |
|---|---|
| edit spec, forget to rename outdir | impossible — hash changes automatically |
| same spec run twice | automatic dedupe |
| naming scheme drift across batches | no naming at all |
| "which dir is the latest run of this config?" | the question dissolves |
| multi-node cluster collision on shared FS | content addresses are unique per spec |

---

## Construction

```julia
Experiment(spec::Dict; store=default_store(), outdir=nothing)
Experiment(yaml_path::AbstractString; store=default_store())
```

- `Experiment(spec)` — outdir auto-derived from `content_id(spec)`.
  Pass `outdir=` only when overriding CAS (e.g. for migration); doing
  so disables CAS dedup for that Experiment.
- `Experiment(yaml_path)` — outdir resolution is four-way:
  1. content_id CAS dir if it already holds a result;
  2. else `yaml`'s own dir if it holds a result (directory-per-config form);
  3. else legacy `runs/<base>_<hash>/` via `find_run_dir` (read-only
     fallback for pre-CAS artifacts);
  4. else the empty CAS dir as the write target for the next `run!`.

---

## Lifecycle

```julia
write_run!(exp)              # write config.yaml into outdir
run!(exp; force=false)       # idempotent run; force=true to rerun
status(exp)                  # :cached | :stale | :pending | :missing
```

`run!` is a thin wrapper over `run_yaml(cfg_path)`. When `force=true`
the lazy observation cache is cleared first.

`status` checks the relative mtime of `config.yaml` vs `result.jld2` —
a YAML edit after the run flags `:stale`.

---

## Observables

Plain functions on Experiment — no `getproperty` magic. First call
reads the jld2 (or computes from RunResult); subsequent calls hit the
in-Experiment memo in O(μs).

| Category | Functions |
|---|---|
| Trajectory `Vector{Float64}` | `Fz_t(exp)`, `Lz_t(exp)`, `Jz_t(exp)`, `norm_t(exp)`, `energy_t(exp)`, `times(exp)`, `peaks(exp)` |
| Per-frame populations | `populations_t(exp)` (single trajectory only), `per_m_t(exp)` (rotating_basis layout) |
| Drift summaries | `Fz_drift(exp)`, `Lz_drift(exp)`, `energy_drift(exp)`, `norm_drift(exp)`, `Fz_rel_drift(exp)`, `energy_rel_drift(exp)`, `norm_rel_drift(exp)` |
| Classification | `classify(exp)` — Symbol from the 5-category collapse classifier |
| Ensemble meta | `n_trajectories(exp)` (1 for single, N for TWA), `integrator_meta(exp)` |
| Parametrised | `density(exp, t)`, `psi(exp, t)`, `density_stats_at(exp, t)` |

Terminal scalar at the end of a trajectory: `last(Fz_t(exp))` etc.

`density(exp, t)` returns:
- `Array{Float64, 3}` for a single-trajectory run, or
- a `(mean, variance)` named tuple of 3D arrays for ensemble runs
  (TWA — jld2 has `dynamics/ensemble/phase_<N>/density/...`).

`psi(exp, t)` is undefined for ensemble runs (no per-trajectory psi).
`populations_t(exp)` likewise errors with a clear message.

`density_stats_at(exp, t)` returns
`(peak, peak_voxel, fwhm_x, fwhm_z, on_axis, sigma_over_mu)` —
`sigma_over_mu = NaN` for single trajectory; uses the variance at the
peak voxel for ensembles. The free function form
`density_stats(density3d; variance=nothing)` is also exported.

---

## Sweep — `Vector{Experiment}`, no Batch type

A sweep is just a vector of experiments. The collection itself has no
new type; standard `length`, indexing, iteration, `map`, `filter` all
work.

```julia
exps = sweep(base;
    over = :pipeline_2_dynamics_loss => [loss(K3_si=f*1e-41) for f in factors])
run!.(exps)                       # serial run; each cell's CAS outdir
tabulate(exps, [Fz_t, classify, norm_drift])
```

Sweep axis is recoverable post-hoc via `spec_diff`:

```julia
spec_diff(exps[1], exps[2])       # → [(path="pipeline.2.dynamics.loss", a=…, b=…)]
```

### Multi-override form

When one sweep dim isn't enough (e.g. epsilon + duration + phi_omega
all changing together with phi_omega written into two pipeline steps):

```julia
cells = [
    1.0 => Dict(:pipeline_2_dynamics_duration => 5.0,
                :pipeline_2_dynamics_loss     => loss(K3_si=1e-41)),
    2.0 => Dict(:pipeline_2_dynamics_duration => 10.0,
                :pipeline_2_dynamics_loss     => loss(K3_si=3e-41)),
]
exps = sweep(base, cells)
```

The cell label (`Pair.first`) is informational only — CAS handles
naming.

### Legacy scan.yaml reader

```julia
exps = sweep("runs/eu151_klaus_phi_phys/scan.yaml")
```

Reads the legacy `scan.yaml` schema (template + parameter.values +
override_path + extra_overrides + point_dir_pattern) and returns
`Vector{Experiment}` directly. No `_manifest.yaml` is written.

### Tabulate

```julia
tab = tabulate(exps, [Fz_t, classify, norm_drift])
tab.Fz_t          # Vector of Vectors
tab.classify      # Vector{Symbol}
tab.norm_drift    # Vector{Float64}
```

Each column is length-`length(exps)`. Failed cells (e.g. jld2 missing)
put the caught Exception in their slot so the table still assembles.

### Why no `Batch` type

`Batch` was a `Vector{Experiment}` with a `Pair{Symbol,Vector}` axis
attached. The axis is recoverable from `spec_diff` across the cells,
and the manifest is recoverable from the directory listing. Carrying
both as a separate type was redundant; `Vector{Experiment}` is the
collection type.

---

## Audit / compare / check / diff

```julia
res = check(ConservationSpec(), exp)         # CheckResult
cmp = compare(exp_a, exp_b)                  # RunComparison
verdict = audit(exp; spec=ConservationSpec())

# spec_diff is the single primitive — used by sweep-axis discovery,
# twin verification, and compare provenance:
spec_diff(exp_a.spec, exp_b.spec)            # → Vector{(path, a, b)}
spec_diff(exp_a, exp_b)                       # same, on Experiments
```

`spec_diff` walks two specs recursively and returns the dotted paths
whose leaves differ. Missing-on-one-side leaves are marked with the
sentinel `:__SPEC_DIFF_MISSING__`.

---

## Twin

```julia
t = twin(exp)        # Experiment with lhy/loss stripped; CAS-named
spec_diff(exp, t)    # → only `lhy` / `loss` keys should appear
```

`twin(exp)` returns a sibling Experiment whose spec has every `lhy:`
block reset to `{kind: "none"}` and every `loss:` block removed. Its
outdir comes from CAS on the modified spec — no `_TWIN_OFF` suffix,
no naming.

Verifying that a twin differs *only* on the expected keys (the old
`audit_twin_controls` Level-12 check) is a one-liner over `spec_diff`.

For batch-producing twins of every K3-on / LHY-on YAML in `runs/`:

```julia
using SpinorBEC
exps = [twin(Experiment(y)) for y in audit_twin_controls("runs").loss_orphans]
run!.(exps)
```

---

## What this replaces

| Old pattern | Now |
|---|---|
| `run_yaml(path)` + manual skip-if-cached | `run!(exp)` |
| `open_result(jld2) + RunResult.Fz_t` | `Fz_t(exp)` |
| `peak_density_trajectory(jld2)` | `peaks(exp)` |
| `find_run_dir(yaml)` | inside `Experiment(yaml_path)` ctor |
| `classify_collapse(peaks, ratio)` | `classify(exp)` |
| `sweep(outdir, base; over, name)` + manifest | `sweep(base; over)` |
| `regenerate(outdir)` | re-call `sweep(base; over)` (CAS dedupes) |
| `Batch(...)` + `Batch(outdir)` | `sweep(...)` returns `Vector{Experiment}` directly |
| TWA `final_density_stats(jld2; ensemble=true)` | `density_stats_at(exp, t)` |
| `twin_off(exp)` | `twin(exp)` (suffix concept retired — CAS handles naming) |
| `audit(yaml)` / `hand_off(yaml)` | `audit(Experiment(yaml))` |
