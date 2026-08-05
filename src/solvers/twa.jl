export run_twa

"""
    run_twa(; psi_gs, grid, atom, interactions, zeeman, potential, sim_params,
             twa_config, enable_ddi=false, c_dd=NaN, backend=CPUBackend(),
             store_trajectories=false, verbose=true, kwargs...) → EnsembleResult

Run a Truncated Wigner Approximation ensemble.

Each trajectory: copy psi_gs → add Wigner vacuum noise → make_workspace → run_simulation! →
extract observables. Mean and variance are computed via Welford's online algorithm.

Uses `pmap` when `nprocs() > 1`, otherwise `map`.
"""
function run_twa(;
    psi_gs::AbstractArray{<:Complex},
    grid::Grid{N},
    atom::AtomSpecies,
    interactions::InteractionParams,
    zeeman::Union{ZeemanParams, TimeDependentZeeman}=ZeemanParams(),
    potential::AbstractPotential=NoPotential(),
    sim_params::SimParams,
    twa_config::TWAConfig,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    backend::AbstractBackend=CPUBackend(),
    store_trajectories::Bool=false,
    verbose::Bool=_default_solver_verbose(),
    kwargs...,
) where {N}
    n_traj = twa_config.n_trajectories
    obs_list = twa_config.observables
    F = atom.F

    all_traj_results = store_trajectories ? Vector{SimulationResult}(undef, n_traj) : nothing

    # Welford accumulators: nothing until first trajectory
    mean_obs = nothing
    M2_obs = nothing
    ref_times = nothing
    last_traj_result = nothing
    # Contributing samples and the members refused. Separate counters because
    # `n_traj` is what was ASKED for and the statistics are over what arrived.
    n_used = 0
    rejected = Int[]

    for i in 1:n_traj
        t_start = time_ns()

        psi_noisy = add_vacuum_noise(psi_gs, grid, F;
            seed=(twa_config.seed_base + i),
            cutoff_energy=twa_config.cutoff_energy)

        ws = make_workspace(;
            grid, atom, interactions, zeeman, potential, sim_params,
            psi_init=psi_noisy, enable_ddi, c_dd, backend, kwargs...)

        result = run_simulation!(ws)

        if store_trajectories
            all_traj_results[i] = result
        end

        # Capture the last trajectory's full SimulationResult — pipeline
        # auto-save uses it to stream the Phase-2 frames that
        # `run_simulation!` already accumulated into the canonical
        # result.jld2 layout. The post-evolution ψ is recovered downstream
        # via `last_trajectory.psi_snapshots[end]`.
        i == n_traj && (last_traj_result = result)

        traj_obs = _extract_trajectory_observables(result, grid, atom, obs_list)

        # REFUSE a diverged member instead of folding it in. `_welford_update!`
        # is cumulative and in place — `mean[I] += delta / i` — so a single NaN
        # anywhere in a trajectory's observables destroys the mean and the
        # variance for that observable for EVERY member after it, and there is
        # no recovery and no record. Until 2026-08-04 `grep isfinite
        # src/solvers/twa.jl` returned nothing: one diverging trajectory in a
        # 200-member ensemble returned an all-NaN answer with n_trajectories
        # still reading 200. 33 configs under `runs/` use `twa:`.
        #
        # Checked at the OBSERVABLE, not at psi: an ensemble is a statement
        # about its observables, a trajectory may be finite in psi and produce a
        # non-finite observable, and this is also the cheap place to look.
        if !_all_finite(traj_obs)
            push!(rejected, i)
            verbose && @warn "TWA: trajectory $i produced a non-finite observable; \
                              excluded from the ensemble" trajectory = i
            continue
        end
        n_used += 1

        if ref_times === nothing
            ref_times = result.times
            mean_obs = Dict{Symbol, Vector{Array{Float64}}}()
            M2_obs = Dict{Symbol, Vector{Array{Float64}}}()
            for sym in keys(traj_obs)
                mean_obs[sym] = [copy(arr) for arr in traj_obs[sym]]
                M2_obs[sym] = [zeros(size(arr)) for arr in traj_obs[sym]]
            end
        else
            for sym in keys(traj_obs)
                for t_idx in eachindex(traj_obs[sym])
                    # `n_used`, not `i`: Welford's 1/i weighting counts
                    # CONTRIBUTING samples. Passing the loop index would give a
                    # rejected member's slot a share of the weight.
                    _welford_update!(mean_obs[sym][t_idx], M2_obs[sym][t_idx],
                        traj_obs[sym][t_idx], n_used)
                end
            end
        end

        elapsed = elapsed_s(t_start)
        if verbose
            avg_time = elapsed
            @printf("  Trajectory %d/%d done (%.1fs)\n", i, n_traj, avg_time)
            flush(stdout)
        end
    end

    # Finalize variance. `n_used`, not `n_traj`: dividing M2 by the number of
    # trajectories REQUESTED rather than the number that contributed inflates
    # the sample count and biases the variance low — a second, quieter error
    # than the NaN, and one that would survive the fix above on its own.
    var_obs = Dict{Symbol, Vector{Array{Float64}}}()
    for sym in keys(M2_obs)
        var_obs[sym] = if n_used > 1
            [m2 ./ (n_used - 1) for m2 in M2_obs[sym]]
        else
            [zeros(size(m2)) for m2 in M2_obs[sym]]
        end
    end

    isempty(rejected) ||
        @warn "TWA ensemble: $(length(rejected)) of $n_traj trajectories were \
               excluded for producing non-finite observables; mean and variance \
               are over $n_used samples" rejected = rejected

    EnsembleResult(ref_times, mean_obs, var_obs, n_used, rejected,
        all_traj_results, last_traj_result)
end

"""
    _all_finite(traj_obs) -> Bool

Every value of every observable at every snapshot is finite.

Guards `_welford_update!`, which is cumulative and in place, so one non-finite
entry propagates to every later member with no recovery and no record.
Short-circuits on the first offender — the common case is all-finite and pays
one pass.
"""
function _all_finite(traj_obs)
    for (_, series) in traj_obs, arr in series
        all(isfinite, arr) || return false
    end
    true
end

"""
Welford online update: incorporate sample x_new (the i-th sample, 1-indexed).
Updates mean and M2 (sum of squared deviations) in place.
"""
function _welford_update!(mean::Array{Float64}, M2::Array{Float64},
    x_new::Array{Float64}, i::Int)
    @inbounds for I in eachindex(mean)
        delta = x_new[I] - mean[I]
        mean[I] += delta / i
        delta2 = x_new[I] - mean[I]
        M2[I] += delta * delta2
    end
end

"""
Extract observables from a SimulationResult at each snapshot time.
Returns Dict{Symbol, Vector{Array{Float64}}}.
"""
function _extract_trajectory_observables(
    result::SimulationResult,
    grid::Grid{N},
    atom::AtomSpecies,
    obs_list::Vector{Symbol},
) where {N}
    F = atom.F
    sm = spin_matrices(F)
    sys = sm.system

    out = Dict{Symbol, Vector{Array{Float64}}}()
    for sym in obs_list
        out[sym] = Array{Float64}[]
    end

    for psi in result.psi_snapshots
        for sym in obs_list
            push!(out[sym], _compute_observable(psi, grid, sm, sys, F, N, sym))
        end
    end

    out
end

function _compute_observable(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sm::SpinMatrices,
    sys::SpinSystem,
    F::Int,
    ndim::Int,
    sym::Symbol,
) where {N}
    if sym === :density
        Float64.(total_density(psi, ndim))
    elseif sym === :magnetization
        dV = cell_volume(grid)
        Mz = 0.0
        n_pts = ntuple(d -> size(psi, d), ndim)
        for (c, m) in enumerate(sys.m_values)
            idx = _component_slice(ndim, n_pts, c)
            Mz += m * sum(abs2, view(psi, idx...)) * dV
        end
        Float64[Mz]
    elseif sym === :spin_density
        fx, fy, fz = spin_density_vector(psi, sm, ndim)
        sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    elseif sym === :component_density
        D = 2F + 1
        n_pts = ntuple(d -> size(psi, d), ndim)
        arr = zeros(Float64, n_pts..., D)
        for c in 1:D
            idx_src = _component_slice(ndim, n_pts, c)
            idx_dst = _component_slice(ndim, n_pts, c)
            view(arr, idx_dst...) .= abs2.(view(psi, idx_src...))
        end
        arr
    elseif sym === :singlet_pair
        Float64.(abs.(singlet_pair_amplitude(psi, F, ndim)))
    elseif sym === :structure_factor
        Float64.(structure_factor(psi, grid))
    elseif sym === :nematic_eigenvalues
        nematic_tensor_eigenvalues(psi, sm, ndim)
    elseif sym === :multipole
        ops = multipole_order_parameters(psi, F, ndim)
        n_pts = ntuple(d -> size(psi, d), ndim)
        ranks = sort(collect(keys(ops)))
        arr = zeros(Float64, n_pts..., length(ranks))
        for (i, k) in enumerate(ranks)
            idx = _component_slice(ndim, n_pts, i)
            view(arr, idx...) .= ops[k]
        end
        arr
    else
        throw(ArgumentError("Unknown TWA observable: $sym"))
    end
end
