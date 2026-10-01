using Test
using SpinorBEC
using JLD2

@testset "precompile workload releases only its own file handles" begin
    dashboard = SpinorBEC.Dashboard
    mktempdir() do dir
        other_path = joinpath(dir, "other.jld2")
        jldopen(other_path, "w") do f
            f["value"] = 7
        end
        other_handle, _ = dashboard._get_or_open_jld_handle(other_path)
        try
            handles_before = Set(keys(dashboard._OPEN_JLD_HANDLES))
            workload_dir = SpinorBEC._precompile_dashboard_workload()
            @test !ispath(workload_dir)
            @test Set(keys(dashboard._OPEN_JLD_HANDLES)) == handles_before
            @test other_handle["value"] == 7
            @test dashboard._OPEN_JLD_HANDLES[other_path][1] === other_handle
        finally
            dashboard.invalidate_path!(Dict(), Dict(), other_path)
        end
    end
end

@testset "a reader waiting on a retired handle retries the live pool" begin
    dashboard = SpinorBEC.Dashboard
    mktempdir() do dir
        path = joinpath(dir, "retired.jld2")
        jldopen(path, "w") do f
            f["value"] = 34
        end
        old_handle, reader_lock = dashboard._get_or_open_jld_handle(path)
        lock(reader_lock)
        waiter = @async dashboard._with_jld_handle(h -> (h, h["value"]), path)
        yield()  # waiter has looked up the entry and is blocked on its lock
        invalidator = @async dashboard.invalidate_path!(Dict(), Dict(), path)
        yield()  # invalidator retires that entry and waits for the same lock
        unlock(reader_lock)
        try
            result = fetch(waiter)
            wait(invalidator)
            @test result[1] !== old_handle
            @test result[2] == 34
            @test dashboard._OPEN_JLD_HANDLES[path][1] === result[1]
        finally
            dashboard.invalidate_path!(Dict(), Dict(), path)
        end
    end
end

@testset "reader errors release locks and refresh closes the pool" begin
    dashboard = SpinorBEC.Dashboard
    mktempdir() do dir
        path = joinpath(dir, "refresh.jld2")
        jldopen(path, "w") do f
            f["value"] = 21
        end
        handle, _ = dashboard._get_or_open_jld_handle(path)
        try
            @test_throws ErrorException dashboard._with_jld_handle(
                h -> error("reader failed"), path)
            @test dashboard._with_jld_handle(h -> h["value"], path) == 21
            data = Dict("run#1" => 1)
            psi = Dict(path => nothing)
            dashboard.clear_all_caches!(data, psi)
            @test isempty(data)
            @test isempty(psi)
            @test isempty(dashboard._OPEN_JLD_HANDLES)
            @test_throws ArgumentError handle["value"]
        finally
            dashboard.invalidate_path!(Dict(), Dict(), path)
        end
    end
end

@testset "handle capacity and failed opens retire evicted handles" begin
    dashboard = SpinorBEC.Dashboard
    mktempdir() do dir
        paths = String[]
        try
            for i in 1:(dashboard._OPEN_JLD_MAX)
                path = joinpath(dir, "frame_$i.jld2")
                push!(paths, path)
                jldopen(path, "w") do f
                    f["value"] = i
                end
                @test dashboard._with_jld_handle(h -> h["value"], path) == i
                @test length(dashboard._OPEN_JLD_HANDLES) <= dashboard._OPEN_JLD_MAX
            end
            victim, (handle, _) = first(dashboard._OPEN_JLD_HANDLES)
            @test_throws SystemError dashboard._get_or_open_jld_handle(
                joinpath(dir, "missing.jld2"))
            @test !haskey(dashboard._OPEN_JLD_HANDLES, victim)
            @test_throws ArgumentError handle["value"]
        finally
            for path in paths
                dashboard.invalidate_path!(Dict(), Dict(), path)
            end
        end
    end
end

@testset "invalidation waits for readers without blocking other files" begin
    dashboard = SpinorBEC.Dashboard
    mktempdir() do dir
        path = joinpath(dir, "active.jld2")
        other = joinpath(dir, "other.jld2")
        for file in (path, other)
            jldopen(file, "w") do f
                f["value"] = 13
            end
        end
        entered = Channel{JLD2.JLDFile}(1)
        release = Channel{Nothing}(1)
        reader = @async dashboard._with_jld_handle(path) do h
            put!(entered, h)
            take!(release)
            h["value"]
        end
        old_handle = take!(entered)
        invalidator = @async dashboard.invalidate_path!(Dict(), Dict(), path)
        yield()
        other_reader = @async dashboard._with_jld_handle(h -> h["value"], other)
        next_reader = @async dashboard._with_jld_handle(h -> (h, h["value"]), path)
        try
            @test !istaskdone(invalidator)
            @test timedwait(() -> istaskdone(other_reader), 5.0) == :ok
            @test timedwait(() -> istaskdone(next_reader), 5.0) == :ok
            @test fetch(next_reader)[1] !== old_handle
        finally
            put!(release, nothing)
            wait(reader)
            wait(invalidator)
            wait(other_reader)
            wait(next_reader)
            dashboard.invalidate_path!(Dict(), Dict(), other)
        end
        @test fetch(reader) == 13
        @test fetch(other_reader) == 13
        @test fetch(next_reader)[2] == 13
        @test dashboard._with_jld_handle(h -> h["value"], path) == 13
        dashboard.invalidate_path!(Dict(), Dict(), path)
    end
end
