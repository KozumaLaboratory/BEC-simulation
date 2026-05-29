using Test
using SpinorBEC
using SpinorBEC:
    run_catalog_index, backfill_summaries!, run_family,
    run_level, run_layer, RUN_SUMMARY_FILENAME
using JLD2
using JSON

@testset "catalog index" begin
    @testset "run_family strips hash + trailing value tokens" begin
        # Hash + grid size both peel → the convergence study is one family.
        @test run_family("L4_eu_matsui_hamiltonian_only_128_41227542") ==
            "L4_eu_matsui_hamiltonian_only"
        @test run_family("L4_eu_matsui_hamiltonian_only_32_deadbeef0badf00d") ==
            "L4_eu_matsui_hamiltonian_only"
        # _n<N> point-count suffix peels too.
        @test run_family("matsui_5ms_morphology_n64") == "matsui_5ms_morphology"
        # Trailing sweep value peels (K3factor sweep).
        @test run_family("matsui_40ms_lossy_K3factor_15") == "matsui_40ms_lossy_K3factor"
        # Alphabetic name tokens are KEPT (not swept values).
        @test run_family("L7_loss_only_uniform_K3") == "L7_loss_only_uniform_K3"
        @test run_family("K0_gdr0_LHY0") == "K0_gdr0_LHY0"
        @test run_family("klaus_quench_omm0p1_holdonly_delay2ms_refine_90bfb48f") ==
            "klaus_quench_omm0p1_holdonly_delay2ms_refine"
        # Pure-hash CAS dir → stays whole (singleton family).
        @test run_family("a1a20f308b886fce") == "a1a20f308b886fce"
    end

    @testset "run_level — validation ladder L<n>" begin
        @test run_level("L4_eu_matsui_hamiltonian_only_64_abc12345") == "L4"
        @test run_level("L4det_eu_matsui_hamiltonian_only_32") == "L4"
        @test run_level("L4dealiasv6_kcut11_eu_matsui_hamiltonian_only") == "L4"
        @test run_level("L7_loss_only_uniform_K3") == "L7"
        @test run_level("L13_something") == "L13"
        # Non-ladder runs have no level.
        @test run_level("klaus_quench_om0p0") === nothing
        @test run_level("00_scalar_free_uniform_stationary") === nothing
        @test run_level("K3x150p0") === nothing
    end

    @testset "run_layer — coarse top-tier grouping" begin
        @test run_layer("L4det_eu_matsui_hamiltonian_only_64") == "L4"
        @test run_layer("L7_loss_only_uniform_K3") == "L7"
        @test run_layer("00_scalar_free_uniform_stationary_0ece2fdb") == "bench"
        @test run_layer("klaus_quench_om0p0") == "klaus"
        @test run_layer("matsui_5ms_morphology_n64") == "matsui"
        @test run_layer("barnett_eu_omm0p3_n64_DDIon") == "barnett"
        @test run_layer("K0_gdr0_LHY0") == "K-sweep"
        @test run_layer("K3x150p0") == "K-sweep"
        @test run_layer("eu_k3_sweep") == "K-sweep"
        @test run_layer("F6_phase_diagram") == "F6"
        @test run_layer("jit_probe") == "jit"
        @test run_layer("a1a20f308b886fce") == "autopilot"  # pure-hash, not "bench"
        @test run_layer("something_unrecognised") == "other"
    end

    @testset "read path: rows from summary + partial runs, recent first" begin
        mktempdir() do runs
            # Run A: has a summary.json (full row).
            a = joinpath(runs, "runA_aaaaaaaaaaaaaaaa")
            mkpath(a)
            touch(joinpath(a, "config.yaml"))
            open(joinpath(a, RUN_SUMMARY_FILENAME), "w") do io
                JSON.print(io, Dict("energy" => -6.0, "F" => 1,
                    "extraction_error" => String[]))
            end
            # Run B: jld2 only, no summary yet (partial row, needs reindex).
            b = joinpath(runs, "runB_bbbbbbbbbbbbbbbb")
            mkpath(b)
            jldopen(joinpath(b, "point_001.jld2"), "w") do f
                local p = zeros(ComplexF64, 8, 8, 3)
                p[1, 1, 1] = 1.0 + 0im
                f["psi"] = p
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["energy"] = -5.0
                f["converged"] = true
            end
            # Bare dir (no config/jld2/summary) → not a run, skipped.
            mkpath(joinpath(runs, "not_a_run"))

            rows = run_catalog_index(; runs_root=runs)
            @test length(rows) == 2
            names = Set(r["name"] for r in rows)
            @test names == Set(["runA_aaaaaaaaaaaaaaaa", "runB_bbbbbbbbbbbbbbbb"])

            ra = only(filter(r -> r["name"] == "runA_aaaaaaaaaaaaaaaa", rows))
            @test ra["has_summary"] === true
            @test ra["energy"] == -6.0
            @test ra["family"] == "runA"

            rb = only(filter(r -> r["name"] == "runB_bbbbbbbbbbbbbbbb", rows))
            @test rb["has_summary"] === false   # partial, visible not hidden
            @test rb["has_jld2"] === true
        end
    end

    @testset "backfill is resumable + makes partial rows whole" begin
        mktempdir() do runs
            b = joinpath(runs, "runB_bbbbbbbbbbbbbbbb")
            mkpath(b)
            jldopen(joinpath(b, "point_001.jld2"), "w") do f
                local p = zeros(ComplexF64, 8, 8, 3)
                p[1, 1, 1] = 1.0 + 0im
                f["psi"] = p
                f["grid_n_points"] = [8, 8]
                f["grid_box_size"] = [4.0, 4.0]
                f["energy"] = -5.0
                f["converged"] = true
            end

            @test !isfile(joinpath(b, RUN_SUMMARY_FILENAME))
            n1 = backfill_summaries!(; runs_root=runs)
            @test n1 == 1
            @test isfile(joinpath(b, RUN_SUMMARY_FILENAME))
            # Resumable: second pass skips the now-present summary.
            n2 = backfill_summaries!(; runs_root=runs)
            @test n2 == 0

            rows = run_catalog_index(; runs_root=runs)
            rb = only(rows)
            @test rb["has_summary"] === true
            @test rb["energy"] == -5.0
            @test rb["_source"] == "backfill"
        end
    end
end
