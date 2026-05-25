# --- Validation typed-view structs ---
#
# Four immutable structs that frame the validation domain:
#
#   * DynamicsTimeSeries — `dynamics/{times,norms,energies,Fz,Lz}` arrays
#     pulled out of a result.jld2 / point_001.jld2 file. Optional Lz
#     because not every run saves it; downstream code computes lazily
#     from `psi` snapshots when needed.
#
#   * RunResult — single converged run, loaded from disk. Wraps the
#     final ψ, grid/atom/interactions metadata, dynamics history,
#     per-term energy decomposition, and the raw env metadata. The
#     Phase-1 `Base.getproperty` overload (next phase) will surface
#     observables (`r.norm`, `r.Fz_drift`, ...) on top of these fields.
#
#   * RunSweep — collection of RunResults that share a parametric axis
#     (typical: `:grid => [24, 32, 48]`). The `varying` Pair documents
#     which knob differs across runs so downstream tabulation can label
#     rows correctly.
#
#   * RunComparison — paired view of two RunResults. Labels distinguish
#     the two sides (`"pre-fix" vs "post-fix"`, `"ours" vs "theirs"`)
#     so the verdict report can identify which side a drift attaches
#     to.
#
# All four are plain `struct` (immutable) — they're typed views, not
# mutable accumulators. Lazy / derived fields live on the operations
# layer (Phase 1+).

export DynamicsTimeSeries, RunResult, RunSweep, RunComparison

"""
    DynamicsTimeSeries(times, norms, energies, Fz; Lz=nothing)

Time series block extracted from `dynamics/*` keys of a result jld2.
`Lz` is `nothing` when the underlying run did not save orbital angular
momentum; in that case the Phase-1 observable layer recomputes it from
saved ψ snapshots on demand.

Fields:
* `times`     — Vector{Float64}, dimensionless time grid (t·ω_ref)
* `norms`     — Vector{Float64}, ∫|ψ(t)|² dV
* `energies`  — Vector{Float64}, ⟨H(t)⟩
* `Fz`        — Vector{Float64}, ⟨F_z(t)⟩ (integrated magnetization)
* `Lz`        — Vector{Float64} or nothing, ⟨L_z(t)⟩ when saved
"""
struct DynamicsTimeSeries
    times::Vector{Float64}
    norms::Vector{Float64}
    energies::Vector{Float64}
    Fz::Vector{Float64}
    Lz::Union{Vector{Float64}, Nothing}

    function DynamicsTimeSeries(
        times::AbstractVector,
        norms::AbstractVector,
        energies::AbstractVector,
        Fz::AbstractVector;
        Lz::Union{AbstractVector, Nothing}=nothing,
    )
        n = length(times)
        length(norms) == n || throw(ArgumentError(
            "norms length $(length(norms)) ≠ times length $n"))
        length(energies) == n || throw(ArgumentError(
            "energies length $(length(energies)) ≠ times length $n"))
        length(Fz) == n || throw(ArgumentError(
            "Fz length $(length(Fz)) ≠ times length $n"))
        Lz === nothing || length(Lz) == n ||
            throw(ArgumentError(
                "Lz length $(length(Lz)) ≠ times length $n"))
        new(
            collect(Float64, times),
            collect(Float64, norms),
            collect(Float64, energies),
            collect(Float64, Fz),
            Lz === nothing ? nothing : collect(Float64, Lz),
        )
    end
end

"""
    RunResult(path, psi, grid, atom, interactions;
              dynamics=nothing, e_decomp=Dict(), metadata=Dict())

Typed view of a single jld2 run artifact. Constructed by
`open_result(path)` in Phase 1; for now the struct definition only
captures the field layout and run-time invariants.

Fields:
* `path`         — source jld2 path (for traceability + error messages)
* `psi`          — final wavefunction, shape `(n_pts..., D)` with `D = 2F+1`
* `grid`         — `Grid` value matching `psi`'s spatial dims
* `atom`         — `AtomSpecies` value
* `interactions` — `InteractionParams` value (Dict-form post-refactor)
* `dynamics`     — `DynamicsTimeSeries` or `nothing` (no dynamics step)
* `e_decomp`     — per-term final-state energy Dict (`"kinetic"`, ...,
                   `"total"`); empty Dict when not exported
* `metadata`     — free-form Dict for env/git_hash/conventions/etc.
"""
struct RunResult{N, D}
    path::String
    psi::Array{ComplexF64, N}                       # spatial dims + spinor (so N = ndim+1)
    hpsi::Union{Array{ComplexF64, N}, Nothing}      # operator-RHS, when exported
    grid::Grid{D}                                   # D = spatial dims (= N-1)
    atom::AtomSpecies
    interactions::InteractionParams
    dynamics::Union{DynamicsTimeSeries, Nothing}
    e_decomp::Dict{String, Float64}
    metadata::Dict{String, Any}

    function RunResult(
        path::AbstractString,
        psi::AbstractArray{<:Complex, N},
        grid::Grid{D},
        atom::AtomSpecies,
        interactions::InteractionParams;
        hpsi::Union{AbstractArray{<:Complex, N}, Nothing}=nothing,
        dynamics::Union{DynamicsTimeSeries, Nothing}=nothing,
        e_decomp::Dict{String, Float64}=Dict{String, Float64}(),
        metadata::Dict{String, Any}=Dict{String, Any}(),
    ) where {N, D}
        N == D + 1 || throw(
            ArgumentError(
                "psi rank $N must equal grid ndim $D + 1 (spatial + spinor)"),
        )
        spinor_dim = size(psi, N)
        spinor_dim == 2 * atom.F + 1 || throw(
            ArgumentError(
                "ψ last-axis size $spinor_dim ≠ 2F+1 = $(2 * atom.F + 1)"),
        )
        hpsi !== nothing && size(hpsi) != size(psi) &&
            throw(
                ArgumentError(
                    "Hψ shape $(size(hpsi)) ≠ ψ shape $(size(psi))"),
            )
        new{N, D}(
            String(path),
            convert(Array{ComplexF64, N}, psi),
            hpsi === nothing ? nothing : convert(Array{ComplexF64, N}, hpsi),
            grid, atom, interactions,
            dynamics, e_decomp, metadata,
        )
    end
end

"""
    RunSweep(runs::Vector{<:RunResult}, varying::Pair{Symbol,<:Vector})

A collection of `RunResult`s that share a parametric axis (e.g.
`:grid => [24, 32, 48]`). `length(runs) == length(varying.second)` is
enforced so each run pairs with one knob value.

Fields:
* `runs`    — Vector of RunResults, indexed by parameter position
* `varying` — `:knob => [values...]` describing which parameter differs

Examples (Phase-2 usage):
```julia
sweep = sweep_runs("config.yaml"; vary = :grid => [24, 32, 48])
sweep.runs[2].grid.config.n_points   # (32, 32, 32)
sweep.varying.first                  # :grid
```
"""
struct RunSweep
    runs::Vector{RunResult}
    varying::Pair{Symbol, Vector}

    function RunSweep(runs::AbstractVector{<:RunResult}, varying::Pair{Symbol, <:Vector})
        length(runs) == length(varying.second) || throw(
            ArgumentError(
                "RunSweep: runs length $(length(runs)) ≠ varying values length $(length(varying.second))"
            ),
        )
        new(collect(RunResult, runs), Pair(varying.first, collect(Any, varying.second)))
    end
end

"""
    RunComparison(a::RunResult, b::RunResult; label_a="A", label_b="B")

Paired view of two RunResults for direct A/B diff. Labels distinguish
the sides in downstream verdicts (`"pre-fix" vs "post-fix"`, `"ours"
vs "theirs"`).

Fields:
* `a`        — first RunResult
* `b`        — second RunResult
* `label_a`  — human-readable label for `a` (used in CheckResult.details)
* `label_b`  — same for `b`
"""
struct RunComparison
    a::RunResult
    b::RunResult
    label_a::String
    label_b::String

    function RunComparison(
        a::RunResult, b::RunResult;
        label_a::AbstractString="A",
        label_b::AbstractString="B",
    )
        new(a, b, String(label_a), String(label_b))
    end
end
