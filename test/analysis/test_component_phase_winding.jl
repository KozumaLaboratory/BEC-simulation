using Test
using SpinorBEC

# `component_phase_winding` exists because the two detectors that were already
# here cannot read the winding of a spin-F magnetic vortex:
#
#   * `winding_number_field` resolves at most ±1 per plaquette, so a charge-ℓ
#     core on one plaquette is invisible for |ℓ| ≥ 2;
#   * `non_abelian_holonomy` returns `cis(phase_acc)`, which is ≈ 1 for EVERY
#     integer winding.
#
# A Saito-Li magnetic vortex has component windings v_m = -m, i.e. up to ∓F.
# For ¹⁵¹Eu that is ±6. This file pins that the new detector reads every one of
# them, and — the part that matters — that it REFUSES rather than returning a
# clean wrong integer when the loop is under-sampled.

@testset "component_phase_winding" begin
    F = 6
    D = 2F + 1
    n = 64
    L = 6.0
    grid = SpinorBEC.make_grid(
        SpinorBEC.GridConfig((n, n, n), (L, L, L)))
    x, y = grid.x[1], grid.x[2]

    # Synthetic magnetic vortex: component m carries phase exp(-i m φ), with a
    # radial envelope that vanishes on the axis exactly as the real state does.
    psi = zeros(ComplexF64, n, n, n, D)
    for k in 1:n, j in 1:n, i in 1:n
        r = hypot(x[i], y[j])
        φ = atan(y[j], x[i])
        env = r * exp(-r^2 / 2)
        for c in 1:D
            m = F - (c - 1)
            psi[i, j, k, c] = env * cis(-m * φ)
        end
    end

    @testset "reads v_m = -m for every component, m = +6 … -6" begin
        for c in 1:D
            m = F - (c - 1)
            w = SpinorBEC.component_phase_winding(psi, grid, c; radius=1.0)
            @test w.converged
            @test w.winding == -m
        end
    end

    @testset "the plaquette detector CANNOT do this (why the function exists)" begin
        # m = +6 → winding -6. Summing plaquettes over the mid z-slice must
        # NOT recover it; if this ever starts passing, the new detector is
        # redundant and should be deleted rather than kept.
        wf = SpinorBEC.winding_number_field(psi, grid; component=1)
        plaquette_total = sum(view(wf,:,:,(n ÷ 2)))
        @test plaquette_total != -6
    end

    @testset "refuses when under-sampled instead of guessing" begin
        # A 4-point loop cannot resolve |ℓ| = 6 (needs > 2|ℓ| = 12 points).
        # The contract is `converged == false`, not a wrong integer.
        w = SpinorBEC.component_phase_winding(
            psi, grid, 1; radius=1.0, n_start=2, n_max=8)
        @test !w.converged

        # Positive control on the same guard: with enough points it converges.
        w_ok = SpinorBEC.component_phase_winding(
            psi, grid, 1; radius=1.0, n_start=64, n_max=512)
        @test w_ok.converged
        @test w_ok.winding == -6
    end

    @testset "radius-independent inside the cloud" begin
        for radius in (0.6, 1.0, 1.6, 2.2)
            w = SpinorBEC.component_phase_winding(psi, grid, 1; radius=radius)
            @test w.converged
            @test w.winding == -6
        end
    end

    @testset "a minority component is not masked away" begin
        # Component m = -6 scaled to 0.3 % of the norm — far below the global
        # density peak. Its winding (+6) must still read, and min_amp_ratio is
        # normalised to the component's OWN maximum, so it stays O(1).
        psi_min = copy(psi)
        psi_min[:, :, :, D] .*= 0.003
        w = SpinorBEC.component_phase_winding(psi_min, grid, D; radius=1.0)
        @test w.converged
        @test w.winding == +6
        @test w.min_amp_ratio > 0.1
    end

    @testset "zero winding on a component with no vortex" begin
        psi_flat = zeros(ComplexF64, n, n, n, D)
        for k in 1:n, j in 1:n, i in 1:n
            r = hypot(x[i], y[j])
            psi_flat[i, j, k, (D + 1) ÷ 2] = exp(-r^2 / 2)
        end
        w = SpinorBEC.component_phase_winding(
            psi_flat, grid, (D + 1) ÷ 2; radius=1.0)
        @test w.converged
        @test w.winding == 0
    end
end
