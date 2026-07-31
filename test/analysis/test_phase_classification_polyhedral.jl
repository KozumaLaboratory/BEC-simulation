# DEFAULT_PHASE_REFERENCES coverage extension to F = 3, 4, 8, 10 polyhedral
# inert states (Paper #3 §V.B/C/E/F).
#
# Sister tests in `test/analysis/test_paper3_validation.jl` verify the
# downstream features (point_group, Q6, channel weights). This file verifies
# that `classify_phase_distance`'s reference table now actually labels
# those features as `:octahedral` / `:cubic` / `:cube_octahedral` /
# `:dodecahedral` instead of falling back to `:unknown`.

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, spin_matrices, canonical_polyhedral_spinor,
    classify_phase_detailed, classify_phase_distance, DEFAULT_PHASE_REFERENCES,
    canonical_polyhedral_point_group

function _uniform_psi_polyhedral(spinor::Vector{ComplexF64}, grid)
    D = length(spinor)
    N = length(grid.config.n_points)
    n_pts = ntuple(d -> grid.config.n_points[d], N)
    psi = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        for c in 1:D
            psi[I, c] = spinor[c]
        end
    end
    psi
end

@testset "DEFAULT_PHASE_REFERENCES polyhedral coverage" begin
    grid_3d = make_grid(GridConfig((8, 8, 8), (10.0, 10.0, 10.0)))

    # Mapping of F → (expected reference phase symbol, expected point group)
    cases = [
        (3, :octahedral, :O_h),
        (4, :cubic, :O_h),
        (8, :cube_octahedral, :O_h),
        (10, :dodecahedral, :I_h),
    ]

    for (F, expected_phase, expected_pg) in cases
        @testset "F=$F → :$expected_phase" begin
            spinor = Vector{ComplexF64}(canonical_polyhedral_spinor(F))
            psi = _uniform_psi_polyhedral(spinor, grid_3d)
            sm = spin_matrices(F)

            features = classify_phase_detailed(psi, F, grid_3d, sm)

            # Point group from peak-density Majorana analysis is unaffected
            # by the reference-table extension but cross-checked here so the
            # detection contract stays bit-stable.
            @test features.point_group === expected_pg

            # Inert-state Schur identity: ⟨F⟩ = 0 → spin_order ≈ 0.
            @test features.spin_order < 0.1

            # Classify with the production reference table.
            result = classify_phase_distance(features, F;
                references=DEFAULT_PHASE_REFERENCES, threshold=0.5)
            @test result.phase === expected_phase

            # canonical_polyhedral_point_group is the single source of truth
            # for the F → point group mapping used by docs / FIG-7.
            @test canonical_polyhedral_point_group(F) === expected_pg
        end
    end

    @testset "F=6 icosahedral (regression — pre-existing reference)" begin
        spinor = Vector{ComplexF64}(canonical_polyhedral_spinor(6))
        psi = _uniform_psi_polyhedral(spinor, grid_3d)
        features = classify_phase_detailed(psi, 6, grid_3d, spin_matrices(6))
        result = classify_phase_distance(features, 6;
            references=DEFAULT_PHASE_REFERENCES, threshold=0.5)
        @test result.phase === :icosahedral
    end

    @testset "Polyhedral references are well-formed" begin
        # Every F ∈ {3, 4, 8, 10} now has a polyhedral entry.
        polyhedral_phases = (:octahedral, :cubic, :cube_octahedral,
            :dodecahedral)
        for F in (3, 4, 8, 10)
            entries = [
                r for r in DEFAULT_PHASE_REFERENCES
                      if r.F == F && r.name in polyhedral_phases
            ]
            @test length(entries) == 1
            @test entries[1].spin_order == 0.0
        end
    end
end
