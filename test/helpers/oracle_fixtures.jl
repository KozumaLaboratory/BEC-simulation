# Shared fixtures for the term property-oracle suite
# (docs/design/term_oracle_bootstrap.md §7, §10).
#
# The all-terms-active workspace closes the historical "term contributes
# zero in the aggregate fixture ⇒ its bugs are invisible" blind spot:
# canary mutants (§7) are only meaningful for terms that are active in
# the fixture they mutate.

"""
    oracle_full_ws(; rotating_frame_omega=0.2) -> (ws, psi)

3D 6³ Rb87 F=1 CPU workspace with as many terms simultaneously active
as practical: trap + linear/quadratic Zeeman + transverse Zeeman
(time-dependent constants) + c0 + c1 + scalar LHY + secular DDI +
Coriolis. `psi` is a normalized spin-coherent state.

`TimeDependentZeeman` field order is `(p_wf, q_wf, bx_wf, by_wf)` —
verified against `foundation/types/interactions_zeeman.jl:121`. (The
sibling fixture in `test_operator_trinity_four_step_chain.jl`
historically carried inverted comment labels; the values there were
fine, the comments were not.)

TODO(week-1 §7): variants with MagneticGradient, LightShift, Raman,
Loss active — every slot of `H_TERMS_CANONICAL_ORDER` needs an active
fixture before its canary mutants mean anything.
"""
function oracle_full_ws(; rotating_frame_omega=0.2, box=4.0, ddi=true, secular=true)
    grid = make_grid(GridConfig{3}((6, 6, 6), (box, box, box)))
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.3),   # p_wf  — linear Zeeman (Bz)
        ConstantWaveform(0.05),  # q_wf  — quadratic Zeeman
        ConstantWaveform(0.2),   # bx_wf — transverse Zeeman
        ConstantWaveform(0.15),  # by_wf — transverse Zeeman
    )
    sp = SimParams(;
        dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega,
    )
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.5, 1 => 0.1); c_lhy=0.3),
        zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=ddi, c_dd=ddi ? 0.05 : 0.0, secular_ddi=ddi && secular,
    )
    psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
    psi ./= sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    return ws, psi
end

"""
    aux_ws() -> (ws, psi)

Auxiliary fixture: the terms the full fixture leaves inactive —
MagneticGradient + diagonal LightShift + static Raman + c2 singlet —
on a 1D grid (F=1). Together with `oracle_full_ws`, every
non-deferred slot of `H_TERMS_CANONICAL_ORDER` is active in at least
one fixture (§7 requirement: inactive terms have invisible bugs).
"""
function aux_ws()
    grid = make_grid(GridConfig{1}((8,), (6.0,)))
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false, normalize_every=0)
    prof = [exp(-x^2 / 4) for x in grid.x[1]]
    U = ComplexF64[1 0 0; 0 1 0; 0 0 1]
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.5, 1 => 0.1, 2 => 0.2)),
        zeeman=ZeemanParams(0.3, 0.05), potential=HarmonicTrap((1.0,)),
        sim_params=sp,
        raman=RamanCoupling{1}(0.4, 0.1, (0.7,)),
        light_shift=LightShift(prof, [0.2, -0.1, 0.4], U, true),
        magnetic_gradient=MagneticGradient{1}(0.4, 1, 1.0),
    )
    psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
    psi ./= sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    return ws, psi
end

"""
    rand_offmanifold_state(ws; rng)

Unnormalized complex Gaussian field — off-manifold by design (§3):
manifold projection is the optimizer's concern and is tested there,
not in the term properties.
"""
rand_offmanifold_state(ws; rng) = randn(rng, ComplexF64, size(ws.state.psi))

"""
    registry_term(ws, ::Type{T}) -> T

Pull the term instance of type `T` from `build_h_terms_registry(ws)` —
property tests consume registry-built terms (production coefficient
sourcing), never hand-constructed duplicates whose coefficients could
silently diverge from `ws`.
"""
function registry_term(ws, ::Type{T}) where {T}
    for term in SpinorBEC.build_h_terms_registry(ws)
        term isa T && return term
    end
    error("registry_term: no $(T) in the registry")
end
