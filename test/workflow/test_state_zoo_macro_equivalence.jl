# State-zoo macro equivalence: every `init_psi_<name>(grid, sys)` wrapper
# must produce a bit-identical psi to `init_psi(grid, sys; state=:name)`.
#
# This pins the contract that the 2026-05 macro-generation of trivial
# wrappers (`_TRIVIAL_ZOO_STATES` in `src/workflow/initialization/state_zoo.jl`)
# is a pure rename and not a behavior change.

using Test
using SpinorBEC

@testset "state zoo: macro-generated trivial wrappers" begin
    # 2D grid covers all trivial states including :skyrmion which requires N >= 2.
    grid = make_grid(GridConfig((16, 16), (8.0, 8.0)))
    sys = SpinSystem(1)

    trivial_pairs = [
        (init_psi_polar, :polar),
        (init_psi_m_plus_F, :m_plus_F),
        (init_psi_m_minus_F, :m_minus_F),
        (init_psi_uniform, :uniform),
        (init_psi_antiferromagnetic, :antiferromagnetic),
        (init_psi_cyclic, :cyclic),
        (init_psi_skyrmion, :skyrmion),
    ]

    for (wrapper, state_sym) in trivial_pairs
        @testset ":$state_sym wrapper equivalence" begin
            psi_wrapper = wrapper(grid, sys)
            psi_direct = init_psi(grid, sys; state=state_sym)
            @test size(psi_wrapper) == size(psi_direct)
            # Macro-generated wrappers must hit the same code path as
            # `init_psi`; bit-identical is the contract.
            @test psi_wrapper == psi_direct
        end
    end

    @testset "legacy ferromagnetic aliases" begin
        # init_psi_ferromagnetic / _min preserved as direct method aliases
        @test init_psi_ferromagnetic === init_psi_m_plus_F
        @test init_psi_ferromagnetic_min === init_psi_m_minus_F
    end
end
