# The TSUBAME billing transcription, checked against the regulation and against
# itself.
#
# `refs/tsubame4_points.toml` is a hand transcription of a PDF, so it is exactly
# the kind of artifact this repository keeps discovering has rotted. Two things
# are checked, and they catch different faults: the numbers are cross-read out of
# the regulation's own text (a retyped coefficient), and the worked examples are
# recomputed from the stated rules (a rule applied backwards). The second is
# where the real drift showed up: the example carried in memory for a year was
# 0.0271, which is the charge ROUNDED, while 第4条 truncates and it is 0.0270.
# Every empirical "match" against that number agreed to within one unit in the
# last place, so nothing ever looked wrong, and the RULE inferred from it was
# backwards.
#
# So this recomputes each `[[example]]` from the coefficients and the rounding
# rule as the file states them. It is deliberate redundancy under CLAUDE.md
# commitment 3: an independent statement of the same arithmetic, gated, rather
# than a single copy nobody re-derives. If a coefficient is retyped wrongly, or
# an example is written with the wrong rounding, this goes red.
#
# It DOES also check the transcription against the regulation, which the first
# version of this file said was impossible. That was pessimism, not analysis: all
# twelve resource types turn out to sit on the same line as their coefficient in
# the PDF's text layer, so a retyped number is mechanically catchable. The text
# layer is committed beside the PDF and pinned to its sha256 — the docs/STATE.md
# pattern, a derived artifact plus a gate that it was really derived — so the
# check needs no PDF library in the test environment.
#
# What remains genuinely uncheckable is INTENT: that 別表3 is the table this
# repository should be reading at all, and that the regulation has not been
# superseded by a new fiscal year's. `[source].effective_from` is the thing to
# look at for that, and no test can look at it for you.

using Test
# The parallel-runner contract: every test file loads the package in the plain
# form, so a worker never depends on some earlier file having done it. Nothing
# here calls into SpinorBEC — this gate is about a transcription, not the code.
using SpinorBEC
using TOML
using Printf
import SHA

const _PTS_ROOT = dirname(@__DIR__)
const _PTS_TOML = joinpath(_PTS_ROOT, "refs", "tsubame4_points.toml")

"""
別表2 on-demand charge, then 第4条 truncation.

Truncation is done on the decimal string rather than as `floor(raw / unit)`:
`0.001 / 0.0001` is 9.999999... in binary, and the first implementation of this
in `observability/job_cost.sh` turned an exact 0.0010 pt into 0.0009.
"""
function _charge(; nodes, type_coef, prio_coef, actual_s, h_rt_s, places)
    raw = nodes * type_coef * prio_coef * (0.7 * max(actual_s, 300) + 0.1 * h_rt_s) / 3600
    s = Printf.format(Printf.Format("%.$(places + 6)f"), raw)
    dot = findfirst('.', s)
    parse(Float64, s[1:(dot + places)])
end

@testset "TSUBAME point cost transcription" begin
    @test isfile(_PTS_TOML)
    t = TOML.parsefile(_PTS_TOML)

    @testset "the primary source is committed beside the transcription" begin
        # A transcription whose source is a URL is not checkable offline, which
        # is the state this file was created to leave.
        pdf = joinpath(_PTS_ROOT, t["source"]["file"])
        @test isfile(pdf)
        @test filesize(pdf) > 100_000
        # The committed text layer is DERIVED, so it must be pinned to the thing
        # it was derived from. Without this, replacing the PDF with a new fiscal
        # year's terms would leave the old text in place and every check below
        # would keep passing against a regulation nobody is using any more.
        @test bytes2hex(SHA.sha256(read(pdf))) == t["source"]["sha256"]
        txt = joinpath(_PTS_ROOT, t["source"]["text"])
        @test isfile(txt)
        @test occursin(t["source"]["sha256"], read(txt, String))
    end

    @testset "every coefficient is co-located with its type IN the regulation" begin
        # The check that makes this a transcription rather than a claim: for each
        # row of 別表3, find a line of the regulation carrying BOTH the resource
        # type's name and the coefficient this file assigns it.
        lines = split(read(joinpath(_PTS_ROOT, t["source"]["text"]), String), '\n')
        colocated(name, coef) =
            any(
                l -> occursin(name, l) && occursin(Printf.format(Printf.Format("%.3f"), coef), l),
                lines,
            )

        # CALIBRATION. A scan that cannot fail is not evidence, and this one has
        # two ways to be silently blind: the text file could be empty (nothing
        # matches, and "0 mismatches" reads as success), or `occursin` on a short
        # name could match anything. So: a row known to be right must be found,
        # and the same row with a WRONG coefficient must not be.
        @test colocated("node_f", 1.000)
        @test !colocated("node_f", 0.999)
        @test !colocated("node_zzz", 1.000)

        for (name, coef) in t["resource_type"]
            @test colocated(name, coef)
        end
    end

    @testset "the rules quoted in prose are the rules in the regulation" begin
        src = read(joinpath(_PTS_ROOT, t["source"]["text"]), String)
        # 第4条, the clause that settles truncation-vs-round-up.
        @test occursin("10,000 分の１ポイント", src)
        @test occursin("端数は切り捨てて計算する", src)
        @test !occursin("端数は切り上げて計算する", src)
        # 別表2's on-demand formula. Specific fragments only: an earlier version
        # of this line fell back to `occursin("300", src)`, which the document
        # satisfies in half a dozen unrelated places — a check that cannot fail
        # is not a check. The formula wraps mid-token in the text layer, so the
        # floor is matched as two pieces rather than as one string.
        @test occursin("max(実際", src)
        @test occursin("，300)", src)
        @test occursin("0.7×max", src)
        @test occursin("0.1×指定した実行時間", src)
        @test occursin("÷3600", src)
        # ...and the negative control for the above: a weight the formula does
        # NOT use must not be found in that position.
        @test !occursin("0.9×max", src)
    end

    @testset "the rounding rule is truncation at 1/10000" begin
        # Stated as a test because it is the thing that was remembered wrongly.
        # 切り上げ would make every sub-unit job cost 1 unit instead of 0.
        @test t["rounding"]["mode"] == "truncate"
        @test t["rounding"]["unit_points"] == 0.0001
        @test t["rounding"]["per"] == "job"
    end

    @testset "別表3 / 別表4 are complete and ordered as the hardware is" begin
        rt = t["resource_type"]
        # All twelve types, and the fractional-node family must be monotone in
        # what it provides: a transposed pair here silently misprices a campaign.
        @test length(rt) == 12
        @test rt["node_f"] > rt["node_h"] > rt["node_q"] > rt["node_o"]
        @test rt["cpu_160"] > rt["cpu_80"] > rt["cpu_40"] > rt["cpu_16"] > rt["cpu_8"] > rt["cpu_4"]
        # gpu_1 is the cheapest FULL (non-MIG) GPU — the fact the cost hacks rest on.
        @test rt["gpu_1"] < rt["node_q"]
        for k in keys(rt)
            @test haskey(t["resource_type_provides"], k)
        end
        @test t["priority"]["0"] == 1.0
        @test t["priority"]["1"] == 2.0
        @test t["priority"]["2"] == 4.0
    end

    @testset "the 300 s floor is what it says" begin
        @test t["formula"]["notes"]["actual_floor_s"] == 300
        rt = t["resource_type"]
        places = 4
        # A 3 s job and a 300 s job at the same h_rt cost the SAME. This is the
        # only round-up in the scheme and the one worth planning around.
        a = _charge(nodes=1, type_coef=rt["cpu_4"], prio_coef=1.0,
            actual_s=3, h_rt_s=300, places=places)
        b = _charge(nodes=1, type_coef=rt["cpu_4"], prio_coef=1.0,
            actual_s=300, h_rt_s=300, places=places)
        @test a == b
        # ...and a 301 s job costs strictly more, or the floor is being applied
        # as a cap somewhere.
        c = _charge(nodes=1, type_coef=rt["cpu_4"], prio_coef=1.0,
            actual_s=3000, h_rt_s=300, places=places)
        @test c > b
    end

    @testset "every worked example reproduces" begin
        rt = t["resource_type"]
        prio = t["priority"]
        places = length(split(string(t["rounding"]["unit_points"]), ".")[2])
        @test !isempty(t["example"])
        for ex in t["example"]
            got = _charge(
                nodes=ex["nodes"],
                type_coef=rt[ex["resource"]],
                prio_coef=prio[string(ex["priority"])],
                actual_s=ex["actual_s"],
                h_rt_s=ex["h_rt_s"],
                places=places,
            )
            @test got ≈ ex["expected_points"] atol = 1e-12
        end
    end

    @testset "truncation and rounding are made to disagree at least once" begin
        # A rounding rule nobody can see the effect of is a rule nobody checks.
        # At least one example must be a case where the two differ, or this gate
        # would stay green with the rule written backwards.
        rt = t["resource_type"]
        prio = t["priority"]
        places = 4
        disagreeing = 0
        for ex in t["example"]
            raw =
                ex["nodes"] * rt[ex["resource"]] * prio[string(ex["priority"])] *
                (0.7 * max(ex["actual_s"], 300) + 0.1 * ex["h_rt_s"]) / 3600
            rounded = round(raw; digits=places)
            rounded ≈ ex["expected_points"] || (disagreeing += 1)
        end
        @test disagreeing >= 1
    end
end
