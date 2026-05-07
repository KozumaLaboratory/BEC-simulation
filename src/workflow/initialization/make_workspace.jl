# --- Workspace factory: make_workspace + _rebuild_workspace ---
#
# Assembles a ready-to-run Workspace{...23 type params...} from grid + atom
# + interactions + zeeman + potential + sim_params. Includes the LHY
# dispatch (two_channel / full_bdg / scalar fallback) and DDI buffer
# allocation. The companion `_rebuild_workspace` lets callers swap one
# field (e.g. dt) without re-allocating the whole struct.

function make_workspace(;
    grid::Grid{N, T},
    atom::AtomSpecies,
    interactions::InteractionParams,
    zeeman::Union{ZeemanParams, TimeDependentZeeman}=ZeemanParams(),
    potential::AbstractPotential=NoPotential(),
    sim_params::SimParams,
    psi_init::Union{Nothing, AbstractArray{<:Complex}}=nothing,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    secular_ddi::Bool=false,
    raman::Union{Nothing, RamanCoupling{N}, TimeDependentRaman{N}}=nothing,
    loss::Union{Nothing, LossParams}=nothing,
    fft_flags=FFTW.MEASURE,
    ddi_padding::Bool=false,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
    spinor_lhy::Union{Nothing, Symbol}=nothing,
    absorbing_boundary::Union{Nothing, AbsorbingBoundary}=nothing,
    light_shift::Union{Nothing, LightShift}=nothing,
    time_dep_interactions::Union{Nothing, TimeDependentInteractions}=nothing,
    magnetic_gradient::Union{Nothing, MagneticGradient, TimeDependentMagneticGradient}=nothing,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    U === T || throw(
        ArgumentError(
            "dtype=$U disagrees with grid eltype=$T. Build the grid with `make_grid(cfg; dtype=$U)` first."
        ),
    )
    if quasi_2d
        N == 2 || throw(ArgumentError("quasi_2d requires 2D grid, got $(N)D"))
        l_z > 0 || throw(ArgumentError("quasi_2d requires l_z > 0"))
    end

    effective_interactions =
        quasi_2d ? scale_interactions_quasi_2d(interactions, l_z) : interactions

    if quasi_2d && enable_ddi
        quasi_2d_ddi = true
        l_z_ddi == 0.0 && (l_z_ddi = l_z)
    end

    sys = SpinSystem(atom.F)
    sm = spin_matrices(atom.F)

    psi = if psi_init === nothing
        init_psi(grid, sys; dtype=U)
    else
        eltype(psi_init) === Complex{U} ? copy(psi_init) : Complex{U}.(psi_init)
    end
    psi = _to_device(backend, psi)

    fft_buf = _zeros(backend, Complex{U}, grid.config.n_points...)
    # Scratch buffer with same shape + device + eltype as psi — used by
    # apply_uniform_spin_rotation! and any other whole-ψ broadcast op that
    # would otherwise allocate similar(psi) per call.
    psi_scratch = similar(psi)
    state = SimState{N, typeof(psi), typeof(fft_buf)}(psi, fft_buf, psi_scratch, 0.0, 0)

    plans = make_fft_plans(grid.config.n_points, backend; flags=fft_flags, dtype=U)
    kinetic_phase = _to_device(
        backend,
        prepare_kinetic_phase(
            grid,
            sim_params.dt;
            imaginary_time=sim_params.imaginary_time,
            dtype=U,
        ),
    )
    V = evaluate_potential(potential, grid)

    omega = sim_params.rotating_frame_omega
    if abs(omega) > 1e-15 && N >= 2
        # Rotating-frame Hamiltonian: H_rot = H_lab − Ω L_z. Completing
        # the square in (p − mΩ×r) gives the centrifugal term
        # −(1/2)Ω²r_⊥² **subtracted** from the trap (so the effective
        # transverse confinement is ω_eff² = ω_⊥² − Ω², deconfining at
        # the centrifugal limit Ω → ω_⊥). The previous `V[I] +=` form
        # had the wrong sign and over-confined any rotating-frame ITP /
        # RTP, biasing FL / cyclic / vortex-lattice scans where Ω
        # approaches a non-trivial fraction of ω_⊥. Fixed 2026-04-27
        # after code review caught it. (Klaus 2022 lab-frame magnetostir
        # runs with rotating_frame_omega = 0 are unaffected.)
        omega_sq_half = U(0.5 * omega^2)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            r_perp_sq = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2
            V[I] -= omega_sq_half * r_perp_sq
        end
    end
    V = _to_device(backend, V)

    effective_zeeman = if abs(omega) > 1e-15
        _shift_zeeman_for_rotating_frame(zeeman, omega)
    else
        zeeman
    end

    ddi = if enable_ddi
        if isnan(c_dd) && atom.mu_mag > 0.0
            throw(
                ArgumentError(
                    "enable_ddi=true for dipolar atom $(atom.name) but c_dd not specified. " *
                    "compute_c_dd(atom) returns SI units which are incompatible with dimensionless grids. " *
                    "Pass c_dd in dimensionless units: c_dd = N × μ₀μ² / (ℏω × a_ho³). " *
                    "See compute_c_dd_dimless().",
                ),
            )
        end
        c_dd_val = isnan(c_dd) ? compute_c_dd(atom) : c_dd

        # Spin rotating-frame correctness guard: the rotating-basis frame is
        # built around z, so off-diagonal DDI components rotate at ω_R and
        # average to zero only in the secular limit. With a non-zero
        # spin_rotating_frame_omega and full (non-secular) DDI, the chosen
        # propagator silently violates rotating-frame consistency.
        if abs(sim_params.spin_rotating_frame_omega) > 1e-15 && !secular_ddi
            throw(
                ArgumentError(
                    "spin_rotating_frame_omega = $(sim_params.spin_rotating_frame_omega) ≠ 0 " *
                    "with non-secular DDI: the rotating frame relies on Larmor-averaging " *
                    "off-diagonal DDI components. Pass `secular_ddi=true` to make_workspace, " *
                    "or set spin_rotating_frame_omega=0 to use the lab-frame full DDI.",
                ),
            )
        end

        # Larmor regime advisory: when ω_L (= p_zeeman, dimensionless) ≫
        # c_dd × n_peak, the Larmor cycle averages off-diagonal DDI to zero,
        # and the secular kernel is the appropriate choice. Most Eu151
        # experiments live deep in this regime (ω_L ~ kHz, c_dd × n ~ Hz).
        # Only @info, not error: the user may intentionally want the full
        # kernel to study transverse Larmor-coherent dynamics.
        p_now = linear_p(zeeman)   # uniform accessor handles both forms
        if !secular_ddi && abs(p_now) > 1e-15 && c_dd_val > 1e-30
            n_peak_est =
                sum(abs2, _to_host(psi)) / cell_volume(grid) /
                max(1, prod(grid.config.n_points))  # rough mean → upper bound on n_peak
            larmor_ratio = abs(p_now) / max(c_dd_val * n_peak_est, 1e-30)
            if larmor_ratio > 100.0
                @info "DDI Larmor regime: ω_L / (c_dd · ⟨n⟩) ≈ $(round(larmor_ratio; sigdigits=3)). " *
                    "Consider `secular_ddi=true` (faster + more physical for ω_L ≫ c_dd·n)."
            end
        end

        make_ddi_params(
            grid,
            atom;
            c_dd=c_dd_val,
            secular=secular_ddi,
            quasi_2d=quasi_2d_ddi,
            l_z=l_z_ddi,
            dtype=U,
        )
    else
        nothing
    end

    ddi = if ddi !== nothing
        _ddi_params_to_device(ddi, backend)
    else
        nothing
    end

    ddi_bufs = if ddi !== nothing
        make_ddi_buffers(grid.config.n_points, backend; flags=fft_flags, dtype=U)
    else
        nothing
    end

    density_buf = _zeros(backend, U, grid.config.n_points...)

    ddi_pad = if ddi_padding && ddi !== nothing
        c_dd_val = isnan(c_dd) ? compute_c_dd(atom) : ddi.C_dd
        make_ddi_padded(
            grid,
            atom;
            c_dd=c_dd_val,
            fft_flags,
            secular=secular_ddi,
            quasi_2d=quasi_2d_ddi,
            l_z=l_z_ddi,
            backend,
            dtype=U,
        )
    else
        nothing
    end

    batched_kinetic = _make_batched_kinetic_cache(psi, kinetic_phase, N, backend; flags=fft_flags)

    F = atom.F
    # Tensor interaction path activation:
    # c_extra[idx] = c_{idx+1} stores higher-rank tensor couplings (c₂, c₃, ...).
    # Only even-rank k ∈ {4, 6, ..., 2F} triggers the full tensor_cache, because the
    # 6j transform (_c_extra_to_delta_gS) maps even-rank c_k to channel g_S.
    #
    # Lower-rank terms are handled by dedicated steps:
    #   k=0 (c₀): diagonal step    k=1 (c₁): spin_mixing step
    #   k=2 (c₂): nematic step     k=3: skipped (odd rank; see below)
    #
    # Note on Kawaguchi-Ueda convention: their c₃ Σ_M|A₂M|² (F=3) is a coupling
    # to the S=2 pair channel, NOT a rank-3 tensor operator. To include such terms,
    # map them to g_S channel couplings directly via _make_tensor_cache_from_channels,
    # bypassing c_extra entirely.
    has_higher_c_extra = any(
        i ->
            iseven(i + 1) &&
            (i + 1) >= 4 &&
            (i + 1) <= 2F &&
            abs(effective_interactions.c_extra[i]) > 1e-30,
        eachindex(effective_interactions.c_extra),
    )

    tensor_cache, ws_interactions = if has_higher_c_extra
        g_delta = _c_extra_to_delta_gS(F, effective_interactions.c_extra)
        tc = _make_tensor_cache_from_channels(F, g_delta)
        tc,
        InteractionParams(
            effective_interactions.c0,
            effective_interactions.c1,
            effective_interactions.c_lhy,
            Float64[],
        )
    else
        tc = make_tensor_interaction_cache(F, effective_interactions)
        if tc !== nothing &&
            (abs(effective_interactions.c0) > 1e-30 || abs(effective_interactions.c1) > 1e-30)
            throw(
                ArgumentError(
                    "tensor_cache active with non-zero c0=$(effective_interactions.c0), c1=$(effective_interactions.c1). " *
                    "When tensor_cache handles all channels, set c0=c1=0 in InteractionParams " *
                    "to avoid double-counting (diagonal step still uses c0, tensor step includes c0+c1).",
                ),
            )
        end
        tc, effective_interactions
    end

    coriolis_cache = if sim_params.rotating_frame_omega != 0.0 && N >= 2
        _make_coriolis_cache(psi, backend; flags=fft_flags)
    else
        nothing
    end

    lhy = if spinor_lhy === :two_channel
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        compute_spinor_lhy_two_channel(;
            F=atom.F, c0=ws_interactions.c0, c1=ws_interactions.c1,
            c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
            n_max=n_max_est,
        )
    elseif spinor_lhy === :full_bdg
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        spinor_init = psi_init !== nothing ? _extract_spinor(psi_init) : _default_spinor(atom.F)
        compute_spinor_lhy_table(;
            spinor=spinor_init, F=atom.F, interactions=ws_interactions,
            c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
            n_max=n_max_est,
        )
    elseif spinor_lhy === :polar_contact
        # F-generic polar contact LHY (paper #1, contact-only). ~1000× faster
        # than :full_bdg. Restricted to polar spinors (ζ_α = δ_{α,0}); for
        # post-quench / mixed states fall back to :full_bdg.
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        g_dict = _c0c1_to_gS(atom.F, ws_interactions.c0, ws_interactions.c1)
        if !isempty(ws_interactions.c_extra)
            for (S, dg) in _c_extra_to_delta_gS(atom.F, ws_interactions.c_extra)
                g_dict[S] = get(g_dict, S, 0.0) + dg
            end
        end
        compute_spinor_lhy_polar_contact(; F=atom.F, g_dict=g_dict, n_max=n_max_est)
    elseif spinor_lhy === :fm_dipolar
        # Stage C scalar reduction: FM single-mode contact LHY × Lima-Pelster Q_5(ε_dd).
        # `ε_dd` derived from the standard scalar definition c_dd / g_{2F};
        # for finer control over the convention call
        # `compute_spinor_lhy_fm_dipolar(; eps_dd, ...)` directly.
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        g_dict = _c0c1_to_gS(atom.F, ws_interactions.c0, ws_interactions.c1)
        if !isempty(ws_interactions.c_extra)
            for (S, dg) in _c_extra_to_delta_gS(atom.F, ws_interactions.c_extra)
                g_dict[S] = get(g_dict, S, 0.0) + dg
            end
        end
        c_dd_eff = enable_ddi && !isnan(c_dd) ? c_dd : 0.0
        g_2F = get(g_dict, 2 * atom.F, 0.0)
        eps_dd = abs(g_2F) > 1e-12 ? abs(c_dd_eff) / abs(g_2F) : 0.0
        compute_spinor_lhy_fm_dipolar(; F=atom.F, g_dict=g_dict,
            eps_dd=eps_dd, n_max=n_max_est)
    elseif spinor_lhy === :fm_contact
        # FM-phase contact LHY (paper #2 contact-only piece). Single-mode
        # collapse at m=+F: ε = (8/15π²)(g_{2F}n)^(5/2). For uniform g_S
        # this matches scalar Lima-Pelster; for realistic per-S a_S it
        # differs. DDI extension is not yet derived.
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        g_dict = _c0c1_to_gS(atom.F, ws_interactions.c0, ws_interactions.c1)
        if !isempty(ws_interactions.c_extra)
            for (S, dg) in _c_extra_to_delta_gS(atom.F, ws_interactions.c_extra)
                g_dict[S] = get(g_dict, S, 0.0) + dg
            end
        end
        compute_spinor_lhy_fm_contact(; F=atom.F, g_dict=g_dict, n_max=n_max_est)
    elseif spinor_lhy === :polar_dipolar
        # F-generic polar contact + DDI LHY (paper #1 with dipolar extension).
        # ε̃ derived as the simple |c_dd| / |δ_1| ratio; for finer control
        # over the convention call `compute_spinor_lhy_polar_dipolar(;
        # eps_tilde_dd, ...)` directly and pass the resulting `SpinorLHYTable`
        # via `lhy_table=`.
        n_max_est = if psi_init !== nothing
            maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
        else
            100.0
        end
        g_dict = _c0c1_to_gS(atom.F, ws_interactions.c0, ws_interactions.c1)
        if !isempty(ws_interactions.c_extra)
            for (S, dg) in _c_extra_to_delta_gS(atom.F, ws_interactions.c_extra)
                g_dict[S] = get(g_dict, S, 0.0) + dg
            end
        end
        c_dd_eff = enable_ddi && !isnan(c_dd) ? c_dd : 0.0
        delta_1 = PolarContactLHY.delta_polar(atom.F, 1, g_dict)
        eps_tilde_dd = abs(delta_1) > 1e-12 ? abs(c_dd_eff) / abs(delta_1) : 0.0
        compute_spinor_lhy_polar_dipolar(; F=atom.F, g_dict=g_dict,
            eps_tilde_dd=eps_tilde_dd,
            n_max=n_max_est)
    elseif quasi_2d && abs(ws_interactions.c_lhy) > 1e-30
        compute_lhy_2d_params(ws_interactions.c0, l_z)
    elseif abs(ws_interactions.c_lhy) > 1e-30
        ScalarLHY(ws_interactions.c_lhy)
    else
        nothing
    end

    abs_mask = if absorbing_boundary !== nothing
        compute_absorbing_mask(grid, absorbing_boundary, sim_params.dt, backend; dtype=U)
    else
        nothing
    end

    Workspace(
        state,
        plans,
        kinetic_phase,
        V,
        density_buf,
        sm,
        grid,
        atom,
        ws_interactions,
        effective_zeeman,
        potential,
        sim_params,
        ddi,
        ddi_bufs,
        raman,
        loss,
        ddi_pad,
        batched_kinetic,
        tensor_cache,
        coriolis_cache,
        backend,
        lhy,
        abs_mask,
        light_shift,
        time_dep_interactions,
        magnetic_gradient,
    )
end

"""
    _rebuild_workspace(ws; field=value, ...)

Create a new Workspace by copying all fields from `ws`, overriding specified fields.
Avoids fragile positional constructor calls when Workspace gains new fields.
"""
function _rebuild_workspace(ws::Workspace; kwargs...)
    names = fieldnames(Workspace)
    override = Dict{Symbol, Any}(kwargs)
    args = [haskey(override, n) ? override[n] : getfield(ws, n) for n in names]
    Workspace(args...)
end

_shift_zeeman_for_rotating_frame(z::ZeemanParams, omega::Float64) = ZeemanParams(z.p - omega, z.q)

# Use the concrete `ShiftedWaveform{typeof(z.p_wf)}` rather than wrapping
# in `FunctionWaveform(t -> ...)`. Each closure-based call leaked a fresh
# anonymous-function type into the per-step `evaluate` dispatch table;
# `ShiftedWaveform` keeps that static. (The narrowed concrete-type
# annotation also lets the optimiser specialise `evaluate(p_wf, t)` —
# see CLAUDE.md "Type stability boundaries".)
function _shift_zeeman_for_rotating_frame(z::TimeDependentZeeman, omega::Float64)
    TimeDependentZeeman(ShiftedWaveform(z.p_wf, omega), z.q_wf, z.bx_wf, z.by_wf)
end
