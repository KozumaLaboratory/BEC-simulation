# L-BFGS ground-state driver (find_ground_state_lbfgs)
#
# The main public entry point. Uses the energy/gradient + helpers
# defined in the sibling files of lbfgs/.

function find_ground_state_lbfgs(;
    grid::Union{Nothing, Grid}=nothing,
    atom::Union{Nothing, AtomSpecies}=nothing,
    interactions::InteractionParams=InteractionParams(0.0, 0.0),
    zeeman::Union{ZeemanParams, TimeDependentZeeman}=ZeemanParams(0.0, 0.0),
    potential::AbstractPotential=NoPotential(),
    n_steps::Int=1000,
    tol::Float64=1e-8,
    initial_state::Symbol=:polar,
    init_state_params::Dict{Symbol, Float64}=Dict{Symbol, Float64}(),
    psi_init::Union{Nothing, AbstractArray}=nothing,
    ws_init::Union{Nothing, Workspace}=nothing,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    secular_ddi::Bool=false,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    target_magnetization::Union{Nothing, Float64}=nothing,
    backend::AbstractBackend=CPUBackend(),
    m_lbfgs::Int=10,
    verbose::Bool=true,
    light_shift::Union{Nothing, LightShift}=nothing,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
    sobolev_alpha::Float64=0.0,
)
    # F32 gradient norm floors around unit roundoff (~1e-7 scaled by grid dV).
    # Relax the default convergence test so F32 runs don't burn all n_steps.
    T_effective = if ws_init !== nothing
        eltype(ws_init.grid.x[1])
    elseif dtype !== nothing
        dtype
    elseif grid !== nothing
        eltype(grid.x[1])
    else
        Float64
    end
    if T_effective === Float32 && tol < 1.0e-5
        @warn "Relaxing LBFGS tol $tol → 1e-5 for Float32 (grad_norm floors near 1e-6)." maxlog=1
        tol = 1.0e-5
    end
    if ws_init !== nothing
        ws = ws_init
        grid = ws.grid
        atom = ws.atom
        if psi_init !== nothing
            size(psi_init) == size(ws.state.psi) ||
                throw(ArgumentError("psi_init size mismatch with ws_init"))
            copyto!(ws.state.psi, psi_init)
        end
    else
        (grid === nothing || atom === nothing) &&
            throw(
                ArgumentError(
                    "find_ground_state_lbfgs requires either ws_init, or both grid and atom"
                ),
            )
        sys = SpinSystem(atom.F)
        if psi_init === nothing
            init_kwargs = Dict{Symbol, Any}(:state => initial_state)
            for (k, v) in init_state_params
                init_kwargs[k] = v
            end
            dtype !== nothing && (init_kwargs[:dtype] = dtype)
            psi_init = init_psi(grid, sys; init_kwargs...)
        end
        sp = SimParams(; dt=0.001, n_steps, imaginary_time=true,
            save_every=max(1, n_steps ÷ 100))
        ws = make_workspace(;
            grid, atom, interactions, zeeman, potential,
            sim_params=sp, psi_init,
            enable_ddi, c_dd, secular_ddi, quasi_2d_ddi, l_z_ddi, backend,
            light_shift, dtype,
        )
    end

    F = atom.F
    D = 2F + 1
    dV = cell_volume(grid)

    # Gradient-coverage guard: energy_gradient! covers kinetic + trap +
    # Zeeman + c0 + c_lhy + c1 + light_shift + DDI. It does NOT cover
    # the c2 singlet-pair channel (apply_singlet_pair_step!) nor the
    # tensor_cache c_extra (c4, c6, …) terms. Energy *evaluation* is
    # correct (energy_decomposition.total at line ~95), but the gradient
    # direction is missing those contributions, so LBFGS would converge
    # to a wrong minimum. Warn the user to fall back to ITP.
    c2_val = abs(get_cn(ws.interactions, 2))
    has_c_extra = !isempty(ws.interactions.c_extra) &&
                  any(>(1e-30) ∘ abs, ws.interactions.c_extra)
    has_tensor = ws.tensor_cache !== nothing
    if c2_val > 1e-30 || has_c_extra || has_tensor
        @warn "find_ground_state_lbfgs: gradient does NOT include c2 singlet-pair " *
            "or c_extra/tensor_cache contributions. The optimizer will converge " *
            "to a biased minimum. Use find_ground_state (ITP) for these channels, " *
            "or only LBFGS-polish a state that has already been ITP-converged with " *
            "the full Hamiltonian. " *
            "(c2=$(round(c2_val; sigdigits=3)), c_extra=$has_c_extra, tensor=$has_tensor)"
    end

    # Device-resident k² for energy_gradient! (matches ws.state.psi's backend)
    k_squared_dev = _to_device(ws.backend, grid.k_squared)

    # Work arrays — separate from ws.state.psi
    psi = copy(ws.state.psi)
    grad = similar(psi)
    grad_new = similar(psi)

    # L-BFGS history
    s_hist = typeof(psi)[]
    y_hist = typeof(psi)[]
    rho_hist = Float64[]

    E_prev = Inf
    converged = false
    last_step = 0
    t_start = time()

    for step in 1:n_steps
        # Gradient at current psi (Riemannian, used unchanged for the
        # convergence test — `grad_norm` is the *physical* residual).
        E = energy_gradient!(grad, psi, ws; k_squared_dev)
        _project_constraints!(grad, psi, grid, target_magnetization, F)
        grad_norm = sqrt(sum(abs2, grad) * dV)

        # Sobolev preconditioner: high-k attenuation acts as a mass-matrix
        # preconditioner for L-BFGS. α = 0 leaves the gradient untouched.
        # Re-project after preconditioning to restore tangency on the
        # (norm + Mz) constraint manifold.
        if sobolev_alpha > 0
            _sobolev_precondition!(grad, ws, k_squared_dev, sobolev_alpha)
            _project_constraints!(grad, psi, grid, target_magnetization, F)
        end

        dE = abs(E - E_prev)

        # Log
        if verbose && (step == 1 || step % max(1, n_steps ÷ 20) == 0 || step == n_steps)
            elapsed = time() - t_start
            eta = elapsed / step * (n_steps - step)
            @printf("  LBFGS %d/%d | E=%.8g dE=%.3g |∇|=%.3g | %.1fs, ETA %.0fs\n",
                step, n_steps, E, dE, grad_norm, elapsed, eta)
            flush(stdout)
        end

        # Convergence
        if step > 1 && grad_norm < tol
            converged = true
            last_step = step
            verbose && println("  Converged! |∇E|=$(round(grad_norm; sigdigits=3))")
            break
        end

        # L-BFGS direction (steepest descent for first step)
        direction = if isempty(rho_hist)
            -grad
        else
            _lbfgs_direction(grad, s_hist, y_hist, rho_hist)
        end

        # Ensure descent direction
        slope = real(sum(conj.(grad) .* direction)) * dV
        if slope >= 0
            direction .= .-grad  # fall back to steepest descent
            slope = -sum(abs2, grad) * dV
        end

        # Line search: pure energy decrease (no slope condition — safe on manifold)
        α, E_trial = _line_search_energy_decrease(
            psi, direction, E, ws, grid, dV, target_magnetization, F
        )

        # Line search failed — reset L-BFGS and try steepest descent next
        if α == 0.0
            empty!(s_hist);
            empty!(y_hist);
            empty!(rho_hist)
            E_prev = E
            last_step = step
            continue
        end

        # Step
        s_k = α .* direction
        psi .+= s_k

        # Retraction
        norm_sq = sum(abs2, psi) * dV
        psi ./= sqrt(norm_sq)
        if target_magnetization !== nothing
            _normalize_psi_constrained!(
                psi, grid, D, length(grid.config.n_points), target_magnetization, F
            )
        end

        # Gradient at new psi
        E_new = energy_gradient!(grad_new, psi, ws; k_squared_dev)
        _project_constraints!(grad_new, psi, grid, target_magnetization, F)
        if sobolev_alpha > 0
            _sobolev_precondition!(grad_new, ws, k_squared_dev, sobolev_alpha)
            _project_constraints!(grad_new, psi, grid, target_magnetization, F)
        end

        # L-BFGS history update
        y_k = grad_new .- grad
        ys = real(sum(conj.(s_k) .* y_k)) * dV
        if ys > 1e-30
            push!(s_hist, copy(s_k))
            push!(y_hist, copy(y_k))
            push!(rho_hist, 1.0 / ys)
            if length(s_hist) > m_lbfgs
                popfirst!(s_hist);
                popfirst!(y_hist);
                popfirst!(rho_hist)
            end
        else
            empty!(s_hist);
            empty!(y_hist);
            empty!(rho_hist)
        end

        E_prev = E_trial
        last_step = step
    end

    copyto!(ws.state.psi, psi)
    E_final = total_energy(ws)

    (
        workspace=ws,
        converged=converged,
        energy=E_final,
        dE=abs(E_final - E_prev),
        last_step=last_step,
    )
end

"""
    _sobolev_precondition!(grad, ws, k_squared_dev, alpha) → grad

In-place Sobolev preconditioner: `grad ← (1 + α·(-∇²))^(-1) · grad`,
applied per spinor component via the existing per-component FFT plans
in `ws.fft_plans` and the device-resident `k_squared_dev`. In k-space
this is pointwise division by `(1 + α·k²)` — the high-`k` (rapid
oscillation) modes of the gradient get attenuated, which acts as a
mass-matrix preconditioner for L-BFGS.

`α = 0` is a no-op (preserves backward compatibility with the
unpreconditioned solver). Useful range: α = 0.01 – 1.0 in dimensionless
ω_ref units; for Eu 64³ box=20 the highest k² ≈ 25, so α ≈ 0.04 dampens
the k_max mode by ~half. Bao et al. 2025-12 ("Projected Sobolev Natural
Gradient Descent", arXiv:2512.11339) is the natural-gradient analogue
applied as a preconditioner here.
"""
