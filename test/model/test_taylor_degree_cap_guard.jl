# Gate: a clamped Horner degree cannot file an artifact under a production id.
#
# `SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE` is the one ambient `Ref` on a kernel
# path that cutover step 4 deliberately KEEPS. Freezing it would delete the only
# positive control `test/hamiltonian/test_taylor_tolerance_criterion.jl` has —
# `NegligibleErrorSpec` returns `:indeterminate` rather than `:pass` when the
# control cannot breach, and two weaker controls were tried and could not.
#
# But it is also the member of the group that most clearly moves an answer:
# `cap = 0` skips the Horner loop entirely, measured rel|Δψ| = 5.9e-2 over 4
# real-time steps and 2.8e-1 over 20 ITP steps. And it is in no `Stage`, because
# no run sets it — a field nobody sets is a field that rots. So the only way it
# can be wrong is a leaked assignment, and the answer to a leaked assignment is
# to refuse: an id that cannot express the question must not address the answer.
#
# The guard sits at `run_pipeline`, not at `find_ground_state`, on purpose. The
# criterion test drives the solver DIRECTLY and writes no artifact, so guarding
# there would break the control this Ref exists for.

using Test
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE, SPIN_TAYLOR_RK_MAX,
    _assert_taylor_degree_cap_unclamped, load_config, run_pipeline

const _CAP_PROBE = """
defaults: {kind: spinor, backend: cpu}
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [16], box: [8.0]}
      potential: {type: harmonic, omega: [1.0]}
      interactions: {N_atoms: 100, omega_ref: 100.0, c0: 1.0, c1: 0.0}
      ddi: {enabled: false}
      lhy: {kind: none}
      initial_state: polar
      method: itp
      n_steps: 5
      dt: 1.0e-3
      tol: 1.0e-6
"""

function _with_cap(f, k::Int)
    old = SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE[]
    SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE[] = k
    try
        f()
    finally
        SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE[] = old
    end
end

@testset "a clamped Taylor degree refuses to run a pipeline" begin
    # PINNED, not read back from the thing under test: the unclamped value is 40
    # because that is the declared ceiling, and if either number drifts this
    # gate must say so rather than agree.
    @test SPIN_TAYLOR_RK_MAX == 40
    @test SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE[] == 40

    @testset "the assertion itself" begin
        @test _assert_taylor_degree_cap_unclamped() === nothing
        for k in (0, 1, 2, 39)
            _with_cap(k) do
                err = try
                    _assert_taylor_degree_cap_unclamped()
                    nothing
                catch e
                    e
                end
                @test err isa ArgumentError
                # The message has to name the slot and the reason, or nobody can
                # act on it.
                @test occursin("SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE", err.msg)
                @test occursin(string(k), err.msg)
                @test occursin("artifact", err.msg)
            end
        end
        # Restored, including after the throws above.
        @test SPIN_TAYLOR_DEGREE_CAP_TEST_OVERRIDE[] == SPIN_TAYLOR_RK_MAX
    end

    @testset "and it is wired into run_pipeline" begin
        mktempdir() do dir
            path = joinpath(dir, "cap_probe.yaml")
            write(path, _CAP_PROBE)
            cfg = load_config(path)

            # RED arm: the guard is the first thing `run_pipeline` does, so this
            # throws before any solve — the arm costs nothing.
            _with_cap(0) do
                @test_throws ArgumentError run_pipeline(cfg; verbose=false)
            end

            # POSITIVE CONTROL. Without it, "it threw" says nothing about the
            # guard: a config that cannot run at all would throw either way.
            # The same call with the cap at its ceiling must complete and return
            # a ground state.
            res = run_pipeline(load_config(path); verbose=false)
            @test :psi in propertynames(res)
            @test res.psi isa AbstractArray
            @test all(isfinite, res.psi)
        end
    end
end
