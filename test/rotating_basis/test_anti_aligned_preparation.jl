# The anti-aligned (Zeeman-highest) preparation, and why it needs the field
# reversed rather than a different seed.
#
# The EdH quench starts from the stretched state at the TOP of the Zeeman ladder.
# `runs/eu151_klaus_phi_phys/config.yaml` tried to get there with
# `init_m_idx: 13` and the run COMPLETED, returning ψ with 0 of 212992 entries
# non-zero and E = 0.0. Imaginary time is a projector onto the LOWEST state, so
# the highest one picks up `exp(-(E_max-E_min)·dt)` per step — exp(-1602) at
# p = 26700 — which underflows Float64 in one step. It is not a configuration
# that was wrong; it is not expressible by ITP at all.
#
# `prepare_anti_aligned: true` relaxes in the REVERSED field and hands the
# dynamics the requested one. The Zeeman-lowest state of -B is the Zeeman-highest
# state of +B, and it is a true ground state of the full interacting problem in
# the field it was relaxed in — not an excited state anyone constructed.
#
# WHAT THIS FILE PINS, and each one is a way the feature could be silently wrong:
#
#   1. It actually flips the state. sign(<F_z>) = -sign(p), against an ALIGNED
#      control arm in the same field that must come out the other way. A single
#      arm cannot distinguish "anti-aligned" from "the sign convention I assumed".
#   2. `q` does NOT flip. q ~ |B|^2 is even in the field; flipping it would relax
#      in a different quadratic Zeeman than the dynamics runs in, which is a
#      different Hamiltonian and not a reversed field.
#   3. The DYNAMICS gets the requested `p`, not the flipped one. If the handoff
#      carried p_itp the run would evolve in the reversed field and the whole
#      quench would be the aligned case wearing the other label.
#   4. The default seed follows the ITP field. Reading the requested `p` there
#      hands the anti-aligned path the one seed that field annihilates — the
#      underflow, reintroduced by the default.
#   5. The underflow still throws when nobody asked for the feature.

using SpinorBEC
using Test

const _F = 1
const _D = 2_F + 1

# F=1, 8³, contact only: the point is the DIRECTION the state ends up pointing,
# and that is decided by the Zeeman term. Cheap enough to run five arms.
function _gs(; p_z, q_z=0.0, n_steps=120, kwargs...)
    cfg = Dict{String, Any}(
        "grid" => Dict("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "interactions" => Dict("c0" => 5.0, "c1" => -0.1, "c_dd" => 0.0),
        "B" => Dict("p" => p_z, "q" => q_z),
        "F" => _F,
        "n_steps" => n_steps,
        "dt" => 0.01,
    )
    for (k, v) in kwargs
        cfg[String(k)] = v
    end
    _, _, _, _, res = SpinorBEC._run_rotating_basis_ground_state_step(cfg; verbose=false)
    res
end

@testset "anti-aligned prep flips the state, against an aligned control" begin
    # THE POSITIVE CONTROL IS THE ALIGNED ARM. `sign(<F_z>) = -sign(p)` alone is
    # satisfiable by a broken run that always returns the same thing; the pair is
    # what makes it a measurement. Both signs of p, so a convention error in the
    # test itself cannot pass both.
    for p_z in (2.0, -2.0)
        aligned = _gs(; p_z)
        anti = _gs(; p_z, prepare_anti_aligned=true)

        fz_al = aligned[:rotating_basis_fz_along_b]
        fz_an = anti[:rotating_basis_fz_along_b]

        @test sign(fz_al) == sign(p_z)      # H = -p F_z: m=+F is lowest at p>0
        @test sign(fz_an) == -sign(p_z)
        # Fully stretched at both ends, not merely leaning the right way.
        @test isapprox(abs(fz_al), _F; atol=0.05)
        @test isapprox(abs(fz_an), _F; atol=0.05)
        @test aligned[:rotating_basis_prepare_anti_aligned] == false
        @test anti[:rotating_basis_prepare_anti_aligned] == true
    end
end

@testset "the dynamics receives the REQUESTED field, not the reversed one" begin
    # Pin 3. If the handoff carried the ITP field the quench would run in the
    # reversed field and be the aligned case under the other name — a defect that
    # changes nothing visible in the ground state and everything downstream.
    p_z = 2.0
    anti = _gs(; p_z, prepare_anti_aligned=true)
    @test anti[:rotating_basis_gs].p == p_z
    @test anti[:rotating_basis_p_itp] == -p_z
    @test anti[:rotating_basis_gs].p != anti[:rotating_basis_p_itp]
end

@testset "q does not flip — it is even in B" begin
    # Pin 2. Relaxing under a reversed `q` is a different Hamiltonian, not a
    # reversed field, and it would move the state's transverse structure without
    # any of the other assertions here noticing.
    q_z = 0.3
    anti = _gs(; p_z=2.0, q_z, prepare_anti_aligned=true)
    @test anti[:rotating_basis_gs].q == q_z
end

@testset "the seed default follows the ITP field, not the requested one" begin
    # Pin 4. With no explicit `init_m_idx` and a large p, the anti-aligned path
    # must still converge: its default seed has to be the Zeeman-lowest state of
    # the REVERSED field. If the default read the requested `p` this arm is the
    # underflow, and the assertion below would be an ErrorException instead.
    anti = _gs(; p_z=40.0, prepare_anti_aligned=true, n_steps=60)
    @test sign(anti[:rotating_basis_fz_along_b]) == -1.0
    @test isfinite(anti[:ground_state_energy])
end

@testset "RED is reachable: the underflow still throws when nobody asked" begin
    # Pin 5, and the canary for the whole file. Seeding the Zeeman-HIGHEST state
    # in a strong field WITHOUT the flag is the original defect; it must be an
    # error and not a completed run returning zeros.
    #
    # THE FIELD HAS TO BE STRONG ENOUGH TO UNDERFLOW IN ONE STEP. The loop
    # renormalises every step, so a merely small factor is divided back out and
    # nothing ever reaches zero — `p = 400` here gives exp(-2·F·p·dt) = exp(-8)
    # and the arm completes happily, which is what this canary did on its first
    # run. Float64 underflows below exp(-708), so at F = 1 and dt = 0.01 the
    # threshold is p > 35400. The production config clears it by 2×: F = 6,
    # p = 26700, dt = 0.005 gives exp(-1602).
    #
    # That distinction is the defect, not an artifact of the test: a strong field
    # is survivable and a very strong one is not, and only the second is the
    # inexpressible case.
    err = try
        _gs(; p_z=50_000.0, init_m_idx=_D, n_steps=200)
        nothing
    catch e
        e
    end
    @test err isa ErrorException
    @test occursin("underflowed", err.msg)
    @test occursin("prepare_anti_aligned", err.msg)

    # And the same seed in the same field WITH the flag is fine — otherwise the
    # test above would pass for a build where nothing works at all.
    ok = _gs(; p_z=50_000.0, init_m_idx=_D, prepare_anti_aligned=true, n_steps=200)
    @test sign(ok[:rotating_basis_fz_along_b]) == -1.0
end

@testset "the directional gate can fail" begin
    # The runtime assertion inside the step is the last line of defence, so it
    # must be shown to be reachable. An ITP that runs zero steps cannot have
    # relaxed anywhere; asking for anti-alignment there is exactly the case where
    # silently returning the seed would be wrong — and the guard skips n_steps=0
    # by design, so this pins the DESIGNED skip rather than a hidden pass.
    z = _gs(; p_z=2.0, prepare_anti_aligned=true, n_steps=0)
    @test z[:ground_state_converged] == false
end
