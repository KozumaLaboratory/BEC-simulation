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

using Test
using SpinorBEC

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
