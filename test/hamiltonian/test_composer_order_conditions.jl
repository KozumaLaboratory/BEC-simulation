# test/hamiltonian/test_composer_order_conditions.jl
#
# The order of a splitting composer is a property of its COEFFICIENTS. It is
# verified here against an exactly-solvable stand-in for the split the
# propagator actually performs — kinetic (diagonal in k) plus a multiplicative
# potential (diagonal in x), as 8×8 matrices whose exact answer is
# `exp((K + V)·T)`. No grid, no Workspace, no FFT plan, no spinor. Milliseconds.
#
# Why at this layer. `test/solvers/test_yoshida_ddi_order.jl` measures the same
# order by running sixteen Eu F=6 (D=13) 6³ split-step simulations with DDI, at
# four dt levels, in the `full` tier — ~14 s, not on the PR gate, and a red
# result says only "the order collapsed somewhere in the stack". The claims
# separate cleanly:
#
#   here  — the COMPOSER has the order it claims.                       (L0)
#   L1    — each substep is a faithful exp(·dt), including for dt < 0.
#           `test/oracles/test_negative_dt_substeps.jl`.
#   L3    — the full spinor stack realises that order with real operators.
#           Worth one cell, not sixteen.
#
# That decomposition is not theoretical: the 2026-07-29 regression was an L1
# defect (a substep that no-oped for dt < 0), and the only thing that saw it was
# the 14 s L3 test.
#
# The stand-in is 8×8 and spectral rather than a pair of arbitrary matrices
# because the composers are RKN-type: their extra order conditions are bought
# with the structure [V,[V,[V,K]]] = 0, which a generic pair does not have.
# Testing a structure-exploiting method on a structure-free example measures the
# wrong thing. (Checked both ways here: the orders below are the same on a
# generic non-commuting pair and on an exactly-RKN classical pair.)

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC:
    _COMP_YOSHIDA, _COMP_SUZUKI, _COMP_BLANES_MOAN_SRKN6B,
    _COMP_OMELYAN_PEFRL, _COMP_YOSHIDA_S6

const _N = 8
const _L = 4.0

# K = F† diag(k²/2) F and V = diag(v(x)): the same two operators split_step!
# alternates between, small enough to exponentiate densely.
const _K, _V = let n = _N, L = _L
    dx = L / n
    x = [-L / 2 + (j - 1) * dx for j in 1:n]
    k = [2π * (j - 1 <= n ÷ 2 ? j - 1 : j - 1 - n) / L for j in 1:n]
    F = [cis(-2π * (a - 1) * (b - 1) / n) / sqrt(n) for a in 1:n, b in 1:n]
    (-im .* Matrix(F' * Diagonal(0.5 .* k .^ 2) * F),
        -im .* Matrix(Diagonal(0.7 .* x .^ 2 .+ 0.3 .* x)))
end

"""ABA product: `a` interleaves with `b`, one more `a` than `b`."""
function _compose(comp, dt::Float64)
    a, b = comp.a, comp.b
    M = exp(a[1] * dt * _K)
    for i in eachindex(b)
        M = exp(a[i + 1] * dt * _K) * exp(b[i] * dt * _V) * M
    end
    M
end

"""Global order over a FIXED total time — the order a user of the integrator
experiences. (One-step error slopes are p+1 and are easy to misread.)"""
function _global_order(comp; T::Float64=0.5, dt0::Float64=0.05)
    errs = map(0:2) do j
        dt = dt0 / 2^j
        opnorm(_compose(comp, dt)^round(Int, T / dt) - exp(T * (_K + _V)))
    end
    (log2(errs[1] / errs[2]), log2(errs[2] / errs[3]))
end

# ORDER, not stage count. `_COMP_BLANES_MOAN_SRKN6B` is Blanes & Moan's SRKN₆ᵇ,
# where the 6 counts STAGES: it is a 6-stage, FOURTH-order method. Measured
# here at 4.00 both on this spectral pair and on a pair satisfying
# [B,[B,[B,A]]] = 0 exactly, so it is not a structure artefact. The name and the
# source comment ("Blanes-Moan S6 is the default 6th") read it as sixth order;
# `_COMP_YOSHIDA_S6` is the one that genuinely is.
const _COMPOSERS = [
    (:yoshida4, _COMP_YOSHIDA, 4),
    (:suzuki4, _COMP_SUZUKI, 4),
    (:omelyan_pefrl, _COMP_OMELYAN_PEFRL, 4),
    (:blanes_moan_srkn6b, _COMP_BLANES_MOAN_SRKN6B, 4),
    (:yoshida6, _COMP_YOSHIDA_S6, 6),
]

@testset "split-step composer order conditions" begin
    @testset "consistency and symmetry — $name" for (name, comp, _p) in _COMPOSERS
        # Σa = Σb = 1 is necessary for ANY order: without it the composer does
        # not advance time by dt at all.
        @test sum(comp.a)≈1.0 atol=1e-12
        @test sum(comp.b)≈1.0 atol=1e-12
        @test length(comp.a) == length(comp.b) + 1
        # Palindromic ⇒ self-adjoint ⇒ even order. This is what cancels the
        # 3rd-order term, and it is why `_YOSHIDA_W0 < 0` must not be "fixed"
        # to a positive value.
        @test collect(comp.a) ≈ reverse(collect(comp.a))
        @test collect(comp.b) ≈ reverse(collect(comp.b))
    end

    @testset "measured global order — $name" for (name, comp, p) in _COMPOSERS
        r1, r2 = _global_order(comp)
        # Bounds are ±0.4 around the claimed order: dropping to the next even
        # order down lands at p − 2, five times outside this window. The window
        # is the slope's own asymptotic error, not a fitted tolerance.
        @test abs(r1 - p) < 0.4
        @test abs(r2 - p) < 0.4
    end

    @testset "Yoshida-4 triple jump" begin
        # The middle substep runs BACKWARD in time, and that is the mechanism,
        # not an accident: Σw = 1 with Σw³ = 0 has no all-positive solution.
        w = collect(_COMP_YOSHIDA.b)
        @test w[2] < 0
        @test sum(w)≈1.0 atol=1e-12
        @test sum(w .^ 3)≈0.0 atol=1e-12
    end
end
