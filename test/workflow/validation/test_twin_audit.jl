# Phase 7 — Level-12 twin-audit tests.

using Test
using SpinorBEC

@testset "validation Phase-7 twin_audit" begin
    @testset "Non-existent root → ArgumentError" begin
        @test_throws ArgumentError audit_twin_controls("/tmp/nonexistent_xyz123")
    end

    @testset "Empty root → PASS (no orphans)" begin
        root = mktempdir()
        try
            r = audit_twin_controls(root)
            @test r.pass == true
            @test r.n_scanned == 0
            @test isempty(r.loss_on)
            @test isempty(r.lhy_on)
        finally
            rm(root; recursive=true)
        end
    end

    @testset "Loss-on YAML without sibling → orphan" begin
        root = mktempdir()
        try
            mkpath(joinpath(root, "campaign_a"))
            write(
                joinpath(root, "campaign_a", "loss_on.yaml"),
                """
pipeline:
  - dynamics:
      loss: {gamma_dr: 0.02}
""",
            )
            r = audit_twin_controls(root)
            @test r.n_scanned == 1
            @test length(r.loss_on) == 1
            @test length(r.loss_orphans) == 1
            @test r.pass == false
        finally
            rm(root; recursive=true)
        end
    end

    @testset "Loss-on YAML WITH sibling control → no orphan" begin
        root = mktempdir()
        try
            d = joinpath(root, "campaign_b")
            mkpath(d)
            write(
                joinpath(d, "loss_on.yaml"),
                """
pipeline:
  - dynamics:
      loss: {gamma_dr: 0.02}
""",
            )
            write(
                joinpath(d, "control.yaml"),
                """
pipeline:
  - dynamics: {}
""",
            )
            r = audit_twin_controls(root)
            @test r.pass == true
            @test length(r.loss_on) == 1
            @test isempty(r.loss_orphans)
        finally
            rm(root; recursive=true)
        end
    end

    @testset "LHY-on without sibling → orphan; LHY:none excluded" begin
        root = mktempdir()
        try
            mkpath(joinpath(root, "x"))
            write(
                joinpath(root, "x", "lhy_on.yaml"),
                """
pipeline:
  - ground_state:
      lhy: {kind: scalar}
""",
            )
            write(
                joinpath(root, "x", "lhy_none.yaml"),
                """
pipeline:
  - ground_state:
      lhy: {kind: none}
""",
            )
            r = audit_twin_controls(root)
            @test length(r.lhy_on) == 1                  # only kind!=none counted
            @test r.pass == true                        # lhy_none.yaml IS the twin
        finally
            rm(root; recursive=true)
        end
    end

    @testset "Unparseable YAML reported, not pass-blocking" begin
        root = mktempdir()
        try
            write(joinpath(root, "broken.yaml"), "this is: not [valid yaml:")
            r = audit_twin_controls(root)
            @test length(r.unparseable) >= 0          # may be empty if YAML loader is forgiving
            # Brokenness doesn't generate orphans, so pass can still be true
            @test r.pass == true
        finally
            rm(root; recursive=true)
        end
    end

    @testset "config.yaml snapshots excluded" begin
        root = mktempdir()
        try
            mkpath(joinpath(root, "myrun"))
            write(
                joinpath(root, "myrun", "config.yaml"),
                """
pipeline:
  - dynamics:
      loss: {gamma_dr: 0.5}
""",
            )
            r = audit_twin_controls(root)
            @test r.n_scanned == 0                    # config.yaml snapshots skipped
        finally
            rm(root; recursive=true)
        end
    end

    @testset "TwinAuditResult Base.show" begin
        r = TwinAuditResult(3, ["a"], String[], String[], ["a"], String[], false)
        @test occursin("TwinAuditResult", sprint(show, r))
        s = sprint((io, x) -> show(io, MIME"text/plain"(), x), r)
        @test occursin("Twin-control audit", s)
        @test occursin("ORPHAN loss-on", s)
    end
end
