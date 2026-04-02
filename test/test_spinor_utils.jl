using Test
using SpinorBEC
using StaticArrays

@testset "Spinor Utils" begin
    @testset "_get_spinor and _set_spinor! round-trip" begin
        psi = zeros(ComplexF64, 16, 3)
        psi[5, 1] = 1.0 + 0.5im
        psi[5, 2] = 0.3 - 0.2im
        psi[5, 3] = -0.1 + 0.7im

        I = CartesianIndex(5)
        s = SpinorBEC._get_spinor(psi, I, Val(3))
        @test s isa SVector{3,ComplexF64}
        @test s[1] ≈ 1.0 + 0.5im
        @test s[2] ≈ 0.3 - 0.2im
        @test s[3] ≈ -0.1 + 0.7im

        new_s = SVector{3,ComplexF64}(0.1, 0.2, 0.3)
        SpinorBEC._set_spinor!(psi, I, new_s, Val(3))
        @test psi[5, 1] ≈ 0.1
        @test psi[5, 2] ≈ 0.2
        @test psi[5, 3] ≈ 0.3
    end

    @testset "_component_slice" begin
        n_pts = (16,)
        idx = SpinorBEC._component_slice(1, n_pts, 2)
        @test idx == (1:16, 2)
    end

    @testset "_component_slice 2D" begin
        n_pts = (8, 8)
        idx = SpinorBEC._component_slice(2, n_pts, 3)
        @test idx == (1:8, 1:8, 3)
    end

    @testset "_matvec is allocation-free and correct" begin
        sm = spin_matrices(1)
        V = Matrix{ComplexF64}(sm.Fx)
        x = SVector{3,ComplexF64}(1.0, 0.0, 0.0)

        result = SpinorBEC._matvec(V, x)
        expected = V * Vector(x)
        @test result ≈ SVector{3,ComplexF64}(expected)
    end

    @testset "_exp_i_hermitian unitarity (F=1)" begin
        sm = spin_matrices(1)
        H = SMatrix{3,3,ComplexF64}(sm.Fz + 0.5 * sm.Fx)
        dt = 0.1

        U = SpinorBEC._exp_i_hermitian(H, dt, false)
        @test U * U' ≈ SMatrix{3,3,ComplexF64}(I) atol = 1e-12
    end

    @testset "_apply_euler_spin_rotation preserves norm" begin
        sm = spin_matrices(2)
        F = 2
        D = 5
        m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))
        V_Fy = sm.Fy_eigvecs
        Vt_Fy = sm.Fy_eigvecs_adj
        λ_Fy = sm.Fy_eigvals

        spinor = SVector{D,ComplexF64}(normalize(randn(ComplexF64, D)))
        phi_x, phi_y, phi_z = 1.0, 0.5, 0.3
        dt = 0.05

        result = SpinorBEC._apply_euler_spin_rotation(
            spinor, phi_x, phi_y, phi_z,
            dt, F, m_vals, V_Fy, Vt_Fy, λ_Fy, sm, false)

        @test norm(result) ≈ norm(spinor) rtol = 1e-12
    end

    @testset "_apply_euler_spin_rotation matches _exp_i_hermitian (F=1)" begin
        sm = spin_matrices(1)
        F = 1
        D = 3
        m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))

        phi_x, phi_y, phi_z = 0.5, -0.3, 0.7
        dt = 0.1
        H = SMatrix{3,3,ComplexF64}(phi_x * sm.Fx + phi_y * sm.Fy + phi_z * sm.Fz)

        spinor = SVector{D,ComplexF64}(normalize(randn(ComplexF64, D)))
        U = SpinorBEC._exp_i_hermitian(H, dt, false)
        expected = U * spinor

        result = SpinorBEC._apply_euler_spin_rotation(
            spinor, phi_x, phi_y, phi_z,
            dt, F, m_vals, sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals, sm, false)

        @test result ≈ expected atol = 1e-12
    end

    @testset "_apply_euler_spin_rotation zero field returns spinor" begin
        sm = spin_matrices(1)
        F = 1
        D = 3
        m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))

        spinor = SVector{D,ComplexF64}(0.5, 0.3 + 0.1im, 0.2 - 0.4im)
        result = SpinorBEC._apply_euler_spin_rotation(
            spinor, 0.0, 0.0, 0.0,
            0.1, F, m_vals, sm.Fy_eigvecs, sm.Fy_eigvecs_adj, sm.Fy_eigvals, sm, false)

        @test result ≈ spinor atol = 1e-13
    end
end
