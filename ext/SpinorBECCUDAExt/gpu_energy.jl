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

# Shared core: compute the energy decomposition and, when `grad !== nothing`,
# accumulate the bare gradient Σ_term H_term·ψ into `grad` in the SAME pass.
# The per-term `apply_operator!` (kinetic/DDI FFTs) is the expensive part —
# running it once for both energy and gradient (instead of once each in
# apply_operator_via_registry! + energy_decomposition) is the fusion win.
function _gpu_energy_and_optional_grad(ws::SpinorBEC.Workspace{N}, grad) where {N}
    psi = ws.state.psi
    grid = ws.grid
    dV = SpinorBEC.cell_volume(grid)
    n_comp = ws.spin_matrices.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))
    accumulate = grad !== nothing

    ctx = SpinorBEC.build_gradient_context(psi, ws)
    out = similar(psi)
    accumulate && fill!(grad, zero(eltype(grad)))

    # E_term = factor · Re⟨ψ, H_term·ψ⟩ · dV via the gated device gradient face.
    # When accumulating, `out` (= H_term·ψ) is also added to `grad` — one
    # apply_operator! serves both faces.
    op_energy = function (term, factor)
        fill!(out, zero(eltype(out)))
        SpinorBEC.apply_operator!(out, term, ws, psi, ctx)
        accumulate && (grad .+= out)
        return factor * real(dot(vec(psi), vec(out))) * dV
    end
    # Accumulate a gradient-blind / separately-computed term's gradient face
    # (LHY, Tensor, Raman) into `grad` without touching its energy.
    accum_grad = function (term)
        accumulate && SpinorBEC.apply_operator!(grad, term, ws, psi, ctx)
        return nothing
    end

    (
        kin_t, trap_t, zee_t, c0_t, c1_t, ddi_t, lhy_t, tensor_t, raman_t,
        ls_t, cor_t, mg_t, sz_t, loss_t,
    ) = SpinorBEC.build_h_terms_registry(ws)

    # Inactive linear/mean-field terms are skipped: their apply_operator!
    # contributes exactly 0 to the gradient (gate-first), so skipping the
    # energy AND the grad-accumulation is identical to the registry loop.
    # Kinetic: per-component FFT reused for BOTH energy (0.5·Σk²|ψ̂|²) and gradient
    # (ifft(0.5k²·ψ̂)) via the small ctx.fft_buf (36 MB), no out buffer or
    # dot(ψ,out). (A batched full-field FFT was measured ~9-19% WORSE on H100 —
    # the 436 MB copy + full-field broadcasts beat the per-component locality.)
    E_kin = 0.0
    let fftb = ctx.fft_buf,
        ksq = SpinorBEC._to_device(ws.backend, ws.grid.k_squared),
        invn = 1.0 / prod(n_pts)

        for c in 1:n_comp
            idx = ntuple(_ -> Colon(), Val(N))
            fftb .= view(psi, idx..., c)
            ws.fft_plans.forward * fftb
            E_kin += 0.5 * invn * real(sum(ksq .* abs2.(fftb))) * dV
            if accumulate
                fftb .*= (0.5 .* ksq)
                ws.fft_plans.inverse * fftb
                view(grad, idx..., c) .+= fftb
            end
        end
    end
    # Trap: direct energy ∫V|ψ|²·dV (fused reduction, no materialisation) +
    # gradient accumulated directly. Reads ψ+V but skips the out buffer/fill/dot.
    accum_grad(trap_t)
    V_bc = reshape(ws.potential_values, size(ws.potential_values)..., 1)
    E_trap = real(sum(V_bc .* abs2.(psi))) * dV
    # Zeeman: diagonal (no transverse) has a direct energy Σ_c coef(m_c)·|ψ_c|²;
    # transverse needs the D×D matrix expectation → keep out+dot.
    E_zee = if SpinorBEC._has_transverse(zee_t)
        op_energy(zee_t, 1.0)
    else
        accum_grad(zee_t)
        Fq = ws.spin_matrices.system.F
        coefvec = SpinorBEC._to_device(
            ws.backend,
            reshape(
                Float64[SpinorBEC._diag_coef(zee_t, Fq - (c - 1)) for c in 1:n_comp],
                ntuple(_ -> 1, Val(N))..., n_comp,
            ),
        )
        real(sum(coefvec .* abs2.(psi))) * dV
    end
    # Mean-field terms (c0, c1, DDI): DIRECT energy from the small intermediates
    # (n², |F|², Φ·F) already held in ctx / ddi_bufs — reads ~36-216 MB instead
    # of the full ψ+Hψ field (872 MB) a dot(ψ,out) would, and skips the per-term
    # out buffer + fill. Gradient accumulated directly. Matches the CPU direct
    # energy formulas (bit-close, ~1e-14 reduction reassociation).
    E_c0 = 0.0
    if abs(ws.interactions[0]) > 1e-30
        accum_grad(c0_t)
        E_c0 = 0.5 * ws.interactions[0] * sum(abs2, ctx.n_density) * dV
    end
    E_c1 = 0.0
    if abs(ws.interactions[1]) > 1e-30
        accum_grad(c1_t)   # (re)computes ctx.fx/fy/fz = spin density
        E_c1 = 0.5 * ws.interactions[1] *
               (sum(abs2, ctx.fx) + sum(abs2, ctx.fy) + sum(abs2, ctx.fz)) * dV
    end
    E_ddi = 0.0
    if ws.ddi !== nothing
        b = ws.ddi_bufs
        if accumulate
            accum_grad(ddi_t)   # _grad_ddi! fills b.F*_r + b.Phi_* and accumulates grad
        else
            SpinorBEC._compute_spin_density!(
                b.Fx_r, b.Fy_r, b.Fz_r, psi, ws.spin_matrices, Val(n_comp), N, n_pts
            )
            SpinorBEC.compute_ddi_potential!(ws.ddi, b)
        end
        E_ddi = 0.5 * sum(b.Phi_x .* b.Fx_r .+ b.Phi_y .* b.Fy_r .+ b.Phi_z .* b.Fz_r) * dV
    end
    # LHY: energy via device mapreduce (kind-specific power); gradient via the
    # gated apply_operator! face (no FFT — a density-power broadcast).
    accum_grad(lhy_t)
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
    # Gradient faces for the gradient-blind terms (Tensor gate-first host
    # fallback; Raman/Loss no-op; SpatialZeeman inactive on GPU) — accumulate
    # into grad to match apply_operator_via_registry! exactly.
    accum_grad(tensor_t)
    accum_grad(raman_t)
    accum_grad(sz_t)
    accum_grad(loss_t)

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

# Energy-only entry (energy_decomposition GPU path).
SpinorBEC._energy_decomposition_gpu(ws::SpinorBEC.Workspace) =
    _gpu_energy_and_optional_grad(ws, nothing)

# Fused entry: fill `grad` with the bare gradient Σ_term H_term·ψ AND return the
# total energy, in one per-term apply_operator! pass (LBFGS energy_gradient!).
function SpinorBEC._energy_and_gradient_gpu!(grad::CuArray, ws::SpinorBEC.Workspace)
    return _gpu_energy_and_optional_grad(ws, grad).total
end
