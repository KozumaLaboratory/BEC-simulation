export make_grid, make_fft_plans, make_rfft_plans, rfft_output_shape
export cell_volume, n_spatial_points
export load_fftw_wisdom, save_fftw_wisdom
export fft_planning_memory_risk

function make_grid(
    config::GridConfig{N};
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    x = ntuple(N) do d
        n = config.n_points[d]
        L = T(config.box_size[d])
        dx = L / n
        collect(T, range(-L / 2 + dx / 2, L / 2 - dx / 2; length=n))
    end

    dx = ntuple(d -> T(config.box_size[d] / config.n_points[d]), N)

    k = ntuple(N) do d
        n = config.n_points[d]
        L = T(config.box_size[d])
        dk = T(2π) / L
        collect(T, fftfreq(n, n * dk))
    end

    dk = ntuple(d -> T(2π / config.box_size[d]), N)

    k_squared = _compute_k_squared(k, config.n_points)

    Grid{N, T}(config, x, dx, k, dk, k_squared)
end

function _compute_k_squared(
    k::NTuple{N, Vector{T}},
    n_points::NTuple{N, Int},
) where {N, T <: AbstractFloat}
    ksq = zeros(T, n_points)
    @inbounds for I in CartesianIndices(n_points)
        s = zero(T)
        for d in 1:N
            s += k[d][I[d]]^2
        end
        ksq[I] = s
    end
    ksq
end

# --- The FFTW MEASURE × Julia-threads × mixed-radix memory trap (#407) --------
#
# MEASURED 2026-08-21 on TSUBAME cpu_16, one process per point, `ru_maxrss`.
# `julia -t 16`, FFTW at 16 threads, `flags=MEASURE`, cubic complex in-place:
#
#   n     48     50     54     64     80     96     98     128
#   radix 2⁴·3   2·5²   2·3³   2⁶     2⁴·5   2⁵·3   2·7²   2⁷
#   RSS   1.66   2.40   3.01   0.35   4.26   6.73   11.97  0.38   GB
#
# **The only cheap sizes are the powers of two.** That is the whole of #407's
# paradox — "a 19× larger problem using 32× less memory at the same thread
# count" is arithmetic, because the larger problem (128) happens to be 2⁷ and
# the smaller one (48) is not. Among mixed-radix sizes RSS grows with n, exactly
# as a per-thread scratch story predicts.
#
# THREE THINGS ARE REQUIRED and removing any one removes the effect:
#   * `MEASURE` (or `PATIENT`). At `ESTIMATE` every size above is 0.33-0.36 GB.
#   * REAL Julia threads. At `julia -t 1` with FFTW still reporting 16 threads,
#     every size above is 0.26-0.30 GB — FFTW.jl dispatches its parallel loop
#     through Julia's threadpool, so `-t 1` serialises the planner and nothing
#     allocates per worker. This is the axis #407 did not have, and a probe run
#     at `-t 1` reports a clean flat null about a configuration nobody ran.
#   * a transform length that is not a power of two.
#
# REFUTED, by the taskset arm: #407's hypothesis was that a library reads
# `/proc/cpuinfo` (384 here) rather than the cgroup (16). Narrowing the visible
# set to 16 CPUs does NOT fix it — 48³ still takes 2.26 GB and 96³ 8.38 GB with
# the affinity mask at 16. The count was never the mechanism.
#
# WHY THIS FUNCTION AND NOT THE CALLER. `make_fft_plans` and `make_rfft_plans`
# default to `MEASURE`, and `analysis/dipole_field.jl:104` plans the DIPOLAR
# work shape that way — the path every eGPE ground state runs. The advisory is
# therefore here, once, rather than at the ~20 call sites.
#
# NOT auto-downgraded to `ESTIMATE`. Silently changing the planner would change
# the throughput of every production run to fix a configuration that is
# recognisable in advance, and this probe measured one call rather than
# steady-state throughput, so it does not license that trade. Set
# `SPINORBEC_FFT_PLAN=estimate` to take it deliberately.

"A transform length FFTW plans cheaply: a pure power of two."
_is_pow2(n::Integer) = n > 0 && (n & (n - 1)) == 0

"""
    fft_planning_memory_risk(shape; flags, fftw_threads, julia_threads) -> Bool

Whether this plan is about to enter the measured `MEASURE × Julia threads ×
mixed radix` corner (#407), where `ru_maxrss` reached 11.97 GB for a single 98³
plan. A pure predicate so a test can pin it without allocating gigabytes.
"""
function fft_planning_memory_risk(shape::NTuple{N, Int};
    flags=FFTW.MEASURE,
    fftw_threads::Int=FFTW.get_num_threads(),
    julia_threads::Int=Threads.nthreads()) where {N}
    (flags == FFTW.MEASURE || flags == FFTW.PATIENT) || return false
    fftw_threads > 1 || return false
    julia_threads > 1 || return false
    any(!_is_pow2, shape)
end

"`SPINORBEC_FFT_PLAN=estimate` downgrades the planner deliberately; anything else leaves `flags` alone."
function _fft_flags_override(flags)
    lowercase(strip(get(ENV, "SPINORBEC_FFT_PLAN", ""))) == "estimate" ?
    FFTW.ESTIMATE : flags
end

function _warn_fft_planning_memory(shape, flags)
    fft_planning_memory_risk(shape; flags) || return nothing
    @warn(
        "FFTW MEASURE planning of a NON-POWER-OF-TWO shape with real Julia " *
            "threads: measured up to 11.97 GB of resident memory for ONE plan " *
            "(98³; 6.73 GB at 96³, 1.66 GB at 48³, against 0.35 GB at 64³ and " *
            "0.38 GB at 128³). Three things are required and removing any one " *
            "removes it: MEASURE, `julia -t > 1`, and a mixed-radix length. " *
            "Set SPINORBEC_FFT_PLAN=estimate, or run the planner at `julia -t 1`, " *
            "or choose a power-of-two grid. See #407.",
        shape, flags, fftw_threads=FFTW.get_num_threads(),
        julia_threads=Threads.nthreads(), maxlog = 1,
    )
    nothing
end

function make_fft_plans(
    spatial_shape::NTuple{N, Int},
    backend::AbstractBackend=CPUBackend();
    flags=FFTW.MEASURE,
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    flags = _fft_flags_override(flags)
    backend isa CPUBackend && _warn_fft_planning_memory(spatial_shape, flags)
    buf = _zeros(backend, Complex{T}, spatial_shape...)
    kw = _fft_kwargs(backend, flags)
    fwd = plan_fft!(buf; kw...)
    inv = plan_ifft!(buf; kw...)
    FFTPlans(fwd, inv)
end

rfft_output_shape(n_pts::NTuple{N, Int}) where {N} = (n_pts[1] ÷ 2 + 1, n_pts[2:end]...)

function make_rfft_plans(
    spatial_shape::NTuple{N, Int},
    backend::AbstractBackend=CPUBackend();
    flags=FFTW.MEASURE,
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    flags = _fft_flags_override(flags)
    # The DDI work shape comes through here (`analysis/dipole_field.jl:104`),
    # and a zero-padded dipolar shape is mixed-radix whenever the base grid is.
    backend isa CPUBackend && _warn_fft_planning_memory(spatial_shape, flags)
    rk_shape = rfft_output_shape(spatial_shape)
    real_buf = _zeros(backend, T, spatial_shape...)
    complex_buf = _zeros(backend, Complex{T}, rk_shape...)
    kw = _fft_kwargs(backend, flags)
    fwd = plan_rfft(real_buf; kw...)
    inv = plan_irfft(complex_buf, spatial_shape[1]; kw...)
    RFFTPlans{N, typeof(fwd), typeof(inv)}(fwd, inv, rk_shape)
end

function cell_volume(grid::Grid{N}) where {N}
    prod(grid.dx)
end

function n_spatial_points(grid::Grid{N}) where {N}
    prod(grid.config.n_points)
end

function load_fftw_wisdom(path::AbstractString)
    isfile(path) && FFTW.import_wisdom(path)
end

function save_fftw_wisdom(path::AbstractString)
    FFTW.export_wisdom(path)
end
