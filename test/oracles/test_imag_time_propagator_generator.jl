# test/oracles/test_imag_time_propagator_generator.jl
#
# Generator-consistency oracle for the imaginary-time propagators of the
# spin-rotation / diagonal-shift family (spin-mixing c1, DDI, uniform Zeeman,
# spatial Zeeman). For a split-step substep `step(ψ; dt) = exp(∓dt·H)ψ` the
# small-dt generator must reproduce the registry operator `apply_operator!`:
#
#   imaginary time:  (ψ − step(ψ; dt)) / dt  →   H·ψ        ( = apply_operator! )
#   real time:       (ψ − step(ψ; dt)) / dt  →  i·H·ψ
#
# ...MODULO a global scalar multiple of ψ. An imaginary-time propagator may
# subtract a constant overflow shift `exp(-dt(H − c·I))` = `exp(c·dt)·exp(-dt·H)`;
# the global scalar `exp(c·dt)` is removed by per-step normalization, so it is
# physically harmless and appears in the raw generator as `c·ψ`. We therefore
# compare the generators after projecting out the ψ-component.
#
# The bug this gates (2026-06-15): the imaginary-time Euler Stage-3 used a
# PER-VOXEL `exp(-(m+F)·θ)` shift with θ ∝ |f(r)| / |Φ(r)| / |B(r)|. A
# per-voxel `c(r)·ψ` is NOT a global scalar multiple of ψ — projection cannot
# absorb it — so it survives normalization and biases the ITP fixed point.
# Found in spin-mixing + DDI (euler_batched / euler_per_voxel / rotation.jl
# GPU) and in spatial-Zeeman diagonal/q steps. Fills the gap left when the
# propagator↔energy strang-step parity gate was deleted 2026-06-06.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: SpinC1Term, DDITerm, ZeemanTerm, SpatialZeemanTerm,
    apply_operator!, apply_step!, build_h_terms_registry, make_workspace,
    cell_volume, zeeman_field
using LinearAlgebra
using Random

# Textured F=6 state: mostly stretched + transverse admixture so the spin
# density f(r) is non-uniform (the regime where a per-voxel shift bites).
function _textured_state(ws)
    D = ws.spin_matrices.system.n_components
    Random.seed!(7)
    psi = zeros(ComplexF64, 8, 8, 8, D)
    for k in 1:8, j in 1:8, i in 1:8
        g = exp(-0.08 * ((i - 4.5)^2 + (j - 4.5)^2 + (k - 4.5)^2))
        for c in 1:D
            amp = g * (c == D ? 1.0 : 0.3 / abs(D - c + 1))
            psi[i, j, k, c] = amp * cis(0.3 * sin(0.7c + 0.2i) + 0.2 * cos(0.5c + 0.3k))
        end
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    return psi
end

# residual of (G − target) after removing its (complex) ψ-component — a
# global scalar·ψ overflow/phase shift is harmless and projected out; a
# per-voxel or operator-shape mismatch is not.
function _residual_mod_psi(G, target, psi)
    diff = G .- target
    c = dot(vec(psi), vec(diff)) / dot(vec(psi), vec(psi))
    perp = diff .- c .* psi
    return sqrt(sum(abs2, perp)) / sqrt(sum(abs2, target))
end

# (ψ − step!(ψ; dt)) / dt for an in-place propagator
function _generator(psi, step!; dt::Float64=1e-6)
    p = copy(psi); step!(p, dt); return (psi .- p) ./ dt
end

# pull the live term from the registry (correct construction from ws)
function _term_of(::Type{T}, ws) where {T}
    for t in build_h_terms_registry(ws)
        t isa T && return t
    end
    error("no $T active in registry")
end

function _check(::Type{T}, ws, psi; tol=1e-3) where {T}
    term = _term_of(T, ws)
    g = zero(psi); apply_operator!(g, term, ws, psi)
    Gi = _generator(psi, (p, dt) -> apply_step!(term, p, dt, true, ws))
    Gr = _generator(psi, (p, dt) -> apply_step!(term, p, dt, false, ws))
    @test _residual_mod_psi(Gi, g, psi) < tol         # imag generator == H·ψ (mod ψ)
    @test _residual_mod_psi(Gr, im .* g, psi) < tol   # real generator == i·H·ψ (mod ψ)
end

@testset "imaginary-time propagator generator == registry operator (mod ψ)" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))

    @testset "spin-mixing c1" begin
        ws = make_workspace(; grid, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.4)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            enable_ddi=false, fft_flags=FFTW.ESTIMATE)
        _check(SpinC1Term, ws, _textured_state(ws))
    end

    @testset "DDI" begin
        ws = make_workspace(; grid, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            enable_ddi=true, c_dd=0.5, fft_flags=FFTW.ESTIMATE)
        _check(DDITerm, ws, _textured_state(ws))
    end

    @testset "uniform Zeeman (p + q): harmless global shift is projected out" begin
        ws = make_workspace(; grid, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.7, 0.2), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            enable_ddi=false, fft_flags=FFTW.ESTIMATE)
        _check(ZeemanTerm, ws, _textured_state(ws))
    end

    @testset "spatial Zeeman B(r): per-voxel shift must NOT bias density" begin
        # spatially-varying bz(r) + q(r): the regime where a per-voxel overflow
        # shift would survive normalization and bias ψ. Post-fix the shift is a
        # global constant, so the generator matches the operator (mod ψ).
        zf = zeeman_field(grid; bz=(x, y, z) -> 0.5 + 0.2 * x, q=(x, y, z) -> 0.1 + 0.05 * y)
        ws = make_workspace(; grid, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=zf, potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            enable_ddi=false, fft_flags=FFTW.ESTIMATE)
        _check(SpatialZeemanTerm, ws, _textured_state(ws))
    end
end
