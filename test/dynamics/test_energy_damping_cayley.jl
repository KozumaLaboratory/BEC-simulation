using Test
using FFTW
using SpinorBEC

# Energy damping must conserve number, and the midpoint form is how.
#
# The term is d(psi) = -i P{psi V_eps} dt with the projector on the PRODUCT. With P
# self-adjoint, psi in C and V_eps real,
#
#   dN/dt = 2 Re[-i int psi* P{psi V_eps}] = 2 Re[-i int |psi|^2 V_eps] = 0
#
# exactly, in ANY basis. I concluded this needed the spectral-Galerkin representation and
# that was wrong; P(i phi)P restricted to C is skew-Hermitian and the Cayley transform of
# a skew-Hermitian operator is unitary.
#
# The two forms that fail, both measured on the cluster:
#   psi *= cis(phi)   stable, pointwise norm-preserving, but a FINITE rotation whose
#                     out-of-band weight the caller's projector deletes: 4.53e-3 per unit
#                     time, FLAT across dt 0.02 -> 0.001 (0.06% over a factor of 20)
#   psi += i phi psi  the projector's form, 2.45e-3, but explicit where the literature
#                     uses a weak semi-implicit Euler for exactly this reason
@testset "energy damping, midpoint (Cayley) form" begin
    n, L, c0, T = 48, 12.0, 0.05, 6.0
    eps_cut = 1.5 + 3T
    k_cut = sqrt(2eps_cut)
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    dV = cell_volume(grid)
    @test π * n / L > k_cut

    function seeded(dt)
        sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
            potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
            fft_flags=FFTW.ESTIMATE)
        hp = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
        h = zeros(ComplexF64, size(ws.state.psi))
        thermal_cfield!(h, grid, hp; T, mu=1.5, c0, k_cut, seed=515)
        copyto!(ws.state.psi, h)
        # INTO C before anything is measured. thermal_cfield! low-passes at k_cut and
        # then multiplies by the density envelope in REAL space, which broadens the
        # spectrum past the cutoff — on this configuration N = 699 -> 340, so more than
        # half the seed is outside C. Without this the first projection removes it, ONCE,
        # and every rate computed afterwards is that one-time loss divided by the run
        # length. That confound is what made the exponential's loss look independent of
        # dt: N_end was 664.759 / 664.762 / 664.729 / 664.743 for 1000 / 2000 / 4000 /
        # 10000 steps, four digits identical across a factor of ten in step count, which
        # no per-step process can produce.
        apply_projected_gp!(ws, k_cut)
        ws
    end
    N_of(w) = real(sum(abs2, w.state.psi)) * dV

    # Loss per unit TIME, with the caller's projector in the path exactly as production
    # has it. Per unit time and not per step: a per-step figure shrinks with dt for free.
    function loss_rate(; dt, iters, t_total=10.0, noise=false)
        w = seeded(dt)
        N0 = N_of(w)
        for s in 1:round(Int, t_total / dt)
            apply_energy_damping_step!(w, 0.05, T, dt; seed=7000 + s, noise, k_cut,
                cayley_iters=iters)
            apply_projected_gp!(w, k_cut)
        end
        (N0 - N_of(w)) / (N0 * t_total)
    end

    @testset "the exponential's loss is O(dt) — discretisation, not a defect" begin
        # Measured with the seed in C: 2.57e-4 at dt = 0.02 and 6.47e-5 at dt = 0.005,
        # a factor of four for a factor of four. I had called this loss a broken term on
        # the strength of a "flat in dt" reading that came from the confound above.
        e = [loss_rate(; dt, iters=0) for dt in (0.02, 0.005)]
        @info "exponential loss per unit time" dt02=e[1] dt005=e[2]
        @test e[1] > 0                                  # it does lose — the premise
        @test e[2] < 0.5 * e[1]                         # and the loss converges away
    end

    @testset "the midpoint form conserves to rounding" begin
        # -2.6e-9 per step measured, sign flipped: the projected phase operator P(i phi)P
        # is skew-Hermitian on C, so its Cayley transform is unitary and this holds in ANY
        # basis. The spectral-Galerkin representation is not required for it, which is
        # what I concluded and had wrong.
        cay = loss_rate(; dt=0.02, iters=2)
        expo = loss_rate(; dt=0.02, iters=0)
        @info "midpoint vs exponential at dt = 0.02" cayley=cay exponential=expo
        @test abs(cay) < 0.05 * abs(expo)
        @test abs(cay) < 1e-5                           # absolute, not just relative
    end

    @testset "it is stable, which the explicit form was accused of failing" begin
        # The accusation was mine and it was wrong — the NaN came from eps(Inf) in my own
        # band-limit buffer. So stability is asserted here rather than assumed either way.
        w = seeded(0.02)
        for s in 1:5000
            apply_energy_damping_step!(w, 0.05, T, 0.02; seed=8000 + s, noise=true,
                k_cut, cayley_iters=2)
            apply_projected_gp!(w, k_cut)
        end
        Nf = N_of(w)
        @test isfinite(Nf)
        @test all(isfinite, w.state.psi)
        @test 0.1 * 698 < Nf < 10 * 698      # neither drained nor blown up
    end

    @testset "the Picard sweep count converges" begin
        # iters is a real knob, so its convergence is measured rather than declared
        # adequate. The requirement is that adding a sweep stops changing the answer,
        # not that more sweeps monotonically improve it — the residual is at rounding
        # level, where monotonicity is not available to assert.
        l = [loss_rate(; dt=0.02, iters=i) for i in (1, 2, 3)]
        @info "loss vs Picard sweeps" one=l[1] two=l[2] three=l[3]
        @test all(x -> abs(x) < 1e-4, l)
        @test abs(l[3] - l[2]) <= abs(l[2] - l[1]) + 1e-9
    end
end
