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

    @testset "F=2 cyclic (T_d, Paper #3 §V.A)" begin
        # ζ_cyc = (1, 0, i√2, 0, 1) / 2
        spinor = ComplexF64[1.0, 0.0, im*sqrt(2.0), 0.0, 1.0] ./ 2.0
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(2)
        r = SpinorBEC.classify_phase_detailed(psi, 2, grid_3d, sm)
        @test r.point_group === :T_d
        # F=2 cyclic has |F|=0 mean-field → spin_order ≈ 0
        @test r.spin_order < 0.1
    end

    @testset "F=3 octahedral O:A_2 (Paper #3 §V.B)" begin
        # ζ = (|3,+2⟩ - |3,-2⟩) / √2
        spinor = ComplexF64[0, 1, 0, 0, 0, -1, 0] ./ sqrt(2)
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(3)
        r = SpinorBEC.classify_phase_detailed(psi, 3, grid_3d, sm)
        @test r.point_group === :O_h
        @test r.spin_order < 0.1
    end

    @testset "F=4 cube O_h (Paper #3 §V.C)" begin
        # ζ = √(5/24)|+4⟩ + √(7/12)|0⟩ + √(5/24)|-4⟩
        spinor = zeros(ComplexF64, 9)
        spinor[1] = sqrt(5/24); spinor[5] = sqrt(7/12); spinor[9] = sqrt(5/24)
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(4)
        r = SpinorBEC.classify_phase_detailed(psi, 4, grid_3d, sm)
        @test r.point_group === :O_h
        @test r.spin_order < 0.1
    end

    @testset "F=6 icosahedral I_h (Paper #3 §V.D)" begin
        # Use IcosahedralMod's canonical state.
        spinor = Vector{ComplexF64}(SpinorBEC.IcosahedralMod.ZETA_F6_IH)
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(6)
        r = SpinorBEC.classify_phase_detailed(psi, 6, grid_3d, sm)
        @test r.point_group === :I_h
        @test r.spin_order < 0.1
        # Q6 Steinhardt order ≈ 1 for icosahedral state
        @test r.Q6 > 0.9
    end

    @testset "F=8 cube-like octahedral O:A_1 (Paper #3 §V.E)" begin
        # ζ = √390/48 (|±8⟩) + √42/24 (|±4⟩) + √33/8 |0⟩
        spinor = zeros(ComplexF64, 17)
        spinor[1] = sqrt(390)/48; spinor[5] = sqrt(42)/24; spinor[9] = sqrt(33)/8
        spinor[13] = sqrt(42)/24; spinor[17] = sqrt(390)/48
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(8)
        r = SpinorBEC.classify_phase_detailed(psi, 8, grid_3d, sm)
        @test r.point_group === :O_h
        @test r.spin_order < 0.1
    end

    @testset "F=10 dodecahedral I_h (Paper #3 §V.F)" begin
        spinor = zeros(ComplexF64, 21)
        spinor[1] = sqrt(561)/75; spinor[6] = sqrt(209)/25
        spinor[11] = sqrt(741)/75
        spinor[16] = -sqrt(209)/25; spinor[21] = sqrt(561)/75
        psi = _uniform_psi(spinor, grid_3d)
        sm = spin_matrices(10)
        r = SpinorBEC.classify_phase_detailed(psi, 10, grid_3d, sm)
        @test r.point_group === :I_h
        @test r.spin_order < 0.1
    end

    @testset "Lemma 1 β_S^(c_0) lower-bound — F=6 I_h" begin
        # Lemma 1 endpoint (Paper #3 §VI): β_0^(c_0) = 1/(2F+1) for any
        # polyhedral inert state. For F=6: β_0^(c_0) = 1/13 ≈ 0.0769.
        # This is the numerical channel weight at S=0 of the I_h state.
        spinor = Vector{ComplexF64}(SpinorBEC.IcosahedralMod.ZETA_F6_IH)
        psi = _uniform_psi(spinor, grid_3d)
        F = 6
        spec = SpinorBEC.pair_amplitude_spectrum(psi, F, grid_3d)
        total = sum(values(spec.channel_weights))
        beta_0 = get(spec.channel_weights, 0, 0.0) / max(total, 1e-30)
        # Lemma 1 closed form: β_0^(c_0) = 1/(2F+1)
        @test isapprox(beta_0, 1.0 / 13.0; rtol=0.05)
    end
end
