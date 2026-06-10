# test/oracles/test_energy_decomposition_sum.jl
#
# Bookkeeping gate: the total energy must equal the sum of its per-term
# parts. `energy_decomposition` returns a NamedTuple of per-term
# contributions plus `:total`; Σ(parts) ≡ total. A term that is computed
# but dropped from the total (or double-counted) is caught here regardless
# of the field names.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: energy_decomposition, total_energy, compute_c_dd

@testset "energy_decomposition: total = Σ parts" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.2)),
        zeeman=ZeemanParams(0.4, 0.1), potential=HarmonicTrap((1.0, 1.2, 0.8)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true,
            rotating_frame_omega=0.3),
        enable_ddi=true, c_dd=compute_c_dd(Eu151),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    copyto!(ws.state.psi, psi)

    nt = energy_decomposition(ws)
    parts = sum(getfield(nt, k) for k in keys(nt) if k != :total)
    @test isapprox(nt.total, parts; rtol=1e-10, atol=1e-12)
    @test isapprox(total_energy(ws), nt.total; rtol=1e-12)
    # at least one interaction part is non-trivial (not a degenerate all-zero pass)
    @test abs(parts) > 1e-8
end
