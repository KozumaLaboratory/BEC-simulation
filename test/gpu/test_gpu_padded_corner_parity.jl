# Gate: the zero-padded DDI layout is BIT-IDENTICAL to the contiguous one.
#
# Padded buffers are larger than `n_pts`, and three GPU hot-path branches used
# to key off that: the fused spin-density kernel fell back to a ≈37-launch
# broadcast, and the rotation materialised `phi[CartesianIndices(n_pts)]`. Both
# now read/write the corner through `_voxel_index`, i.e. the SAME kernel on both
# layouts. This file pins that the layout is what changed and not the numbers.
#
# Why the corner-write comparison is an oracle and not a self-check: the
# reference is `_spin_density_corner_bcast!`, an independently-written broadcast
# form that predates the fused kernel and is what the padded path actually ran
# until this change.
#
# Two different strengths, deliberately:
#
#   padded vs contiguous  — `==`. It is the SAME kernel over the same values;
#     only the destination/source index differs, so any difference at all is a
#     defect. A tolerance here would hide exactly the indexing bug the map
#     exists to prevent (App. A defect 9 — reading the first N_spatial LINEAR
#     elements walks the pad region for ndim ≥ 2).
#
#   fused vs broadcast    — machine precision, NOT `==`. Same arithmetic in the
#     same accumulation order, but one is a hand-written kernel and the other a
#     chain of broadcasts, and NVPTX contracts `a*b + c*d` to fma at its own
#     discretion. Asserting bit-identity across that boundary would be asserting
#     a property of the backend, not of this code.

using Test
using Random
import CUDA
using SpinorBEC

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU padded-corner parity"
else
    const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

    @testset "GPU padded corner ≡ contiguous" begin
        n_pts = (8, 8, 8)
        Ns = prod(n_pts)
        pad = (16, 16, 16)

        @testset "spin density: fused corner write ≡ broadcast corner write (F=$F)" for F in
                                                                                        (1, 6)
            sm = spin_matrices(F)
            D = 2F + 1
            rng = MersenneTwister(1234 + F)
            psi = CUDA.CuArray(randn(rng, ComplexF64, n_pts..., D))

            # Reference: the broadcast form the padded path used to take.
            rx = CUDA.zeros(Float64, pad...)
            ry = CUDA.zeros(Float64, pad...)
            rz = CUDA.zeros(Float64, pad...)
            Ext._spin_density_corner_bcast!(rx, ry, rz, psi, F, Val(D), 3, n_pts)

            # Under test: one fused launch writing the same corner.
            fx = CUDA.zeros(Float64, pad...)
            fy = CUDA.zeros(Float64, pad...)
            fz = CUDA.zeros(Float64, pad...)
            SpinorBEC._compute_spin_density!(fx, fy, fz, psi, sm, Val(D), 3, n_pts)
            CUDA.synchronize()

            # Independent-oracle half: machine precision, since NVPTX may
            # contract one form's mul+add to fma and not the other's.
            for (a, b) in ((fx, rx), (fy, ry), (fz, rz))
                ah, bh = Array(a), Array(b)
                scale = max(maximum(abs, bh), eps())
                @test maximum(abs, ah .- bh) <= 8 * eps() * scale
            end

            # Layout half: BIT-identical, because it is the same kernel with a
            # different destination index. This is the assertion that actually
            # constrains the index map; the pad-untouched check is its other
            # direction.
            cx = CUDA.zeros(Float64, n_pts...)
            cy = CUDA.zeros(Float64, n_pts...)
            cz = CUDA.zeros(Float64, n_pts...)
            SpinorBEC._compute_spin_density!(cx, cy, cz, psi, sm, Val(D), 3, n_pts)
            CUDA.synchronize()
            corner = CartesianIndices(n_pts)
            for (a, c) in ((fx, cx), (fy, cy), (fz, cz))
                ah = Array(a)
                @test ah[corner] == Array(c)
                @test ah[9, 1, 1] == 0.0          # first voxel past the corner
                @test count(!iszero, ah) <= Ns    # nothing written outside it
            end
        end

        @testset "DDI rotation: padded Φ in place ≡ cropped Φ (F=$F, IT=$it)" for F in
                                                                                  (1, 6),
            it in (false, true)

            sm = spin_matrices(F)
            D = 2F + 1
            rng = MersenneTwister(99 + F + (it ? 7 : 0))
            psi0 = CUDA.CuArray(randn(rng, ComplexF64, n_pts..., D))
            dt = 0.01

            # A padded Φ whose pad region is NONZERO. That is the discriminating
            # input: reading linearly instead of through the corner map picks up
            # these values, and a run with a zero pad would not notice.
            px = CUDA.CuArray(randn(rng, Float64, pad...))
            py = CUDA.CuArray(randn(rng, Float64, pad...))
            pz = CUDA.CuArray(randn(rng, Float64, pad...))
            corner = CartesianIndices(n_pts)
            cx = CUDA.CuArray(Array(px)[corner])
            cy = CUDA.CuArray(Array(py)[corner])
            cz = CUDA.CuArray(Array(pz)[corner])

            a = copy(psi0)
            SpinorBEC._apply_ddi_rotation!(a, px, py, pz, sm, dt, 3; imaginary_time=it)
            b = copy(psi0)
            SpinorBEC._apply_ddi_rotation!(b, cx, cy, cz, sm, dt, 3; imaginary_time=it)
            CUDA.synchronize()
            @test Array(a) == Array(b)

            # Positive control: the pad really is discriminating — a rotation
            # driven by the pad values instead of the corner gives a DIFFERENT
            # state, so the equality above is a constraint on the index map.
            wrong = CUDA.CuArray(reshape(Array(px)[1:Ns], n_pts))
            c = copy(psi0)
            SpinorBEC._apply_ddi_rotation!(c, wrong, cy, cz, sm, dt, 3; imaginary_time=it)
            CUDA.synchronize()
            @test Array(c) != Array(a)
        end
    end
end
