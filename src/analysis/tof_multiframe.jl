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
    da = minimum(abs(g * (ms[i+1] - ms[i])) for i in 1:(length(ms)-1))
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
