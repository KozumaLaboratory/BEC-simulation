#!/usr/bin/env julia
#
# The ITP fixed point is trustworthy only where the terms do not nearly cancel —
# and the advisory that says so must fire exactly there.
#
# Background (measured 2026-08-18, `runs/yls_barnett_f6/`): on a free-space
# dipolar droplet the imaginary-time fixed point sat 26 % high in energy — above
# the energy of its own seed — and 44 % low in peak density, at dt = 2e-3, while
# reporting `dpsi = 3e-6`. It was grid-independent to 0.4 % and box-independent to
# 2 %, so the usual convergence scan certifies the wrong answer. L-BFGS on
# `energy_gradient!` reproduced the published peak density to 2.2 %.
#
# This file gates three separate claims, because they can fail independently:
#
#  1. The FIXED POINT moves with dt while `dpsi` reports convergence. On this
#     fixture: ITP lands +65 % above the L-BFGS energy at dt = 2e-3 and +26 % at
#     dt = 5e-4, while `dpsi` improves 426x (3.1e-3 -> 7.4e-6) across those two
#     runs. So `dpsi` measures how still the map has become, not how right it is.
#     That the error shrinks with dt is what makes it a splitting artifact rather
#     than a propagator/energy mismatch, which no dt could refine away.
#  2. The advisory FIRES in the stiff regime (positive control).
#  3. The advisory is SILENT in a trapped, non-cancelling regime, where ITP and
#     L-BFGS do agree — asserted here to 1e-4 (negative control). Without this a
#     warning that fired unconditionally would pass claim 2 forever.
#
# The threshold `ITP_CANCELLATION_WARN` is calibrated, not chosen: droplets sit at
# R = 0.0038…0.0118 and trapped gases at R = 0.678…1.000, a 57× gap
# (`runs/yls_barnett_f6/g_calibrate_stiffness_ratio.jl`). Claims 2 and 3 pin that
# the two populations stay on their own sides of it.

using SpinorBEC
using Logging
using Test

const _DT_ATOM = AtomSpecies("itp_probe", SpinorBEC.Units.AMU * 151, 1,
    100 * SpinorBEC.Units.BOHR_RADIUS, 0.0,
    4.5 * SpinorBEC.Units.BOHR_MAGNETON, 4.5)

"""
Stiff, free-space configuration: contact and DDI nearly cancel, LHY stabilises.
The couplings are scaled to a torus seed on a small grid so the cancellation
ratio lands in the droplet population without needing a physical droplet.
"""
function _stiff_case(; n=24, box=10.0)
    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    psi0 = _torus_seed(grid, 1)
    (; grid, atom=_DT_ATOM,
        interactions=InteractionParams(Dict(0 => 300.0); c_lhy=95.0),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        psi_init=psi0, enable_ddi=true, c_dd=1197.0, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0)
end

"Trapped, non-cancelling configuration with the same terms active."
function _soft_case(; n=24, box=12.0)
    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    psi0 = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 2,
        init_phi=π / 2, init_vortex_charge=1)
    (; grid, atom=_DT_ATOM,
        interactions=InteractionParams(Dict(0 => 500.0); c_lhy=500.0),
        zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
        psi_init=psi0, enable_ddi=true, c_dd=200.0, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0)
end

"Flux-closure torus: spins circulating azimuthally, ∇·M = 0, the droplet texture."
function _torus_seed(grid::Grid{3}, F::Int; lam=1.0, sr=1.4, sz=1.2)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    c_base = exp(-1im * (π / 2) * Matrix(spin_matrices(F).Fy))[:, 1]
    @inbounds for I in CartesianIndices(n_pts)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2
        amp = sqrt(r2^lam * exp(-r2 / sr^2 - z^2 / sz^2))
        phi = atan(y, x)
        for c in 1:D
            psi[I, c] = amp * c_base[c] * cis(-(F - (c - 1)) * (phi + π / 2))
        end
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

_ws_of(case; dt) = make_workspace(; case...,
    sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=true))

"Did `f()` emit a warning mentioning the advisory?"
function _warned(f)
    logger = Test.TestLogger(; min_level=Logging.Warn)
    Logging.with_logger(logger) do
        f()
    end
    any(r -> r.level >= Logging.Warn && occursin("displaced by dt", r.message),
        logger.logs)
end

@testset "ITP dt-limited advisory" begin
    stiff = _stiff_case()
    soft = _soft_case()

    @testset "the two regimes sit on opposite sides of the threshold" begin
        R_stiff = itp_cancellation_ratio(_ws_of(stiff; dt=1e-4))
        R_soft = itp_cancellation_ratio(_ws_of(soft; dt=1e-4))
        # calibrated populations: droplets 0.0038-0.0118, traps 0.678-1.000
        @test R_stiff < ITP_CANCELLATION_WARN
        @test R_soft > ITP_CANCELLATION_WARN
        @test R_soft / R_stiff > 10         # the separation is what licenses a threshold
        #                                     (measured 98x: 0.0087 vs 0.853)
    end

    @testset "1. the fixed point moves with dt, and `dpsi` does not notice" begin
        lb = find_ground_state(; stiff..., method=:lbfgs, n_steps=800, tol=1e-10,
            verbose=false)
        @test lb.grad_norm < 1e-4                      # measured 1.3e-5
        E_star = lb.energy

        # Same seed, same everything, only dt differs.
        res = map((2e-3, 5e-4)) do dt
            find_ground_state(; stiff..., dt=dt, n_steps=ceil(Int, 6.0 / dt),
                tol=1e-10, save_every=500, verbose=false)
        end
        err = [(r.energy - E_star) / abs(E_star) for r in res]
        # measured on this fixture: err = +0.672 (dt=2e-3), +0.263 (dt=5e-4);
        #                           dpsi = 3.1e-3, 7.4e-6

        # (a) neither ITP fixed point reaches the minimiser; both sit ABOVE it.
        @test all(>(0.05), err)
        # (b) the fixed point DEPENDS on dt. This is the hazard, and it is why a
        #     grid or box convergence scan cannot see the error — those axes are
        #     held fixed here.
        @test err[1] - err[2] > 0.1
        # (c) refining dt reduces it, so this is a splitting artifact and not a
        #     propagator/energy face mismatch, which no dt could refine away.
        @test err[2] < err[1] / 1.5
        # (d) THE POINT, as a relationship rather than a threshold: `dpsi` improves
        #     by more than two orders of magnitude between the two runs while the
        #     answer stays tens of percent wrong. So `dpsi` measures how still the
        #     map has become, not how right it is, and the advisory has to carry
        #     that warning itself. For scale, the production droplet run that
        #     started all this stopped at dpsi = 3e-6 and was 44 % wrong in peak
        #     density.
        @test res[2].dpsi < res[1].dpsi / 100
        @test res[2].dpsi < 1e-4
        @test err[2] > 0.1
    end

    @testset "2. the advisory fires in the stiff regime" begin
        @test _warned() do
            find_ground_state(; stiff..., dt=2e-3, n_steps=2, tol=1e-12,
                save_every=1, verbose=false)
        end
    end

    @testset "3. silent where ITP is trustworthy, and there ITP ≡ L-BFGS" begin
        @test !_warned() do
            find_ground_state(; soft..., dt=1e-3, n_steps=2, tol=1e-12,
                save_every=1, verbose=false)
        end
        itp = find_ground_state(; soft..., dt=1e-3, n_steps=4000, tol=1e-11,
            save_every=1000, verbose=false)
        lb = find_ground_state(; soft..., method=:lbfgs, n_steps=800, tol=1e-10,
            verbose=false)
        @test itp.energy ≈ lb.energy rtol = 1e-4      # measured 1.5e-5
    end
end
