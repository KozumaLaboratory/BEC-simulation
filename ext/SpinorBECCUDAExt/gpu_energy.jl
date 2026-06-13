# GPU-optimized energy computation
#
# Eliminates two major bottlenecks:
# 1. FFT plan recreation on every checkpoint (cache CPU plans)
# 2. Q-tensor re-transfer from GPU on every checkpoint (cache host copy)

# Cache for CPU-side energy computation resources
mutable struct EnergyHostCache
    fft_buf::Array{ComplexF64}
    plans::Any  # FFTPlanPair
    ddi_host::Union{Nothing, SpinorBEC.DDIParams}
    ddi_bufs::Union{Nothing, SpinorBEC.DDIBuffers}
    # Reused buffers for per-call host transfers (avoid ~5 MB/call leak
    # at 24³ × D=13 that accumulated to 23 GB over 1000 LBFGS iterations).
    psi_host::Union{Nothing, Array{ComplexF64}}
    V_trap_host::Union{Nothing, Array{Float64}}
end

const _ENERGY_CACHE = Dict{UInt64, EnergyHostCache}()

function _get_energy_cache(ws::SpinorBEC.Workspace{N}) where {N}
    n_pts = ntuple(d -> size(ws.state.psi, d), Val(N))
    key = hash((objectid(ws), n_pts))
    cache = get(_ENERGY_CACHE, key, nothing)
    cache !== nothing && return cache::EnergyHostCache

    grid = ws.grid
    fft_buf = zeros(ComplexF64, grid.config.n_points)
    plans = SpinorBEC.make_fft_plans(grid.config.n_points; flags=SpinorBEC.FFTW.ESTIMATE)

    ddi_host = nothing
    ddi_bufs = nothing
    if ws.ddi !== nothing && SpinorBEC._is_gpu(ws.ddi_bufs.Fx_r)
        ddi_gpu = ws.ddi
        ddi_host = SpinorBEC.DDIParams(
            ddi_gpu.C_dd,
            Array(ddi_gpu.Q_xx), Array(ddi_gpu.Q_xy), Array(ddi_gpu.Q_xz),
            Array(ddi_gpu.Q_yy), Array(ddi_gpu.Q_yz), Array(ddi_gpu.Q_zz),
        )
        rfft_plans = SpinorBEC.make_rfft_plans(n_pts)
        Fx_r = zeros(Float64, n_pts)
        Fy_r = zeros(Float64, n_pts)
        Fz_r = zeros(Float64, n_pts)
        Fx_rk = rfft_plans.forward * copy(Fx_r)
        ddi_bufs = SpinorBEC.DDIBuffers(
            rfft_plans, Fx_r, Fy_r, Fz_r,
            copy(Fx_rk), similar(Fx_rk), similar(Fx_rk),
            similar(Fx_rk), similar(Fx_rk), similar(Fx_rk),
            similar(Fx_r), similar(Fx_r), similar(Fx_r),
        )
    end

    cache = EnergyHostCache(fft_buf, plans, ddi_host, ddi_bufs, nothing, nothing)
    _ENERGY_CACHE[key] = cache
    cache
end

"""
Cached DDI energy using pre-built host plans and Q-tensor (extension-local, not an override).
"""
function _cached_ddi_energy(
    psi_host,
    sm::SpinorBEC.SpinMatrices{D},
    ecache::EnergyHostCache,
    ndim, n_pts, dV,
) where {D}
    bufs = ecache.ddi_bufs
    SpinorBEC._compute_spin_density!(
        bufs.Fx_r, bufs.Fy_r, bufs.Fz_r,
        psi_host, sm, Val(D), ndim, n_pts,
    )
    SpinorBEC.compute_ddi_potential!(ecache.ddi_host, bufs)

    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        E +=
            bufs.Phi_x[I] * bufs.Fx_r[I] +
            bufs.Phi_y[I] * bufs.Fy_r[I] +
            bufs.Phi_z[I] * bufs.Fz_r[I]
    end
    0.5 * E * dV
end

"""
GPU-optimized energy_decomposition: caches FFT plans and DDI host resources.
"""
function SpinorBEC._energy_decomposition_gpu(ws::SpinorBEC.Workspace{N}) where {N}
    grid = ws.grid
    n_comp = ws.spin_matrices.system.n_components
    dV = SpinorBEC.cell_volume(grid)
    psi_src = ws.state.psi
    n_pts = ntuple(d -> size(psi_src, d), Val(N))

    ecache = _get_energy_cache(ws)
    # Reuse host buffers — avoid 5 MB/call * 1000+ LBFGS calls = GB-scale leak
    if ecache.psi_host === nothing || size(ecache.psi_host) != size(psi_src)
        ecache.psi_host = Array{ComplexF64}(undef, size(psi_src))
    end
    copyto!(ecache.psi_host, psi_src)
    psi = ecache.psi_host
    if ecache.V_trap_host === nothing || size(ecache.V_trap_host) != size(ws.potential_values)
        ecache.V_trap_host = Array{Float64}(undef, size(ws.potential_values))
    end
    copyto!(ecache.V_trap_host, ws.potential_values)
    V_trap = ecache.V_trap_host
    fft_buf = ecache.fft_buf
    plans = ecache.plans

    E_kin = SpinorBEC._kinetic_energy(psi, grid, plans, fft_buf, n_comp, N, n_pts, dV)
    E_trap = SpinorBEC._trap_energy(psi, V_trap, n_comp, N, n_pts, dV)
    zee = SpinorBEC.zeeman_at(ws.zeeman, ws.state.t)
    E_zee_diag = SpinorBEC._zeeman_energy(psi, zee, ws.spin_matrices.system, n_comp, N, n_pts, dV)
    bx_gpu, by_gpu = SpinorBEC.transverse_b(ws.zeeman, ws.state.t)
    E_zee_transverse = SpinorBEC._transverse_zeeman_energy(
        psi, bx_gpu, by_gpu, ws.spin_matrices, N, dV
    )
    E_zee = E_zee_diag + E_zee_transverse

    E_c0 = if abs(ws.interactions[0]) > 1e-30
        SpinorBEC._density_interaction_energy(psi, ws.interactions[0], n_comp, N, n_pts, dV)
    else
        0.0
    end
    E_c1 = if abs(ws.interactions[1]) > 1e-30
        SpinorBEC._spin_interaction_energy(
            psi, ws.spin_matrices, ws.interactions[1], n_comp, N, n_pts, dV
        )
    else
        0.0
    end

    E_ddi = if ws.ddi !== nothing
        if SpinorBEC._is_gpu(ws.ddi_bufs.Fx_r) && ecache.ddi_host !== nothing
            _cached_ddi_energy(psi, ws.spin_matrices, ecache, N, n_pts, dV)
        elseif SpinorBEC._is_gpu(ws.ddi_bufs.Fx_r)
            SpinorBEC._ddi_energy_from_gpu(
                psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, n_comp, N, n_pts, dV;
                ddi_padded=ws.ddi_padded,
            )
        else
            SpinorBEC._ddi_energy(
                psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, n_comp, N, n_pts, dV;
                ddi_padded=ws.ddi_padded,
            )
        end
    else
        0.0
    end

    E_lhy = if ws.lhy !== nothing
        SpinorBEC._lhy_energy(psi, ws.lhy, n_comp, N, n_pts, dV)
    elseif ws.interactions.c_lhy != 0.0
        SpinorBEC._lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, dV)
    else
        0.0
    end

    E_tensor = begin
        e = 0.0
        c2 = SpinorBEC.get_cn(ws.interactions, 2)
        abs(c2) > 1e-30 &&
            (e += SpinorBEC._singlet_pair_energy(psi, ws.spin_matrices.system.F, c2, N, n_pts, dV))
        ws.tensor_cache !== nothing &&
            (e += SpinorBEC._tensor_interaction_energy(psi, ws.tensor_cache, N, n_pts, dV))
        e
    end

    E_raman = if ws.raman !== nothing
        SpinorBEC._raman_energy(psi, ws.spin_matrices, ws.raman, grid, N, n_pts, dV)
    else
        0.0
    end

    E_light_shift = if ws.light_shift !== nothing
        SpinorBEC._light_shift_energy(psi, ws.light_shift, n_comp, N, n_pts, dV)
    else
        0.0
    end

    Ω = ws.sim_params.rotating_frame_omega
    E_coriolis = if SpinorBEC.is_active(Ω, SpinorBEC.ROTATION_TOL) && N >= 2
        -Ω * SpinorBEC.orbital_angular_momentum(psi, grid, plans)
    else
        0.0
    end

    # Magnetic gradient (post-[GAP-2] 2026-06-04): mirror the CPU
    # path's call into `_magnetic_gradient_energy`. The helper operates
    # on the host-side `psi` already prepared above.
    E_mg = SpinorBEC._magnetic_gradient_energy(psi, ws, N, n_pts, dV)

    # Spatial Zeeman (arbitrary B(r,t)): always 0 on a GPU workspace —
    # make_workspace rejects a spatial field + GPU backend, so ws.zeeman is
    # always the uniform arm here. The slot must exist for shape parity with
    # the CPU registry NamedTuple.
    E_sz = 0.0

    E_total =
        E_kin + E_trap + E_zee + E_c0 + E_c1 + E_ddi + E_lhy + E_tensor + E_raman +
        E_light_shift + E_coriolis + E_mg + E_sz
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
        spatial_zeeman=E_sz,
        # Shape parity with the CPU registry path (App. A defect 7):
        # B1 added :loss to energy_decomposition_via_registry_legacy_shape
        # (identically zero — K3 loss is non-Hermitian, no GP energy);
        # the GPU tuple lacked it and the per-term parity gate's shape
        # assertion failed the moment the GPU-gated ci oracles actually
        # ran. Same value semantics as LossTerm.energy_contribution ≡ 0.
        loss=0.0,
        total=E_total,
    )
end
