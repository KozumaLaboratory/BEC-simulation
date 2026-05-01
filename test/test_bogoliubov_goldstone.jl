using Test
using LinearAlgebra
using SpinorBEC

# Bogoliubov ferromagnetic Goldstone-mode regression.
#
# A homogeneous ferromagnetic state in zero magnetic field spontaneously
# breaks SU(2). The associated Goldstone modes must satisfy ω(k → 0) → 0.
#
# History (2026-05-02): a previous version of this test sliced the BdG
# omega matrix as `bdg.omega[1, :]` — that's the *first row* across all
# k columns, but `_bdg_k_scan` writes eigenvalues into `omega[:, ik]`
# in the LAPACK-arbitrary order returned by `eigen`. Picking the
# row-1 eigenvalue at every k is meaningless; in F=6 the test happened
# to read the LARGEST mode (≈ ±c_dd·Q_zz·F·m·n₀ ≈ 1440 for the Eu-scale
# problem here), not the Goldstone. The CLAUDE.md note about a μ
# convention bug was an artifact of this indexing.
#
# Correct slice: `bdg.omega[:, 1]` — all eigenvalues at the smallest
# `k`, where the gap actually lives.

@testset "Bogoliubov ferromagnetic Goldstone mode" begin
    n0 = 0.1

    @testset "F=1 contact-only ferromagnetic phase, zero field" begin
        F = 1
        spinor_FM = ComplexF64[1.0, 0.0, 0.0]   # |m = +F⟩
        ip = InteractionParams(50.0, -2.0)      # c1 < 0 → ferromagnetic
        zee = ZeemanParams(0.0, 0.0)

        bdg = bogoliubov_spectrum(;
            spinor=spinor_FM, n0=n0, F=F,
            interactions=ip, zeeman=zee,
            c_dd=0.0,
            k_max=0.05, n_k=50,
            k_direction=(0.0, 0.0, 1.0),
        )

        # Slice across all eigenvalues at the smallest k probed.
        # F=1 contact-only FM: 1 gauge Goldstone (n0 phase) + 1 spin
        # Goldstone (transverse magnon) → 2 zeros expected at k=0.
        gap = minimum(abs.(real.(bdg.omega[:, 1])))
        @test gap < 1e-6
        @info "F=1 FM gap at k=0 = $(round(gap; sigdigits=4))  (true Goldstone present)"
    end

    @testset "F=6 DDI-on ferromagnetic, k̂ ∥ magnetization, zero field" begin
        F = 6
        spinor_FM = ComplexF64[1.0, zeros(ComplexF64, 12)...]
        ip = InteractionParams(100.0, 0.0)
        zee = ZeemanParams(0.0, 0.0)
        c_dd_eu = 200.0

        bdg = bogoliubov_spectrum(;
            spinor=spinor_FM, n0=n0, F=F,
            interactions=ip, zeeman=zee,
            c_dd=c_dd_eu,
            k_max=0.05, n_k=50,
            k_direction=(0.0, 0.0, 1.0),
        )

        # F=6 FM with k̂ ∥ ẑ: gauge mode + 3 spin Goldstones (SU(2) → U(1))
        # → 4 zeros expected at k=0. Loosen the threshold a hair to
        # absorb the small but finite contact piece in the smallest k bin.
        gap = minimum(abs.(real.(bdg.omega[:, 1])))
        @test gap < 1e-6
        @info "F=6 FM gap at k=0 = $(round(gap; sigdigits=4))  (true Goldstone present)"
    end
end
