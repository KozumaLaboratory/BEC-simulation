using SpinorBEC
using SpinorBEC: DDITerm, apply_operator!, energy_contribution
using FFTW
using LinearAlgebra
using Random
using Test

# The DDI energy and gradient must come from the SAME kernel.
#
# `_ddi_energy` branches on `ws.ddi_padded`; until 2026-07-30 `_grad_ddi!` did
# not. With `ddi_padding` on — the YAML default since 2026-07-29 — that meant a
# padded energy and an unpadded gradient, i.e. L-BFGS and Newton-CG descending
# one operator toward the minimum of a different one. The two kernels differ by
# the periodic-image field error that padding exists to remove (2-5 %).
#
# Nothing caught it: `test_ddi_padded.jl` never calls `energy_gradient!` or
# `apply_operator!`, and the FD term-consistency oracle builds its workspaces
# without DDI at all, let alone with padding.
#
# The gate is the finite-difference identity between the two faces,
#
#     (E(psi + eps*dpsi) - E(psi)) / eps  ==  Re<grad, dpsi> * dV
#
# run with padding ON. Two controls make a green result mean something:
#
#   * the same identity with padding OFF must also hold — otherwise a green
#     padded run could just mean the FD check is insensitive;
#   * the padded and unpadded gradients must DIFFER — otherwise the padded case
#     is vacuous at this size and the test proves nothing about padding.

function _ddi_ws(; padded::Bool)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        enable_ddi=true, c_dd=1.0,
        ddi_padding=padded, ddi_pad_factor=2,
        fft_flags=FFTW.ESTIMATE,
    )
end

function _seeded_state(ws, seed)
    rng = MersenneTwister(seed)
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    psi = randn(rng, ComplexF64, n_pts..., D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    psi
end

# (E(psi + eps*dpsi) - E(psi)) / eps  vs  Re<grad, dpsi> * dV, for the DDI term.
function _ddi_fd_vs_gradient(ws, psi, dpsi; ε=1.0e-7)
    dV = cell_volume(ws.grid)
    grad = similar(psi)
    fill!(grad, zero(eltype(grad)))
    apply_operator!(grad, DDITerm(), ws, psi)
    # `apply_operator!` returns dE/dpsi_bar, and the energy's first variation is
    # dE = 2 Re<dE/dpsi_bar, dpsi> — the Wirtinger factor of 2 that
    # `energy_gradient!` applies for its callers and that this raw face does not.
    # Dropping it made BOTH the padded case and the unpadded control fail, which
    # is the control earning its place: it said the comparison was broken rather
    # than letting a broken comparison indict the padded path.
    analytic = 2 * real(dot(grad, dpsi)) * dV

    e_plus = energy_contribution(DDITerm(), psi .+ ε .* dpsi, ws)
    e_zero = energy_contribution(DDITerm(), psi, ws)
    fd = (e_plus - e_zero) / ε
    (fd, analytic)
end

@testset "DDI gradient and energy use the same kernel under padding" begin
    ws_pad = _ddi_ws(padded=true)
    ws_bare = _ddi_ws(padded=false)
    @test ws_pad.ddi_padded !== nothing      # the padded path is really on
    @test ws_bare.ddi_padded === nothing

    psi = _seeded_state(ws_pad, 20260730)
    dpsi = _seeded_state(ws_pad, 20260731)

    @testset "canary: the two kernels actually differ here" begin
        # Without this, everything below could pass because padding happens to
        # be a no-op at this size — and the bug being gated would be invisible.
        g_pad = similar(psi)
        fill!(g_pad, zero(eltype(g_pad)))
        apply_operator!(g_pad, DDITerm(), ws_pad, psi)

        g_bare = similar(psi)
        fill!(g_bare, zero(eltype(g_bare)))
        apply_operator!(g_bare, DDITerm(), ws_bare, psi)

        rel = maximum(abs, g_pad .- g_bare) / maximum(abs, g_bare)
        @test rel > 1.0e-3
        @test all(isfinite, g_pad)
    end

    @testset "FD identity holds WITH padding" begin
        fd, analytic = _ddi_fd_vs_gradient(ws_pad, psi, dpsi)
        @test isapprox(fd, analytic; rtol=1.0e-4)
    end

    @testset "positive control: FD identity holds without padding" begin
        # If this failed, a green padded case would say nothing — it would mean
        # the FD comparison itself is not sensitive to the gradient.
        fd, analytic = _ddi_fd_vs_gradient(ws_bare, psi, dpsi)
        @test isapprox(fd, analytic; rtol=1.0e-4)
    end

    @testset "positive control: the FD check can fail" begin
        # Feed it the WRONG kernel's gradient on purpose — padded energy against
        # the bare gradient, which is exactly the defect this file gates. It must
        # be rejected, or the rtol above is too loose to detect it.
        dV = cell_volume(ws_pad.grid)
        g_bare = similar(psi)
        fill!(g_bare, zero(eltype(g_bare)))
        apply_operator!(g_bare, DDITerm(), ws_bare, psi)
        wrong = 2 * real(dot(g_bare, dpsi)) * dV

        ε = 1.0e-7
        fd =
            (
                energy_contribution(DDITerm(), psi .+ ε .* dpsi, ws_pad) -
                energy_contribution(DDITerm(), psi, ws_pad)
            ) / ε
        @test !isapprox(fd, wrong; rtol=1.0e-4)
    end
end
