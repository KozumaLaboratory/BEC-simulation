using Test
using SpinorBEC

# `compute_spinor_lhy_table` (full_bdg) and `compute_spatial_lhy` both take a
# `zeeman` and use it in the BdG excitation spectrum. `_build_spinor_lhy` passed
# neither, so both fell back to `ZeemanParams()` and **every table was built at
# zero field**, whatever the run's B was.
#
# Two things that made it invisible:
#
#   * The closed forms genuinely do not take a zeeman (ansatz-based, no BdG), so
#     "LHY does not depend on B" looked like a property of the physics rather
#     than a dropped argument.
#   * Nothing errors. A B-scan just gets the same functional at every field —
#     measured on config_texture_bscan_lhy_full_bdg.yaml, where the instability
#     diagnostic `max Im ω` was bit-identical across 50/60/70/80 µG.
#
# And it made the table's own warning unactionable: it says "pick a
# mean-field-stable (F, c₀, c₁, q) point", but q never arrived.

const _ATOM = SpinorBEC.ATOM_REGISTRY[:Eu151]

function _table(zeeman; kind=:full_bdg, state=:polar)
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    psi = init_psi(grid, SpinSystem(_ATOM.F); state)
    ws = make_workspace(; grid, atom=_ATOM,
        interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)),
        zeeman, sim_params=SimParams(; dt=0.001, n_steps=1),
        psi_init=psi, backend=CPUBackend(), spinor_lhy=kind,
        lhy_opts=LHYTableOpts(; n_max=50.0, n_points=40, n_atoms=1))
    ws.lhy
end

@testset "the BdG-solving LHY modes see the Zeeman field" begin
    @testset "q changes the full_bdg table" begin
        v0 = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(0.0, 0.0)))
        vq = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(0.0, 0.5)))
        @test v0 > 0                       # positive control: a real table
        # The regression: these were equal, because q never reached the builder.
        @test !isapprox(v0, vq; rtol=1e-6)
        # ... and by a physically visible amount, not a rounding wobble.
        @test abs(vq - v0) / v0 > 1e-3
    end

    @testset "p is nearly inert for a polar state, q is not" begin
        # m=0 feels no linear Zeeman at leading order, so this asymmetry is a
        # sanity check on WHICH field component is being threaded — swapping
        # p and q at the call site would fail here rather than pass silently.
        vq = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(0.0, 0.5)))
        vpq = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(1.0, 0.5)))
        @test isapprox(vq, vpq; rtol=1e-4)
    end

    @testset "a transverse field is reported, not silently dropped" begin
        # ZeemanParams carries only (p, q). A transverse field cannot enter the
        # uniform BdG problem, so the builder must SAY so rather than pick a
        # representative value.
        zf = SpinorBEC._to_zeeman_field(ZeemanParams(0.0, 0.1), nothing)
        @test SpinorBEC._lhy_zeeman_params(zf) == ZeemanParams(0.0, 0.1)

        bx = SpinorBEC.ZeemanField((0.3, 0.0, 0.0, 0.1), nothing,
            (nothing, nothing, nothing, nothing))
        @test_logs (:warn, r"UNIFORM AXIAL"i) SpinorBEC._lhy_zeeman_params(bx)
        # It still returns the axial part rather than throwing — the run proceeds
        # with a stated approximation.
        @test SpinorBEC._lhy_zeeman_params(bx) == ZeemanParams(0.0, 0.1)
    end

    @testset "closed forms are unaffected (they take no zeeman by design)" begin
        a = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(0.0, 0.0); kind=:polar_contact))
        b = SpinorBEC._lhy_V(1.0, _table(ZeemanParams(0.0, 0.5); kind=:polar_contact))
        @test a > 0
        @test a == b
    end
end
