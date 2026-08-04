# Invariant 2, first half: no field reachable from `Model` is `Any`, a
# `Function`, or an abstract non-union type.
#
# The enumeration is `subtypes(ModelValue)` walked TRANSITIVELY through field
# types, array eltypes and dict key/value types — not `subtypes` alone.
# `subtypes(ModelValue)` returns 21 types; the transitive walk reaches 26, and
# the five it adds are exactly the ones carrying the layer's real hazards:
# `AtomSpecies`, `LossParams`, `AbsorbingBoundary`, `GaussianBeam` and
# `Dict{Int,Float64}`. A `subtypes`-only gate would assert "no Dict field" and
# pass while `AtomSpecies.scattering_lengths` sat one level down — the single
# hash-ordered field in the whole tree, and the reason `_enc_atom` exists.
#
# The rule is stated on the LEAVES, not on the fields. A field may be a tuple or
# a typed vector; what must be concrete (or a closed union of concretes) is what
# you reach by decomposing it. `HarmonicSpec.omega::NTuple{3, ModelWaveform}` is
# the case that forces the distinction: the tuple type is abstract, while each of
# its three leaves is the same two-member union the layer already accepts as a
# bare field. Union-splitting works per leaf, and the hazards invariant 2 names —
# `Any`, closures, open abstract types — are all leaf properties.

using Test
using InteractiveUtils: subtypes
using SpinorBEC
using SpinorBEC: Model, ModelValue, ModelWaveform, slots

probe_arms(T) = T isa Union ? collect(Base.uniontypes(T)) : Any[T]

const SCALAR_LEAF_KINDS = (Number, Symbol, AbstractString, AbstractChar, Nothing)

function walk_type!(T, path::String, bad::Vector{String}, seen::Set{Any})
    for A in probe_arms(T)
        if A === Any
            push!(bad, "$path :: Any")
            continue
        elseif A isa UnionAll
            push!(bad, "$path :: $A — a UnionAll, i.e. an unparameterised abstract field")
            continue
        elseif !(A isa DataType)
            push!(bad, "$path :: $A — not a DataType")
            continue
        elseif A <: Function
            push!(bad, "$path :: $A <: Function")
            continue
        end
        if A <: Tuple
            A === Tuple && (push!(bad, "$path :: Tuple — an open tuple type"); continue)
            for (i, ET) in enumerate(fieldtypes(A))
                walk_type!(ET, "$path[$i]", bad, seen)
            end
            continue
        end
        if !isconcretetype(A)
            push!(bad, "$path :: $A is abstract and not a union of concrete types")
            continue
        end
        A in seen && continue         # cycle guard, and it doubles as memoisation
        push!(seen, A)
        any(K -> A <: K, SCALAR_LEAF_KINDS) && continue
        if A <: AbstractArray
            walk_type!(eltype(A), "$path[]", bad, seen)
        elseif A <: AbstractDict
            walk_type!(keytype(A), "$path{key}", bad, seen)
            walk_type!(valtype(A), "$path{value}", bad, seen)
        else
            for (n, FT) in zip(fieldnames(A), fieldtypes(A))
                walk_type!(FT, "$path.$n", bad, seen)
            end
        end
    end
    nothing
end

@testset "Model shape (invariant 2)" begin
    roots = unique(Any[Model, subtypes(ModelValue)...])

    @testset "the enumeration is not empty and not hand-listed" begin
        # `Model in roots` was here and could not fail: `roots` puts it in
        # unconditionally. What IS breakable, and is the actual claim, is that
        # every spec slot arrives through `subtypes(ModelValue)` rather than by
        # being named here — drop `<: ModelValue` from any spec and this reddens.
        # `atom` and `loss` are reused foundation types and are exactly why the
        # walk below has to be transitive.
        unreached = [
            f for f in slots(Model)
                  if !(f in (:atom, :loss)) && !(fieldtype(Model, f) in roots)
        ]
        isempty(unreached) ||
            println("slots not collected by subtypes(ModelValue): ", unreached)
        @test isempty(unreached)
        # 20 specs + Model today. A drop below the spec count would mean the
        # abstract supertype stopped collecting them, which silently empties the
        # gate rather than failing it.
        @test length(subtypes(ModelValue)) >= 15
        # No type parameters. Asserted in two steps because `Model.parameters`
        # THROWS a FieldError on a `Model{B}` — it would have errored the suite
        # instead of reporting a verdict, and an erroring gate is one nobody can
        # read the result of.
        @test Model isa DataType
        @test isempty(Base.unwrap_unionall(Model).parameters)
    end

    bad = String[]
    seen = Set{Any}()
    for R in roots
        walk_type!(R, string(nameof(R)), bad, seen)
    end

    @testset "no Any / Function / abstract non-union leaf" begin
        isempty(bad) || println("shape violations:\n  " * join(bad, "\n  "))
        @test isempty(bad)
    end

    @testset "the walk is transitive, not subtypes-only" begin
        # Positive control on COVERAGE. Without these the gate would still be
        # green while never having looked at the five reused foundation types.
        # `subtypes(ModelValue)` reaches none of them.
        st = Set{Any}(subtypes(ModelValue))
        for T in (SpinorBEC.AtomSpecies, SpinorBEC.LossParams,
            SpinorBEC.AbsorbingBoundary, SpinorBEC.GaussianBeam, Dict{Int, Float64})
            @test T in seen
            @test !(T in st)
        end
        @test length(seen) > length(st)
    end

    @testset "ModelWaveform is a closed union of concrete types" begin
        # Why the tuple-of-union leaves are admissible: every arm is concrete,
        # immutable and closure-free, so union-splitting applies per leaf and no
        # `Function` field can enter a Model through a waveform.
        arms = Base.uniontypes(ModelWaveform)
        @test length(arms) == 2
        @test all(isconcretetype, arms)
        @test !any(A -> A <: Function, arms)
        @test Float64 in arms
    end
end
