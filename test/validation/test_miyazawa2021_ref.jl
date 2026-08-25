# `refs/miyazawa2021.toml` + `ref` — the third source, and the first one added
# because a LIVE CLAIM needed it rather than because the paper was interesting.
#
# Measured 2026-08-25: the claim ledger's six type-C rows had zero anchors between
# them, and five of the six lean on this thesis. The two sources already
# registered arbitrate nothing in the ledger. So the direction is the one
# `CAMPAIGN.md` §14 states — reproduction is pulled by claims, not pushed by the
# literature — and this file is the first instance of it.
#
# WHAT IS WORTH PINNING HERE, given that `test_klaus2022_ref.jl` already pins the
# read_off refusal for a paper with no data record:
#
#   1. The a_s TRAP. The thesis says 135 a_0; production uses 110(4) from a later
#      published measurement. Every thesis-derived number was extracted USING 135,
#      so the dependency has to be carried, and the row must not be reachable
#      under the obvious name.
#   2. The DIRECTION of the K_3 comparison. `eu-evap-k3-outside-universal-vdw-band`
#      needs 2.45e-40 m^6/s; the thesis gives ~1e-41, inside the universal band.
#      A reader who hears "the thesis measured K_3" will assume the gap closes. It
#      does not, and the factor is asserted here so that assumption cannot survive
#      contact with the suite.
#   3. That the EXPONENT agrees with an independently derived claim. The thesis
#      fits dN/dt = -gamma*N^(9/5) with solution N ~ t^(-5/4); this repository
#      derived the same attractor from the Thomas-Fermi <n^2> moment. Cross-source
#      agreement on a power law is the cheapest confirmation available and it is
#      free here.

using Test
using SpinorBEC
using SpinorBEC: claim_ledger, claim_by_id

@testset "refs/miyazawa2021.toml + ref" begin
    @testset "the source is registered and every row resolves" begin
        qs = ref_quantities(:miyazawa2021)
        @test Set(qs) == Set([
            :alpha_scalar_1550nm, :velocity_ratio_parallel_perp, :eps_dd_thesis,
            :a_s_thesis, :omega_bar_bec, :tau_3body_initial, :three_body_L,
        ])
        for q in qs
            r = ref(:miyazawa2021, q)
            @test r.source === :miyazawa2021
            @test r.quantity === q
            @test isfinite(r.value)
            @test !isempty(r.units)
            @test !isempty(r.locus)     # every row names the page it was read from
            @test occursin("p. ", r.locus)
        end
    end

    @testset "nothing here arbitrates, and that is the design" begin
        # A thesis ships no re-measurable record, so every row is `read_off` and
        # `arbitrates = measured && isempty(disqualified_by)` is false throughout.
        # Same standing as Klaus 2022, for the same reason.
        for q in ref_quantities(:miyazawa2021)
            @test ref(:miyazawa2021, q).arbitrates === false
        end
    end

    @testset "the a_s trap: 135 is registered, `a_s` is not reachable" begin
        # The thesis value exists under a name that carries its own warning. A row
        # called `a_s` would be one autocompletion away from re-entering the code
        # as an input authority and reversing the 2026-07-27 decision.
        @test :a_s_thesis in ref_quantities(:miyazawa2021)
        @test !(:a_s in ref_quantities(:miyazawa2021))
        @test ref(:miyazawa2021, :a_s_thesis).value == 135.0

        # Production is 110, and the two must not be confused: the registry entry
        # is the authority for the ATOM, the thesis row is the authority for what
        # the thesis said.
        @test SpinorBEC.ATOM_REGISTRY[:Eu151].a_s /
              SpinorBEC.Units.BOHR_RADIUS ≈ 110.0 rtol = 1e-2
    end

    @testset "the three-body coefficient does not close the K_3 gap" begin
        # THE ASSUMPTION THIS REFUSES: "the thesis measured K_3, so the claim that
        # no K_3 in the universal band reproduces the endpoint must be settled."
        # It is not. The two numbers are a factor ~25 apart and on opposite sides
        # of the band top.
        L = ref(:miyazawa2021, :three_body_L).value          # ~1e-41 m^6/s
        needed = 2.45e-40                                     # to reproduce the endpoint
        band_top = 9.7e-41                                    # 3*C*hbar*a^4/m at C = 67
        @test L < band_top                                    # thesis value is INSIDE the band
        @test needed > band_top                                # what the endpoint demands is not
        @test needed / L > 10                                  # and they are not the same number

        # The live claim is still live, and this row is why it is not contradicted.
        c = claim_by_id(claim_ledger(), "eu-evap-k3-outside-universal-vdw-band")
        @test c !== nothing
        @test c.status == "live"
    end

    @testset "a_s^1.2 is the dependency, and it is below the number's own precision" begin
        # Eq. 7.7 gives L ~ a_s^(6/5) * omega_bar^(-12/5). Re-extracting at the
        # production a_s instead of the thesis one changes L by (110/135)^1.2.
        # THE POINT IS THAT IT IS SMALL: 22 %, against a value quoted to one
        # significant figure with a "~". So the epoch difference in a_s cannot be
        # the explanation for a factor-2.6 spread in K_3 determinations, and
        # reaching for it would be a wrong lead.
        ratio = (110.0 / ref(:miyazawa2021, :a_s_thesis).value)^1.2
        @test 0.75 < ratio < 0.80
        @test 1 - ratio < 0.3         # smaller than one significant figure
        @test 1 - ratio < 2.6 - 1     # and far smaller than the spread it might be blamed for
    end

    @testset "the thesis's decay exponent agrees with our own derivation" begin
        # Thesis Eq. 7.5-7.6: dN/dt = -gamma*N^(9/5), N ~ t^(-5/4) at long time.
        # Independently derived here from the TF second moment <n^2> = (8/21)n_0^2
        # with n_0 ~ N_0^(2/5). Two routes, five years apart, same power — and the
        # ledger row records that a closed-system 3D SGPE fit returned 1.796
        # against the predicted 1.800.
        p = 9 // 5
        @test float(p) == 1.8
        @test -1 / (float(p) - 1) == -1.25          # the attractor exponent
        c = claim_by_id(claim_ledger(), "eu-evap-condensate-n2-moment-is-8-over-21")
        @test c !== nothing
        @test occursin("9/5", c.claim)
        @test occursin("-5/4", c.claim) || occursin("−5/4", c.claim)
    end

    @testset "the excerpt the loci cite is committed" begin
        # A `read_off` row owes the line of the published source. The full thesis
        # is 27.56 MB and lives outside the repository; the nine cited pages are
        # committed at 5.05 MB. If this file goes missing the loci become
        # unverifiable assertions, which is the state the whole layer exists to
        # avoid.
        p = joinpath(dirname(dirname(@__DIR__)), "docs", "refs",
            "Miyazawa_2021_thesis_excerpt_ch6_ch7.pdf")
        @test isfile(p)
        @test filesize(p) > 1_000_000        # a real scan, not a stub
        @test filesize(p) < 27_000_000       # and not the whole thesis
    end
end
