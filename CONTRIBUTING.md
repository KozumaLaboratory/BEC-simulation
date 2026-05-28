# Contributing to SpinorBEC.jl

## Code style

See `CLAUDE.md` for the load-bearing conventions (DDI sign convention,
Workspace type-stability rules, naming discipline). Lint with the
standard Julia formatter; tests pass at `SPINORBEC_TEST_TIER=fast` before
PR review.

## `scripts/` invariant

`scripts/` holds **operational artifacts** — entry points, build
tooling, and declarative ops specs (systemd units, container builds,
SLURM env bootstrap). Flat, no subdirs. A new file is allowed only
if it falls into one of three categories:

1. **Pure dispatch / arg-parse entry point.** Body contains nothing
   but argument parsing, calling library functions, and `exit(code)`.
   All compute lives in `src/`. The canonical Julia CLI is
   `scripts/cli.jl` (single entry; subcommands include autopilot
   operator ops). Each subcommand handler stays ≤20 LOC and contains
   no compute. No per-subsystem sibling CLIs — they fragment operator
   memory and duplicate flag-parse code. Bash entries that orchestrate
   non-Julia tools (LaTeX, deploy, install) are fine alongside.

2. **Build-time tooling that cannot run from the package.** Currently
   `scripts/build_sysimage.jl` (PackageCompiler invocation).

3. **Declarative ops specs** for tools whose configuration lives in
   their own format. Currently: `scripts/spinor-autopilot.{service,timer}`
   (systemd-user units), `scripts/spinorbec.def` (Singularity image),
   `scripts/tsubame_setup.sh` (cluster env bootstrap sourced by
   operators).

Anything else — config generators, figure builders, summary
tabulators, cluster helpers, post-processing — goes into `src/` as a
library function exported from the SpinorBEC umbrella. Then the entry
point (if any is needed) is a tiny CLI in `scripts/cli.jl`.

### Why

The campaign that took `scripts/` from 117 → 2 (`cli.jl`, plus 1
PackageCompiler entry) revealed three failure modes when logic lived
in `scripts/`:

- **Bitrot**: 24 near-duplicate `*_gen.jl` files, 15 near-duplicate
  `*_summary.jl` files. Each was edited independently; the rotating-basis
  loss bug (FIXED 2026-05-13, memory `gotcha_K3_routing_pre_2026_05_13.md`)
  sat in one variant for weeks because the canonical path was unclear.
- **Inaccessible from REPL**: research code in `scripts/foo.jl` cannot
  be called interactively, profiled, or stress-tested. Forcing it into
  the library makes `include` / `Pkg.test` / `Cthulhu.descend` all work.
- **CI blindness**: only library code is exercised by `Pkg.test()`;
  `scripts/` is dark for the regression suite.

### Review trigger

If a script exceeds 30 LOC or any of its functions does non-trivial
compute, that's a "lift to library" PR. Same applies to inline `julia -e`
heredocs in `.sbatch` / `.sh` files — they are scripts in disguise and
follow the same rule (the heredoc body should be a single library call).

### What's already in `cli.jl`

| Subcommand | Library function |
|---|---|
| `inspect <yaml>` | `inspect_config()` + `print_inspection()` |
| `launch [<batch>] <name>` | `launch_experiment()` |
| `figure --paper P --fig N` | `render_manuscript_figure()` |
| `preflight [<smoke_yaml>]` | `cuda_preflight_check()` |

New CLI commands extend `cli.jl`. New `.jl` files in `scripts/` should
not be created unless they hit category 2 above.

## Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'         # full tier (~5 min)
SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'
```

Tier definitions in `CLAUDE.md`. Add new tests under `test/<subsystem>/`
mirroring the `src/` tree.

## Commits

Use Conventional Commits (see `~/.claude/agents.md` for the shape).
Single-purpose commits — don't bundle unrelated refactors. The
`scripts/` archaeology campaigns committed each phase separately so
the inventory delta is auditable per commit.
