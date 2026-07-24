# Quantify how much _null_nyquist_modes! would change already-saved GS states,
# i.e. would re-running (now that the ψ-null is in the pipeline) change results.
#   julia --project=. scripts/eu_nyquist_impact.jl <run_dir>
using SpinorBEC, JLD2, FFTW, Printf
using SpinorBEC: make_grid, GridConfig, _null_nyquist_modes!
run = ARGS[1]
files = filter(f -> startswith(f, "point_") && endswith(f, ".jld2"), readdir(run))
for f in first(sort(files), 6)
    p = joinpath(run, f)
    psi = ComplexF64.(JLD2.load(p, "psi"))
    n = size(psi, 1)
    pk = fft(@view psi[:, :, :, 1])
    nyq = div(n, 2) + 1
    nyqpow = abs(pk[nyq, nyq, nyq]) / (sum(abs, pk) + 1e-30)
    n0 = sqrt(sum(abs2, psi))
    p2 = copy(psi)
    grid = make_grid(GridConfig(Tuple(Int.(JLD2.load(p, "grid_n_points"))),
        Tuple(Float64.(JLD2.load(p, "grid_box_size")))))
    _null_nyquist_modes!(p2, grid)
    dpsi = sqrt(sum(abs2, p2 .- psi)) / n0
    @printf("%-28s Nyquist/tot=%.1e  |Δψ|/|ψ|=%.1e\n", f, nyqpow, dpsi)
end
