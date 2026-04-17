using Test
using Scattering
using LinearAlgebra

@testset "Two-atom hyperfine ↔ molecular transform (toy F=1 atom)" begin
    # I=0, J=1 ⇒ F=1, 3 states/atom. Molecular 𝒮 ∈ {0,1,2}.
    atom = Scattering.AtomParams(:toy, 0, 2, 0.0, 0.0, 1.0, 0.0, 1000.0)

    for M_tot in -2:2
        hf = build_two_atom_hyperfine_basis(atom, M_tot)
        mol = build_two_atom_molecular_basis(atom, M_tot)
        @test length(hf) == length(mol)       # same Hilbert block

        U = hyperfine_to_molecular_transform(atom, hf, mol)
        # Unitarity at fixed M_tot block
        @test U' * U ≈ I(length(hf)) atol = 1e-12
        @test U * U' ≈ I(length(mol)) atol = 1e-12
    end
end

@testset "Two-atom transform: Eu+Eu block sizes and unitarity" begin
    atom = Eu151()
    # M_tot = -12 (stretched) : only |6,-6;6,-6⟩ on hyperfine side and
    # |𝒮 M_𝒮=-7 or similar; m_{I1}=m_{I2}=-5/2⟩ blocks on molecular side.
    for M_tot in (-12, -6, 0, 5, 11)
        hf  = build_two_atom_hyperfine_basis(atom, M_tot)
        mol = build_two_atom_molecular_basis(atom, M_tot)
        @test length(hf) == length(mol)

        U = hyperfine_to_molecular_transform(atom, hf, mol)
        @test U' * U ≈ I(length(hf)) atol = 1e-10
        @test U * U' ≈ I(length(mol)) atol = 1e-10
    end
end

@testset "Stretched |6,-6;6,-6⟩ → |𝒮=7, M_𝒮=-7; m_{I1}=-5/2, m_{I2}=-5/2⟩" begin
    atom = Eu151()
    hf  = build_two_atom_hyperfine_basis(atom, -12)
    mol = build_two_atom_molecular_basis(atom, -12)

    # Exactly one hyperfine state at M_tot = -12 (both stretched)
    @test length(hf) == 1
    h = hf[1]
    @test h.tF1 == 12 && h.tm1 == -12
    @test h.tF2 == 12 && h.tm2 == -12

    U = hyperfine_to_molecular_transform(atom, hf, mol)
    # All amplitude on the fully-stretched molecular state
    #   𝒮 = 7 (2𝒮 = 14), M_𝒮 = -7 (2M_𝒮 = -14), m_{I1} = m_{I2} = -5/2
    row_target = findfirst(
        m -> m.two_S == 14 && m.two_MS == -14 &&
             m.two_mI1 == -5 && m.two_mI2 == -5,
        mol,
    )
    @test !isnothing(row_target)
    @test abs(U[row_target, 1]) ≈ 1.0 atol = 1e-12

    # All other rows are zero
    for r in 1:size(U, 1)
        r == row_target && continue
        @test abs(U[r, 1]) < 1e-12
    end
end

@testset "Orthogonal projectors Σ_𝒮 P_𝒮 = I in the hyperfine block" begin
    atom = Eu151()
    M_tot = -6
    hf  = build_two_atom_hyperfine_basis(atom, M_tot)
    mol = build_two_atom_molecular_basis(atom, M_tot)
    U = hyperfine_to_molecular_transform(atom, hf, mol)

    # Projector onto a given 𝒮: diagonal in the molecular basis.
    # The sum over 𝒮 of P_𝒮 = 1, so in the hyperfine basis
    # Σ_𝒮 U' · diag(1[𝒮]) · U = I.
    n = length(hf)
    sum_proj = zeros(Float64, n, n)
    tJ = atom.two_J
    for tS in 0:2:(tJ + tJ)
        mask = [m.two_S == tS for m in mol]
        D = Diagonal(Float64.(mask))
        sum_proj .+= U' * D * U
    end
    @test sum_proj ≈ I(n) atol = 1e-10
end
