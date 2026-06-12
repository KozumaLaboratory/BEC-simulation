using Test
using SpinorBEC
using SpinorBEC: Units

# Larmor precession + adiabatic-following analysis. The self-field B(r) is the
# DDI convolution (computed via the DDI term, not here); these helpers take B
# as input and answer the adiabaticity question ω_Larmor ≷ ω_rot.

@testset "Larmor + adiabatic following" begin
    atom = SpinorBEC.Eu151
    ℏ = Units.HBAR

    @testset "larmor_frequency is rigorous (g_F μ_B |B|/ℏ, F-independent)" begin
        B = 1.0e-6
        g_F_muB = atom.mu_mag / atom.F           # NOT the full moment
        @test larmor_frequency(B, atom) ≈ g_F_muB * B / ℏ
        # Smaller than the (wrong) full-moment value by exactly F.
        @test larmor_frequency(B, atom) ≈ (atom.mu_mag * B / ℏ) / atom.F
        @test larmor_frequency((0.0, 0.0, B), atom) ≈ larmor_frequency(B, atom)
        @test larmor_frequency((3e-7, 4e-7, 0.0), atom) ≈ larmor_frequency(5e-7, atom)
        @test larmor_frequency([1e-6, 2e-6], atom) ≈
            [larmor_frequency(1e-6, atom), larmor_frequency(2e-6, atom)]
    end

    @testset "field_tilt" begin
        @test field_tilt(0.0, 0.0, 1.0) ≈ 0.0
        @test field_tilt(1.0, 0.0, 0.0) ≈ π / 2
        @test field_tilt(0.0, 0.0, -1.0) ≈ π
        @test field_tilt(1.0, 0.0, 1.0) ≈ π / 4
    end

    @testset "adiabaticity_trajectory" begin
        B_self = (2.0e-8, 0.0, 5.0e-9)  # tesla, has a transverse component
        traj = adiabaticity_trajectory(
            B_self, atom; B_ini=1.0e-6, B_fin=1.0e-8, T_ramp=0.5, n=500
        )
        @test length(traj.times) == 500
        @test traj.times[1] == 0.0
        @test traj.times[end] ≈ 0.5
        @test traj.B_ext[1] ≈ 1.0e-6
        @test traj.B_ext[end] ≈ 1.0e-8

        @test traj.tilt[end] > traj.tilt[1]
        @test traj.tilt[1] < 0.05               # strong bias ⇒ nearly aligned

        Btot = @. sqrt(B_self[1]^2 + B_self[2]^2 + (B_self[3] + traj.B_ext)^2)
        @test traj.omega_larmor ≈ larmor_frequency(Btot, atom)

        @test traj.ratio[2:end] == traj.omega_larmor[2:end] ./ traj.omega_rot[2:end]
        @test minimum(traj.ratio[2:end]) > 0
        @test traj.ratio[2] > traj.ratio[end]   # strong field early ⇒ more adiabatic
    end
end
