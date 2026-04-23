function evaluate_potential(::NoPotential, grid::Grid{N}) where {N}
    zeros(Float64, grid.config.n_points)
end

function evaluate_potential(trap::HarmonicTrap{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d = 1:N
            s += trap.omega[d]^2 * grid.x[d][I[d]]^2
        end
        V[I] = 0.5 * s
    end
    V
end

function evaluate_potential(grav::GravityPotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    ax = grav.axis
    @inbounds for I in CartesianIndices(grid.config.n_points)
        V[I] = grav.g * grid.x[ax][I[ax]]
    end
    V
end

function evaluate_potential(comp::CompositePotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    for pot in comp.components
        V .+= evaluate_potential(pot, grid)
    end
    V
end

function evaluate_potential(ring::RingPotential{N}, grid::Grid{N}) where {N}
    N >= 2 || throw(ArgumentError("RingPotential requires N >= 2"))
    V = zeros(Float64, grid.config.n_points)
    inv_2w2 = 1.0 / (2.0 * ring.width^2)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r = sqrt(grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2)
        V[I] = ring.strength * exp(-(r - ring.radius)^2 * inv_2w2)
    end
    V
end

function evaluate_potential(box::BoxPotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    half = ntuple(d -> box.size[d] / 2, N)
    inv_w = 1.0 / box.wall_width
    @inbounds for I in CartesianIndices(grid.config.n_points)
        wall = 0.0
        for d in 1:N
            dist = abs(grid.x[d][I[d]]) - half[d]
            if dist > 0
                wall += box.wall_strength * (dist * inv_w)^2
            end
        end
        V[I] = wall
    end
    V
end

function evaluate_potential(lat::OpticalLatticePotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d in 1:N
            k_lat = 2π / lat.period[d]
            s += lat.depth[d] * sin(k_lat * grid.x[d][I[d]] + lat.phase[d])^2
        end
        V[I] = s
    end
    V
end

function evaluate_potential(dw::DoubleWellPotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    half_sep = dw.separation / 2
    ax = dw.axis
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d in 1:N
            s += dw.omega[d]^2 * grid.x[d][I[d]]^2
        end
        x_ax = grid.x[ax][I[ax]]
        barrier_val = dw.barrier * exp(-x_ax^2 / (half_sep^2 + eps(Float64)))
        V[I] = 0.5 * s + barrier_val
    end
    V
end

function evaluate_potential(mg::MagneticGradient{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    ax = mg.axis
    @inbounds for I in CartesianIndices(grid.config.n_points)
        V[I] = mg.g_F * mg.gradient * grid.x[ax][I[ax]]
    end
    V
end

function evaluate_potential(td::TimeDependentTrap{N}, grid::Grid{N}; t::Float64=0.0) where {N}
    omega = ntuple(d -> evaluate(td.omega_wf[d], t), N)
    trap = HarmonicTrap{N}(omega)
    evaluate_potential(trap, grid) .+ evaluate_potential(td.base, grid)
end

function evaluate_potential(lg::LaguerreGaussBeam{N}, grid::Grid{N}) where {N}
    N >= 2 || throw(ArgumentError("LaguerreGaussBeam requires N >= 2"))
    V = zeros(Float64, grid.config.n_points)
    w = lg.waist
    l = abs(lg.l_mode)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r = sqrt(grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2)
        rho = sqrt(2.0) * r / w
        intensity = (rho^2)^l * exp(-rho^2)
        V[I] = -lg.polarizability * lg.power * intensity
    end
    V
end

function evaluate_potential(pb::PlugBeam{N}, grid::Grid{N}) where {N}
    N >= 2 || throw(ArgumentError("PlugBeam requires N >= 2"))
    V = zeros(Float64, grid.config.n_points)
    inv_2w2 = 1.0 / (2.0 * pb.waist^2)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r_sq = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2
        V[I] = pb.strength * exp(-r_sq * inv_2w2)
    end
    V
end

function evaluate_potential(sl::ShakenLatticePotential{N}, grid::Grid{N}; t::Float64=0.0) where {N}
    V = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d in 1:N
            k_lat = 2π / sl.period[d]
            phase_shift = evaluate(sl.shake_wf[d], t)
            s += sl.depth[d] * sin(k_lat * grid.x[d][I[d]] + phase_shift)^2
        end
        V[I] = s
    end
    V
end

function evaluate_potential(q::QuarticPotential{N}, grid::Grid{N}) where {N}
    V = zeros(Float64, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = 0.0
        for d in 1:N
            x = grid.x[d][I[d]]
            s += 0.5 * q.omega[d]^2 * x^2 + q.lambda[d] * x^4
        end
        V[I] = s
    end
    V
end
