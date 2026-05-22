using SpinorBEC
using Test

# make_lhy is a thin (state, ddi, F) dispatcher over the existing
# compute_spinor_lhy_* implementations. These tests pin bit-equality against
# the direct calls and validate the argument-error branches.

@testset "make_lhy factory" begin
    g_dict = Dict(0 => 1.0, 2 => 1.0, 4 => 1.0, 6 => 1.0, 8 => 1.0, 10 => 1.0, 12 => 1.0)

    @testset ":polar contact" begin
        a = make_lhy(:polar; F=6, g_dict=g_dict)
        b = compute_spinor_lhy_polar_contact(; F=6, g_dict=g_dict)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset ":polar dipolar" begin
        a = make_lhy(:polar; ddi=true, F=6, g_dict=g_dict, eps_tilde_dd=0.3)
        b = compute_spinor_lhy_polar_dipolar(; F=6, g_dict=g_dict, eps_tilde_dd=0.3)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset ":fm contact" begin
        a = make_lhy(:fm; F=6, g_dict=g_dict)
        b = compute_spinor_lhy_fm_contact(; F=6, g_dict=g_dict)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset ":fm dipolar" begin
        a = make_lhy(:fm; ddi=true, F=6, g_dict=g_dict, eps_dd=0.3)
        b = compute_spinor_lhy_fm_dipolar(; F=6, g_dict=g_dict, eps_dd=0.3)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset ":icosahedral F=6" begin
        a = make_lhy(:icosahedral; F=6, g_dict=g_dict)
        b = compute_spinor_lhy_icosahedral(; F=6, g_dict=g_dict)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset ":polar_two_channel F=1" begin
        a = make_lhy(:polar_two_channel; F=1, c0=10.0, c1=-0.5)
        b = compute_spinor_lhy_polar_two_channel(; F=1, c0=10.0, c1=-0.5)
        @test a.densities == b.densities
        @test a.potential_values == b.potential_values
    end

    @testset "error branches" begin
        @test_throws ArgumentError make_lhy(:icosahedral; F=3, g_dict=g_dict)
        @test_throws ArgumentError make_lhy(:icosahedral; ddi=true, F=6, g_dict=g_dict)
        @test_throws ArgumentError make_lhy(:unknown_state; F=6, g_dict=g_dict)
    end

    @testset ":polar_two_channel F>2 warns" begin
        # Use @test_logs to confirm the F>2 advisory fires.
        @test_logs (:warn, r"two_channel.*approximate") match_mode=:any begin
            make_lhy(:polar_two_channel; F=6, c0=10.0, c1=-0.5)
        end
    end
end
