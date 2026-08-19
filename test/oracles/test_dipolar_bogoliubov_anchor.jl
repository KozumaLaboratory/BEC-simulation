using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _bdg_ddi_matrices, _q_tensor_direction, bdg_chemical_potential

# The DDI block of the homogeneous BdG, against a closed form and against zero.
#
# `test_bogoliubov_anchor.jl` pins the CONTACT spectrum to the F=1 analytic
# dispersion and says so in its own KNOWN-LIMIT: the DDI block was pinned by
# nothing. It was wrong, in two ways that a spectrum check on a polar state
# cannot see and a polarized one can only half see (#361):
#
#   * the normal block was the HARTREE term `c_dd Q_ab ⟨F_b⟩ (F_a)_{mm'}`,
#     evaluated at the fluctuation direction `Q(k̂)`. For a uniform condensate
#     the Hartree term samples `Q(q=0) = 0` and is absent; what belongs there is
#     the EXCHANGE term, `½ c_dd Q_ab (F_aζ)_m conj((F_bζ)_{m'})`.
#   * on a fully polarized state the two forms differ only by a factor 2, so the
#     DDI part of `L` was exactly twice too large — visible only against a
#     closed form, which is this file's first testset.
#   * on a polar state `⟨F⟩ = 0` makes the old form identically zero, so the
#     normal DDI block vanished where the spin-roton lives — the second testset.
#
# A fully polarized dipolar condensate has the textbook dispersion
#
#     ω(k)² = ε_k [ ε_k + 2n₀ ( g_{2F} + c_dd F² Q_zz(k̂) ) ],   ε_k = k²/2,
#
# exact, not asymptotic: the condensate component's 2×2 BdG block closes on
# itself because the transverse pieces `(F_±ζ)` live in the m = F−1 sector.
# `Q_zz = k̂_z² − 1/3` carries the (3cos²θ−1)/3 anisotropy, so the SAME fixture
# read along ẑ and along x̂ is a directional oracle: the DDI stiffens the phonon
# along the polarization and softens it across.

const _F_CASES = (1, 6)

"Phonon branch of a uniform, fully polarized (m = +F) condensate."
function _phonon(F, k, k_dir; c0, c_dd, n0, p)
    D = 2F + 1
    ζ = zeros(ComplexF64, D)
    ζ[1] = 1.0                                   # c = 1 ⇔ m = +F
    # p gaps the magnons so the phonon is the lowest positive branch; it cannot
    # touch the phonon itself, since ⟨ζ|Z|ζ⟩ cancels against the same term in μ.
    res = bogoliubov_spectrum(; spinor=ζ, n0=n0, F=F,
        interactions=InteractionParams(Dict(0 => c0, 1 => 0.0)),
        zeeman=ZeemanParams(p, 0.0), c_dd=c_dd,
        k_max=k, n_k=2, k_direction=k_dir)
    w = real.(res.omega[:, 2])                   # omega is (2D, n_k): k SECOND
    ω = minimum(filter(>(1e-9), w))
    # GUARD, not decoration: the phonon is identified as the lowest positive
    # branch, which is only true while it sits below the Zeeman gap. If a magnon
    # ever undercuts it the comparison would be against the wrong branch, so
    # fail here instead of reporting a mismatch as physics.
    ω < 0.9p || error("branch selection unsafe: ω = $ω against a magnon gap of $p")
    ω
end

_analytic(F, k; c0, c_dd, n0, Qzz) =
    sqrt((k^2 / 2) * (k^2 / 2 + 2n0 * (c0 + c_dd * F^2 * Qzz)))

@testset "polarized dipolar BdG = the closed form, both directions" begin
    # p = 8 keeps the magnon gap clear of the phonon at every (F, k, k̂) below:
    # the largest phonon here is F=6, k=2, k ∥ z at ω = 3.58.
    c0, c_dd, n0, p = 1.0, 0.05, 1.0, 8.0
    for F in _F_CASES,
        (dir, Qzz, name) in (((0.0, 0.0, 1.0), 2 / 3, "k ∥ z"),
            ((1.0, 0.0, 0.0), -1 / 3, "k ⊥ z"))

        @testset "F=$F, $name" begin
            for k in (0.5, 1.0, 2.0)
                got = _phonon(F, k, dir; c0, c_dd, n0, p)
                want = _analytic(F, k; c0, c_dd, n0, Qzz)
                @test isapprox(got, want; rtol=1e-9)
            end
        end
    end

    # The anchor is only an anchor if the DDI moves it. At F=6 the dipolar term
    # is c_dd F² Q_zz = ±0.6 / ∓0.6 against a contact 1.0, so the two directions
    # must disagree by a large factor — and the OLD normal block, being twice
    # this size, misses each of them by ~20 % at k = 0.5.
    @testset "the knob moves, and by how much" begin
        F = 6
        zk = _phonon(F, 0.5, (0.0, 0.0, 1.0); c0, c_dd, n0, p)
        xk = _phonon(F, 0.5, (1.0, 0.0, 0.0); c0, c_dd, n0, p)
        @test zk > 1.25 * xk
        # what the pre-#361 form would have produced: DDI part doubled in L only
        # (the anomalous block was already right), so it is NOT a rescaling of
        # the closed form and cannot be absorbed into c_dd.
        eps_k = 0.5^2 / 2
        gz = c0 + c_dd * F^2 * (2 / 3)
        old_z = sqrt((eps_k + n0 * (c0 + 2 * c_dd * F^2 * (2 / 3)))^2 - (n0 * gz)^2)
        @test abs(old_z - zk) / zk > 0.1
    end
end

@testset "polar state: the normal DDI block is not zero" begin
    # ⟨F⟩ = 0 for ζ = e₀, which is exactly what the Hartree form multiplies by.
    # The exchange form does not vanish there — F_x ζ and F_y ζ are non-zero for
    # any spinor — and it is the term that carries the spin-roton.
    for F in _F_CASES
        D = 2F + 1
        ζ = zeros(ComplexF64, D)
        ζ[(D + 1) ÷ 2] = 1.0                     # m = 0
        @test abs(real(ζ' * Matrix(spin_matrices(F).Fz) * ζ)) < 1e-12
        h, M = _bdg_ddi_matrices(ζ, F, D, spin_matrices(F), 0.05,
            _q_tensor_direction([0.0, 0.0, 1.0]))
        @test norm(h) > 1e-6
        @test norm(M) > 1e-6
        # Normal and anomalous are the same second variation with one index
        # conjugated, and on this fixture that predicts their difference in
        # closed form. ζ = e₀ real and k̂ = ẑ leave only the xx and yy channels;
        # F_x ζ is real so xx cancels in `2h − M`, while F_y ζ is imaginary
        # (conj = −itself) so yy survives doubled:
        #     2h − M = −2 c_dd Q_yy (F_yζ)(F_yζ)ᵀ.
        # A stray conj() anywhere in either block breaks this and nothing else
        # in this file would notice.
        vy = Matrix{ComplexF64}(spin_matrices(F).Fy) * ζ
        @test isapprox(2 .* h .- M, -2 * 0.05 * (-1 / 3) .* (vy * transpose(vy));
            atol=1e-12)
    end
end

@testset "μ is a property of the state, not of the probe" begin
    # It must not depend on k̂. Before #361 every call site built it from
    # contact + DDI(k̂), so looking along z and along x gave two chemical
    # potentials for one condensate.
    F = 6
    D = 2F + 1
    ζ = zeros(ComplexF64, D)
    ζ[1] = 1.0
    ip = InteractionParams(Dict(0 => 1.0, 1 => 0.0))
    h_contact, _, zee, _ = SpinorBEC._bdg_contact_matrices(ζ, F, ip, ZeemanParams(3.0, 0.0))
    mu = bdg_chemical_potential(h_contact, zee, ζ, 1.0)
    for dir in ([0.0, 0.0, 1.0], [1.0, 0.0, 0.0], [1.0, 1.0, 0.0] ./ sqrt(2))
        h_ddi, _ = _bdg_ddi_matrices(ζ, F, D, spin_matrices(F), 0.05,
            _q_tensor_direction(dir))
        # the DDI block is direction-dependent (control) …
        @test norm(h_ddi) > 1e-6
        # … and μ, built from contact alone, is not.
        @test bdg_chemical_potential(h_contact, zee, ζ, 1.0) == mu
    end
end
