# The truncated-Wigner seed for the scalar eGPE, and the basis it is drawn in.
#
# The basis is load-bearing and was got wrong once: sampling plane waves instead
# of trap eigenstates counts modes proportional to the SIMULATION BOX, so on the
# Klaus cell the "noise" came out carrying 102 % of N — a different initial
# state wearing the word "seed". Both the mode count and the seeded fraction are
# pinned here so that cannot recur silently.

using Test
using SpinorBEC
using SpinorBEC: make_scalar_ws, seed_scalar_thermal!, ho_eigenfunctions,
    scalar_norm, normalize_scalar!, GridConfig, make_grid

@testset "scalar eGPE thermal seed" begin
    @testset "ho_eigenfunctions are orthonormal, including where the closed form dies" begin
        # Wide, fine grid so the quadrature error is below the tolerance for the
        # highest mode (which oscillates fastest and spreads furthest).
        x = collect(range(-14.0, 14.0; length=2001))
        dx = x[2] - x[1]
        for ω in (1.0, 2.6)
            h = ho_eigenfunctions(x, ω, 14)
            @test all(isfinite, h)                 # the naive H_n/√(2ⁿn!) is not
            for n in (0, 1, 5, 14)
                @test sum(abs2, view(h, :, n + 1)) * dx ≈ 1.0 atol = 1e-6
            end
            for (m, n) in ((0, 1), (0, 2), (3, 4), (7, 14))
                @test abs(sum(view(h, :, m + 1) .* view(h, :, n + 1)) * dx) < 1e-6
            end
        end
        # Calibration: the check above must be able to fail. Two DIFFERENT
        # frequencies' ground states are not orthogonal, so this overlap is ~1.
        h1 = ho_eigenfunctions(x, 1.0, 0)
        h2 = ho_eigenfunctions(x, 2.6, 0)
        @test abs(sum(view(h1, :, 1) .* view(h2, :, 1)) * dx) > 0.9
    end

    @testset "seeded fraction on the Klaus cell is a perturbation" begin
        grid = make_grid(GridConfig((48, 48, 24), (16.0, 16.0, 8.0)))
        ω = (1.0, 1.0, 2.6)
        V = [
            0.5 * (ω[1]^2 * x^2 + ω[2]^2 * y^2 + ω[3]^2 * z^2)
            for x in grid.x[1], y in grid.x[2], z in grid.x[3]
        ]
        ws = make_scalar_ws(grid, V; g_contact=600.0, c_dd=0.0, F=1.0)
        ws.psi .= 0
        n_modes, frac = seed_scalar_thermal!(ws;
            kT=8.33, omega=ω, n_atoms=10000, seed=1)

        # ~300 trap modes below 2k_BT, not the ~6600 plane waves the box holds.
        @test 150 <= n_modes <= 600
        # A few percent of N. The plane-wave version measured 1.02 here.
        @test 0 < frac < 0.1

        # And the number the seed actually deposits agrees with the number it
        # reports — a fraction printed from the occupation sum while the array
        # carries something else would be invisible.
        deposited = scalar_norm(ws) * 10000
        @test deposited ≈ frac * 10000 rtol = 0.2
    end

    @testset "the seed is reproducible and the seed argument matters" begin
        grid = make_grid(GridConfig((32, 32, 16), (12.0, 12.0, 6.0)))
        ω = (1.0, 1.0, 2.6)
        V = [0.5 * (x^2 + y^2 + ω[3]^2 * z^2)
             for x in grid.x[1], y in grid.x[2], z in grid.x[3]]
        mk() = (w=make_scalar_ws(grid, V; g_contact=600.0, c_dd=0.0, F=1.0);
            w.psi.=0; w)
        a = mk();
        b = mk();
        c = mk()
        seed_scalar_thermal!(a; kT=5.0, omega=ω, n_atoms=10000, seed=42)
        seed_scalar_thermal!(b; kT=5.0, omega=ω, n_atoms=10000, seed=42)
        seed_scalar_thermal!(c; kT=5.0, omega=ω, n_atoms=10000, seed=43)
        @test a.psi == b.psi
        @test a.psi != c.psi
    end

    @testset "kT = 0 seeds nothing" begin
        grid = make_grid(GridConfig((16, 16, 8), (8.0, 8.0, 4.0)))
        V = zeros(16, 16, 8)
        ws = make_scalar_ws(grid, V; g_contact=1.0, c_dd=0.0, F=1.0)
        ws.psi .= 1
        before = copy(ws.psi)
        n, f = seed_scalar_thermal!(ws; kT=0.0, omega=(1.0, 1.0, 1.0), n_atoms=100)
        @test n == 0
        @test f == 0
        @test ws.psi == before
    end
end
