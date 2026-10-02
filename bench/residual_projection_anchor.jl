# Harmonic-oscillator anchor: a constant potential offset cannot alter the
# minimizer or its projected residual. Test both implementations on one input.
using SpinorBEC, FFTW, Printf, Test
source = read("src/solvers/newton_cg.jl", String)
start = findfirst("function residual_newton_refine(", source)
stop = findfirst("# Preconditioned CG for the Newton step", source)
body = source[first(start):(first(stop) - 1)]
# Mutate only the trial projection to reproduce the original defect.
needle = "residual_norm(prm_t, ψt)"
@assert occursin(needle, body)
reference = replace(body,
    "function residual_newton_refine(" => "function residual_old_projection_probe(",
    needle => "residual_norm(prm_t)")
Base.include_string(SpinorBEC, reference, "old_projection_probe.jl")

grid = make_grid(GridConfig(64, 16.0))
psi = zeros(ComplexF64, 64, 3)
psi[:, 2] .= exp.(-grid.x[1] .^ 2 ./ 2) .* (1 .+ 0.01 .* grid.x[1])
psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
for offset in (0.0, 100.0),
    (name, solve) in
    (("old_projection", SpinorBEC.residual_old_projection_probe),
        ("trial_projection", SpinorBEC.residual_newton_refine))

    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        potential=HarmonicTrap(1.0), psi_init=psi,
        sim_params=SimParams(; dt=1e-4, n_steps=1), fft_flags=FFTW.ESTIMATE)
    ws.potential_values .+= offset
    result = solve(ws, psi; tol=1e-9, max_outer=8, max_cg=80,
        ε=6e-4, hvp_order=4)
    g = similar(psi)
    energy = SpinorBEC.energy_gradient!(g, result.psi, ws)
    mu = real(sum(conj.(result.psi) .* g)) * cell_volume(grid) / 2
    residual = sqrt(sum(abs2, g .- 2mu .* result.psi) * cell_volume(grid))
    @printf("ANCHOR offset=%.0f arm=%s energy_error=%.4e residual=%.4e iterations=%d\n",
        offset, name, energy - (0.5 + offset), residual, result.iterations)
    flush(stdout)
    if name == "trial_projection"
        @test abs(energy - (0.5 + offset)) < 1e-10
        @test residual < 1e-9
    end
end
