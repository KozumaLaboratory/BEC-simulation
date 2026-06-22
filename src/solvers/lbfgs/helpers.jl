# L-BFGS internal helpers: Sobolev preconditioner + 2-loop direction
# update + line search.

# Scratch buffers for LBFGS direction update + line search, backed by the
# shared scratch registry. Avoids per-iteration allocations that
# accumulated to GB-scale CUDA pool pressure during long LBFGS runs on GPU.
function _lbfgs_scratch(template)
    scratch_get!(:lbfgs, (typeof(template), size(template))) do
        (q=similar(template), psi_trial=similar(template))
    end
end

function _sobolev_precondition!(
    grad::AbstractArray{<:Complex},
    ws::Workspace{N},
    k_squared_dev::AbstractArray{<:AbstractFloat},
    alpha::Float64,
) where {N}
    alpha > 0 || return grad
    n_pts = ntuple(d -> size(grad, d), Val(N))
    n_comp = ws.spin_matrices.system.n_components
    fft_buf = ws.state.fft_buf
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(grad, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf ./= (1 .+ alpha .* k_squared_dev)
        ws.fft_plans.inverse * fft_buf
        view(grad, idx...) .= fft_buf
    end
    grad
end

"""
Two-loop L-BFGS direction, evaluated under the manifold inner product
`⟨a,b⟩ = real(dot(a,b))·dV` — the same convention the driver uses for
`rho_hist` (`1/(⟨s,y⟩)`), `slope`, and `grad_norm`.

The `·dV` on the `alphas`/`β` dot products is load-bearing: `rho_hist`
already carries a `1/dV`, so omitting `dV` here under-weights every
correction term by `1/dV` (≈8× on a 128-pt/L=16 grid), mis-scaling the
search direction. That inconsistency was masked for years by the old
shrink-only line search capping the step at `α=0.01`; once the line
search takes the natural `α≈1` step the mis-scaling dominates. `γ` is
invariant under the `dV` rescaling (it cancels), so it is unchanged.
"""
function _lbfgs_direction(
    grad::AbstractArray{<:Complex},
    s_hist::Vector, y_hist::Vector, rho_hist::Vector{Float64},
    dV::Float64,
)
    sc = _lbfgs_scratch(grad)
    q = sc.q
    copyto!(q, grad)
    m = length(rho_hist)
    alphas = zeros(m)

    # `dot(a, b) = sum(conj(a) * b)` for complex arrays; identical to the
    # `real(sum(conj.(...) .* ...))` form but doesn't materialise the
    # `conj.(s)` and product temporaries (each ~`size(grad)` complex
    # array — for a 16³ × D=13 spinor that's ~640 KB per call, repeated
    # 2m+1 times per L-BFGS direction).
    for i in m:-1:1
        alphas[i] = rho_hist[i] * real(dot(s_hist[i], q)) * dV
        q .-= alphas[i] .* y_hist[i]
    end

    if m > 0
        ys = real(dot(y_hist[end], s_hist[end]))
        yy = real(sum(abs2, y_hist[end]))
        γ = ys / max(yy, 1e-30)
        q .*= γ
    end

    for i in 1:m
        β = rho_hist[i] * real(dot(y_hist[i], q)) * dV
        q .+= (alphas[i] - β) .* s_hist[i]
    end

    q .*= -1
    q
end

"""
Backtracking-Armijo line search on the constraint manifold, starting from
the natural L-BFGS step `α_init = 1`.

The L-BFGS direction is already curvature-scaled (the two-loop recursion
multiplies by `γ = ⟨s,y⟩/⟨y,y⟩`), so it is an approximate Newton step whose
natural length is `α ≈ 1` — the historical `α_init = 0.01` shrink-only search
could never take more than 1 % of that step, capping LBFGS far above its
gradient floor (scalar harmonic GS plateaued at `|∇E|≈4e-3`, `errE≈2e-6`, vs
ITP's `2e-12`). Starting at `α = 1` and backtracking restores the Newton step.

Acceptance is the Armijo sufficient-decrease test `E(α) ≤ E0 + c1·α·slope`
(`slope = ⟨∇E, d⟩·dV ≤ 0` is the manifold directional derivative, passed from
the driver). When `slope` is not supplied (`0`) it degrades to the strict-
decrease test `E(α) < E0`, preserving the old manifold-safe behaviour.

`expand=true` (used for the steepest-descent step, whose scale is unknown)
permits a bounded doubling phase when `α = 1` already decreases, so the first
unscaled step auto-finds its scale instead of being stuck at the Newton length.
"""
function _line_search_energy_decrease(
    psi, direction, E0, ws, grid, dV, target_Mz, F;
    slope::Float64=0.0,
    α_init::Float64=1.0, shrink::Float64=0.5, grow::Float64=2.0,
    c1::Float64=1.0e-4, max_iter::Int=30, max_expand::Int=6,
    expand::Bool=false,
)
    D = 2F + 1
    N_dim = length(grid.config.n_points)
    psi_trial = _lbfgs_scratch(psi).psi_trial

    eval_energy = function (α)
        psi_trial .= psi .+ α .* direction
        # Retraction: normalize back to manifold
        norm_sq = sum(abs2, psi_trial) * dV
        psi_trial ./= sqrt(norm_sq)
        if target_Mz !== nothing
            _normalize_psi_constrained!(psi_trial, grid, D, N_dim, target_Mz, F)
        end
        copyto!(ws.state.psi, psi_trial)
        total_energy(ws)
    end

    # Armijo sufficient decrease (slope ≤ 0). slope == 0 ⇒ strict decrease.
    accept(α, E) = slope < 0 ? (E ≤ E0 + c1 * α * slope) : (E < E0)

    α = α_init
    E_trial = eval_energy(α)

    if accept(α, E_trial)
        # Optional bounded expansion: only when the curvature step is not yet
        # the local minimiser along the ray (steepest-descent scale finding).
        if expand
            best_α, best_E = α, E_trial
            for _ in 1:max_expand
                α2 = best_α * grow
                E2 = eval_energy(α2)
                (E2 < best_E && accept(α2, E2)) || break
                best_α, best_E = α2, E2
            end
            best_α == α || eval_energy(best_α)  # leave ws.state.psi at best
            return best_α, best_E
        end
        return α, E_trial
    end

    # Backtracking from α_init.
    for _ in 1:max_iter
        α *= shrink
        E_trial = eval_energy(α)
        if accept(α, E_trial)
            return α, E_trial
        end
    end
    # No sufficient decrease found — return zero step.
    (0.0, E0)
end
