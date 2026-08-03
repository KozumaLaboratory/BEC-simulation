# `initial_state: from_jld2` on the SPINOR ground_state step.
#
# The recipe already existed on the rotating_basis path; this gates the spinor
# path, where it is the mechanism for continuing a converged texture instead of
# re-converging it from a Gaussian. Two things can go silently wrong and both are
# checked here: the loaded ψ must actually be used (a silent fall-through to the
# Gaussian seed looks like a converged run, just a different one), and
# `init_state_params` carries a path/snap rather than Float64s, so the numeric
# params loop must not try to convert it.

using Test
using SpinorBEC
using JLD2

@testset "spinor ground_state from_jld2" begin
    dir = mktempdir()
    n, D = 8, 3                                   # F=1 → D=3
    psi_saved = randn(ComplexF64, n, n, n, D)
    top_level = joinpath(dir, "top_level.jld2")
    jldopen(top_level, "w") do f
        f["psi"] = psi_saved
    end

    @testset "top-level psi storage" begin
        loaded = SpinorBEC._load_psi_from_jld2(top_level, "last")
        @test size(loaded) == (n, n, n, D)
        @test loaded ≈ psi_saved
    end

    @testset "streamed snapshots, and `snap` indexing" begin
        streamed = joinpath(dir, "streamed.jld2")
        frames = [randn(ComplexF64, n, n, n, D) for _ in 1:3]
        jldopen(streamed, "w") do f
            f["dynamics/psi_snapshots_streamed/n_snapshots"] = 3
            for (k, fr) in enumerate(frames)
                f["dynamics/psi_snapshots_streamed/frame_" * lpad(k, 5, '0')] = fr
            end
        end
        @test SpinorBEC._load_psi_from_jld2(streamed, "last") ≈ frames[3]
        @test SpinorBEC._load_psi_from_jld2(streamed, 1) ≈ frames[1]
        @test SpinorBEC._load_psi_from_jld2(streamed, -1) ≈ frames[3]
        @test SpinorBEC._load_psi_from_jld2(streamed, -3) ≈ frames[1]
        @test_throws ArgumentError SpinorBEC._load_psi_from_jld2(streamed, 4)
        @test_throws ArgumentError SpinorBEC._load_psi_from_jld2(streamed, 0)
    end

    @testset "loud failure, never a silent Gaussian" begin
        @test_throws ArgumentError SpinorBEC._load_psi_from_jld2(
            joinpath(dir, "does_not_exist.jld2"), "last")

        empty_file = joinpath(dir, "empty.jld2")
        jldopen(empty_file, "w") do f
            f["something_else"] = 1
        end
        @test_throws ArgumentError SpinorBEC._load_psi_from_jld2(empty_file, "last")
    end

    _cfg_yaml(isp) = """
    pipeline:
      - ground_state:
          atom: Rb87
          F: 1
          interactions: {N_atoms: 1000, omega_ref: 100.0, c1_ratio: 0.0}
          grid: {n: [$n, $n, $n], box: [8.0, 8.0, 8.0]}
          potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
          initial_state: from_jld2
          init_state_params: {$isp}
          n_steps: 0
    """

    @testset "the spinor pipeline actually starts from the loaded ψ" begin
        # The seed here is SMOOTH — a Gaussian carrying an m-dependent phase
        # winding — and not the white noise used above. `_run_itp_loop!` applies
        # the Orszag 2/3 filter at entry, and white noise puts most of its weight
        # above that cut: measured overlap 0.83 for a random seed even though the
        # seed was honoured, which would make a tight threshold test the filter
        # rather than the seeding. A band-limited state passes the filter
        # untouched, so the assertion isolates what it is meant to.
        smooth = joinpath(dir, "smooth.jld2")
        xs = range(-4.0, 4.0; length=n)
        psi_smooth = Array{ComplexF64}(undef, n, n, n, D)
        for c in 1:D, k in 1:n, j in 1:n, i in 1:n
            r2 = xs[i]^2 + xs[j]^2 + xs[k]^2
            theta = atan(xs[j], xs[i])
            psi_smooth[i, j, k, c] = exp(-r2 / 4) * cis((c - 2) * theta)
        end
        jldopen(smooth, "w") do f
            f["psi"] = psi_smooth
        end

        # n_steps = 0, so the step hands back the state it was seeded with —
        # except that `_run_itp_loop!` applies the Orszag filter and one opening
        # V(dt/2) before the (empty) loop, which moves ψ by ~1 %. So the
        # assertion is DISCRIMINATING rather than tight: the `polar` seed is run
        # as a control arm, and the question is which state the output resembles.
        # Measured here: 0.9888 against the loaded ψ, 0.5582 for the control.
        # A tight bound would be testing the filter; this tests the seeding.
        overlap(a, b) =
            abs(sum(conj.(vec(a)) .* vec(b))) /
            (sqrt(sum(abs2, a)) * sqrt(sum(abs2, b)))

        psi_seeded = run_config(load_config_from_string(
            _cfg_yaml("path: $smooth, snap: last"))).psi
        control_yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              F: 1
              interactions: {N_atoms: 1000, omega_ref: 100.0, c1_ratio: 0.0}
              grid: {n: [$n, $n, $n], box: [8.0, 8.0, 8.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              initial_state: polar
              n_steps: 0
        """
        psi_control = run_config(load_config_from_string(control_yaml)).psi

        @test size(psi_seeded) == (n, n, n, D)
        @test overlap(psi_seeded, psi_smooth) > 0.95
        # The seeded run must resemble the file far more than the Gaussian does.
        @test overlap(psi_seeded, psi_smooth) >
            overlap(psi_control, psi_smooth) + 0.3
    end

    @testset "missing path is an error, not a fallback" begin
        cfg_bad = load_config_from_string(_cfg_yaml("snap: last"))
        @test_throws ArgumentError run_config(cfg_bad)
    end
end
