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
end

# ── the PARAMETERISED wrappers ────────────────────────────────────────
# The block above covers only the zero-argument wrappers, so nothing checked that
# a wrapper taking `theta` / `phi` / `winding` / `q_vector` actually FORWARDS them.
# That is exactly where a wrapper can be wrong: `test_state_zoo_wrappers_runnable.jl`
# is named for the MethodError regression and asserts only that these run.
# Measured: dropping `init_phi=phi` from `init_psi_spin_coherent` was caught by no
# test in test/workflow/ (mutation run 2026-07-30), while
# `state=:transverse_x` is precisely this call with phi = 0 vs phi = π/2.
#
# Each row is (wrapper call, equivalent init_psi call). Non-default values on
# purpose: a forwarded default and a dropped argument are indistinguishable at the
# default.
@testset "state zoo: parameterised wrappers forward their arguments" begin
    grid3 = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    grid2 = make_grid(GridConfig((16, 16), (8.0, 8.0)))
    sys = SpinSystem(1)

    cases = [
        ("spin_coherent(θ=0.7, φ=1.1)", grid3,
            (g, s) -> init_psi_spin_coherent(g, s; theta=0.7, phi=1.1),
            (g, s) -> init_psi(g, s; state=:spin_coherent, init_theta=0.7, init_phi=1.1)),
        ("spin_coherent(θ=π/2, φ=0) — the :transverse_x call", grid3,
            (g, s) -> init_psi_spin_coherent(g, s; theta=π / 2, phi=0.0),
            (g, s) -> init_psi(g, s; state=:spin_coherent, init_theta=π / 2, init_phi=0.0)),
        ("radial_spin_vortex(winding=2)", grid2,
            (g, s) -> init_psi_radial_spin_vortex(g, s; winding=2),
            (g, s) -> init_psi(g, s; state=:radial_spin_vortex, init_vortex_charge=2)),
    ]

    for (name, grid, viaw, viad) in cases
        @testset "$name" begin
            a = viaw(grid, sys)
            b = viad(grid, sys)
            @test size(a) == size(b)
            @test a == b            # a rename, not a behaviour change
        end
    end

    # A positive control: the two calls below differ in φ only, so if the wrapper
    # dropped φ they would be equal and the rows above could not fail.
    p0 = init_psi_spin_coherent(grid3, sys; theta=π / 2, phi=0.0)
    p1 = init_psi_spin_coherent(grid3, sys; theta=π / 2, phi=π / 2)
    @test p0 != p1
end
