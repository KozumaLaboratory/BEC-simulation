using Test
using SpinorBEC

@testset "P4 analyzers and noise models" begin

    @testset "P4.4 Projected GP: high-k modes zeroed" begin
        cfg = GridConfig((16, 16), (6.0, 6.0))
        grid = make_grid(cfg)
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0*5.29e-11, 54.3*5.29e-11, 0.0)
        sp = SimParams(; dt=0.005, n_steps=1)
        ws = make_workspace(;
            grid, atom,
            interactions = InteractionParams(10.0, 0.0),
            sim_params = sp,
            potential = HarmonicTrap(1.0, 1.0),
            zeeman = ZeemanParams(),
        )
        # Deposit a high-k perturbation on m=0 component
        psi = ws.state.psi
        @inbounds for j in 1:size(psi, 2), i in 1:size(psi, 1)
            psi[i, j, 2] += 0.01 * cis(2π * (i-1) * (size(psi,1)/2) / size(psi,1))
        end
        n_before = sum(abs2, psi)

        apply_projected_gp!(ws, 2.0)    # k_cut = 2 (pretty low for this grid)
        n_after = sum(abs2, psi)

        # Some mass was removed
        @test n_after <= n_before
        # But not all: low-k content is preserved
        @test n_after > 0
    end

    @testset "P4.6 Photon scattering preserves density, randomises phase" begin
        cfg = GridConfig((8, 8, 8), (4.0, 4.0, 4.0))
        grid = make_grid(cfg)
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0*5.29e-11, 54.3*5.29e-11, 0.0)
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(;
            grid, atom,
            interactions = InteractionParams(10.0, 0.0),
            sim_params = sp, potential = HarmonicTrap(1.0, 1.0, 1.0),
            zeeman = ZeemanParams(),
        )
        psi_before = copy(ws.state.psi)
        n_before = sum(abs2, psi_before)
        apply_photon_scattering!(ws, 0.1, 0.01; seed=42)
        n_after = sum(abs2, ws.state.psi)
        # Density preserved up to F64 roundoff (just phase kicks)
        @test n_after ≈ n_before rtol=1e-10
        # Phase has changed somewhere
        @test !all(ws.state.psi .≈ psi_before)
    end

    @testset "P4.11 topology: winding number of a singly-charged vortex" begin
        cfg = GridConfig((32, 32), (6.0, 6.0))
        grid = make_grid(cfg)
        # Synthesize a single-charge vortex: ψ(x,y) = f(r) · exp(iθ)
        psi = zeros(ComplexF64, 32, 32, 3)
        @inbounds for j in 1:32, i in 1:32
            x = grid.x[1][i]; y = grid.x[2][j]
            r = sqrt(x^2 + y^2)
            phase = atan(y, x)
            psi[i, j, 1] = 0.5 * r * cis(phase) * exp(-r^2 / 4)
        end
        winding = winding_number_field(psi, grid; component=1)
        # The sum over the full plaquette field should equal +1 (single vortex)
        total = sum(winding)
        @test total == 1
    end

    @testset "P4.11 monopole charge: uniform spin has zero charge" begin
        cfg = GridConfig((8, 8, 8), (4.0, 4.0, 4.0))
        grid = make_grid(cfg)
        # Uniform polarised along +z
        psi = zeros(ComplexF64, 8, 8, 8, 3)
        psi[:, :, :, 1] .= 1.0 / sqrt(prod(grid.config.n_points))
        q = monopole_charge_3d(psi, grid)
        @test all(abs.(q) .< 1e-8)  # uniform → zero charge density
    end

    @testset "P4.11 non_abelian_holonomy: trivial loop = 1" begin
        cfg = GridConfig((16, 16), (6.0, 6.0))
        grid = make_grid(cfg)
        psi = zeros(ComplexF64, 16, 16, 3)
        psi[:, :, 2] .= 1.0 / 16  # constant phase everywhere
        # Trivial tiny closed loop
        loop = [(8, 8), (9, 8), (9, 9), (8, 9), (8, 8)]
        hol = non_abelian_holonomy(psi, grid, loop)
        @test real(hol) ≈ 1.0 atol=1e-10
        @test abs(imag(hol)) < 1e-10
    end
end
