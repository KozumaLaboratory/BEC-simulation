using Test
using Scattering
using LinearAlgebra

@testset "Spin projector matrices: stretched s-wave channel (Eu+Eu)" begin
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 0)
    @test length(chans) == 1

    Q = spin_projector_matrices(atom, chans)
    @test length(Q) == 8     # S = 0..7 for J = 7/2 atoms

    # All projectors are 1×1 for single channel.
    @test all(size(q) == (1, 1) for q in Q)
    # Fully stretched |6,-6;6,-6⟩ ℓ=0 lives in the 𝒮=7 subspace.
    for S in 0:6
        @test Q[S + 1][1, 1] ≈ 0.0 atol = 1e-14
    end
    @test Q[7 + 1][1, 1] ≈ 1.0 atol = 1e-14
end

@testset "Spin projector sum rule: Σ_𝒮 Q^𝒮 = I" begin
    atom = Eu151()
    for (M_tot, ℓ_max) in ((-12, 2), (-6, 2), (0, 2))
        chans = enumerate_channels(atom, M_tot, ℓ_max)
        Q = spin_projector_matrices(atom, chans)
        sumQ = reduce(+, Q)
        @test sumQ ≈ I(length(chans)) atol = 1e-10
    end
end

@testset "W(R) is block-diagonal in (ℓ, m_ℓ)" begin
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 2)
    Q = spin_projector_matrices(atom, chans)

    septet = eueu_septet_params()
    exch = eueu_exchange_params()
    R = 10.0
    W = coupling_matrix(R, Q, septet, exch)

    @test W ≈ W' atol = 1e-12   # Hermitian (real symmetric here)

    for i in 1:length(chans), j in 1:length(chans)
        if chans[i].ℓ != chans[j].ℓ || chans[i].m_ℓ != chans[j].m_ℓ
            @test abs(W[i, j]) < 1e-14
        end
    end
end

@testset "Stretched s-wave: W(R) = V_septet(R)" begin
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 0)
    Q = spin_projector_matrices(atom, chans)

    septet = eueu_septet_params()
    exch = eueu_exchange_params()

    for R in (6.0, 9.2919, 15.0, 50.0)
        W = coupling_matrix(R, Q, septet, exch)
        @test size(W) == (1, 1)
        # Only 𝒮=7 contributes; J(R)·0 correction → V = V_septet.
        @test W[1, 1] ≈ V_septet(septet, R) atol = 1e-14
    end
end

@testset "Toy F=1 atom: stretched two-channel coupling" begin
    # I=0, J=1 toy atom: F=1 only, 3 states. Molecular 𝒮 ∈ {0,1,2}.
    atom = Scattering.AtomParams(:toy, 0, 2, 0.0, 0.0, 1.0, 0.0, 1000.0)

    # Stretched state |1,-1;1,-1⟩, M_tot = -2, ℓ=0 only.
    chans = enumerate_channels(atom, -2, 0)
    @test length(chans) == 1
    Q = spin_projector_matrices(atom, chans)
    # Stretched product ⇒ pure |𝒮=2, M_𝒮=-2⟩
    @test length(Q) == 3    # S = 0, 1, 2 (n_S = tJ + 1 = 3 for tJ = 2)
    @test Q[1][1, 1] ≈ 0.0 atol = 1e-14
    @test Q[2][1, 1] ≈ 0.0 atol = 1e-14
    @test Q[3][1, 1] ≈ 1.0 atol = 1e-14
end

@testset "Centrifugal and threshold extraction" begin
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 2; B_tesla = 1e-4)
    L = centrifugal_vector(chans)
    E = channel_thresholds(chans)
    @test length(L) == length(chans)
    @test length(E) == length(chans)
    for (i, c) in enumerate(chans)
        @test L[i] == c.ℓ * (c.ℓ + 1)
        @test E[i] == c.E_threshold
    end
end
