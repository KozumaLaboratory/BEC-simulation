function init_psi(
    grid::Grid{N, T},
    sys::SpinSystem;
    state::Symbol=:polar,
    seed::Int=42,
    helix_k::NTuple{N, Float64}=ntuple(_ -> 0.0, N),
    init_theta::Real=0.0,
    init_phi::Real=0.0,
    init_vortex_charge::Real=0,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    init_theta_f = Float64(init_theta)
    init_phi_f = Float64(init_phi)
    init_vortex_charge_i = Int(init_vortex_charge)
    n_pts = grid.config.n_points
    psi = zeros(Complex{U}, n_pts..., sys.n_components)
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
        for c in 1:D
            _set_component!(psi, gauss / sqrt(D), N, n_pts, c)
        end
    elseif state == :antiferromagnetic
        for c in 1:D
            m = F - (c - 1)
            sign = iseven(F - m) ? 1.0 : -1.0
            _set_component!(psi, sign * gauss / sqrt(D), N, n_pts, c)
        end
    elseif state == :random
        rng = Random.MersenneTwister(seed)
        psi .= randn(rng, ComplexF64, size(psi))
        @inbounds for I in CartesianIndices(n_pts)
            for c in 1:D
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
                    ":spin_coherent with init_vortex_charge≠0 requires N >= 2"
                ),
            )
        end

        sm = spin_matrices(F)
        U_y = exp(-1im * theta_use * Matrix(sm.Fy))
        c_base = U_y[:, 1]  # column for |m=+F⟩

        if vortex_charge_use == 0
            # Uniform spin direction: precompute Rz(init_phi) c_base.
            spinor_uniform = Vector{ComplexF64}(undef, D)
            for c in 1:D
                m = F - (c - 1)
                spinor_uniform[c] = c_base[c] * cis(-m * init_phi_f)
            end
            @inbounds for I in CartesianIndices(n_pts)
                for c in 1:D
                    psi[I, c] = gauss[I] * spinor_uniform[c]
                end
            end
        else
            @inbounds for I in CartesianIndices(n_pts)
                x = grid.x[1][I[1]]
                y = grid.x[2][I[2]]
                phi_local = init_phi_f + vortex_charge_use * atan(y, x)
                for c in 1:D
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
            for c in 1:D
                m = F - (c - 1)
                if c == 1
                    psi[I, c] = gauss[I] * complex(ct, st)^F
                else
                    psi[I, c] = zero(ComplexF64)
                end
            end
            spinor = Vector{ComplexF64}(undef, D)
            for c in 1:D
                spinor[c] = psi[I, c]
            end
            rot = exp(-1im * theta * Matrix(sm.Fy))
            rotated = rot * [c == 1 ? complex(gauss[I]) : zero(ComplexF64) for c in 1:D]
            for c in 1:D
                psi[I, c] = rotated[c]
            end
        end
    elseif state == :cyclic
        # Cyclic state: equal amplitude, phases 0, 2π/3, 4π/3
        # For F=1: ψ = (1, 0, 1)/√2 (up to normalization)
        # General F: distribute among m = F, 0, -F with cyclic phases
        c_top = 1
        c_mid = (D + 1) ÷ 2
        c_bot = D
        inv_sqrt3 = 1.0 / sqrt(3.0)
        for I in CartesianIndices(n_pts)
            psi[I, c_top] = gauss[I] * inv_sqrt3
            psi[I, c_mid] = gauss[I] * inv_sqrt3 * cis(2π / 3)
            psi[I, c_bot] = gauss[I] * inv_sqrt3 * cis(4π / 3)
        end
    elseif state == :biaxial_nematic
        # Biaxial nematic: (|+2⟩ + |−2⟩)/√2 for F≥2, (|+1⟩ + |−1⟩)/√2 for F=1
        delta = min(2, F)
        c_p = F - delta + 1
        c_m = F + delta + 1
        inv_sqrt2 = 1.0 / sqrt(2.0)
        for I in CartesianIndices(n_pts)
            psi[I, c_p] = gauss[I] * inv_sqrt2
            psi[I, c_m] = gauss[I] * inv_sqrt2
        end
    elseif state == :polar_core_vortex
        # Polar-core vortex (PCV): core is polar (m=0), outer is vortex in m=±F
        N >= 2 || throw(ArgumentError(":polar_core_vortex requires N >= 2"))
        c_mid = (D + 1) ÷ 2
        r_core = min(grid.config.box_size...) / 8
        charge = init_vortex_charge_i == 0 ? 1 : init_vortex_charge_i
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            r = sqrt(x^2 + y^2)
            phi = atan(y, x)
            f_core = exp(-r^2 / (2 * r_core^2))
            f_outer = sqrt(max(0.0, 1.0 - f_core^2))
            psi[I, c_mid] = gauss[I] * f_core
            psi[I, 1] = gauss[I] * f_outer * cis(charge * phi) / sqrt(2.0)
            psi[I, D] = gauss[I] * f_outer * cis(-charge * phi) / sqrt(2.0)
        end
    elseif state == :soliton_bright
        # Bright soliton in 1D: sech profile
        c_mid = (D + 1) ÷ 2
        w = grid.config.box_size[1] / 10
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            psi[I, c_mid] = complex(1.0 / cosh(x / w))
        end
    elseif state == :soliton_dark
        # Dark soliton in 1D: tanh profile
        c_mid = (D + 1) ÷ 2
        w = grid.config.box_size[1] / 20
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            psi[I, c_mid] = gauss[I] * tanh(x / w)
        end
    elseif state == :skyrmion
        # Baby skyrmion texture in 2D
        N >= 2 || throw(ArgumentError(":skyrmion requires N >= 2"))
        D >= 3 || throw(ArgumentError(":skyrmion requires F >= 1"))
        sm = spin_matrices(F)
        R = min(grid.config.box_size...) / 4
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            r = sqrt(x^2 + y^2)
            phi = atan(y, x)
            theta = π * (1.0 - r / R)
            theta = clamp(theta, 0.0, π)
            U_y = exp(-1im * theta * Matrix(sm.Fy))
            c_base = U_y[:, 1]
            for c in 1:D
                m = F - (c - 1)
                psi[I, c] = gauss[I] * c_base[c] * cis(-m * phi)
            end
        end
    elseif state == :gaussian_wavepacket
        # Gaussian wavepacket with momentum kick along dim 1
        c_mid = (D + 1) ÷ 2
        k0 = init_theta_f  # reuse init_theta as momentum
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            psi[I, c_mid] = gauss[I] * cis(k0 * x)
        end
    elseif state == :domain_wall
        # Domain wall: m=+F for x<0, m=-F for x>0, smooth transition
        w = grid.config.box_size[1] / 20
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            f_left = 0.5 * (1.0 - tanh(x / w))
            f_right = 0.5 * (1.0 + tanh(x / w))
            psi[I, 1] = gauss[I] * sqrt(f_left)
            psi[I, D] = gauss[I] * sqrt(f_right)
        end
    elseif state == :two_packet
        # Two counter-propagating wavepackets for collision studies
        c_mid = (D + 1) ÷ 2
        sep = grid.config.box_size[1] / 4
        w = grid.config.box_size[1] / 12
        k0 = init_theta_f == 0.0 ? 2π / grid.config.box_size[1] * 3 : init_theta_f
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            g1 = exp(-(x + sep)^2 / (2 * w^2))
            g2 = exp(-(x - sep)^2 / (2 * w^2))
            psi[I, c_mid] = (g1 * cis(k0 * x) + g2 * cis(-k0 * x))
        end
    elseif state == :chiral_spin_vortex
        # Chiral spin vortex: spin texture winds chirally in the xy-plane
        # Core: m=0 (polar), outer: spin rotates with winding + helicity
        N >= 2 || throw(ArgumentError(":chiral_spin_vortex requires N >= 2"))
        sm = spin_matrices(F)
        R = min(grid.config.box_size...) / 4
        charge = init_vortex_charge_i == 0 ? 1 : init_vortex_charge_i
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            r = sqrt(x^2 + y^2)
            phi = atan(y, x)
            theta = (π / 2) * min(r / R, 1.0)
            chi = charge * phi + init_phi_f
            U_y = exp(-1im * theta * Matrix(sm.Fy))
            c_base = U_y[:, 1]
            for c in 1:D
                m = F - (c - 1)
                psi[I, c] = gauss[I] * c_base[c] * cis(-m * chi)
            end
        end
    elseif state == :magnetic_domain
        # 2D magnetic domain pattern: stripe (default), square, or hexagonal
        # init_vortex_charge selects pattern: 0/1=stripe, 2=square, 3=hexagonal
        k0 = init_theta_f == 0.0 ? 2π / (grid.config.box_size[1] / 4) : init_theta_f
        pattern = init_vortex_charge_i
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            mod_val = if pattern <= 1
                sin(k0 * x)
            elseif pattern == 2 && N >= 2
                y = grid.x[2][I[2]]
                sin(k0 * x) * sin(k0 * y)
            elseif pattern == 3 && N >= 2
                y = grid.x[2][I[2]]
                cos(k0 * x) + cos(k0 * (-0.5 * x + sqrt(3) / 2 * y)) +
                cos(k0 * (-0.5 * x - sqrt(3) / 2 * y))
            else
                sin(k0 * x)
            end
            f_up = 0.5 * (1.0 + tanh(5.0 * mod_val))
            f_dn = 1.0 - f_up
            psi[I, 1] = gauss[I] * sqrt(f_up)
            psi[I, D] = gauss[I] * sqrt(f_dn)
        end
    elseif state == :vortex_lattice
        # Vortex lattice: array of phase vortices in m=+F component
        N >= 2 || throw(ArgumentError(":vortex_lattice requires N >= 2"))
        n_v = init_vortex_charge_i == 0 ? 4 : abs(init_vortex_charge_i)
        spacing = grid.config.box_size[1] / (n_v + 1)
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            phase_acc = 0.0
            for ix in 1:n_v, iy in 1:n_v
                xv = -grid.config.box_size[1] / 2 + ix * spacing
                yv = -grid.config.box_size[2] / 2 + iy * spacing
                phase_acc += atan(y - yv, x - xv)
            end
            psi[I, 1] = gauss[I] * cis(phase_acc)
        end
    elseif state == :skyrmion_lattice
        # Skyrmion lattice: periodic array of skyrmions via triple-Q ansatz
        N >= 2 || throw(ArgumentError(":skyrmion_lattice requires N >= 2"))
        D >= 3 || throw(ArgumentError(":skyrmion_lattice requires F >= 1"))
        sm = spin_matrices(F)
        q0 = init_theta_f == 0.0 ? 2π / (grid.config.box_size[1] / 3) : init_theta_f
        q_vecs = [(q0, 0.0), (q0 * (-0.5), q0 * sqrt(3) / 2), (q0 * (-0.5), q0 * (-sqrt(3) / 2))]
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            mx = sum(cos(qx * x + qy * y) for (qx, qy) in q_vecs)
            my = sum(sin(qx * x + qy * y) for (qx, qy) in q_vecs)
            mz = 1.5
            m_norm = sqrt(mx^2 + my^2 + mz^2)
            mx /= m_norm;
            my /= m_norm;
            mz /= m_norm
            theta = acos(clamp(mz, -1.0, 1.0))
            phi = atan(my, mx)
            U_y = exp(-1im * theta * Matrix(sm.Fy))
            c_base = U_y[:, 1]
            for c in 1:D
                m = F - (c - 1)
                psi[I, c] = gauss[I] * c_base[c] * cis(-m * phi)
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

function _gaussian(grid::Grid{N}, sigma::NTuple{N, Float64}) where {N}
    g = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d in 1:N
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

function _extract_spinor(psi::AbstractArray{<:Complex})
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
        if !secular_ddi && abs(zeeman.p) > 1e-15 && c_dd_val > 1e-30
            n_peak_est =
                sum(abs2, _to_host(psi)) / cell_volume(grid) /
                max(1, prod(grid.config.n_points))  # rough mean → upper bound on n_peak
            larmor_ratio = abs(zeeman.p) / max(c_dd_val * n_peak_est, 1e-30)
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
_shift_zeeman_for_rotating_frame(z::TimeDependentZeeman, omega::Float64) = TimeDependentZeeman(
    FunctionWaveform(t -> evaluate(z.p_wf, t) - omega),
    z.q_wf,
    z.bx_wf,
    z.by_wf,
)
