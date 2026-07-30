# `compute_spinor_lhy_table` must honour `n_atoms` on BOTH of its branches.
#
# It has two: a fast path for degenerate Zeeman levels, where ε ∝ n^(5/2) exactly
# and one integral fills the table, and the general path through
# `_tabulate_lhy`. Only the general one divided by `n_atoms`. The fast path
# accepted the kwarg and ignored it, so `full_bdg` was exactly N too large
# whenever the Zeeman levels were degenerate — which is the entire weak-field
# regime the Eu campaign works in.
#
# Measured before the fix, F=1 polar, c₀=1, c₁=0.05, n_atoms 1 vs 50000:
#
#     degenerate  (p=q=0)    ratio 1.0       <- ignored
#     non-degen.  (p=0.5)    ratio 50000.0   <- honoured
#
# Downstream it showed up as E_LHY = 99.8 % of E_tot through `run_yaml` while
# `polar_contact` on the same cell and state gave 1.34 %. The direct-call parity
# oracle stayed green at 97/97 throughout, because it compares the two modes at
# `n_atoms = 1` where the branches agree — which is why this needs its own gate
# rather than a tighter tolerance on that one.

using Test
using SpinorBEC

@testset "full_bdg honours n_atoms on both branches" begin
    F = 1
    spinor = ComplexF64[0, 1, 0]                       # polar
    ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
    N = 50_000
    probe = 6                                          # any interior density point

    tbl(zee, n_atoms) = compute_spinor_lhy_table(;
        spinor, F, interactions=ip, zeeman=zee,
        n_max=2.0, n_points=9, n_atoms)

    @testset "degenerate Zeeman (the fast path)" begin
        zee = ZeemanParams(0.0, 0.0)
        v1 = tbl(zee, 1).potential_values[probe]
        vN = tbl(zee, N).potential_values[probe]
        @test v1 > 0                                   # not vacuously equal at 0
        @test isapprox(v1 / vN, N; rtol=1e-9)
    end

    @testset "non-degenerate Zeeman (through _tabulate_lhy)" begin
        zee = ZeemanParams(0.5, 0.0)
        v1 = tbl(zee, 1).potential_values[probe]
        vN = tbl(zee, N).potential_values[probe]
        @test v1 > 0
        @test isapprox(v1 / vN, N; rtol=1e-9)
    end

    @testset "the two branches agree where they overlap" begin
        # A vanishing but non-degenerate splitting must land on the degenerate
        # answer; otherwise the branch boundary is itself a discontinuity, which
        # is how a per-branch normalisation error hides.
        #
        # The bound is set by the general path's central-difference V, not by
        # physics, so it is resolution-dependent. Measured gap at the midpoint
        # density, n_atoms = 50000:
        #
        #     n_points     9      41      201      801
        #     rel gap   1.4e-2  3.5e-4  1.26e-5  2.5e-6
        #
        # — clean ~1/n_points² convergence. 201 points with rtol 1e-4 leaves
        # ~8× margin over the measured 1.26e-5 rather than sitting on it.
        fine(zee) = compute_spinor_lhy_table(;
            spinor, F, interactions=ip, zeeman=zee,
            n_max=2.0, n_points=201, n_atoms=N).potential_values[100]
        @test isapprox(fine(ZeemanParams(0.0, 0.0)),
            fine(ZeemanParams(1e-12, 0.0)); rtol=1e-4)
    end
end
