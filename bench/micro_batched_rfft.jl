# Does cuFFT do better on ONE batched 3-field plan than on three separate ones?
#
# `bench/perf_targets.txt` lists this as the next unmeasured idea for the padded
# DDI convolution, and it is worth settling BEFORE the refactor it would need: a
# batched plan requires `DDIPaddedContext` to hold F and Φ as `(pad…, 3)` arrays
# instead of three separate ones, which is a struct change touching the rotation,
# the fused half-step and the contraction. Measuring the plan alone costs one
# short job and needs none of that.
#
# It also settles something my own profiler could NOT. `profile_ddi_convolve.jl`
# reports a "3× / 1×" ratio as an overhead-vs-bandwidth discriminator, but its
# single-transform arm is timed with a `CUDA.synchronize()` on both ends, so that
# arm carries a sync the three-transform arm amortises. The ratio is therefore
# contaminated and cannot answer this. Here BOTH arms are timed the same way,
# over the same bytes, inside one timed region — so the difference is the plan.
#
#   julia --project=. bench/micro_batched_rfft.jl [padded_n] [reps]

using Printf
import CUDA
using CUDA.CUFFT
using FFTW: plan_rfft, plan_brfft
using LinearAlgebra: mul!

const PAD_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const REPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 50

function paired_times(separate, batched, prepare, reps)
    samples = (Float64[], Float64[])
    for repetition in 1:reps
        # Alternate order to avoid systematically assigning clock/thermal drift
        # to one arm. Restore inputs outside the timed region: C2R may destroy
        # its input, and repeated unnormalised round trips overflow.
        for arm in (isodd(repetition) ? (1, 2) : (2, 1))
            prepare()
            CUDA.synchronize()
            t0 = time_ns()
            (arm == 1 ? separate : batched)()
            CUDA.synchronize()
            push!(samples[arm], (time_ns() - t0) * 1e-9)
        end
    end
    map(samples) do values
        sorted = sort(values)
        (best=first(sorted), median=(sorted[(reps + 1) ÷ 2] + sorted[(reps + 2) ÷ 2]) / 2)
    end
end

function max_relative_error(a, b)
    maximum(abs, a .- b) / max(maximum(abs, a), eps(Float64))
end

function check_transforms!(Fs, Rs, Fb, Rb, fwd_sep, fwd_bat, bwd_sep, bwd_bat, shape)
    fwd_sep()
    fwd_bat()
    forward_error = maximum(1:3) do c
        max_relative_error(Rs[c], selectdim(Rb, 4, c))
    end
    bwd_sep()
    bwd_bat()
    backward_error = maximum(1:3) do c
        max_relative_error(Fs[c], selectdim(Fb, 4, c))
    end
    @assert forward_error < 1e-12
    @assert backward_error < 1e-12
    @printf("  forward parity %.3e; inverse parity %.3e\n", forward_error, backward_error)
    nothing
end

function restore_real!(Fs, Fb, seed)
    copyto!(Fb, seed)
    for c in 1:3
        copyto!(Fs[c], selectdim(seed, 4, c))
    end
end

function restore_spectrum!(Rs, Rb, spectrum)
    copyto!(Rb, spectrum)
    for c in 1:3
        copyto!(Rs[c], selectdim(spectrum, 4, c))
    end
end

function run(pad_n)
    shape = (pad_n, pad_n, pad_n)
    rk = (pad_n ÷ 2 + 1, pad_n, pad_n)

    # Separate arms: three independent real arrays and one shared plan, exactly
    # what `DDIPaddedContext` holds today.
    Fs = ntuple(_ -> CUDA.rand(Float64, shape...), 3)
    Rs = ntuple(_ -> CUDA.zeros(ComplexF64, rk...), 3)
    p_sep = plan_rfft(Fs[1], 1:3)
    bp_sep = plan_brfft(Rs[1], pad_n, 1:3)

    # Batched arm: one (pad…, 3) array, one plan over the spatial dims.
    Fb = CUDA.rand(Float64, shape..., 3)
    Rb = CUDA.zeros(ComplexF64, rk..., 3)
    p_bat = plan_rfft(Fb, 1:3)
    bp_bat = plan_brfft(Rb, pad_n, 1:3)
    seed = copy(Fb)

    fwd_sep() =
        for c in 1:3
            mul!(Rs[c], p_sep, Fs[c])
        end
    fwd_bat() = mul!(Rb, p_bat, Fb)
    bwd_sep() =
        for c in 1:3
            mul!(Fs[c], bp_sep, Rs[c])
        end
    bwd_bat() = mul!(Fb, bp_bat, Rb)

    restore_real!(Fs, Fb, seed)
    check_transforms!(Fs, Rs, Fb, Rb, fwd_sep, fwd_bat, bwd_sep, bwd_bat, shape)
    restore_real!(Fs, Fb, seed)
    fwd_bat()
    spectrum = copy(Rb)
    for _ in 1:5
        restore_real!(Fs, Fb, seed)
        fwd_sep()
        fwd_bat()
        restore_spectrum!(Rs, Rb, spectrum)
        bwd_sep()
        bwd_bat()
    end

    fs, fb = paired_times(fwd_sep, fwd_bat, () -> restore_real!(Fs, Fb, seed), REPS)
    bs, bb = paired_times(bwd_sep, bwd_bat, () -> restore_spectrum!(Rs, Rb, spectrum), REPS)
    t_fs, t_fb, t_bs, t_bb = fs.best, fb.best, bs.best, bb.best

    bytes = 3 * (prod(shape) * 8 + prod(rk) * 16)
    @printf("\n  padded %d³ → rk %s   (3 fields move %.1f MB one way)\n",
        pad_n, string(rk), bytes / 2^20)
    @printf("  %-22s %10s %10s %9s\n", "", "separate", "batched", "speedup")
    @printf("  %-22s %9.1fµs %9.1fµs %8.3f\n", "rFFT forward ×3",
        t_fs * 1e6, t_fb * 1e6, t_fs / t_fb)
    @printf("  %-22s %9.1fµs %9.1fµs %8.3f\n", "brFFT backward ×3",
        t_bs * 1e6, t_bb * 1e6, t_bs / t_bb)
    @printf("  %-22s %9.1fµs %9.1fµs %8.3f\n", "both",
        (t_fs + t_bs) * 1e6, (t_fb + t_bb) * 1e6, (t_fs + t_bs) / (t_fb + t_bb))
    @printf("  median fwd speedup %.3f; backward %.3f\n",
        fs.median / fb.median, bs.median / bb.median)
    @printf("  bandwidth floor for both directions: %.1f µs at 3 TB/s\n",
        2 * bytes / 3e12 * 1e6)
end

println("="^72)
println("batched vs separate rFFT — $(CUDA.name(CUDA.device()))  reps=$REPS")
println("="^72)
println("""
A speedup near 1.0 means cuFFT already amortises what a batch would, and the
`DDIPaddedContext` field-type change it needs is not worth making. Well above 1.0
means the padded convolution is paying per-plan-invocation overhead that the
struct change removes.""")
for n in (PAD_N, 2PAD_N)
    run(n)
end
