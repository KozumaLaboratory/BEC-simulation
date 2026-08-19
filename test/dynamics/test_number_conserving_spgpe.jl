using Test
using FFTW
using SpinorBEC

# The closed loop: mu is set by the atoms outside the c-field, so N_0 comes OUT.
#
# The open loop is what made the evaporation verdict unanswerable. Prescribing mu
# prescribes N_0 — mu < eps_0 forbids a condensate, mu > eps_0 fixes its size through
# mu = eps_0 + c_0 n_0 — so the euv3 result tracked a one-parameter K_3 fit and
# flipped at K_3/fit ~ 0.3. Here mu is read back from the field every step.
@testset "number-conserving SPGPE" begin
    n, L, c0, T = 128, 40.0, 0.05, 5.0
    eps_cut = 8.0
    k_cut = sqrt(2 * eps_cut)
    grid = make_grid(GridConfig((n,), (L,)))
    dV = cell_volume(grid)

    function run_closed(N_total; steps=3000, seed0=4242)
        sp = SimParams(; dt=0.02, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Sr88,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
            potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
        mu_ref = Ref(0.0)
        bad = Ref(0)
        # c0 is REQUIRED. It was optional and defaulted to "return NaN", so a caller
        # that forgot it got a control loop that silently never updated mu — which is
        # exactly what this test hit: N_C identical across a 3x change in the total, and
        # every one of 150 callbacks unsatisfiable. An absent argument is missing, not a
        # default, and the fix is a MethodError rather than a quiet no-op.
        cb = number_conserving_callback(mu_ref, _ -> N_total, _ -> T, eps_cut;
            every=20, counter=bad, c0_lda=c0)
        res = SPGPEReservoir(; T, mu=FeedbackWaveform(mu_ref), a_s=0.02, k_cut,
            gamma=0.05, M=0.0, allow_unphysical_rates=true)
        fill!(ws.state.psi, 0)
        for s in 1:steps
            split_step!(ws)
            apply_spgpe_step!(ws, res, 0.02; t=0.0, seed=seed0 + s)
            cb(ws, s)
        end
        (; N_C=real(sum(abs2, ws.state.psi)) * dV, mu=mu_ref[], unsat=bad[])
    end

    @testset "the loop closes and mu ends finite" begin
        r = run_closed(600.0)
        @test isfinite(r.mu)
        @test r.N_C > 0
        # The whole point: N_C is not the input. It must not equal the total, and it
        # must not be zero either — an open loop with mu below eps_0 gives exactly 0.
        @test 0 < r.N_C < 600.0
    end

    @testset "N_C responds to the TOTAL, which is the control now" begin
        # Doubling the atoms the reservoir has to place must put more of them in the
        # c-field. Under a prescribed mu the c-field would not know the total changed.
        small = run_closed(300.0)
        large = run_closed(900.0)
        @test large.N_C > small.N_C
    end

    @testset "mu settles below the cutoff and the demand stays satisfiable" begin
        r = run_closed(600.0)
        @test r.mu < eps_cut
        # Unsatisfiable steps are counted, not clamped. A run that spends most of
        # itself unsatisfiable is not describing the experiment, and this is the
        # number that says so.
        @test r.unsat < 0.5 * (3000 ÷ 20)
    end

    @testset "the counter is not decorative" begin
        # Positive control for the NaN path: ask for more than the I region can hold
        # and every callback must count it, leaving mu untouched at its initial value.
        cap = incoherent_population(eps_cut - 1e-9, T, eps_cut)
        r = run_closed(10 * cap; steps=200)
        @test r.unsat == 200 ÷ 20
        @test r.mu == 0.0                      # never updated
    end
end
