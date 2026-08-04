using Test
using FFTW
using Random
using SpinorBEC

# The energy-damping reservoir composed with the projector — the production path,
# which the term's own unit test does not exercise.
#
# `apply_energy_damping_step!` multiplies by a phase. In isolation that conserves
# |psi|^2 to the last bit, and `test_spgpe.jl` checks exactly that by calling the
# function directly. But `apply_spgpe_step!` projects the STATE afterwards, and
# `P{}` in Eq. (4) acts on the INCREMENT. For the additive number-damping term the
# two are the same because the map is linear; for a multiplicative one they are
# not, and a rough phase — dU is white noise coloured only by 1/sqrt(|k|) —
# scatters weight past k_cut on every step for the projector to remove.
#
# Measured before the fix, at mu = -1, T = 1.026, k_cut = 2.01, dt = 0.05: the
# phase pushed 0.05% of the norm above the cutoff per step at Mbar = 0.01 and
# 0.53% at Mbar = 0.1, so over 20000 steps N fell 56.4 -> 1.6e-3 and 56.4 ->
# 1.2e-44. The same term without the projector held N to machine precision. The
# full SPGPE equilibrated to 55% of Thomas-Fermi as a result and every
# full-SPGPE measurement on this branch was retracted.
@testset "energy damping through the projector" begin
    mu, T, c0 = -1.0, 1.026, 0.0139
    k_cut = sqrt(2 * (1.0 + T))
    n, L = 256, 200.0
    grid = make_grid(GridConfig((n,), (L,)))
    plans = make_fft_plans((n,); flags=FFTW.ESTIMATE)

    function seeded_ws()
        sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Sr88,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
            potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
        buf = zeros(ComplexF64, n)
        rng = MersenneTwister(771)
        for i in 1:n
            buf[i] = randn(rng) + im * randn(rng)
        end
        plans.forward * buf
        for i in 1:n
            d = 0.5 * grid.k_squared[i] - mu
            buf[i] = grid.k_squared[i] > k_cut^2 ? 0 : buf[i] * sqrt(T / d)
        end
        plans.inverse * buf
        view(ws.state.psi, :, 1) .= buf
        ws
    end
    dV = cell_volume(grid)
    N_of(ws) = real(sum(abs2, ws.state.psi)) * dV

    @testset "the gamma = 0 loss is the measured rate, not zero" begin
        # This asserted survival > 0.9 and was RED when committed — it stated the
        # property I wanted rather than the one that holds. With gamma = 0 the loss
        # is real and irreducible in this representation: psi and the phase are both
        # band-limited, their product reaches 2 k_cut, and the caller's projector
        # removes the excess. Rooney, Blakie & Bradley PRE 89, 013302 keep only
        # C-region mode coefficients, so nothing leaks; on a full grid it does.
        #
        # Measured rate per unit time, flat across dt = 0.05, 0.01, 0.002 (0.0238,
        # 0.0250, 0.0243 at Mbar = 0.1) and linear in Mbar. So the honest gate is
        # that the rate MATCHES that, which catches both a regression that makes it
        # worse and a change that would silently make it better than measured.
        for (Md, expect) in ((0.01, 0.00238), (0.1, 0.0238))
            ws = seeded_ws()
            res = SPGPEReservoir(; T, mu, a_s=c0 / 2, k_cut, gamma=0.0, M=Md,
                allow_unphysical_rates=true)
            N0 = N_of(ws)
            t_run = 200.0
            for s in 1:round(Int, t_run / 0.05)
                apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=61_000 + s)
            end
            rate = -log(max(N_of(ws) / N0, 1e-300)) / t_run
            @test rate≈expect rtol=0.4
        end
    end

    @testset "band-limiting helps, and by how much depends on k_max/k_cut" begin
        # Canary for Eq. (15): pass k_cut = Inf to get the unrestricted 1/|k| kernel
        # and the loss must be materially worse. It matters HOW MUCH, and the first
        # version of this test got a null because it ran on the n = 256 grid, where
        # k_max = 2 k_cut and the grid already truncates most of what the band limit
        # would. On a grid with headroom (k_max = 4 k_cut) the rate differs 4.3x:
        #
        #   Mbar    raw 1/|k|    band-limited
        #   0.01    0.0104       0.0023
        #   0.1     0.1052       0.0243
        #
        # which is also the correction to a commit message: the 600x survival
        # improvement quoted for band-limiting spanned TWO changes — this one and
        # reverting the update from a second-order increment to the exact phase —
        # and was credited entirely to this one. Band-limiting is worth ~4.3x in the
        # rate; the rest came from the phase form. One change per measurement.
        big = make_grid(GridConfig((512,), (L,)))       # k_max = 4 k_cut
        bplans = make_fft_plans((512,); flags=FFTW.ESTIMATE)
        function big_ws()
            sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
                normalize_every=0)
            w = make_workspace(; grid=big, atom=Sr88,
                interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
                potential=HarmonicTrap{1}((0.0,)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            buf = zeros(ComplexF64, 512)
            rng = MersenneTwister(771)
            for i in 1:512
                buf[i] = randn(rng) + im * randn(rng)
            end
            bplans.forward * buf
            for i in 1:512
                buf[i] = if big.k_squared[i] > k_cut^2
                    0
                else
                    buf[i] * sqrt(T / (0.5 * big.k_squared[i] - mu))
                end
            end
            bplans.inverse * buf
            view(w.state.psi, :, 1) .= buf
            w
        end
        rates = map((Inf, k_cut)) do kc
            w = big_ws()
            dVb = cell_volume(big)
            N0 = real(sum(abs2, w.state.psi)) * dVb
            for s in 1:2000
                apply_energy_damping_step!(w, 0.1, T, 0.05; seed=61_000 + s, k_cut=kc)
                apply_projected_gp!(w, k_cut)
            end
            N1 = real(sum(abs2, w.state.psi)) * dVb
            -log(max(N1 / N0, 1e-300)) / (2000 * 0.05)
        end
        @test rates[1] > 2.5 * rates[2]
    end

    @testset "the equilibrium does not depend on Mbar" begin
        # The sharpest test of an SPGPE implementation, and the one this file's own
        # SPGPEReservoir docstring names (Rooney et al. SS III D 3 / III E 3):
        # both reservoir processes satisfy detailed balance with the same (mu, T),
        # so the stationary distribution is exp(-(H - mu N)/T) whatever Mbar is.
        # It had never been run. It fails at 55% before the fix.
        mu_c, γ = 1.0, 0.1
        N_TF = mu_c * L / c0
        Ns = map((0.0, γ)) do Md
            sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
                normalize_every=0)
            ws = make_workspace(; grid, atom=Sr88,
                interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
                potential=HarmonicTrap{1}((0.0,)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            res = SPGPEReservoir(; T, mu=mu_c, a_s=c0 / 2, k_cut, gamma=γ, M=Md,
                allow_unphysical_rates=true)
            fill!(ws.state.psi, 0)
            for s in 1:round(Int, (60.0 / (γ * mu_c)) / 0.05)
                split_step!(ws)
                apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=71_000 + s)
            end
            N_of(ws)
        end
        @test Ns[1]≈N_TF rtol=0.15          # number damping alone reaches Thomas-Fermi
        @test Ns[2] / Ns[1] > 0.85          # and energy damping must not move it
    end
end
