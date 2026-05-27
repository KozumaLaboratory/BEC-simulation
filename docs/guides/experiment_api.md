# Experiment / Batch — the unified workflow API

`Experiment` is the unit object of SpinorBEC. A single triple

```
(spec, outdir, lazy observation cache)
```

owns the full simulation lifecycle: define → persist → run → observe.
`Batch` is a `Vector{Experiment}` paired with the sweep axis they vary
over. Together they subsume the scattered `run_yaml + skip-if-cached
loops + RunResult + free observable functions` patterns that used to
live across `scripts/`.

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

exp = Experiment(spec; outdir="runs/eu_demo/K3x1p0")

write_run!(exp)              # writes runs/eu_demo/K3x1p0/config.yaml
run!(exp)                    # runs (idempotent — no-op if result.jld2 exists)

exp.times                    # Vector{Float64}, snapshot time axis
exp.peaks                    # max(total_density) per snapshot
exp.Fz_t                     # ⟨F_z⟩ trajectory
exp.classification           # :delay  / :collapse / :stable_arrest / …
exp.density_at(20.0)         # 3D density at t≈20 (closest snapshot)
exp.density_stats_at(20.0)   # (peak, fwhm_x, fwhm_z, on_axis, σ/μ)
```

The Experiment is cheap to construct (no I/O until you touch an
observable). Repeated property access is O(1) cache hits.

---

## Construction

```julia
Experiment(spec::Dict; outdir::AbstractString)
Experiment(yaml_path::AbstractString)
```

- `Experiment(spec; outdir)` — from an in-memory spec Dict (typically
  built via `config([...])`). `outdir` is where `write_run!` will
  persist the YAML and where `run!` looks for / writes `result.jld2`.
- `Experiment(yaml_path)` — from an existing YAML file. `outdir` is
  resolved by:
  1. if `yaml_path` is `<dir>/config.yaml`, use `<dir>`;
  2. else scan `runs/` for `<base>_<hash>/` siblings newer than the
     YAML (via `find_run_dir`) and pick the most recent;
  3. else fall back to `<yaml_dir>/<base>/`.

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

## Observable surface

Properties are lazy. The first access reads the jld2 (or computes from
RunResult), caches in `exp._cache`, and serves subsequent accesses in
O(μs).

| Category | Properties |
|---|---|
| Terminal scalar | `:norm`, `:energy`, `:Fz`, `:Lz`, `:Jz` |
| Trajectory (Vector{Float64}) | `:norm_t`, `:energy_t`, `:Fz_t`, `:Lz_t`, `:Jz_t`, `:times`, `:peaks` |
| Per-frame populations | `:populations_t` (Vector{Vector{Float64}}, single trajectory only) |
| Drift summaries | `:norm_drift`, `:Fz_drift`, `:energy_drift`, `:Lz_drift`, `:norm_rel_drift`, `:Fz_rel_drift`, `:energy_rel_drift` |
| Classification | `:classification` — Symbol from `classify_collapse` |
| Ensemble meta | `:n_trajectories` (1 for single, N for TWA) |
| Parametrised | `exp.density_at(t)`, `exp.psi_at(t)`, `exp.density_stats_at(t)` |

`exp.density_at(t)` returns:
- `Array{Float64, 3}` for a single-trajectory run, or
- `(mean::Array, variance::Array)` named tuple for an ensemble run
  (TWA — the jld2 has `dynamics/ensemble/phase_<N>/density/...`).

`exp.psi_at(t)` is undefined for ensemble runs (no per-trajectory psi).
`exp.populations_t` likewise errors with a clear message.

`exp.density_stats_at(t)` returns
`(peak, peak_voxel, fwhm_x, fwhm_z, on_axis, sigma_over_mu)` —
`sigma_over_mu = NaN` for single trajectory; uses the variance at the
peak voxel for ensembles. The same primitive is also exposed as a free
function: `density_stats(density3d; variance=nothing)`.

---

## Batch

```julia
batch = Batch(
    base_spec;
    over = :pipeline_2_dynamics_loss => [loss(K3_si=f*1e-41) for f in factors],
    outdir = "runs/eu_k3_sweep",
    name = d -> begin
        v = d === nothing ? 0.0 :
            parse(Float64, split(d["K3_per_m_si"][1], " ")[1]) / 1e-41
        "K3x" * replace(string(round(v; digits=1)), "." => "p")
    end,
)

write_run!(batch)            # N config.yaml files + _manifest.yaml
run!(batch)                  # serial, skip cached cells (parallel arg
                             #   reserved; today only parallel=1 works)
```

- `batch.outdir` is the batch root. Each cell's outdir is
  `<batch.outdir>/<name(value)>/` (directory-per-cell layout, matching
  the directory-per-config form of `run_yaml`).
- `batch[i]`, `length(batch)`, and iteration work as on a Vector.

### Sweep axis: `over`

`over` is a `Pair{Symbol, Vector}` where the symbol is a *dotted-path
key* into the spec Dict. Numeric path tokens (1-based) index into
vectors — `:pipeline_2_dynamics_loss` walks `spec["pipeline"][2]
  ["dynamics"]["loss"]`. The values list is what gets substituted; the
length determines the number of cells.

Multi-axis (cartesian) sweeps and multi-override cell lists from the
old `sweep(outdir, base, cells)` are NOT yet wired on `Batch`; for now
build the cell list yourself and construct one Experiment per cell.

### Rehydrate from disk

```julia
batch = Batch("runs/eu_k3_sweep")   # reads _manifest.yaml
batch[1].Fz_t                       # works without re-running
```

### Tabulate

```julia
tab = tabulate(batch, [:Fz, :classification, :norm_drift])
# NamedTuple with columns: values, Fz, classification, norm_drift
```

Each column is length-`length(batch)`. Failed cells (e.g. result.jld2
missing) put the caught exception in the corresponding row so the table
still assembles.

---

## Audit / compare / check

These bridge Experiment to the existing spec-driven verdict layer.

```julia
res = check(ConservationSpec(), exp)        # CheckResult
cmp = compare(exp_a, exp_b; label_a="A", label_b="B")  # RunComparison
res = check(OperatorRHSSpec(...), cmp)      # CheckResult on the pair

verdict = audit(exp; spec=ConservationSpec()) # run! + check, idempotent
```

`check / compare` are thin adapters over `check_runs / compare_runs` —
they reuse each Experiment's cached RunResult so repeated audits are
fast.

The legacy `audit(yaml::AbstractString)` and `hand_off(yaml)` forms
continue to work; they construct an Experiment internally.

---

## Twin controls

```julia
twin = twin_off(exp)   # outdir = exp.outdir * "_TWIN_OFF"
write_run!(twin)
run!(twin)
```

`twin_off(exp)` returns a sibling Experiment whose spec has every
`lhy:` block reset to `{kind: "none"}` and every `loss:` block removed.
Does not touch disk — the caller does the write/run.

For producing twins of every K3-on / LHY-on YAML under `runs/` (the
old `generate_twin_controls.jl` workflow):

```julia
using YAML, SpinorBEC
for orig in audit_twin_controls("runs").loss_orphans
    raw = YAML.load_file(orig)
    walk_dicts!(raw) do d
        haskey(d, "lhy") && d["lhy"] isa AbstractDict &&
            (d["lhy"] = Dict("kind" => "none"))
        delete!(d, "loss")
    end
    YAML.write_file(replace(orig, ".yaml" => "_TWIN_OFF.yaml"), raw)
end
```

---

## What this replaces

| Old pattern | Now |
|---|---|
| `run_yaml(path)` + manual skip-if-cached | `run!(exp)` |
| `open_result(jld2) + RunResult.Fz_t` | `exp.Fz_t` (delegates via `getproperty`) |
| `peak_density_trajectory(jld2)` | `exp.peaks` |
| `find_run_dir(yaml)` | inside `Experiment(yaml_path)` |
| `classify_collapse(peaks, ratio)` | `exp.classification` |
| `sweep(outdir, base; over, name)` + manifest | `Batch(base; over, outdir, name)` + `write_run!` |
| `regenerate(outdir)` | `Batch(outdir)` then `write_run!` |
| TWA `final_density_stats(jld2; ensemble=true)` | `exp.density_stats_at(t)` |
| `audit(yaml)` / `hand_off(yaml)` | same names, Experiment-typed (yaml form still works) |
