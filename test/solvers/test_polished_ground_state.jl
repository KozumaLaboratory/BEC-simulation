using Test
using SpinorBEC

# Smoke test for find_ground_state_polished — the ITP+LBFGS chained
# driver promoted from scripts/lib/polished_sweep.jl. Verifies:
#   (1) the chain runs end-to-end at a tiny grid without throwing
#   (2) LBFGS polish lowers (or matches) the ITP energy
#   (3) n_lbfgs=0 skips LBFGS and reports NaN grad_norm
#
# F=1 Na23 + small grid + no DDI keeps wall-clock under a few seconds
# once JIT is warm.

@testset "find_ground_state_polished (CI-tier smoke)" begin
    grid = make_grid(GridConfig((12, 12, 12), (10.0, 10.0, 10.0)))
    atom = SpinorBEC.Na23
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * 2π * 110.0))
    interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.01))
    potential = HarmonicTrap{3}((1.0, 1.0, 1.0))
    preset = SpinorBEC.Preset(
        atom, 2π * 110.0, 10_000, grid, potential, interactions, 0.0
    )

    @testset "full ITP+LBFGS chain" begin
        zee = static_zeeman(; Bz=0.1, q=0.01)
        r = find_ground_state_polished(
            preset, 0.0, zee;
            initial_state=:polar,
            enable_ddi=false,
            n_itp=200, dt_itp=0.005, tol_itp=1e-6,
            n_lbfgs=50, tol_lbfgs=1e-5, sobolev_alpha=0.0,
        )

        @test r.workspace isa Workspace
        @test isfinite(r.energy)
        @test isfinite(r.E_itp)
        @test isfinite(r.grad_norm)
        # LBFGS polish should not raise energy (variational principle).
        @test r.energy ≤ r.E_itp + 1e-8
        @test r.t_itp > 0.0
        @test r.t_lbfgs > 0.0
    end

    @testset "n_lbfgs=0 skips polish stage" begin
        zee = static_zeeman()
        r = find_ground_state_polished(
            preset, 0.0, zee;
            initial_state=:polar,
            enable_ddi=false,
            n_itp=50, dt_itp=0.005, tol_itp=1e-6,
            n_lbfgs=0,
        )
        @test r.energy == r.E_itp
        @test isnan(r.grad_norm)
        @test r.t_lbfgs == 0.0
    end
end
