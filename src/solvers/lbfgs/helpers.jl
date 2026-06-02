# L-BFGS internal helpers: Sobolev preconditioner + 2-loop direction
# update + line search.

# Scratch cache for LBFGS — avoids per-iteration allocations that accumulate
# to GB-scale memory pressure during long LBFGS runs on GPU. Keyed by
# (typeof, size). Single-threaded Julia assumption.
const _LBFGS_SCRATCH = IdDict{Any, NamedTuple}()

function _lbfgs_scratch(template)
    key = (typeof(template), size(template))
    sc = get(_LBFGS_SCRATCH, key, nothing)
    if sc === nothing
        sc = (
            q=similar(template),
            psi_trial=similar(template),
        )
        _LBFGS_SCRATCH[key] = sc
    end
    return sc
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

"""Two-loop L-BFGS direction."""
function _lbfgs_direction(
    grad::AbstractArray{<:Complex},
    s_hist::Vector, y_hist::Vector, rho_hist::Vector{Float64},
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
        alphas[i] = rho_hist[i] * real(dot(s_hist[i], q))
        q .-= alphas[i] .* y_hist[i]
    end

    if m > 0
        ys = real(dot(y_hist[end], s_hist[end]))
        yy = real(sum(abs2, y_hist[end]))
        γ = ys / max(yy, 1e-30)
        q .*= γ
    end

    for i in 1:m
        β = rho_hist[i] * real(dot(y_hist[i], q))
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
    psi_trial = _lbfgs_scratch(psi).psi_trial

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
