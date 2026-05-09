# --- Embedded error estimation for adaptive split-step ---

export run_simulation_embedded!

# Correct embedded pairs for Yoshida S4 and Blanes-Moan S6.
#
# Key insight (user derivation): intermediate stage differences ψ_mid - ψ_final
# are O(dt), NOT O(dt^p). The correct embedded solution requires specific linear
# combinations that cancel O(dt) and O(dt²) terms via Vandermonde conditions:
#
#   Σ_j α_j = 1,  Σ_j α_j τ_j = 1,  ...,  Σ_j α_j τ_j^{p-2} = 1
#
# where τ_j are the cumulative substep "times" within one composition step.

# =====================================================================
# Yoshida S4: 4(2) embedded pair
# =====================================================================
#
# S4 = S2(w1·h) ∘ S2(w0·h) ∘ S2(w1·h), w0+2w1=1
# Intermediate outputs: ψ₀ (input), ψ₁ (after S2₁), ψ₂ (after S2₂), ψ₃ (output)
# Cumulative times: τ = [0, w1, 1-w1, 1]
#
# Error estimator (cancels O(h) and O(h²) exactly):
#   E = (2w1-1)(ψ₃ - ψ₀) - (ψ₁ - ψ₂) = O(h³)

const _YOSHIDA_EMBED_C = 2 * _YOSHIDA_W1 - 1  # ≈ 1.7024

"""
    _yoshida_embedded_step!(ws, dt, n_comp, psi0, psi1; t_base) → err

Yoshida S4 step with O(h³) embedded error estimate.
Requires two buffers: psi0 (initial state) and psi1 (after first Strang substep).
"""
function _yoshida_embedded_step!(
    ws::Workspace{N}, dt::Float64, n_comp::Int,
    psi0::AbstractArray, psi1::AbstractArray;
    t_base::Float64=ws.state.t,
) where {N}
    w1 = _YOSHIDA_W1
    w0 = _YOSHIDA_W0
    wm = (w1 + w0) / 2
    omega = ws.sim_params.rotating_frame_omega

    # Save ψ₀
    copyto!(psi0, ws.state.psi)

    # --- Strang 1: S2(w1·dt) ---
    _half_potential_step!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + w1 * dt / 4, t_start=t_base)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    _half_potential_step!(ws, wm * dt, n_comp, N, false;
        t_eval=t_base + w1 * dt / 2 + wm * dt / 2, t_start=t_base + w1 * dt / 2)

    # Save ψ₁
    copyto!(psi1, ws.state.psi)

    # --- Strang 2: S2(w0·dt) ---
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    t_v3 = t_base + w1 * dt / 2 + wm * dt
    _half_potential_step!(ws, wm * dt, n_comp, N, false;
        t_eval=t_v3 + wm * dt / 2, t_start=t_v3)

    # ψ₂ is now in ws.state.psi — save temporarily by computing (ψ₁ - ψ₂)
    # psi1 = ψ₁ - ψ₂  (reuse buffer)
    psi1 .= psi1 .- ws.state.psi

    # --- Strang 3: S2(w1·dt) ---
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    _half_potential_step!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + dt - w1 * dt / 4, t_start=t_base + dt - w1 * dt / 2)

    # ψ₃ is now in ws.state.psi
    # Error = c(ψ₃ - ψ₀) - (ψ₁ - ψ₂)
    # psi0 still holds ψ₀, psi1 holds (ψ₁ - ψ₂)
    c = _YOSHIDA_EMBED_C
    dV = cell_volume(ws.grid)
    err_sq = 0.0
    @inbounds for i in eachindex(ws.state.psi, psi0, psi1)
        e = c * (ws.state.psi[i] - psi0[i]) - psi1[i]
        err_sq += abs2(e)
    end
    sqrt(err_sq * dV)
end

# =====================================================================
# Blanes-Moan S6: 6(4) embedded pair
# =====================================================================
#
# S6 has 6 kinetic stages (7 Strang substeps in ABA form), giving
# intermediate outputs ψ₀..ψ₆ (ψ₇ = final output stored in ws.state.psi).
# Actually in the ABA form with 7 a-coefficients and 6 b-coefficients,
# we get 7 intermediate states after each V·K pair.
#
# Cumulative "times": τ_j = Σ_{k=1}^j b_k  (τ₀=0, τ₆=1)
# where b_k are the kinetic step weights.
#
# 4th-order embedded: solve Σ α_j τ_j^k = 1 for k=0..4 (5 equations, 7 unknowns).
# Use minimum-norm pseudoinverse with α₀ = 0.

const _BM_S6_EMBED_ALPHA = let
    comp = _COMP_BLANES_MOAN_S6
    b = comp.b  # 6 kinetic weights
    # Cumulative times τ₁..τ₆ (τ₀=0 excluded since α₀=0)
    τ = cumsum(collect(b))  # should end at 1.0

    # Vandermonde matrix: V[k+1, j] = τ_j^k for k=0..4, j=1..6
    V = [τ[j]^k for k in 0:4, j in 1:6]  # 5×6
    rhs = ones(5)
    # Minimum-norm solution: α = V' (V V')⁻¹ rhs
    α_rest = V' * ((V * V') \ rhs)
    # Full vector with α₀ = 0
    vcat(0.0, α_rest)
end

"""
    _bm_s6_embedded_step!(ws, dt, n_comp, stages; t_base) → err

Blanes-Moan S6 step with O(h⁵) embedded error estimate.
`stages` must be a vector of 7 arrays (same size as ws.state.psi)
to store intermediate wavefunctions ψ₀..ψ₆.
"""
function _bm_s6_embedded_step!(
    ws::Workspace{N}, dt::Float64, n_comp::Int,
    stages::Vector{<:AbstractArray};
    t_base::Float64=ws.state.t,
) where {N}
    comp = _COMP_BLANES_MOAN_S6
    a = comp.a  # 7 V-step weights
    b = comp.b  # 6 K-step weights
    omega = ws.sim_params.rotating_frame_omega
    α = _BM_S6_EMBED_ALPHA  # 7 embedded coefficients (α₀=0)

    # Save ψ₀
    copyto!(stages[1], ws.state.psi)

    t_cur = 0.0
    _half_potential_step!(ws, a[1] * dt, n_comp, N, false;
        t_eval=t_base + a[1] * dt / 2, t_start=t_base)
    t_cur += a[1] * dt

    for i in 1:6
        _apply_coriolis_step!(ws.state.psi, ws.grid, omega, b[i] * dt / 2, false, ws.coriolis_cache)
        _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, b[i] * dt)
        apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
        _apply_coriolis_step!(ws.state.psi, ws.grid, omega, b[i] * dt / 2, false, ws.coriolis_cache)

        _half_potential_step!(ws, a[i + 1] * dt, n_comp, N, false;
            t_eval=t_base + t_cur + a[i + 1] * dt / 2, t_start=t_base + t_cur)
        t_cur += a[i + 1] * dt

        # Save ψᵢ (after i-th kinetic step + following V-step)
        copyto!(stages[i + 1], ws.state.psi)
    end

    # ψ₆ = final output is in ws.state.psi (and stages[7])
    # Embedded solution: ψ̃ = Σ α_j ψ_j
    # Error = ψ₆ - ψ̃ = ψ₆ - Σ α_j ψ_j
    #       = (1 - α₆) ψ₆ - Σ_{j≠6} α_j ψ_j
    dV = cell_volume(ws.grid)
    err_sq = 0.0
    @inbounds for idx in eachindex(ws.state.psi)
        emb = zero(ComplexF64)
        for j in 1:7
            emb += α[j] * stages[j][idx]
        end
        e = ws.state.psi[idx] - emb
        err_sq += abs2(e)
    end
    sqrt(err_sq * dV)
end

# =====================================================================
# PI controller
# =====================================================================

function _pi_controller(
    err::Float64, tol::Float64, dt::Float64,
    dt_min::Float64, dt_max::Float64, order::Int;
    prev_err::Float64=NaN,
)
    safety = 0.8
    fac_min = 0.2
    fac_max = 5.0

    if err < 1e-300
        return min(dt * fac_max, dt_max)
    end

    # P controller: dt_new = dt × safety × (tol/err)^(1/(order+1))
    α = 0.7 / (order + 1)
    β = 0.4 / (order + 1)

    factor = safety * (tol / err)^α
    if !isnan(prev_err) && prev_err > 1e-300
        factor *= (tol / prev_err)^β
    end
    clamp(dt * clamp(factor, fac_min, fac_max), dt_min, dt_max)
end

# =====================================================================
# Note on 4th-order ITP — the Sheng-Suzuki barrier
# =====================================================================
#
# An earlier `_sc4_itp_step!` shipped a "SC4s4 symmetric-conjugate ITP"
# step with `b = (1/4, 3/8, 3/8, 1/4)`. Code review caught the bug:
# `sum(b) = 5/4`, breaking even 1st-order consistency.
#
# Fixing that table is non-trivial. Sheng-Suzuki's no-go theorem rules
# out real-valued 4th-or-higher-order splittings with all-positive
# coefficients, so every fast 4th+ scheme in this file's composition
# table (Yoshida, Suzuki, Blanes-Moan S6, PEFRL) carries a negative
# weight somewhere. In ITP that negative middle step expands modes
# instead of contracting them — overflow on stiff problems.
#
# The way out is *complex*-coefficient symmetric-conjugate methods
# (Castella-Chartier-Descombes-Vilmart 2009, Blanes-Casas-Murua 2024).
# Implementing one correctly requires verified palindromic complex
# weights with `Re(sum(b)) = 1` and matching imaginary cancellations,
# plus extending `_half_potential_step!` / kinetic kernels to accept
# complex dt. That's a research-grade addition, not a patch.
#
# Until then `find_ground_state` exposes only `:strang` as the ITP
# stepper. For tighter convergence, the LBFGS polish path
# (`find_ground_state_lbfgs`) is the supported route.

"""
    run_simulation_embedded!(ws; t_end, save_interval, adaptive, composition, callback)

RTP with embedded error estimation. Default: Blanes-Moan S6 with O(h⁵) error.

Error estimator uses correct linear combinations of intermediate stages
(Blanes, Casas & Thalhammer, Appl. Numer. Math. 2019). The O(h) and O(h²)
terms cancel exactly, leaving a pure O(h^{p-1}) local error estimate.
"""
function run_simulation_embedded!(
    ws::Workspace{N};
    adaptive::AdaptiveDtParams=AdaptiveDtParams(error_mode=:embedded),
    t_end::Float64,
    save_interval::Float64,
    composition::Symbol=:blanes_moan_s6,
    callback::Union{Nothing, Function}=nothing,
) where {N}
    n_comp = ws.spin_matrices.system.n_components
    sys = ws.spin_matrices.system

    use_s6 = composition === :blanes_moan_s6
    comp_order = use_s6 ? 6 : 4

    dt = clamp(adaptive.dt_init, adaptive.dt_min, adaptive.dt_max)

    times = Float64[]
    energies = Float64[]
    norms = Float64[]
    mags = Float64[]
    snapshots = Array{ComplexF64}[]
    _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)

    # Allocate stage buffers
    if use_s6
        stages = [similar(ws.state.psi) for _ in 1:7]
    else
        buf0 = similar(ws.state.psi)
        buf1 = similar(ws.state.psi)
    end
    psi_backup = similar(ws.state.psi)

    next_save = ws.state.t + save_interval
    n_accepted = 0
    n_rejected = 0
    prev_err = NaN

    while ws.state.t < t_end - 1e-14
        dt_step = min(dt, t_end - ws.state.t)
        remaining_to_save = next_save - ws.state.t
        if remaining_to_save > 1e-14 && remaining_to_save < dt_step
            dt_step = remaining_to_save
        end
        dt_step = max(dt_step, adaptive.dt_min)

        is_clamped = dt_step < dt * 0.99
        may_reject = !is_clamped && dt_step > adaptive.dt_min * 1.01

        copyto!(psi_backup, ws.state.psi)

        err = if use_s6
            _bm_s6_embedded_step!(ws, dt_step, n_comp, stages; t_base=ws.state.t)
        else
            _yoshida_embedded_step!(ws, dt_step, n_comp, buf0, buf1; t_base=ws.state.t)
        end

        if may_reject && err > adaptive.tol
            copyto!(ws.state.psi, psi_backup)
            n_rejected += 1
            dt = _pi_controller(err, adaptive.tol, dt_step, adaptive.dt_min, adaptive.dt_max,
                comp_order; prev_err)
            continue
        end

        ws.state.t += dt_step
        ws.state.step += 1
        n_accepted += 1
        prev_err = err

        dt = _pi_controller(err, adaptive.tol, dt_step, adaptive.dt_min, adaptive.dt_max,
            comp_order; prev_err)

        if ws.state.t >= next_save - 1e-14
            _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)
            callback !== nothing && callback(ws, length(times), -1)
            next_save += save_interval
        end
    end

    (
        times=times, energies=energies, norms=norms, magnetizations=mags,
        snapshots=snapshots, n_accepted=n_accepted, n_rejected=n_rejected,
        final_dt=dt,
    )
end
