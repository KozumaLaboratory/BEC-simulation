using Test
using Scattering
using Scattering: _fold_first_zone
using LinearAlgebra

@testset "ladder operators: [J_+, J_-] = 2 J_z and [I_+, I_-] = 2 I_z" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    Jp = Jplus_matrix(basis)
    Jm = Matrix(Jp')
    Jz = Jz_matrix(basis)
    @test norm(Jp * Jm - Jm * Jp - 2 * Jz) < 1e-10

    Ip = Iplus_matrix(basis)
    Im = Matrix(Ip')
    Iz = Iz_matrix(basis)
    @test norm(Ip * Im - Im * Ip - 2 * Iz) < 1e-10
end

@testset "ladder: J² = J_z² + (J_+ J_- + J_- J_+)/2 has eigenvalue J(J+1)" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    Jp = Jplus_matrix(basis)
    Jm = Matrix(Jp')
    Jz = Jz_matrix(basis)
    J2 = Jz * Jz + 0.5 * (Jp * Jm + Jm * Jp)
    Jv = atom.two_J / 2
    @test norm(J2 - (Jv * (Jv + 1)) * I) < 1e-10
end

@testset "zero MW: Floquet spectrum = H_0 − nω" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    H0 = single_atom_hamiltonian(basis, 1e-4)
    d = length(basis)
    ω = 1e-6
    field = MWField(MWTone(ω, zeros(ComplexF64, d, d)))
    N = 2
    HF = floquet_hamiltonian(H0, field; n_photon = N)
    vals = sort(eigvals(Hermitian(HF)))
    evals0 = sort(eigvals(Hermitian(H0)))
    expected = sort([e - n * ω for n in -N:N, e in evals0][:])
    @test isapprox(vals, expected; atol = 1e-14)
end

@testset "Floquet Hamiltonian hermitian and single-tone band-1 structure" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    H0 = single_atom_hamiltonian(basis, 1e-4)
    d = length(basis)
    ω = 1e-6
    tone = mw_sigma_plus(basis, ω, 1e-7)
    HF = floquet_hamiltonian(H0, MWField(tone); n_photon = 3)
    @test HF ≈ HF'

    N = 3
    for na in -N:N, nb in -N:N
        abs(na - nb) <= 1 && continue
        A = HF[((na + N) * d + 1):((na + N + 1) * d),
               ((nb + N) * d + 1):((nb + N + 1) * d)]
        @test norm(A) < 1e-14
    end
end

# Two-level test fixtures: rotating V couples only |g⟩↔|e⟩ for clean analytics.
function _two_level_H0(ω_0)
    Float64[0.0 0.0; 0.0 ω_0]
end

function _two_level_V(Ω_half)
    v = zeros(ComplexF64, 2, 2)
    v[2, 1] = Ω_half    # V |g⟩ = Ω_half |e⟩  (raises)
    v
end

@testset "two-level RWA: on-resonance σ+ splitting = 2|V|" begin
    ω_0 = 1e-3
    Ω_half = 1e-6
    H0 = _two_level_H0(ω_0)
    V = _two_level_V(Ω_half)
    field = MWField(MWTone(ω_0, V))
    N = 6
    HF = floquet_hamiltonian(H0, field; n_photon = N)
    vals = eigvals(Hermitian(HF))
    # Fold to [−ω/2, ω/2) and collect distinct values.
    folded = sort([v - round(v / ω_0) * ω_0 for v in vals])
    @test minimum(folded) ≈ -Ω_half atol = 1e-12
    @test maximum(folded) ≈ +Ω_half atol = 1e-12
end

@testset "two-level RWA: far-detuned AC Stark shift" begin
    ω_0 = 1.0
    Ω_half = 1e-4
    Δ = 1e-2                         # drive ω − ω_0
    ω = ω_0 + Δ
    H0 = _two_level_H0(ω_0)
    V = _two_level_V(Ω_half)
    field = MWField(MWTone(ω, V))
    N = 3
    HF = floquet_hamiltonian(H0, field; n_photon = N)
    vals = eigvals(Hermitian(HF))
    folded = sort([v - round(v / ω) * ω for v in vals])
    # In the rotating frame the 2-level problem reduces to
    # [[0, V*]; [V, -Δ]] → eigenvalues −Δ/2 ± (1/2)√(Δ² + 4Ω_half²).
    # Fold both into [-ω/2, ω/2): for |Δ| ≪ ω both are close to 0 and −Δ.
    disc = sqrt(Δ^2 + 4 * Ω_half^2)
    λ_minus = -Δ/2 - disc/2                      # ground-like
    λ_plus  = -Δ/2 + disc/2                      # excited-like (bare ≈ -Δ + Ω²/Δ)
    λ_minus_folded = λ_minus - round(λ_minus / ω) * ω
    λ_plus_folded  = λ_plus  - round(λ_plus  / ω) * ω
    @test any(v -> isapprox(v, λ_minus_folded; atol = 1e-10), folded)
    @test any(v -> isapprox(v, λ_plus_folded;  atol = 1e-10), folded)
end

@testset "Floquet dressed states reproduce bare spectrum for zero drive" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    H0 = single_atom_hamiltonian(basis, 1e-4)
    d = length(basis)
    ω = 1e-6
    field = MWField(MWTone(ω, zeros(ComplexF64, d, d)))
    N = 2
    HF = floquet_hamiltonian(H0, field; n_photon = N)
    states = floquet_dressed_states(HF, basis, ω, N)
    @test length(states) == d
    bare = sort(real(eigvals(Hermitian(H0))))
    got = sort([s.quasi_energy for s in states])
    expected = sort([_fold_first_zone(e, ω) for e in bare])
    @test isapprox(got, expected; atol = 1e-10)
    # Each state should be labeled with the bare (tF, tm) matching its
    # primary content (since at B=1e-4 T HFS ≫ Zeeman so (F,m) is good).
    for s in states
        @test (s.primary_two_F, s.primary_two_m) in basis.states
    end
end

@testset "mw_sigma_minus = mw_sigma_plus†" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    ω = 1e-6
    B = 1e-8
    Vp = mw_sigma_plus(basis, ω, B).V
    Vm = mw_sigma_minus(basis, ω, B).V
    @test Vm ≈ Vp'
end

@testset "mw_sigma_plus V raises m_F by 1" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    V = mw_sigma_plus(basis, 1e-6, 1e-8).V
    for i in eachindex(basis.states), j in eachindex(basis.states)
        tm1 = basis.states[i][2]
        tm2 = basis.states[j][2]
        if tm1 != tm2 + 2       # σ+ must satisfy m1 − m2 = +1, i.e. tm1−tm2 = 2
            @test abs(V[i, j]) < 1e-18
        end
    end
end

@testset "mw_pi V conserves m_F" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    V = mw_pi(basis, 1e-6, 1e-8).V
    for i in eachindex(basis.states), j in eachindex(basis.states)
        if basis.states[i][2] != basis.states[j][2]
            @test abs(V[i, j]) < 1e-18
        end
    end
end

