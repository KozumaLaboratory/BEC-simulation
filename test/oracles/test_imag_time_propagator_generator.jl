# test/oracles/test_imag_time_propagator_generator.jl
#
# Generator-consistency oracle for the imaginary-time spin-rotation
# propagators (spin-mixing c1 + DDI). For a split-step substep
# `step(ψ; dt) = exp(∓dt·H)ψ` the small-dt generator must reproduce the
# registry operator `apply_operator!`:
#
#   imaginary time:  (ψ − step(ψ; dt)) / dt  →   H·ψ        ( = apply_operator! )
#   real time:       (ψ − step(ψ; dt)) / dt  →  i·H·ψ
#
# This gates the bug class found 2026-06-15: the imaginary-time Euler
# Stage-3 used a per-voxel exp(-(m+F)·θ) overflow shift; because θ ∝
# |f(r)| / |Φ(r)| is spatially varying, the spurious exp(-F·θ(r)) factor
# was a density reweighting (not removed by global normalization) that
# moved the ITP fixed point off the variational GP minimum. The real-time
# path was immune (same factor = irrelevant global phase), so an ITP-only
# or RTP-only check could not see it — only the propagator-vs-operator
# generator comparison does. It fills the gap left when the propagator↔
# energy strang-step parity gate was deleted 2026-06-06.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: SpinC1Term, DDITerm, apply_operator!, apply_spin_mixing_step!,
    apply_ddi_step!, make_workspace, cell_volume
using Random

# Textured F=6 (Eu) state: mostly stretched + transverse admixture so the
# spin density f(r) is non-uniform (the regime where the per-voxel shift bites).
function _gen_ws_and_state(; c1::Float64, enable_ddi::Bool, seed::Int=7)
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    interactions = InteractionParams(Dict(0 => 1.0, 1 => c1))
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws = make_workspace(;
        grid, atom=Eu151, interactions, zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=enable_ddi, c_dd=(enable_ddi ? 0.5 : NaN),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    Random.seed!(seed)
    psi = zeros(ComplexF64, 8, 8, 8, D)
    for k in 1:8, j in 1:8, i in 1:8
        g = exp(-0.08 * ((i - 4.5)^2 + (j - 4.5)^2 + (k - 4.5)^2))
        for c in 1:D
            amp = g * (c == D ? 1.0 : 0.3 / abs(D - c + 1))
            psi[i, j, k, c] = amp * cis(0.3 * sin(0.7c + 0.2i) + 0.2 * cos(0.5c + 0.3k))
        end
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    return ws, psi
end

# generator (ψ − step(ψ; dt)) / dt for an in-place propagator `step!`
function _generator(psi, step!; dt::Float64=1e-6)
    psi_after = copy(psi)
    step!(psi_after, dt)
    return (psi .- psi_after) ./ dt
end

_relerr(a, b) = sqrt(sum(abs2, a .- b)) / sqrt(sum(abs2, b))

@testset "imaginary-time propagator generator == registry operator" begin
    TOL = 1e-3   # FD generator is O(dt) accurate; dt=1e-6

    @testset "spin-mixing (c1)" begin
        ws, psi = _gen_ws_and_state(; c1=0.4, enable_ddi=false)
        g = zero(psi)
        apply_operator!(g, SpinC1Term(0.4), ws, psi)   # H·ψ

        G_imag = _generator(psi, (p, dt) ->
            apply_spin_mixing_step!(p, ws.spin_matrices, 0.4, dt, 3; imaginary_time=true))
        G_real = _generator(psi, (p, dt) ->
            apply_spin_mixing_step!(p, ws.spin_matrices, 0.4, dt, 3; imaginary_time=false))

        @test _relerr(G_imag, g) < TOL          # imag generator == H·ψ
        @test _relerr(G_real, im .* g) < TOL     # real generator == i·H·ψ
    end

    @testset "DDI" begin
        ws, psi = _gen_ws_and_state(; c1=0.0, enable_ddi=true)
        g = zero(psi)
        apply_operator!(g, DDITerm(), ws, psi)

        G_imag = _generator(psi, (p, dt) ->
            apply_ddi_step!(p, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, 3; imaginary_time=true))
        G_real = _generator(psi, (p, dt) ->
            apply_ddi_step!(p, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, 3; imaginary_time=false))

        @test _relerr(G_imag, g) < TOL
        @test _relerr(G_real, im .* g) < TOL
    end
end
