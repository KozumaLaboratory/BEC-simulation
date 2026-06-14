using Test
using SpinorBEC
using SpinorBEC: ZeemanTerm, apply_step!, _materialize_field
using Random

_std(v) = (m=sum(v) / length(v); sqrt(sum(abs2, v .- m) / length(v)))

@testset "Spatial Zeeman B(r)" begin
    @testset "Uniform limit ≡ ZeemanTerm (bit-identical, q=0)" begin
        # A constant field must reproduce the uniform ZeemanTerm exactly —
        # the load-bearing sign/convention coherence check. q=0 so the per-voxel
        # Euler rotation is exact (no Strang split against q·F_z²).
        grid = make_grid(GridConfig{2}((16, 16), (8.0, 8.0)))
        F = 1
        sm = spin_matrices(F)
        D = 2F + 1
        Random.seed!(7)
        psi0 = randn(ComplexF64, 16, 16, D)
        bx, by, bz = 0.3, -0.2, 0.5
        field = spatial_zeeman_field(grid; bx=bx, by=by, bz=bz, q=0.0)

        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            zeeman=ZeemanParams(), potential=NoPotential(),
            sim_params=SimParams(; dt=0.01, n_steps=1), psi_init=copy(psi0))

        dt = 0.05
        for it in (false, true)
            a = copy(psi0)
            apply_spatial_zeeman_step!(a, field, sm, dt, it)
            copyto!(ws.state.psi, psi0)
            apply_step!(ZeemanTerm(bx, by, bz, 0.0), ws.state.psi, dt, it, ws)
            @test maximum(abs.(a .- Array(ws.state.psi))) < 1e-12
        end
    end

    @testset "RT preserves norm (varying field, with q)" begin
        grid = make_grid(GridConfig{2}((24, 24), (10.0, 10.0)))
        F = 2
        sm = spin_matrices(F)
        D = 2F + 1
        Random.seed!(11)
        psi = randn(ComplexF64, 24, 24, D)
        n0 = sum(abs2, psi)
        field = quadrupole_field(grid; gradient=0.4, bias=0.3)
        # inject a spatially-varying q to exercise the qphase split
        field_q = SpatialZeemanField(field.bx, field.by, field.bz,
            _materialize_field((x, y) -> 0.05 * (x^2 + y^2), grid))
        apply_spatial_zeeman_step!(psi, field_q, sm, 0.03, false)
        @test sum(abs2, psi) ≈ n0 rtol = 1e-12   # rotation is unitary per voxel
    end

    @testset "Curvature oracle: B(r) makes the spin texture position-dependent" begin
        # One step on a uniform-spin cloud: a spatially-varying field rotates
        # each voxel differently, so the local ⟨F_z⟩(r) acquires spatial
        # structure. A uniform field rotates every voxel identically → no
        # spatial structure. This is the direct signature of arbitrary B(r).
        grid = make_grid(GridConfig{2}((32, 32), (10.0, 10.0)))
        F = 1
        sm = spin_matrices(F)
        sys = SpinSystem(F)
        # transverse-x spin-coherent, uniform density envelope
        psi_base = init_psi_spin_coherent(grid, sys; theta=π / 2, phi=0.0)

        quad = quadrupole_field(grid; gradient=0.5, bias=1.0)
        unif = spatial_zeeman_field(grid; bx=0.0, by=0.0, bz=1.0)

        function fz_spatial_std(field)
            psi = copy(psi_base)
            apply_spatial_zeeman_step!(psi, field, sm, 0.4, false)
            _, _, fz = spin_density_vector(psi, sm, 2)
            n = total_density(psi, 2)
            mask = n .> 1e-6 * maximum(n)
            _std(fz[mask] ./ n[mask])    # spatial spread of local ⟨F_z⟩/n
        end

        @test fz_spatial_std(quad) > 1e-3        # curved field ⇒ structured texture
        @test fz_spatial_std(unif) < 1e-9        # uniform field ⇒ flat texture
    end

    @testset "simulate_field_dynamics: end-to-end + deformation vs control" begin
        grid = make_grid(GridConfig{2}((32, 32), (12.0, 12.0)))
        F = 1
        sys = SpinSystem(F)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            zeeman=ZeemanParams(),
            potential=HarmonicTrap((1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
            psi_init=init_psi_spin_coherent(grid, sys; theta=π / 2, phi=0.0))

        quad = quadrupole_field(grid; gradient=0.6, bias=1.5)
        unif = spatial_zeeman_field(grid; bx=0.0, by=0.0, bz=1.5)

        r_quad = simulate_field_dynamics(ws; field=quad, t_total=1.0, n_steps=60,
            save_every=20, drop_trap=true)
        r_unif = simulate_field_dynamics(ws; field=unif, t_total=1.0, n_steps=60,
            save_every=20, drop_trap=true)

        # snapshots recorded, RT norm conserved on both paths
        @test length(r_quad.psi_snapshots) >= 2
        @test all(n -> isapprox(n, r_quad.norms[1]; rtol=1e-8), r_quad.norms)
        @test all(n -> isapprox(n, r_unif.norms[1]; rtol=1e-8), r_unif.norms)

        # The curved field deforms the cloud more than the uniform control:
        # compare aspect-ratio departure from 1 of the final density.
        m_quad = density_moments(r_quad.psi_snapshots[end], grid)
        m_unif = density_moments(r_unif.psi_snapshots[end], grid)
        @test abs(m_quad.aspect_ratio - 1) > abs(m_unif.aspect_ratio - 1)
    end
end
