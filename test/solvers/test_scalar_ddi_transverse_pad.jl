# Transverse zero-padding of the scalar-eGPE dipolar convolution.
#
# What this is NOT: a truncated kernel. It was built to be one — the flagged
# limit in docs/validation/dipolar_supersolid_tube.md was that E_dd is not
# converged in the transverse box — and measurement showed it is something else:
#
#   padding axis d by an integer factor p is EXACTLY equivalent to running with
#   no padding in a box p times larger on that axis.
#
# That identity (verified below to machine precision) is what the padding is
# worth. It is not a new boundary condition; it is a cheaper route to the same
# large-box limit, because the wavefunction grid — kinetic, contact, LHY,
# normalisation, and the ITP step itself — stays small while only the dipolar
# FFT grows. Measured 3.2× faster than the equivalent big box at pad = 4.
#
# The axial axis must stay at pad = 1. A tube cell is a ring, so its axial
# periodicity is physical; padding it would remove the very images that belong
# there. That is also why the spinor path's spherical `ddi_trunc_factor`
# (Ronen-Bortolotti-Bohn) is the wrong tool here — it cuts every direction.

using Test
using SpinorBEC
using StaticArrays: SVector

const _U = SpinorBEC.Units

# 166Er tube cell of Roccuzzo & Ancilotto (2019); see the validation doc.
function _tube_ws(; Lt, nt, pad, nx=48, gamma=0.0)
    atom = Er166
    N = 60_000
    w = 2π * 600.0
    a_ho = sqrt(_U.HBAR / (atom.mass * w))
    a_dd = _U.MU_0 * atom.mu_mag^2 * atom.mass / (12π * _U.HBAR^2)
    L = 15.873e-6 / a_ho
    eps_dd = 1.45
    a_s = a_dd / eps_dd
    grid = make_grid(GridConfig((nx, nt, nt), (L, Lt, Lt)))
    V = [
        0.5 * (grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2)
        for I in CartesianIndices((nx, nt, nt))
    ]
    ws = SpinorBEC.make_scalar_ws(
        grid, V;
        g_contact=4π * (a_s / a_ho) * N,
        c_dd=12π * (a_dd / a_ho) * N,
        F=1.0,
        gamma_lhy=gamma,
        ddi_pad=pad === nothing ? nothing : (1, pad, pad),
    )
    # Analytic trial state: transverse Gaussian × 11-period axial modulation, so
    # only the kernel varies between cases.
    for I in CartesianIndices(ws.psi)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        ws.psi[I] = exp(-(y^2 + z^2) / 2) * sqrt(1 + 0.9 * cos(11 * 2π / L * x)) + 0im
    end
    SpinorBEC.normalize_scalar!(ws)
    ws.rho .= abs2.(ws.psi)
    ws
end

_edd(; kwargs...) =
    SpinorBEC.scalar_energies(_tube_ws(; kwargs...), SVector{3, Float64}(0, 0, 1.0)).E_dd

@testset "Scalar eGPE transverse DDI padding" begin
    @testset "pad = 1 on every axis is the unpadded path" begin
        a = _edd(; Lt=14.0, nt=24, pad=nothing)
        b = _edd(; Lt=14.0, nt=24, pad=1)
        @test a ≈ b rtol = 1e-14
    end

    @testset "pad = p at L_t is exactly no-pad at p·L_t" begin
        # The load-bearing identity. It is also the sharpest available check on
        # the padded k-grid and the embedding: an off-by-one in either would
        # break it far above round-off.
        for (Lt, nt, p) in ((14.0, 24, 2), (14.0, 24, 3), (10.0, 20, 2))
            padded = _edd(; Lt=Lt, nt=nt, pad=p)
            bigbox = _edd(; Lt=p * Lt, nt=p * nt, pad=nothing)
            # Round-off level: the two routes run FFTs of different sizes, so
            # they round differently over ~10⁵ summed terms. Any real
            # discrepancy (a mis-built k grid, an off-by-one embedding) would
            # land many orders above this — the 1/L_t² corrections being
            # resolved here are themselves 1e-3.
            @test padded ≈ bigbox rtol = 1e-10
        end
    end

    @testset "images fall as 1/L_t², not 1/L_t³" begin
        # The periodic images of a tube are parallel LINES of dipoles, and the
        # line-line dipolar energy per unit length falls as 1/R², not the
        # point-point 1/R³. Getting this exponent wrong would corrupt any
        # extrapolation to the isolated tube, so pin it against both candidates.
        e = [_edd(; Lt=14.0, nt=24, pad=p) for p in 2:5]
        @test all(diff(e) .> 0)                       # monotone approach
        for i in 1:2
            p1, p2, p3 = i + 1, i + 2, i + 3
            ratio = (e[i + 1] - e[i]) / (e[i + 2] - e[i + 1])
            pred2 = (1 / p1^2 - 1 / p2^2) / (1 / p2^2 - 1 / p3^2)
            pred3 = (1 / p1^3 - 1 / p2^3) / (1 / p2^3 - 1 / p3^3)
            @test ratio ≈ pred2 rtol = 5e-3
            @test !isapprox(ratio, pred3; rtol=0.1)   # 1/L³ is excluded
        end
    end

    @testset "Richardson in 1/p² reaches the isolated-tube value" begin
        # With the exponent known, two padded evaluations extrapolate. Check the
        # extrapolant is stable when computed from different pairs — an unstable
        # extrapolant would mean the exponent is wrong even if the ratios above
        # happened to pass.
        e = Dict(p => _edd(; Lt=14.0, nt=24, pad=p) for p in 3:6)
        rich(pa, pb) =
            e[pb] + (e[pb] - e[pa]) * (1 / pb^2) / ((1 / pa^2) - (1 / pb^2))
        r45, r56 = rich(4, 5), rich(5, 6)
        @test r45 ≈ r56 rtol = 2e-3
        # And the unpadded box is off from it by a per-cent-level amount, i.e.
        # the correction is real but not order-unity.
        bare = _edd(; Lt=14.0, nt=24, pad=nothing)
        @test 0.005 < abs(bare - r56) / abs(r56) < 0.15
    end

    @testset "padding leaves the rest of the functional alone" begin
        # Only E_dd may move: same state, same grid, same couplings.
        ws0 = _tube_ws(; Lt=14.0, nt=24, pad=nothing, gamma=25.0)
        ws4 = _tube_ws(; Lt=14.0, nt=24, pad=4, gamma=25.0)
        B = SVector{3, Float64}(0, 0, 1.0)
        e0 = SpinorBEC.scalar_energies(ws0, B)
        e4 = SpinorBEC.scalar_energies(ws4, B)
        @test e4.E_kin ≈ e0.E_kin rtol = 1e-14
        @test e4.E_trap ≈ e0.E_trap rtol = 1e-14
        @test e4.E_contact ≈ e0.E_contact rtol = 1e-14
        @test e4.E_lhy ≈ e0.E_lhy rtol = 1e-14
        @test e4.E_dd != e0.E_dd
        @test e4.total - e0.total ≈ e4.E_dd - e0.E_dd rtol = 1e-12
    end

    @testset "argument validation" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        @test_throws ArgumentError SpinorBEC.make_scalar_ddi_pad(grid, (1, 0, 2))
        @test_throws ArgumentError SpinorBEC.make_scalar_ddi_pad(grid, (1, -1, 2))
    end
end
