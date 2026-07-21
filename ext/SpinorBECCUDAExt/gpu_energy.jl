# Device-resident GPU energy_decomposition (P2).
#
# Replaces the old host fork (copy ψ + V + Q to host, recompute the whole
# decomposition on CPU with FFTW plans) with an on-device evaluation:
#
#   E_term = factor · Re⟨ψ, apply_operator!(ψ)⟩ · dV
#
# where `apply_operator!` is the gated device-safe gradient face (the same
# object LBFGS uses; per-term GPU=CPU parity is asserted by
# test_gpu_cpu_per_term_parity.jl). `factor` is the term's homogeneity
# degree /2: 1 for linear terms (kinetic, trap, Zeeman, Coriolis, light
# shift, magnetic gradient), 1/2 for the density mean-field terms
# (c0, c1, DDI). LHY is a density mapreduce (kind-specific power). The two
# gradient-blind terms — Tensor (scalar-loop singlet + tensor-cache accumulate)
# and Raman (apply_operator! is a declared no-op) — keep the host helpers,
# behind a single ψ→host copy taken only when either is active.
#
# The terms are drawn from `build_h_terms_registry(ws)` so the RF-corrected
# Zeeman/Coriolis match the propagator + gradient exactly.

# Reused host buffer for the Tensor/Raman fallback copy (avoids the
# per-call GB-scale leak the old full-decomposition fork guarded against;
# now taken ONLY for configs with an active gradient-blind term).
const _GPU_ENERGY_PSI_HOST = Dict{UInt64, Array{ComplexF64}}()

function _gpu_energy_psi_host(psi, ws)
    key = hash((objectid(ws), size(psi)))
    buf = get(_GPU_ENERGY_PSI_HOST, key, nothing)
    if buf === nothing || size(buf) != size(psi)
        buf = Array{ComplexF64}(undef, size(psi))
        _GPU_ENERGY_PSI_HOST[key] = buf
    end
    copyto!(buf, psi)
    buf
end

# Device LHY energy: mirror `_lhy_energy` but as a mapreduce over the
# device total density. Scalar/Quasi2D closed forms run on-device; other
# kinds fall back to the host body (rare on the GPU path).
function _gpu_lhy_energy(psi, ws, n_comp, N, n_pts, dV)
    lhy = ws.lhy
    if lhy === nothing
        c = ws.interactions.c_lhy
        c == 0.0 && return 0.0
        n = SpinorBEC.total_density(psi, N)
        return (2.0 / 5.0) * c * sum(x -> x * x * sqrt(x), n) * dV
    elseif lhy isa SpinorBEC.ScalarLHY
        n = SpinorBEC.total_density(psi, N)
        return (2.0 / 5.0) * lhy.c_lhy * sum(x -> x * x * sqrt(x), n) * dV
    elseif lhy isa SpinorBEC.Quasi2DLHY
        n = SpinorBEC.total_density(psi, N)
        a2 = lhy.a_2d_sq
        lc = lhy.log_const
        E = sum(n) do ni
            ni < 1e-30 ? zero(ni) : ni * ni * (log(ni * a2) + lc)
        end
        return 0.5 * lhy.c_lhy_2d * E * dV
    else
        # Tabulated / spinor LHY kinds: host body (single copy).
        psi_h = _gpu_energy_psi_host(psi, ws)
        return SpinorBEC._lhy_energy(psi_h, lhy, n_comp, N, n_pts, dV)
    end
end

function SpinorBEC._energy_decomposition_gpu(ws::SpinorBEC.Workspace{N}) where {N}
    psi = ws.state.psi
    grid = ws.grid
    dV = SpinorBEC.cell_volume(grid)
    n_comp = ws.spin_matrices.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))

    ctx = SpinorBEC.build_gradient_context(psi, ws)
    out = similar(psi)

    # E_term = factor · Re⟨ψ, H_term·ψ⟩ · dV via the gated device gradient face.
    op_energy = function (term, factor)
        fill!(out, zero(eltype(out)))
        SpinorBEC.apply_operator!(out, term, ws, psi, ctx)
        return factor * real(dot(vec(psi), vec(out))) * dV
    end

    (
        kin_t, trap_t, zee_t, c0_t, c1_t, ddi_t, _lhy_t, _tensor_t, _raman_t,
        ls_t, cor_t, mg_t, _sz_t, _loss_t,
    ) = SpinorBEC.build_h_terms_registry(ws)

    E_kin = op_energy(kin_t, 1.0)
    E_trap = op_energy(trap_t, 1.0)
    E_zee = op_energy(zee_t, 1.0)
    E_c0 = abs(ws.interactions[0]) > 1e-30 ? op_energy(c0_t, 0.5) : 0.0
    E_c1 = abs(ws.interactions[1]) > 1e-30 ? op_energy(c1_t, 0.5) : 0.0
    E_ddi = ws.ddi !== nothing ? op_energy(ddi_t, 0.5) : 0.0
    E_lhy = _gpu_lhy_energy(psi, ws, n_comp, N, n_pts, dV)
    E_light_shift = ws.light_shift !== nothing ? op_energy(ls_t, 1.0) : 0.0
    Ω = ws.sim_params.rotating_frame_omega
    E_coriolis =
        (SpinorBEC.is_active(Ω, SpinorBEC.ROTATION_TOL) && N >= 2) ?
        op_energy(cor_t, 1.0) : 0.0
    E_mg = op_energy(mg_t, 1.0)

    # Gradient-blind terms — Tensor (scalar-loop) + Raman (no-op grad):
    # host helpers behind a single ψ→host copy, only when active.
    F = ws.spin_matrices.system.F
    c2 = SpinorBEC.get_cn(ws.interactions, 2)
    need_tensor = SpinorBEC.is_active(c2) || ws.tensor_cache !== nothing
    need_raman = ws.raman !== nothing
    E_tensor = 0.0
    E_raman = 0.0
    if need_tensor || need_raman
        psi_h = _gpu_energy_psi_host(psi, ws)
        if need_tensor
            SpinorBEC.is_active(c2) &&
                (E_tensor += SpinorBEC._singlet_pair_energy(psi_h, F, c2, N, n_pts, dV))
            ws.tensor_cache !== nothing &&
                (E_tensor += SpinorBEC._tensor_interaction_energy(
                    psi_h, ws.tensor_cache, N, n_pts, dV
                ))
        end
        if need_raman
            E_raman = SpinorBEC._raman_energy(
                psi_h, ws.spin_matrices, SpinorBEC.raman_at(ws.raman, ws.state.t),
                grid, N, n_pts, dV,
            )
        end
    end

    # Spatial Zeeman: make_workspace rejects spatial B + GPU, so always 0
    # (slot kept for shape parity with the CPU registry NamedTuple).
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
        loss=0.0,
        total=E_total,
    )
end
