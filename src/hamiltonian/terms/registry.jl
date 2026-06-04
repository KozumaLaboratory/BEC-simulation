# --- HamTerm registry: derive an NTuple of terms from Workspace state ---
#
# Phase 3 of the sign-bug-proof architecture
# (`docs/conventions/sign_bug_proof_architecture.md`). Builds an
# NTuple{N, HamTerm} from the existing Workspace fields. The Julia
# compiler then specializes any `for term in registry` loop per element
# — zero abstraction overhead vs hand-written direct calls.
#
# Backwards compatibility: this is ADDITIVE. Existing
# `energy_decomposition` / `split_step!` / `energy_gradient!` remain
# unchanged. The new `total_energy_via_registry` / etc. functions are
# parallel paths whose bit-identity to the legacy is asserted by
# `test/oracles/test_registry_bit_identity.jl`. Once verified, the
# legacy paths can be retired in a later sprint.

"""
    build_h_terms_registry(ws) → NTuple{N, HamTerm}

Derive an NTuple of HamTerm instances from `ws`. The order matches
the existing `energy_decomposition` enumeration so per-term energies
are reported in the same order as before.

Inactive terms (e.g. DDI when `ws.ddi === nothing`) are still included
in the tuple as their respective HamTerm subtype; their
`energy_contribution` and `add_gradient!` methods short-circuit to
zero / no-op. This keeps the NTuple type stable across all
workspaces.
"""
function build_h_terms_registry(ws)
    # Sample current zeeman state. For TimeDependentZeeman this is
    # at t=0; runtime-changed fields must be rebuilt per call.
    z = zeeman_at(ws.zeeman, ws.state.t)
    bx, by = transverse_b(ws.zeeman, ws.state.t)
    Ω = ws.sim_params.rotating_frame_omega

    return (
        Kinetic(),
        Trap(),
        LinearZeemanZ(z.p, z.q),
        TransverseZeeman(bx, by),
        DensityC0(ws.interactions[0]),
        SpinC1(ws.interactions[1]),
        DDI(),
        LHY(),
        TensorInteraction(),
        Raman(),
        LightShift(),
        Coriolis(Ω),
        MagneticGradient(),
        Loss(),
    )
end

"""
    total_energy_via_registry(ws) → Float64

Compute `E_total = Σ energy_contribution(term, psi, ws)` by iterating
the registry. Bit-identical to `energy_decomposition(ws).total` for
any well-formed workspace (asserted by
`test/oracles/test_registry_bit_identity.jl`).

The key property: any new H term added to the registry is
automatically included in the total. Missing-term bugs of the
2026-06-04 GPU-energy class are structurally impossible.
"""
function total_energy_via_registry(ws)
    registry = build_h_terms_registry(ws)
    psi = _to_host(ws.state.psi)
    E = 0.0
    for term in registry
        E += energy_contribution(term, psi, ws)
    end
    return E
end

"""
    add_gradient_via_registry!(grad, ws) → grad

Build δE/δψ* by iterating the registry. Bit-identical to the in-place
sum performed by `energy_gradient!` modulo the `* 2` Wirtinger scaling
that `energy_gradient!` applies at the end.

Use this for CI bit-identity tests (asserting that the registry sum
matches the legacy hand-written sum) and as the future replacement
for `energy_gradient!`'s body.
"""
function add_gradient_via_registry!(grad, ws)
    fill!(grad, zero(eltype(grad)))
    registry = build_h_terms_registry(ws)
    psi = _to_host(ws.state.psi)
    for term in registry
        add_gradient!(grad, term, psi, ws)
    end
    return grad
end

"""
    is_kinetic_term(::Type{T}) -> Bool

Classify a HamTerm as kinetic (the K piece of the Strang `V K V` sandwich)
or potential (the V piece). Default: false (assume potential).
"""
is_kinetic_term(::Type{<:HamTerm}) = false
is_kinetic_term(::Type{Kinetic}) = true

"""
    strang_step_via_registry!(ws, dt)

Apply ONE Strang step `V(dt/2) K(dt) V(dt/2)` by iterating the
HamTerm registry. Each substep dispatches via `apply_step!`. The
imaginary_time flag is read from `ws.sim_params.imaginary_time`.

Phase 3.3 proof-of-concept: structurally identical to the legacy
`split_step!` for workspaces where the V piece is just the diagonal
Zeeman + trap + light_shift terms (no DDI, c1, raman, etc. — those
require the nested Strang sandwich which this minimal version doesn't
reproduce). Bit-identity to legacy verified in
`test/oracles/test_registry_strang_step_equivalence.jl` for the
restricted-config case.

Production use requires:
1. Generalising the V piece to the nested Strang sandwich pattern
   `(diag → SM → singlet_pair → ... → DDI → ... → diag)` per
   `split_step.jl:13-17`. This in turn needs each HamTerm to declare
   its position in that nested sandwich.
2. Adding GPU dispatch for `apply_step!` on each term.
3. Time-dependent Zeeman handling — currently `build_h_terms_registry`
   samples Zeeman at t=0; should re-sample per call.

For now this serves as the architectural skeleton.
"""
function strang_step_via_registry!(ws, dt)
    registry = build_h_terms_registry(ws)
    it = ws.sim_params.imaginary_time

    # V(dt/2): apply all potential-class terms with half step
    for term in registry
        is_kinetic_term(typeof(term)) || apply_step!(term, ws.state.psi, dt / 2, it, ws)
    end
    # K(dt): apply kinetic
    for term in registry
        is_kinetic_term(typeof(term)) && apply_step!(term, ws.state.psi, dt, it, ws)
    end
    # V(dt/2): apply all potential-class terms with half step
    for term in registry
        is_kinetic_term(typeof(term)) || apply_step!(term, ws.state.psi, dt / 2, it, ws)
    end

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1
    return nothing
end

"""
    energy_breakdown_via_registry(ws) → NamedTuple

Per-term energy breakdown via the registry. Returns a NamedTuple with
one field per HamTerm subtype. Order matches `build_h_terms_registry`.
"""
function energy_breakdown_via_registry(ws)
    registry = build_h_terms_registry(ws)
    psi = _to_host(ws.state.psi)
    contributions = map(term -> energy_contribution(term, psi, ws), registry)
    total = sum(contributions)
    return (
        kinetic=contributions[1],
        trap=contributions[2],
        zeeman_z=contributions[3],
        zeeman_transverse=contributions[4],
        density_c0=contributions[5],
        spin_c1=contributions[6],
        ddi=contributions[7],
        lhy=contributions[8],
        tensor=contributions[9],
        raman=contributions[10],
        light_shift=contributions[11],
        coriolis=contributions[12],
        magnetic_gradient=contributions[13],
        loss=contributions[14],
        total=total,
    )
end
