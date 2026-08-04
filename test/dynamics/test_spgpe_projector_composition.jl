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

    @testset "N survives the composed step" begin
        # gamma = 0, so the ONLY reservoir process is number-conserving and the
        # atom number may not decay. 4000 steps is long enough that the historical
        # 0.5%/step would leave 1e-9 of the field; the term's own test ran 20 steps,
        # where the same defect costs 10% and passes a 1e-13 tolerance on nothing.
        for Md in (0.01, 0.1)
            ws = seeded_ws()
            res = SPGPEReservoir(; T, mu, a_s=c0 / 2, k_cut, gamma=0.0, M=Md,
                allow_unphysical_rates=true)
            N0 = N_of(ws)
            for s in 1:4000
                apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=61_000 + s)
            end
            @test N_of(ws) / N0 > 0.9
        end
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
