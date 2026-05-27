# --- Reference Hψ: aggregate Hamiltonian-only Hψ from a Workspace ---
#
# Builds the full reference Hψ that should match what production's
# split-step propagator exponentiates. Sums kinetic + trap + Zeeman
# (diag + transverse) + c₀ density + c₁ spin + c₂ singlet + DDI (if
# present). Does NOT include LHY, Raman, tensor c_n (n ≥ 4), loss, or
# Coriolis — those are validated separately or are non-Hamiltonian.

export reference_total_hpsi, reference_total_energy

"""
    reference_total_hpsi(ws::Workspace; t=ws.state.t) → Array

Returns a freshly-allocated array `H ψ` of the same shape as
`ws.state.psi`. Sums every Hamiltonian-only term the production
split-step would exponentiate, using the reference RHS kernels in
this directory.
"""
function reference_total_hpsi(ws::Workspace{N}; t::Real=ws.state.t) where {N}
    psi = ws.state.psi
    out = zeros(eltype(psi), size(psi))
    buf = similar(out)

    reference_kinetic_apply!(out, psi, ws.grid)

    reference_trap_apply!(buf, psi, ws.potential_values)
    @. out += buf

    reference_zeeman_apply!(buf, psi, ws.zeeman, ws.spin_matrices, Float64(t))
    @. out += buf

    ip = interactions_at(ws.interactions, Float64(t))
    c0 = get_cn(ip, 0)
    if abs(c0) > 1e-30
        reference_density_apply!(buf, psi, c0)
        @. out += buf
    end
    c1 = get_cn(ip, 1)
    if abs(c1) > 1e-30
        reference_spin_apply!(buf, psi, ws.spin_matrices, c1)
        @. out += buf
    end
    c2 = get_cn(ip, 2)
    if abs(c2) > 1e-30
        reference_singlet_pair_apply!(buf, psi, ws.spin_matrices.system.F, c2)
        @. out += buf
    end

    if ws.ddi !== nothing
        reference_ddi_apply!(buf, psi, ws.spin_matrices, ws.grid, ws.ddi.C_dd;
            secular=_is_secular_ddi(ws.ddi))
        @. out += buf
    end

    out
end

"""
    reference_total_energy(ws::Workspace; t=ws.state.t) → NamedTuple

Reference energy decomposition: each term computed from the *reference*
implementation. Should match `energy_decomposition(ws)` for the
Hamiltonian-only subset.
"""
function reference_total_energy(ws::Workspace{N}; t::Real=ws.state.t) where {N}
    psi = ws.state.psi
    grid = ws.grid
    sm = ws.spin_matrices
    e_kin = reference_kinetic_energy(psi, grid)
    e_trap = reference_trap_energy(psi, ws.potential_values, grid)
    e_zee = reference_zeeman_diag_energy(psi, ws.zeeman, sm.system, grid, Float64(t))
    ip = interactions_at(ws.interactions, Float64(t))
    c0 = get_cn(ip, 0)
    e_c0 = abs(c0) > 1e-30 ? reference_density_energy(psi, c0, grid) : 0.0
    c1 = get_cn(ip, 1)
    e_c1 = abs(c1) > 1e-30 ? reference_spin_energy(psi, sm, c1, grid) : 0.0
    c2 = get_cn(ip, 2)
    e_c2 = abs(c2) > 1e-30 ?
           reference_singlet_pair_energy(psi, sm.system.F, c2, grid) : 0.0
    e_ddi = if ws.ddi !== nothing
        reference_ddi_energy(psi, sm, grid, ws.ddi.C_dd; secular=_is_secular_ddi(ws.ddi))
    else
        0.0
    end
    e_total = e_kin + e_trap + e_zee + e_c0 + e_c1 + e_c2 + e_ddi
    (
        kinetic=e_kin,
        trap=e_trap,
        zeeman=e_zee,
        density=e_c0,
        spin=e_c1,
        singlet_pair=e_c2,
        ddi=e_ddi,
        total=e_total,
    )
end

# Decide secular vs full from a DDI param struct. Production stores
# Q-tensor arrays; we infer the secular branch by checking Q_xy ≈ 0
# everywhere (secular sets Q_xy = Q_xz = Q_yz = 0 identically). Cheap
# probe — checked once at the first k-bin away from origin.
function _is_secular_ddi(ddi)
    Q_xy = ddi.Q_xy
    # Q_xy is set to zero in the secular branch
    # (qtensor.jl _build_q_tensor!), so a strict max test is a safe
    # discriminator without traversing the whole array.
    @inbounds for i in eachindex(Q_xy)
        abs(Q_xy[i]) > 1e-30 && return false
    end
    true
end
