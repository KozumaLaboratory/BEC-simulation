using Test
using SpinorBEC

# `dynamics/Fx` and `dynamics/Fy` must be measurements, not constants.
#
# The rotating_basis handler pushed literal `0.0` into both arrays at every
# save, and `save_rotating_result.jl` wrote them to the jld2 alongside the real
# `Fz` and `Lz`. So every rotating-field run on record reports **no transverse
# magnetisation** — a plausible-looking measurement of precisely the quantity a
# rotating-field experiment exists to observe, and zero is exactly what a reader
# would half-expect in a field-following frame.
#
# Nothing was missing but the call: `sm` and `ψtilde` were both in scope, and
# `spin_density_vector(psi, sm, ndim)` returns all three components.
#
# This is the session's theme in its purest form — an absence written out as a
# value. A missing key would have been survivable; a fabricated zero is not,
# because it cannot be told from a result.

@testset "transverse spin is measured, not assumed zero" begin
    grid = make_grid(GridConfig{3}((8, 8, 8), (6.0, 6.0, 6.0)))
    sys = SpinSystem(1)
    sm = spin_matrices(1)
    dV = cell_volume(grid)
    tot(f) = sum(f) * dV

    # CALIBRATION. An implementation returning zeros for everything satisfies
    # every "is zero" arm below; one returning the same non-zero for everything
    # satisfies every "is non-zero" arm. Both directions are pinned on states
    # whose answer is known analytically.
    @testset "the observable distinguishes states" begin
        x = init_psi_spin_coherent(grid, sys; theta=pi / 2, phi=0.0)
        fx, fy, fz = spin_density_vector(x, sm, 3)
        @test tot(fx) ≈ 1.0 atol = 1e-8      # fully transverse along x
        @test abs(tot(fy)) < 1e-8
        @test abs(tot(fz)) < 1e-8

        z = init_psi(grid, sys; state=:m_plus_F)
        gx, gy, gz = spin_density_vector(z, sm, 3)
        @test abs(tot(gx)) < 1e-8
        @test abs(tot(gy)) < 1e-8
        @test tot(gz) ≈ 1.0 atol = 1e-8      # fully axial
    end

    # …and along y, so an implementation that only ever populates the x slot is
    # caught. `theta=pi/2, phi=pi/2` is +y.
    @testset "it resolves the transverse DIRECTION, not just its magnitude" begin
        y = init_psi_spin_coherent(grid, sys; theta=pi / 2, phi=pi / 2)
        fx, fy, _ = spin_density_vector(y, sm, 3)
        @test abs(tot(fx)) < 1e-8
        @test tot(fy) ≈ 1.0 atol = 1e-8
    end

    # The handler must CALL it. A literal is the defect being prevented, and it
    # is invisible to any test of the observable itself — the observable was
    # always correct; nobody used it.
    @testset "the rotating handler measures rather than pushing a literal" begin
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
                "pipeline", "run_step_rotating", "dynamics.jl"), String)
        code = [l for l in split(src, '\n') if !startswith(strip(l), "#")]
        @test any(l -> occursin("spin_density_vector(", l), code)
        # no literal push into either array
        for arr in ("Fx_arr", "Fy_arr")
            bad = [l for l in code if occursin(Regex("push!\\($arr,\\s*0\\.0"), l)]
            isempty(bad) || println("\n  $arr still takes a literal:\n    ",
                join(strip.(bad), "\n    "))
            @test isempty(bad)
        end
    end
end
