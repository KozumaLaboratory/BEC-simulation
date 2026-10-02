# Compare all four certified states after a same-node ABBA solve benchmark.
# julia --project=. bench/compare_solver_states.jl PREFIX
using JLD2, LinearAlgebra, Printf, Test
prefix = isempty(ARGS) ? "" : ARGS[1]
a = load("logs/solver_$(prefix)C1.jld2")
psi_a, rec_a = a["psi"], a["record"]
records = Dict("C1" => rec_a)
@testset "solver ABBA state agreement $prefix" begin
    for label in ("D1", "D2", "C2")
        b = load("logs/solver_$prefix$label.jld2")
        psi_b, rec_b = b["psi"], b["record"]
        records[label] = rec_b
        overlap = dot(vec(psi_a), vec(psi_b))
        phase = iszero(overlap) ? one(overlap) : overlap / abs(overlap)
        error = norm(psi_b .- phase .* psi_a) / norm(psi_a)
        energy_error = abs(rec_b.energy - rec_a.energy)
        @printf("STATE_AB label=%s energy_error=%.4e relative_state_error=%.4e\n",
            label, energy_error, error)
        @test rec_a.fresh_residual <= 1e-8
        @test rec_b.fresh_residual <= 1e-8
        @test isapprox(rec_a.energy, rec_b.energy; rtol=1e-10, atol=1e-10)
        @test error <= 1e-5
        @test rec_b.n == rec_a.n
        @test rec_b.julia == rec_a.julia
        if hasproperty(rec_a, :source_sha256)
            @test hasproperty(rec_b, :source_sha256)
            @test rec_b.source_sha256 == rec_a.source_sha256
        end
    end
end
baseline_seconds = (records["C1"].seconds + records["C2"].seconds) / 2
candidate_seconds = (records["D1"].seconds + records["D2"].seconds) / 2
@printf(
    "SOLVER_ABBA prefix=%s baseline_mean_seconds=%.6f candidate_mean_seconds=%.6f speedup=%.4f\n",
    prefix, baseline_seconds, candidate_seconds, baseline_seconds / candidate_seconds)
