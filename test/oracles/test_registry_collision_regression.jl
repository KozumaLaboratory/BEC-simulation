# test/oracles/test_registry_collision_regression.jl
#
# Regression gate for the HamTerm name-shadowing bug closed 2026-06-04.
#
# Before the rename to *Term suffix, `MagneticGradient <: HamTerm`
# (empty struct) shadowed `MagneticGradient{N} <: AbstractPotential`
# (workflow potential type), and `LightShift <: HamTerm` shadowed
# `LightShift{A}` (workspace field type). Both production constructors
# raised TypeError / MethodError after `using SpinorBEC`. This file
# locks the unshadowed access in place.
#
# Two layers:
#
#   (A) Explicit smoke list: every load-bearing user-facing ctor that
#       could plausibly be shadowed by a future HamTerm with a similar
#       name. Each call asserts the result is the expected non-HamTerm
#       type. If a regression shadows one of these, the failure is
#       loud and immediate.
#
#   (B) Meta-rule: every concrete `<: HamTerm` subtype in SpinorBEC
#       MUST end with the `Term` suffix. This is the GENERATIVE rule
#       that catches the NEXT shadowing bug class before someone adds
#       `struct Foo <: HamTerm end` next to an existing `Foo`-named
#       potential / parameter type.

using Test
using LinearAlgebra
using SpinorBEC
using InteractiveUtils: subtypes

@testset "HamTerm renames do not shadow potential types" begin
    @testset "MagneticGradient{N} still constructible" begin
        # Was broken: TypeError, in Type{...} expression, expected UnionAll, got Type{MagneticGradient}
        mg = MagneticGradient{3}(0.5, 1, 1.0)
        @test mg isa SpinorBEC.AbstractPotential
        @test mg.gradient == 0.5
        @test mg.axis == 1
        @test mg.g_F == 1.0
    end

    @testset "MagneticGradient(; kwargs) still constructible" begin
        mg = MagneticGradient(; gradient=0.3, axis=2, g_F=1.5, ndim=3)
        @test mg isa MagneticGradient{3}
        @test mg.gradient == 0.3
    end

    @testset "LightShift{A} still constructible" begin
        # Was broken: MethodError matched only the empty `LightShift()`
        profile = rand(8, 8, 8)
        eigvals = [-1.0, 0.0, 1.0]
        U = Matrix{ComplexF64}(I, 3, 3)
        ls = LightShift(profile, eigvals, U, true)
        @test ls isa LightShift
        @test ls.is_diagonal == true
    end

    @testset "MagneticGradientTerm HamTerm coexists" begin
        # Renamed term-type is a separate symbol.
        t = SpinorBEC.MagneticGradientTerm()
        @test t isa SpinorBEC.HamTerm
        @test supertype(typeof(t)) === SpinorBEC.HamTerm
    end

    @testset "LightShiftTerm HamTerm coexists" begin
        t = SpinorBEC.LightShiftTerm()
        @test t isa SpinorBEC.HamTerm
    end
end

# ============================================================================
# (A) Extended smoke list — user-facing ctors that future HamTerm names
# could plausibly shadow. Each was a real concern after the 2026-06-04
# audit; locking them here prevents regression in either direction.
# ============================================================================

@testset "User-facing ctors not shadowed by HamTerm subtypes" begin
    @testset "Potentials" begin
        @test HarmonicTrap((1.0, 1.0, 1.0)) isa SpinorBEC.AbstractPotential
        @test BoxPotential((10.0, 10.0); wall_strength=1000.0, wall_width=0.5) isa
            SpinorBEC.AbstractPotential
        @test RingPotential{2}(5.0, 50.0, 1.0) isa SpinorBEC.AbstractPotential
        @test DoubleWellPotential(; separation=4.0, barrier=10.0, omega=(1.0,), axis=1) isa
            SpinorBEC.AbstractPotential
        @test MagneticGradient{3}(0.5, 1, 1.0) isa SpinorBEC.AbstractPotential
        @test MagneticGradient(; gradient=0.3, axis=2, g_F=1.5, ndim=3) isa MagneticGradient{3}
    end

    @testset "LHY family" begin
        @test ScalarLHY(0.5) isa SpinorBEC.AbstractLHY
        @test Quasi2DLHY(0.3, 1.0, 0.0) isa SpinorBEC.AbstractLHY
        @test NoLHY() isa SpinorBEC.AbstractLHY
    end

    @testset "DDI / Loss / LightShift parameter types" begin
        @test DDIParams(1.0, zeros(3, 3, 3), zeros(3, 3, 3), zeros(3, 3, 3),
            zeros(3, 3, 3), zeros(3, 3, 3), zeros(3, 3, 3),
            (12.0, 12.0, 12.0)) isa DDIParams
        @test LossParams(0.0, 0.0, [0.0, 0.0, 0.0], 0.0, [0.0, 0.0, 0.0], 0.0, 0.0) isa LossParams
        # LightShift positional 4-arg ctor — was broken by HamTerm shadow
        profile = rand(8, 8, 8)
        eigvals = [-1.0, 0.0, 1.0]
        U = Matrix{ComplexF64}(I, 3, 3)
        @test LightShift(profile, eigvals, U, true) isa LightShift
    end

    @testset "Zeeman / Interactions / Sim" begin
        @test ZeemanParams(0.5, 0.2) isa ZeemanParams
        @test TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
            ConstantWaveform(0.3), ConstantWaveform(0.0)) isa TimeDependentZeeman
        @test InteractionParams(Dict(0 => 1.0, 1 => 0.1)) isa InteractionParams
        @test SimParams(; dt=0.01, n_steps=10) isa SimParams
        @test RamanCoupling{1}(0.3, 0.05, (0.5,)) isa RamanCoupling{1}
    end

    @testset "Grid / SpinSystem" begin
        @test GridConfig{1}((16,), (8.0,)) isa GridConfig
        @test SpinSystem(1) isa SpinSystem
        @test SpinSystem(6) isa SpinSystem
    end
end

# ============================================================================
# (B) Generative rule — every concrete HamTerm subtype must use the
# `Term` suffix. Catches the NEXT class of shadow bug at the source:
# if someone adds `struct Foo <: HamTerm end` alongside an existing
# `Foo` parameter type, this test fires before the shadow can land.
# ============================================================================

@testset "Naming rule: every HamTerm subtype has `Term` suffix" begin
    bad_names = String[]
    for T in subtypes(SpinorBEC.HamTerm)
        name = string(nameof(T))
        endswith(name, "Term") || push!(bad_names, name)
    end
    if !isempty(bad_names)
        @info "HamTerm subtypes missing `Term` suffix" bad_names
    end
    @test isempty(bad_names)
end
