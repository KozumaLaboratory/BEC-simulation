# `refs/klaus2022.toml` + `ref` — the quote boundary for the second paper.
#
# `refs/matsui2025.toml` says the directory should not be treated as a registry
# "before there is a second paper", because generalising early invents the
# requirement. Klaus 2022 is the second paper, and it turned out to need NO code
# change: `ref` / `_ref_doc` / `_known_sources` were already source-generic. So
# what this file gates is not a new mechanism — it is the CONSEQUENCE of adding
# a source whose paper ships no data.
#
# The load-bearing assertion is the refusal. `arbitrates` is derived as
# `measured && isempty(disqualified_by)`, so every `read_off` row is quotable and
# none can decide a comparison — and a `:C` Claim against one is therefore
# unconstructible. Klaus ship no re-measurable record, so every row is
# `read_off`, so **there is no type-C Klaus claim to be had** under this design.
#
# That refusal is the thing worth pinning, because routing around it is exactly
# what happened before this file existed: `scripts/klaus2022_reproduce.jl`
# carried the same four numbers as a bare `PUBLISHED` NamedTuple with no locus,
# no schema and no arbitration check, and compared against them anyway.

using Test
using SpinorBEC
using SpinorBEC: compute_a_dd, ATOM_REGISTRY, Units

@testset "refs/klaus2022.toml + ref" begin
    @testset "the source is registered and its rows resolve" begin
        qs = SpinorBEC.ref_quantities(:klaus2022)
        @test Set(qs) == Set([:omega_c_over_omega_perp, :ar_magnetostricted,
            :n_vortex_stripes, :a_dd_dy162])
        for q in qs
            r = ref(:klaus2022, q)
            @test r.source === :klaus2022
            @test r.quantity === q
            @test isfinite(r.value)
            @test !isempty(r.units)
            @test !isempty(r.locus)      # every row names where in the paper
            @test !isempty(r.note)
        end
        # An unregistered quantity is a named error, not a silent nothing.
        @test_throws ArgumentError ref(:klaus2022, :no_such_quantity)
    end

    @testset "the published literals" begin
        @test ref(:klaus2022, :omega_c_over_omega_perp).value == 0.74
        @test ref(:klaus2022, :ar_magnetostricted).value == 1.03
        @test ref(:klaus2022, :n_vortex_stripes).value == 3.0
        @test ref(:klaus2022, :a_dd_dy162).value == 129.2
    end

    @testset "nothing here arbitrates, and that is not vacuous" begin
        for q in SpinorBEC.ref_quantities(:klaus2022)
            r = ref(:klaus2022, q)
            @test r.provenance === :read_off
            @test r.arbitrates == false
        end
        # CALIBRATION. `arbitrates == false` above must be a fact about THESE
        # rows, not about the function. Matsui's measured, undisqualified row
        # does arbitrate — if this flips, the assertions above stop meaning
        # anything and start passing for free.
        @test ref(:matsui2025, :dip_width_exp_scanwindow_nT).arbitrates == true
    end

    @testset "a :C Klaus claim is REFUSED — the consequence of read_off" begin
        # A minimal but real Stage, so the refusal is exercised against the
        # actual constructor rather than a mock.
        m = Model(; grid=GridSpec(; ndim=1, n_points=(16,), box=(8.0,)),
            atom=ATOM_REGISTRY[:Na23],
            interactions=InteractionSpec(; n_atoms=1000, omega_ref=100.0,
                c0=10.0, c1=0.1),
            ddi=DDISpec(; c_dd=1.0))
        s = stage(:relax; model=m, method=:itp, dt=0.01, n_steps=10)
        ctrl = stage(:relax; model=with(m; ddi=DDISpec()), method=:itp,
            dt=0.01, n_steps=10)
        @test ctrl.model != s.model      # the control is the physics switched off

        for q in SpinorBEC.ref_quantities(:klaus2022)
            @test_throws ArgumentError Claim(
                "our magnetostirring reproduces Klaus et al. 2022",
                :C, Stage[s], ctrl, ref(:klaus2022, q))
        end

        # POSITIVE control for the same constructor: an arbitrating target
        # builds. Without this, "throws" could be a property of the call shape
        # (the Stage, the control, the statement) rather than of the target.
        ok = Claim("our Fig. 4B dip width reproduces Matsui et al.",
            :C, Stage[s], ctrl, ref(:matsui2025, :dip_width_exp_scanwindow_nT))
        @test ok.kind === :C
    end

    @testset "a_dd is the one row we can re-derive" begin
        # Their 129.2 a_0 against `compute_a_dd` on our own Dy162 entry. The
        # only independent check available for a paper with no data record, and
        # it is a check of the SPECIES — which has been got wrong on this path
        # before (test_klaus_validation.jl runs Dy164).
        ours = compute_a_dd(ATOM_REGISTRY[:Dy162]) / Units.BOHR_RADIUS
        @test ours ≈ ref(:klaus2022, :a_dd_dy162).value rtol = 3e-3
        # …and Dy164 does NOT match it, so the agreement above is about the
        # isotope and not about a_dd being roughly 129 for any dysprosium.
        theirs164 = compute_a_dd(ATOM_REGISTRY[:Dy164]) / Units.BOHR_RADIUS
        @test !isapprox(theirs164, ref(:klaus2022, :a_dd_dy162).value; rtol=3e-3)
    end

    @testset "a_s is deliberately NOT registered" begin
        # Their a_s = 111(9) a_0 was fitted against simulations of this same
        # family (Methods A.3), and `read_off` rows cannot carry
        # `disqualified_by` to say so — it is in `_REF_KEYS_MEASURED` only.
        # Registering it would put an input authority one `ref` call away with
        # only prose guarding it. Pinned so that adding it is a decision someone
        # makes with this comment in front of them.
        @test !(:a_s_dy162 in SpinorBEC.ref_quantities(:klaus2022))
        @test !any(q -> occursin("a_s", String(q)),
            SpinorBEC.ref_quantities(:klaus2022))
    end
end
