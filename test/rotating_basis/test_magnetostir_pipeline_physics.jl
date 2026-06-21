# Self-contained physics gate for the magnetostir pipeline AFTER the rotating
# engine was retired (the old rotating-vs-engine equivalence gates went with the
# engine). Runs a small `kind: rotating_basis` ground_state → dynamics pipeline
# (now entirely on the standard split-step path) and asserts the recorded
# :rotating_basis_dynamics arrays are physically sane:
#   - norm conserved under the unitary RT evolution,
#   - per-m populations evolve non-trivially under the rotating field (spin-mixing
#     is actually happening — the run is not frozen),
#   - per-m stays a valid probability vector (≥0, sums to 1),
#   - ⟨L_z⟩ ≈ 0 for a vortex-free cloud (orbital AM is spin-rotation invariant).

using Test
using SpinorBEC

@testset "magnetostir pipeline physics (engine-free)" begin
    gs_params = Dict{String, Any}(
        "F" => 1,
        "grid" => Dict("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "interactions" => Dict("c0" => 12.0, "c1" => 0.5),
        "B" => Dict("p" => 4.0, "q" => 0.0),
        "B_direction" => Dict("theta" => 0.0, "phi" => 0.0),
        "n_steps" => 100,
        "dt" => 0.01,
        "init_m_idx" => 2,   # seed m=0 so spin-mixing has somewhere to go
        "init_sigma" => 1.0,
    )
    step_gs = SpinorBEC.RotatingBasisGroundStateStep(gs_params)
    psi_gs, grid_gs, atom_gs, _, gs_result = SpinorBEC._run_step(
        step_gs, nothing, nothing, nothing, nothing; verbose=false)
    @test haskey(gs_result, :rotating_basis_gs)
    @test isfinite(gs_result[:rotating_basis_mu])

    # In-plane rotating B̂(t): θ=π/2, φ̇=Ω. Drives spin-mixing.
    dyn_params = Dict{String, Any}(
        "duration" => 1.0,
        "dt" => 0.01,
        "save_every" => 10,
        "B_direction" => Dict("theta" => π / 2, "phi" => Dict("rate" => 0.8)),
        "save" => Dict("psi" => false),
    )
    step_dyn = SpinorBEC.RotatingBasisDynamicsStep(dyn_params)
    _, _, _, _, dyn_result = SpinorBEC._run_step(
        step_dyn, psi_gs, grid_gs, atom_gs, nothing;
        verbose=false, pipeline_results=gs_result)

    dyn = dyn_result[:rotating_basis_dynamics]
    norms = dyn[:norms]::Vector{Float64}
    per_m = dyn[:per_m_history]::Vector{Vector{Float64}}
    Lz = dyn[:Lz]::Vector{Float64}

    @test !isempty(per_m)
    # Norm conserved (RT is unitary).
    @test all(n -> isapprox(n, 1.0; atol=1e-4), norms)
    # Each per-m snapshot is a valid probability vector.
    for pm in per_m
        @test all(≥(-1e-10), pm)
        @test isapprox(sum(pm), 1.0; atol=1e-8)
    end
    # The rotating field actually moved population (not frozen).
    @test maximum(abs.(per_m[end] .- per_m[1])) > 1e-3
    # No vortex seeded ⇒ ⟨L_z⟩ ≈ 0 throughout (orbital AM, spin-invariant).
    @test maximum(abs.(Lz)) < 1e-6
end
