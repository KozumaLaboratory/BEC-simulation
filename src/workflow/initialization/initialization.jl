function init_psi(
    grid::Grid{N},
    sys::SpinSystem;
    state::Symbol = :polar,
    seed::Int = 42,
    helix_k::NTuple{N,Float64} = ntuple(_ -> 0.0, N),
    init_theta::Real = 0.0,
    init_phi::Real = 0.0,
    init_vortex_charge::Real = 0,
) where {N}
    init_theta_f = Float64(init_theta)
    init_phi_f = Float64(init_phi)
    init_vortex_charge_i = Int(init_vortex_charge)
    n_pts = grid.config.n_points
    psi = zeros(ComplexF64, n_pts..., sys.n_components)
    F = sys.F
    D = sys.n_components

    sigma = ntuple(d -> grid.config.box_size[d] / 8, N)
    gauss = _gaussian(grid, sigma)

    if state == :polar
        mid = (D + 1) ÷ 2
        _set_component!(psi, gauss, N, n_pts, mid)
    elseif state == :ferromagnetic
        _set_component!(psi, gauss, N, n_pts, 1)  # m = +F
    elseif state == :ferromagnetic_min
        _set_component!(psi, gauss, N, n_pts, D)  # m = -F
    elseif state == :uniform
        for c = 1:D
            _set_component!(psi, gauss / sqrt(D), N, n_pts, c)
        end
    elseif state == :antiferromagnetic
        for c = 1:D
            m = F - (c - 1)
            sign = iseven(F - m) ? 1.0 : -1.0
            _set_component!(psi, sign * gauss / sqrt(D), N, n_pts, c)
        end
    elseif state == :random
        rng = Random.MersenneTwister(seed)
        psi .= randn(rng, ComplexF64, size(psi))
        @inbounds for I in CartesianIndices(n_pts)
            for c = 1:D
                psi[I, c] *= gauss[I]
            end
        end
    elseif state == :spin_coherent || state == :fl_vortex
        # Spin-coherent state: at each grid point, the spinor points in the
        # direction (sin θ cos φ, sin θ sin φ, cos θ), constructed as
        # |ψ⟩ = Rz(φ) Ry(θ) |m=+F⟩.
        #
        # When init_vortex_charge ≠ 0, the azimuthal angle picks up
        # ℓ × atan(y, x) so the spin texture has winding number ℓ. This
        # generalizes the flower (FL) vortex (θ=π/2, ℓ=1).
        #
        # :fl_vortex is a backward-compat alias that forces θ=π/2, ℓ=1.
        theta_use, vortex_charge_use = if state == :fl_vortex
            N >= 2 || throw(ArgumentError(":fl_vortex requires N >= 2 (needs xy-plane)"))
            (Float64(π) / 2, 1)
        else
            (init_theta_f, init_vortex_charge_i)
        end
        if vortex_charge_use != 0
            N >= 2 || throw(
                ArgumentError(
                    ":spin_coherent with init_vortex_charge≠0 requires N >= 2",
                ),
            )
        end

        sm = spin_matrices(F)
        U_y = exp(-1im * theta_use * Matrix(sm.Fy))
        c_base = U_y[:, 1]  # column for |m=+F⟩

        if vortex_charge_use == 0
            # Uniform spin direction: precompute Rz(init_phi) c_base.
            spinor_uniform = Vector{ComplexF64}(undef, D)
            for c = 1:D
                m = F - (c - 1)
                spinor_uniform[c] = c_base[c] * cis(-m * init_phi_f)
            end
            @inbounds for I in CartesianIndices(n_pts)
                for c = 1:D
                    psi[I, c] = gauss[I] * spinor_uniform[c]
                end
            end
        else
            @inbounds for I in CartesianIndices(n_pts)
                x = grid.x[1][I[1]]
                y = grid.x[2][I[2]]
                phi_local = init_phi_f + vortex_charge_use * atan(y, x)
                for c = 1:D
                    m = F - (c - 1)
                    psi[I, c] = gauss[I] * c_base[c] * cis(-m * phi_local)
                end
            end
        end
    elseif state == :spin_helix
        sm = spin_matrices(F)
        @inbounds for I in CartesianIndices(n_pts)
            theta = sum(ntuple(d -> helix_k[d] * grid.x[d][I[d]], Val(N)))
            ct = cos(theta)
            st = sin(theta)
            for c = 1:D
                m = F - (c - 1)
                if c == 1
                    psi[I, c] = gauss[I] * complex(ct, st)^F
                else
                    psi[I, c] = zero(ComplexF64)
                end
            end
            spinor = Vector{ComplexF64}(undef, D)
            for c = 1:D
                spinor[c] = psi[I, c]
            end
            rot = exp(-1im * theta * Matrix(sm.Fy))
            rotated = rot * [c == 1 ? complex(gauss[I]) : zero(ComplexF64) for c = 1:D]
            for c = 1:D
                psi[I, c] = rotated[c]
            end
        end
    else
        throw(ArgumentError("Unknown initial state: $state"))
    end

    dV = cell_volume(grid)
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
    psi
end

function _gaussian(grid::Grid{N}, sigma::NTuple{N,Float64}) where {N}
    g = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d = 1:N
            s += grid.x[d][I[d]]^2 / (2 * sigma[d]^2)
        end
        g[I] = exp(-s)
    end
    g
end

function _set_component!(psi, vals, ndim, n_pts, c)
    idx = _component_slice(ndim, n_pts, c)
    view(psi, idx...) .= vals
end

function _extract_spinor(psi::AbstractArray{ComplexF64})
    D = size(psi, ndims(psi))
    n_pts = ntuple(d -> size(psi, d), ndims(psi) - 1)
    peak_idx = argmax(sum(abs2, psi; dims=ndims(psi)))
    spinor = Vector{ComplexF64}(undef, D)
    for c in 1:D
        spinor[c] = psi[peak_idx, c]
    end
    nrm = norm(spinor)
    nrm > 1e-30 && (spinor ./= nrm)
    spinor
end

function _default_spinor(F::Int)
    D = 2F + 1
    spinor = zeros(ComplexF64, D)
    spinor[1] = 1.0
    spinor
end

function make_workspace(;
    grid::Grid{N},
    atom::AtomSpecies,
    interactions::InteractionParams,
    zeeman::Union{ZeemanParams,TimeDependentZeeman} = ZeemanParams(),
    potential::AbstractPotential = NoPotential(),
    sim_params::SimParams,
    psi_init::Union{Nothing,AbstractArray{ComplexF64}} = nothing,
    enable_ddi::Bool = false,
    c_dd::Float64 = NaN,
    secular_ddi::Bool = false,
    raman::Union{Nothing,RamanCoupling{N}} = nothing,
    loss::Union{Nothing,LossParams} = nothing,
    fft_flags = FFTW.MEASURE,
    ddi_padding::Bool = false,
    quasi_2d_ddi::Bool = false,
    l_z_ddi::Float64 = 0.0,
    quasi_2d::Bool = false,
    l_z::Float64 = 0.0,
    backend::AbstractBackend = CPUBackend(),
    spinor_lhy::Union{Nothing,Symbol} = nothing,
) where {N}
    if quasi_2d
        N == 2 || throw(ArgumentError("quasi_2d requires 2D grid, got $(N)D"))
        l_z > 0 || throw(ArgumentError("quasi_2d requires l_z > 0"))
    end

    effective_interactions = quasi_2d ? scale_interactions_quasi_2d(interactions, l_z) : interactions

    if quasi_2d && enable_ddi
        quasi_2d_ddi = true
        l_z_ddi == 0.0 && (l_z_ddi = l_z)
    end

    sys = SpinSystem(atom.F)
    sm = spin_matrices(atom.F)

    psi = if psi_init === nothing
        init_psi(grid, sys)
    else
        copy(psi_init)
    end
    psi = _to_device(backend, psi)

    fft_buf = _zeros(backend, ComplexF64, grid.config.n_points...)
    state = SimState{N,typeof(psi),typeof(fft_buf)}(psi, fft_buf, 0.0, 0)

    plans = make_fft_plans(grid.config.n_points, backend; flags = fft_flags)
    kinetic_phase = _to_device(
        backend,
        prepare_kinetic_phase(
            grid,
            sim_params.dt;
            imaginary_time = sim_params.imaginary_time,
        ),
    )
    V = evaluate_potential(potential, grid)

    omega = sim_params.rotating_frame_omega
    if abs(omega) > 1e-15 && N >= 2
        @inbounds for I in CartesianIndices(grid.config.n_points)
            r_perp_sq = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2
            V[I] += 0.5 * omega^2 * r_perp_sq
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
        make_ddi_params(
            grid,
            atom;
            c_dd = c_dd_val,
            secular = secular_ddi,
            quasi_2d = quasi_2d_ddi,
            l_z = l_z_ddi,
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
        make_ddi_buffers(grid.config.n_points, backend; flags = fft_flags)
    else
        nothing
    end

    density_buf = _zeros(backend, Float64, grid.config.n_points...)

    ddi_pad = if ddi_padding && ddi !== nothing
        c_dd_val = isnan(c_dd) ? compute_c_dd(atom) : ddi.C_dd
        make_ddi_padded(
            grid,
            atom;
            c_dd = c_dd_val,
            fft_flags,
            secular = secular_ddi,
            quasi_2d = quasi_2d_ddi,
            l_z = l_z_ddi,
            backend,
        )
    else
        nothing
    end

    batched_kinetic = _make_batched_kinetic_cache(psi, kinetic_phase, N, backend; flags = fft_flags)

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
        tc, InteractionParams(effective_interactions.c0, effective_interactions.c1, effective_interactions.c_lhy, Float64[])
    else
        tc = make_tensor_interaction_cache(F, effective_interactions)
        if tc !== nothing && (abs(effective_interactions.c0) > 1e-30 || abs(effective_interactions.c1) > 1e-30)
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
        _make_coriolis_cache(psi, backend; flags = fft_flags)
    else
        nothing
    end

    lhy = if spinor_lhy === :two_channel
        n_max_est = psi_init !== nothing ? maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0 : 100.0
        compute_spinor_lhy_two_channel(;
            F=atom.F, c0=ws_interactions.c0, c1=ws_interactions.c1,
            c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
            n_max=n_max_est,
        )
    elseif spinor_lhy === :full_bdg
        n_max_est = psi_init !== nothing ? maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0 : 100.0
        spinor_init = psi_init !== nothing ? _extract_spinor(psi_init) : _default_spinor(atom.F)
        compute_spinor_lhy_table(;
            spinor=spinor_init, F=atom.F, interactions=ws_interactions,
            c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
            n_max=n_max_est,
        )
    elseif quasi_2d && abs(ws_interactions.c_lhy) > 1e-30
        compute_lhy_2d_params(ws_interactions.c0, l_z)
    elseif abs(ws_interactions.c_lhy) > 1e-30
        ScalarLHY(ws_interactions.c_lhy)
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
    )
end

_shift_zeeman_for_rotating_frame(z::ZeemanParams, omega::Float64) =
    ZeemanParams(z.p - omega, z.q)
_shift_zeeman_for_rotating_frame(z::TimeDependentZeeman, omega::Float64) =
    TimeDependentZeeman(t -> begin
        zp = z.B_func(t)
        ZeemanParams(zp.p - omega, zp.q)
    end)
