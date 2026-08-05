# Gate: the fused GPU diagonal kernel with a TABULATED LHY ≡ the generic
# broadcast propagator it replaces.
#
# Every `TabulatedLHY` used to miss the fused kernel's `c_lhy` type bound and
# fall to the generic broadcast path — 2D ≈ 26 launches plus a materialised
# V_LHY array, four times per ITP step. Measured on an H100 at 24³ Eu F=6:
# 0.336 ms/step with no LHY against 1.021 with a table, so 0.685 ms of that step
# was the fallback rather than the physics. Every production Eu run is tabulated,
# so this was the common case, not an edge one.
#
# The reference is the generic broadcast path, forced by calling
# `_diagonal_step_svec!` on an `AbstractArray`-typed view of the same device
# array so dispatch cannot pick the fused method. That is the code every GPU run
# took until now.
#
# Machine precision, not `==`, and for a specific reason: the two paths associate
# the Zeeman factor differently. The generic one puts `zee_rel` INSIDE the
# exponent, `exp(-(V + zee + c₀n + lhy)·dt)`; the fused kernel evaluates
# `exp(-(V + c₀n + lhy)·dt) · zph[c]` with the per-component factor precomputed —
# one transcendental per voxel instead of D. That is the same trade the scalar
# arm of this kernel already documents as machine-precision equivalent.
#
# The LOOKUP itself is shared: both call `_lhy_interp_uniform` on the same cached
# device table, so a disagreement there would be a disagreement of the function
# with itself. What this gate actually covers is the phase assembly and the
# dispatch — i.e. that the new method is reached and puts the table's V in the
# right place.

using Test
using Random
import CUDA
using SpinorBEC
using SpinorBEC: _diagonal_step_svec!, compute_spinor_lhy_polar_contact, _c0c1_to_gS

if !CUDA.functional()
    @info "CUDA not functional — skipping fused tabulated-LHY diagonal parity"
else
    @testset "fused diagonal with a tabulated LHY ≡ generic broadcast" begin
        F, D = 6, 13
        n_pts = (6, 6, 6)
        Ns = prod(n_pts)
        # A real table, not a synthetic one: the uniform-grid precondition and the
        # value range both have to be the ones production builds.
        lhy = compute_spinor_lhy_polar_contact(;
            F, g_dict=_c0c1_to_gS(F, 10.0, 0.1), n_max=6.0, n_points=200)

        @testset "IT=$it" for it in (false, true)
            rng = MersenneTwister(20260730 + (it ? 1 : 0))
            psi0 = CUDA.CuArray(randn(rng, ComplexF64, n_pts..., D))
            V = CUDA.CuArray(rand(rng, Float64, n_pts...))
            zee = SpinorBEC.SVector{D, Float64}(
                ntuple(c -> 0.3 * (F - (c - 1)), Val(D)))
            db_a = CUDA.zeros(Float64, n_pts...)
            db_b = CUDA.zeros(Float64, n_pts...)
            c0, dt = 4.0, 0.002

            # Fused: dispatch on the CuArray method just added.
            a = copy(psi0)
            _diagonal_step_svec!(Val(3), a, V, zee, c0, lhy, dt, db_a, it)

            # Reference: the generic AbstractArray method. `view(...)` of the whole
            # array is an AbstractArray but not a CuArray, so dispatch cannot pick
            # the fused method — this is the path every GPU run took before.
            b = copy(psi0)
            bv = view(b, axes(b)...)
            _diagonal_step_svec!(Val(3), bv, V, zee, c0, lhy, dt, db_b, it)
            CUDA.synchronize()

            ah, bh = Array(a), Array(b)
            scale = max(maximum(abs, bh), eps())
            @test maximum(abs, ah .- bh) <= 1e-12 * scale
            # The reference must actually have done something, or the comparison
            # is between two copies of the input.
            @test maximum(abs, bh .- Array(psi0)) > 1e-6 * scale

            # The density buffer is an output too, and a kernel that skipped it
            # would still pass the ψ comparison.
            @test Array(db_a) ≈ Array(db_b) rtol = 1e-13
            @test maximum(Array(db_a)) > 0

            # Positive control: the table must be REACHING the phase. Running the
            # same fused kernel with no LHY at all has to give a different state
            # — otherwise this gate would pass on a kernel that computed the
            # lookup and then dropped it, which is precisely the defect class
            # this path has had before (every tabulated GPU run silently ran with
            # c_lhy collapsed to 0.0 until 2026-07-28).
            c = copy(psi0)
            _diagonal_step_svec!(Val(3), c, V, zee, c0, nothing, dt,
                CUDA.zeros(Float64, n_pts...), it)
            CUDA.synchronize()
            @test maximum(abs, Array(c) .- ah) > 1e-6 * scale
        end
    end
end
