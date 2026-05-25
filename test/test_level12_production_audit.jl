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
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: 0.0}
      ddi: {enabled: false}
      lhy: {kind: none}
      B: {Bz: 0.0, q: 0.0}
      initial_state: polar
      init_sigma: 1.0
      dt: 0.01
      n_steps: 10
      tol: 1.0e-6
"""

function _yaml_with_lhy(kind)
    replace(_BASE_YAML, "lhy: {kind: none}" => "lhy: {kind: $kind, c_lhy: 0.1}")
end

function _yaml_with_loss()
    replace(
        _BASE_YAML,
        "ddi: {enabled: false}" => "ddi: {enabled: false}\n      loss: {gamma_dr: 0.05}",
    )
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
            _write_yaml(joinpath(tmp, "campaign", "ctrl.yaml"), _BASE_YAML)
            _write_yaml(joinpath(tmp, "campaign", "another.yaml"), _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "K3-on without twin → FAIL" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.yaml"),
                _yaml_with_loss())
            r = audit_twin_controls(tmp)
            @test r.pass == false
            @test length(r.loss_orphans) == 1
        end
    end

    @testset "K3-on with sibling control → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.yaml"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign", "k3_off.yaml"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "LHY-on without twin → FAIL" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.yaml"),
                _yaml_with_lhy("scalar"))
            r = audit_twin_controls(tmp)
            @test r.pass == false
            @test length(r.lhy_orphans) == 1
        end
    end

    @testset "LHY-on with sibling control → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.yaml"),
                _yaml_with_lhy("scalar"))
            _write_yaml(joinpath(tmp, "campaign", "lhy_off.yaml"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "Mixed: K3-on + LHY-on + shared control twin → PASS" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign", "k3_on.yaml"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign", "lhy_on.yaml"),
                _yaml_with_lhy("scalar"))
            _write_yaml(joinpath(tmp, "campaign", "everything_off.yaml"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == true
        end
    end

    @testset "Twin must be in same directory (not unrelated tree)" begin
        mktempdir() do tmp
            _write_yaml(joinpath(tmp, "campaign_A", "k3_on.yaml"),
                _yaml_with_loss())
            _write_yaml(joinpath(tmp, "campaign_B", "k3_off.yaml"),
                _BASE_YAML)
            r = audit_twin_controls(tmp)
            @test r.pass == false
        end
    end
end
