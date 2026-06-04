# test/workflow/test_checkpoint.jl
#
# General Checkpoint primitive — keyed JLD2 store, memoise via
# get_or_compute!, universal load+transform+save via fork! (in-place
# or branching), ancestry walking.

using Test
using SpinorBEC
using SpinorBEC: Checkpoint, get_or_compute!, fork!, has_checkpoint,
    load_checkpoint, save_checkpoint!, list_keys, parent_of, ancestry

@testset "Checkpoint primitive" begin
    @testset "save / load / has roundtrip" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            @test !has_checkpoint(cp, "x")
            @test load_checkpoint(cp, "x") === nothing
            save_checkpoint!(cp, "x", (; v=42, w=[1.0, 2.0]))
            @test has_checkpoint(cp, "x")
            r = load_checkpoint(cp, "x")
            @test r.v == 42
            @test r.w == [1.0, 2.0]
        end
    end

    @testset "get_or_compute! memoises" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            calls = Ref(0)
            compute() = (calls[] += 1; (; n=calls[]))
            r1 = get_or_compute!(cp, "expensive", compute)
            @test r1.n == 1 && calls[] == 1
            r2 = get_or_compute!(cp, "expensive", compute)
            @test r2.n == 1 && calls[] == 1  # cached
            # force: re-run
            r3 = get_or_compute!(cp, "expensive", compute; force=true)
            @test r3.n == 2 && calls[] == 2
        end
    end

    @testset "fork! in-place (target == source): advances checkpoint" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            save_checkpoint!(cp, "psi", (; step=0, e=1.0))
            # Refine: bump step, decrease e
            fork!(cp, "psi", "psi",
                prev -> (; step=prev.step + 1, e=prev.e * 0.5))
            r = load_checkpoint(cp, "psi")
            @test r.step == 1
            @test r.e == 0.5
            # Apply again: continues advancing
            fork!(cp, "psi", "psi",
                prev -> (; step=prev.step + 1, e=prev.e * 0.5))
            r2 = load_checkpoint(cp, "psi")
            @test r2.step == 2 && r2.e == 0.25
            # In-place does NOT add parent_key metadata (advancement, not branch)
            @test parent_of(cp, "psi") === nothing
        end
    end

    @testset "fork! branching (target != source): both coexist + ancestry" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            save_checkpoint!(cp, "warm_state", (; psi=1.0, params=:base))
            fork!(cp, "warm_state", "branch_A",
                prev -> (; psi=prev.psi * 2, params=:A))
            fork!(cp, "warm_state", "branch_B",
                prev -> (; psi=prev.psi * 3, params=:B))
            # Both branches exist independently
            @test load_checkpoint(cp, "warm_state").params == :base
            @test load_checkpoint(cp, "branch_A").params == :A
            @test load_checkpoint(cp, "branch_B").params == :B
            # Ancestry: each branch knows its parent
            @test parent_of(cp, "branch_A") == "warm_state"
            @test parent_of(cp, "branch_B") == "warm_state"
            @test parent_of(cp, "warm_state") === nothing
            @test ancestry(cp, "branch_A") == ["warm_state", "branch_A"]
        end
    end

    @testset "fork! predicate short-circuits" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            save_checkpoint!(cp, "x", (; converged=true, n=10))
            calls = Ref(0)
            # predicate(source)==true → transform NOT called, source returned
            r = fork!(cp, "x", "x",
                prev -> (calls[] += 1; (; converged=true, n=prev.n + 1));
                predicate=r -> r.converged)
            @test calls[] == 0
            @test r.n == 10  # unchanged
        end
    end

    @testset "fork! errors" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            # Source missing
            @test_throws ArgumentError fork!(cp, "missing", "x",
                prev -> prev)
            # Branching to existing key (must overwrite explicitly)
            save_checkpoint!(cp, "p", (; v=1))
            save_checkpoint!(cp, "q", (; v=2))
            @test_throws ArgumentError fork!(cp, "p", "q", prev -> prev)
        end
    end

    @testset "Deep ancestry chain (5 fork levels)" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            save_checkpoint!(cp, "lvl0", (; n=0))
            for i in 1:5
                fork!(cp, "lvl$(i - 1)", "lvl$(i)",
                    prev -> (; n=prev.n + 1))
            end
            anc = ancestry(cp, "lvl5")
            @test anc == ["lvl0", "lvl1", "lvl2", "lvl3", "lvl4", "lvl5"]
            @test load_checkpoint(cp, "lvl5").n == 5
        end
    end

    @testset "list_keys" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            @test isempty(list_keys(cp))
            save_checkpoint!(cp, "a", (; v=1))
            save_checkpoint!(cp, "b", (; v=2))
            keys = list_keys(cp)
            @test Set(keys) == Set(["a", "b"])
        end
    end

    @testset "Filename sanitisation" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            # Slashes / colons in key should not escape cache_dir
            save_checkpoint!(cp, "B=1.0/Ω=0.6:seed=polar", (; v=99))
            @test has_checkpoint(cp, "B=1.0/Ω=0.6:seed=polar")
            @test load_checkpoint(cp, "B=1.0/Ω=0.6:seed=polar").v == 99
        end
    end
end
