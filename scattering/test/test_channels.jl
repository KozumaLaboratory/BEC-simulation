using Test
using Scattering

@testset "Channel enumeration: conservation and symmetry" begin
    atom = Eu151()

    # For every channel, m_{F1} + m_{F2} + m_ℓ = M_tot
    for M_tot in (-12, -11, -6, 0, 5)
        chans = enumerate_channels(atom, M_tot, 4)
        for c in chans
            m1 = c.state.tm1 / 2
            m2 = c.state.tm2 / 2
            @test m1 + m2 + c.ℓ == M_tot ||
                  Int(round(m1 + m2)) + c.m_ℓ == M_tot
            # Canonical order
            @test (c.state.tF1, c.state.tm1) <= (c.state.tF2, c.state.tm2)
            # |m_ℓ| ≤ ℓ
            @test abs(c.m_ℓ) <= c.ℓ
            # Identical-boson parity: if identical, ℓ must be even
            if c.state.identical
                @test iseven(c.ℓ)
            end
        end
    end
end

@testset "Stretched channel M_tot = -12" begin
    atom = Eu151()

    # s-wave only: the stretched channel |6,-6; 6,-6⟩ at ℓ=0 is the unique
    # symmetry-allowed state.
    chans = enumerate_channels(atom, -12, 0)
    @test length(chans) == 1
    c = chans[1]
    @test c.state.tF1 == 12 && c.state.tm1 == -12
    @test c.state.tF2 == 12 && c.state.tm2 == -12
    @test c.state.identical
    @test c.ℓ == 0 && c.m_ℓ == 0

    # Up to ℓ=2: add even partial waves. The identical (6,-6;6,-6) pair
    # contributes ℓ=0 (m_ℓ=0) and ℓ=2 (m_ℓ=0). Distinct pairs with
    # m1+m2 > -12 are allowed with m_ℓ = M_tot − (m1+m2), |m_ℓ|≤ℓ.
    chans2 = enumerate_channels(atom, -12, 2)
    # All must conserve M_tot
    @test all(c -> c.state.tm1 / 2 + c.state.tm2 / 2 + c.m_ℓ == -12, chans2)

    # ℓ=1 channels: identical pair excluded, so only distinct pairs.
    ℓ1 = filter(c -> c.ℓ == 1, chans2)
    @test all(c -> !c.state.identical, ℓ1)

    # ℓ=0 channel must be the stretched one only
    ℓ0 = filter(c -> c.ℓ == 0, chans2)
    @test length(ℓ0) == 1
end

@testset "Threshold ordering" begin
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 2; B_tesla = 1e-4)
    # sorted ascending by threshold
    Es = [c.E_threshold for c in chans]
    @test issorted(Es)

    # The lowest threshold at small B should be the stretched
    # |6,-6;6,-6⟩ s-wave (both atoms in the low-field-seeking or
    # high-field-seeking ground state depending on sign of g_F, but at
    # B → 0 the F=6 manifold has the HFS-minimum energy for A<0).
    lowest = chans[1]
    @test lowest.state.tF1 == 12 && lowest.state.tF2 == 12
    @test lowest.state.tm1 == -12 && lowest.state.tm2 == -12
end

@testset "Small-F sanity check (F=1 model atom)" begin
    # A minimal system: I=0, J=1 → F=1, 3 states, much simpler counting.
    atom = Scattering.AtomParams(
        :toy, 0, 2,
        0.0, 0.0,
        1.0, 0.0,
        1000.0,
    )
    basis = build_single_atom_basis(atom)
    @test length(basis) == 3

    # M_tot = -2, ℓ_max = 0: only (F=1,m=-1)+(F=1,m=-1). Identical, 1 ch.
    chans = enumerate_channels(atom, -2, 0)
    @test length(chans) == 1
    @test chans[1].state.identical

    # M_tot = -1, ℓ_max = 1: three channels expected from two distinct pairs
    #   - (F=1,m=-1)+(F=1,m=0): m_ℓ=0, ℓ=0 and ℓ=1 both allowed (distinct)
    #   - (F=1,m=-1)+(F=1,m=+1): m_ℓ=-1, ℓ=1 only (distinct, odd ok)
    # Identical pairs contribute nothing here.
    chans1 = enumerate_channels(atom, -1, 1)
    @test length(chans1) == 3
    @test all(c -> !c.state.identical, chans1)
end
