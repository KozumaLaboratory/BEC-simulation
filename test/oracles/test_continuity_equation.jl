# test/oracles/test_continuity_equation.jl
#
# Mass conservation in differential form: ∂n/∂t + ∇·j = 0, where
# j = Σ_c Im(ψ_c*∇ψ_c). Evolve a smooth state by free (kinetic) real-time
# flow for a small dt and check the time-centred density change matches the
# divergence of the time-centred current to O(dt²). Ties together the
# propagator, the FFT current, and the FFT divergence — a sign error in any
# would break the balance.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: KineticTerm, apply_step!, probability_current,
    total_density, _fft_partial_derivative

@testset "Continuity ∂n/∂t + ∇·j = 0 (free flow)" begin
    grid = make_grid(GridConfig((24, 24, 24), (12.0, 12.0, 12.0)))
    ws = make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=0.001, n_steps=1, imaginary_time=false),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components

    # smooth Gaussian wavepacket with a transverse phase gradient (moving)
    psi = zeros(ComplexF64, 24, 24, 24, D)
    @inbounds for I in CartesianIndices((24, 24, 24))
        x = ws.grid.x[1][I[1]]; y = ws.grid.x[2][I[2]]; z = ws.grid.x[3][I[3]]
        psi[I, 1] = exp(-0.5 * (x^2 + y^2 + z^2)) * cis(0.7 * x + 0.4 * y)
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))

    n0 = total_density(psi, 3)
    j0 = probability_current(psi, grid, ws.fft_plans)
    dt = 0.001
    apply_step!(KineticTerm(), psi, dt, false, ws)   # exact free evolution
    n1 = total_density(psi, 3)
    j1 = probability_current(psi, grid, ws.fft_plans)

    dndt = (n1 .- n0) ./ dt
    jm = ntuple(d -> 0.5 .* (j0[d] .+ j1[d]), 3)      # time-centred current
    divj = _fft_partial_derivative(jm[1], grid, ws.fft_plans, 1) .+
           _fft_partial_derivative(jm[2], grid, ws.fft_plans, 2) .+
           _fft_partial_derivative(jm[3], grid, ws.fft_plans, 3)

    resid = dndt .+ divj
    @test maximum(abs, resid) < 1e-3 * maximum(abs, dndt)
end
