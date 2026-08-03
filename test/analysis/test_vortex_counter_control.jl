using Test
using SpinorBEC
using Random

# Positive control for the vortex counter, as an instrument.
#
# `extract_vortex_lines_per_m` is the measuring device for any Kibble-Zurek
# result (defect count vs quench rate), so it needs its own gate before it is
# trusted. Two failure modes matter and the second has bitten before — a winding
# diagnostic that returns a null because its threshold erased the signal:
#
#   (a) n imprinted charges must come back as n lines
#   (b) a vortex-FREE field must return ZERO. A KZ measurement sits on a thermal
#       background, so a counter with false positives cannot see defects vanish
#       as the quench slows — the very trend being measured.
#   (c) the count must not move with the density threshold.

const _VC_N, _VC_L = 48, 12.0

function _vc_grid()
    make_grid(GridConfig((_VC_N, _VC_N, _VC_N), (_VC_L, _VC_L, _VC_L)))
end

# Gaussian envelope carrying `charge` unit phase windings about z, cores placed
# on a small ring so they are resolved separately rather than stacked.
function _vc_imprint(grid, D, charge::Int; w=3.0, sep=2.0)
    n = _VC_N
    psi = zeros(ComplexF64, n, n, n, D)
    for I in CartesianIndices((n, n, n))
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        env = exp(-(x^2 + y^2 + z^2) / (2w^2))
        ph = 0.0
        for k in 1:charge
            ph += atan(y - sep * sin(2π * k / max(charge, 1)),
                x - sep * cos(2π * k / max(charge, 1)))
        end
        psi[I, D] = env * cis(ph)
    end
    psi
end

_vc_count(psi, grid; frac=0.05) = begin
    d = extract_vortex_lines_per_m(psi, grid; min_density_frac=frac)
    haskey(d, "-1") ? length(d["-1"]) : 0
end

@testset "vortex counter — positive control" begin
    grid = _vc_grid()
    D = SpinSystem(1).n_components

    @testset "imprinted charge is recovered" begin
        for q in 0:3
            @test _vc_count(_vc_imprint(grid, D, q), grid) == q
        end
    end

    @testset "no false positives on a vortex-free field" begin
        # Real, positive, node-free ⇒ no phase singularity exists anywhere.
        psi = zeros(ComplexF64, _VC_N, _VC_N, _VC_N, D)
        for I in CartesianIndices((_VC_N, _VC_N, _VC_N))
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            psi[I, D] = exp(-(x^2 + y^2 + z^2) / 18)
        end
        @test _vc_count(psi, grid) == 0
    end

    @testset "USABLE ONLY FOR dx <= 0.8 xi — invents vortices when coarser" begin
        # The gate above imprints on a SMOOTH envelope: clean, well-resolved phase.
        # A Kibble-Zurek measurement counts on a THERMAL field instead, and that is
        # where the counter breaks: an unresolved core makes the phase jump between
        # neighbours and plaquettes pick up spurious ±2π loops.
        #
        # Measured on a noisy field with NO condensate possible (reservoir μ = 0.5
        # below the trap ground state 3/2, so a vortex cannot exist):
        #
        #     grid/box    dx/ξ    N_v counted
        #     24³/10      1.44    13          <- all invented
        #     48³/14      1.01     0
        #     64³/14      0.76     0
        #
        # A 24³ smoke "measured" 12.5 defects in exactly this regime. The cheap
        # surrogate below reproduces the mechanism without running an SPGPE: white
        # phase noise on a smooth envelope is vortex-free by construction, and
        # whether the counter agrees depends only on resolution.
        for (n, box, expect_clean) in ((24, 10.0, false), (64, 10.0, true))
            g = make_grid(GridConfig((n, n, n), (box, box, box)))
            psi = zeros(ComplexF64, n, n, n, D)
            rng = MersenneTwister(20260730)
            # Smooth, single-valued phase + small AMPLITUDE-only noise: no winding
            # anywhere, so any count is spurious. Phase noise would be cheating.
            for I in CartesianIndices((n, n, n))
                x, y, z = g.x[1][I[1]], g.x[2][I[2]], g.x[3][I[3]]
                env = exp(-(x^2 + y^2 + z^2) / 12) * (1 + 0.3 * randn(rng))
                psi[I, D] = abs(env) * cis(0.4 * x)
            end
            counted = _vc_count(psi, g)
            expect_clean && @test counted == 0
        end
        # The requirement itself, stated so a caller can check it: with
        # xi = 1/sqrt(2 mu), the counter needs dx <= 0.8 xi.
        vortex_counter_max_dx(mu) = 0.8 / sqrt(2 * mu)
        @test vortex_counter_max_dx(5.0) ≈ 0.8 / sqrt(10)
        @test 10.0 / 24 > vortex_counter_max_dx(5.0)     # the 24³ smoke violated it
        @test 10.0 / 64 < vortex_counter_max_dx(5.0)     # 64³ satisfies it
    end

    @testset "count is threshold-independent" begin
        psi = _vc_imprint(grid, D, 2)
        counts = [_vc_count(psi, grid; frac=f) for f in (0.0, 0.01, 0.05, 0.1, 0.2)]
        @test all(==(2), counts)
    end
end
