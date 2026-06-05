export total_energy, energy_decomposition

"""
    energy_decomposition(ws) → NamedTuple

Decompose total energy into individual contributions.

Returns `(kinetic, trap, zeeman, density, spin, ddi, lhy, tensor, raman, light_shift, total)`.
"""
function energy_decomposition(ws::Workspace{N}) where {N}
    # GPU path: dispatch to extension via _energy_decomposition_impl
    if _is_gpu(ws.state.psi)
        return _energy_decomposition_gpu(ws)
    end
    _energy_decomposition_cpu(ws)
end

function _energy_decomposition_gpu end

function _energy_decomposition_cpu(ws::Workspace{N}) where {N}
    psi = _to_host(ws.state.psi)
    grid = ws.grid
    n_comp = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))

    fft_buf = _is_gpu(ws.state.psi) ? zeros(ComplexF64, grid.config.n_points) : ws.state.fft_buf
    plans = if _is_gpu(ws.state.psi)
        make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    else
        ws.fft_plans
    end
    V_trap = _to_host(ws.potential_values)
    E_kin = _kinetic_energy(psi, grid, plans, fft_buf, n_comp, N, n_pts, dV)
    E_trap = _trap_energy(psi, V_trap, n_comp, N, n_pts, dV)
    zee = zeeman_at(ws.zeeman, ws.state.t)
    E_zee_diag = _zeeman_energy(psi, zee, ws.spin_matrices.system, n_comp, N, n_pts, dV)
    # Transverse Zeeman: -bx·⟨F_x⟩ - by·⟨F_y⟩. Pre-2026-06-04 silently
    # missing ([GAP-1]). Fixed via systematic audit + HamTerm registry.
    bx, by = transverse_b(ws.zeeman, ws.state.t)
    E_zee_transverse = _transverse_zeeman_energy(psi, bx, by, ws.spin_matrices, N, dV)
    E_zee = E_zee_diag + E_zee_transverse

    E_c0 = if is_active(ws.interactions[0])
        _density_interaction_energy(psi, ws.interactions[0], n_comp, N, n_pts, dV)
    else
        0.0
    end
    E_c1 = if is_active(ws.interactions[1])
        _spin_interaction_energy(psi, ws.spin_matrices, ws.interactions[1], n_comp, N, n_pts, dV)
    else
        0.0
    end

    E_ddi = if ws.ddi !== nothing
        if _is_gpu(ws.ddi_bufs.Fx_r)
            _ddi_energy_from_gpu(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, n_comp, N, n_pts,
                dV;
                ddi_padded=ws.ddi_padded)
        else
            _ddi_energy(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, n_comp, N, n_pts, dV;
                ddi_padded=ws.ddi_padded)
        end
    else
        0.0
    end

    E_lhy = if ws.lhy !== nothing
        _lhy_energy(psi, ws.lhy, n_comp, N, n_pts, dV)
    elseif ws.interactions.c_lhy != 0.0
        _lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, dV)
    else
        0.0
    end

    E_tensor = begin
        e = 0.0
        c2 = get_cn(ws.interactions, 2)
        is_active(c2) &&
            (e += _singlet_pair_energy(psi, ws.spin_matrices.system.F, c2, N, n_pts, dV))
        ws.tensor_cache !== nothing &&
            (e += _tensor_interaction_energy(psi, ws.tensor_cache, N, n_pts, dV))
        e
    end

    E_raman = if ws.raman !== nothing
        _raman_energy(psi, ws.spin_matrices, ws.raman, grid, N, n_pts, dV)
    else
        0.0
    end

    E_light_shift = if ws.light_shift !== nothing
        _light_shift_energy(psi, ws.light_shift, n_comp, N, n_pts, dV)
    else
        0.0
    end

    # H_rot = H_lab - Ω L_z. The -Ω ⟨L_z⟩ piece is what makes ITP converge to
    # vortex / FL ground states under finite rotating_frame_omega; without it,
    # `dE` tracks H_lab while the propagator drives toward H_rot's minimum.
    Ω = ws.sim_params.rotating_frame_omega
    E_coriolis = if is_active(Ω, ROTATION_TOL) && N >= 2
        -Ω * orbital_angular_momentum(psi, grid, plans)
    else
        0.0
    end

    # Magnetic gradient (post-[GAP-2] 2026-06-04): included for runs
    # with active `ws.magnetic_gradient`. Pre-fix this was silently
    # dropped — see `_magnetic_gradient_energy` docstring.
    E_mg = _magnetic_gradient_energy(psi, ws, N, n_pts, dV)

    E_total =
        E_kin + E_trap + E_zee + E_c0 + E_c1 + E_ddi + E_lhy + E_tensor + E_raman +
        E_light_shift + E_coriolis + E_mg
    (
        kinetic=E_kin,
        trap=E_trap,
        zeeman=E_zee,
        density=E_c0,
        spin=E_c1,
        ddi=E_ddi,
        lhy=E_lhy,
        tensor=E_tensor,
        raman=E_raman,
        light_shift=E_light_shift,
        coriolis=E_coriolis,
        magnetic_gradient=E_mg,
        total=E_total,
    )
end

function total_energy(ws::Workspace{N}) where {N}
    energy_decomposition(ws).total
end

# Per-term bodies (_trap_energy, _zeeman_energy, _magnetic_gradient_energy,
# _density_interaction_energy, _lhy_energy multi-methods) now live with
# their HamTerm subtypes in src/hamiltonian/terms/. `_energy_decomposition_cpu`
# above calls each by its canonical name — Julia resolves to the terms/
# definition. The trinity dispatch (`energy_contribution(::Term, psi, ws)`)
# provides the same physics via the registry.

