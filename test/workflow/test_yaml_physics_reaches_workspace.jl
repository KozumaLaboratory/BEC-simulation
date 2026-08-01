# test/workflow/test_yaml_physics_reaches_workspace.jl
#
# One gate for the whole "a term is right everywhere except on ONE path" class.
#
# The HamTerm registry guarantees each term declares its SIGN once. It does not
# guarantee the term REACHES every path: a kwarg dropped from one `make_workspace`
# call site removes the physics entirely, and every sign oracle stays green
# because it calls `make_workspace` directly and never goes through the parser.
# That has now happened six times for `ws.lhy` alone (#125 GPU, #174 dynamics,
# #179 lbfgs, adaptive ITP, pin continuation, the `method=:lbfgs` forward), and
# once as a parser DEFAULT flip that silently ran every production job on the
# bare unpadded DDI kernel.
#
# The claim, stated once: a physics block written in YAML is live on the
# Workspace, on every path that block is legal on. That is a (block × path)
# TABLE, so it is written as a table — a new path adds a row, a new block adds a
# column, and an empty cell is visible. The per-incident alternative is one file
# per cell, which is how test/workflow/ reached 53 files while still missing
# cells.
#
# Deliberately not a physics test: it asserts the term is PRESENT, not that its
# value is right. Value correctness is `test/oracles/`' job. Presence is the
# thing the oracles structurally cannot see.

using Test
using SpinorBEC
using SpinorBEC: TabulatedLHY, NoLHY, zeeman_at

# ── the table ──────────────────────────────────────────────────────
# Each block: (name, YAML lines to splice into ground_state, predicate on ws).
const _BLOCKS = [
    (:ddi,
        "      ddi: {enabled: true, c_dd: 1.0}",
        ws -> ws.ddi !== nothing),
    # Zero-padded DDI is a PARSER default (`DDI_PADDED_DEFAULT`), which is
    # exactly why it needs a row here: nothing below the parser can see it flip.
    (:ddi_padded,
        "      ddi: {enabled: true, c_dd: 1.0}",
        ws -> ws.ddi_padded !== nothing),
    # `scalar` does NOT populate `ws.lhy`: it rides `interactions.c_lhy`, which
    # is exactly why a scalar-only row would have stayed green through all six
    # per-path drops of the tabulated table. Asserted on its own field.
    #
    (:lhy_scalar_dipolar,
        "      ddi: {enabled: true, c_dd: 1.0}\n      lhy: {kind: scalar}",
        ws -> ws.interactions.c_lhy != 0.0),
    # The non-dipolar row is the one that mattered: `_resolve_lhy_block!` guarded
    # the c_lhy auto-derivation on `c_dd > 0` until 2026-07-29, so on a contact
    # gas `lhy: {kind: scalar}` set nothing and warned about nothing — the run
    # reported an LHY mode it was not using. Scalar LHY is *most* meaningful
    # without DDI, so this cell must be green.
    (:lhy_scalar_contact,
        "      ddi: {enabled: false}\n      lhy: {kind: scalar}",
        ws -> ws.interactions.c_lhy != 0.0),
    # The tabulated modes are the ones that were dropped per-path: `scalar`
    # rides `interactions.c_lhy` separately and survives a dropped `spinor_lhy`,
    # so a scalar-only row would have stayed green through all six incidents.
    (:lhy_tabulated,
        "      lhy: {kind: polar_contact}",
        ws -> ws.lhy isa TabulatedLHY),
]

# Each ground-state path: (name, YAML lines that select it).
const _PATHS = [
    (:itp, "      method: itp"),
    (:lbfgs, "      method: lbfgs"),
]

const _GS_HEAD = """
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [6, 6, 6], box: [4.0, 4.0, 4.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 1000, omega_ref: 100.0}
      initial_state: polar
      dt: 0.01
      n_steps: 2
      tol: 1.0e-2
"""

_gs_config(block_yaml::String, path_yaml::String) =
    string(_GS_HEAD, path_yaml, "\n", block_yaml, "\n")

# ── dynamics rows ──────────────────────────────────────────────────
# The overlay a `dynamics:` step applies has its own set of drop sites, and they
# are not reachable from a ground_state fixture. `:dynamics_workspace` in the step
# result is the observation point.
const _DYN_BLOCKS = [
# `_apply_pulse_sequence` read `haskey(compiled, :B)` while the compiler
# writes `:zeeman`, so the TimeDependentZeeman it had just built was discarded
# on every run — the whole `pulse_sequence` B overlay was dead. Nothing else
# observed the dynamics workspace, so nothing saw it.
# Asserted on the FIELD, not on the container type: the overlay builds a
# `TimeDependentZeeman` and the unified B block then wraps it in a
# `ZeemanField`, so a type check pins plumbing that is free to change. What
# cannot change is that a ramp from 0 to 5 must make p(0) ≠ p(t_end).
# (Measured with the defect restored: every waveform slot is `nothing`.)
    (:pulse_sequence_B,
    """      pulse_sequence:
        - {t: 0.0, apply: B, duration: 0.02, p: {from: 0.0, to: 5.0}}
""",
    ws -> zeeman_at(ws.zeeman, 0.0).p != zeeman_at(ws.zeeman, 0.02).p),
]

_dyn_config(block_yaml::String) = string(
    _GS_HEAD, "      method: itp\n",
    """  - dynamics:
      duration: 0.02
      dt: 0.005
""", block_yaml,
)

@testset "YAML physics blocks reach the Workspace on every path" begin
    for (bname, byaml, pred) in _BLOCKS, (pname, pyaml) in _PATHS
        @testset "$bname via $pname" begin
            result = run_config(load_config_from_string(_gs_config(byaml, pyaml));
                verbose=false)
            @test pred(result.workspace)
        end
    end

    @testset "$bname via dynamics" for (bname, byaml, pred) in _DYN_BLOCKS
        result = run_config(load_config_from_string(_dyn_config(byaml)); verbose=false)
        @test pred(result.dynamics_workspace)
    end
end
