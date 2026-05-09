export GaussianBeam, CrossedDipoleTrap

struct GaussianBeam
    wavelength::Float64     # m
    power::Float64          # W
    waist::Float64          # m (1/e² radius)
    position::NTuple{3, Float64}   # m (focus position)
    direction::NTuple{3, Float64}  # unit vector (propagation axis)
end

struct CrossedDipoleTrap{N} <: AbstractPotential
    beams::Vector{GaussianBeam}
    polarizability::Float64  # J/(W/m²), scalar polarizability α
end

CrossedDipoleTrap(beams, pol; dims::Int=3) = CrossedDipoleTrap{dims}(beams, pol)

function evaluate_potential(trap::CrossedDipoleTrap{N}, grid::Grid{N, T}) where {N, T}
    V = zeros(T, grid.config.n_points)
    for beam in trap.beams
        _add_beam_potential!(V, beam, grid, trap.polarizability)
    end
    V
end

function _add_beam_potential!(
    V::AbstractArray{T, N},
    beam::GaussianBeam,
    grid::Grid{N, T},
    alpha::Float64,
) where {N, T <: AbstractFloat}
    w0 = T(beam.waist)
    P = T(beam.power)
    I0 = T(2) * P / (T(π) * w0^2)

    d = ntuple(i -> T(beam.direction[i]), 3)
    pos = ntuple(i -> T(beam.position[i]), 3)
    alpha_t = T(alpha)

    @inbounds for I in CartesianIndices(size(V))
        coords = ntuple(N) do dim
            grid.x[dim][I[dim]] - pos[dim]
        end

        axial = sum(ntuple(dim -> coords[dim] * d[dim], N))
        r_perp_sq = sum(ntuple(dim -> coords[dim]^2, N)) - axial^2

        intensity = I0 * exp(-T(2) * r_perp_sq / w0^2)
        V[I] += -alpha_t * intensity
    end
    nothing
end
