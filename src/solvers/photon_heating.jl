# --- P4.6: Photon-scattering heating ---

export apply_photon_scattering!, photon_scattering_callback

# Phase-diffusion noise model: spontaneous photon scattering during imaging
# or during red-detuned trap illumination adds random phase kicks to each
# grid point. Equivalent to the low-temperature / thermal-free limit of
# SGPE (P4.3) with white noise amplitude set by the scattering rate Γ_sc.
#
# Strategy: after each split_step, add
#   ψ(r) → ψ(r) · exp(i · δθ(r)),  δθ ~ N(0, σ²)
# with σ² = Γ_sc · dt.  Preserves norm + density, randomises phase.

using Random

"""
    apply_photon_scattering!(ws, Γ_sc, dt; seed=nothing) -> Nothing

Add one time-step of phase-diffusion noise corresponding to a photon
scattering rate `Γ_sc` (dimensionless, units of ω_ref). The typical use is
as an `on_step` callback during `run_simulation!` / dynamics.

`Γ_sc · dt` is the variance of the per-grid-point phase kick. Keep
`Γ_sc · dt ≪ 1` for the diffusion approximation to hold.
"""
function apply_photon_scattering!(
    ws::Workspace{N}, Γ_sc::Real, dt::Real;
    seed::Union{Nothing, Int}=nothing,
) where {N}
    σ = sqrt(Float64(Γ_sc) * Float64(dt))
    σ <= 0 && return nothing
    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points

    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    # Build a single CPU array of random phases and transfer once.
    # NOTE: for GPU workspaces this pushes the random phases device-side
    # via a single copy, which is fine at 64³ (<1 ms). For very large
    # grids, a GPU-native generator (CUDA.rand!) would be faster but
    # requires the CUDA extension.
    phase_host = randn(rng, Float64, n_pts) .* σ
    phase_dev = _to_device(ws.backend, phase_host)

    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        @. psi_c = psi_c * cis(phase_dev)
    end
    nothing
end

"""
    photon_scattering_callback(Γ_sc, dt; seed=nothing) -> Function

`on_step` callback that applies phase-diffusion noise after every step.
"""
function photon_scattering_callback(Γ_sc::Real, dt::Real;
    seed::Union{Nothing, Int}=nothing)
    # Accept SimulationCallbacks 4-arg `(ws, step, times, energies)` as well
    # as the older 3-arg `(ws, step, n_steps)` direct-callable convention.
    function (ws, step, args...)
        apply_photon_scattering!(ws, Γ_sc, dt;
            seed=seed === nothing ? nothing : seed + step)
        nothing
    end
end
