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
    E_zee = _zeeman_energy(psi, zee, ws.spin_matrices.system, n_comp, N, n_pts, dV)

    E_c0 = if abs(ws.interactions.c0) > 1e-30
        _density_interaction_energy(psi, ws.interactions.c0, n_comp, N, n_pts, dV)
    else
        0.0
    end
    E_c1 = if abs(ws.interactions.c1) > 1e-30
        _spin_interaction_energy(psi, ws.spin_matrices, ws.interactions.c1, n_comp, N, n_pts, dV)
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
        abs(c2) > 1e-30 &&
            (e += _nematic_energy(psi, ws.spin_matrices.system.F, c2, N, n_pts, dV))
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
    E_coriolis = if abs(Ω) > 1e-15 && N >= 2
        -Ω * orbital_angular_momentum(psi, grid, plans)
    else
        0.0
    end

    E_total =
        E_kin + E_trap + E_zee + E_c0 + E_c1 + E_ddi + E_lhy + E_tensor + E_raman +
        E_light_shift + E_coriolis
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
        total=E_total,
    )
end

function total_energy(ws::Workspace{N}) where {N}
    energy_decomposition(ws).total
end

function _kinetic_energy(psi, grid, plans, fft_buf, n_comp, ndim, n_pts, dV)
    E = 0.0
    inv_npts = 1.0 / prod(n_pts)
    k_sq = grid.k_squared
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        fft_buf .= view(psi, idx...)
        plans.forward * fft_buf
        # Manual reduction loop: avoids materialising an `n_pts`-shaped
        # `k_squared .* abs2.(fft_buf)` temporary every component
        # (saves D × n_pts × 8 B per energy call — ~425 KB per call at
        # 16³ × D=13).
        Ec = 0.0
        for i in eachindex(k_sq, fft_buf)
            Ec += k_sq[i] * abs2(fft_buf[i])
        end
        E += Ec * dV * inv_npts
    end
    0.5 * E
end

function _trap_energy(psi, V_trap, n_comp, ndim, n_pts, dV)
    E = 0.0
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        # Manual reduction loop — same shape as _kinetic_energy. The
        # broadcast `V_trap .* abs2.(psi_c)` previously allocated a
        # full n_pts-shaped temporary per component.
        Ec = 0.0
        for i in eachindex(V_trap, psi_c)
            Ec += V_trap[i] * abs2(psi_c[i])
        end
        E += Ec * dV
    end
    E
end

function _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)
    # Inline `(-z.p m + z.q m²) |ψ_m|²` instead of materialising the
    # `zeeman_energies` Vector{Float64} per call (saves ~104 B / 1 alloc
    # per `energy_decomposition` call at D=13).
    p = zeeman.p
    q = zeeman.q
    E = 0.0
    @inbounds for c in 1:n_comp
        m = sys.m_values[c]
        zee_c = -p * m + q * m * m
        idx = _component_slice(ndim, n_pts, c)
        E += zee_c * sum(abs2, view(psi, idx...)) * dV
    end
    E
end

function _density_interaction_energy(psi, c0, n_comp, ndim, n_pts, dV)
    # Fuse density build + square-sum into one pass — avoids the
    # n_pts-sized temporary that `total_density` materialises (~2.3 KB
    # per call at 16² which is the bulk of `energy_decomposition`'s
    # per-call alloc on small grids).
    s = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        nI = 0.0
        for c in 1:n_comp
            nI += abs2(psi[I, c])
        end
        s += nI * nI
    end
    0.5 * c0 * s * dV
end

"""
LHY energy in the scalar (fully-polarized) approximation: E_LHY = (2/5) c_lhy ∫ n^{5/2} dV.

This uses the scalar BEC Lee-Huang-Yang correction proportional to n^{5/2}.
For spinor condensates (n_comp > 1), the true LHY correction depends on the
Bogoliubov spectrum of the full spin-F system and can differ qualitatively
(e.g., spinor droplets in 39K, spin-dependent depletion). Use with caution
when spin degrees of freedom are dynamically active.

For F ≥ 3 (e.g. Eu151 F=6) the spinor LHY problem is **research-open**:
- The two-channel `TwoChannelLHY` table we ship covers (S=0, S=2) only — sufficient
  for F ≤ 2 (Na23 F=1/2, Rb87 F=1, Cr52 F=3 limit), insufficient for F=6.
- No closed-form Lima-Pelster–style elliptic integral is known for general F.
- Petrov–Astrakharchik droplet stabilisation (PRL 117 100401) was derived for
  scalar condensates; extension to F=6 with full DDI is unsolved.
- Lima-Pelster Q5(ε_dd) for **scalar with DDI** is implemented separately
  (`compute_c_lhy_with_ddi`) and is the right call for fully-polarized states
  in a strong B field — but it does not capture spin-dependent depletion.

For F=6 production runs, one of the following is the appropriate choice:
1. `spinor_lhy: two_channel` for c0/c1 path with weak DDI (qualitative).
2. `spinor_lhy: scalar_with_ddi` (planned) for fully-polarized + strong DDI.
3. Disable LHY entirely (set `gamma_lhy: 0`) and rely on TF — most reliable
   when ε_dd ≲ 1 and the cloud is far from droplet onset.

Until item 2 lands, the scalar warning is the honest signal.
"""
function _lhy_energy(psi, c_lhy, n_comp, ndim, n_pts, dV)
    if n_comp > 1
        @warn """LHY energy uses scalar (fully-polarized) approximation for a \
spinor condensate (n_comp=$n_comp). Spin-dependent LHY corrections are not \
included. To use the two-channel spinor LHY table, add `spinor_lhy: two_channel` \
to the YAML ground_state step or pass `spinor_lhy=:two_channel` to make_workspace. \
For F ≥ 3 the two-channel table is also incomplete — see _lhy_energy docstring.""" maxlog=1
    end
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        E += ni * ni * sqrt(ni)
    end
    (2.0 / 5.0) * c_lhy * E * dV
end

function _lhy_energy(psi, lhy::ScalarLHY, n_comp, ndim, n_pts, dV)
    _lhy_energy(psi, lhy.c_lhy, n_comp, ndim, n_pts, dV)
end

function _lhy_energy(psi, lhy::Quasi2DLHY, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        ni < 1e-30 && continue
        E += ni * ni * (log(ni * lhy.a_2d_sq) + lhy.log_const)
    end
    0.5 * lhy.c_lhy_2d * E * dV
end

function _lhy_energy(::Any, ::NoLHY, _n_comp, _ndim, _n_pts, _dV)
    0.0
end

# Shared energy eval for all table-based modes (TabulatedLHY subtypes).
# All carry the same (densities, potential_values) shape; interpolation is
# identical across modes.
function _lhy_energy(psi, lhy::TabulatedLHY, n_comp, ndim, n_pts, dV)
    n = total_density(psi, ndim)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ni = n[I]
        ni < 1e-30 && continue
        E += _interpolate_1d(lhy.densities, lhy.potential_values, ni) * ni
    end
    E * dV
end

function _spin_interaction_energy(psi, sm, c1, n_comp, ndim, n_pts, dV)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    # Broadcast `fx.^2 .+ fy.^2 .+ fz.^2` materialised an n_pts-shape
    # temporary every call. Inline the reduction.
    s = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        s += fx[i]^2 + fy[i]^2 + fz[i]^2
    end
    0.5 * c1 * s * dV
end

function _nematic_energy(psi, F, c2, ndim, n_pts, dV)
    A = singlet_pair_amplitude(psi, F, ndim)
    0.5 * c2 * sum(abs2, A) * dV
end

function _ddi_energy(
    psi,
    sm::SpinMatrices{D},
    ddi,
    ddi_bufs,
    n_comp,
    ndim,
    n_pts,
    dV;
    ddi_padded=nothing,
) where {D}
    if ddi_padded !== nothing
        _compute_and_convolve_ddi_padded!(psi, sm, ddi, ddi_padded, Val(D), ndim, n_pts)
        E = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            E +=
                ddi_padded.Phi_x_pad[I] * ddi_padded.Fx_pad[I] +
                ddi_padded.Phi_y_pad[I] * ddi_padded.Fy_pad[I] +
                ddi_padded.Phi_z_pad[I] * ddi_padded.Fz_pad[I]
        end
        return 0.5 * E * dV
    end
    _compute_spin_density!(
        ddi_bufs.Fx_r,
        ddi_bufs.Fy_r,
        ddi_bufs.Fz_r,
        psi,
        sm,
        Val(D),
        ndim,
        n_pts,
    )
    compute_ddi_potential!(ddi, ddi_bufs)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E +=
            ddi_bufs.Phi_x[I] * ddi_bufs.Fx_r[I] +
            ddi_bufs.Phi_y[I] * ddi_bufs.Fy_r[I] +
            ddi_bufs.Phi_z[I] * ddi_bufs.Fz_r[I]
    end
    0.5 * E * dV
end

function _ddi_energy_from_gpu(
    psi_host,
    sm::SpinMatrices{D},
    ddi_gpu,
    ddi_bufs_gpu,
    n_comp,
    ndim,
    n_pts,
    dV;
    ddi_padded=nothing,
) where {D}
    Fx_r = zeros(Float64, n_pts)
    Fy_r = zeros(Float64, n_pts)
    Fz_r = zeros(Float64, n_pts)
    _compute_spin_density!(Fx_r, Fy_r, Fz_r, psi_host, sm, Val(D), ndim, n_pts)

    ddi_host = DDIParams(ddi_gpu.C_dd, _to_host(ddi_gpu.Q_xx), _to_host(ddi_gpu.Q_xy),
        _to_host(ddi_gpu.Q_xz), _to_host(ddi_gpu.Q_yy), _to_host(ddi_gpu.Q_yz),
        _to_host(ddi_gpu.Q_zz))
    rfft_plans = make_rfft_plans(n_pts)
    Fx_rk = rfft_plans.forward * Fx_r
    Fy_rk = similar(Fx_rk)
    Fz_rk = similar(Fx_rk)
    Phi_x_rk = similar(Fx_rk)
    Phi_y_rk = similar(Fx_rk)
    Phi_z_rk = similar(Fx_rk)
    Phi_x = similar(Fx_r)
    Phi_y = similar(Fx_r)
    Phi_z = similar(Fx_r)
    bufs_host = DDIBuffers(rfft_plans, Fx_r, Fy_r, Fz_r, Fx_rk, Fy_rk, Fz_rk,
        Phi_x_rk, Phi_y_rk, Phi_z_rk, Phi_x, Phi_y, Phi_z)

    compute_ddi_potential!(ddi_host, bufs_host)

    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E +=
            bufs_host.Phi_x[I] * bufs_host.Fx_r[I] +
            bufs_host.Phi_y[I] * bufs_host.Fy_r[I] +
            bufs_host.Phi_z[I] * bufs_host.Fz_r[I]
    end
    0.5 * E * dV
end

function _raman_energy(
    psi,
    sm::SpinMatrices{D},
    raman::RamanCoupling{N},
    grid::Grid{N},
    ndim,
    n_pts,
    dV,
) where {D, N}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        kr = sum(ntuple(d -> raman.k_eff[d] * grid.x[d][I[d]], Val(N)))
        phase = exp(1im * kr)

        fz_val = 0.0
        for c in 1:D
            fz_val += m_vals[c] * abs2(psi[I, c])
        end

        fp_val = zero(ComplexF64)
        for c in 2:D
            fp_val += fp_coeffs[c] * conj(psi[I, c - 1]) * psi[I, c]
        end

        E += (raman.delta * fz_val + raman.Omega_R * real(phase * fp_val)) * dV
    end
    E
end
