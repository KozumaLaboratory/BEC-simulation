# test/oracles/test_loss_nonunitarity.jl
#
# Loss is the one NON-unitary term: three-body loss removes atoms, so a
# real-time loss step must STRICTLY decrease the norm (and never increase
# it or go negative). This is the dynamical signature that distinguishes
# the dissipative channel from the Hermitian terms (which the unitarity
# gate pins to norm-preserving). A wrong loss sign would pump atoms in.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: LossTerm, apply_step!

@testset "Loss is non-unitary: norm strictly decreases" begin
    F = 1
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    D = 2F + 1
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false),
        loss=SpinorBEC.LossParams(; K3_per_m_cubic=fill(2.0, D)),
        fft_flags=FFTW.ESTIMATE,
    )
    dV = cell_volume(grid)
    psi = zeros(ComplexF64, 8, 8, 8, D)
    @inbounds for I in CartesianIndices((8, 8, 8))
        r2 = ws.grid.x[1][I[1]]^2 + ws.grid.x[2][I[2]]^2 + ws.grid.x[3][I[3]]^2
        psi[I, 1] = exp(-0.5 * r2)
    end
    psi ./= sqrt(sum(abs2, psi) * dV)

    norm(p) = sum(abs2, p) * dV
    n0 = norm(psi)
    n_prev = n0
    for _ in 1:10
        apply_step!(LossTerm(), psi, 0.02, false, ws)
        n = norm(psi)
        @test n < n_prev          # strictly decreasing
        @test n > 0               # never negative / NaN
        n_prev = n
    end
    @test n_prev < n0             # atoms were lost (net non-unitary)
end
