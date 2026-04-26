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
            integrated = dropdims(sum(mom_density; dims=ax); dims=ax)
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

    ip_tof = drop_interactions ? InteractionParams(0.0, 0.0) :
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
            ax = imaging_axis
            integrated = dropdims(sum(density_c; dims=ax); dims=ax)
            result[m] = integrated
        end
    end
    result
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
