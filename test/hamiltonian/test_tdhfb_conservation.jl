# TDHFB coupled (φ, ρ, κ) conservation tests — the load-bearing safety net.
#
# C1: ρ Hermiticity preserved across N=200 coupled Strang steps
# C2: κ symmetry preserved across N=200 coupled Strang steps
# C3: Particle number N = ∫(|φ|² + tr ρ) conserved, finite g_S, finite κ
# C4: Total energy E[φ, ρ, κ] does NOT drift by more or less than it does
#     today — the engine has an open EOM/E inconsistency and the measured
#     1.52e-2 is pinned as a band, not passed as a tolerance. See the testset.
# C5: ρ=κ=0 limit ⇒ pure F=1 GP equivalence (catches BdG-vs-GP factor errors)
# C6: κ kinematic motion — starting from κ=0 with finite g_S and nonzero φ,
#     after one BdG step κ ≠ 0 AND κ symmetric (proves κ evolution is wired,
#     not stubbed)
#
# Reference: src/hamiltonian/tdhfb/strang_step.jl + energy.jl

using Test
using LinearAlgebra
using FFTW
using Random
using SpinorBEC

@testset "TDHFB coupled-evolution conservation" begin

    # Common helper: build a Hermitian random rho with given amplitude
    function random_hermitian_rho(nx::Int, D::Int, amp::Float64; seed=1)
        rng = MersenneTwister(seed)
        rho = zeros(ComplexF64, nx, D, D)
        for i in 1:nx
            A = randn(rng, ComplexF64, D, D) .* amp
            rho[i, :, :] = (A + A') / 2
        end
        return rho
    end

    # Common helper: build a symmetric random kappa with given amplitude
    function random_symmetric_kappa(nx::Int, D::Int, amp::Float64; seed=2)
        rng = MersenneTwister(seed)
        kappa = zeros(ComplexF64, nx, D, D)
        for i in 1:nx
            A = randn(rng, ComplexF64, D, D) .* amp
            kappa[i, :, :] = (A + transpose(A)) / 2
        end
        return kappa
    end

    @testset "C1: ρ Hermiticity drift over 200 coupled steps" begin
        nx = 8
        F = 1
        D = 3
        Random.seed!(101)

        phi = randn(ComplexF64, nx, D) .* 0.3
        rho = random_hermitian_rho(nx, D, 0.1; seed=101)
        kappa = random_symmetric_kappa(nx, D, 0.1; seed=102)

        state = init_tdhfb_vacuum(phi)
        state.rho .= rho
        state.kappa .= kappa

        # Harmonic trap
        V_ext = zeros(Float64, nx, D)
        x = collect(0:(nx - 1)) .- nx/2 .+ 0.5
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * 0.5^2 * x[i]^2
        end
        gS = Dict(0 => 0.5, 2 => 0.1)
        dt = 0.01

        for _ in 1:200
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
        end

        rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
        @test rho_dev < 1e-10
        @test kappa_dev < 1e-10
    end

    @testset "C2: κ symmetry preserved (already covered by C1's kappa_dev)" begin
        # C1's `kappa_dev < 1e-10` is exactly the κ-symmetry assertion. Replicated
        # here as a separate testset for readability + explicit κ-only check.
        nx = 8
        F = 1
        D = 3
        Random.seed!(201)

        phi = randn(ComplexF64, nx, D) .* 0.3
        rho = random_hermitian_rho(nx, D, 0.1; seed=201)
        kappa = random_symmetric_kappa(nx, D, 0.1; seed=202)

        state = init_tdhfb_vacuum(phi)
        state.rho .= rho
        state.kappa .= kappa

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.5, 2 => 0.1)
        dt = 0.01

        for _ in 1:100
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
        end

        # κ symmetric: κ[c,c'] == κ[c',c]
        max_asym = 0.0
        for i in 1:nx, c in 1:D, c_p in 1:D
            d = abs(state.kappa[i, c, c_p] - state.kappa[i, c_p, c])
            max_asym = max(max_asym, d)
        end
        @test max_asym < 1e-10
    end

    @testset "C3: Particle number conservation (finite g_S, finite κ)" begin
        nx = 8
        F = 1
        D = 3
        Random.seed!(301)

        phi = randn(ComplexF64, nx, D) .* 0.3
        rho = random_hermitian_rho(nx, D, 0.05; seed=301)
        kappa = random_symmetric_kappa(nx, D, 0.05; seed=302)

        state = init_tdhfb_vacuum(phi)
        state.rho .= rho
        state.kappa .= kappa

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.5, 2 => 0.1)
        dt = 0.01
        nsteps = 200

        N0 = tdhfb_total_particle_number(state)
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
        end
        N1 = tdhfb_total_particle_number(state)

        # Particle number is conserved by the FULL coupled TDHFB dynamics
        # (Δ^φ φ* condensate loss balanced by Δ^R κ̄ - κ Δ̄^R quasi-particle
        # gain).
        # The `< 1e-1` bound and its "observed ~4.7e-2" justification were
        # written on 2026-05-12 and never revisited. Re-measured 2026-07-31,
        # bit-identical over three runs: |ΔN| = 1.2951e-4 at N₀ = 2.6317, i.e.
        # 4.9e-5 relative — 360x better than the comment claimed and 772x
        # inside the bound, so a 700x regression in N conservation would have
        # passed. Pinned at the measured value with ~8x headroom for
        # FFTW-plan variation across machines.
        @test abs(N1 - N0) < 1e-3
    end

    @testset "C4: Energy is NOT conserved — the drift is pinned, not passed" begin
        nx = 16
        F = 1
        D = 3
        Random.seed!(401)

        # Gaussian-ish initial φ in m=0
        phi = zeros(ComplexF64, nx, D)
        x = collect(0:(nx - 1)) .- nx/2 .+ 0.5
        for i in 1:nx
            phi[i, 2] = exp(-x[i]^2 / 6) * 0.5
        end
        rho = random_hermitian_rho(nx, D, 0.02; seed=401)
        kappa = random_symmetric_kappa(nx, D, 0.02; seed=402)

        state = init_tdhfb_vacuum(phi)
        state.rho .= rho
        state.kappa .= kappa

        # Harmonic trap
        V_ext = zeros(Float64, nx, D)
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * 0.3^2 * x[i]^2
        end
        gS = Dict(0 => 0.3, 2 => 0.05)
        dt = 0.005
        nsteps = 400  # T = 2

        E0 = tdhfb_energy(state, F, gS, V_ext)
        @test isfinite(E0) && E0 != 0
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
        end
        E1 = tdhfb_energy(state, F, gS, V_ext)

        rel_drift = abs(E1 - E0) / max(abs(E0), 1e-12)
        # The engine does not conserve E. The drift is dt-INDEPENDENT and
        # linear in g_S — a per-step EOM/E-functional inconsistency open since
        # 2026-05-12. Measured 2026-07-31, bit-identical over three runs:
        # 1.5215e-2 at g_S = (0.3, 0.05), T = 2.
        #
        # The old one-sided `< 2e-2` sat 1.31x from red, so it was both close
        # to flaking and unable to notice a fix. A BAND is the honest
        # instrument for a known-broken quantity: it fails on a regression AND
        # on an improvement, so the number cannot drift in either direction
        # without someone coming back to this comment. Tighten the band —
        # do not widen it — when the EOM/E factor is corrected.
        @test 1.0e-2 < rel_drift < 2.0e-2
    end

    @testset "C5: ρ=κ=0 ⇒ pure GP equivalence (F=1 c0/c1, perturbative)" begin
        # When ρ=κ=0 initially, the TDHFB φ EOM (Stoof / particle-conserving
        # form) reduces to GP for the FIRST HF half-step. After one full
        # Strang step, ρ and κ are O(dt) from the V·φφ source in Δ^R, so
        # subsequent HF substeps introduce O(g·dt)² deviation from pure GP.
        # We use small dt and few steps so the cumulative deviation stays
        # well below the threshold that would catch a factor-2 BdG-vs-GP
        # bug (~O(g·dt) per step ⇒ ~O(g·T) cumulative).
        nx = 16
        F = 1
        D = 3
        Random.seed!(501)

        phi0 = zeros(ComplexF64, nx, D)
        x = collect(0:(nx - 1)) .- nx/2 .+ 0.5
        for i in 1:nx
            phi0[i, 2] = exp(-x[i]^2 / 6) * 0.4
        end

        V_ext = zeros(Float64, nx, D)
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * 0.3^2 * x[i]^2
        end

        # GP couplings: c_0, c_1
        c0 = 1.0
        c1 = 0.1
        # KU map: g_0 = c_0 - 2 c_1, g_2 = c_0 + c_1
        gS = Dict(0 => c0 - 2 * c1, 2 => c0 + c1)

        dt = 0.001
        nsteps = 10
        # Expected scale of correct TDHFB deviation from GP: O((g·T)²) ~ 1e-4.
        # Factor-2 error (wrong condensate self-interaction) would give
        # O(g·T) ~ 1e-2. Tolerance 1e-3 sits cleanly between.
        tolerance = 1.0e-3

        # TDHFB run
        phi_tdhfb = copy(phi0)
        state = init_tdhfb_vacuum(phi_tdhfb)
        # rho, kappa stay zero throughout this test
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
        end

        # Hand-rolled GP run with the same V(dt/2) U_GP(dt/2) K(dt) U_GP(dt/2) V(dt/2) order.
        # Uses hf_matrix_F1! (GP form) for the HF substep, exp(-i h_GP dt) applied to φ.
        phi_gp = copy(phi0)
        # Build a default k_squared with the same dx=1 box used by _tdhfb_kinetic_step!
        function _default_k2(spatial::Tuple)
            ks2 = zeros(Float64, spatial)
            nd = length(spatial)
            for idx in CartesianIndices(spatial)
                s = 0.0
                for d in 1:nd
                    nd_d = spatial[d]
                    ki = idx[d] - 1 < nd_d / 2 ? (idx[d] - 1) : (idx[d] - 1 - nd_d)
                    s += (2π * ki / nd_d)^2
                end
                ks2[idx] = s
            end
            return ks2
        end
        k_squared = _default_k2((nx,))

        function v_half!(phi, V_ext, dt)
            for i in 1:nx, m in 1:D
                phi[i, m] *= cis(-V_ext[i, m] * dt / 2)
            end
        end
        function k_full!(phi, k_squared, dt)
            kp = cis.(-0.5 .* k_squared .* dt)
            for m in 1:D
                phi_m = view(phi, :, m)
                phi_k = fft(collect(phi_m))
                phi_k .*= kp
                phi_back = ifft(phi_k)
                for i in 1:nx
                    phi_m[i] = phi_back[i]
                end
            end
        end
        function gp_hf_half!(phi, c0, c1, dt)
            # F=1 GP form: h_GP from hf_matrix_F1! ; apply exp(-i h_GP dt/2) at each site
            rho = zeros(ComplexF64, nx, 3, 3)
            kappa = zeros(ComplexF64, nx, 3, 3)
            h_hf = hf_matrix_F1(phi, rho, kappa, c0, c1)
            for i in 1:nx
                h_mat = h_hf[i, :, :]
                ev = eigen(Hermitian(h_mat))
                U = ev.vectors
                lam = ev.values
                exp_h = U * Diagonal(cis.(-lam .* dt / 2)) * U'
                v_in = phi[i, :]
                phi[i, :] = exp_h * v_in
            end
        end

        for _ in 1:nsteps
            v_half!(phi_gp, V_ext, dt)
            gp_hf_half!(phi_gp, c0, c1, dt)
            k_full!(phi_gp, k_squared, dt)
            gp_hf_half!(phi_gp, c0, c1, dt)
            v_half!(phi_gp, V_ext, dt)
        end

        max_diff = maximum(abs.(state.phi .- phi_gp))
        @test max_diff < tolerance
    end

    @testset "C6: κ kinematic motion (proves κ evolution is wired)" begin
        # Starting from κ=0 with non-zero φ and finite g_S, after ONE BdG step κ
        # must be (a) non-zero, (b) symmetric. The previously-stubbed κ step
        # would yield κ = 0 forever.
        nx = 4
        F = 1
        D = 3
        Random.seed!(601)

        phi = randn(ComplexF64, nx, D) .* 0.5
        state = init_tdhfb_vacuum(phi)
        # rho, kappa are vacuum (zero) by init_tdhfb_vacuum

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 1.0)  # singlet only — Δ ≠ 0 with non-zero φ
        dt = 0.05

        tdhfb_strang_step!(state, F, gS, V_ext, dt)

        @test norm(state.kappa) > 1e-3

        # κ symmetric
        max_asym = 0.0
        for i in 1:nx, c in 1:D, c_p in 1:D
            d = abs(state.kappa[i, c, c_p] - state.kappa[i, c_p, c])
            max_asym = max(max_asym, d)
        end
        @test max_asym < 1e-12
    end
end

@info "TDHFB conservation tests PASS"
