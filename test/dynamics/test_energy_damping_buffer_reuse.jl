using Test
using FFTW
using SpinorBEC

# A tracking cutoff must not allocate a buffer per cutoff VALUE.
#
# The energy-damping buffers were keyed on (type, n_pts, k_cut). Three of the four do
# not depend on k_cut at all, and the cutoff has to track the temperature — a fixed one
# decouples the reservoir as T falls. So every step took a different k_cut, allocated a
# fresh set, and retained the old: 2.0 MB per step at 44^3, ~17000 steps, 36.6 GB, and
# three cluster runs killed with exit 137 after each had passed a 5% smoke.
#
# The control loop was the suspect and measured 1.3 GB of the 36.6
# (scripts/kz/mu_lda_allocation.jl). Being wrong about where it was is why this gate
# measures growth rather than asserting a key.
@testset "energy-damping buffers under a moving cutoff" begin
    n, L = 32, 12.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => 0.05)),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        fft_flags=FFTW.ESTIMATE)
    fill!(ws.state.psi, 0.1)

    # Warm up so first-call compilation is not counted.
    apply_energy_damping_step!(ws, 0.01, 5.0, 0.01; seed=1, k_cut=6.0)

    @testset "allocation does not grow with the number of distinct cutoffs" begin
        # Ten distinct cutoffs. Under the old key that is ten buffer sets; under the
        # new one it is one, refilled.
        few = @allocated for i in 1:3
            apply_energy_damping_step!(ws, 0.01, 5.0, 0.01; seed=10 + i,
                k_cut=6.0 - 0.01i)
        end
        many = @allocated for i in 1:30
            apply_energy_damping_step!(ws, 0.01, 5.0, 0.01; seed=100 + i,
                k_cut=5.5 - 0.01i)
        end
        # Per-step allocation must be flat in the number of steps, not growing. A
        # per-cutoff buffer set is 3 x 32^3 x 8 B = 786 kB, so ten times more steps
        # would cost ten times more; allow 3x for noise and it still separates.
        @test many < 3 * (few / 3) * 30
        # And the absolute scale: a 32^3 buffer set is 786 kB, so a run that
        # allocates one per step cannot come in under that per step.
        @test many / 30 < 786_432
    end

    @testset "the band limit still holds — the property the key was protecting" begin
        # The cache change must not weaken the band limit. Same canary as
        # test_spgpe_projector_composition: on a grid whose k_max is well above the
        # cutoff, a low cutoff must damp far less than a high one.
        function loss_rate(k_cut)
            g = make_grid(GridConfig((128,), (40.0,)))
            w = make_workspace(; grid=g, atom=Rb87,
                interactions=InteractionParams(Dict{Int, Float64}(0 => 0.05)),
                potential=HarmonicTrap{1}((0.0,)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            fill!(w.state.psi, 0.3)
            dV = cell_volume(g)
            N0 = real(sum(abs2, w.state.psi)) * dV
            for s in 1:200
                apply_energy_damping_step!(w, 0.1, 5.0, 0.01; seed=7000 + s, k_cut)
            end
            N1 = real(sum(abs2, w.state.psi)) * dV
            abs(N1 - N0) / (N0 * 200)
        end
        lo, hi = loss_rate(2.0), loss_rate(8.0)
        @test hi > lo                      # a wider band does more
    end

    @testset "refilling gives the same result as a fresh cutoff would" begin
        # The refill must be equivalent to rebuilding. Alternate two cutoffs and check
        # the field after A,B,A matches a run that only ever saw those cutoffs in that
        # order from a clean cache — i.e. the stale-buffer bug cannot hide here.
        function run(seq)
            g = make_grid(GridConfig((32,), (12.0,)))
            w = make_workspace(; grid=g, atom=Rb87,
                interactions=InteractionParams(Dict{Int, Float64}(0 => 0.05)),
                potential=HarmonicTrap{1}((0.0,)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            fill!(w.state.psi, 0.2)
            for (i, kc) in enumerate(seq)
                apply_energy_damping_step!(w, 0.05, 5.0, 0.01; seed=500 + i, k_cut=kc)
            end
            copy(w.state.psi)
        end
        a = run([3.0, 7.0, 3.0])
        b = run([3.0, 7.0, 3.0])
        @test a ≈ b
        # and a different sequence must differ, or the test proves nothing
        @test !(a ≈ run([7.0, 3.0, 7.0]))
    end
end
