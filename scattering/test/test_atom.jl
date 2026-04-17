using Test
using Scattering
using LinearAlgebra

@testset "Atom construction and single-atom basis" begin
    atom = Eu151()
    @test atom.name == :Eu151
    @test atom.two_I == 5            # I = 5/2
    @test atom.two_J == 7            # J = 7/2
    @test atom.g_J ≈ 1.9934
    @test atom.A_hfs < 0              # sign convention: negative for Eu151 8S_{7/2}
    @test atom.mass > 2.7e5           # ~275k m_e for Eu151

    # Basis dimension = (2J+1)(2I+1) = 8·6 = 48
    basis = build_single_atom_basis(atom)
    @test length(basis) == 48

    # Enumerate F = 1..6, each with 2F+1 states, sum = 48
    F_counts = Dict{Int,Int}()
    for (tF, _) in basis.states
        F_counts[tF] = get(F_counts, tF, 0) + 1
    end
    @test F_counts == Dict(2 => 3, 4 => 5, 6 => 7, 8 => 9, 10 => 11, 12 => 13)

    # States ordered by F ascending then m_F ascending within each F
    # First state should be (F=1, m_F=-1) → (tF=2, tmF=-2)
    @test basis.states[1] == (2, -2)
    @test basis.states[end] == (12, 12)
end

@testset "Hyperfine interval rule" begin
    # For pure magnetic-dipole (B_hfs = 0): E(F+1) - E(F) = A (F+1)
    atom = Eu151(B_hfs_mhz = 0.0)
    # F runs 1..6; intervals E(F+1) - E(F) = A*(F+1)
    intervals = [(Scattering.hfs_energy(atom, 2 * (F + 1)) -
                  Scattering.hfs_energy(atom, 2 * F)) for F in 1:5]
    expected = [atom.A_hfs * (F + 1) for F in 1:5]
    @test intervals ≈ expected rtol = 1e-12
end

@testset "HFS Hamiltonian diagonal + degeneracy in m_F" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    H = hfs_hamiltonian(basis)
    @test H isa Diagonal
    @test size(H) == (48, 48)

    # All states at the same F must share the same HFS energy (no m_F dependence).
    by_F = Dict{Int,Vector{Float64}}()
    for (i, (tF, _)) in enumerate(basis.states)
        push!(get!(by_F, tF, Float64[]), H[i, i])
    end
    for (_, vals) in by_F
        @test maximum(vals) - minimum(vals) < 1e-18
    end
end

@testset "Reduced mass" begin
    a = Eu151(); b = Eu151()
    μ = Scattering.reduced_mass(a, b)
    @test μ ≈ a.mass / 2 rtol = 1e-14
end
