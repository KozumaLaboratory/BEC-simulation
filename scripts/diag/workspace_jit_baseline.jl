#!/usr/bin/env julia
# Workspace JIT cost baseline — measures cold + warm `run_yaml` cascade.
# Matches the CLAUDE.md "Cascade cost (measured 2026-04-26)" reference of
# ~4 min for a trivial Rb87 1D 32-pt GS run_yaml first-output. Run
# before/after Workspace type-param refactors.
#
# Usage:
#   julia --project=. --startup=no scripts/diag/workspace_jit_baseline.jl
#
# Two cost surfaces measured:
#   (1) make_workspace direct call — fast (ms) but misses the
#       run_yaml dispatch cascade.
#   (2) run_yaml on a trivial YAML — slow (minutes) but covers the
#       end-to-end inference path that anko's pipelines actually pay.

using Printf

@info "Loading SpinorBEC (one-time)..."
t_load = @elapsed using SpinorBEC
@info "loaded" t_load_seconds=t_load

# ── Part 1: direct make_workspace ─────────────────────────────────────

@inline function _mk_direct(F::Int, ddi::Bool, loss::Bool=false, ndim::Int=3)
    grid = make_grid(GridConfig(ntuple(_ -> 8, ndim), ntuple(_ -> 6.0, ndim)))
    atom = if F == 1
        AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
    elseif F == 3
        SpinorBEC.Cr52
    elseif F == 6
        SpinorBEC.Eu151
    else
        AtomSpecies("scalar", 1e-25, 0, 100.0 * 5.29e-11, 0.0)
    end
    interactions = InteractionParams(10.0, 0.0)
    pot = ndim == 1 ? HarmonicTrap(1.0) : (ndim == 2 ? HarmonicTrap(1.0, 1.0) : HarmonicTrap(1.0, 1.0, 1.0))
    sp = SimParams(; dt=0.001, n_steps=10)
    kwargs = (; grid, atom, interactions, sim_params=sp,
        potential=pot, zeeman=ZeemanParams(),
        enable_ddi=ddi, c_dd=ddi ? 0.1 : NaN)
    if loss
        kwargs = (; kwargs..., loss=LossParams(; gamma_dr=0.01))
    end
    make_workspace(; kwargs...)
end

direct_combos = [
    ("scalar_no_ddi",    () -> _mk_direct(0, false)),
    ("F1_no_ddi",        () -> _mk_direct(1, false)),
    ("F1_no_ddi_loss",   () -> _mk_direct(1, false, true)),
    ("F3_ddi",           () -> _mk_direct(3, true)),
    ("F6_ddi",           () -> _mk_direct(6, true)),
]

println("\n" * "─"^76)
println("Part 1: make_workspace direct call (ms scale)")
println("─"^76)
@printf("%-22s | %10s | %10s | %5s | type sig\n", "combo", "cold (ms)", "warm (ms)", "params")
println("─"^76)

for (label, mk) in direct_combos
    GC.gc()
    GC.gc()
    GC.gc()
    t_cold = @elapsed ws = mk()
    GC.gc()
    GC.gc()
    t_warm = @elapsed ws2 = mk()
    n_params = length(typeof(ws).parameters)
    @printf("%-22s | %10.1f | %10.1f | %5d | hash=%x\n",
        label,
        t_cold * 1000, t_warm * 1000, n_params,
        UInt32(hash(typeof(ws)) & 0xffffffff))
end
println("─"^76)

# ── Part 2: run_yaml cascade (CLAUDE.md "4 min" path) ─────────────────

yaml_doc = """
metadata:
  suite: jit_baseline_probe

defaults:
  kind: spinor
  backend: cpu

pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [32], box: [12.0]}
      potential: {type: harmonic, omega: [1.0]}
      interactions: {N_atoms: 1000, omega_ref: 100.0}
      ddi: {enabled: false}
      lhy: {kind: none}
      B: {p: 0.0, q: 0.0}
      initial_state: polar
      init_sigma: 1.5
      dt: 0.01
      n_steps: 5
      tol: 1.0e-6
"""

tmpdir = mktempdir()
yaml_path = joinpath(tmpdir, "jit_probe.yaml")
write(yaml_path, yaml_doc)

println("\n" * "─"^76)
println("Part 2: run_yaml cascade (seconds-to-minutes scale)")
println("Trivial Rb87 1D 32-pt 5-step GS, matches CLAUDE.md ~4-min reference")
println("─"^76)

@printf("%-22s | %10s | %10s\n", "phase", "elapsed (s)", "")
println("─"^76)

# Run once cold, once warm. Clean run_dir between calls so the cache
# doesn't short-circuit.
function _run_once(label)
    # Reset env so caching of the run_dir doesn't muddy timing.
    GC.gc()
    GC.gc()
    GC.gc()
    isolated_yaml = joinpath(mktempdir(), "jit_probe.yaml")
    write(isolated_yaml, yaml_doc)
    t = @elapsed run_yaml(isolated_yaml; verbose=false)
    @printf("%-22s | %10.1f |\n", label, t)
end

_run_once("cold (first)")
_run_once("warm (second)")
println("─"^76)
