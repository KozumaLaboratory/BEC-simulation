# --- L-BFGS ground state solver ---
#
# Direct minimization of E[ψ] on the constraint manifold {‖ψ‖²=1, ⟨Fz⟩=Mz}.
#
# Advantages over split-step ITP:
#   - Energy is guaranteed to decrease at every step (line search)
#   - DDI self-consistency is exact (Φ[ψ] computed at current ψ)
#   - No split-step error or operator-ordering artifacts
#
# Cost per step: ~1 split-step equivalent (FFT pairs + DDI convolution)
# for the gradient, plus ~1 energy evaluation for line search.

using Printf

"""
    energy_gradient!(grad, psi, ws; k_squared_dev) → E

Compute δE/δψ* = H_eff ψ and return total energy.
The gradient includes kinetic, trap, contact, LHY, spin, and DDI terms.

`k_squared_dev` must live on the same device as `psi` (defaults to `ws.grid.k_squared`,
which only works on CPU). L-BFGS on GPU should pass a device-resident copy.
"""
function energy_gradient!(
    grad::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    ws::Workspace{N};
    k_squared_dev::AbstractArray{<:AbstractFloat}=ws.grid.k_squared,
) where {N}
    grid = ws.grid
    n_comp = ws.spin_matrices.system.n_components
    F = ws.atom.F
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = n_comp

    fill!(grad, zero(ComplexF64))

    # Sync workspace psi for energy evaluation
    copyto!(ws.state.psi, psi)

    # --- Kinetic: (-∇²/2) ψ via FFT ---
    fft_buf = similar(psi, ComplexF64, n_pts)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf .*= (0.5 .* k_squared_dev)
        ws.fft_plans.inverse * fft_buf
        view(grad, idx...) .+= fft_buf
    end

    # --- Trap potential: V_trap ψ ---
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= ws.potential_values .* view(psi, idx...)
    end

    # --- Zeeman ---
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zee_vals = zeeman_energies(zee, ws.spin_matrices.system)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= zee_vals[c] .* view(psi, idx...)
    end

    # --- Density interaction: c₀ n ψ ---
    n_density = total_density(psi, N)
    c0 = ws.interactions.c0
    if abs(c0) > 1e-30
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= c0 .* n_density .* view(psi, idx...)
        end
    end

    # --- LHY ---
    c_lhy_val = ws.interactions.c_lhy
    if c_lhy_val != 0.0
        v_lhy = c_lhy_val .* n_density .* sqrt.(max.(n_density, 0.0))
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= v_lhy .* view(psi, idx...)
        end
    end

    # --- Spin interaction: c₁ (F⃗·f⃗) ψ ---
    c1 = ws.interactions.c1
    if abs(c1) > 1e-30
        sm = ws.spin_matrices
        # device-aware allocation: GPU when psi is CuArray, CPU otherwise
        fx = similar(psi, Float64, n_pts)
        fy = similar(psi, Float64, n_pts)
        fz = similar(psi, Float64, n_pts)
        _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), N, n_pts)
        # Fz part (diagonal)
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            m = Float64(F - (c - 1))
            view(grad, idx...) .+= c1 .* m .* fz .* view(psi, idx...)
        end
        # F+/F- parts (tridiagonal)
        for c in 2:D
            idx_c = _component_slice(N, n_pts, c)
            idx_cm1 = _component_slice(N, n_pts, c - 1)
            fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            # (F⃗·f⃗)ψ has off-diagonal: fp/2 × [(fx-ify)ψ_{c} in row c-1, (fx+ify)ψ_{c-1} in row c]
            view(grad, idx_cm1...) .+= c1 .* 0.5 .* fp .* (fx .- im .* fy) .* view(psi, idx_c...)
            view(grad, idx_c...) .+= c1 .* 0.5 .* fp .* (fx .+ im .* fy) .* view(psi, idx_cm1...)
        end
    end

    # --- Light shift: M × I(r) × ψ ---
    if ws.light_shift !== nothing
        ls = ws.light_shift
        profile = _to_host(ls.profile)
        if ls.is_diagonal
            for c in 1:D
                idx = _component_slice(N, n_pts, c)
                view(grad, idx...) .+= ls.eigvals[c] .* profile .* view(psi, idx...)
            end
        else
            M_full = ls.U * Diagonal(ls.eigvals) * ls.U'
            for c in 1:D
                idx_c = _component_slice(N, n_pts, c)
                for c2 in 1:D
                    abs(M_full[c, c2]) < 1e-30 && continue
                    idx_c2 = _component_slice(N, n_pts, c2)
                    view(grad, idx_c...) .+= M_full[c, c2] .* profile .* view(psi, idx_c2...)
                end
            end
        end
    end

    # --- DDI: (Φ⃗·f⃗) ψ ---
    if ws.ddi !== nothing
        sm = ws.spin_matrices
        bufs = ws.ddi_bufs
        _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, n_pts)
        compute_ddi_potential!(ws.ddi, bufs)

        # Keep on device (bufs.Phi_* already live on the workspace backend)
        phi_x = bufs.Phi_x
        phi_y = bufs.Phi_y
        phi_z = bufs.Phi_z

        # Fz part
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            m = Float64(F - (c - 1))
            view(grad, idx...) .+= m .* phi_z .* view(psi, idx...)
        end
        # F+/F- parts
        for c in 2:D
            idx_c = _component_slice(N, n_pts, c)
            idx_cm1 = _component_slice(N, n_pts, c - 1)
            fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            view(grad, idx_cm1...) .+= 0.5 .* fp .* (phi_x .- im .* phi_y) .* view(psi, idx_c...)
            view(grad, idx_c...) .+= 0.5 .* fp .* (phi_x .+ im .* phi_y) .* view(psi, idx_cm1...)
        end
    end

    # Scale gradient by 2 for complex ψ convention:
    # δE = 2 Re ∫ (δE/δψ*)* · δψ dV, so grad_R = 2 × δE/δψ*
    # makes δE = Re ∫ grad_R* · δψ dV (standard real inner product)
    grad .*= 2

    energy_decomposition(ws).total
end

"""
Project gradient onto constraint tangent space:
  1. Remove ψ-component (particle number conservation)
  2. Remove Mz-changing component (magnetization conservation)
"""
function _project_constraints!(
    grad::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    target_Mz::Union{Nothing, Float64},
    F::Int,
) where {N}
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = 2F + 1

    # 1. Remove ψ-direction: grad -= Re⟨ψ|grad⟩ × ψ
    #    (chemical potential projection)
    μ_real = real(sum(conj.(psi) .* grad)) * dV
    grad .-= μ_real .* psi

    # 2. Magnetization conservation
    if target_Mz !== nothing
        mz_grad = 0.0
        mz_norm = 0.0
        for c in 1:D
            m = Float64(F - (c - 1))
            idx = _component_slice(N, n_pts, c)
            gc = view(grad, idx...)
            pc = view(psi, idx...)
            mz_grad += m * real(sum(conj.(pc) .* gc)) * dV
            mz_norm += m^2 * sum(abs2, pc) * dV
        end
        if mz_norm > 1e-30
            λ = mz_grad / mz_norm
            for c in 1:D
                m = Float64(F - (c - 1))
                idx = _component_slice(N, n_pts, c)
                view(grad, idx...) .-= λ * m .* view(psi, idx...)
            end
        end
    end
    nothing
end

"""
    find_ground_state_lbfgs(; kwargs...) → NamedTuple

Find ground state by direct energy minimization using L-BFGS on the
constraint manifold {‖ψ‖²=1}.

# Hamiltonian coverage

The gradient implementation (`energy_gradient!`) covers:
kinetic, trap, Zeeman, c0 (density), c_lhy, c1 (spin), light_shift, DDI.

It does **NOT** cover:
- c2 (the S=0 singlet-pair channel — `apply_singlet_pair_step!`)
- `c_extra` higher-rank tensor couplings (c4, c6, …)
- `tensor_cache` (per-channel g_S table)

The energy evaluation at end of step is correct (uses
`energy_decomposition`), but the gradient direction is biased when any
of those channels is active. The optimizer will converge to a wrong
minimum. A runtime `@warn` fires in this case; for those Hamiltonians
use the ITP path (`find_ground_state`) instead, or only LBFGS-polish a
state already ITP-converged with the full Hamiltonian.
"""
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
        # Gradient at current psi
        E = energy_gradient!(grad, psi, ws; k_squared_dev)
        _project_constraints!(grad, psi, grid, target_magnetization, F)
        grad_norm = sqrt(sum(abs2, grad) * dV)

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

"""Two-loop L-BFGS direction."""
function _lbfgs_direction(
    grad::AbstractArray{<:Complex},
    s_hist::Vector, y_hist::Vector, rho_hist::Vector{Float64},
)
    q = copy(grad)
    m = length(rho_hist)
    alphas = zeros(m)

    for i in m:-1:1
        alphas[i] = rho_hist[i] * real(sum(conj.(s_hist[i]) .* q))
        q .-= alphas[i] .* y_hist[i]
    end

    if m > 0
        ys = real(sum(conj.(y_hist[end]) .* s_hist[end]))
        yy = real(sum(abs2, y_hist[end]))
        γ = ys / max(yy, 1e-30)
        q .*= γ
    end

    for i in 1:m
        β = rho_hist[i] * real(sum(conj.(y_hist[i]) .* q))
        q .+= (alphas[i] - β) .* s_hist[i]
    end

    q .*= -1
    q
end

"""
Line search on the constraint manifold: require E_trial < E0 (strict decrease).
No slope condition — avoids the retraction/normalization mismatch that makes
Armijo unreliable on the sphere.
"""
function _line_search_energy_decrease(
    psi, direction, E0, ws, grid, dV, target_Mz, F;
    α_init::Float64=0.01, shrink::Float64=0.5, max_iter::Int=30,
)
    D = 2F + 1
    N_dim = length(grid.config.n_points)
    psi_trial = similar(psi)

    α = α_init
    for _ in 1:max_iter
        psi_trial .= psi .+ α .* direction
        # Retraction: normalize back to manifold
        norm_sq = sum(abs2, psi_trial) * dV
        psi_trial ./= sqrt(norm_sq)
        if target_Mz !== nothing
            _normalize_psi_constrained!(psi_trial, grid, D, N_dim, target_Mz, F)
        end

        copyto!(ws.state.psi, psi_trial)
        E_trial = total_energy(ws)

        if E_trial < E0
            return α, E_trial
        end
        α *= shrink
    end
    # No decrease found — return zero step
    (0.0, E0)
end
