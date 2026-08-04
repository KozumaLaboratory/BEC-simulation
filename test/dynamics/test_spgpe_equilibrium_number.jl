using Test
using FFTW
using SpinorBEC

# What atom number does the SPGPE actually equilibrate to, and does the closed
# form used to size runs agree with it?
#
# In a trap at mu = 15, T = 80 the run reaches N = 1.85e4 from BOTH directions —
# growing from vacuum and decaying from a seed of 1.24e5 — while
# classical_field_equilibrium predicts 1.24e5. A factor of 6.7, and one of the
# two is wrong.
#
# The suspect is the cutoff convention. The projector cuts on |k|; the closed
# form cuts on the TOTAL energy k^2/2 + V + 2 c0 n, so its C region is smaller by
# the mean-field shift. Removing the trap makes the Rayleigh-Jeans prediction a
# plain mode sum with no local-density approximation in the way, and lets both
# conventions be evaluated against the same run.
#
# gamma is deliberately far above its physical value here: the EQUILIBRIUM does
# not depend on it, only the time taken to reach it, and the point is to reach it.
@testset "SPGPE equilibrium atom number vs the Rayleigh-Jeans mode sum" begin
    n, L = 48, 10.0
    mu, T, c0 = 15.0, 80.0, 0.19
    k_cut = sqrt(2 * (mu + T))
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    V = prod(grid.config.box_size)
    @test π / (L / n) > k_cut                      # the grid must resolve the cut

    # Prediction in the CODE's convention: occupation T/(eps - mu) per plane-wave
    # mode inside |k| < k_cut, with eps = k^2/2 + 2 c0 n, solved for n.
    function rj_modesum(nguess; iters=200)
        nn = nguess
        for _ in 1:iters
            s = 0.0
            for I in CartesianIndices(grid.config.n_points)
                k2 = grid.k_squared[I]
                k2 <= k_cut^2 || continue
                d = 0.5 * k2 + 2c0 * nn - mu
                d > 0 && (s += T / d)
            end
            nn = 0.5 * nn + 0.5 * (s / V)          # damped
        end
        nn * V
    end
    N_modesum = rj_modesum(50.0)

    # Prediction in the CLOSED FORM's convention: same physics, but the cut is on
    # total energy, so K = sqrt(2 (eps_cut - 2 c0 n)) < k_cut.
    eq = classical_field_equilibrium(; T, mu, c0, omega=0.0, rmax=L / 2, nr=200)
    N_closed = (eq.N0 + eq.Nth) * V / (4π / 3 * (L / 2)^3)   # its r-integral is a ball

    @test N_modesum > 0
    # The cutoff convention was the suspect and it is NOT the culprit: measured
    # 6.59e4 (mode sum, cut on |k|) against 5.91e4 (closed form, cut on total
    # energy), 12% apart, not the factor of 6.7 that has to be explained. So the
    # closed form is sound in the homogeneous limit and whatever is wrong is
    # either the run or the trapped local-density step.
    @test isapprox(N_modesum, N_closed; rtol=0.3)

    # The verdict, as a function of interaction strength. The SPGPE's exact
    # stationary distribution is P ∝ exp(−(H−μN)/T), the FULL interacting
    # classical-field measure; T/(ϵ_k−μ) is only its Hartree–Fock approximation
    # and becomes exact as c₀ → 0. So run the same box at three couplings: if the
    # ratio goes to 1 with c₀ the code is right and the closed form is merely
    # approximate, and if it does not the code is wrong.
    #
    # At the KZ parameters (c₀ = 0.19, c₀n = 28.6 against T = 80) the run sits
    # 2.29× above the mode sum, which is either a real 2.3× error or Hartree–Fock
    # failing at an interaction it has no right to describe.
    function run_equilibrium(c0_run; steps=8000, seed0=4200)
        sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0_run)),
            potential=HarmonicTrap{3}((0.0, 0.0, 0.0)),   # homogeneous
            sim_params=sp, fft_flags=FFTW.ESTIMATE)
        res = SPGPEReservoir(; T, mu, a_s=0.01, k_cut, gamma=0.05, M=0.0,
            allow_unphysical_rates=true)
        fill!(ws.state.psi, 0)
        dV = cell_volume(grid)
        N_hist = Float64[]
        for s in 1:steps
            split_step!(ws)
            apply_spgpe_step!(ws, res, 0.002; t=0.0, seed=seed0 + s)
            s % 1000 == 0 && push!(N_hist, real(sum(abs2, ws.state.psi)) * dV)
        end
        (; N=N_hist[end], settled=isapprox(N_hist[end], N_hist[end - 1]; rtol=0.1))
    end

    # Hartree–Fock prediction at the same coupling, in the code's convention.
    # Rayleigh-Jeans is the THERMAL prediction and only applies while there is
    # no condensate. Returns NaN + condensed=true otherwise rather than a number
    # that silently omits the largest term.
    function rj_at(c0_run)
        nn = 50.0
        for _ in 1:400
            s = 0.0
            for I in CartesianIndices(grid.config.n_points)
                k2 = grid.k_squared[I]
                k2 <= k_cut^2 || continue
                d = 0.5 * k2 + 2c0_run * nn - mu
                # `d <= 0` is NOT an absent mode to skip. It means mu sits above
                # the Hartree-Fock floor, which is a CONDENSATE — and skipping it
                # made this predictor report 2.2e5 where the run held 7.2e6, then
                # the run was blamed for the difference. Signal it.
                d > 0 || return (; N=NaN, condensed=true)
                s += T / d
            end
            nn = 0.5 * nn + 0.5 * (s / V)
        end
        (; N=nn * V, condensed=false)
    end

    # Weak coupling at mu = 15 is deeply CONDENSED, so the Thomas-Fermi number
    # mu*V/c0 is the prediction there and Rayleigh-Jeans does not apply at all.
    # That is the whole lesson: at c0 = 0.002 the run holds 7.2e6 against a
    # Thomas-Fermi 7.5e6, 4% low, while the thermal-only predictor said 2.2e5 —
    # and the 33x was charged to the code.
    #
    # `condensed` is the SELECTOR for which prediction applies, not a property all
    # three cells have. It used to be asserted of all three ("all three are
    # condensed") and c0 = 0.19 does not satisfy it: raising c0 lifts
    # d = k^2/2 + 2 c0 n - mu through the mean-field shift, so the d <= 0
    # condensate signal never fires there. That cell is the LEAST condensed of the
    # three, which is also why it is the one far from Thomas-Fermi.
    for c0_run in (0.19, 0.02, 0.002)
        r = run_equilibrium(c0_run)
        @test r.settled
        rj = rj_at(c0_run)
        N_TF = mu * V / c0_run
        @info "equilibrium" c0_run N_run=r.N N_TF ratio_TF=r.N / N_TF rj_applies=!rj.condensed N_rj=rj.N

        if rj.condensed
            # mu above the Hartree-Fock floor: the thermal-only sum does not
            # apply and Thomas-Fermi is what to check. Measured 0.876 (c0 = 0.02)
            # and 0.960 (c0 = 0.002), so 0.15 is the tolerance the data supports.
            # It was rtol = 1.0, which admits anything inside a factor of two and
            # passed the 1.91 below without objecting.
            @test r.N≈N_TF rtol=0.15
        else
            # c0 = 0.19 lands here and matches NEITHER convention: 2.29x the
            # Rayleigh-Jeans mode sum (150819 vs 65936) and 1.91x Thomas-Fermi
            # (vs 78947). The header's question — "one of the two is wrong" — is
            # still open at the strong-coupling end, and nothing here resolves it.
            #
            # `@test_broken` rather than a deleted cell or a loosened bound: the
            # discrepancy stays visible, stays measured, and turns the suite RED
            # the moment it closes, so whoever closes it is told.
            @test_broken r.N≈rj.N rtol=0.15
        end
    end
end
