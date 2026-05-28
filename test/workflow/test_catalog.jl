using Test
using Dates
using SpinorBEC
using SpinorBEC:
    TagRecord, load_tags, tag_run!, untag!, resolve_tag,
    tags_for, tags_path, catalog_dir

@testset "catalog tags" begin
    mktempdir() do runs
        @testset "empty catalog" begin
            @test isempty(load_tags(; runs_root=runs))
            @test resolve_tag("nope"; runs_root=runs) === nothing
            @test isempty(tags_for("deadbeef"; runs_root=runs))
        end

        @testset "tag round-trip + resolve + reverse lookup" begin
            rec = tag_run!("paper3_fig6_final", "a1a20f308b886fce";
                created_by="anko", runs_root=runs)
            @test rec isa TagRecord
            @test rec.name == "paper3_fig6_final"
            @test rec.content_id == "a1a20f308b886fce"
            @test rec.created_by == "anko"

            @test isfile(tags_path(runs))
            @test resolve_tag("paper3_fig6_final"; runs_root=runs) ==
                "a1a20f308b886fce"
            @test tags_for("a1a20f308b886fce"; runs_root=runs) ==
                ["paper3_fig6_final"]

            # Survives a fresh read (persisted to TOML, not in-memory).
            reread = load_tags(; runs_root=runs)
            @test length(reread) == 1
            @test reread[1].name == "paper3_fig6_final"
        end

        @testset "many names per cid; one cid per name" begin
            tag_run!("klaus_best", "63c68385a5a009dc"; runs_root=runs)
            tag_run!("klaus_alt", "63c68385a5a009dc"; runs_root=runs)
            # Two names point at the same cid.
            @test Set(tags_for("63c68385a5a009dc"; runs_root=runs)) ==
                Set(["klaus_best", "klaus_alt"])
            # Re-point an existing name (last write wins).
            tag_run!("klaus_best", "fb40129aea28ad1b"; runs_root=runs)
            @test resolve_tag("klaus_best"; runs_root=runs) ==
                "fb40129aea28ad1b"
            @test tags_for("63c68385a5a009dc"; runs_root=runs) == ["klaus_alt"]
        end

        @testset "untag" begin
            @test untag!("klaus_alt"; runs_root=runs) === true
            @test resolve_tag("klaus_alt"; runs_root=runs) === nothing
            # Idempotent: removing a gone tag is a no-op false.
            @test untag!("klaus_alt"; runs_root=runs) === false
        end

        @testset "name validation" begin
            @test_throws ArgumentError tag_run!("bad name", "abc"; runs_root=runs)
            @test_throws ArgumentError tag_run!("with:colon", "abc"; runs_root=runs)
            @test_throws ArgumentError tag_run!("ok_name", ""; runs_root=runs)
            # Valid: dots, slashes, dashes, underscores.
            @test tag_run!("fig/2a.final-v", "abcd"; runs_root=runs) isa TagRecord
        end

        @testset "catalog lives under .catalog, CAS untouched" begin
            @test occursin(".catalog", catalog_dir(runs))
            # No hash-named run dir was created by tagging.
            entries = filter(e -> !startswith(e, "."), readdir(runs))
            @test isempty(entries)
        end
    end
end
