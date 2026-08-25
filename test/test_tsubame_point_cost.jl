# The TSUBAME billing transcription, checked against itself.
#
# `refs/tsubame4_points.toml` is a hand transcription of a PDF, so it is exactly
# the kind of artifact this repository keeps discovering has rotted. It cannot be
# checked against the regulation by a test — nothing here can read intent out of
# 別表3 — but it CAN be held to internal consistency, and that is where the real
# drift showed up: the worked example carried in memory for a year was 0.0271,
# which is the charge ROUNDED, while 第4条 truncates and the charge is 0.0270.
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
# What it does NOT check, said plainly so the gate is not read as more than it
# is: whether the transcription matches the PDF. Re-extract and compare by eye —
# the tables are in the text layer, so it takes about ten seconds:
#   python3 -c "import pypdf; print(''.join(p.extract_text() for p in \
#     pypdf.PdfReader('docs/refs/TSUBAME4_Terms_2024-02.pdf').pages))"

using Test
# The parallel-runner contract: every test file loads the package in the plain
# form, so a worker never depends on some earlier file having done it. Nothing
# here calls into SpinorBEC — this gate is about a transcription, not the code.
using SpinorBEC
using TOML
using Printf

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
