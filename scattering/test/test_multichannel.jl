using Test
using Scattering
using LinearAlgebra

@testset "Multichannel Numerov: decoupled two-channel matches single-channel" begin
    # Two independent square wells, no coupling. Multichannel run must
    # give each channel's a_i equal to the single-channel reference.
    μ = 1.0
    V1 = 0.3; R1 = 5.0
    V2 = 0.8; R2 = 4.0
    V_single_1(R) = R < R1 ? -V1 : 0.0
    V_single_2(R) = R < R2 ? -V2 : 0.0

    h = 5e-4
    R_min = 1e-8
    R_max = max(3R1, 3R2)

    a1_ref = zero_energy_scattering_length(V_single_1, R_min, R_max, h;
                                            μ = μ, u0 = (0.0, R_min + h))
    a2_ref = zero_energy_scattering_length(V_single_2, R_min, R_max, h;
                                            μ = μ, u0 = (0.0, R_min + h))

    # Build uncoupled 2-channel M(R): W is diagonal, no threshold shift,
    # both ℓ=0, E=0.
    W_func(R) = [V_single_1(R) 0.0; 0.0 V_single_2(R)]
    M_func = make_channel_M(W_func, [0.0, 0.0], [0, 0], μ, 0.0)

    U0 = zeros(2, 2)
    U1 = (R_min + h) * Matrix{Float64}(I, 2, 2)
    Rs, U = numerov_multichannel(M_func, R_min, R_max, h; U0 = U0, U1 = U1)

    # Channel 1 column (2nd solution column) drives channel 2, so extract
    # per-channel scattering length from diagonal component.
    N = length(Rs)
    u1 = U[1, 1, :]
    u2 = U[2, 2, :]
    h_step = Rs[2] - Rs[1]
    # central-difference u' at penultimate grid point
    for (ch, u_vec, a_ref) in ((1, u1, a1_ref), (2, u2, a2_ref))
        u_mid = u_vec[N - 1]
        u_deriv = (u_vec[N] - u_vec[N - 2]) / (2 * h_step)
        a_num = Rs[N - 1] - u_mid / u_deriv
        @test a_num ≈ a_ref rtol = 1e-3
    end
    # Off-diagonal block is zero for uncoupled problem
    @test maximum(abs.(U[1, 2, :])) == 0.0
    @test maximum(abs.(U[2, 1, :])) == 0.0
end

@testset "Multichannel Numerov: free-particle K-matrix is zero" begin
    # Two decoupled free channels at E > 0: sin(k_i R) each. K_ii = 0.
    μ = 1.0
    E = 0.5
    k = sqrt(2 * μ * E)
    W_func(R) = zeros(2, 2)
    M_func = make_channel_M(W_func, [0.0, 0.0], [0, 0], μ, E)

    h = 1e-3
    R_min = 1e-6; R_max = 20.0
    # Exact start on sin(kR) for both channels
    U0 = diagm([sin(k * R_min) / k, sin(k * R_min) / k])
    U1 = diagm([sin(k * (R_min + h)) / k, sin(k * (R_min + h)) / k])

    Rs, U = numerov_multichannel(M_func, R_min, R_max, h; U0 = U0, U1 = U1)
    N = length(Rs)
    K = kmatrix_swave(U[:, :, N], U[:, :, N - 1], Rs[2] - Rs[1],
                       [k, k], Rs[N])
    @test maximum(abs.(K)) < 1e-6
end

@testset "S-matrix from K-matrix is unitary" begin
    K = [0.3 0.1; 0.1 -0.2]
    S = smatrix_from_kmatrix(K)
    @test S * S' ≈ I(2) atol = 1e-12
    @test S' * S ≈ I(2) atol = 1e-12
end

@testset "Multichannel: square well K-matrix → phase shift δ = −kR₀ + k·a" begin
    # Single (1×1 matrix) test against square well: K = tan(δ) = −k·a at
    # low energy; check that at a finite small k we get K ≈ −tan(k·a_eff).
    μ = 1.0
    V0 = 0.3; R0 = 4.0
    E = 1e-4
    k = sqrt(2 * μ * E)

    W_func(R) = reshape([R < R0 ? -V0 : 0.0], 1, 1)
    M_func = make_channel_M(W_func, [0.0], [0], μ, E)
    h = 5e-4
    R_min = 1e-8; R_max = 3 * R0
    U0 = reshape([0.0], 1, 1)
    U1 = reshape([R_min + h], 1, 1)
    Rs, U = numerov_multichannel(M_func, R_min, R_max, h; U0 = U0, U1 = U1)
    N = length(Rs)
    K = kmatrix_swave(U[:, :, N], U[:, :, N - 1], Rs[2] - Rs[1], [k], Rs[N])
    a_analytic = square_well_scattering_length(V0, R0; μ = μ)
    # K ≈ −tan(k·a) / ... at low energy. For ℓ=0, tan(δ) = −K·k (in our
    # conventions), so K → −k·a as k → 0. Here k is small, so
    #     a_from_K = −K[1,1] / k
    a_from_K = -K[1, 1] / k
    @test a_from_K ≈ a_analytic rtol = 5e-3
end
