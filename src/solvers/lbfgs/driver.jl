# L-BFGS ground-state driver (find_ground_state_lbfgs)

export find_ground_state_lbfgs

# Projected-Riemannian gradient at ψ + preconditioning, in place on `g`.
# Returns (E, grad_norm) where grad_norm is the PROJECTED-RAW residual (before
# preconditioning — the physical convergence certificate). Single source so the
# initial and per-step gradient (reused across steps, not recomputed) precondition
# identically. Mirrors the former inline block exactly ⇒ bit-identical trajectory.
@inline function _lbfgs_grad!(
    g, psi, ws, k_squared_dev, grid, target_magnetization, F,
    precond_alpha_v::Float64, precond_alpha_k::Float64, sobolev_alpha::Float64, dV::Float64;
    E_known::Union{Nothing, Float64}=nothing,
)
    # `E_known` short-circuits the energy evaluation. The line search already
    # evaluated the total energy at exactly this ψ (it is the value it accepted
    # the step on, and the driver adopts the line search's own retracted
    # iterate), so recomputing it here was a second full energy pass per
    # iteration — on the CPU, a second traversal of the whole term registry.
    E = if E_known === nothing
        energy_gradient!(g, psi, ws; k_squared_dev)
    else
        gradient_only!(g, psi, ws)
        E_known
    end
    _project_constraints!(g, psi, grid, target_magnetization, F)
    grad_norm = sqrt(sum(abs2, g) * dV)
    if precond_alpha_v >= 0
        sqrt_pv = build_precond_sqrt_pv(ws, psi, precond_alpha_v)
        combined_precondition!(g, ws, sqrt_pv, k_squared_dev, precond_alpha_k)
        _project_constraints!(g, psi, grid, target_magnetization, F)
    elseif sobolev_alpha > 0
        _sobolev_precondition!(g, ws, k_squared_dev, sobolev_alpha)
        _project_constraints!(g, psi, grid, target_magnetization, F)
    end
    (E, grad_norm)
end

# The main public entry point. Uses the energy/gradient + helpers
# defined in the sibling files of lbfgs/.

function find_ground_state_lbfgs(;
    grid::Union{Nothing, Grid}=nothing,
    atom::Union{Nothing, AtomSpecies}=nothing,
    interactions::InteractionParams=InteractionParams(Dict{Int, Float64}()),
    zeeman::AbstractZeemanField=ZeemanParams(0.0, 0.0),
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
    ddi_trunc_radius::Float64=NaN,
    ddi_padding::Bool=false,
    ddi_pad_factor::Union{Real, NTuple}=2,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    target_magnetization::Union{Nothing, Float64}=nothing,
    backend::AbstractBackend=CPUBackend(),
    m_lbfgs::Int=20,   # history depth. 20 measured ~9× lower grad_norm floor +
    # ~30% fewer line-search backtracks vs 10 on Eu F=6+DDI
    # 16³ (m=30 was worse). Memory ~ 2·m·|ψ|: reduce to 10 if
    # VRAM-constrained at large grids.
    verbose::Bool=_default_solver_verbose(),
    light_shift::Union{Nothing, LightShift}=nothing,
    # Spinor (tabulated) LHY. Until 2026-07-29 these kwargs did not exist, so
    # `find_ground_state_lbfgs` could not build a workspace carrying a
    # `TabulatedLHY` at all — every LBFGS ground state ran with NO spinor LHY,
    # silently. `scalar` was unaffected because it rides in
    # `interactions.c_lhy`, which was already threaded; only the modes that
    # need a table (full_bdg / polar_contact / icosahedral / …) were dropped.
    spinor_lhy::Union{Nothing, Symbol, AbstractLHY}=nothing,
    lhy_opts::LHYTableOpts=LHYTableOpts(),
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
    sobolev_alpha::Union{Float64, Symbol}=:auto,
    precond_alpha_v::Float64=-1.0,        # ≥0 ⇒ combined P_C = P_V^½ P_K P_V^½
    precond_alpha_k::Float64=1.0,         # kinetic shift for the P_C kinetic factor
    rotating_frame_omega::Float64=0.0,
    newton_polish::Bool=false,
    newton_max_outer::Int=20,
    newton_max_cg::Int=40,
    newton_eps::Float64=1.0e-6,
    residual_polish::Bool=false,        # eigenvector-residual final polish that
    residual_hvp_order::Int=4,          # BREAKS the √eps energy-gate floor (1.1e-7
    # → 6.5e-12 on Eu 16³). order-4 HvP stencil is
    # ~13× deeper than order-2 at equal iters for ~2×
    # HvP cost. newton_polish (HvP) cannot break it.
    pin::Union{Nothing, Function}=nothing,        # ε -> (; zeeman=…) | (; potential=…)
    epsilon_ramp::AbstractVector{<:Real}=Float64[],  # non-empty ⇒ pin ε→0 continuation
    lbfgs_history=nothing,   # optional (s_hist, y_hist, rho_hist) to warm-start the
    # two-loop (ε-continuation threads it across rungs so
    # each rung reuses curvature instead of restarting SD).
    # Always returned in the result NamedTuple.
)
    # Soft-manifold pin continuation: a descending ε ramp with a symmetry-breaking
    # pin reaches an isolated minimum (|∇E|~1e-5) and the ε→0 extrapolation
    # certifies the degenerate-problem energy. Default-off (empty ramp) ⇒ the
    # ordinary single solve below runs unchanged.
    if !isempty(epsilon_ramp)
        return _lbfgs_pin_continuation(;
            pin, epsilon_ramp, grid, atom, interactions, zeeman, potential,
            n_steps, tol, initial_state, init_state_params, psi_init, ws_init,
            enable_ddi, c_dd, secular_ddi, ddi_trunc_radius, ddi_padding, ddi_pad_factor,
            quasi_2d_ddi, l_z_ddi, target_magnetization, backend, m_lbfgs, verbose,
            light_shift, dtype, sobolev_alpha, precond_alpha_v, precond_alpha_k,
            rotating_frame_omega, newton_polish, newton_max_outer, newton_max_cg, newton_eps,
            spinor_lhy, lhy_opts,
        )
    end

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
            save_every=max(1, n_steps ÷ 100),
            rotating_frame_omega=rotating_frame_omega)
        ws = make_workspace(;
            grid, atom, interactions, zeeman, potential,
            sim_params=sp, psi_init,
            enable_ddi, c_dd, secular_ddi, ddi_trunc_radius, ddi_padding, ddi_pad_factor,
            quasi_2d_ddi, l_z_ddi, backend,
            light_shift, spinor_lhy, lhy_opts, dtype,
        )
    end

    F = atom.F
    D = 2F + 1
    dV = cell_volume(grid)

    # Grid-adaptive Sobolev preconditioner default. `α = 1/k_max²` damps the
    # highest-k (Nyquist) gradient mode by half — a mass-matrix preconditioner
    # that improves the L-BFGS gradient floor on ill-conditioned (DDI / soft-
    # manifold) problems for free (Eu F=6 24³+DDI: |∇E| floor 6.1e-6 → 3.4e-6,
    # same energy, slightly faster) and is ≈identity on smooth, well-conditioned
    # GS (no high-k gradient content to damp). Pass an explicit Float64 (incl.
    # `0.0` to disable) to override.
    sobolev_alpha =
        sobolev_alpha === :auto ?
        1.0 / Float64(maximum(grid.k_squared)) : Float64(sobolev_alpha)

    # Gradient coverage: energy_gradient! is registry-only, so it now covers
    # EVERY HamTerm including TensorTerm (c2 singlet-pair + tensor_cache
    # higher-rank channels), whose anomalous gradient face was implemented
    # 2026-06-09 (FD-gated in test_term_consistency). The old "falls back to
    # ITP for tensor" warning is retired — LBFGS/Newton-CG optimise the full
    # Hamiltonian for tensor-active configurations.

    # Device-resident k² for energy_gradient! (matches ws.state.psi's backend)
    k_squared_dev = _to_device_cached(ws.backend, grid.k_squared)

    # Work arrays — separate from ws.state.psi
    psi = copy(ws.state.psi)
    grad = similar(psi)
    grad_new = similar(psi)
    # (q, psi_trial, s_k, y_k) — shared with the direction update and the line
    # search, so the per-iteration step/curvature buffers are never allocated.
    scratch = _lbfgs_scratch(psi)

    # L-BFGS history — warm-start from a supplied history when threading across
    # ε-continuation rungs (copied so the caller's vectors are not mutated).
    s_hist, y_hist, rho_hist = if lbfgs_history === nothing
        (typeof(psi)[], typeof(psi)[], Float64[])
    else
        (typeof(psi)[copy(s) for s in lbfgs_history[1]],
            typeof(psi)[copy(y) for y in lbfgs_history[2]],
            Float64[ρ for ρ in lbfgs_history[3]])
    end

    E_prev = Inf
    converged = false
    last_step = 0
    t_start = time()

    # Initial gradient. `grad` is carried across iterations (the gradient at the
    # accepted ψ becomes the next step's gradient) rather than recomputed at the
    # top of each step — halving the energy_gradient! evals. grad_norm is the
    # projected-raw residual; `grad` is left preconditioned for the direction.
    E, grad_norm = _lbfgs_grad!(
        grad, psi, ws, k_squared_dev, grid, target_magnetization, F,
        precond_alpha_v, precond_alpha_k, sobolev_alpha, dV,
    )

    for step in 1:n_steps
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
        is_sd = isempty(rho_hist)
        direction = if is_sd
            scratch.q .= .-grad   # same buffer _lbfgs_direction returns
        else
            _lbfgs_direction(grad, s_hist, y_hist, rho_hist, dV)
        end

        # Ensure descent direction. `_realdot`, not `real(dot(...))` — see the
        # note there on OpenBLAS level-1 team overhead.
        slope = _realdot(grad, direction) * dV
        if slope >= 0
            direction .= .-grad  # fall back to steepest descent
            slope = -sum(abs2, grad) * dV
            is_sd = true
        end

        # Backtracking-Armijo line search from the natural L-BFGS step α=1.
        # `expand` lets the unscaled steepest-descent step auto-find its scale.
        α, E_trial, psi_accepted = _line_search_energy_decrease(
            psi, direction, E, ws, grid, dV, target_magnetization, F;
            slope=slope, expand=is_sd,
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

        # Step + retraction: both were already performed inside the line search
        # at the accepted α (that is what it evaluated the energy of), so take
        # its iterate rather than recomputing `psi .+= α·d` and renormalising.
        s_k = scratch.s_k
        s_k .= α .* direction
        copyto!(psi, psi_accepted)

        # Gradient at the new ψ — same preconditioning as the initial gradient so
        # it can be carried to the next iteration. grad_norm_new is the projected-
        # raw residual used by the next convergence test.
        E_new, grad_norm_new = _lbfgs_grad!(
            grad_new, psi, ws, k_squared_dev, grid, target_magnetization, F,
            precond_alpha_v, precond_alpha_k, sobolev_alpha, dV;
            E_known=Float64(E_trial),
        )

        # L-BFGS history update — `real(dot(s_k, y_k))` is the same
        # quantity as `real(sum(conj.(s_k) .* y_k))` without the two
        # `size(grad)` temporaries.
        y_k = scratch.y_k
        y_k .= grad_new .- grad
        ys = _realdot(s_k, y_k) * dV
        if is_active(ys)
            # At capacity, evict the oldest pair and write the new one into
            # the buffers it was holding: steady-state history maintenance
            # allocates nothing. `push!(hist, copy(s_k))` used to allocate two
            # ψ-sized arrays per iteration (~5.8 MB/iter at 24³ × D=13) and
            # drop two more on the floor for the GC / CUDA pool.
            if length(s_hist) >= m_lbfgs
                s_slot = popfirst!(s_hist)
                y_slot = popfirst!(y_hist)
                popfirst!(rho_hist)
                copyto!(s_slot, s_k)
                copyto!(y_slot, y_k)
                push!(s_hist, s_slot)
                push!(y_hist, y_slot)
            else
                push!(s_hist, copy(s_k))
                push!(y_hist, copy(y_k))
            end
            push!(rho_hist, 1.0 / ys)
        else
            empty!(s_hist);
            empty!(y_hist);
            empty!(rho_hist)
        end

        # Carry the new gradient/energy to the next iteration (swap buffers so the
        # old `grad` is reused as scratch for the next `grad_new`).
        # `E_prev` is the energy BEFORE this step, so `dE` is the step's energy
        # decrease. It used to be assigned `E_trial` — the energy AT the accepted
        # point, i.e. the same iterate `E_new` is measured at, and bit-identical
        # to it — so the reported `dE` was exactly 0.0 from step 2 onward, for
        # every run, including the value returned in `result.dE`.
        grad, grad_new = grad_new, grad
        grad_norm = grad_norm_new
        E_prev = E
        E = E_new
        last_step = step
    end

    # Optional second-order polish. Both L-BFGS (line search) and Newton-CG
    # (trust region) accept steps by an ENERGY comparison, so neither can
    # resolve a step whose energy reduction (~‖∇E‖²/curvature) falls below the
    # energy-evaluation roundoff (~eps·|E|). That puts a floor on the projected
    # gradient at ‖∇E‖ ~ √eps·‖g‖ (≈ √eps·2|E|; measured `‖∇E‖/|E| ≈ 1.4e-7`
    # constant as |E| is swept 256×, and INDEPENDENT of the HvP finite-
    # difference order — a 4th-order stencil does not lower it). The Newton-CG
    # pass still buys ~10× over L-BFGS (6.6e-8 → 5e-9 on the scalar harmonic;
    # energy unchanged to ~1e-15) by getting closer to that √eps floor, but it
    # is NOT a route below it — the bottleneck is the energy comparison, not
    # the HvP, so a better (AD / analytic-Bogoliubov) HvP would not help. To
    # break √eps·‖g‖ needs an eigenvector-residual iteration (RQI / inverse
    # iteration) that drives (H−μ)ψ→0 directly, without energy-gated steps.
    # Useful when ‖∇E‖ is itself the certificate (BdG / stability gates).
    # Opt-in: it costs ~max_outer × max_cg HvPs (2 gradient evals each).
    if newton_polish
        rn = newton_cg_ground_state(
            ws, psi;
            tol=min(tol, 1.0e-12), max_outer=newton_max_outer, max_cg=newton_max_cg,
            sobolev_alpha=sobolev_alpha, ε=newton_eps, verbose,
        )
        copyto!(psi, rn.psi)
    end

    # Eigenvector-residual polish: drives (H−μ)ψ→0 directly, WITHOUT energy-gated
    # steps, so it breaks the √eps·‖g‖ floor that both L-BFGS and Newton-CG hit
    # (see the note above). Opt-in; costs ~max_outer×max_cg HvPs. Use when the
    # grad_norm floor itself is the certificate (BdG / stability gates).
    if residual_polish
        rr = residual_newton_refine(
            ws, psi;
            tol=min(tol, 1.0e-13), max_outer=newton_max_outer,
            max_cg=max(newton_max_cg, 120), ε=newton_eps,
            hvp_order=residual_hvp_order, verbose,
        )
        copyto!(psi, rr.psi)
    end

    # Atomic finalization (spine G, 2026-06-05). Guarantees the returned
    # NamedTuple's {ws.state.psi, energy, grad_norm} all refer to the
    # SAME iterate. The legacy inline sequence (copyto! + total_energy +
    # energy_gradient! + _project_constraints! + sqrt) had a subtle drift
    # found on 2026-06-05 (13/22 M1 cells: disk grad_norm ≠ fresh re-eval
    # at saved ψ by 30-50×). `_finalize_lbfgs_atomic!` does a single
    # explicit psi snapshot, evaluates everything from it, and re-syncs
    # ws.state.psi to the snapshot at exit. See atomic.jl docstring.
    result = _finalize_lbfgs_atomic!(
        ws, psi, converged, last_step;
        k_squared_dev, target_magnetization, F, E_prev=Float64(E_prev),
    )
    # Expose the final L-BFGS curvature history so ε-continuation (or any warm
    # restart) can thread it into the next solve. Does not touch the atomic
    # {ws.state.psi, energy, grad_norm} spine.
    merge(result, (; lbfgs_history=(s_hist, y_hist, rho_hist)))
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
