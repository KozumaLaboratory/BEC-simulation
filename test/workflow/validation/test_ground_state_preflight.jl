# Gate for the ground-state preflight.
#
# The point of the preflight is that each rule traces to one measurement, so the
# test pins the REFUSALS and — more importantly — that a clean setup still passes.
# A gate that refuses everything is indistinguishable from one that works, and
# this one sits in front of every ground state.

using Test
using SpinorBEC
using SpinorBEC: ground_state_preflight, print_preflight, passed

@testset "ground state preflight" begin
    ok_ip = InteractionParams(Dict(0 => 4687.3, 1 => -100.0))   # c₀ > 0, c₁ < 0
    bad_ip = InteractionParams(Dict(0 => -5859.1, 1 => 293.0))  # c₀ < 0: past −1/36

    @testset "a clean production setup PASSES" begin
        # The control. Without it every assertion below is satisfied by a
        # function that returns :fail unconditionally.
        r = ground_state_preflight(; interactions=ok_ip, c_dd=211.0,
            spinor_lhy=:polar_contact, method=:lbfgs)
        @test passed(r)
        @test occursin("clear", r.summary)
    end

    @testset "c₀ ≤ 0 is refused, and the pole is named" begin
        r = ground_state_preflight(; interactions=bad_ip, spinor_lhy=:polar_contact)
        @test !passed(r)
        @test occursin("ATTRACTIVE", r.summary)
        @test occursin("−1/F²", r.summary) || occursin("1/36", r.summary)
    end

    @testset "full_bdg with an active dipole is refused" begin
        r = ground_state_preflight(; interactions=ok_ip, c_dd=211.0,
            spinor_lhy=:full_bdg, method=:lbfgs)
        @test !passed(r)
        @test occursin("scheme-dependent", r.summary)
        # …and it is the DIPOLE that does it, not full_bdg itself.
        @test passed(
            ground_state_preflight(; interactions=ok_ip, c_dd=0.0,
                spinor_lhy=:full_bdg, method=:lbfgs),
        )
    end

    @testset "save_every above n_steps is refused" begin
        r = ground_state_preflight(; interactions=ok_ip, spinor_lhy=:polar_contact,
            method=:itp, n_steps=40000, save_every=10^9)
        @test !passed(r)
        @test occursin("NEVER", r.summary)
        # A sane cadence must not trip it — the rule is about the ratio, not
        # about save_every being present.
        r2 = ground_state_preflight(; interactions=ok_ip, spinor_lhy=:polar_contact,
            method=:itp, n_steps=40000, save_every=200)
        @test passed(r2)
    end

    @testset "ITP warns, and REFUSES when the run backs an accuracy claim" begin
        warn_only = ground_state_preflight(; interactions=ok_ip,
            spinor_lhy=:polar_contact, method=:itp)
        @test passed(warn_only)                       # a caveat, not a blocker
        @test occursin("O(dt)", warn_only.summary)

        claim = ground_state_preflight(; interactions=ok_ip,
            spinor_lhy=:polar_contact, method=:itp, accuracy_claim=true)
        @test !passed(claim)
        @test occursin("lbfgs", claim.summary)
        # L-BFGS under the same claim must pass, or the rule is "never make
        # claims" rather than "use the solver without a dt".
        @test passed(
            ground_state_preflight(; interactions=ok_ip,
                spinor_lhy=:polar_contact, method=:lbfgs, accuracy_claim=true),
        )
    end

    @testset "`:none` is flagged as non-neutral but does not block" begin
        r = ground_state_preflight(; interactions=ok_ip, spinor_lhy=:none,
            method=:lbfgs)
        @test passed(r)
        @test occursin("SHIPPED DEFAULT", r.summary)
    end

    @testset "the report states what it does NOT cover" begin
        buf = IOBuffer()
        print_preflight(
            ground_state_preflight(; interactions=ok_ip,
                spinor_lhy=:polar_contact, method=:lbfgs); io=buf)
        s = String(take!(buf))
        @test occursin("NOT covered", s)
        @test occursin("dt is STABLE", s)
    end
end
