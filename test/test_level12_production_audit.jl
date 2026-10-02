# Level 12 — production audit (twin-control check).
#
# Validation ladder Level 12 contract: every K3-on / LHY-on production
# run must have a sibling control twin (K3-off / LHY-off) so the
# effect of the variable can be isolated.
#
# Tests the `audit_twin_controls()` API in
# src/workflow/validation/twin_audit.jl (subsumed
# scripts/validation/production_audit.jl on 2026-05-26 — see
# commit 23b72f1).

using Test
using SpinorBEC

const _BASE_YAML = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
                "q" => 0.0,
            ),
            "atom" => "Rb87",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [4.0, 4.0, 4.0],
                "n" => [8, 8, 8],
            ),
            "init_sigma" => 1.0,
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 100,
                "c1_ratio" => 0.0,
                "omega_ref" => 1.0,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
)
"""

function _yaml_with_lhy(kind)
    data = SpinorBEC._julia_config_string(_BASE_YAML)
    data["pipeline"][1]["ground_state"]["lhy"] = Dict("kind" => kind, "c_lhy" => 0.1)
    repr(data)
end

function _yaml_with_loss()
    data = SpinorBEC._julia_config_string(_BASE_YAML)
    data["pipeline"][1]["ground_state"]["loss"] = Dict("gamma_dr" => 0.05)
    repr(data)
end

function _write_yaml(path::AbstractString, body::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, body)
    end
end

@testset "Level 12 — production audit (twin control)" begin
    @testset "Empty tree → PASS" begin
        mktempdir() do tmp
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "Control-only tree (lhy=none, no loss) → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "ctrl.experiment.jl"), _BASE_YAML)
            _write_yaml(joinpath(tmp, "campaign", "another.experiment.jl"), _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "K3-on without twin → FAIL" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.experiment.jl"),
                _yaml_with_loss())
            r = audit_twin_controls(tmp)
            @test r.pass == false
            @test length(r.loss_orphans) == 1
        end
    end

    @testset "K3-on with sibling control → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.experiment.jl"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign", "k3_off.experiment.jl"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "LHY-on without twin → FAIL" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.experiment.jl"),
                _yaml_with_lhy("scalar"))
            r = audit_twin_controls(tmp)
            @test r.pass == false
            @test length(r.lhy_orphans) == 1
        end
    end

    @testset "LHY-on with sibling control → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.experiment.jl"),
                _yaml_with_lhy("scalar"))
            _write_yaml(joinpath(tmp, "campaign", "lhy_off.experiment.jl"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "Mixed: K3-on + LHY-on + shared control twin → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.experiment.jl"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.experiment.jl"),
                _yaml_with_lhy("scalar"))
            _write_yaml(joinpath(tmp, "campaign", "everything_off.experiment.jl"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "Twin must be in same directory (not unrelated tree)" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign_A", "k3_on.experiment.jl"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign_B", "k3_off.experiment.jl"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == false
        end
    end
end
