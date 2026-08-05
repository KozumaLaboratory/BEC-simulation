# `SPINORBEC_STORE` must move the WHOLE output tree, not half of it.
#
# Three things decide where output lands: `run_yaml`'s run directory, the GS
# stage cache (`_stage/gs`, which holds the ψ and is the bulk), and the CAS
# store behind `Experiment`. They used to disagree — `_gs_stage_dir()` and
# `default_store()` read `SPINORBEC_STORE` while `run_yaml` hardcoded `"runs"`.
# Setting the variable therefore moved the ψ store and left the run dirs on the
# project filesystem, which is the wrong half to move.
#
# This matters operationally: on 2026-07-29 the group's 1 TB `/gs/fs` quota was
# 100 % full and five of eight array tasks died on it — one EDQUOT (`sendfile`
# −122) and three SIGBUS from mmap on files that could not be extended. Neither
# reads as "disk full" in the log.

using Test
using SpinorBEC

@testset "SPINORBEC_STORE moves the whole output tree" begin
    saved = get(ENV, "SPINORBEC_STORE", nothing)
    try
        delete!(ENV, "SPINORBEC_STORE")
        @test SpinorBEC.default_run_root() == "runs"
        @test SpinorBEC._gs_stage_dir() == joinpath("runs", "_stage", "gs")
        @test SpinorBEC.default_store().root == "runs"

        root = joinpath("/tmp", "spinorbec_store_probe", "runs")
        ENV["SPINORBEC_STORE"] = root
        @test SpinorBEC.default_run_root() == root
        @test SpinorBEC._gs_stage_dir() == joinpath(root, "_stage", "gs")
        @test SpinorBEC.default_store().root == root

        # …and the run dir a YAML maps to follows, which is the half that used
        # to stay behind.
        mktempdir() do d
            y = joinpath(d, "probe.yaml")
            write(y, "pipeline: []\n")
            @test startswith(compute_run_dir(y), root)
            # explicit base_dir still wins over the environment
            @test startswith(compute_run_dir(y; base_dir="elsewhere"), "elsewhere")
        end
    finally
        saved === nothing ? delete!(ENV, "SPINORBEC_STORE") :
        (ENV["SPINORBEC_STORE"] = saved)
    end
end
