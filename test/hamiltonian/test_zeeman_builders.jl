using Test
using SpinorBEC

@testset "Zeeman builders (static + lab-units)" begin
    @testset "static_zeeman: dimensionless slot order" begin
        # Order must be (p_wf, q_wf, bx_wf, by_wf) — p first = Bz.
        zee = static_zeeman(; Bz=1.0, q=0.2, Bx=0.3, By=0.4)
        @test zee isa TimeDependentZeeman
        @test SpinorBEC.evaluate(zee.p_wf, 0.0) == 1.0     # Bz
        @test SpinorBEC.evaluate(zee.q_wf, 0.0) == 0.2     # q
        @test SpinorBEC.evaluate(zee.bx_wf, 0.0) == 0.3    # Bx
        @test SpinorBEC.evaluate(zee.by_wf, 0.0) == 0.4    # By
    end

    @testset "static_zeeman: defaults are zero" begin
        zee = static_zeeman()
        @test SpinorBEC.evaluate(zee.p_wf, 0.0) == 0.0
        @test SpinorBEC.evaluate(zee.q_wf, 0.0) == 0.0
        @test SpinorBEC.evaluate(zee.bx_wf, 0.0) == 0.0
        @test SpinorBEC.evaluate(zee.by_wf, 0.0) == 0.0
    end

    @testset "static_zeeman_lab: nT conversion via preset.p_per_nT" begin
        preset = eu151_preset()
        zee = static_zeeman_lab(preset; Bx_nT=100.0)
        # In-plane Bx at 100 nT (M1 sweep cell value).
        @test SpinorBEC.evaluate(zee.bx_wf, 0.0) ≈ preset.p_per_nT * 100.0
        @test SpinorBEC.evaluate(zee.p_wf, 0.0) == 0.0    # No Bz.
        @test SpinorBEC.evaluate(zee.by_wf, 0.0) == 0.0   # No By.

        # Bz_nT routes to p_wf, Bx_nT/By_nT to bx/by_wf — verify channel
        # routing matches the (p, q, bx, by) slot order documented in
        # memory mistake_transverse_zeeman_sign_inversion_2026_06_04.md.
        zee2 = static_zeeman_lab(preset; Bz_nT=50.0, By_nT=10.0, q=0.05)
        @test SpinorBEC.evaluate(zee2.p_wf, 0.0) ≈ preset.p_per_nT * 50.0
        @test SpinorBEC.evaluate(zee2.by_wf, 0.0) ≈ preset.p_per_nT * 10.0
        @test SpinorBEC.evaluate(zee2.bx_wf, 0.0) == 0.0
        @test SpinorBEC.evaluate(zee2.q_wf, 0.0) == 0.05   # q passed through dimensionless.
    end
end
