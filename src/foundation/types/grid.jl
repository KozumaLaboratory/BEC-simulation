# --- Grid + Backend types ---
#
# Most foundational types: the AbstractBackend tag (CPU vs CUDA), the
# GridConfig record (n_points + box_size), and the resolved Grid struct
# carrying axis arrays + k-space buffers. Workspace and every solver
# step depend on these.

export AbstractBackend, GridConfig, Grid

abstract type AbstractBackend end

# --- Grid Configuration ---

struct GridConfig{N}
    n_points::NTuple{N, Int}
    box_size::NTuple{N, Float64}

    function GridConfig{N}(n_points::NTuple{N, Int}, box_size::NTuple{N, Float64}) where {N}
        all(n -> n > 0 && iseven(n), n_points) ||
            throw(ArgumentError("n_points must be positive even integers"))
        all(L -> L > 0, box_size) || throw(ArgumentError("box_size must be positive"))
        new{N}(n_points, box_size)
    end
end

GridConfig(n_points::NTuple{N, Int}, box_size::NTuple{N, Float64}) where {N} = GridConfig{N}(
    n_points, box_size
)
GridConfig(n_points::Int, box_size::Float64) = GridConfig{1}((n_points,), (box_size,))

spatial_dims(::GridConfig{N}) where {N} = N

# --- Spatial Grid ---

struct Grid{N, T <: AbstractFloat}
    config::GridConfig{N}
    x::NTuple{N, Vector{T}}
    dx::NTuple{N, T}
    k::NTuple{N, Vector{T}}
    dk::NTuple{N, T}
    k_squared::Array{T, N}
end

# Partial-application alias for the common Float64 case. Most call sites
# write `Grid{N}` or `grid::Grid{N}` — with this alias those continue to
# resolve to the concrete `Grid{N,Float64}`, so the precision-parameter
# rollout is backward compatible.
const GridF64{N} = Grid{N, Float64}
