"""
One place for "how do we plan an FFT?".

`FFTW.MEASURE` benchmarks candidate algorithms at plan time and keeps the fastest
one, so the algorithm — and therefore the SUMMATION ORDER of every transform —
depends on how loaded the machine was when the plan was built. Every quantity in
this codebase that is round-off-limited is then non-reproducible from one process
to the next. Measured on the L-BFGS projected-gradient floor, 128-point scalar
harmonic, `n_steps=120`, `tol=1e-8`, four fresh processes each:

    MEASURE    1.709e-8 | 2.130e-8 | 5.258e-8 | 1.709e-8   (E varies in its last
                                                            two digits)
    ESTIMATE   4.1453063004739704e-9 × 4                   (E identical to all
                                                            digits)

`ESTIMATE` picks by a heuristic and measures nothing, so it is deterministic.

Production keeps `MEASURE`: the plan is built once per workspace and the transform
runs millions of times, so the benchmark pays for itself. A TEST SUITE wants the
opposite — it builds hundreds of workspaces, runs few steps each, and needs its
numbers to be comparable across processes and across runs. So the flags are
overridable by `SPINORBEC_FFT_ESTIMATE=1`, which `test/runtests.jl` sets.

This does not make round-off-limited quantities meaningful; it makes them
REPRODUCIBLE, which is what lets a test distinguish "the code changed" from "the
plan changed". See `docs/conventions/testing_strategy.md`.
"""

"""
    default_fft_flags() -> UInt32

`FFTW.ESTIMATE` when `SPINORBEC_FFT_ESTIMATE` is set to a truthy value, otherwise
`FFTW.MEASURE`. Read at call time, not at load time, so a runner can set it after
the package is loaded.
"""
function default_fft_flags()
    v = lowercase(get(ENV, "SPINORBEC_FFT_ESTIMATE", ""))
    return v in ("1", "true", "yes") ? FFTW.ESTIMATE : FFTW.MEASURE
end
