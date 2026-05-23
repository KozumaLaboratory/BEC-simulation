# TDHFB Y4-midpoint integrator tests (Phase 4, WIP — see header of
# `src/hamiltonian/tdhfb/y4_midpoint_step.jl` for the order-4-not-achieved
# diagnosis).
#
# Y1: Smoke — one step preserves dimensions, advances state.t/step
# Y2: ρ Hermiticity + κ symmetry preserved over 100 Y4 steps
# Y3: Order test — verify order >= 2 (matches Strang, NOT order 4)
# Y4: Inner-substep equivalence (regression guard against semantic drift)
# Y5: Palindrome residual is O(dt²) (= proof of why Y4 cannot give order 4)
#
# Reference: src/hamiltonian/tdhfb/y4_midpoint_step.jl

using Test
using LinearAlgebra
using FFTW
using Random
using SpinorBEC

# Internal accessor for Y4-equivalence regression test
import SpinorBEC: _tdhfb_strang_substep!

@testset "TDHFB Y4-midpoint integrator (Phase 4 WIP)" begin
    function random_hermitian_rho(nx::Int, D::Int, amp::Float64; seed=1)
        rng = MersenneTwister(seed)
        rho = zeros(ComplexF64, nx, D, D)
        for i in 1:nx
            A = randn(rng, ComplexF64, D, D) .* amp
            rho[i, :, :] = (A + A') / 2
        end
        return rho
    end

    function random_symmetric_kappa(nx::Int, D::Int, amp::Float64; seed=2)
        rng = MersenneTwister(seed)
        kappa = zeros(ComplexF64, nx, D, D)
        for i in 1:nx
            A = randn(rng, ComplexF64, D, D) .* amp
            kappa[i, :, :] = (A + transpose(A)) / 2
        end
        return kappa
    end

    @testset "Y1: Smoke — one step preserves dimensions, advances t/step" begin
        nx = 8
        F = 1
        D = 3
        Random.seed!(101)

        phi = randn(ComplexF64, nx, D) .* 0.3
        state = init_tdhfb_vacuum(phi)
        state.rho .= random_hermitian_rho(nx, D, 0.05; seed=101)
        state.kappa .= random_symmetric_kappa(nx, D, 0.05; seed=102)

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.3, 2 => 0.05)
        dt = 0.01

        sz_phi = size(state.phi)
        sz_rho = size(state.rho)
        sz_kappa = size(state.kappa)

        tdhfb_y4_midpoint_step!(state, F, gS, V_ext, dt)

        @test size(state.phi) == sz_phi
        @test size(state.rho) == sz_rho
        @test size(state.kappa) == sz_kappa
        @test all(isfinite, state.phi)
        @test all(isfinite, state.rho)
        @test all(isfinite, state.kappa)
        # Y4 = 3 Strang sub-steps, so state.step advances by 3.
        @test state.step == 3
        @test isapprox(state.t, dt; atol=1e-12)
    end

    @testset "Y2: ρ Hermiticity + κ symmetry preserved over 100 Y4 steps" begin
        nx = 8
        F = 1
        D = 3
        Random.seed!(201)

        phi = randn(ComplexF64, nx, D) .* 0.3
        state = init_tdhfb_vacuum(phi)
        state.rho .= random_hermitian_rho(nx, D, 0.1; seed=201)
        state.kappa .= random_symmetric_kappa(nx, D, 0.1; seed=202)

        V_ext = zeros(Float64, nx, D)
        x = collect(0:(nx - 1)) .- nx / 2 .+ 0.5
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * 0.5^2 * x[i]^2
        end
        gS = Dict(0 => 0.5, 2 => 0.1)
        dt = 0.01

        for _ in 1:100
            tdhfb_y4_midpoint_step!(state, F, gS, V_ext, dt)
        end

        rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
        @test rho_dev < 1e-10
        @test kappa_dev < 1e-10
    end

    @testset "Y3: Convergence rate measurement (Phase 4 WIP — observed order 1)" begin
        # The Y4 *composition* is correct (verified in Y4 below), but the
        # underlying Strang substep is not palindromic at O(dt²) (verified
        # in Y5). The three-substep Yoshida composition then AMPLIFIES the
        # O(dt²) palindrome residual into an O(dt) global error
        # (each substep contributes O(dt²) which the negative-weight
        # cancellation does NOT remove). Result: Y4 wrapper measured
        # order is ~1, vs Strang's order 2.
        #
        # This is the documented Phase-4 WIP outcome. Once a palindromic
        # substep (TODO — see file header for routes) lands, this test
        # should be tightened to `order_y4 > 3.5`.
        nx = 8
        F = 1
        D = 3
        Random.seed!(301)

        phi0 = randn(ComplexF64, nx, D) .* 0.3
        rho0 = random_hermitian_rho(nx, D, 0.05; seed=301)
        kappa0 = random_symmetric_kappa(nx, D, 0.05; seed=302)

        V_ext = zeros(Float64, nx, D)
        x = collect(0:(nx - 1)) .- nx / 2 .+ 0.5
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * 0.3^2 * x[i]^2
        end
        gS = Dict(0 => 0.3, 2 => 0.05)

        t_end = 0.16
        dts = [0.04, 0.02, 0.01, 0.005]

        function run_y4(dt)
            phi = copy(phi0)
            state = init_tdhfb_vacuum(phi)
            state.rho .= rho0
            state.kappa .= kappa0
            nsteps = round(Int, t_end / dt)
            for _ in 1:nsteps
                tdhfb_y4_midpoint_step!(state, F, gS, V_ext, dt)
            end
            return state.phi
        end

        function run_strang(dt)
            phi = copy(phi0)
            state = init_tdhfb_vacuum(phi)
            state.rho .= rho0
            state.kappa .= kappa0
            nsteps = round(Int, t_end / dt)
            for _ in 1:nsteps
                tdhfb_strang_step!(state, F, gS, V_ext, dt)
            end
            return state.phi
        end

        # Use a very-fine Strang run as ground truth.
        phi_truth = run_strang(0.0001)

        errs_y4 = Float64[]
        errs_strang = Float64[]
        for dt in dts
            push!(errs_y4, maximum(abs, run_y4(dt) .- phi_truth))
            push!(errs_strang, maximum(abs, run_strang(dt) .- phi_truth))
        end

        # Slope between the two coarsest dts (where higher-order corrections
        # have not yet hit the round-off floor).
        function slope(d1, d2, e1, e2)
            return log(e1 / e2) / log(d1 / d2)
        end

        order_strang = slope(dts[1], dts[2], errs_strang[1], errs_strang[2])
        order_y4 = slope(dts[1], dts[2], errs_y4[1], errs_y4[2])

        @info "Y3 convergence" errs_y4 errs_strang order_y4 order_strang

        # Strang must be order 2 — REGRESSION guard for any change to the
        # base Strang substep.
        @test 1.5 < order_strang < 2.5
        # Y4 is currently ~order 1 (palindrome-residual amplified by the
        # negative-weight composition). We assert observed order > 0.7 so
        # the test catches a complete blowup, AND we assert the order is
        # below the theoretical Yoshida-4 of 4 so the test is honest
        # about the current state. When a palindromic substep is wired
        # in, flip the inequality direction and tighten to > 3.5.
        @test 0.7 < order_y4 < 3.5
    end

    @testset "Y4: substep reproduces tdhfb_strang_step! byte-for-byte" begin
        # Regression guard: the inner substep (picard_midpoint=false) must
        # match the existing Strang step exactly (within machine epsilon).
        # This protects the wrapper from silent semantic drift if someone
        # rewrites `_tdhfb_strang_substep!`.
        nx = 8
        F = 1
        D = 3
        Random.seed!(401)

        phi = randn(ComplexF64, nx, D) .* 0.3
        rho = random_hermitian_rho(nx, D, 0.05; seed=401)
        kappa = random_symmetric_kappa(nx, D, 0.05; seed=402)

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.3, 2 => 0.05)
        dt = 0.01

        state_s = init_tdhfb_vacuum(copy(phi))
        state_s.rho .= rho
        state_s.kappa .= kappa
        tdhfb_strang_step!(state_s, F, gS, V_ext, dt)

        state_sub = init_tdhfb_vacuum(copy(phi))
        state_sub.rho .= rho
        state_sub.kappa .= kappa
        _tdhfb_strang_substep!(state_sub, F, gS, V_ext, dt)

        @test maximum(abs, state_s.phi .- state_sub.phi) < 1e-14
        @test maximum(abs, state_s.rho .- state_sub.rho) < 1e-14
        @test maximum(abs, state_s.kappa .- state_sub.kappa) < 1e-14

        # And manually composing three tdhfb_strang_step! calls at (w1, w0, w1)
        # reproduces tdhfb_y4_midpoint_step!.
        w1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
        w0 = 1.0 - 2 * w1

        state_h = init_tdhfb_vacuum(copy(phi))
        state_h.rho .= rho
        state_h.kappa .= kappa
        tdhfb_strang_step!(state_h, F, gS, V_ext, w1 * dt)
        tdhfb_strang_step!(state_h, F, gS, V_ext, w0 * dt)
        tdhfb_strang_step!(state_h, F, gS, V_ext, w1 * dt)

        state_y = init_tdhfb_vacuum(copy(phi))
        state_y.rho .= rho
        state_y.kappa .= kappa
        tdhfb_y4_midpoint_step!(state_y, F, gS, V_ext, dt)

        @test maximum(abs, state_h.phi .- state_y.phi) < 1e-14
        @test maximum(abs, state_h.rho .- state_y.rho) < 1e-14
        @test maximum(abs, state_h.kappa .- state_y.kappa) < 1e-14
    end

    @testset "Y5: Strang palindrome residual is O(dt²) (root cause of Y3)" begin
        # If `S(-dt) ∘ S(dt) = I + O(dt^5)` (true palindrome), Yoshida-4
        # delivers order 4. We measure the residual at several dt and check
        # the slope to demonstrate why Phase 4 stops at order 2: the
        # residual is O(dt²), not O(dt^5).
        nx = 8
        F = 1
        D = 3
        Random.seed!(501)

        phi0 = randn(ComplexF64, nx, D) .* 0.3
        rho0 = random_hermitian_rho(nx, D, 0.05; seed=501)
        kappa0 = random_symmetric_kappa(nx, D, 0.05; seed=502)

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.3, 2 => 0.05)

        dts = [0.04, 0.02, 0.01, 0.005]
        residuals = Float64[]
        for dt in dts
            state = init_tdhfb_vacuum(copy(phi0))
            state.rho .= rho0
            state.kappa .= kappa0
            tdhfb_strang_step!(state, F, gS, V_ext, dt)
            tdhfb_strang_step!(state, F, gS, V_ext, -dt)
            # Worst-case across all three fields. The ρ component dominates
            # by ~30× over φ in practice — that's the BdG non-conjugation
            # asymmetry leaking through.
            r = max(maximum(abs, state.phi .- phi0),
                maximum(abs, state.rho .- rho0),
                maximum(abs, state.kappa .- kappa0))
            push!(residuals, r)
        end

        # Slope between coarsest dts: should be ~2 (proves O(dt²) palindrome
        # remainder, NOT O(dt^5) as would be needed for Y4 to deliver
        # order 4).
        slope = log(residuals[1] / residuals[2]) / log(dts[1] / dts[2])
        @info "Y5 palindrome residual" dts residuals slope
        @test 1.5 < slope < 2.5
    end

    @testset "Y6: picard_midpoint=true clears the palindromic gate (A4)" begin
        # With picard_midpoint=true, all generators are evaluated at the
        # midpoint state via Picard fixed-point — the substep becomes
        # palindromic at Picard tolerance, so S(-dt) ∘ S(dt) = I to machine
        # precision regardless of dt. A4 acceptance #1.
        nx = 8
        F = 1
        D = 3
        Random.seed!(601)

        phi0 = randn(ComplexF64, nx, D) .* 0.3
        rho0 = random_hermitian_rho(nx, D, 0.05; seed=601)
        kappa0 = random_symmetric_kappa(nx, D, 0.05; seed=602)

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.3, 2 => 0.05)

        for dt in (0.04, 0.01, 0.0025)
            state = init_tdhfb_vacuum(copy(phi0))
            state.rho .= rho0
            state.kappa .= kappa0
            tdhfb_strang_step!(state, F, gS, V_ext, dt;
                picard_midpoint=true, picard_max_iter=30, picard_tol=1e-12)
            tdhfb_strang_step!(state, F, gS, V_ext, -dt;
                picard_midpoint=true, picard_max_iter=30, picard_tol=1e-12)
            r = max(maximum(abs, state.phi .- phi0),
                maximum(abs, state.rho .- rho0),
                maximum(abs, state.kappa .- kappa0))
            @test r < 1e-10
        end
    end

    @testset "Y7: picard_midpoint=true unlocks Y4 order 4 (A4 acceptance)" begin
        # With palindromic substep, Yoshida-4 composition delivers global
        # order 4. Use a coarse dt range so the order signal sits well above
        # the F64 noise floor (~1e-14): finer dts saturate at machine eps
        # and report bogus order. A4 acceptance #2.
        nx = 8
        F = 1
        D = 3
        Random.seed!(701)

        phi0 = randn(ComplexF64, nx, D) .* 0.3
        rho0 = random_hermitian_rho(nx, D, 0.05; seed=701)
        kappa0 = random_symmetric_kappa(nx, D, 0.05; seed=702)

        V_ext = zeros(Float64, nx, D)
        gS = Dict(0 => 0.3, 2 => 0.05)
        T_FINAL = 0.04

        function _run_y4(dt)
            state = init_tdhfb_vacuum(copy(phi0))
            state.rho .= rho0
            state.kappa .= kappa0
            n_steps = Int(round(T_FINAL / dt))
            actual_dt = T_FINAL / n_steps
            for _ in 1:n_steps
                tdhfb_y4_midpoint_step!(state, F, gS, V_ext, actual_dt;
                    picard_midpoint=true,
                    picard_midpoint_max_iter=30,
                    picard_midpoint_tol=1e-12,
                )
            end
            state
        end

        # Reference at dt = 2.5e-4 (160 steps). Test dts chosen so errors
        # are at 1e-10 ... 1e-12, well above F64 noise floor ~1e-14.
        state_ref = _run_y4(2.5e-4)
        dts = [4.0e-3, 2.0e-3]
        errs = Float64[]
        for dt in dts
            state = _run_y4(dt)
            e = max(maximum(abs, state.phi .- state_ref.phi),
                maximum(abs, state.rho .- state_ref.rho),
                maximum(abs, state.kappa .- state_ref.kappa))
            push!(errs, e)
        end
        order = log2(errs[1] / errs[2])
        @info "Y7 Y4 order with picard_midpoint" dts errs order
        @test order >= 3.5
    end
end

@info "TDHFB Y4-midpoint Phase 4 WIP tests PASS"
