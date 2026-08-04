#!/usr/bin/env julia
# Is `⟨ψ, H_term ψ⟩` free if it is accumulated inside the loop that applies the
# term?
#
#   julia --project=. bench/probe_inline_energy_accumulation.jl [cpu|gpu] [grid_n]
#
# The CPU L-BFGS iteration pays a whole energy pass (6.6 ms of ~30) that is
# redundant with the gradient pass: every GP term's energy is a fixed rational
# multiple of `⟨ψ, H_term ψ⟩` — 1 for the one-body terms, 1/2 for the
# density-quadratic ones (c0, c1, DDI, singlet, tensor), 2/5 for LHY, where
# `V = dε/dn` and `ε ∝ n^(5/2)`. So the energy could come out of the traversal
# that already forms `H·ψ`, the way it already does on the GPU.
#
# That is only worth building if the accumulation is close to free. There are
# ~14 terms; a separate reduction each is a ψ-sized streaming read per term, and
# at 24³ × D=13 that is ~0.25 ms a time — eight active terms would spend the
# whole 6.6 ms it is trying to save. The design only works if the dot rides
# along inside the elementwise loop that is already touching both arrays.
#
# So: measure the marginal cost of the accumulation, not the cost of the pass.
#   A: out .+= v .* psi                    (a diagonal term's apply_operator!)
#   B: the same, plus acc += real(conj(psi) * v * psi) in the same loop
#   C: A, then a SEPARATE real(dot(psi, out)) pass          (the naive way)
#
# B - A is what the protocol change costs per term. C - A is what it costs if
# done the obvious way. If B - A is not << C - A there is nothing to build.

const BACKEND_ARG = length(ARGS) >= 1 ? ARGS[1] : "cpu"
const GRID_N = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 24
const D = 13

if BACKEND_ARG == "gpu"
    @eval import CUDA
end

using LinearAlgebra: dot
using Printf

const TARGET = parse(Float64, get(ENV, "SBEC_PROBE_SECONDS", "3.0"))
const SYNC = BACKEND_ARG == "gpu" ? () -> CUDA.synchronize() : () -> nothing

function timed(f)
    f()
    SYNC()
    t1 = @elapsed (f(); SYNC())
    n = clamp(round(Int, TARGET / max(t1, 1.0e-6)), 5, 200_000)
    ts = Float64[]
    for _ in 1:n
        push!(ts, @elapsed (f(); SYNC()))
    end
    sort!(ts)
    (med=1000 * ts[(length(ts) + 1) ÷ 2], min=1000 * ts[1], n=n)
end

# --- CPU kernels: one pass over psi and v, writing out. -----------------------

function apply_only!(out::Array, v::Array, psi::Array)
    @inbounds @simd for i in eachindex(out, v, psi)
        out[i] += v[i] * psi[i]
    end
    out
end

function apply_and_accumulate!(out::Array, v::Array, psi::Array)
    acc = 0.0
    @inbounds @simd for i in eachindex(out, v, psi)
        h = v[i] * psi[i]
        out[i] += h
        acc += real(psi[i]) * real(h) + imag(psi[i]) * imag(h)
    end
    acc
end

function main()
    n_elem = GRID_N^3 * D
    mb = n_elem * 16 / 2^20
    println("inline-energy-accumulation probe — backend=$BACKEND_ARG, ",
        "$(GRID_N)^3 × D=$D = $n_elem elements ($(round(mb; digits=1)) MB per ψ), ",
        "threads=$(Threads.nthreads()), ",
        "OPENBLAS_NUM_THREADS=$(get(ENV, "OPENBLAS_NUM_THREADS", "unset"))")
    println("target per point: $(TARGET)s of repeats")
    println()

    if BACKEND_ARG == "gpu"
        psi = CUDA.rand(ComplexF64, n_elem)
        v = CUDA.rand(Float64, n_elem)
        out = CUDA.zeros(ComplexF64, n_elem)
        tA = timed(() -> (out .+= v .* psi))
        tB = timed(() -> (out .+= v .* psi; sum(real.(conj.(psi) .* (v .* psi)))))
        tC = timed(() -> (out .+= v .* psi; real(dot(psi, out))))
    else
        psi = rand(ComplexF64, n_elem)
        v = rand(Float64, n_elem)
        out = zeros(ComplexF64, n_elem)
        tA = timed(() -> apply_only!(out, v, psi))
        tB = timed(() -> apply_and_accumulate!(out, v, psi))
        tC = timed(() -> (apply_only!(out, v, psi); real(dot(psi, out))))
    end

    for (nm, t) in (("A apply only", tA), ("B apply + inline dot", tB),
        ("C apply, then separate dot", tC))
        @printf("  %-28s %8.4f ms  (min %7.4f, n=%d)\n", nm, t.med, t.min, t.n)
    end
    @printf("\n  inline overhead   B-A = %+.4f ms  (%.0f %% of A)\n",
        tB.med - tA.med, 100 * (tB.med - tA.med) / tA.med)
    @printf("  separate overhead C-A = %+.4f ms  (%.0f %% of A)\n",
        tC.med - tA.med, 100 * (tC.med - tA.med) / tA.med)

    # What it means for the thing being sized: eight active diagonal-ish terms.
    n_terms = 8
    @printf("\n  extrapolated to %d terms: inline %+.2f ms, separate %+.2f ms\n",
        n_terms, n_terms * (tB.med - tA.med), n_terms * (tC.med - tA.med))
    println("  (against a CPU energy pass of ~6.6 ms — the thing this would remove)")
end

main()
