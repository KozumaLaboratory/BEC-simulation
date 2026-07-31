# test/workflow/test_b_block_spherical_angles.jl
#
# The spherical `B:` form takes `theta_deg` / `phi_deg` and the builder works in
# radians. Dropping the `deg2rad` left all 59 workflow test files green (mutation
# harness, TSUBAME job 8310033) — because it is invisible to everything that does
# not look at the DIRECTION: |B| is unchanged, the field still moves when the
# knob moves, and it still points along +z at theta = 0. A B-scan produced with
# the defect is a scan; it is just a scan over different fields.
#
# So the claim has to be about the direction at a KNOWN angle, and the angles
# that pin it are the ones where the components are exactly 0 or exactly |B|.
# `test_b_block_normalize.jl` covers the schema's rejection rules and never
# evaluates a field, which is why it could not see this.

using Test
using SpinorBEC
using SpinorBEC: _canonicalize_b_to_dimless_xyz, get_atom

@testset "B-block spherical angles are degrees" begin
    atom = get_atom(:Rb87)
    ω_ref = 2π * 100.0
    dur = 1.0

    # (bx, by, bz) at t = 0 for a static spherical B.
    _b(θ_deg, φ_deg; B=1.0) = begin
        z = Dict{Any, Any}("B_mag" => B, "theta_deg" => θ_deg, "phi_deg" => φ_deg)
        wfs = _canonicalize_b_to_dimless_xyz(z, :spherical, dur, atom, ω_ref)
        map(w -> evaluate(w, 0.0), wfs)
    end

    @testset "θ = 0 is axial, θ = 90 is transverse" begin
        bx, by, bz = _b(0.0, 0.0)
        @test abs(bx) < 1e-12
        @test abs(by) < 1e-12
        @test abs(bz) > 0                       # the whole field is along z

        bx, by, bz = _b(90.0, 0.0)
        @test abs(bz) < 1e-12                   # ...and none of it is, here
        @test abs(bx) > 0
        @test abs(by) < 1e-12
        # Read as radians, θ = 90 gives cos(90 rad) = -0.448: bz would be 45 % of
        # |B|, not zero. That is the row that fails.
    end

    @testset "φ = 90 rotates x into y at fixed θ" begin
        bx0, by0, _ = _b(90.0, 0.0)
        bx1, by1, _ = _b(90.0, 90.0)
        @test abs(by1) ≈ abs(bx0) rtol = 1e-10
        @test abs(bx1) < 1e-10
        @test abs(by0) < 1e-10
    end

    @testset "|b| is independent of the angles" begin
        # True with or without the conversion, so it is NOT the gate — it is the
        # control that says the two rows above test the DIRECTION and not the
        # magnitude, which is exactly what the defect leaves alone.
        n(v) = sqrt(sum(abs2, v))
        ref = n(_b(0.0, 0.0))
        for (θ, φ) in ((30.0, 0.0), (90.0, 45.0), (135.0, 200.0))
            @test n(_b(θ, φ)) ≈ ref rtol = 1e-10
        end
    end
end
