# `store_census` — which duplicate run directories are recoverable waste (#478).
#
# The instrument answers a question #478 pre-registered and PR #482 could not
# reach: of the run directories sharing a basename, how many differ on PHYSICS
# (cause a) and how many on nothing that reaches it (cause b)? #482 had to
# estimate, because the store predates the current naming and a directory cannot
# be reverse-mapped to its source YAML. It does not need to be: every directory
# carries its own `config.yaml`.
#
# WHAT THIS FILE GATES, and it is the part that decides the answer: the CLASSIFIER.
# A count of duplicates is not a verdict — `defaults.backend` differing is a
# GPU=CPU parity arm that is supposed to exist, and `metadata.suite` differing is
# the same physics recomputed because the run-directory key is a hash of the whole
# file's bytes. Those two land in opposite buckets and the fixture asserts both,
# in both directions, because a classifier that called everything physics would
# reproduce #482's estimate and look like it had measured something.

using Test
using YAML
using SpinorBEC

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# A minimal but REAL config shape: the paths the classifier keys on have to be
# where they are in a production config, or the fixture proves nothing about it.
function _cfg(; backend="cpu", suite="A", n_steps=200, bz="0.01 Gauss")
    Dict{String, Any}(
        "defaults" => Dict{String, Any}("backend" => backend),
        "metadata" => Dict{String, Any}("suite" => suite),
        "pipeline" => Any[
            Dict{String, Any}(
            "ground_state" => Dict{String, Any}(
                "n_steps" => n_steps,
                "B" => Dict{String, Any}("Bz" => bz)),
        ),
        ],
    )
end

function _mkrun(root, name, cfg; with_point=true)
    d = joinpath(root, name)
    mkpath(d)
    YAML.write_file(joinpath(d, "config.yaml"), cfg)
    with_point && write(joinpath(d, "point_001.jld2"), "not really a jld2")
    d
end

@testset "store_census — cache-miss causes, separated (#478)" begin
    @testset "basename stripping sees both naming generations" begin
        # The store holds 8-hex (pre-`compute_run_dir`) and 16-hex names side by
        # side. A pattern that admitted only the current width would find zero
        # duplicates in this store and be believed — the shape of the "0 of 219"
        # mistake, one layer over.
        @test store_run_basename("matsui_edh_baseline_9ca97308") == "matsui_edh_baseline"
        @test store_run_basename("klaus_weff0p714_B5p2nT_0123456789abcdef") ==
            "klaus_weff0p714_B5p2nT"
        # A hand-named directory is its own basename, NOT a group with every
        # other unhashed directory.
        @test store_run_basename("klaus_quench") == "klaus_quench"
        @test store_run_basename("eu151_klaus_phi_phys") == "eu151_klaus_phi_phys"
        # Neither 7 nor 9 hex is a suffix this store uses; a looser pattern would
        # eat a real name segment.
        @test store_run_basename("run_abc1234") == "run_abc1234"
        @test store_run_basename("run_abc12345f") == "run_abc12345f"
    end

    @testset "the classifier splits parity arms from recomputed physics" begin
        # BOTH DIRECTIONS. The failure that matters is not "physics called
        # annotation" alone — it is the pair, because each mistake produces a
        # plausible and opposite verdict about the same store.
        @test store_path_class("metadata.suite") === :annotation
        @test store_path_class("metadata.noise_convention") === :annotation
        @test store_path_class("defaults.backend") === :execution
        @test store_path_class("pipeline[1].ground_state.dtype") === :execution
        @test store_path_class("pipeline[1].ground_state.B.Bz") === :physics
        @test store_path_class("pipeline[2].dynamics.dt") === :physics
        @test store_path_class("pipeline[1].ground_state.n_steps") === :physics
        @test store_path_class("defaults.interactions") === :physics
        # An UNKNOWN key must fall to physics. Read as execution it would report
        # real duplicated work as intentional, which is the direction that loses
        # the finding; read as physics it only overstates cause (a), and the
        # report prints the path so a reader sees the overstatement.
        @test store_path_class("pipeline[1].ground_state.some_new_knob") === :physics
    end

    @testset "four buckets on a synthetic store" begin
        mktempdir() do root
            # (b) pure: canonically equal, key order only.
            _mkrun(root, "pure_b_aaaaaaaa", _cfg())
            _mkrun(root, "pure_b_bbbbbbbb",
                Dict{String, Any}(reverse(collect(pairs(_cfg())))))
            # (b) as it occurs: annotation differs, physics identical.
            _mkrun(root, "annot_aaaaaaaa", _cfg(; suite="A"))
            _mkrun(root, "annot_bbbbbbbb", _cfg(; suite="B"))
            # (e) parity arm.
            _mkrun(root, "parity_aaaaaaaa", _cfg(; backend="cpu"))
            _mkrun(root, "parity_bbbbbbbb", _cfg(; backend="cuda"))
            # (e) with an annotation riding along — must NOT be promoted to (a).
            _mkrun(root, "parity2_aaaaaaaa", _cfg(; backend="cpu", suite="A"))
            _mkrun(root, "parity2_bbbbbbbb", _cfg(; backend="cuda", suite="B"))
            # (a) a sign flip on the field — the real `matsui_edh_baseline` case.
            _mkrun(root, "phys_aaaaaaaa", _cfg(; bz="0.01 Gauss"))
            _mkrun(root, "phys_bbbbbbbb", _cfg(; bz="-0.01 Gauss"))
            # A singleton must not appear in any bucket.
            _mkrun(root, "lonely_aaaaaaaa", _cfg())
            # A directory with points and no config is counted, not skipped.
            no_cfg = joinpath(root, "no_config_aaaaaaaa")
            mkpath(no_cfg)
            write(joinpath(no_cfg, "point_001.jld2"), "x")

            c = store_census(root)
            @test c.n_dirs == 12
            @test c.n_no_config == 1
            @test isempty(c.unreadable)
            @test sort(collect(keys(c.groups))) ==
                ["annot", "parity", "parity2", "phys", "pure_b"]
            @test !haskey(c.groups, "lonely")
            @test c.differing["pure_b"] == String[]

            rep = store_census_report(c; io=devnull)
            @test rep["identical"] == ["pure_b"]
            @test sort(collect(keys(rep["annotation_only"]))) == ["annot"]
            @test sort(collect(keys(rep["execution_only"]))) == ["parity", "parity2"]
            @test sort(collect(keys(rep["physics"]))) == ["phys"]
            @test rep["physics"]["phys"] == ["pipeline[1].ground_state.B.Bz"]
            @test rep["n_duplicate_basenames"] == 5
            @test rep["n_duplicate_dirs"] == 10
        end
    end

    @testset "an added block counts as physics, not as absence" begin
        # `L3_cr_f3_edh_toy_ddi_off` differs by one side HAVING
        # `defaults.interactions: {N_atoms: 10000, omega_ref: 628.3}` and the other
        # not. A diff that only reported :changed would call this pair identical.
        mktempdir() do root
            a = _cfg()
            b = _cfg()
            b["defaults"]["interactions"] = Dict{String, Any}(
                "N_atoms" => 10000, "omega_ref" => 628.3
            )
            _mkrun(root, "added_aaaaaaaa", a)
            _mkrun(root, "added_bbbbbbbb", b)
            rep = store_census_report(store_census(root); io=devnull)
            @test haskey(rep["physics"], "added")
            @test isempty(rep["identical"])
        end
    end

    @testset "a config edited after the run is caught by its own key" begin
        # `bce2068f` ("211 Eu configs pinned m=-F under a field that prefers
        # m=+F") edited a committed run directory's config IN PLACE, flipping
        # `Bz: "-0.01 Gauss"` to `"0.01 Gauss"`. The directory name is
        # `sha256(config bytes)`, so the file no longer hashes to the directory it
        # lives in and the stored config describes different physics than the run.
        #
        # This is the check with a free calibration: the verifying directories are
        # the negative control and the edited one is the positive control, in the
        # same pass. Both are asserted here.
        mktempdir() do root
            cfg = _cfg(; bz="-0.01 Gauss")
            body = YAML.yaml(cfg)
            key = bytes2hex(SpinorBEC.sha256(codeunits(body)))[1:8]

            honest = joinpath(root, "honest_$key")
            mkpath(honest)
            write(joinpath(honest, "config.yaml"), body)

            edited = joinpath(root, "edited_$key")
            mkpath(edited)
            write(joinpath(edited, "config.yaml"),
                replace(body, "-0.01 Gauss" => "0.01 Gauss"))

            c = store_census(root)
            @test c.n_keyed == 2
            @test collect(keys(c.stale_key)) == ["edited_$key"]      # positive
            @test !haskey(c.stale_key, "honest_$key")                # negative
            rep = store_census_report(c; io=devnull)
            @test rep["n_keyed"] == 2
            @test haskey(rep["stale_key"], "edited_$key")
        end
    end

    @testset "an unparseable config is reported, not silently dropped" begin
        mktempdir() do root
            _mkrun(root, "ok_aaaaaaaa", _cfg())
            bad = joinpath(root, "bad_bbbbbbbb")
            mkpath(bad)
            write(joinpath(bad, "config.yaml"), "pipeline: [\n  unclosed: {")
            c = store_census(root)
            @test "bad_bbbbbbbb" in c.unreadable
        end
        @test_throws ArgumentError store_census(joinpath(tempdir(), "no_such_store_x"))
    end

    @testset "the knob lists are named, not derived from the store" begin
        # A list built by scanning the store would classify whatever is there as
        # legitimate, so the calibration is that the names are literals AND that
        # each one is reachable by the classifier.
        hits = calibrated_scan(SpinorBEC.STORE_EXECUTION_KNOBS;
            match=k -> store_path_class("pipeline[1].ground_state.$k") === :execution,
            present="backend", absent="Bz")
        @test length(hits) == length(SpinorBEC.STORE_EXECUTION_KNOBS)
        hits2 = calibrated_scan(SpinorBEC.STORE_ANNOTATION_PREFIXES;
            match=p -> store_path_class("$p.anything") === :annotation,
            present="metadata", absent="pipeline")
        @test length(hits2) == length(SpinorBEC.STORE_ANNOTATION_PREFIXES)
    end
end
