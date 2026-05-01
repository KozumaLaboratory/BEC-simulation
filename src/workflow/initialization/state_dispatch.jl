# --- init_psi state-symbol dispatch ---
#
# Single switch over 22 named initial states. Each branch sets one or more
# spinor components from a Gaussian envelope. Helpers (_gaussian,
# _set_component!, _extract_spinor, _default_spinor) live in
# state_dispatch_helpers.jl.

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

    state = canonicalize_state(state)   # legacy ferromagnetic{,_min} → m_{plus,minus}_F
    if state == :polar
        mid = (D + 1) ÷ 2
        _set_component!(psi, gauss, N, n_pts, mid)
    elseif state == :m_plus_F
        _set_component!(psi, gauss, N, n_pts, 1)  # m = +F
    elseif state == :m_minus_F
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

