# test/workflow/test_checkpointed_sweep.jl
#
# CheckpointedSweep — per-cell JLD2 cache + skip + extend.

using Test
using SpinorBEC
using SpinorBEC:
    CheckpointedSweep, run_cell!, run_sweep!,
    extend_unconverged!, load_cell, collect_results

@testset "CheckpointedSweep" begin
    @testset "run_cell! caches, second call returns cached" begin
        mktempdir() do dir
            n_calls = Ref(0)
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> "x$(p.x)",
                runner=p -> begin
                    n_calls[] += 1
                    (; x=p.x, y=2 * p.x, gate_ok=p.x > 5)
                end,
                gate=r -> r.gate_ok,
            )
            r1 = run_cell!(sweep, (x=3,))
            @test r1.y == 6 && n_calls[] == 1
            # Second call: cached, runner not called again
            r2 = run_cell!(sweep, (x=3,))
            @test r2.y == 6 && n_calls[] == 1
            # Different params → new run
            r3 = run_cell!(sweep, (x=10,))
            @test r3.y == 20 && n_calls[] == 2
            @test r3.gate_ok
        end
    end

    @testset "run_sweep! runs cells in order, skips cached" begin
        mktempdir() do dir
            calls_log = Symbol[]
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> "k$(p.k)",
                runner=p -> begin
                    push!(calls_log, p.k)
                    (; k=p.k, value=p.k == :a ? 1.0 : 2.0)
                end,
                gate=r -> r.value > 1.5,
            )
            cells = [(k=:a,), (k=:b,)]
            results = run_sweep!(sweep, cells; verbose=false)
            @test length(results) == 2
            @test results[1].k == :a
            @test results[2].k == :b
            @test calls_log == [:a, :b]
            # Second sweep: both cached
            results2 = run_sweep!(sweep, cells; verbose=false)
            @test calls_log == [:a, :b]  # no additional calls
            @test results2[1].value == 1.0
        end
    end

    @testset "extend_unconverged! only touches gate=false cells" begin
        mktempdir() do dir
            extend_log = Symbol[]
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> "$(p.id)",
                # initial run produces partially-converged results
                runner=p -> (; id=p.id, value=p.id == :converged ? 100.0 : 0.5),
                # extender increases value by n_extend
                extender=(p, prev; n_extend) -> begin
                    push!(extend_log, p.id)
                    (; id=p.id, value=prev.value + n_extend * 1.0)
                end,
                gate=r -> r.value > 1.0,
            )
            cells = [(id=:converged,), (id=:slow1,), (id=:slow2,)]
            run_sweep!(sweep, cells; verbose=false)
            # No extend log yet
            @test isempty(extend_log)

            # Extend with small budget that won't push slow cells past gate
            results = extend_unconverged!(sweep, cells; n_extend=0, verbose=false)
            @test extend_log == [:slow1, :slow2]
            @test results[1].value == 100.0  # converged, untouched
            @test results[2].value == 0.5    # extended (n_extend=0 + 0.5 = 0.5)
            @test results[3].value == 0.5

            # Run again with adequate budget — should push past gate
            empty!(extend_log)
            results2 = extend_unconverged!(sweep, cells; n_extend=10, verbose=false)
            # slow1, slow2 still ✗ from prev round (value=0.5, gate at >1.0)
            @test extend_log == [:slow1, :slow2]
            @test results2[2].value == 10.5  # now passes gate
            @test results2[3].value == 10.5

            # Third extend: all cells converged → nothing in log
            empty!(extend_log)
            results3 = extend_unconverged!(sweep, cells; n_extend=0, verbose=false)
            @test isempty(extend_log)  # all converged
            @test all(r -> r.value > 1.0, results3)
        end
    end

    @testset "load_cell + collect_results" begin
        mktempdir() do dir
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> string(p.n),
                runner=p -> (; n=p.n, sq=p.n^2),
                gate=r -> true,
            )
            cells = [(n=1,), (n=2,), (n=3,)]
            # Before run: load returns nothing
            @test load_cell(sweep, (n=1,)) === nothing
            run_sweep!(sweep, cells[1:2]; verbose=false)
            # After partial run: 1+2 cached, 3 not
            @test load_cell(sweep, (n=1,)).sq == 1
            @test load_cell(sweep, (n=2,)).sq == 4
            @test load_cell(sweep, (n=3,)) === nothing
            # collect_results includes nothing for missing
            results = collect_results(sweep, cells)
            @test results[1].sq == 1
            @test results[2].sq == 4
            @test results[3] === nothing
        end
    end

    @testset "extend_unconverged! errors when no extender" begin
        mktempdir() do dir
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> "$(p.id)",
                runner=p -> (; id=p.id, gate_ok=false),
                gate=r -> r.gate_ok,
                # NO extender
            )
            run_sweep!(sweep, [(id=:a,)]; verbose=false)
            @test_throws ArgumentError extend_unconverged!(sweep, [(id=:a,)];
                verbose=false)
        end
    end

    @testset "force=true overwrites cache" begin
        mktempdir() do dir
            counter = Ref(0)
            sweep = CheckpointedSweep(
                cache_dir=dir,
                cell_key=p -> "x",
                runner=p -> begin
                    counter[] += 1
                    (; n=counter[])
                end,
                gate=r -> true,
            )
            r1 = run_cell!(sweep, (;))
            @test r1.n == 1
            # Default: cached
            r2 = run_cell!(sweep, (;))
            @test r2.n == 1
            # force: re-run
            r3 = run_cell!(sweep, (;); force=true)
            @test r3.n == 2
        end
    end
end
