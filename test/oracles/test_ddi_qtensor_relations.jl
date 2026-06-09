# test/oracles/test_ddi_qtensor_relations.jl
#
# Structural identities of the DDI Q-tensor that hold at EVERY k (no need
# to reconstruct the wavevectors), so they pin the kernel construction
# directly:
#   • full:    traceless  Q_xx+Q_yy+Q_zz = 0
#   • secular: Q_xx = Q_yy = −Q_zz/2  and  all off-diagonals = 0
#     (the rotating-frame-averaged dipolar kernel; only Q_zz survives).
# A wrong −δ/3, a missing secular collapse, or a stray off-diagonal in the
# secular branch lights up here.

using Test
using SpinorBEC
using SpinorBEC: make_ddi_params

@testset "DDI Q-tensor structural relations" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))

    @testset "full kernel is traceless" begin
        ddi = make_ddi_params(grid, Eu151)
        tr = ddi.Q_xx .+ ddi.Q_yy .+ ddi.Q_zz
        @test maximum(abs, tr) < 1e-12
    end

    @testset "secular kernel: Q_xx=Q_yy=−Q_zz/2, off-diagonals=0" begin
        ddi = make_ddi_params(grid, Eu151; secular=true)
        @test maximum(abs, ddi.Q_xx .- ddi.Q_yy) < 1e-12
        @test maximum(abs, ddi.Q_xx .+ 0.5 .* ddi.Q_zz) < 1e-12
        @test maximum(abs, ddi.Q_xy) == 0.0
        @test maximum(abs, ddi.Q_xz) == 0.0
        @test maximum(abs, ddi.Q_yz) == 0.0
        # secular is still traceless
        @test maximum(abs, ddi.Q_xx .+ ddi.Q_yy .+ ddi.Q_zz) < 1e-12
    end
end
