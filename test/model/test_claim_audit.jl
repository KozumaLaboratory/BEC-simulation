# `verify_claim`: does the declared control switch anything off?
#
# `Claim`'s constructor insists a `:B`/`:C` claim DECLARED a control and says in
# its own comment that it cannot check the control actually fails. This file
# gates the half of that which needs no run — and, more importantly, gates the
# ways the check itself could be WRONG:
#
#   - too loose: a control differing only in `backend` / `method` / `dt` / `seed`
#     must be caught, because that is the bit-identical-A/B failure verbatim;
#   - too TIGHT: a control differing in an unrecognised `params` key must PASS.
#     That is not hypothetical politeness — it is the Klaus 2022 stir-tilt
#     control, the one well-formed control in the tree, which lives in
#     `Stage.params` because `Model` is spinor-shaped and the scalar eGPE path
#     cannot produce one. A gate that reddened on it would be switched off.
#
# and the one thing the audit must never claim: `checked_by_running` is `false`
# in every audit, so a structural pass can never be read as an experimental one.

using Test
using SpinorBEC
using SpinorBEC: Claim, claim, ClaimAudit, verify_claim, stage_differences,
    Stage, stage, Model, GridSpec, InteractionSpec, DDISpec, ATOM_REGISTRY, ref

_m(; c1=-0.1, c_dd=1.0) = Model(;
    grid=GridSpec(; ndim=3, n_points=(8, 8, 8), box=(6.0, 6.0, 6.0)),
    atom=ATOM_REGISTRY[:Eu151],
    interactions=InteractionSpec(; n_atoms=1000, omega_ref=691.15, c0=10.0, c1=c1),
    ddi=DDISpec(; c_dd=c_dd))

_st(m=_m(); method=:strang, backend=:cpu, params...) =
    stage(:evolve; model=m, method=method, backend=backend, params...)

@testset "verify_claim (structural: does the control switch anything off?)" begin
    @testset "stage_differences names the paths, in both directions" begin
        a = _st(; dt=0.001, theta=0.6)
        @test isempty(stage_differences(a, a))
        @test stage_differences(a, _st(; dt=0.002, theta=0.6)) == ["params.dt"]
        @test stage_differences(a, _st(; dt=0.001, theta=0.0)) == ["params.theta"]
        @test stage_differences(a, _st(; dt=0.001, theta=0.6, backend=:gpu)) ==
            ["backend"]
        @test stage_differences(a, _st(; dt=0.001, theta=0.6, method=:rk4ip)) ==
            ["method"]
        # a param present on one side only is a difference, not a silent match
        @test stage_differences(a, _st(; dt=0.001)) == ["params.theta"]
        # the model arm reports the FIELD, so a reader sees which physics moved
        @test stage_differences(a, _st(_m(; c_dd=0.0); dt=0.001, theta=0.6)) ==
            ["model.ddi"]
    end

    @testset "a well-formed control passes" begin
        ev = _st(; dt=0.001, theta=0.6)
        ct = _st(_m(; c_dd=0.0); dt=0.001, theta=0.6)   # DDI switched off
        a = verify_claim(
            claim("dipolar stripes need the DDI";
                kind=:B, evidence=Stage[ev], control=ct),
        )
        @test a.ok
        @test isempty(a.problems)
        @test a.differences[1] == ["model.ddi"]
    end

    @testset "TOO TIGHT is the failure that matters: an unlisted param passes" begin
        # The Klaus 2022 control. `theta` is not on `_NUMERICS_ONLY_PARAMS` and
        # must therefore count as physics-bearing — unrecognised means physics,
        # so the list can only ever quieten the gate, never redden it.
        ev = _st(; dt=0.001, theta=0.6)
        ct = _st(; dt=0.001, theta=0.0)
        a = verify_claim(
            claim("the stripe axis follows B"; kind=:B,
                evidence=Stage[ev], control=ct),
        )
        @test a.ok
        @test a.differences[1] == ["params.theta"]
    end

    @testset "numerics-only controls are refused" begin
        ev = _st(; dt=0.001, theta=0.6)
        for (label, ct) in [
            ("backend", _st(; dt=0.001, theta=0.6, backend=:gpu)),
            ("method", _st(; dt=0.001, theta=0.6, method=:rk4ip)),
            ("dt", _st(; dt=0.002, theta=0.6)),
            ("seed", _st(; dt=0.001, theta=0.6, seed=7)),
            ("several at once", _st(; dt=0.002, theta=0.6, backend=:gpu)),
        ]
            a = verify_claim(claim("x"; kind=:B, evidence=Stage[ev], control=ct))
            @test !a.ok
            @test any(p -> occursin("only in numerics", p), a.problems)
            @test !isempty(a.differences[1])   # it DID differ — just not in physics
        end
        # `seed` alone is the sharpest of these: a different realization is not a
        # control, and it is the one a reader is most likely to defend.
        a = verify_claim(
            claim("x"; kind=:B, evidence=Stage[ev],
                control=_st(; dt=0.001, theta=0.6, seed=7)),
        )
        @test occursin("params.seed", only(a.problems))
    end

    @testset "an identical control is refused, and says why" begin
        ev = _st(; dt=0.001, theta=0.6)
        a = verify_claim(claim("x"; kind=:B, evidence=Stage[ev], control=ev))
        @test !a.ok
        @test occursin("nothing is switched off", only(a.problems))
        @test isempty(a.differences[1])
    end

    @testset "empty evidence is refused HERE, not in the constructor" begin
        ct = _st(_m(; c_dd=0.0))
        c = claim("nothing has been computed yet"; kind=:B,
            evidence=Stage[], control=ct)   # constructs on purpose
        @test c isa Claim
        a = verify_claim(c)
        @test !a.ok
        @test occursin("no evidence", only(a.problems))
    end

    @testset "every evidence stage is audited, not just the first" begin
        good = _st(_m(; c_dd=0.0); dt=0.001)
        ev = Stage[_st(; dt=0.001), _st(_m(; c_dd=0.0); dt=0.002)]
        a = verify_claim(claim("x"; kind=:B, evidence=ev, control=good))
        @test !a.ok
        @test length(a.problems) == 1          # only the second arm is degenerate
        @test occursin("evidence[2]", only(a.problems))
        @test a.differences[1] == ["model.ddi"]
        @test a.differences[2] == ["params.dt"]
    end

    @testset ":A claims need no control, and are still audited for evidence" begin
        a = verify_claim(claim("GPU == CPU"; kind=:A, evidence=Stage[_st()]))
        @test a.ok
        @test isempty(a.differences)           # no control ⇒ nothing to diff
        @test !verify_claim(claim("GPU == CPU"; kind=:A, evidence=Stage[])).ok
    end

    @testset "a structural pass is never an experimental one" begin
        ev = _st(; dt=0.001, theta=0.6)
        ct = _st(; dt=0.001, theta=0.0)
        for c in (claim("x"; kind=:A, evidence=Stage[ev]),
            claim("y"; kind=:B, evidence=Stage[ev], control=ct),
            claim("z"; kind=:B, evidence=Stage[], control=ct))
            a = verify_claim(c)
            @test a.checked_by_running === false
            @test a.ok == isempty(a.problems)  # `ok` is derived, not settable
        end
    end

    @testset "the two layers compose: Klaus cannot reach an audit at all" begin
        # The real campaign, and the reason this testset is not a happy path.
        # Every row in `refs/klaus2022.toml` is `read_off` — the paper publishes
        # no re-measurable data record — so `arbitrates` is `false` for all of
        # them and the CONSTRUCTOR refuses a `:C` claim before `verify_claim`
        # ever sees one. Ω_c agreeing to 1.5 % is a real result and still not a
        # deciding comparison, and the tree is built so that saying otherwise
        # requires editing a fixture rather than writing a sentence.
        t = ref(:klaus2022, :omega_c_over_omega_perp)
        @test t.provenance === :read_off
        @test !t.arbitrates
        ev = _st(; dt=0.001, theta=0.6)
        ct = _st(; dt=0.001, theta=0.0)
        @test_throws ArgumentError claim("Omega_c reproduces Klaus et al. 2022";
            kind=:C, evidence=Stage[ev], control=ct, target=t)

        # The same evidence and control as a `:B` claim — physics agreement,
        # no published number arbitrating — is well formed, and that is the
        # honest kind for this campaign.
        a = verify_claim(
            claim("the stripe axis follows B and Omega_c is finite";
                kind=:B, evidence=Stage[ev], control=ct),
        )
        @test a.ok
        @test a.checked_by_running === false   # the 1.5 % is NOT established here
    end
end
