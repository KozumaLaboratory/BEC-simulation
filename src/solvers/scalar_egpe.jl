"""
Scalar eGPE under adiabatic spin elimination.

For dipolar BECs in the Larmor-fast limit (ω_L ≫ trap, DDI), the spinor
wavefunction factorizes: |Ψ(r,t)⟩ = ψ(r,t)·|B̂(t)⟩_F. The spin degree of
freedom follows B̂(t) instantaneously, leaving a scalar GPE for ψ(r,t)
with a **time-dependent dipolar polarization axis** B̂(t).

This file is the minimal Klaus-2022-style scalar dipolar eGPE skeleton:

    iℏ ∂_t ψ = [-ℏ²∇²/2m + V_trap + g|ψ|² + Φ_dd(r,t) + γ_LHY|ψ|³] ψ

where Φ_dd(r,t) = c_dd F² · F⁻¹{[(k̂·B̂(t))² - 1/3] · F{|ψ|²}}.

Not yet integrated with Workspace / YAML / dashboard — pass raw arrays.
"""

# --- Workspace ---

export make_scalar_ddi_pad

# --- Transverse-truncated dipolar kernel ---
#
# A plain FFT convolution imposes periodicity on EVERY axis, so a tube geometry
# gets image tubes at ±L_transverse that interact with the real one through the
# long-ranged DDI. Measured on the Roccuzzo-Ancilotto cell, E_dd drifts 38 % from
# L_t = 16 to 48 a_ho and is still moving (docs/validation/
# dipolar_supersolid_tube.md).
#
# The boundary conditions a tube actually wants are MIXED: periodic along the
# tube axis (that is physical — the cell is a ring) and isolated transversally.
# Zero-padding only the transverse axes realises exactly that split: the axial
# axis stays unpadded so its periodicity is exact by construction, while the
# transverse images move out to `pad · L_t`, where their 1/r³ contribution is
# suppressed by pad³.
#
# This is NOT the spherical truncation of `ddi_trunc_factor` used by the spinor
# padded path (Ronen-Bortolotti-Bohn). That one cuts the kernel at a radius in
# ALL directions, which would destroy the axial periodicity a ring depends on.
struct ScalarDDIPad{T <: AbstractFloat, N, FP, IP}
    shape::NTuple{N, Int}          # padded grid size
    pad::NTuple{N, Int}            # per-axis integer pad factor (1 = untouched)
    fwd::FP
    inv::IP
    buf::Array{Complex{T}, N}      # padded density / potential scratch
    k::NTuple{N, Vector{T}}        # padded k grids (same dx as the base grid)
end

"""
    make_scalar_ddi_pad(grid, pad) -> ScalarDDIPad

Zero-pad context for the dipolar convolution. `pad` is a per-axis integer factor;
`1` leaves an axis periodic at its physical period. For a tube along `x` use
`(1, 2, 2)` or wider — see `ScalarDDIPad` for why the axial axis must stay at 1.
"""
function make_scalar_ddi_pad(grid::Grid{N, T}, pad::NTuple{N, Int}) where {N, T}
    all(>=(1), pad) || throw(ArgumentError("pad factors must be ≥ 1, got $pad"))
    n_pts = grid.config.n_points
    shape = ntuple(d -> pad[d] * n_pts[d], N)
    buf = zeros(Complex{T}, shape...)
    fwd = plan_fft!(similar(buf))
    inv = plan_ifft!(similar(buf))
    # Same dx, more points ⇒ finer k spacing over the same Nyquist range.
    kg = ntuple(N) do d
        n = shape[d]
        collect(T, fftfreq(n, n * 2π / (n * grid.dx[d])))
    end
    ScalarDDIPad{T, N, typeof(fwd), typeof(inv)}(shape, pad, fwd, inv, buf, kg)
end

struct ScalarSimWS{T <: AbstractFloat, N, FP, IP, PD}
    psi::Array{Complex{T}, N}
    grid::Grid{N, T}

    # FFT plans (in-place on psi-shaped buffer)
    fft_fwd::FP
    fft_inv::IP
    psi_k::Array{Complex{T}, N}    # scratch for psi in k-space
    rho::Array{T, N}               # |psi|² scratch
    rho_c::Array{Complex{T}, N}    # complex copy of rho for FFT
    V_dd::Array{T, N}              # real-space dipolar potential

    # static parts
    V_trap::Array{T, N}

    # couplings (all in dimensionless reference units)
    g_contact::T          # 4π·a_s·N (scalar contact)
    c_dd::T               # mu0*(gF*muB)^2*N per unit spin (no 4π)
    F::T                  # spin quantum number (only enters as F² in DDI weight)
    gamma_lhy::T          # γ_LHY (set 0 to disable)

    # `nothing` = plain periodic convolution on the base grid (default, and the
    # right choice when every axis is genuinely periodic).
    ddi_pad::PD
end

function make_scalar_ws(
    grid::Grid{N, T},
    V_trap::AbstractArray{T, N};
    g_contact::Real,
    c_dd::Real,
    F::Real,
    gamma_lhy::Real=0.0,
    ddi_pad::Union{Nothing, NTuple{N, Int}}=nothing,
) where {N, T <: AbstractFloat}
    n_pts = grid.config.n_points
    psi = zeros(Complex{T}, n_pts...)
    psi_k = similar(psi)
    rho = zeros(T, n_pts...)
    rho_c = similar(psi)
    V_dd = zeros(T, n_pts...)

    fft_fwd = plan_fft!(similar(psi))
    fft_inv = plan_ifft!(similar(psi))

    pad_ctx = ddi_pad === nothing ? nothing : make_scalar_ddi_pad(grid, ddi_pad)

    ScalarSimWS{T, N, typeof(fft_fwd), typeof(fft_inv), typeof(pad_ctx)}(
        psi, grid, fft_fwd, fft_inv,
        psi_k, rho, rho_c, V_dd,
        Array(V_trap),
        T(g_contact), T(c_dd), T(F), T(gamma_lhy),
        pad_ctx,
    )
end

# --- Tilted dipole kernel ---

"""
Compute V_dd(r) = c_dd F² · ∫ [(k̂·B̂)² - 1/3] ρ̂(k) e^{ik·r} d³k
in place into `ws.V_dd`. Caller has already filled `ws.rho` with |ψ|².

Sign + normalization match `_build_q_tensor!` (no explicit 4π, k=0 → 0).
"""
# Dipolar projection (k̂·B̂)² − 1/3 applied in place to a k-space density, with
# the k=0 mode dropped (repo convention Q(k=0)=0).
@inline function _apply_dipole_projection!(
    buf::Array{Complex{T}, N}, shape::NTuple{N, Int}, kg, k2_of, weight::T, B_hat
) where {T, N}
    third = T(1) / T(3)
    bx, by, bz = B_hat[1], B_hat[2], B_hat[3]
    @inbounds for I in CartesianIndices(shape)
        kvx = kg[1][I[1]]
        kvy = N >= 2 ? kg[2][I[2]] : zero(T)
        kvz = N >= 3 ? kg[3][I[3]] : zero(T)
        k2 = k2_of(I, kvx, kvy, kvz)
        if iszero(k2)
            buf[I] = zero(Complex{T})
            continue
        end
        kdotB = kvx * bx + kvy * by + kvz * bz
        buf[I] *= weight * (kdotB * kdotB / k2 - third)
    end
    nothing
end

# Transverse-truncated (zero-padded) dipolar potential. The axial axis keeps
# pad = 1 so its periodicity is exact; padded axes push their images out.
function _compute_dipole_potential_padded!(
    ws::ScalarSimWS{T, N}, B_hat::SVector{3, T}, pd::ScalarDDIPad{T, N}
) where {T, N}
    fill!(pd.buf, zero(Complex{T}))
    n_pts = ws.grid.config.n_points
    # Embed the density at the ORIGIN of the padded box. Because the kernel is
    # evaluated in k-space it is periodic on the padded grid, so where the
    # density sits does not matter — only that it does not wrap.
    @inbounds for I in CartesianIndices(n_pts)
        pd.buf[I] = Complex{T}(ws.rho[I], zero(T))
    end
    pd.fwd * pd.buf
    _apply_dipole_projection!(
        pd.buf, pd.shape, pd.k,
        (_, kx, ky, kz) -> kx * kx + ky * ky + kz * kz,
        ws.c_dd * ws.F * ws.F, B_hat,
    )
    pd.inv * pd.buf
    @inbounds for I in CartesianIndices(n_pts)
        ws.V_dd[I] = real(pd.buf[I])
    end
    nothing
end

function compute_tilted_dipole_potential!(
    ws::ScalarSimWS{T, N}, B_hat::SVector{3, T}
) where {T, N}
    ws.ddi_pad === nothing ||
        return _compute_dipole_potential_padded!(ws, B_hat, ws.ddi_pad)
    # rho is real; lift to complex for in-place FFT
    @inbounds for I in eachindex(ws.rho)
        ws.rho_c[I] = Complex{T}(ws.rho[I], zero(T))
    end
    ws.fft_fwd * ws.rho_c   # in-place: rho_c now in k-space

    third = T(1) / T(3)
    bx, by, bz = B_hat[1], B_hat[2], B_hat[3]
    weight = ws.c_dd * ws.F * ws.F   # F² factor for full polarization

    n_pts = ws.grid.config.n_points
    kx = ws.grid.k[1]
    ky = N >= 2 ? ws.grid.k[2] : T[zero(T)]
    kz = N >= 3 ? ws.grid.k[3] : T[zero(T)]

    @inbounds for I in CartesianIndices(n_pts)
        k2 = ws.grid.k_squared[I]
        if iszero(k2)
            ws.rho_c[I] = zero(Complex{T})
            continue
        end
        kvx = kx[I[1]]
        kvy = N >= 2 ? ky[I[2]] : zero(T)
        kvz = N >= 3 ? kz[I[3]] : zero(T)
        kdotB = kvx * bx + kvy * by + kvz * bz
        proj = kdotB * kdotB / k2 - third
        ws.rho_c[I] *= weight * proj
    end

    ws.fft_inv * ws.rho_c   # in-place: back to real space
    @inbounds for I in eachindex(ws.V_dd)
        ws.V_dd[I] = real(ws.rho_c[I])
    end
    nothing
end

# --- Substep operators ---

"""Compute ρ = |ψ|² in place into ws.rho."""
function _update_density!(ws::ScalarSimWS{T, N}) where {T, N}
    @inbounds for I in eachindex(ws.psi)
        re = real(ws.psi[I]);
        im = imag(ws.psi[I])
        ws.rho[I] = re * re + im * im
    end
    nothing
end

"""Diagonal step: ψ ← exp(-i (V_trap + g·ρ + V_dd + γ_LHY·ρ^{3/2}) · dt) ψ
(real time) or exp(-(...)·dt) ψ (imaginary time)."""
function apply_diagonal_step_scalar!(
    ws::ScalarSimWS{T, N}, dt::T; imaginary_time::Bool=false
) where {T, N}
    g = ws.g_contact
    γ = ws.gamma_lhy
    if imaginary_time
        @inbounds for I in eachindex(ws.psi)
            ρ = ws.rho[I]
            V_local = ws.V_trap[I] + g * ρ + ws.V_dd[I]
            if γ != zero(T)
                V_local += γ * ρ * sqrt(ρ)
            end
            ws.psi[I] *= exp(-V_local * dt)
        end
    else
        @inbounds for I in eachindex(ws.psi)
            ρ = ws.rho[I]
            V_local = ws.V_trap[I] + g * ρ + ws.V_dd[I]
            if γ != zero(T)
                V_local += γ * ρ * sqrt(ρ)
            end
            ws.psi[I] *= cis(-V_local * dt)
        end
    end
    nothing
end

"""Kinetic step: ψ ← F⁻¹{exp(-i k²/2 · dt) F{ψ}} (real time) or
F⁻¹{exp(-k²/2·dt) F{ψ}} (imaginary time)."""
function apply_kinetic_step_scalar!(
    ws::ScalarSimWS{T, N}, dt::T; imaginary_time::Bool=false
) where {T, N}
    ws.fft_fwd * ws.psi
    if imaginary_time
        @inbounds for I in eachindex(ws.psi)
            ws.psi[I] *= exp(-T(dt) * ws.grid.k_squared[I] / 2)
        end
    else
        @inbounds for I in eachindex(ws.psi)
            ws.psi[I] *= cis(-T(dt) * ws.grid.k_squared[I] / 2)
        end
    end
    ws.fft_inv * ws.psi
    nothing
end

# --- Strang split-step ---

"""
One Strang step at time `t` over duration `dt` with polarization axis
function `B_hat_func(t) → SVector{3,T}`. Order:

    T(dt/2) → V_diag(dt) → T(dt/2)

where V_diag is evaluated with B̂ at midpoint t + dt/2 and ρ refreshed
just before the diagonal step. The dipolar potential is treated as part
of the local potential — no separate symmetrization (it's diagonal in r).
"""
function split_step_scalar!(
    ws::ScalarSimWS{T, N}, dt::T, t::T, B_hat_func::Function;
    imaginary_time::Bool=false,
) where {T, N}
    half = dt / 2
    apply_kinetic_step_scalar!(ws, half; imaginary_time)

    _update_density!(ws)
    B_mid = B_hat_func(t + half)::SVector{3, T}
    compute_tilted_dipole_potential!(ws, B_mid)
    apply_diagonal_step_scalar!(ws, dt; imaginary_time)

    apply_kinetic_step_scalar!(ws, half; imaginary_time)
    nothing
end

"""Renormalize ψ to total norm = `target_norm`."""
function normalize_scalar!(ws::ScalarSimWS{T, N}; target_norm::T=one(T)) where {T, N}
    n = scalar_norm(ws)
    n > zero(T) || return nothing
    s = sqrt(target_norm / n)
    @inbounds for I in eachindex(ws.psi)
        ws.psi[I] *= s
    end
    nothing
end

"""ITP ground state: imaginary-time Strang split with renormalization
each step. Returns final estimated chemical potential μ ≈ -ln(N(t)/N(t-dt))/dt
(after a renormalization step the norm has dropped by exp(-2μ·dt))."""
function find_ground_state_scalar!(
    ws::ScalarSimWS{T, N}, n_steps::Int, dt::T; B_hat::SVector{3, T},
    target_norm::T=one(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N}
    B_func = (_t::T) -> B_hat
    μ_last = zero(T)
    for step in 1:n_steps
        split_step_scalar!(ws, dt, zero(T), B_func; imaginary_time=true)
        n_before_renorm = scalar_norm(ws)
        # Norm decay in imag-time corresponds to drop ratio exp(-2μ·dt)·N0
        # We renormalize after, but capture μ from the decay.
        if n_before_renorm > zero(T) && target_norm > zero(T)
            μ_last = -log(n_before_renorm / target_norm) / (2 * dt)
        end
        normalize_scalar!(ws; target_norm)
        on_step !== nothing && on_step(step, μ_last, ws)
    end
    μ_last
end

# --- Driver ---

"""
Evolve ws.psi for `n_steps` of size `dt` starting at time `t0`. The
polarization axis is `B_hat_func(t)`; called at each step's midpoint.

Returns the final time `t0 + n_steps·dt`. Use `observe!` callbacks
(via the optional `on_step` kwarg) to record observables.
"""
function evolve_scalar!(
    ws::ScalarSimWS{T, N}, n_steps::Int, dt::T; t0::T=zero(T),
    B_hat_func::Function,
    on_step::Union{Nothing, Function}=nothing,
) where {T, N}
    t = t0
    for step in 1:n_steps
        split_step_scalar!(ws, dt, t, B_hat_func)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

# --- Observables (minimal) ---

"""Total norm ∫|ψ|² dV."""
function scalar_norm(ws::ScalarSimWS{T, N}) where {T, N}
    s = zero(T)
    @inbounds for I in eachindex(ws.psi)
        re = real(ws.psi[I]);
        im = imag(ws.psi[I])
        s += re * re + im * im
    end
    s * prod(ws.grid.dx)
end

"""Centre of mass (x_cm, y_cm[, z_cm])."""
function scalar_com(ws::ScalarSimWS{T, N}) where {T, N}
    dV = prod(ws.grid.dx)
    norm = scalar_norm(ws)
    inv_n = norm > 0 ? one(T) / norm : zero(T)
    com = zeros(T, N)
    @inbounds for I in CartesianIndices(ws.psi)
        re = real(ws.psi[I]);
        im = imag(ws.psi[I])
        ρ = re * re + im * im
        for d in 1:N
            com[d] += ρ * ws.grid.x[d][I[d]]
        end
    end
    SVector{N, T}(ntuple(d -> com[d] * dV * inv_n, N))
end

"""Aspect ratio (Rz / Rxy) from second moments of density."""
function scalar_aspect_ratio(ws::ScalarSimWS{T, 3}) where {T}
    dV = prod(ws.grid.dx)
    n = scalar_norm(ws)
    n > 0 || return zero(T)
    com = scalar_com(ws)
    σ_xy = zero(T);
    σ_z = zero(T)
    @inbounds for I in CartesianIndices(ws.psi)
        re = real(ws.psi[I]);
        im = imag(ws.psi[I])
        ρ = re * re + im * im
        x = ws.grid.x[1][I[1]] - com[1]
        y = ws.grid.x[2][I[2]] - com[2]
        z = ws.grid.x[3][I[3]] - com[3]
        σ_xy += ρ * (x * x + y * y) / 2
        σ_z += ρ * z * z
    end
    σ_xy *= dV / n;
    σ_z *= dV / n
    σ_xy > 0 ? sqrt(σ_z / σ_xy) : zero(T)
end

"""Energy decomposition: (E_kin, E_trap, E_contact, E_dd, E_total).
Excludes LHY (assumes γ_LHY=0; safe for current callers)."""
function scalar_energies(ws::ScalarSimWS{T, N}, B_hat::SVector{3, T}) where {T, N}
    dV = prod(ws.grid.dx)

    # Kinetic energy: ⟨ψ| -∇²/2 |ψ⟩ via FFT
    @inbounds for I in eachindex(ws.psi)
        ws.psi_k[I] = ws.psi[I]
    end
    ws.fft_fwd * ws.psi_k
    n_total = scalar_norm(ws)
    n_pts_total = prod(ws.grid.config.n_points)
    E_kin = zero(T)
    @inbounds for I in CartesianIndices(ws.psi_k)
        E_kin += abs2(ws.psi_k[I]) * ws.grid.k_squared[I] / 2
    end
    # Parseval normalization for fft (no scaling): |ψ̂|² sum = N · |ψ|² sum
    E_kin = E_kin * dV / n_pts_total

    _update_density!(ws)
    compute_tilted_dipole_potential!(ws, B_hat)
    E_trap = zero(T);
    E_contact = zero(T);
    E_dd = zero(T);
    E_lhy = zero(T)
    g = ws.g_contact
    γ = ws.gamma_lhy
    @inbounds for I in eachindex(ws.psi)
        ρ = ws.rho[I]
        E_trap += ρ * ws.V_trap[I]
        E_contact += ρ * ρ * g / 2
        E_dd += ρ * ws.V_dd[I] / 2
        # E_LHY = (2/5)·γ·∫ρ^{5/2}: the functional whose δ/δψ̄ is the γ·ρ^{3/2}ψ
        # the diagonal propagator already applies. Omitting it (pre-2026-07-27)
        # left the reported energy inconsistent with the state ITP converges to,
        # so the total could rise along an imaginary-time trajectory.
        if γ != zero(T)
            E_lhy += (2 / 5) * γ * ρ * ρ * sqrt(ρ)
        end
    end
    E_trap *= dV;
    E_contact *= dV;
    E_dd *= dV;
    E_lhy *= dV
    (
        E_kin=E_kin, E_trap=E_trap, E_contact=E_contact, E_dd=E_dd, E_lhy=E_lhy,
        total=E_kin + E_trap + E_contact + E_dd + E_lhy,
    )
end

# --- Symmetry-breaking seeds ---
#
# ITP started from a uniform state stays uniform: the unmodulated solution is a
# stationary point, so a density wave never nucleates however unstable it is.
# A supersolid ground state has to be seeded.

"""
    seed_scalar_noise!(ws; amplitude, seed=nothing)

Multiply ψ by `1 + amplitude·ξ` with ξ uniform in [-1, 1) per voxel, then
renormalise. Broadband, so ITP selects the wavelength itself — use this when the
modulation period is the answer rather than an input.
"""
function seed_scalar_noise!(
    ws::ScalarSimWS{T, N}; amplitude::Real, seed::Union{Nothing, Integer}=nothing
) where {T, N}
    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    a = T(amplitude)
    @inbounds for I in eachindex(ws.psi)
        ws.psi[I] *= one(T) + a * (2 * rand(rng, T) - one(T))
    end
    normalize_scalar!(ws)
    nothing
end

"""
    seed_scalar_mode!(ws; k, amplitude, axis=1)

Multiply ψ by `1 + amplitude·cos(k·x_axis)`, then renormalise. Deterministic
single-wavelength seed: use it to test a specific period (e.g. the roton
wavelength) or to reproduce a published droplet count.
"""
function seed_scalar_mode!(
    ws::ScalarSimWS{T, N}; k::Real, amplitude::Real, axis::Int=1
) where {T, N}
    1 <= axis <= N || throw(ArgumentError("axis $axis outside 1:$N"))
    kk = T(k);
    a = T(amplitude)
    x = ws.grid.x[axis]
    @inbounds for I in CartesianIndices(ws.psi)
        ws.psi[I] *= one(T) + a * cos(kk * x[I[axis]])
    end
    normalize_scalar!(ws)
    nothing
end

"""z-component of orbital angular momentum L_z = -i ⟨ψ|x∂_y - y∂_x|ψ⟩.
3D only; uses spectral derivatives via existing FFT plans."""
function scalar_Lz(ws::ScalarSimWS{T, 3}) where {T}
    # ∂_y ψ via FFT
    n_pts = ws.grid.config.n_points
    kx = ws.grid.k[1];
    ky = ws.grid.k[2]
    @inbounds for I in eachindex(ws.psi)
        ws.psi_k[I] = ws.psi[I]
    end
    ws.fft_fwd * ws.psi_k
    # ∂_y → multiply by i k_y
    dpsi_dy = similar(ws.psi)
    @inbounds for I in CartesianIndices(n_pts)
        dpsi_dy[I] = ws.psi_k[I] * (im * ky[I[2]])
    end
    ws.fft_inv * dpsi_dy
    # ∂_x → multiply by i k_x (reuse ws.psi_k)
    dpsi_dx = similar(ws.psi)
    @inbounds for I in CartesianIndices(n_pts)
        dpsi_dx[I] = ws.psi_k[I] * (im * kx[I[1]])
    end
    ws.fft_inv * dpsi_dx

    Lz = zero(Complex{T})
    @inbounds for I in CartesianIndices(n_pts)
        x = ws.grid.x[1][I[1]];
        y = ws.grid.x[2][I[2]]
        # ψ* (x ∂_y - y ∂_x) ψ
        Lz += conj(ws.psi[I]) * (x * dpsi_dy[I] - y * dpsi_dx[I])
    end
    real(-im * Lz) * prod(ws.grid.dx)
end
