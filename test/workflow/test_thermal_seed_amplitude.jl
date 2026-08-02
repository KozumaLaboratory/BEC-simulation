# test/workflow/test_thermal_seed_amplitude.jl
#
# `thermal_noise_amplitude` had NO test anywhere under test/ — the mutation
# harness (2026-07-31, TSUBAME job 8309101) dropped the `/4` and 57 workflow
# test files stayed green.
#
# What can be claimed here is limited, and saying so is part of the test. The
# seed is documented as a HEURISTIC: "dimensional-scaling shorthand without a
# derivation". There is no physics oracle for it — no conserved quantity, no
# limit, no experiment. So the honest claim is the formula itself, plus the
# structure a wrong formula would have to reproduce:
#
#   1. η(1) = 1/2 EXACTLY. At T = T_c the kick is half the peak amplitude.
#      This is the row the dropped `/4` fails; it is a pin, and it is the only
#      absolute number available.
#   2. η ∝ (T/T_c)^{3/2} — a metamorphic relation, and deliberately NOT
#      sufficient on its own: dropping the `/4` preserves every ratio, so a
#      suite carrying only the scaling law would have been green against the
#      mutant too. Both rows are needed and neither is redundant.
#   3. `add_thermal_seed!` actually scales the perturbation with η, and
#      renormalises. Otherwise η is a number the caller never feels.

using Test
using SpinorBEC
using SpinorBEC: thermal_noise_amplitude

@testset "thermal seed amplitude" begin
    @testset "η(T/T_c = 1) = 1/2" begin
        # η = √((T/T_c)³/4); at T = T_c this is √(1/4).
        @test thermal_noise_amplitude(1.0) == 0.5
        @test thermal_noise_amplitude(0.0) == 0.0
    end

    @testset "η ∝ (T/T_c)^{3/2}" begin
        # Insensitive to the prefactor BY CONSTRUCTION — see the header. Here
        # to pin the exponent, which the row above cannot see.
        for r in (0.1, 0.25, 0.5)
            @test thermal_noise_amplitude(2r) ≈ 2^1.5 * thermal_noise_amplitude(r)
        end
        @test thermal_noise_amplitude(0.4) ≈ 0.4^1.5 * thermal_noise_amplitude(1.0)
    end

    @testset "the seed carries η into the wavefunction" begin
        F = 1
        base = zeros(ComplexF64, 8, 3)
        base[:, 2] .= 1.0                       # polar, peak amplitude 1

        # Same seed, two temperatures: the perturbation the caller feels must
        # scale like η, not merely be nonzero.
        pert(t) = begin
            psi = copy(base)
            add_thermal_seed!(psi, F; T_over_Tc=t, seed=7)
            psi
        end
        d1 = pert(0.2) .- base
        d2 = pert(0.4) .- base
        r = sqrt(sum(abs2, d2)) / sqrt(sum(abs2, d1))
        # Renormalisation after the kick perturbs the ratio, so this is a loose
        # band around 2^{3/2} = 2.83 rather than an equality. A seed that
        # ignored η entirely would give 1.
        @test 2.2 < r < 3.5

        # And the norm survives the kick.
        psi = copy(base)
        add_thermal_seed!(psi, F; T_over_Tc=0.3, seed=7)
        @test sqrt(sum(abs2, psi)) ≈ sqrt(sum(abs2, base))
    end
end
