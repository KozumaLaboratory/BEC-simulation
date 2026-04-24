"""
Laser beam dipole trap potential using the full Gaussian beam model
(includes Rayleigh length and beam divergence along propagation axis).

V(r) = -α × I(r) where I accounts for w(z) = w₀√(1 + (z/z_R)²).
"""
struct LaserBeamPotential{N} <: AbstractPotential
    beam::OpticalBeam
    polarizability::Float64
    position::NTuple{N,Float64}
    direction::NTuple{N,Float64}

    function LaserBeamPotential{N}(
        beam::OpticalBeam,
        polarizability::Float64,
        position::NTuple{N,Float64},
        direction::NTuple{N,Float64},
    ) where {N}
        d_norm = sqrt(sum(d^2 for d in direction))
        dir_normalized = ntuple(i -> direction[i] / d_norm, N)
        new{N}(beam, polarizability, position, dir_normalized)
    end
end

function LaserBeamPotential(
    beam::OpticalBeam,
    polarizability::Float64,
    position::NTuple{N,Float64},
    direction::NTuple{N,Float64},
) where {N}
    LaserBeamPotential{N}(beam, polarizability, position, direction)
end

function evaluate_potential(lp::LaserBeamPotential{N}, grid::Grid{N,T}) where {N,T<:AbstractFloat}
    V = zeros(T, grid.config.n_points)
    w0 = T(waist_radius(lp.beam))
    z_R = T(rayleigh_length(lp.beam))
    I0 = T(2) * T(lp.beam.power) / (T(π) * w0^2)
    alpha_t = T(lp.polarizability)
    pos = ntuple(i -> T(lp.position[i]), N)
    dir = ntuple(i -> T(lp.direction[i]), N)

    @inbounds for I in CartesianIndices(size(V))
        coords = ntuple(N) do dim
            grid.x[dim][I[dim]] - pos[dim]
        end

        axial = sum(ntuple(dim -> coords[dim] * dir[dim], N))
        r_perp_sq = sum(ntuple(dim -> coords[dim]^2, N)) - axial^2

        wz_sq = w0^2 * (one(T) + (axial / z_R)^2)
        intensity = I0 * (w0^2 / wz_sq) * exp(-T(2) * r_perp_sq / wz_sq)
        V[I] = -alpha_t * intensity
    end
    V
end

"""
Create a crossed dipole trap from multiple LaserBeamPotentials.
"""
function crossed_laser_trap(beams::Vector{LaserBeamPotential{N}}) where {N}
    CompositePotential{N}(AbstractPotential[b for b in beams])
end
