# Gate: the fused GPU k-space DDI contraction ≡ the three broadcasts it replaces.
#
# `Φ_α(k) = C · Q_αβ(k) · F_β(k)`. The GPU used to write it as one broadcast per
# α, each re-reading all three `F_β`; the kernel does one pass. The reference
# here is that broadcast form (`_ddi_k_contraction_bcast!`), which is what every
# GPU run took before — a comparison of realizations, not of formulas.
#
# Machine precision, not `==`: both arms are CUDA kernels, but one is
# hand-written and the other a chain of broadcasts, and NVPTX contracts `a*b+c*d`
# to fma at its own discretion. Asserting bit-identity across that boundary would
# assert a property of the backend rather than of this code — the same reasoning
# as `test_gpu_padded_corner_parity.jl`.
#
# `Q` is symmetric and the kernel exploits it (six components, sub-diagonal
# reads reuse Q_xy/Q_xz/Q_yz). The asymmetric-input case below is what would
# catch that being wrong: with Q_xy ≠ Q_yx the two arms would disagree, so
# feeding independent random Q components and still matching pins the symmetry
# assumption rather than hiding it.

using Test
using Random
import CUDA
using SpinorBEC
using SpinorBEC: _ddi_k_contraction_core!

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU DDI contraction parity"
else
    const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

    @testset "GPU DDI k-contraction: fused ≡ broadcast" begin
        @testset "eltype $T, rk shape $rk" for T in (Float64, Float32),
            rk in ((9, 16, 16), (5, 8, 1))

            rng = MersenneTwister(4242 + length(rk) + (T === Float32 ? 1 : 0))
            CT = Complex{T}
            F = ntuple(_ -> CUDA.CuArray(rand(rng, CT, rk...)), 3)
            # Independent random Q components — NOT built from a k̂ tensor — so a
            # kernel that silently assumed a different symmetry than the
            # broadcast form would show up here.
            Q = ntuple(_ -> CUDA.CuArray(rand(rng, T, rk...)), 6)
            C = T(0.37)

            ref = ntuple(_ -> CUDA.zeros(CT, rk...), 3)
            Ext._ddi_k_contraction_bcast!(ref..., F..., Q..., C)

            got = ntuple(_ -> CUDA.zeros(CT, rk...), 3)
            _ddi_k_contraction_core!(got..., F..., Q..., C, rk, false)
            CUDA.synchronize()

            for (nm, a, b) in (("Φx", got[1], ref[1]), ("Φy", got[2], ref[2]),
                ("Φz", got[3], ref[3]))
                ah, bh = Array(a), Array(b)
                scale = max(maximum(abs, bh), eps(T))
                @test maximum(abs, ah .- bh) <= 8 * eps(T) * scale
                @test !all(iszero, bh)     # the reference must not be trivial
            end
        end

        # End-to-end: the same workspace path a production run takes, so the
        # dispatch is exercised as well as the kernel.
        @testset "through the padded convolution" begin
            n = (8, 8, 8)
            grid = make_grid(GridConfig(n, (8.0, 8.0, 8.0)))
            D = 3
            psi0 = zeros(ComplexF64, n..., D)
            for I in CartesianIndices(n)
                env = exp(-sum(grid.x[d][I[d]]^2 for d in 1:3) / 4)
                psi0[I, 1] = env
                psi0[I, 2] = 0.6env * cis(0.4)
                psi0[I, 3] = 0.3env * cis(-0.9)
            end
            ws = make_workspace(;
                grid, atom=Na23,
                interactions=InteractionParams(Dict(0 => 5.0, 1 => -0.2)),
                potential=HarmonicTrap((1.0, 1.0, 1.0)),
                sim_params=SimParams(; dt=0.005, n_steps=1), psi_init=psi0,
                enable_ddi=true, c_dd=1.0, ddi_padding=true,
                backend=CUDABackend(),
            )
            ctx = ws.ddi_padded
            SpinorBEC._compute_and_convolve_ddi_padded!(
                ws.state.psi, ws.spin_matrices, ws.ddi, ctx, Val(D), 3, n)
            CUDA.synchronize()
            # The backward FFT only READS Phi_*_pad_rk, so these still hold what
            # the fused kernel wrote.
            fused = (Array(ctx.Phi_x_pad_rk), Array(ctx.Phi_y_pad_rk),
                Array(ctx.Phi_z_pad_rk))

            # Same F_rk the FFTs just produced, through the broadcast form.
            ref = ntuple(_ -> CUDA.zeros(eltype(ctx.Phi_x_pad_rk),
                    size(ctx.Phi_x_pad_rk)...), 3)
            Ext._ddi_k_contraction_bcast!(
                ref...,
                ctx.Fx_pad_rk, ctx.Fy_pad_rk, ctx.Fz_pad_rk,
                ctx.Q_xx, ctx.Q_xy, ctx.Q_xz, ctx.Q_yy, ctx.Q_yz, ctx.Q_zz,
                ws.ddi.C_dd / prod(size(ctx.Phi_x_pad)))
            CUDA.synchronize()

            for (a, r) in zip(fused, ref)
                b = Array(r)
                scale = max(maximum(abs, b), eps())
                @test maximum(abs, a .- b) <= 1e-12 * scale
                @test !all(iszero, b)
            end
        end
    end
end
