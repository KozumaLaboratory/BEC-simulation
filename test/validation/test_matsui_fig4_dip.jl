# Matsui et al. (2025) Fig. 4B — the resonantly enhanced EdH dip.
#
# The published dataset (Zenodo 17303925, CC-BY-4.0; CSV extracts under
# test/fixtures/matsui2025/) carries both the experimental scan and the curve
# their own Fortran code produced. This file pins the two numbers a
# reproduction has to hit — the dip centre and its half-depth width — measured
# off the fixture by `resonance_dip`, so the target cannot drift silently when
# either the fixture or the metric changes.
#
# It gates the *target*, not a simulation. When a SpinorBEC B-scan exists it is
# compared with the identical call, so the only way the comparison can be wrong
# is if it is wrong for the reference too.

using Test
using SpinorBEC
using DelimitedFiles
using Statistics

const FIXDIR = joinpath(@__DIR__, "..", "fixtures", "matsui2025")

# Values recomputed from the fixture at 886d03bd; see
# docs/validation/parameter_contract_with_Ueda.md §0.5.
const THEO_CENTER_NT = -2.5495
const THEO_WIDTH_NT = 15.0224
const EXP_CENTER_NT = -3.2048
const EXP_WIDTH_NT = 14.5414

function _load(stem)
    raw, hdr = readdlm(joinpath(FIXDIR, stem * ".csv"), ','; header=true)
    (Float64.(raw[:, 1]), Float64.(raw[:, 2]), vec(hdr))
end

# Their experimental scan is 4 (negative side) / 3 (positive side) repeats
# concatenated; Fig. 4B plots the per-field mean.
function _mean_over_repeats(x, y)
    keys = sort(unique(round.(x; digits=4)))
    xs = Float64[]
    ys = Float64[]
    for k in keys
        m = round.(x; digits=4) .== k
        push!(xs, k)
        push!(ys, mean(y[m]))
    end
    (xs, ys)
end

@testset "Matsui 2025 Fig. 4B dip" begin
    @testset "fixtures parse with the expected columns" begin
        for stem in
            ["dataset_fig2_exp", "dataset_fig2_theo", "dataset_fig4_exp", "dataset_fig4_theo"]
            raw, hdr = readdlm(joinpath(FIXDIR, stem * ".csv"), ',', header=true)
            @test size(raw, 2) == 14                      # abscissa + m = -6 … +6
            @test occursin("N_{-6}", vec(hdr)[2])
            @test size(raw, 1) > 50
        end
        _, _, h4 = _load("dataset_fig4_theo")
        @test occursin("Magnetic field", h4[1])
        _, _, h2 = _load("dataset_fig2_theo")
        @test occursin("Time", h2[1])
    end

    @testset "their simulated dip: centre and width" begin
        B, N6, _ = _load("dataset_fig4_theo")
        p = sortperm(B)
        d = resonance_dip(B[p], N6[p])
        # 1 nT scan step ⇒ the vertex refinement is good to well under a step;
        # 1e-3 nT pins the fixture + metric pair, not a physics tolerance.
        @test d.center ≈ THEO_CENTER_NT atol = 1e-3
        @test d.width ≈ THEO_WIDTH_NT atol = 1e-3
        # The dip is on the NEGATIVE side — that offset is the claim Fig. 4B
        # makes. A sign slip anywhere in the B → p chain lands it on the other.
        @test d.center < 0
    end

    @testset "their measured dip: centre and width" begin
        B, N6, _ = _load("dataset_fig4_exp")
        Bm, Nm = _mean_over_repeats(B, N6)
        d = resonance_dip(Bm, Nm)
        @test d.center ≈ EXP_CENTER_NT atol = 1e-3
        @test d.width ≈ EXP_WIDTH_NT atol = 1e-3
        @test d.center < 0
    end

    # Measured vs simulated agree on the width to 3 %, and the centres differ by
    # 0.66 nT — under the paper's own stated ~1 nT field fluctuation. This is
    # the size of the gap a SpinorBEC reproduction has to beat to say anything.
    @testset "reference measured/simulated consistency" begin
        @test abs(THEO_WIDTH_NT - EXP_WIDTH_NT) / EXP_WIDTH_NT < 0.05
        @test abs(THEO_CENTER_NT - EXP_CENTER_NT) < 1.0
    end

    # Canary: the metric must MOVE when the curve does, otherwise the pins above
    # would pass against any fixture at all.
    @testset "canary — metric tracks the curve" begin
        B, N6, _ = _load("dataset_fig4_theo")
        p = sortperm(B)
        Bs, Ns = B[p], N6[p]
        # Compare against the freshly measured dip, not the 4-decimal pins above
        # — those are quotable numbers, not the exactness this canary needs.
        base = resonance_dip(Bs, Ns)
        shifted = resonance_dip(Bs .+ 4.0, Ns)
        @test shifted.center ≈ base.center + 4.0 atol = 1e-9
        @test shifted.width ≈ base.width atol = 1e-9
        stretched = resonance_dip(2 .* Bs, Ns)
        @test stretched.width ≈ 2 * base.width atol = 1e-9
    end

    # Fig. 2C is the other half of the same run family, and the two sheets agree
    # with each other: Fig. 2C at 5 ms gives N_-6 = 21449, and Fig. 4B
    # interpolated to the same +2.6 nT gives 21344 — 0.5 %. That mutual
    # consistency is what licenses reading "5 ms hold at 2.6 nT" off both.
    @testset "Fig. 2C landmarks, and its consistency with Fig. 4B" begin
        raw, _ = readdlm(joinpath(FIXDIR, "dataset_fig2_theo.csv"), ','; header=true)
        t = Float64.(raw[:, 1])
        N6 = Float64.(raw[:, 2])
        Ntot = sum(Float64.(raw[1, 2:end]))
        @test Ntot ≈ 50000.0 atol = 0.1
        @test t[end] ≈ 40.0014 atol = 1e-3

        # Early-time landmarks: the depletion timescale of the source component.
        # These, not the >10 ms recurrences, are the fair reproduction target —
        # by 30 ms the curve is dominated by finite-trap revivals that a coarse
        # grid has no business matching.
        first_below(f) = t[findfirst(<(f * Ntot), N6)]
        @test first_below(0.9) ≈ 1.129 atol = 0.02
        @test first_below(0.7) ≈ 2.199 atol = 0.02
        @test first_below(0.5) ≈ 3.588 atol = 0.02

        i5 = argmin(abs.(t .- 5.0))
        @test N6[i5] / Ntot ≈ 0.4290 atol = 1e-3

        # Same physical point read off the other sheet.
        raw4, _ = readdlm(joinpath(FIXDIR, "dataset_fig4_theo.csv"), ','; header=true)
        B4 = Float64.(raw4[:, 1])
        N64 = Float64.(raw4[:, 2])
        j = sortperm(B4)
        B4, N64 = B4[j], N64[j]
        k = searchsortedfirst(B4, 2.6)
        w = (2.6 - B4[k - 1]) / (B4[k] - B4[k - 1])
        n_interp = N64[k - 1] + w * (N64[k] - N64[k - 1])
        @test abs(n_interp - N6[i5]) / N6[i5] < 0.01
    end

    @testset "resonance_dip refuses an unbracketed dip" begin
        x = collect(0.0:1.0:10.0)
        @test_throws ArgumentError resonance_dip(x, collect(10.0:-1.0:0.0))  # min on endpoint
        @test_throws ArgumentError resonance_dip([0.0, 1.0], [1.0, 0.0])     # too short
        @test_throws ArgumentError resonance_dip(reverse(x), x)              # unsorted
    end
end
