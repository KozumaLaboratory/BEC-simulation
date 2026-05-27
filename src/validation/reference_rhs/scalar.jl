# --- Reference Hψ: scalar one-body operators (kinetic, trap, density) ---
#
# Kinetic and trap are single-particle linear operators. Density (c₀)
# is the two-body density-density mean-field nonlinearity.
#
# Conventions (matched to src/analysis/energy.jl and src/hamiltonian/integrator/propagators.jl):
#   T = -(1/2) ∇²                      per component (ℏ = m = 1 dimensionless)
#   V_trap = V(r)                       per component
#   c₀ density-density: ε = (c₀/2) n²  → (H_c₀ ψ)_c(r) = c₀ n(r) ψ_c(r)
#
# Each *_apply!(out, psi, ...) writes (H_term ψ)(r) into `out`.
# Each *_energy(psi, ...) returns ⟨ψ|H_term|ψ⟩ with the *same* prefactor
# as the production energy_decomposition (i.e. the 1/2 for c₀ is baked in).

export reference_kinetic_apply!, reference_kinetic_energy
export reference_trap_apply!, reference_trap_energy
export reference_density_apply!, reference_density_energy

"""
    reference_kinetic_apply!(out, psi, grid::Grid{N})

Write `(T ψ)(r) = -(1/2) ∇² ψ` per component into `out`.
Implemented as `IFFT[(1/2) k² · FFT[ψ_c]]` per component.
"""
function reference_kinetic_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    k_sq = grid.k_squared
    buf = Array{ComplexF64, N}(undef, n_pts)
    fwd = plan_fft!(buf; flags=FFTW.ESTIMATE)
    inv = plan_ifft!(buf; flags=FFTW.ESTIMATE)
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        buf .= view(psi, idx...)
        fwd * buf
        @. buf = 0.5 * k_sq * buf
        inv * buf
        out_c = view(out, idx...)
        out_c .= buf
    end
    out
end

"""
    reference_kinetic_energy(psi, grid::Grid{N}) → Float64

⟨ψ|T|ψ⟩ = (1/2) (dV/N_pts) Σ_c Σ_k |k|² |FFT[ψ_c](k)|². Matches
`_kinetic_energy` in `src/analysis/energy.jl` to machine precision.
"""
function reference_kinetic_energy(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(grid)
    inv_npts = 1.0 / prod(n_pts)
    k_sq = grid.k_squared
    buf = Array{ComplexF64, N}(undef, n_pts)
    fwd = plan_fft!(buf; flags=FFTW.ESTIMATE)
    E = 0.0
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        buf .= view(psi, idx...)
        fwd * buf
        Ec = 0.0
        for i in eachindex(k_sq, buf)
            Ec += k_sq[i] * abs2(buf[i])
        end
        E += Ec * dV * inv_npts
    end
    0.5 * E
end

"""
    reference_trap_apply!(out, psi, V_trap)

Write `(V ψ)_c(r) = V_trap(r) · ψ_c(r)` into `out`. `V_trap` is a real
spatial array (same shape as the spatial axes of psi).
"""
function reference_trap_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    V_trap::AbstractArray{<:Real},
)
    ndim = ndims(V_trap)
    n_pts = size(V_trap)
    n_comp = size(psi, ndim + 1)
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        out_c = view(out, idx...)
        @. out_c = V_trap * psi_c
    end
    out
end

"""
    reference_trap_energy(psi, V_trap, grid) → Float64

⟨ψ|V|ψ⟩ = Σ_c ∫ V(r) |ψ_c(r)|² dV. Matches `_trap_energy`.
"""
function reference_trap_energy(
    psi::AbstractArray{<:Complex},
    V_trap::AbstractArray{<:Real},
    grid::Grid{N},
) where {N}
    n_pts = size(V_trap)
    n_comp = size(psi, N + 1)
    dV = cell_volume(grid)
    E = 0.0
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        Ec = 0.0
        for i in eachindex(V_trap, psi_c)
            Ec += V_trap[i] * abs2(psi_c[i])
        end
        E += Ec * dV
    end
    E
end

"""
    reference_density_apply!(out, psi, c0)

Write the c₀ density-density GP nonlinear term:
`(H_c₀ ψ)_c(r) = c₀ n(r) ψ_c(r)` where `n = Σ_c |ψ_c|²`.

Note this is the *propagator* shape (no 1/2). The corresponding energy
`reference_density_energy` carries the 1/2 to match production.
"""
function reference_density_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    c0::Real,
)
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_comp = size(psi, ndim + 1)
    n_density = total_density(psi, ndim)
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        psi_c = view(psi, idx...)
        out_c = view(out, idx...)
        @. out_c = c0 * n_density * psi_c
    end
    out
end

"""
    reference_density_energy(psi, c0, grid) → Float64

`E_c₀ = (c₀/2) ∫ n(r)² dV`. Matches `_density_interaction_energy`.
"""
function reference_density_energy(
    psi::AbstractArray{<:Complex},
    c0::Real,
    grid::Grid{N},
) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(grid)
    s = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        nI = 0.0
        for c in 1:n_comp
            nI += abs2(psi[I, c])
        end
        s += nI * nI
    end
    0.5 * c0 * s * dV
end
