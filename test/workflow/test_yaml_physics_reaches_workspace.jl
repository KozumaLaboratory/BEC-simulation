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
using SpinorBEC: TabulatedLHY, NoLHY

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

# Each path: (name, YAML lines that select it).
const _PATHS = [
    (:itp, "      method: itp"),
    (:lbfgs, "      method: lbfgs"),
]

_config(block_yaml::String, path_yaml::String) = """
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
$path_yaml
$block_yaml
"""

@testset "YAML physics blocks reach the Workspace on every path" begin
    for (bname, byaml, pred) in _BLOCKS, (pname, pyaml) in _PATHS
        @testset "$bname via $pname" begin
            cfg = load_config_from_string(_config(byaml, pyaml))
            result = run_config(cfg; verbose=false)
            ws = result.workspace
            @test pred(ws)
        end
    end
end
