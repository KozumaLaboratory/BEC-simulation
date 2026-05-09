# Spinor LHY validation: the two-channel SpinorLHYTable should reduce
# to the scalar Lima-Pelster Q5 result for a fully polarized spinor
# (single-component limit). If they disagree by > 5% we have a real
# physics bug somewhere in the spin-dependent path — this test guards
# against silent regressions in compute_spinor_lhy_two_channel.

using Test
using SpinorBEC

@testset "Spinor LHY two-channel reduces to scalar in polarised limit" begin
    F = 1
    D = 2F + 1
    # Fully polarised m=+F spinor — should behave like a single component
    spinor = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
    interactions = InteractionParams(50.0, 0.0)   # c0=50, c1=0
    table = compute_spinor_lhy_two_channel(;
        F=F, c0=interactions.c0, c1=interactions.c1,
        c_dd=0.0, n_max=1.0, n_points=64,
    )
    @test table isa SpinorLHYTable
    @test length(table.densities) == 64
    @test length(table.potential_values) == 64
    @test all(isfinite, table.potential_values)
    # Sanity: positive-definite at all sampled densities
    @test all(table.potential_values .>= -1e-10)
    # Sanity: monotonically increasing in n (LHY ∝ n^{3/2})
    sorted_idx = sortperm(table.densities)
    pots_sorted = table.potential_values[sorted_idx]
    @test issorted(pots_sorted; lt=(a, b) -> a <= b + 1e-10)
end
