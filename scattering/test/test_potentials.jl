using Test
using Scattering

@testset "Eu+Eu MLR potential V_{S=7}(R)" begin
    p = eueu_septet_params()
    De_cm1 = 704.32
    Re = p.Re

    # --- well depth at R = Re: V = -De ---
    @test V_septet(p, Re) ≈ -p.De atol = 1e-14
    @test au_to_cm1(V_septet(p, Re)) ≈ -De_cm1 rtol = 1e-6

    # --- asymptote: V → 0 at large R ---
    @test isapprox(V_septet(p, 1e5), 0.0, atol = 1e-20)

    # --- long-range tail: V(R) → -C_6/R^6 for R ≫ Re ---
    # At 200 a_0 (≈ 22·Re) the MLR correction is tiny; V ≈ -C_6/R^6.
    R_far = 200.0
    V_tail = -p.C6 / R_far^6
    @test V_septet(p, R_far) ≈ V_tail rtol = 1e-4

    # --- V monotonically approaches 0 from below for R > Re ---
    Rs_outer = Re .+ [1.0, 3.0, 10.0, 30.0, 100.0]
    Vs_outer = V_septet.(Ref(p), Rs_outer)
    @test all(Vs_outer .< 0)
    @test issorted(Vs_outer)  # increasing toward 0

    # --- repulsive wall inside Re ---
    @test V_septet(p, 6.0) > V_septet(p, Re)
    @test V_septet(p, 5.0) > V_septet(p, 6.0)
end

@testset "Eu+Eu exchange coupling J(R)" begin
    e = eueu_exchange_params()

    # --- peak magnitude at R = R_0: |J| = |α| ---
    @test J_exchange(e, e.R0) ≈ e.alpha atol = 1e-14
    @test au_to_cm1(J_exchange(e, e.R0)) ≈ -0.53915 rtol = 1e-6

    # --- sign: α < 0 from Tomza 2018 ---
    @test e.alpha < 0
    @test J_exchange(e, e.R0) < 0

    # --- decay: |J(R→∞)| → 0, |J(R→0)| → 0 (cosh diverges both sides) ---
    # β·Δ=24 ⇒ cosh ≈ e²⁴/2 ≈ 1.3e10, |α|≈2.5e-6 E_h ⇒ |J| ≲ 2e-16 E_h
    @test abs(J_exchange(e, e.R0 + 30.0)) < 1e-14
    @test abs(J_exchange(e, e.R0 - 30.0)) < 1e-14

    # --- monotone decay from R_0 outward ---
    Rs = e.R0 .+ [0.5, 1.0, 2.0, 4.0, 8.0]
    Js = abs.(J_exchange.(Ref(e), Rs))
    @test issorted(Js; rev = true)
end

@testset "V_S via Heisenberg model" begin
    p = eueu_septet_params()
    e = eueu_exchange_params()

    # --- S = 7: correction vanishes identically ---
    for R in (6.0, 8.0, 9.2919, 12.0, 50.0)
        @test V_spin(p, e, 7, R) == V_septet(p, R)
    end

    # --- S = 0: correction = 28 · J(R) ---
    R = 9.0
    @test V_spin(p, e, 0, R) ≈ V_septet(p, R) + 28 * J_exchange(e, R) atol = 1e-14

    # --- Heisenberg factor (56 - S(S+1))/2 at R_0 ---
    J0 = J_exchange(e, e.R0)
    for S in 0:7
        expected = V_septet(p, e.R0) + (56 - S * (S + 1)) / 2 * J0
        @test V_spin(p, e, S, e.R0) ≈ expected atol = 1e-14
    end

    # --- ordering at R = R_0 where |J| is maximal: α < 0 ⇒ V_0 < V_1 < ... < V_7
    #     (Heisenberg factor decreasing in S, times negative J, gives increasing V) ---
    Vs = [V_spin(p, e, S, e.R0) for S in 0:7]
    @test issorted(Vs)

    # --- asymptote: at R large, exchange ≈ 0, so V_S ≈ V_{S=7} for all S ---
    R_far = 50.0
    for S in 0:7
        @test V_spin(p, e, S, R_far) ≈ V_septet(p, R_far) atol = 1e-14
    end

    # --- domain check: S outside 0..7 rejected ---
    @test_throws ArgumentError V_spin(p, e, -1, 9.0)
    @test_throws ArgumentError V_spin(p, e, 8, 9.0)
end

@testset "Unit conversions cm⁻¹ ↔ E_h" begin
    # 1 cm⁻¹ ≈ 4.55633525e-6 E_h (CODATA 2018; exact h, c; E_h to ~10⁻¹⁰)
    @test cm1_to_au(1.0) ≈ 4.55633525e-6 rtol = 1e-7
    @test au_to_cm1(cm1_to_au(123.456)) ≈ 123.456 rtol = 1e-12
    @test cm1_to_au(0.0) == 0.0
end
