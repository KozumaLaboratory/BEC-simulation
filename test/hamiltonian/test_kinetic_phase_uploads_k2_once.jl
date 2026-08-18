using Test
using SpinorBEC
using SpinorBEC: _update_batched_kinetic_phase!, BatchedKineticCache,
    SCRATCH_REGISTRY

# The GPU branch must not re-upload k² on every call.
#
# `Grid.k_squared` is a host `Array` even for a GPU workspace, so when the
# kinetic phase buffer is device-resident the phase builder cannot broadcast it
# directly. It used to `similar` + `copyto!` a fresh device array EVERY CALL —
# 128³ Float64 = 16.0 MiB re-uploaded per call, of an array that never changes.
#
# Call frequency (the default `split_step!` does NOT call it — the phase is built
# once in `make_workspace` — which bounds the blast radius):
#   split_step_midpoint!   1x/step   (and the rotating_basis loop, unconditionally)
#   rk4ip_step!            1x/step
#   the Yoshida cores      3x/step
#   the Richardson loop    2x/step   (unguarded)
#
# `_to_device_cached`'s docstring in `foundation/backend.jl` names this exact k²
# re-upload as the defect it was written to remove. It was removed on the
# OPERATOR face (`terms/kinetic.jl` uses the cached form); the propagator face
# kept the uncached copy.
#
# THIS SUITE HAS NO GPU. It exercises the non-`Array` branch with a minimal
# AbstractArray wrapper — enough to prove the CACHING contract, which is what
# regressed. The device semantics are covered by `test/gpu/`.

"A non-`Array` AbstractArray, so `kp isa Array` is false and the else-branch runs."
struct NotAnArray{T, N} <: AbstractArray{T, N}
    data::Array{T, N}
end
Base.size(a::NotAnArray) = size(a.data)
Base.getindex(a::NotAnArray, i...) = getindex(a.data, i...)
Base.setindex!(a::NotAnArray, v, i...) = setindex!(a.data, v, i...)
Base.similar(::NotAnArray, ::Type{T}, dims::Dims) where {T} = Array{T}(undef, dims)

function fresh_cache(n)
    kp = NotAnArray(zeros(ComplexF64, n, n, n, 1))
    BatchedKineticCache(nothing, nothing, kp)
end

entries() =
    haskey(SCRATCH_REGISTRY, :kinetic_phase_k2) ?
    length(SCRATCH_REGISTRY[:kinetic_phase_k2]) : 0

@testset "the kinetic phase uploads k² once per array, not per call" begin
    haskey(SCRATCH_REGISTRY, :kinetic_phase_k2) &&
        empty!(SCRATCH_REGISTRY[:kinetic_phase_k2])

    n = 8
    k2 = [Float64(i + j + k) for i in 1:n, j in 1:n, k in 1:n]
    cache = fresh_cache(n)

    # CALIBRATION. If the else-branch were never taken — `kp isa Array` true, or
    # the function returning early — nothing would be cached and `entries()`
    # would stay 0, which is also what a *perfectly* cached implementation looks
    # like after zero calls. Establish the branch runs and does work first.
    @testset "the device branch is the one under test" begin
        @test !(cache.kinetic_phase_bc isa Array)
        @test entries() == 0
        _update_batched_kinetic_phase!(cache, k2, 0.01, false)
        @test entries() == 1
        # and it actually wrote a phase, rather than caching and doing nothing
        @test any(!iszero, cache.kinetic_phase_bc.data)
    end

    @testset "repeated calls reuse the same device array" begin
        before = SCRATCH_REGISTRY[:kinetic_phase_k2]
        obj = first(values(before))
        for dt in (0.02, 0.03, 0.04)
            _update_batched_kinetic_phase!(cache, k2, dt, false)
        end
        @test entries() == 1                       # no new upload per call
        @test first(values(SCRATCH_REGISTRY[:kinetic_phase_k2])) === obj
    end

    @testset "changing dt still changes the phase" begin
        _update_batched_kinetic_phase!(cache, k2, 0.01, false)
        a = copy(cache.kinetic_phase_bc.data)
        _update_batched_kinetic_phase!(cache, k2, 0.05, false)
        b = copy(cache.kinetic_phase_bc.data)
        # caching k² must not accidentally cache the PHASE
        @test maximum(abs, a .- b) > 1e-6
    end

    # NEGATIVE CONTROL, and the one that matters. A cache keyed on SIZE would
    # hand the second grid the first grid's k², which is the trap
    # `cached_kspace_filter` documents twenty lines above the fix. Two arrays of
    # equal shape and different values must get separate entries and separate
    # phases.
    @testset "a different k² of the same size is not served the first one" begin
        k2b = 2.0 .* k2
        cache2 = fresh_cache(n)
        _update_batched_kinetic_phase!(cache2, k2b, 0.01, false)
        @test entries() == 2

        ca = fresh_cache(n)
        cb = fresh_cache(n)
        _update_batched_kinetic_phase!(ca, k2, 0.01, false)
        _update_batched_kinetic_phase!(cb, k2b, 0.01, false)
        @test maximum(abs, ca.kinetic_phase_bc.data .- cb.kinetic_phase_bc.data) > 1e-6
    end

    # NO SOURCE SCAN. The first version asserted "no bare `copyto!(_, k_squared)`
    # remains" and flagged the fix itself: the copy is still there, inside the
    # cached factory, which is exactly where it belongs. Deciding whether a line
    # sits inside a `do` block from its text is re-implementing Julia's grammar
    # in a regex — the move that already produced a wrong tier count in this
    # tree. The behavioural arms above are strictly stronger anyway: the
    # uncached form never touches the registry, so `entries()` would be 0 and
    # the calibration arm fails. Verified by canary, both directions.

    haskey(SCRATCH_REGISTRY, :kinetic_phase_k2) &&
        empty!(SCRATCH_REGISTRY[:kinetic_phase_k2])
end
