using Test
using SpinorBEC

@testset "memory audit: entry-point reachability and repair preconditions" begin
    python = Sys.iswindows() ? "python" : "python3"
    suite = joinpath(@__DIR__, "python", "test_audit_memory.py")
    @test success(`$python -X utf8 $suite`)
end
