# Real part of a complex inner product, as a blocked sequential reduction.
#
# Lives in foundation rather than with L-BFGS because it is a math primitive
# over arrays and `hamiltonian/terms/registry.jl` calls it too — a solver file
# is the wrong home for something the layer below depends on.

using LinearAlgebra: dot

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
