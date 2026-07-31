# test/workflow/test_auto_grid_derivation.jl
#
# `auto_grid: true` derives the box and the point count from the Thomas-Fermi
# radius. Nothing tested either step: the mutation harness sized the box AT the
# TF radius (dropping the safety factor) and changed the TF exponent from 2/5 to
# 2/3, and all 59 workflow test files stayed green (TSUBAME job 8310033).
#
# Both defects share a shape — the derived grid stays PLAUSIBLE. The box is still
# positive and still grows with N; the run completes, the norm is conserved. What
# is lost is the margin between the cloud and the wall, and that is invisible
# unless something looks at it.
#
# Grounding: the exponent is `order` (double N, the ratio must be 2^{2/5}, which
# no other exponent reproduces), the safety factor is `exact` against the closed
# form. Neither row can see the other's defect, which is why both are here.

using Test
using SpinorBEC
using SpinorBEC: _auto_grid_from_physics, _DEFAULT_TF_BOX_SAFETY, _DEFAULT_TF_NYQUIST

@testset "auto_grid derivation" begin
    # A ground-state step as the schema hands it over: isotropic trap, so every
    # axis gets the same radius and the arithmetic is checkable by hand.
    _step(; n_atoms=1.0e5, omega=[1.0, 1.0, 1.0]) = Dict{Any, Any}(
        "atom" => "Rb87",
        "interactions" => Dict{Any, Any}(
            "n_atoms" => n_atoms, "omega_ref" => 2π * 100.0, "omega" => omega),
    )

    _rtf(step) = begin
        atom = get_atom(:Rb87)
        ω_ref = step["interactions"]["omega_ref"]
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * ω_ref))
        N = step["interactions"]["n_atoms"]
        μ = 0.5 * (15.0 * N * atom.a_s / a_ho)^(2 / 5)
        sqrt(2μ)                                    # ω = 1 on each axis
    end

    @testset "the box stands OFF the Thomas-Fermi radius" begin
        step = _step()
        g = _auto_grid_from_physics(step)
        R = _rtf(step)
        # The margin is the whole point: a box at R puts the cloud edge on the
        # wall. Asserted as the ratio, not the value, so retuning the constant
        # does not require editing a number here — but a box AT the radius does.
        for b in g["box"]
            @test b ≈ R * _DEFAULT_TF_BOX_SAFETY rtol = 1e-10
            @test b > R                            # the claim, stated plainly
        end
        @test _DEFAULT_TF_BOX_SAFETY > 1.0
    end

    @testset "μ_TF ∝ N^{2/5}" begin
        # Order, not value: the ratio at fixed trap isolates the exponent, and
        # no other exponent reproduces it. The box inherits μ through
        # R = sqrt(2μ), so the box ratio is 2^{1/5} for a doubling of N.
        b1 = _auto_grid_from_physics(_step(; n_atoms=1.0e5))["box"][1]
        b2 = _auto_grid_from_physics(_step(; n_atoms=2.0e5))["box"][1]
        @test b2 / b1 ≈ 2^(1 / 5) rtol = 1e-8
        # 2/3 would give 2^(1/3) = 1.26 against 2^(1/5) = 1.149 — a 10 % gap,
        # far outside the tolerance above and the reason this row is enough.
        @test !isapprox(b2 / b1, 2^(1 / 3); rtol=1e-2)
    end

    @testset "an anisotropic trap gives R ∝ 1/ω per axis" begin
        g = _auto_grid_from_physics(_step(; omega=[1.0, 1.0, 4.0]))
        @test g["box"][3] ≈ g["box"][1] / 4 rtol = 1e-10
        @test length(g["n"]) == 3
        @test all(n -> n >= _DEFAULT_TF_NYQUIST, g["n"])
    end
end
