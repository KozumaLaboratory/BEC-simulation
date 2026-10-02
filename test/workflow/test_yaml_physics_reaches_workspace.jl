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

# Each block is evaluated through both ground-state methods.
const _BLOCKS = [
    (:ddi, (ddi=(enabled=true, c_dd=1.0),), ws -> ws.ddi !== nothing),
    (:ddi_padded, (ddi=(enabled=true, c_dd=1.0),), ws -> ws.ddi_padded !== nothing),
    (:lhy_scalar_dipolar, (ddi=(enabled=true, c_dd=1.0), lhy=(kind=:scalar,)),
        ws -> ws.interactions.c_lhy != 0.0),
    (:lhy_scalar_contact, (ddi=(enabled=false,), lhy=(kind=:scalar,)),
        ws -> ws.interactions.c_lhy != 0.0),
    (:lhy_tabulated, (lhy=(kind=:polar_contact,),), ws -> ws.lhy isa TabulatedLHY),
]

function _gs_step(; kwargs...)
    GroundStateStep(; atom=:Rb87,
        grid=(n=[6, 6, 6], box=[4.0, 4.0, 4.0]),
        interactions=(N_atoms=1000, omega_ref=100.0),
        potential=(type=:harmonic, omega=[1.0, 1.0, 1.0]),
        initial_state=:polar, dt=0.01, n_steps=2, tol=0.01, kwargs...)
end

@testset "Julia physics blocks reach the Workspace on every path" begin
    for (name, parameters, predicate) in _BLOCKS, method in (:itp, :lbfgs)
        @testset "$name via $method" begin
            config = PipelineConfig([_gs_step(; method, parameters...)])
            # Match file entry preprocessing, including derived lab units and LHY.
            resolved = load_config_from_string(repr(config.raw_data))
            result = run_pipeline(resolved; verbose=false)
            @test predicate(result.workspace)
        end
    end
    @testset "pulse sequence via dynamics" begin
        config = PipelineConfig([
            _gs_step(method=:itp),
            DynamicsStep(duration=0.02, dt=0.005,
                pulse_sequence=[(apply=:B, t=0.0, duration=0.02, p=(from=0.0, to=5.0))]),
        ])
        result = run_pipeline(load_config_from_string(repr(config.raw_data)); verbose=false)
        ws = result.dynamics_workspace
        @test zeeman_at(ws.zeeman, 0.0).p != zeeman_at(ws.zeeman, 0.02).p
    end
end
