using Test
using SpinorBEC
using SpinorBEC: frame_params, component_centroids, component_widths,
    _apply_boost!, boost_phase, TOFFrame, find_t_sep

# Weighted centroid + RMS width of a 1D component density.
function _centroid_width(nc, x, dV)
    mass = sum(nc) * dV
    xbar = sum(nc .* x) * dV / mass
    w = sqrt(sum(nc .* (x .- xbar) .^ 2) * dV / mass)
    (mass=mass, centroid=xbar, width=w)
end

@testset "Multi-frame TOF (skeleton)" begin
    ω = 1.0
    F = 1
    sys = SpinSystem(F)
    D = 2F + 1
    σ0 = 1 / sqrt(2ω)
    G = 2.0
    t_f = 2.0
    axis = 1
    grid = make_grid(GridConfig{1}((256,), (24.0,)))
    x = grid.x[1]
    dV = cell_volume(grid)

    # Trapped ground-state Gaussian, all m equally populated.
    psi0 = zeros(ComplexF64, 256, D)
    for c in 1:D
        @. psi0[:, c] = exp(-ω * x^2 / 2)
    end
    psi0 ./= sqrt(sum(abs2, psi0) * dV)

    @testset "frame_params analytic" begin
        f = frame_params(1.0, (ω,); t=t_f, gradient=G, gradient_axis=axis)
        @test f.R[1] ≈ 0.5 * 1.0 * G * t_f^2
        @test f.Rdot[1] ≈ 1.0 * G * t_f
        @test f.Λ[1] ≈ sqrt(1 + ω^2 * t_f^2)
        # gradient = 0 ⇒ no COM motion
        f0 = frame_params(1.0, (ω,); t=t_f, gradient=0.0, gradient_axis=axis)
        @test f0.R[1] == 0.0 && f0.Rdot[1] == 0.0
    end

    @testset "boost phase contract round-trip" begin
        f = TOFFrame{1}(1.0, (3.0,), (2.5,), (1.3,), (0.4,), 1.0)
        chi = ComplexF64.(exp.(-(x .- 1) .^ 2)) .+ 0im
        chi0 = copy(chi)
        _apply_boost!(chi, f, grid, -1.0)   # de-boost
        @test !(chi ≈ chi0)                 # actually changed phase
        _apply_boost!(chi, f, grid, +1.0)   # re-boost
        @test maximum(abs.(chi .- chi0)) < 1e-13
        # constant -½Ṙ·R is carried in the same function (single source)
        @test boost_phase(f, (0.0,)) ≈ -0.5 * f.Rdot[1] * f.R[1]
    end

    @testset "frames match analytic at t_f" begin
        state = simulate_tof_multiframe(psi0, grid, sys;
            gradient=G, gradient_axis=axis, t=t_f, omega=(ω,))
        @test length(state.frames) == D
        cen = component_centroids(state)
        wid = component_widths(state)
        for (f, c, w) in zip(state.frames, cen, wid)
            @test c[1] ≈ 0.5 * f.m * G * t_f^2 atol = 1e-10
            @test w[1] ≈ σ0 * sqrt(1 + ω^2 * t_f^2) rtol = 1e-3
        end
    end

    @testset "brute-force (SpatialZeeman full grid) matches frames" begin
        # The validating oracle: a full-grid free expansion under the real
        # m-DEPENDENT field bz(x)=G·x (NOT the spin-independent MagneticGradient,
        # which would not separate components). a_m = +m·G.
        field = spatial_zeeman_field(grid; bz=(xx,) -> G * xx)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            potential=NoPotential(), zeeman=ZeemanParams(),
            sim_params=SimParams(; dt=t_f / 800, n_steps=800,
                imaginary_time=false, normalize_every=0),
            psi_init=copy(psi0), spatial_zeeman=field)
        for _ in 1:800
            split_step!(ws)
        end
        state = simulate_tof_multiframe(psi0, grid, sys;
            gradient=G, gradient_axis=axis, t=t_f, omega=(ω,))
        frame_by_m = Dict(f.m => f for f in state.frames)
        width_by_m = Dict(state.frames[i].m => component_widths(state)[i]
                          for i in eachindex(state.frames))
        for c in 1:D
            m = Float64(sys.m_values[c])
            nc = abs2.(Array(view(ws.state.psi, :, c)))
            bf = _centroid_width(nc, x, dV)
            @test bf.centroid ≈ frame_by_m[m].R[1] atol = 0.02
            @test bf.width ≈ width_by_m[m][1] rtol = 2e-2
            @test bf.mass ≈ 1 / D rtol = 1e-3          # per-component norm conserved
        end
    end

    @testset "far_field read-out sanity" begin
        state = simulate_tof_multiframe(psi0, grid, sys;
            gradient=G, gradient_axis=axis, t=t_f, omega=(ω,))
        img = far_field_density(state)
        @test Set(keys(img)) == Set(Float64.(sys.m_values))
        # mass conserved through the FFT (Parseval) read-out
        for (m, d) in img
            @test sum(d) * grid.dk[1] * t_f ≈ 1 / D rtol = 1e-6
        end
    end

    @testset "interacting (co-expanding Phase A) vs brute-force" begin
        # Contact c0: Phase A in the co-expanding frame keeps χ frozen-width
        # (no chirp); handoff measures the physical COM + velocity (capturing
        # the inter-component mean-field repulsion). COM is near-exact; the
        # width carries the controlled "interactions negligible post-t_sep"
        # approximation — ~8% in 1D (worst case; the density drops as 1/∏b, so
        # it is far tighter in 2D/3D).
        c0 = 4.0
        Gi = 2.5
        tsep = 1.4
        tff = 2.5
        gA = make_grid(GridConfig{1}((256,), (16.0,)))
        psiA = zeros(ComplexF64, 256, D)
        xa = gA.x[1]
        for c in 1:D
            @. psiA[:, c] = exp(-ω * xa^2 / 2)
        end
        psiA ./= sqrt(sum(abs2, psiA) * cell_volume(gA))
        state = simulate_tof_multiframe_interacting(psiA, gA, sys;
            c0=c0, gradient=Gi, gradient_axis=axis, omega=(ω,),
            t_sep=tsep, t_f=tff, n_steps_A=500)

        gB = make_grid(GridConfig{1}((512,), (44.0,)))
        psiB = zeros(ComplexF64, 512, D)
        xb = gB.x[1]
        for c in 1:D
            @. psiB[:, c] = exp(-ω * xb^2 / 2)
        end
        psiB ./= sqrt(sum(abs2, psiB) * cell_volume(gB))
        wsB = make_workspace(; grid=gB, atom=Rb87,
            interactions=InteractionParams(Dict(0 => c0)),
            potential=NoPotential(), zeeman=ZeemanParams(),
            sim_params=SimParams(; dt=tff / 1000, n_steps=1000,
                imaginary_time=false, normalize_every=0),
            psi_init=psiB, spatial_zeeman=spatial_zeeman_field(gB; bz=(xx,) -> Gi * xx))
        for _ in 1:1000
            split_step!(wsB)
        end

        frame_by_m = Dict(state.frames[i].m => state.frames[i]
                          for i in eachindex(state.frames))
        width_by_m = Dict(state.frames[i].m => component_widths(state)[i]
                          for i in eachindex(state.frames))
        dVb = cell_volume(gB)
        for c in 1:D
            m = Float64(sys.m_values[c])
            bf = _centroid_width(abs2.(Array(view(wsB.state.psi, :, c))), xb, dVb)
            # COM captured to ~1% (Ehrenfest + measured repulsion kick)
            @test isapprox(bf.centroid, frame_by_m[m].R[1]; atol=0.05,
                rtol=0.02)
            # width within the post-t_sep-interaction approximation (1D worst case)
            @test isapprox(bf.width, width_by_m[m][1]; rtol=0.12)
        end
    end

    @testset "find_t_sep" begin
        t_sep = find_t_sep(grid, sys; gradient=G, gradient_axis=axis,
            omega=(ω,), sigma0=σ0, kappa=3.0)
        @test isfinite(t_sep) && t_sep > 0
        # at t_sep the slowest adjacent pair is exactly 3σ separated
        Δa = G * 1.0   # |m=1 − m=0|·G
        sep = 0.5 * Δa * t_sep^2
        @test sep ≈ 3.0 * σ0 * sqrt(1 + ω^2 * t_sep^2) rtol = 1e-3
        # gradient = 0 ⇒ Inf
        @test find_t_sep(grid, sys; gradient=0.0, gradient_axis=axis,
            omega=(ω,), sigma0=σ0) == Inf
    end
end
