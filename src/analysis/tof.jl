export simulate_tof, simulate_tof_with_gradient, sg_separation_peaks
export simulate_tof_scaling
export momentum_distribution

"""
    simulate_tof(psi, grid, sys, params; fft_plans=nothing) → Dict{Int, Array}

Simulate time-of-flight + Stern-Gerlach imaging.

Far-field approximation: momentum distribution |ψ̃_m(k)|² shifted by SG displacement
d_m = m × gradient × t_tof² / 2 along the imaging axis.
Column-integrated along `imaging_axis`.

Returns `Dict(m => density_2d)` for each m component.
For 1D grids, returns `Dict(m => density_1d)` (no column integration needed).
"""
function simulate_tof(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sys::SpinSystem,
    params::TOFParams;
    fft_plans::Union{Nothing, FFTPlans}=nothing,
) where {N}
    D = sys.n_components
    n_pts = grid.config.n_points
    plans = fft_plans !== nothing ? fft_plans : make_fft_plans(n_pts)

    # k-space grid for far-field: position = ℏk × t_tof / m (ℏ=m=1)
    # so final position grid ∝ k-grid × t_tof
    k_dx = ntuple(d -> grid.dk[d] * params.t_tof, Val(N))

    result = Dict{Int, Array{Float64}}()

    for c in 1:D
        m = sys.m_values[c]
        idx = _component_slice(N, n_pts, c)
        psi_c = copy(view(psi, idx...))

        # FFT to get momentum-space wavefunction
        psi_k = plans.forward * psi_c
        # Normalize: |ψ̃(k)|² dk = |ψ(x)|² dx
        dV = cell_volume(grid)
        nk = length(psi_k)
        psi_k .*= (dV / sqrt(Float64(nk)))

        mom_density = abs2.(psi_k)

        if N == 1
            result[m] = mom_density
        else
            # SG shift: displacement along imaging_axis in k-space pixels
            sg_shift = m * params.gradient * params.t_tof^2 / 2
            shift_pixels = if params.gradient != 0.0
                ax = params.imaging_axis
                ax <= N || throw(ArgumentError("imaging_axis=$ax > ndim=$N"))
                round(Int, sg_shift / (grid.dk[ax] * params.t_tof + eps(Float64)))
            else
                0
            end

            # Apply SG shift by rolling along imaging axis
            if shift_pixels != 0
                ax = params.imaging_axis
                mom_density = _circshift_axis(mom_density, shift_pixels, ax, Val(N))
            end

            # Column integrate along imaging_axis
            ax = min(params.imaging_axis, N)
            integrated = _integrate_out_axis(mom_density, ax)
            result[m] = integrated
        end
    end

    result
end

function _circshift_axis(
    arr::AbstractArray{T, N},
    shift::Int,
    axis::Int,
    ::Val{N},
) where {T, N}
    shifts = ntuple(d -> d == axis ? shift : 0, Val(N))
    circshift(arr, shifts)
end

# --- P2.9: real-time Stern-Gerlach + TOF ---
#
# The `simulate_tof` above is far-field (single FFT + k-shift), fine for
# pedagogical imaging but misses finite-time TOF diffraction and the cross
# effect of transverse spin textures on longitudinal spreading.
#
# `simulate_tof_with_gradient` integrates the Gross-Pitaevskii equation during
# free expansion: drops the trap + interactions, keeps kinetic, and adds a
# magnetic gradient whose per-component linear potential separates the m
# channels in real space (Stern-Gerlach). Returns the column density per
# component at the final time. This path is correct for short TOF where the
# cloud is still within the grid box.

"""
    simulate_tof_with_gradient(ws_source; gradient, t_tof, imaging_axis=3,
                               n_steps=200, gradient_axis=3, keep_trap=false,
                               drop_interactions=true) -> Dict{Int, Array}

Real-time TOF propagator with a magnetic-gradient-driven Stern-Gerlach
separation. Takes the wavefunction from `ws_source` (a `Workspace`), clones
it into a temporary TOF workspace with the trap disabled (default) and the
contact interactions zeroed (default), then adds a linear gradient potential
`V_m(r) = m · g_F · gradient · r[axis]` per spin component via the existing
`MagneticGradient` struct, and integrates for `t_tof` using `n_steps`
split-step ticks.

Returns a `Dict(m => density_2d)` column-integrated along `imaging_axis`
(or `density_1d` for N=1).

Arguments:
- `ws_source`: the trapped BEC workspace to image.
- `gradient::Float64`: magnetic field gradient in dimensionless units.
- `t_tof::Float64`: total time of flight (dimensionless `ω_ref⁻¹`).
- `imaging_axis::Int`: the axis to column-integrate over (defaults to N).
- `gradient_axis::Int`: the axis the gradient pushes along. Must differ
  from the imaging axis for spin separation to be visible.
- `n_steps::Int`: number of split-step iterations during TOF.
- `keep_trap::Bool`: retain the source trap potential (rarely wanted —
  default `false` removes the trap before expansion).
- `drop_interactions::Bool`: zero out c0/c1/c_lhy/tensor during TOF
  (default `true`; physical for dilute clouds).
"""
function simulate_tof_with_gradient(
    ws_source::Workspace{N};
    gradient::Float64,
    t_tof::Float64,
    imaging_axis::Int=N,
    gradient_axis::Int=N,
    n_steps::Int=200,
    keep_trap::Bool=false,
    drop_interactions::Bool=true,
) where {N}
    t_tof >= 0 || throw(ArgumentError("t_tof must be non-negative"))
    n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
    1 <= gradient_axis <= N || throw(ArgumentError(
        "gradient_axis=$gradient_axis outside 1..$N"))
    1 <= imaging_axis <= N || throw(ArgumentError(
        "imaging_axis=$imaging_axis outside 1..$N"))

    grid = ws_source.grid
    atom = ws_source.atom
    D = ws_source.spin_matrices.system.n_components

    ip_tof = drop_interactions ? InteractionParams(Dict{Int, Float64}()) :
             ws_source.interactions
    potential_tof = keep_trap ? ws_source.potential : NoPotential()

    dt_tof = t_tof / n_steps
    sp_tof = SimParams(; dt=dt_tof, n_steps, imaginary_time=false,
        normalize_every=0,
        save_every=max(1, n_steps ÷ 4))

    # Use existing MagneticGradient — the hot-path split_step already
    # integrates V_mg(r, m) = m · g_F · gradient · r[axis] per component.
    mg = MagneticGradient{N}(gradient, gradient_axis, atom.g_F)

    ws_tof = make_workspace(;
        grid,
        atom,
        interactions=ip_tof,
        zeeman=ZeemanParams(),          # no Zeeman during TOF
        potential=potential_tof,
        sim_params=sp_tof,
        psi_init=ws_source.state.psi,
        backend=ws_source.backend,
        magnetic_gradient=mg,
    )

    for _ in 1:n_steps
        split_step!(ws_tof)
    end

    # Extract per-component column density
    psi = ws_tof.state.psi
    n_pts = grid.config.n_points
    result = Dict{Int, Array{Float64}}()
    for c in 1:D
        m = ws_source.spin_matrices.system.m_values[c]
        idx = _component_slice(N, n_pts, c)
        slice_arr = view(psi, idx...)
        density_c = Array(abs2.(slice_arr))  # host copy — analyzer output
        if N == 1
            result[m] = density_c
        else
            integrated = _integrate_out_axis(density_c, imaging_axis)
            result[m] = integrated
        end
    end
    result
end

# --- Co-expanding (scaling-coordinate) frame TOF ---
#
# `simulate_tof_with_gradient` evolves free expansion on the FIXED grid, so
# a long TOF blows the cloud past the box and demands a huge grid. The
# scaling transform (Castin-Dum 1996, PRL 77 5315) keeps the grid compact:
# work in rescaled coordinates ξ_d = x_d / b_d(t) with the ballistic factor
# b_d(t) = √(1 + ω_d² t²) carrying the mean expansion, while the rescaled
# wavefunction χ(ξ,t) stays compact and carries ALL the residual physics —
# interference, interaction-driven anisotropy, Stern-Gerlach bending.
#
# With ℏ = m = 1 and the trap released at t=0, χ obeys (per axis d):
#   i ∂_t χ = Σ_d [ -1/(2 b_d²) ∂²_{ξ_d} + ½ b_d b̈_d ξ_d² ] χ
#             + (c₀ / Π_d b_d) |χ|² χ + V_SG(b·ξ) χ
# where b̈_d = ω_d² / b_d³ for the ballistic law. The residual harmonic term
# ½ b_d b̈_d ξ_d² is what keeps χ stationary for a non-interacting ground
# state (then the physical width is exactly b_d(t)·σ_d(0)) — that closed
# form is the validation oracle.

"""
    simulate_tof_scaling(ws_source; t_tof, omega=nothing, n_steps=200,
                         drop_interactions=true, gradient=0.0,
                         gradient_axis=N, imaging_axis=N) -> NamedTuple

Co-expanding (scaling-coordinate) frame time-of-flight. Evolves the
rescaled wavefunction χ on the source grid (now interpreted as the ξ = x/b
grid) so the cloud stays compact for arbitrarily long `t_tof`; the physical
state is `ψ(x) = (Π_d b_d)^{-1/2} χ(x/b)` with `b_d(t) = √(1+ω_d² t²)`.

`omega` is the pre-release trap frequency per axis (the scaling driver); if
omitted it is read from a `HarmonicTrap` source potential. With
`drop_interactions=false` the contact `c₀` term is carried with its
`1/Π b_d` density rescaling (higher spinor channels are not yet transported
through the frame and raise a `@warn`). A linear Stern-Gerlach `gradient`
along `gradient_axis` is evaluated at the physical position `b·ξ`.

Returns `(b, omega, chi_density, moments, widths_physical, norm_drift)`:
- `b`               — final scaling factors `b_d(t_tof)`.
- `chi_density`     — `Dict(m => column density of χ)` (the ξ-frame shape).
- `moments`         — `density_moments(χ)` in the ξ-frame; multiply
                      `widths`/`com` by `b` to get physical lengths.
- `widths_physical` — `b .* moments.widths` (physical per-axis RMS widths).
- `norm_drift`      — `|‖χ‖² − ‖ψ_in‖²|` (frame conserves norm).
"""
function simulate_tof_scaling(
    ws_source::Workspace{N};
    t_tof::Float64,
    omega::Union{Nothing, NTuple{N, Float64}}=nothing,
    n_steps::Int=200,
    drop_interactions::Bool=true,
    gradient::Float64=0.0,
    gradient_axis::Int=N,
    imaging_axis::Int=N,
) where {N}
    t_tof >= 0 || throw(ArgumentError("t_tof must be non-negative"))
    n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
    1 <= gradient_axis <= N || throw(ArgumentError("gradient_axis outside 1..$N"))
    1 <= imaging_axis <= N || throw(ArgumentError("imaging_axis outside 1..$N"))

    grid = ws_source.grid
    atom = ws_source.atom
    sys = ws_source.spin_matrices.system
    D = sys.n_components
    n_pts = grid.config.n_points

    om = if omega !== nothing
        all(>(0), omega) || throw(ArgumentError("omega entries must be positive"))
        omega
    elseif ws_source.potential isa HarmonicTrap
        ws_source.potential.omega
    else
        throw(
            ArgumentError(
                "simulate_tof_scaling needs the pre-release trap frequencies; pass " *
                "`omega=(ω₁,…,ω_N)` or release from a HarmonicTrap source potential."),
        )
    end

    c0 = 0.0
    if !drop_interactions
        c0 = ws_source.interactions[0]
        if abs(ws_source.interactions[1]) > 0 || ws_source.ddi !== nothing
            @warn "simulate_tof_scaling carries only the c₀ contact term through the \
                   scaling frame; c₁ / DDI / tensor channels are dropped during TOF."
        end
    end

    chi = ComplexF64.(Array(ws_source.state.psi))   # χ on the ξ grid; χ(0)=ψ_in
    norm0 = sum(abs2, chi) * cell_volume(grid)
    plans = make_fft_plans(n_pts)
    fft_buf = zeros(ComplexF64, n_pts...)
    kphase = zeros(ComplexF64, n_pts...)
    dt = t_tof / n_steps

    _b(t) = ntuple(d -> sqrt(1 + om[d]^2 * t^2), Val(N))
    _bdd(b) = ntuple(d -> om[d]^2 / b[d]^3, Val(N))   # b̈_d for the ballistic law

    t = 0.0
    for _ in 1:n_steps
        b0 = _b(t)
        _scaling_potential_halfstep!(chi, grid, b0, _bdd(b0), c0,
            gradient, gradient_axis, atom.g_F, sys, dt / 2)
        _scaling_kinetic_step!(chi, fft_buf, kphase, grid, _b(t + dt / 2), plans, D, dt)
        t += dt
        b1 = _b(t)
        _scaling_potential_halfstep!(chi, grid, b1, _bdd(b1), c0,
            gradient, gradient_axis, atom.g_F, sys, dt / 2)
    end

    b_final = _b(t_tof)
    moments = density_moments(chi, grid)
    widths_physical = ntuple(d -> b_final[d] * moments.widths[d], Val(N))

    chi_density = Dict{Int, Array{Float64}}()
    for c in 1:D
        m = sys.m_values[c]
        dens = Array(abs2.(view(chi, _component_slice(N, n_pts, c)...)))
        chi_density[Int(m)] = N == 1 ? dens : _integrate_out_axis(dens, imaging_axis)
    end

    norm_drift = abs(sum(abs2, chi) * cell_volume(grid) - norm0)
    (
        b=b_final,
        omega=om,
        chi_density=chi_density,
        moments=moments,
        widths_physical=widths_physical,
        norm_drift=norm_drift,
    )
end

function _scaling_potential_halfstep!(
    chi, grid::Grid{N}, b, bdd, c0::Float64,
    gradient::Float64, gaxis::Int, gF::Float64, sys, dtf::Float64,
) where {N}
    n_pts = grid.config.n_points
    D = sys.n_components
    inv_pb = 1.0 / prod(b)
    harm = ntuple(d -> 0.5 * b[d] * bdd[d], Val(N))
    dens = c0 != 0.0 ? total_density(chi, N) : nothing
    xg = grid.x
    for c in 1:D
        m = sys.m_values[c]
        gcoef = m * gF * gradient * b[gaxis]
        cv = view(chi, _component_slice(N, n_pts, c)...)
        @inbounds for I in CartesianIndices(n_pts)
            v = 0.0
            for d in 1:N
                xd = xg[d][I[d]]
                v += harm[d] * xd * xd
            end
            dens !== nothing && (v += c0 * inv_pb * dens[I])
            gcoef != 0.0 && (v += gcoef * xg[gaxis][I[gaxis]])
            cv[I] *= cis(-dtf * v)
        end
    end
    nothing
end

function _scaling_kinetic_step!(
    chi, fft_buf, kphase, grid::Grid{N}, b, plans, D::Int, dt::Float64
) where {N}
    n_pts = grid.config.n_points
    inv_b2 = ntuple(d -> 1.0 / b[d]^2, Val(N))
    kg = grid.k
    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for d in 1:N
            kd = kg[d][I[d]]
            s += kd * kd * inv_b2[d]
        end
        kphase[I] = cis(-0.5 * dt * s)
    end
    for c in 1:D
        cv = view(chi, _component_slice(N, n_pts, c)...)
        fft_buf .= cv
        plans.forward * fft_buf
        fft_buf .*= kphase
        plans.inverse * fft_buf
        cv .= fft_buf
    end
    nothing
end

"""
    sg_separation_peaks(result::Dict{Int,<:AbstractArray}, grid, imaging_axis)
        -> Dict{Int,NTuple{2,Float64}}

Helper for post-processing `simulate_tof_with_gradient` output: locate the
centre of each spin component's column density (argmax → physical
coordinate) along the non-imaging axes. Returns `Dict(m => (center_x,
center_y))` (or `(center_x,)` for 2D result collapsed from 3D along the
last axis).
"""
function sg_separation_peaks(
    result::Dict{<:Integer, <:AbstractArray},
    grid::Grid{N},
    imaging_axis::Int=N,
) where {N}
    out = Dict{Int, NTuple{N-1, Float64}}()
    # Remaining axes after dropping imaging_axis
    remaining = Int[d for d in 1:N if d != imaging_axis]
    for (m, dens) in result
        # argmax returns CartesianIndex over the collapsed array (size N-1)
        idx = argmax(dens)
        t = Tuple(idx)
        centers = ntuple(i -> grid.x[remaining[i]][t[i]], Val(N-1))
        out[Int(m)] = centers
    end
    out
end
