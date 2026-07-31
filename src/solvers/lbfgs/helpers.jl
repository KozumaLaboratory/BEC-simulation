# L-BFGS internal helpers: Sobolev preconditioner + 2-loop direction
# update + line search.

# Scratch buffers for LBFGS direction update + line search + the curvature
# pair (s_k, y_k), backed by the shared scratch registry. Avoids
# per-iteration allocations that accumulated to GB-scale CUDA pool pressure
# during long LBFGS runs on GPU.
function _lbfgs_scratch(template)
    scratch_get!(:lbfgs, (typeof(template), size(template))) do
        (
            q=similar(template), psi_trial=similar(template),
            s_k=similar(template), y_k=similar(template),
        )
    end
end

function _sobolev_precondition!(
    grad::AbstractArray{<:Complex},
    ws::Workspace{N},
    k_squared_dev::AbstractArray{<:AbstractFloat},
    alpha::Float64,
) where {N}
    alpha > 0 || return grad
    α = real(eltype(k_squared_dev))(alpha)
    filt = cached_kspace_filter(
        k_squared_dev, :sobolev_precond, alpha, k2 -> inv(one(α) + α * k2)
    )
    return batched_kspace_filter!(grad, ws, filt)
end

"""
    _axpy!(a, c, b) → a

`a .+= c .* b` as an explicit `@simd` loop, for host arrays.

Bit-identical to the broadcast it replaces — same operations, same order.

It is NOT threaded, and that is a measurement, not an oversight: splitting
these across threads made the two-loop recursion 9.8 ms → 22.6 ms (4 threads)
→ 32.4 ms (48 threads) at 24³ × D=13. Each axpy is ~0.5 ms of real work and
there are `2m` of them per direction, so a `@threads` region per axpy is mostly
launch cost, and that cost grows with the thread count. See
`docs/design/lbfgs_iteration_cost.md`.
"""
function _axpy!(a::Array, c::Number, b::Array)
    @inbounds @simd for i in eachindex(a, b)
        a[i] += c * b[i]
    end
    return a
end

# Device arrays: the broadcast is already the parallel form.
_axpy!(a, c, b) = (a .+= c .* b)

# Number of blocks the real-dot reduction is cut into. Blocking is here for
# ACCURACY (one level of pairwise summation), not for parallelism — nothing in
# this file is threaded, see `_axpy!`.
const _REALDOT_BLOCKS = 64

# Real part of ⟨a,b⟩ over `lo:hi`. `@simd` on purpose: a hand-unrolled scalar
# form (four independent accumulators, no `@simd`) measured 8.2 ms against BLAS
# `zdotc`'s 7.7 ms for the whole two-loop at 24³ × D=13 — the scalar loads alone
# gave the whole advantage back. The cost is that `@simd`'s reassociation
# depends on the machine's vector width, so the result is reproducible for a
# given binary + CPU but not across CPUs; `zdotc`, whose kernel is selected per
# CPU, was never machine-independent either.
@inline function _realdot_range(a, b, lo::Int, hi::Int)
    s = 0.0
    @inbounds @simd for i in lo:hi
        s += real(a[i]) * real(b[i]) + imag(a[i]) * imag(b[i])
    end
    return s
end

"""
    _realdot(a, b) → Float64

`real(dot(a, b))` as a sequential 64-block reduction: each block is summed with
`@simd`, then the 64 partials are added in index order.

**Why not `dot`.** `dot` on a `ComplexF64` array dispatches to OpenBLAS
`zdotc`, and OpenBLAS sizes its thread team from the machine's core count. On a
few-MB array that call is team wakeup and barrier with almost no arithmetic, so
its cost grows with the size of the node: the same L-BFGS iteration measured
156.6 ms with BLAS at 192 threads and 50.2 ms with `OPENBLAS_NUM_THREADS=1`.
The two-loop calls this `2m` times per direction, and `_project_constraints!`
twice per gradient. Not calling BLAS at all is the fix that needs no global
setting — pinning BLAS threads process-wide would also throttle the genuine
level-3 work elsewhere (dense `eigen` in the Bogoliubov solver).

**Accuracy.** Blocking a sum is one level of pairwise summation, so the error
bound improves from `O(n·eps)` to `O((n/64 + 64)·eps)`. The gate in
`test_lbfgs_fast_path_equivalence.jl` measures it against a `BigFloat`
reference on a deliberately ill-conditioned input and requires it to be no
worse than a sequential sum.

It is **not** bit-identical to the `zdotc` it replaces. Worth stating: this
solver sits close enough to the `sqrt(eps)` energy-gated floor that a change in
summation order moves the endpoint.
"""
function _realdot(a::Array, b::Array)
    n = length(a)
    n == 0 && return 0.0
    nb = min(_REALDOT_BLOCKS, n)
    chunk = cld(n, nb)
    s = 0.0
    @inbounds for t in 1:nb
        s += _realdot_range(a, b, (t - 1) * chunk + 1, min(t * chunk, n))
    end
    return s
end

# Device arrays: the existing reduction is already the parallel form.
_realdot(a, b) = real(dot(a, b))

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
        alphas[i] = rho_hist[i] * _realdot(s_hist[i], q) * dV
        # `q - a*y` and `q + (-a)*y` agree bit for bit: negating a float is
        # exact, so the sum rounds to the same value.
        _axpy!(q, -alphas[i], y_hist[i])
    end

    if m > 0
        # ⟨s,y⟩ is already stored: `rho_hist[i] = 1/(⟨s_i,y_i⟩·dV)` by
        # construction in the driver (and in the warm-start contract), so
        # recomputing the dot product was a full extra pass over two
        # ψ-sized arrays for a number we had.
        ys = 1.0 / (rho_hist[end] * dV)
        yy = _realdot(y_hist[end], y_hist[end])   # ≡ sum(abs2, y)
        γ = ys / max(yy, 1e-30)
        q .*= γ
    end

    for i in 1:m
        β = rho_hist[i] * _realdot(y_hist[i], q) * dV
        _axpy!(q, alphas[i] - β, s_hist[i])
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

Returns `(α, E, psi_accepted, n_eval)`. `psi_accepted` is the retracted iterate
at the accepted `α` (scratch-backed, valid until the next line search) so the
driver does not have to redo the step + retraction it already computed here. On
failure (`α = 0`) it is the untouched `psi`.

`n_eval` is how many TOTAL-ENERGY evaluations this call made. It is reported
because it, not any single kernel, is what sets the cost of an iteration: a
5-minute measurement of Eu-151 F=6 at 24³ put the iteration at ~245 ms against
a component sum of ~57 ms, and the only candidate for the missing ~190 ms is
this count being much larger than one. Retractions without an energy (the
expansion phase's final re-placement) are not counted — they are not evaluations.
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

    # Retraction alone. Split out from the energy so the expansion phase can
    # re-place the iterate at its best α without paying a second full energy
    # evaluation for a number it already has.
    retract! = function (α)
        psi_trial .= psi .+ α .* direction
        norm_sq = sum(abs2, psi_trial) * dV
        psi_trial ./= sqrt(norm_sq)
        if target_Mz !== nothing
            _normalize_psi_constrained!(psi_trial, grid, D, N_dim, target_Mz, F)
        end
        copyto!(ws.state.psi, psi_trial)
        nothing
    end
    n_eval = 0
    eval_energy = function (α)
        retract!(α)
        n_eval += 1
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
            last_α = α
            for _ in 1:max_expand
                α2 = best_α * grow
                E2 = eval_energy(α2)
                last_α = α2
                (E2 < best_E && accept(α2, E2)) || break
                best_α, best_E = α2, E2
            end
            # Re-place the iterate whenever the LAST evaluation was somewhere
            # other than `best_α`. The earlier guard was `best_α == α`, which is
            # TRUE in the common case that the very first trial doubling is
            # rejected — and then the workspace was left at that rejected step
            # while `best_E` described `α_init`. Only the retraction is needed
            # (`best_E` is already known), which is why this is `retract!` and
            # not the `eval_energy` the fix on main used.
            last_α == best_α || retract!(best_α)
            return best_α, best_E, psi_trial, n_eval
        end
        return α, E_trial, psi_trial, n_eval
    end

    # Backtracking from α_init.
    for _ in 1:max_iter
        α *= shrink
        E_trial = eval_energy(α)
        if accept(α, E_trial)
            return α, E_trial, psi_trial, n_eval
        end
    end
    # No sufficient decrease found — return zero step.
    (0.0, E0, psi, n_eval)
end
