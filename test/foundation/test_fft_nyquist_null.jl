# Regression guard: FFT first-derivative helpers must NULL the Nyquist mode, so
# the k=±N/2 checkerboard artifact cannot reappear in currents / L_z / gradients.
# Without the null, d/dx of a pure checkerboard (the Nyquist mode) via ik·FFT is a
# large spurious field; with it, ≈0.

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, make_fft_plans,
    _fft_partial_derivative, _fft_gradient, probability_current

@testset "Nyquist-null in FFT first-derivatives" begin
    n = (16, 16, 16)
    grid = make_grid(GridConfig(n, (8.0, 8.0, 8.0)))
    plans = make_fft_plans(n)

    # pure Nyquist (checkerboard) real field: only k=±N/2 content
    cb = Float64[(-1.0)^(i + j + k) for i in 1:16, j in 1:16, k in 1:16]

    d = _fft_partial_derivative(cb, grid, plans, 1)
    @test maximum(abs, d) < 1e-8            # derivative of the Nyquist mode nulled → ≈0

    g = _fft_gradient(cb, grid, plans)
    @test all(maximum(abs, gd) < 1e-8 for gd in g)

    # a smooth PERIODIC field must still differentiate correctly (null harmless)
    x = grid.x[1]
    L = grid.config.box_size[1]
    kf = 2π / L                              # fundamental mode ⇒ periodic on the box
    sm = Float64[sin(kf * x[i]) for i in 1:16, _ in 1:16, __ in 1:16]
    ds = _fft_partial_derivative(sm, grid, plans, 1)
    dref = Float64[kf * cos(kf * x[i]) for i in 1:16, _ in 1:16, __ in 1:16]
    @test maximum(abs, ds .- dref) < 1e-6   # null does NOT harm resolved derivatives

    # probability_current: a ψ with Nyquist phase contamination ⇒ no checkerboard in j
    D = 13
    psi = zeros(ComplexF64, n..., D)
    for I in CartesianIndices(n)
        r2 = (I[1] - 8)^2 + (I[2] - 8)^2 + (I[3] - 8)^2
        psi[I, 1] = exp(-0.1 * r2) * exp(im * 1e-2 * (-1.0)^(I[1] + I[2] + I[3]))
    end
    jx, _, _ = probability_current(psi, grid, plans)
    chk = Float64[(-1.0)^(i + j) for i in 1:16, j in 1:16]
    sx = jx[:, :, 8]
    cbf = abs(sum(sx .* chk)) / (sum(abs, sx) + 1e-30)
    @test cbf < 0.3                          # no dominant Nyquist checkerboard in j
end
