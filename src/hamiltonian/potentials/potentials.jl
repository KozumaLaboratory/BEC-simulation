function evaluate_potential(::NoPotential, grid::Grid{N,T}) where {N,T}
    zeros(T, grid.config.n_points)
end

function evaluate_potential(trap::HarmonicTrap{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    half = T(0.5)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = zero(T)
        for d = 1:N
            s += T(trap.omega[d])^2 * grid.x[d][I[d]]^2
        end
        V[I] = half * s
    end
    V
end

function evaluate_potential(grav::GravityPotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    ax = grav.axis
    g = T(grav.g)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        V[I] = g * grid.x[ax][I[ax]]
    end
    V
end

function evaluate_potential(comp::CompositePotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    for pot in comp.components
        V .+= evaluate_potential(pot, grid)
    end
    V
end

function evaluate_potential(ring::RingPotential{N}, grid::Grid{N,T}) where {N,T}
    N >= 2 || throw(ArgumentError("RingPotential requires N >= 2"))
    V = zeros(T, grid.config.n_points)
    width = T(ring.width)
    strength = T(ring.strength)
    radius = T(ring.radius)
    inv_2w2 = one(T) / (T(2) * width^2)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r = sqrt(grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2)
        V[I] = strength * exp(-(r - radius)^2 * inv_2w2)
    end
    V
end

function evaluate_potential(box::BoxPotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    half = ntuple(d -> T(box.size[d] / 2), N)
    inv_w = one(T) / T(box.wall_width)
    strength = T(box.wall_strength)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        wall = zero(T)
        for d in 1:N
            dist = abs(grid.x[d][I[d]]) - half[d]
            if dist > 0
                wall += strength * (dist * inv_w)^2
            end
        end
        V[I] = wall
    end
    V
end

function evaluate_potential(lat::OpticalLatticePotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = zero(T)
        for d in 1:N
            k_lat = T(2π / lat.period[d])
            s += T(lat.depth[d]) * sin(k_lat * grid.x[d][I[d]] + T(lat.phase[d]))^2
        end
        V[I] = s
    end
    V
end

function evaluate_potential(dw::DoubleWellPotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    half_sep = T(dw.separation / 2)
    ax = dw.axis
    barrier = T(dw.barrier)
    half = T(0.5)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = zero(T)
        for d in 1:N
            s += T(dw.omega[d])^2 * grid.x[d][I[d]]^2
        end
        x_ax = grid.x[ax][I[ax]]
        barrier_val = barrier * exp(-x_ax^2 / (half_sep^2 + eps(T)))
        V[I] = half * s + barrier_val
    end
    V
end

function evaluate_potential(mg::MagneticGradient{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    ax = mg.axis
    gF_grad = T(mg.g_F * mg.gradient)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        V[I] = gF_grad * grid.x[ax][I[ax]]
    end
    V
end

function evaluate_potential(td::TimeDependentTrap{N}, grid::Grid{N,T}; t::Float64=0.0) where {N,T}
    omega = ntuple(d -> evaluate(td.omega_wf[d], t), N)
    trap = HarmonicTrap{N}(omega)
    evaluate_potential(trap, grid) .+ evaluate_potential(td.base, grid)
end

function evaluate_potential(lg::LaguerreGaussBeam{N}, grid::Grid{N,T}) where {N,T}
    N >= 2 || throw(ArgumentError("LaguerreGaussBeam requires N >= 2"))
    V = zeros(T, grid.config.n_points)
    w = T(lg.waist)
    l = abs(lg.l_mode)
    amp = T(-lg.polarizability * lg.power)
    sqrt2 = sqrt(T(2))
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r = sqrt(grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2)
        rho = sqrt2 * r / w
        intensity = (rho^2)^l * exp(-rho^2)
        V[I] = amp * intensity
    end
    V
end

function evaluate_potential(pb::PlugBeam{N}, grid::Grid{N,T}) where {N,T}
    N >= 2 || throw(ArgumentError("PlugBeam requires N >= 2"))
    V = zeros(T, grid.config.n_points)
    waist = T(pb.waist)
    strength = T(pb.strength)
    inv_2w2 = one(T) / (T(2) * waist^2)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r_sq = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2
        V[I] = strength * exp(-r_sq * inv_2w2)
    end
    V
end

function evaluate_potential(sl::ShakenLatticePotential{N}, grid::Grid{N,T}; t::Float64=0.0) where {N,T}
    V = zeros(T, grid.config.n_points)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = zero(T)
        for d in 1:N
            k_lat = T(2π / sl.period[d])
            phase_shift = T(evaluate(sl.shake_wf[d], t))
            s += T(sl.depth[d]) * sin(k_lat * grid.x[d][I[d]] + phase_shift)^2
        end
        V[I] = s
    end
    V
end

function evaluate_potential(q::QuarticPotential{N}, grid::Grid{N,T}) where {N,T}
    V = zeros(T, grid.config.n_points)
    half = T(0.5)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        s = zero(T)
        for d in 1:N
            x = grid.x[d][I[d]]
            s += half * T(q.omega[d])^2 * x^2 + T(q.lambda[d]) * x^4
        end
        V[I] = s
    end
    V
end
