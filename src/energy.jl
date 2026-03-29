"""
    energy_decomposition(ws) → NamedTuple

Decompose total energy into individual contributions.

Returns `(kinetic, trap, zeeman, density, spin, ddi, lhy, tensor, raman, total)`.
"""
function energy_decomposition(ws::Workspace{N}) where {N}
    psi = ws.state.psi
    grid = ws.grid
    n_comp = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)

    E_kin = _kinetic_energy(psi, grid, ws.fft_plans, ws.state.fft_buf, n_comp, N, n_pts, dV)
    E_trap = _trap_energy(psi, ws.potential_values, n_comp, N, n_pts, dV)
    zee = zeeman_at(ws.zeeman, ws.state.t)
    E_zee = _zeeman_energy(psi, zee, ws.spin_matrices.system, n_comp, N, n_pts, dV)

    E_c0 = if ws.tensor_cache === nothing
        _density_interaction_energy(psi, ws.interactions.c0, n_comp, N, n_pts, dV)
    else
        0.0
    end
    E_c1 = if ws.tensor_cache === nothing
        _spin_interaction_energy(psi, ws.spin_matrices, ws.interactions.c1, n_comp, N, n_pts, dV)
    else
        0.0
    end

    E_ddi = if ws.ddi !== nothing
        _ddi_energy(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, n_comp, N, n_pts, dV;
                    ddi_padded=ws.ddi_padded)
    else
        0.0
    end

    E_lhy = ws.interactions.c_lhy != 0.0 ? _lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, dV) : 0.0

    E_tensor = if ws.tensor_cache !== nothing
        _tensor_interaction_energy(psi, ws.tensor_cache, N, n_pts, dV)
    else
        c2 = get_cn(ws.interactions, 2)
        c2 != 0.0 ? _nematic_energy(psi, ws.spin_matrices.system.F, c2, N, n_pts, dV) : 0.0
    end

    E_raman = if ws.raman !== nothing
        _raman_energy(psi, ws.spin_matrices, ws.raman, grid, N, n_pts, dV)
    else
        0.0
    end

    E_total = E_kin + E_trap + E_zee + E_c0 + E_c1 + E_ddi + E_lhy + E_tensor + E_raman
    (kinetic=E_kin, trap=E_trap, zeeman=E_zee,
     density=E_c0, spin=E_c1, ddi=E_ddi, lhy=E_lhy,
     tensor=E_tensor, raman=E_raman, total=E_total)
end

function total_energy(ws::Workspace{N}) where {N}
    energy_decomposition(ws).total
end

function _kinetic_energy(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)
    E = 0.0
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        fft_buf .= view(psi, idx...)
        plans.forward * fft_buf
        E += real(sum(grid.k_squared .* abs2.(fft_buf))) * dV / prod(n_pts)
    end
    0.5 * E
end

function _trap_energy(psi, V_trap, n_comp, ndim, n_pts, dV)
    E = 0.0
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        E += sum(V_trap .* abs2.(view(psi, idx...))) * dV
    end
    E
end

function _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)
    zee = zeeman_energies(zeeman, sys)
    E = 0.0
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        E += zee[c] * sum(abs2, view(psi, idx...)) * dV
    end
    E
end

function _density_interaction_energy(psi, c0, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    0.5 * c0 * sum(n .^ 2) * dV
end

"""
LHY energy in the scalar (fully-polarized) approximation: E_LHY = (2/5) c_lhy ∫ n^{5/2} dV.
This does NOT account for spin-dependent corrections relevant to spinor droplets.
For spinor LHY, the correction depends on Bogoliubov modes of the full spin-F system.
"""
function _lhy_energy(psi, c_lhy, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        E += ni * ni * sqrt(ni)
    end
    (2.0 / 5.0) * c_lhy * E * dV
end

function _spin_interaction_energy(psi, sm, c1, n_comp, ndim, n_pts, dV)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    0.5 * c1 * sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
end

function _nematic_energy(psi, F, c2, ndim, n_pts, dV)
    A = singlet_pair_amplitude(psi, F, ndim)
    0.5 * c2 * sum(abs2, A) * dV
end

function _ddi_energy(psi, sm::SpinMatrices{D}, ddi, ddi_bufs, n_comp, ndim, n_pts, dV;
                     ddi_padded=nothing) where {D}
    if ddi_padded !== nothing
        _compute_and_convolve_ddi_padded!(psi, sm, ddi, ddi_padded, Val(D), ndim, n_pts)
        E = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            E += ddi_padded.Phi_x_pad[I] * ddi_padded.Fx_pad[I] +
                 ddi_padded.Phi_y_pad[I] * ddi_padded.Fy_pad[I] +
                 ddi_padded.Phi_z_pad[I] * ddi_padded.Fz_pad[I]
        end
        return 0.5 * E * dV
    end
    _compute_spin_density!(ddi_bufs.Fx_r, ddi_bufs.Fy_r, ddi_bufs.Fz_r, psi, sm, Val(D), ndim, n_pts)
    compute_ddi_potential!(ddi, ddi_bufs)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E += ddi_bufs.Phi_x[I] * ddi_bufs.Fx_r[I] +
             ddi_bufs.Phi_y[I] * ddi_bufs.Fy_r[I] +
             ddi_bufs.Phi_z[I] * ddi_bufs.Fz_r[I]
    end
    0.5 * E * dV
end

function _raman_energy(psi, sm::SpinMatrices{D}, raman::RamanCoupling{N},
                       grid::Grid{N}, ndim, n_pts, dV) where {D,N}
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        kr = sum(ntuple(d -> raman.k_eff[d] * grid.x[d][I[d]], Val(N)))
        phase = exp(1im * kr)
        H_R = raman.delta * sm.Fz +
              (raman.Omega_R / 2) * (phase * sm.Fp + conj(phase) * sm.Fm)
        spinor = _get_spinor(psi, I, Val(D))
        E += real(dot(spinor, SMatrix{D,D,ComplexF64}(H_R) * spinor)) * dV
    end
    E
end
