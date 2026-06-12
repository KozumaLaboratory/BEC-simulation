using Test
using FFTW
using SpinorBEC
using SpinorBEC: frame_params, component_centroids, component_widths,
    _apply_boost!, boost_phase, TOFFrame, MultiFrameTOFState, find_t_sep,
    recombine_field, recombine_density, simulate_bragg_tof,
    simulate_tof_multiframe_interacting, make_fft_plans

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
        width_by_m = Dict(
            state.frames[i].m => component_widths(state)[i]
            for i in eachindex(state.frames)
        )
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
        width_by_m = Dict(
            state.frames[i].m => component_widths(state)[i]
            for i in eachindex(state.frames)
        )
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

    @testset "DDI in co-expanding frame (anisotropic Λ) vs fixed-grid" begin
        # Dipolar TOF (the Er/Eu signature) under an ANISOTROPIC trap release
        # (ω=(1,2) ⇒ Λ=(√(1+t²),√(1+4t²)) — strongly anisotropic). The DDI kernel
        # Q is re-evaluated at k_ξ/Λ each substep; this must reproduce a
        # fixed-grid evolution using the SAME audited apply_ddi_step! primitive,
        # validating the SCALING embedding + anisotropic-kernel re-eval (the new
        # part). 2D, x-polarized.
        ωx, ωy = 1.0, 2.0
        c0d = 1.5
        cdd = 3.0
        Td = 1.2
        coef = [0.5, 1 / sqrt(2), 0.5]   # F=1 transverse-x spin coherent (M ∥ x)
        function mkpsi2d(grd)
            xx = grd.x[1]
            yy = grd.x[2]
            p = zeros(ComplexF64, length(xx), length(yy), D)
            for c in 1:D, j in eachindex(yy), i in eachindex(xx)
                p[i, j, c] = coef[c] * exp(-(ωx * xx[i]^2 + ωy * yy[j]^2) / 2)
            end
            p ./= sqrt(sum(abs2, p) * cell_volume(grd))
            p
        end
        function widths2d(n, gx, gy, dV)
            m = sum(n) * dV
            xb = sum(I -> gx[I[1]] * n[I], CartesianIndices(n)) * dV / m
            yb = sum(I -> gy[I[2]] * n[I], CartesianIndices(n)) * dV / m
            wx = sqrt(sum(I -> (gx[I[1]] - xb)^2 * n[I], CartesianIndices(n)) * dV / m)
            wy = sqrt(sum(I -> (gy[I[2]] - yb)^2 * n[I], CartesianIndices(n)) * dV / m)
            (wx, wy)
        end

        sm = spin_matrices(F)
        g2 = make_grid(GridConfig{2}((72, 72), (14.0, 14.0)))
        st = simulate_tof_multiframe_interacting(mkpsi2d(g2), g2, sys;
            c0=c0d, gradient=0.0, gradient_axis=1, omega=(ωx, ωy),
            t_sep=Td, t_f=Td, n_steps_A=300, atom=Er168, c_dd=cdd)
        bx, by = sqrt(1 + ωx^2 * Td^2), sqrt(1 + ωy^2 * Td^2)
        totχ = zeros(Float64, size(st.chis[1]))
        for ch in st.chis
            totχ .+= abs2.(ch)
        end
        wxχ, wyχ = widths2d(totχ, g2.x[1], g2.x[2], cell_volume(g2))
        wx_coexp, wy_coexp = bx * wxχ, by * wyχ

        # fixed-grid brute-force: same DDI primitive, no scaling
        gB = make_grid(GridConfig{2}((96, 96), (22.0, 22.0)))
        nB = gB.config.n_points
        ddi = SpinorBEC.make_ddi_params(gB, Er168; c_dd=cdd)
        bufs = SpinorBEC.make_ddi_buffers(nB)
        plans = SpinorBEC.make_fft_plans(nB)
        fbuf = zeros(ComplexF64, nB...)
        kph = zeros(ComplexF64, nB...)
        psi = mkpsi2d(gB)
        dtb = Td / 350
        for _ in 1:350
            dens = total_density(psi, 2)
            for c in 1:D
                cv = view(psi, SpinorBEC._component_slice(2, nB, c)...)
                @. cv *= cis(-(dtb / 2) * c0d * dens)
            end
            SpinorBEC.apply_ddi_step!(psi, sm, ddi, bufs, dtb / 2, 2)
            SpinorBEC._scaling_kinetic_step!(psi, fbuf, kph, gB, (1.0, 1.0), plans, D, dtb)
            SpinorBEC.apply_ddi_step!(psi, sm, ddi, bufs, dtb / 2, 2)
            dens = total_density(psi, 2)
            for c in 1:D
                cv = view(psi, SpinorBEC._component_slice(2, nB, c)...)
                @. cv *= cis(-(dtb / 2) * c0d * dens)
            end
        end
        nb = zeros(Float64, nB...)
        for c in 1:D
            nb .+= abs2.(view(psi,:,:,c))
        end
        wx_brute, wy_brute = widths2d(nb, gB.x[1], gB.x[2], cell_volume(gB))

        @test by > 1.5 * bx                          # Λ genuinely anisotropic
        @test isapprox(wx_coexp, wx_brute; rtol=0.05)
        @test isapprox(wy_coexp, wy_brute; rtol=0.05)
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

@testset "Multi-frame TOF (Bragg interference)" begin
    ω = 1.0
    F = 1
    sys = SpinSystem(F)
    σ0 = 1 / sqrt(2ω)
    v = 4.0           # Bragg recoil velocity (relative momentum 2v)
    t = 0.1           # early enough that the ±v orders still overlap
    Λ = sqrt(1 + ω^2 * t^2)
    n = 512
    L = 24.0
    g1 = make_grid(GridConfig{1}((n,), (L,)))
    x = g1.x[1]
    dV = cell_volume(g1)
    env = ComplexF64.(exp.(-ω .* x .^ 2 ./ 2))
    env ./= sqrt(sum(abs2, env) * dV)
    orders = [(k=(v,), amp=1.0 + 0im), (k=(-v,), amp=1.0 + 0im)]

    state = simulate_bragg_tof(env, g1, sys; orders=orders, omega=(ω,), t=t)
    n_rec = recombine_density(state)

    @testset "vs brute-force free expansion" begin
        # The oracle: split-step free expansion of the SAME coherent initial
        # field (e^{ivx}+e^{-ivx})·g. Castin-Dum is exact for the free Gaussian,
        # so only the N-linear interpolation of the (smooth) envelope differs.
        psi0 = zeros(ComplexF64, n, sys.n_components)
        @. psi0[:, 1] = (cis(v * x) + cis(-v * x)) * env
        ws = make_workspace(; grid=g1, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            potential=NoPotential(), zeeman=ZeemanParams(),
            sim_params=SimParams(; dt=t / 400, n_steps=400,
                imaginary_time=false, normalize_every=0),
            psi_init=psi0)
        for _ in 1:400
            split_step!(ws)
        end
        n_bf = abs2.(Array(view(ws.state.psi, :, 1)))
        # global Gouy phase is common to both orders ⇒ cancels in the density
        @test sqrt(sum(abs2, n_rec .- n_bf)) / sqrt(sum(abs2, n_bf)) < 0.03
        @test sum(n_rec) * dV ≈ sum(n_bf) * dV rtol = 1e-2
    end

    @testset "fringe wavevector ≈ 2v" begin
        # density cross-term oscillates at k_fringe = 2v/Λ²; the envelope FT
        # decays by k~3 so the sideband peak is isolated.
        spec = abs.(rfft(n_rec))
        kbins = 2π .* (0:(length(spec) - 1)) ./ L
        mask = kbins .> 4.0
        kpeak = kbins[mask][argmax(spec[mask])]
        @test isapprox(kpeak, 2v / Λ^2; rtol=0.05)
        # interference is actually present: deep fringe nulls near the center
        mid = (n ÷ 2 - 40):(n ÷ 2 + 40)
        @test minimum(n_rec[mid]) < 0.1 * maximum(n_rec[mid])
    end

    @testset "single order → Castin-Dum Gaussian, no fringes" begin
        st1 = simulate_bragg_tof(env, g1, sys;
            orders=[(k=(v,), amp=1.0 + 0im)], omega=(ω,), t=t)
        d1 = recombine_density(st1)
        # centroid at v·t, width Λ·σ0, mass preserved
        mass = sum(d1) * dV
        xbar = sum(d1 .* x) * dV / mass
        wid = sqrt(sum(d1 .* (x .- xbar) .^ 2) * dV / mass)
        @test xbar ≈ v * t atol = 1e-2
        @test wid ≈ Λ * σ0 rtol = 1e-2
        @test mass ≈ 1.0 rtol = 1e-2
        # no sideband: the smooth Gaussian density has only its monotone tail at
        # the fringe band (k≈2v/Λ²), where the two-order case shows a clear peak.
        spec = abs.(rfft(d1))
        kbins = 2π .* (0:(length(spec) - 1)) ./ L
        band = (kbins .> 2v / Λ^2 - 1) .& (kbins .< 2v / Λ^2 + 1)
        @test maximum(spec[band]) < 1e-3 * maximum(spec)
    end

    @testset "boost single-source sets the fringe phase" begin
        # The −½Ṙ·R constant lives inside boost_phase; both orders see it through
        # the SAME function, so the ±v pair interferes CONSTRUCTIVELY at x=0 (the
        # phases coincide there) — a sign/constant drift would shift the fringes
        # off center. The cell-centered grid straddles x=0 at indices n/2, n/2+1.
        @test n_rec[n ÷ 2] > 0.95 * maximum(n_rec)        # central fringe is a peak
        @test n_rec[n ÷ 2] ≈ n_rec[n ÷ 2 + 1] rtol = 1e-6 # mirror about x=0
        @test n_rec[n ÷ 2 - 5] ≈ n_rec[n ÷ 2 + 6] rtol = 1e-6
    end

    @testset "distinct spin states add incoherently (no spurious fringes)" begin
        # Two frames, SAME envelope, opposite boosts ±v, but DISTINCT internal
        # states (m=+1, m=-1). Orthogonal ⇒ they must NOT interfere: the physical
        # density is |ψ_+|²+|ψ_-|² (smooth), not |ψ_++ψ_-|² (which WOULD fringe).
        # recombine_density groups by m; recombine_field (coherent over all) does
        # not — the contrast between them is exactly the orthogonality check.
        fp = frame_params(1.0, (ω,); t=t, gradient=0.0, gradient_axis=1, V0=(v,))
        fm = frame_params(-1.0, (ω,); t=t, gradient=0.0, gradient_axis=1, V0=(-v,))
        plans = make_fft_plans(g1.config.n_points)
        nrm = sum(abs2, env) * dV
        st = MultiFrameTOFState{1}(g1, sys, [fp, fm], [copy(env), copy(env)],
            t, plans, [nrm, nrm])

        n_inc = recombine_density(st)        # grouped: incoherent across m
        n_coh = abs2.(recombine_field(st))   # wrong-for-distinct-m: coherent

        fband(d) = begin
            s = abs.(rfft(d))
            kb = 2π .* (0:(length(s) - 1)) ./ L
            maximum(s[(kb .> 2v / Λ ^ 2 - 1) .& (kb .< 2v / Λ ^ 2 + 1)]) / maximum(s)
        end
        @test fband(n_inc) < 1e-3            # no sideband — smooth, incoherent
        @test fband(n_coh) > 0.05            # coherent sum WOULD fringe
        # incoherent density = sum of the two single-frame Castin-Dum Gaussians
        d_plus = recombine_density(
            simulate_bragg_tof(env, g1, sys;
                orders=[(k=(v,), amp=1.0 + 0im)], omega=(ω,), t=t, m=1.0),
        )
        d_minus = recombine_density(
            simulate_bragg_tof(env, g1, sys;
                orders=[(k=(-v,), amp=1.0 + 0im)], omega=(ω,), t=t, m=-1.0),
        )
        @test sqrt(sum(abs2, n_inc .- (d_plus .+ d_minus))) /
              sqrt(sum(abs2, n_inc)) < 1e-12
    end
end

@testset "Multi-frame TOF (interacting recombination)" begin
    # End-to-end: the interacting SG path hands off DE-BOOSTED residuals; the
    # density read-out reconstructs them faithfully (magnitude drops the boost
    # phase, R_m/Λ_m carry position/width) and adds the orthogonal spin
    # components incoherently. Validate against a full brute-force split-step
    # lab density.
    ω = 1.0
    F = 1
    sys = SpinSystem(F)
    D = 2F + 1
    c0 = 4.0
    Gi = 2.5
    tsep = 1.4
    tff = 2.5
    axis = 1

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
    xb = gB.x[1]
    dVb = cell_volume(gB)
    psiB = zeros(ComplexF64, 512, D)
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
    n_bf = zeros(Float64, 512)
    for c in 1:D
        n_bf .+= abs2.(Array(view(wsB.state.psi, :, c)))
    end

    n_rec = recombine_density(state; lab_grid=gB)
    # mass conserved through the reconstruction
    @test sum(n_rec) * dVb ≈ 1.0 rtol = 1e-2
    @test sum(n_rec) * dVb ≈ sum(n_bf) * dVb rtol = 1e-2
    # lab density within the documented post-t_sep-interaction approximation
    @test sqrt(sum(abs2, n_rec .- n_bf)) / sqrt(sum(abs2, n_bf)) < 0.2
end
