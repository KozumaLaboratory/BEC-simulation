# Directional gate for apply_fl_alignment (Flower/FL phase): rotating the
# m=+F state to the local field direction must leave ⟨F⟩ parallel to B.
# The historical bug applied a single rotation by α about (0,sinβ,cosβ)
# (plus a dead identity step), instead of U=R_z(α)R_y(β) — so for B=+x̂
# (α=0) it was a no-op and ⟨F⟩ stayed along +ẑ. This pins the alignment.

using Test
using SpinorBEC
using SpinorBEC: apply_fl_alignment, spin_density_vector, total_density, spin_matrices

@testset "apply_fl_alignment: ⟨F⟩ ∥ B" begin
    F = 1
    D = 2F + 1
    grid = make_grid(GridConfig((8,), (8.0,)))
    sm = spin_matrices(F)
    dV = cell_volume(grid)

    # density envelope (input only provides |ψ|²; FL builds the aligned m=+F)
    psi = zeros(ComplexF64, 8, D)
    for i in 1:8
        psi[i, 1] = exp(-0.1 * (i - 4.5)^2)
    end
    psi ./= sqrt(sum(abs2, psi) * dV)

    function aligned_F(bx, by, bz)
        Bx = fill(Float64(bx), 8)
        By = fill(Float64(by), 8)
        Bz = fill(Float64(bz), 8)
        out = apply_fl_alignment(psi, Bx, By, Bz, F, sm)
        fx, fy, fz = spin_density_vector(out, sm, 1)
        n = sum(total_density(out, 1)) * dV
        (sum(fx) * dV / n, sum(fy) * dV / n, sum(fz) * dV / n)
    end

    @testset "B = +x̂ ⇒ ⟨F⟩ = (F,0,0)" begin
        fx, fy, fz = aligned_F(1.0, 0.0, 0.0)
        @test isapprox(fx, Float64(F); atol=1e-3)
        @test abs(fy) < 1e-3
        @test abs(fz) < 1e-3
    end

    @testset "B = +ŷ ⇒ ⟨F⟩ = (0,F,0)" begin
        fx, fy, fz = aligned_F(0.0, 1.0, 0.0)
        @test abs(fx) < 1e-3
        @test isapprox(fy, Float64(F); atol=1e-3)
        @test abs(fz) < 1e-3
    end

    @testset "B = +ẑ ⇒ ⟨F⟩ = (0,0,F)" begin
        fx, fy, fz = aligned_F(0.0, 0.0, 1.0)
        @test abs(fx) < 1e-3
        @test abs(fy) < 1e-3
        @test isapprox(fz, Float64(F); atol=1e-3)
    end

    @testset "tilted B ⇒ ⟨F⟩ ∥ B̂ (full alignment)" begin
        b = (0.5, -0.7, 0.6)
        bn = sqrt(sum(abs2, b))
        fx, fy, fz = aligned_F(b...)
        # ⟨F⟩ points along B̂ with magnitude F
        @test isapprox(fx, F * b[1] / bn; atol=1e-3)
        @test isapprox(fy, F * b[2] / bn; atol=1e-3)
        @test isapprox(fz, F * b[3] / bn; atol=1e-3)
    end
end
