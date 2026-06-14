# --- Multi-frame TOF: 3-layer (R boost / Λ scaling / χ residual) × far-field ---
#
# Build 1 (skeleton): non-interacting Stern-Gerlach TOF where each spin
# component separates with a KNOWN ballistic trajectory, so the empty gaps
# between components are never represented. Each component lives in its own
# co-moving (R_m) + co-expanding (Λ_m) frame on a shared compact ξ-grid; the
# residual χ_m is FROZEN (free + uniform-force ⇒ no internal dynamics). All
# motion lives in the analytic frame parameters.
#
# Cost reframe: TOF is heavy from (a) multi-decade expansion and (b) the
# relative phase the separated components wind in k-space — NOT from the empty
# space itself. The affine (Castin-Dum) frame strips the analytically-known
# part; only the small, slow residual would need stepping (Build 2+).
#
# Sign convention matches SpatialZeemanTerm: a linear field bz(x)=G·x couples
# as H_diag = -bz(x)·m = -G·x·m, so the force on component m is a_m = +m·G.
#
# Refs: Castin-Dum PRL 77 5315; far-field arXiv:1401.7699/1701.06789.

export TOFFrame, MultiFrameTOFState, simulate_tof_multiframe
export boost_phase, frame_params, component_centroids, component_widths
export far_field_density, find_t_sep
export simulate_tof_multiframe_interacting
export recombine_field, recombine_density, simulate_bragg_tof
export simulate_rf_sg_tof

"""
Affine frame for one spin component: center of mass `R`, COM velocity `Rdot`,
per-axis scaling `Λ` and its rate `Λdot`, at frame time `t`. (ℏ = M = 1.)
"""
struct TOFFrame{N}
    m::Float64
    R::NTuple{N, Float64}
    Rdot::NTuple{N, Float64}
    Λ::NTuple{N, Float64}
    Λdot::NTuple{N, Float64}
    t::Float64
end

"""
Phase-B representation: per-component residuals `chis[i]` (spatial-only, on the
shared ξ-grid — no spin axis, since the skeleton is decoupled) plus their
affine `frames[i]`. `norm0` is the per-component reference norm (handoff
invariant).
"""
mutable struct MultiFrameTOFState{N}
    grid::Grid{N}
    sys::SpinSystem
    frames::Vector{TOFFrame{N}}
    chis::Vector{Array{ComplexF64, N}}
    t::Float64
    plans::FFTPlans
    norm0::Vector{Float64}
end

# ---------------------------------------------------------------------------
# Phase contract: the single source of truth for the Galilean boost phase.
# Subtracted at handoff (de-boost → centered/slow χ), re-added at read-out.
# Using ONE function for both directions guarantees the constant -½Ṙ·R cancels
# — the place that silently breaks interference fringes if it ever diverges.
# ---------------------------------------------------------------------------

@inline function boost_phase(frame::TOFFrame{N}, coords::NTuple{N, <:Real}) where {N}
    s = 0.0
    c = 0.0
    @inbounds for d in 1:N
        s += frame.Rdot[d] * coords[d]
        c += frame.Rdot[d] * frame.R[d]
    end
    s - 0.5 * c
end

# Multiply χ in place by exp(sign·i·boost_phase) over the grid. sign=-1 de-boost.
function _apply_boost!(chi::Array{ComplexF64, N}, frame::TOFFrame{N}, grid::Grid{N},
    sign::Float64) where {N}
    n_pts = grid.config.n_points
    xg = grid.x
    @inbounds for I in CartesianIndices(n_pts)
        coords = ntuple(d -> xg[d][I[d]], Val(N))
        chi[I] *= cis(sign * boost_phase(frame, coords))
    end
    nothing
end

# ---------------------------------------------------------------------------
# Layer R + Λ: analytic frame parameters
# ---------------------------------------------------------------------------

"""
    frame_params(m, omega; t, gradient, gradient_axis, R0, V0) -> TOFFrame

Affine parameters for component `m` at time `t`. Ballistic COM under the
Stern-Gerlach force `a_m = +m·gradient` along `gradient_axis` (bz(x)=gradient·x
convention, matching SpatialZeemanTerm), and Castin-Dum scaling
`Λ_d = √(1+ω_d² t²)` per axis. `omega` (per-axis trap frequency) is positional
so the static parameter `N` binds from it.
"""
function frame_params(m::Real, omega::NTuple{N, Float64}; t::Real,
    gradient::Real, gradient_axis::Int,
    R0::NTuple{N, Float64}=ntuple(_ -> 0.0, Val(N)),
    V0::NTuple{N, Float64}=ntuple(_ -> 0.0, Val(N))) where {N}
    tf = Float64(t)
    a = ntuple(d -> d == gradient_axis ? Float64(m) * Float64(gradient) : 0.0, Val(N))
    R = ntuple(d -> R0[d] + V0[d] * tf + 0.5 * a[d] * tf^2, Val(N))
    Rdot = ntuple(d -> V0[d] + a[d] * tf, Val(N))
    Λ = ntuple(d -> sqrt(1 + omega[d]^2 * tf^2), Val(N))
    Λdot = ntuple(d -> tf == 0.0 ? 0.0 : omega[d]^2 * tf / Λ[d], Val(N))
    TOFFrame{N}(Float64(m), R, Rdot, Λ, Λdot, tf)
end

# ---------------------------------------------------------------------------
# Setup: shared spinor → per-component frozen frames
# ---------------------------------------------------------------------------

"""
    simulate_tof_multiframe(psi0, grid, sys; gradient, gradient_axis, t, omega)
        -> MultiFrameTOFState

Skeleton TOF: split the initial spinor `psi0` into per-component residuals
(frozen) and assign each an analytic affine frame at time `t`. Empty gaps
between separated components are never represented. `omega` is the pre-release
trap frequency per axis (drives the Λ scaling). Components below 1e-14 of the
total norm are dropped.
"""
function simulate_tof_multiframe(psi0::AbstractArray{<:Complex}, grid::Grid{N},
    sys::SpinSystem; gradient::Real, gradient_axis::Int, t::Real,
    omega::NTuple{N, Float64}) where {N}
    n_pts = grid.config.n_points
    D = sys.n_components
    dV = cell_volume(grid)
    total = sum(abs2, psi0) * dV
    plans = make_fft_plans(n_pts)

    frames = TOFFrame{N}[]
    chis = Array{ComplexF64, N}[]
    norm0 = Float64[]
    for c in 1:D
        m = sys.m_values[c]
        chi = ComplexF64.(Array(view(psi0, _component_slice(N, n_pts, c)...)))
        nrm = sum(abs2, chi) * dV
        nrm < 1e-14 * max(total, eps()) && continue
        push!(frames, frame_params(m, omega; t=t, gradient=gradient,
            gradient_axis=gradient_axis))
        push!(chis, chi)
        push!(norm0, nrm)
    end
    MultiFrameTOFState{N}(grid, sys, frames, chis, Float64(t), plans, norm0)
end

# ---------------------------------------------------------------------------
# Per-component observables (the gap-free read-out the skeleton validates)
# ---------------------------------------------------------------------------

"""Physical center of mass per component = R_m(t) (the frame center)."""
component_centroids(state::MultiFrameTOFState) = [f.R for f in state.frames]

"""Physical RMS width per axis per component = Λ_m(t) · (frozen-χ width)."""
function component_widths(state::MultiFrameTOFState{N}) where {N}
    map(zip(state.frames, state.chis)) do (f, chi)
        mom = density_moments(reshape(chi, (size(chi)..., 1)), state.grid)
        ntuple(d -> f.Λ[d] * mom.widths[d], Val(N))
    end
end

# ---------------------------------------------------------------------------
# Far-field read-out (asymptotic shortcut: freeze χ, FFT, k→r=k·t)
# ---------------------------------------------------------------------------

"""
    far_field_density(state; imaging_axis=N) -> Dict{Float64,Array}

Far-field image per component: FFT the frozen residual (its internal momentum
spread maps to width via r=k·t) and place the centroid at R_m(t) by a pixel
roll. Exact in centroid; the width is the t→∞ asymptote of the Castin-Dum
width (use `component_widths` for the exact finite-t width). Returns
column-integrated density per m (full density for N=1). k-ordering is FFTW
(fftfreq); the centroid roll uses dr_d = dk_d·t.
"""
function far_field_density(state::MultiFrameTOFState{N}; imaging_axis::Int=N) where {N}
    grid = state.grid
    dV = cell_volume(grid)
    t = state.t
    # Physical far-field density n(r) = |χ̃_cont(k=r/t)|² / ((2π)^N t^N) with the
    # continuous FT χ̃_cont = (raw DFT)·dV; this satisfies ∫n d^N r = norm on the
    # r-grid (spacing dr_d = dk_d·t). r = ℏkt/M with ℏ=M=1.
    norm_ff = dV^2 / ((2π)^N * t^N)
    result = Dict{Float64, Array{Float64}}()
    for (f, chi) in zip(state.frames, state.chis)
        psik = state.plans.forward * copy(chi)
        dens = abs2.(psik) .* norm_ff
        for d in 1:N
            dr = grid.dk[d] * t
            sp = dr != 0.0 ? round(Int, f.R[d] / dr) : 0
            sp != 0 && (dens = _circshift_axis(dens, sp, d, Val(N)))
        end
        # Column-integrate the imaging axis (with its physical dr) for N ≥ 2.
        result[f.m] = if N == 1
            dens
        else
            dropdims(sum(dens; dims=imaging_axis); dims=imaging_axis) .*
            (grid.dk[imaging_axis] * t)
        end
    end
    result
end

# ---------------------------------------------------------------------------
# t_sep: when do components separate enough to split (skeleton: COM distance)
# ---------------------------------------------------------------------------

"""
    find_t_sep(grid, sys; gradient, gradient_axis, omega, sigma0, kappa=3.0,
               t_max=1e3) -> Float64

Smallest time at which every pair of components is separated along
`gradient_axis` by more than `kappa · max(width)` (skeleton COM-distance
criterion). `sigma0` is the initial RMS width along the axis. Returns `Inf`
(with a warning) when `gradient == 0` (no separation; degenerates to a single
co-expanding frame). Monotone in t ⇒ bisection.
"""
function find_t_sep(grid::Grid{N}, sys::SpinSystem; gradient::Real, gradient_axis::Int,
    omega::NTuple{N, Float64}, sigma0::Real, kappa::Real=3.0, t_max::Real=1e3) where {N}
    if gradient == 0
        @warn "find_t_sep: gradient == 0 ⇒ components never separate; returning Inf"
        return Inf
    end
    ms = sort(collect(Float64.(sys.m_values)))
    g = Float64(gradient)
    ax = gradient_axis
    ω = omega[ax]
    σ0 = Float64(sigma0)
    # minimum adjacent acceleration gap (slowest-separating pair sets t_sep)
    da = minimum(abs(g * (ms[i + 1] - ms[i])) for i in 1:(length(ms) - 1))
    da == 0.0 && return Inf
    separated(t) = 0.5 * da * t^2 > kappa * σ0 * sqrt(1 + ω^2 * t^2)
    separated(t_max) || return Float64(t_max)
    lo, hi = 0.0, Float64(t_max)
    for _ in 1:200
        mid = 0.5 * (lo + hi)
        separated(mid) ? (hi = mid) : (lo = mid)
    end
    hi
end

# ---------------------------------------------------------------------------
# Build 2a: interacting two-phase TOF (co-expanding Phase A)
#
# Phase A runs t=0→t_sep in the CO-EXPANDING frame (Castin-Dum Λ removes the
# breathing, so χ stays frozen-WIDTH — no chirp), evolving the full spinor under
# the residual harmonic + rescaled contact c0 + the m-dependent SG (bz(x)=G·x).
# Reuses `_scaling_kinetic_step!`; the potential half-step is inlined to carry
# the SpatialZeeman SG sign (V_m = -G·x·m ⇒ a_m = +m·G). At t_sep each component
# is de-boosted (ξ-momentum) + re-centered (ξ-COM) into a frozen residual. The
# COM trajectory is EXACT by Ehrenfest (linear force ⇒ R_m(t)=½ m G t²,
# interaction-independent); Λ(t)=√(1+ω²t²) is shared. χ frozen for t>t_sep
# (interactions negligible post-separation — dilute TOF). DDI in Phase A is a
# Build 2b follow-up (needs the scaling-frame dipolar kernel).
# ---------------------------------------------------------------------------

# Potential half-step in the co-expanding frame: residual harmonic + c0/∏Λ
# density + SG (V_m = -G·b·ξ·m). Mirrors tof.jl `_scaling_potential_halfstep!`
# but with the SpatialZeeman SG sign.
function _mf_pot_halfstep!(chi, grid::Grid{N}, b, bdd, c0::Float64,
    G::Float64, gaxis::Int, sys, dtf::Float64) where {N}
    n_pts = grid.config.n_points
    D = sys.n_components
    inv_pb = 1.0 / prod(b)
    harm = ntuple(d -> 0.5 * b[d] * bdd[d], Val(N))
    dens = c0 != 0.0 ? total_density(chi, N) : nothing
    xg = grid.x
    for c in 1:D
        m = Float64(sys.m_values[c])
        gco = -G * b[gaxis] * m
        cv = view(chi, _component_slice(N, n_pts, c)...)
        @inbounds for I in CartesianIndices(n_pts)
            v = 0.0
            for d in 1:N
                xd = xg[d][I[d]]
                v += harm[d] * xd * xd
            end
            dens !== nothing && (v += c0 * inv_pb * dens[I])
            v += gco * xg[gaxis][I[gaxis]]
            cv[I] *= cis(-dtf * v)
        end
    end
    nothing
end

# Rebuild the DDI Q-tensor IN PLACE at the rescaled momentum k_ξ/Λ (per axis).
# Q_αβ = k̂_α k̂_β − δ_αβ/3 is scale-free in |k|, so feeding rescaled axes gives
# Q(k_ξ/Λ) — the anisotropic-Λ kernel. For isotropic Λ this returns the same Q
# (k̂ invariant). Called each DDI substep since Λ(t) changes.
function _rebuild_ddi_q!(ddi::DDIParams{N}, grid::Grid{N}, Λ, secular::Bool) where {N}
    n_pts = grid.config.n_points
    rk_shape = rfft_output_shape(n_pts)
    T = eltype(ddi.Q_xx)
    kx = collect(T, rfftfreq(n_pts[1], n_pts[1] * grid.dk[1])) ./ T(Λ[1])
    ky = N >= 2 ? (T.(grid.k[2]) ./ T(Λ[2])) : T[]
    kz = N >= 3 ? (T.(grid.k[3]) ./ T(Λ[3])) : T[]
    k_sq = zeros(T, rk_shape)
    @inbounds for I in CartesianIndices(rk_shape)
        s = kx[I[1]]^2
        N >= 2 && (s += ky[I[2]]^2)
        N >= 3 && (s += kz[I[3]]^2)
        k_sq[I] = s
    end
    _build_q_tensor!(ddi.Q_xx, ddi.Q_xy, ddi.Q_xz, ddi.Q_yy, ddi.Q_yz, ddi.Q_zz,
        kx, ky, kz, k_sq, rk_shape; secular, full_n=n_pts)
    nothing
end

# ξ-space COM and FFT-centroid momentum of one component (for the handoff).
function _xi_com_momentum(chi::Array{ComplexF64, N}, grid::Grid{N}, plans) where {N}
    n_pts = grid.config.n_points
    dens = abs2.(chi)
    mass = sum(dens)
    R = ntuple(Val(N)) do d
        s = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            s += grid.x[d][I[d]] * dens[I]
        end
        s / mass
    end
    densk = abs2.(plans.forward * copy(chi))
    massk = sum(densk)
    p = ntuple(Val(N)) do d
        s = 0.0
        @inbounds for I in CartesianIndices(n_pts)
            s += grid.k[d][I[d]] * densk[I]
        end
        s / massk
    end
    (R, p)
end

"""
    simulate_tof_multiframe_interacting(psi0, grid, sys; c0, gradient,
        gradient_axis, omega, t_sep, t_f, n_steps_A) -> MultiFrameTOFState

Interacting (contact c0) Stern-Gerlach TOF. Phase A evolves the spinor in the
co-expanding frame to `t_sep` (so χ keeps frozen width — no chirp), then hands
off to per-component frozen residuals with the exact ballistic COM
`R_m(t)=½ m·gradient·t²` and shared Castin-Dum `Λ(t)=√(1+ω²t²)`. `t_sep` is the
overlap→separated handoff time (e.g. from `find_t_sep`); `t_f` the imaging time.
"""
function simulate_tof_multiframe_interacting(psi0::AbstractArray{<:Complex},
    grid::Grid{N}, sys::SpinSystem; c0::Real, gradient::Real, gradient_axis::Int,
    omega::NTuple{N, Float64}, t_sep::Real, t_f::Real, n_steps_A::Int,
    atom::Union{Nothing, AtomSpecies}=nothing, c_dd::Real=0.0,
    secular_ddi::Bool=false) where {N}
    n_steps_A > 0 || throw(ArgumentError("n_steps_A must be positive"))
    t_f >= t_sep || throw(ArgumentError("t_f must be ≥ t_sep"))
    n_pts = grid.config.n_points
    D = sys.n_components
    dV = cell_volume(grid)
    G = Float64(gradient)
    c0f = Float64(c0)

    # DDI in the co-expanding frame: E_dd = (1/∏Λ)·(c_dd/2)∫Q(k_ξ/Λ)M̃*M̃ dk_ξ.
    # The kernel Q is re-evaluated at the rescaled momentum k_ξ/Λ each substep
    # (`_rebuild_ddi_q!`) — exact for ANISOTROPIC Λ (isotropic is the special
    # case where Q is invariant); the 1/∏Λ density prefactor is applied as
    # dt/∏Λ on the audited apply_ddi_step! primitive.
    enable_ddi = c_dd != 0.0
    sm = spin_matrices(sys.F)
    ddi = nothing
    ddi_bufs = nothing
    if enable_ddi
        atom === nothing && throw(ArgumentError("DDI (c_dd≠0) requires `atom`"))
        ddi = make_ddi_params(grid, atom; c_dd=Float64(c_dd), secular=secular_ddi)
        ddi_bufs = make_ddi_buffers(n_pts)
    end

    plans = make_fft_plans(n_pts)
    fft_buf = zeros(ComplexF64, n_pts...)
    kphase = zeros(ComplexF64, n_pts...)
    chi_A = ComplexF64.(Array(psi0))
    dt = Float64(t_sep) / n_steps_A
    _b(t) = ntuple(d -> sqrt(1 + omega[d]^2 * t^2), Val(N))
    _bdd(b) = ntuple(d -> omega[d]^2 / b[d]^3, Val(N))
    # Co-expanding DDI half-step: rebuild Q(k_ξ/Λ) for the current Λ, then apply
    # with the 1/∏Λ prefactor folded into dt.
    function _ddi_half!(chi, b, dtf)
        enable_ddi || return nothing
        _rebuild_ddi_q!(ddi, grid, b, secular_ddi)
        apply_ddi_step!(chi, sm, ddi, ddi_bufs, dtf / prod(b), N)
        nothing
    end

    # --- Phase A: co-expanding evolution to t_sep (save state one step before
    # t_sep for the finite-difference COM velocity at handoff) ---
    t = 0.0
    chi_prev = copy(chi_A)
    t_prev = 0.0
    for step in 1:n_steps_A
        step == n_steps_A && (chi_prev=copy(chi_A); t_prev=t)
        b0 = _b(t)
        _mf_pot_halfstep!(chi_A, grid, b0, _bdd(b0), c0f, G, gradient_axis, sys, dt / 2)
        _ddi_half!(chi_A, b0, dt / 2)
        _scaling_kinetic_step!(chi_A, fft_buf, kphase, grid, _b(t + dt / 2), plans, D, dt)
        t += dt
        b1 = _b(t)
        _ddi_half!(chi_A, b1, dt / 2)
        _mf_pot_halfstep!(chi_A, grid, b1, _bdd(b1), c0f, G, gradient_axis, sys, dt / 2)
    end

    # --- Handoff at t_sep + frame advance to t_f ---
    b_sep = _b(Float64(t_sep))
    b_pprev = _b(t_prev)
    b_f = _b(Float64(t_f))
    bdot_f = ntuple(d -> omega[d]^2 * Float64(t_f) / b_f[d], Val(N))
    Δ = Float64(t_f) - Float64(t_sep)
    total = sum(abs2, chi_A) * dV
    frames = TOFFrame{N}[]
    chis = Array{ComplexF64, N}[]
    norm0 = Float64[]
    for c in 1:D
        m = Float64(sys.m_values[c])
        idx = _component_slice(N, n_pts, c)
        chi = ComplexF64.(Array(view(chi_A, idx...)))
        nrm = sum(abs2, chi) * dV
        nrm < 1e-12 * max(total, eps()) && continue
        ξR, ξp = _xi_com_momentum(chi, grid, plans)
        # Physical COM and (finite-difference) COM velocity at t_sep — captures
        # the inter-component mean-field repulsion kick that pure-SG Ehrenfest
        # misses. R_phys = b·ξ_COM; v_phys = d(b·ξ_COM)/dt.
        ξR_prev, _ = _xi_com_momentum(
            ComplexF64.(Array(view(chi_prev, idx...))), grid, plans)
        R_sep = ntuple(d -> b_sep[d] * ξR[d], Val(N))
        v_sep = ntuple(
            d -> (b_sep[d] * ξR[d] - b_pprev[d] * ξR_prev[d]) /
                 (Float64(t_sep) - t_prev), Val(N))
        # de-boost ξ-momentum, re-center ξ-COM → frozen residual
        fb = TOFFrame{N}(m, ξR, ξp, ntuple(_ -> 1.0, Val(N)), ntuple(_ -> 0.0, Val(N)),
            Float64(t_sep))
        _apply_boost!(chi, fb, grid, -1.0)
        for d in 1:N
            sp = round(Int, ξR[d] / grid.dx[d])
            sp != 0 && (chi = _circshift_axis(chi, -sp, d, Val(N)))
        end
        # Phase B: SG continues (½ a Δ²); v_sep carries pre-t_sep SG + repulsion.
        a = ntuple(d -> d == gradient_axis ? m * G : 0.0, Val(N))
        R = ntuple(d -> R_sep[d] + v_sep[d] * Δ + 0.5 * a[d] * Δ^2, Val(N))
        Rdot = ntuple(d -> v_sep[d] + a[d] * Δ, Val(N))
        push!(frames, TOFFrame{N}(m, R, Rdot, b_f, bdot_f, Float64(t_f)))
        push!(chis, chi)
        push!(norm0, nrm)
    end
    MultiFrameTOFState{N}(grid, sys, frames, chis, Float64(t_f), plans, norm0)
end

# ---------------------------------------------------------------------------
# Build 3 (①): coherent recombination → matter-wave / Bragg interference
#
# `far_field_density` places each |χ̃_m|² at R_m — INCOHERENT, valid only where
# the clouds are disjoint (SG-separated). When clouds OVERLAP (Bragg momentum
# orders of one spin state, or a zero-gradient release) the fringes come from
# the RELATIVE phase between frames. We rebuild the coherent lab field
#   ψ(x) = Σ_n (1/√∏Λ_n) χ_n((x−R_n)/Λ_n) · exp(i[φ_scal,n(x) + φ_boost,n(x)])
# the exact Castin-Dum × Galilean single-component solution, with
#   φ_scal,n(x) = Σ_d ½ (Λ̇/Λ)_{n,d} (x−R_n)_d²    (Castin-Dum expansion phase)
#   φ_boost,n(x) = `boost_phase(frame_n, x)`        (the single source of truth)
# `boost_phase` carries the −½Ṙ·R constant; using the SAME function for the
# de-boost (handoff) and the re-add (here) is what keeps the inter-frame phase
# difference — hence the fringe positions — physical.
#
# Internal-state orthogonality: frames of the SAME state (`frame.m`) interfere
# (Bragg orders); distinct spin states are orthogonal and add as |ψ|². So the
# physical image groups by m: coherent within, incoherent across (`recombine_
# density`). The de-boosted interacting-handoff residual therefore reconstructs
# faithfully in the DENSITY (magnitude drops the boost phase); only COHERENT
# interference between de-boosted SAME-m residuals would need the handoff frame
# re-added — a case the one-frame-per-m interacting path never produces.
# ---------------------------------------------------------------------------

# N-linear interpolation of χ (defined on `grid`) at ξ; 0 outside the box.
@inline function _interp_linear(chi::Array{ComplexF64, N}, grid::Grid{N},
    ξ::NTuple{N, Float64}) where {N}
    n_pts = grid.config.n_points
    r = ntuple(d -> (ξ[d] - grid.x[d][1]) / grid.dx[d], Val(N))
    lo = ntuple(d -> floor(Int, r[d]), Val(N))
    frac = ntuple(d -> r[d] - lo[d], Val(N))
    acc = zero(ComplexF64)
    @inbounds for c in 0:((1 << N) - 1)
        w = 1.0
        ok = true
        idx = ntuple(d -> lo[d] + 1 + ((c >> (d - 1)) & 1), Val(N))
        for d in 1:N
            b = (c >> (d - 1)) & 1
            w *= b == 1 ? frac[d] : (1.0 - frac[d])
            (idx[d] < 1 || idx[d] > n_pts[d]) && (ok = false)
        end
        ok && (acc += w * chi[CartesianIndex(idx)])
    end
    acc
end

# Accumulate (in place) the coherent lab field of a SUBSET of frames. Same
# internal state assumed — the caller groups by it. Each frame is the exact
# Castin-Dum × Galilean solution; the boost / scaling phase only matters where
# same-state frames overlap (the interference term).
function _accumulate_field!(field::Array{ComplexF64, N}, frames, chis,
    src_grid::Grid{N}, lab_grid::Grid{N}) where {N}
    xg = lab_grid.x
    for (f, chi) in zip(frames, chis)
        inv_sqrt_Λ = 1.0 / sqrt(prod(f.Λ))
        @inbounds for I in CartesianIndices(field)
            x = ntuple(d -> Float64(xg[d][I[d]]), Val(N))
            ξ = ntuple(d -> (x[d] - f.R[d]) / f.Λ[d], Val(N))
            amp = _interp_linear(chi, src_grid, ξ)
            amp == 0 && continue
            φ = 0.0
            for d in 1:N
                dxr = x[d] - f.R[d]
                φ += 0.5 * (f.Λdot[d] / f.Λ[d]) * dxr * dxr
            end
            φ += boost_phase(f, x)
            field[I] += inv_sqrt_Λ * amp * cis(φ)
        end
    end
    field
end

"""
    recombine_field(state; lab_grid=state.grid) -> Array{ComplexF64,N}

Coherent lab-frame complex field ψ(x) = Σ_n ψ_n(x) over ALL frames, each
reconstructed as the exact Castin-Dum × Galilean solution (scaling + boost phase
via `boost_phase`). Physical ONLY when every frame shares the same internal state
(e.g. Bragg momentum orders) — distinct spin components are orthogonal and must
NOT be added coherently; use `recombine_density` for the physical image, which
groups by internal state. χ is interpolated N-linearly onto `lab_grid` (the only
approximation). Assumes the skeleton / Bragg residual convention (χ NOT
de-boosted); for the interacting handoff only the magnitude is reconstructed
faithfully — see `recombine_density`.
"""
function recombine_field(state::MultiFrameTOFState{N};
    lab_grid::Grid{N}=state.grid) where {N}
    field = zeros(ComplexF64, lab_grid.config.n_points...)
    _accumulate_field!(field, state.frames, state.chis, state.grid, lab_grid)
end

"""
    recombine_density(state; lab_grid=state.grid) -> Array{Float64,N}

Physical lab-frame density: coherent WITHIN each internal state (frames sharing
`frame.m` interfere — the matter-wave / Bragg fringe term) and INCOHERENT across
distinct states (orthogonal spin components add as |ψ|², no spurious fringes):

    n(x) = Σ_m |Σ_{n: m_n=m} ψ_n(x)|².

For a single internal state (all `m` equal, e.g. Bragg orders) this is
`|Σ_n ψ_n|²`. For the multi-spin SG paths (skeleton / interacting, one frame per
m) it is `Σ_m |ψ_m|²` — and since `|ψ_m|²` is independent of the boost / scaling
phase, the de-boosted interacting-handoff residual reconstructs faithfully (only
R_m and Λ_m enter the magnitude).
"""
function recombine_density(state::MultiFrameTOFState{N};
    lab_grid::Grid{N}=state.grid) where {N}
    dens = zeros(Float64, lab_grid.config.n_points...)
    field = zeros(ComplexF64, lab_grid.config.n_points...)
    for mval in unique(f.m for f in state.frames)
        idxs = findall(f -> f.m == mval, state.frames)
        fill!(field, 0)
        _accumulate_field!(field, view(state.frames, idxs),
            view(state.chis, idxs), state.grid, lab_grid)
        dens .+= abs2.(field)
    end
    dens
end

"""
    simulate_bragg_tof(envelope, grid, sys; orders, omega, t,
        m=0.0, gradient=0.0, gradient_axis=1) -> MultiFrameTOFState

Bragg / matter-wave TOF: one spin state (`m`) split into momentum `orders`
(each `(k=Δv-tuple, amp=complex)`) that co-expand from a shared `envelope` and
interfere on recombination. A Bragg order is just an affine frame with initial
velocity `V0 = k` (no SG by default), so it falls out of `frame_params`; the
fringes appear in `recombine_density`. `omega` is the pre-release trap frequency
(drives Λ). For ±v symmetric orders the overlap-center fringe wavevector is
`2v/Λ²` with `Λ=√(1+ω²t²)`.
"""
function simulate_bragg_tof(envelope::AbstractArray{<:Complex}, grid::Grid{N},
    sys::SpinSystem; orders, omega::NTuple{N, Float64}, t::Real,
    m::Real=0.0, gradient::Real=0.0, gradient_axis::Int=1) where {N}
    isempty(orders) && throw(ArgumentError("orders must be non-empty"))
    plans = make_fft_plans(grid.config.n_points)
    dV = cell_volume(grid)
    env = ComplexF64.(Array(envelope))
    frames = TOFFrame{N}[]
    chis = Array{ComplexF64, N}[]
    norm0 = Float64[]
    for ord in orders
        k = ntuple(d -> Float64(ord.k[d]), Val(N))
        amp = ComplexF64(ord.amp)
        f = frame_params(m, omega; t=t, gradient=gradient,
            gradient_axis=gradient_axis, V0=k)
        chi = amp .* env
        push!(frames, f)
        push!(chis, chi)
        push!(norm0, sum(abs2, chi) * dV)
    end
    MultiFrameTOFState{N}(grid, sys, frames, chis, Float64(t), plans, norm0)
end

"""
    simulate_rf_sg_tof(psi0, grid, sys; theta, phi=0.0, gradient,
        gradient_axis, t, omega) -> MultiFrameTOFState

RF + Stern-Gerlach TOF: a hard RF pulse (area `theta`, in-plane axis at azimuth
`phi`) rotates the spin BEFORE the SG-TOF, so the per-component populations
encode the spin projection along the rotated axis (the tomography knob). The
pulse precedes release, so it composes with the skeleton multi-frame path
(`apply_rf_pulse` then `simulate_tof_multiframe`). Scan `(theta, phi)` and read
the per-m populations to reconstruct the spin density (see `rf_tomography`).
"""
function simulate_rf_sg_tof(psi0::AbstractArray{<:Complex}, grid::Grid{N},
    sys::SpinSystem; theta::Real, phi::Real=0.0, gradient::Real, gradient_axis::Int,
    t::Real, omega::NTuple{N, Float64}) where {N}
    psi_rot = apply_rf_pulse(psi0, sys.F; theta=theta, phi=phi)
    simulate_tof_multiframe(psi_rot, grid, sys; gradient=gradient,
        gradient_axis=gradient_axis, t=t, omega=omega)
end
