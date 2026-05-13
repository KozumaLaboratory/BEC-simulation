using SpinorBEC
using LinearAlgebra
using Test

# U4: Paper #3 validation matrix.
# Confirms the full numerical pipeline (psi field → classify_phase_detailed
# → point_group + channel weights) reproduces Paper #3 §V predictions
# when seeded with the canonical inert state spinors.
#
# Also tests the Sign Pattern Lemma 1 closed form against numerically-
# computed β_S^(c_0) from the pair-amplitude spectrum.

# Helper: embed a single spinor uniformly into a psi field on a small grid.
function _uniform_psi(spinor::Vector{ComplexF64}, grid)
    D = length(spinor)
    n_pts = ntuple(d -> grid.config.n_points[d], grid_ndim(grid))
    psi = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        for c in 1:D
            psi[I, c] = spinor[c]
        end
    end
    psi
end

grid_ndim(::SpinorBEC.Grid{N}) where {N} = N

@testset "Paper #3 §V validation matrix" begin

    # Small 3D grid — Q6 / point-group detection don't care about spatial
    # resolution since psi is uniform in space; only the spinor matters.
    grid_3d = make_grid(SpinorBEC.GridConfig((8, 8, 8), (10.0, 10.0, 10.0)))

    # Canonical ζ vectors are the single source of truth in
    # `src/analysis/canonical_polyhedral_states.jl`. The
    # `(F, expected_point_group, paper3_section)` triples here pin
    # both the spinor data and the downstream detection contract.
    polyhedral_cases = [
        (2, :T_d, "§V.A cyclic"),
        (3, :O_h, "§V.B O:A_2"),
        (4, :O_h, "§V.C cube"),
        (6, :I_h, "§V.D I_h"),
        (8, :O_h, "§V.E cube-like octahedral"),
        (10, :I_h, "§V.F dodecahedral"),
    ]

    for (F, expected_pg, label) in polyhedral_cases
        @testset "F=$F $label" begin
            spinor = Vector{ComplexF64}(SpinorBEC.canonical_polyhedral_spinor(F))
            psi = _uniform_psi(spinor, grid_3d)
            sm = spin_matrices(F)
            r = SpinorBEC.classify_phase_detailed(psi, F, grid_3d, sm)
            @test r.point_group === expected_pg
            # Polyhedral inert states satisfy Lemma 1 ⟨F⟩ = 0.
            @test r.spin_order < 0.1
            # F=6 I_h is the only entry where Q6 ≈ 1 is meaningful.
            F == 6 && @test r.Q6 > 0.9
        end
    end

    @testset "Lemma 1 β_S^(c_0) lower-bound — F=6 I_h" begin
        # Lemma 1 endpoint (Paper #3 §VI): β_0^(c_0) = 1/(2F+1) for any
        # polyhedral inert state. For F=6: β_0^(c_0) = 1/13 ≈ 0.0769.
        # This is the numerical channel weight at S=0 of the I_h state.
        spinor = Vector{ComplexF64}(SpinorBEC.canonical_polyhedral_spinor(6))
        psi = _uniform_psi(spinor, grid_3d)
        F = 6
        spec = SpinorBEC.pair_amplitude_spectrum(psi, F, grid_3d)
        total = sum(values(spec.channel_weights))
        beta_0 = get(spec.channel_weights, 0, 0.0) / max(total, 1e-30)
        # Lemma 1 closed form: β_0^(c_0) = 1/(2F+1)
        @test isapprox(beta_0, 1.0 / 13.0; rtol=0.05)
    end
end
