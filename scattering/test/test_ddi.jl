using Test
using Scattering
using LinearAlgebra

@testset "DDI: s-wave only → zero coupling" begin
    # At M_tot=-12 with ℓ_max=0 there is a single channel and the
    # spatial ⟨ℓ=0|C²|ℓ=0⟩ ≡ 0, so the DDI matrix vanishes.
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 0)
    @test length(chans) == 1
    M = ddi_angular_matrix(atom, chans)
    @test size(M) == (1, 1)
    @test abs(M[1, 1]) < 1e-14
end

@testset "DDI: matrix is real symmetric" begin
    atom = Eu151()
    for M_tot in (-12, -10, -6, 0, 6), ℓ_max in (0, 2)
        chans = enumerate_channels(atom, M_tot, ℓ_max)
        isempty(chans) && continue
        M = ddi_angular_matrix(atom, chans)
        @test size(M) == (length(chans), length(chans))
        @test maximum(abs, M .- transpose(M)) < 1e-10
    end
end

@testset "DDI: stretched (ℓ=0) ↔ (ℓ=2) matrix element vs analytic" begin
    # In the stretched M_tot=-12 channel |F=6,m=-6⟩⊗|F=6,m=-6⟩ (spin =
    # |𝒮=7, M_𝒮=-7; m_{I1}=-5/2, m_{I2}=-5/2⟩), [J₁⊗J₂]²_0 acts only on
    # 𝒮=7 M=-7 with matrix element
    #     ⟨𝒮=7,M=-7 | [J⊗J]²_0 | 𝒮=7,M=-7⟩ = 49/(2√6)
    # (computed directly from [A⊗B]²_0 = (1/√6)(3 A_z B_z − A·B) with
    # A = B = J on the stretched m_J state). The spatial factor is
    # ⟨ℓ=2 m=0 | C²_0 | ℓ=0 m=0⟩ = 1/√5. The phase (-1)^q for q=0 is +1.
    # Hence
    #     M_ang[s,d] = (1/√5) · (49 / (2√6)) = 49 / (2√30),
    #     M_dd[s,d]  = prefactor · 49 / (2√30).
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 2)
    # Find the ℓ=0 channel and the ℓ=2, m_ℓ=0 channel that share the
    # stretched spin state.
    s_idx = findfirst(c -> c.ℓ == 0, chans)
    d_idx = findfirst(c -> c.ℓ == 2 && c.m_ℓ == 0 &&
                             c.state.tF1 == 12 && c.state.tm1 == -12 &&
                             c.state.tF2 == 12 && c.state.tm2 == -12,
                      chans)
    @test s_idx !== nothing
    @test d_idx !== nothing

    M_ang = ddi_angular_matrix(atom, chans)
    expected_ang = 49 / (2 * sqrt(30))
    @test M_ang[s_idx, d_idx] ≈ expected_ang atol = 1e-10
    @test M_ang[d_idx, s_idx] ≈ expected_ang atol = 1e-10

    M_dd = ddi_matrix(atom, chans)
    @test M_dd[s_idx, d_idx] ≈ ddi_prefactor(atom) * expected_ang atol = 1e-12
end

@testset "DDI: prefactor sign and magnitude sanity" begin
    atom = Eu151()
    # prefactor = -√6 α² g_J² μ_B²; for g_J ≈ 2 the numerical value is
    # ≈ -√6 · (1/137)² · 4 · (1/4) = -√6 · α² ≈ -1.30e-4 (E_h·a_0³).
    pf = ddi_prefactor(atom)
    @test pf < 0
    @test abs(pf) < 2e-4
    @test abs(pf) > 1e-5
end
