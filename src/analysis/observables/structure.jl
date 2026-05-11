# --- Density structure observables ---
#
# FFT-based static structure factor + simple density modulation contrast.
# Used for supersolid / modulated phase detection.

export structure_factor, modulation_contrast

"""
    structure_factor(psi, grid) → Array{Float64,N}

Static structure factor S(k) = |δn(k)|² / N_grid from density fluctuations.
Useful for detecting supersolid/modulated phases.
"""
function structure_factor(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    n = total_density(psi, N)
    n_mean = sum(n) / prod(size(n))
    delta_n = n .- n_mean
    delta_n_k = FFTW.fft(delta_n)
    abs2.(delta_n_k) ./ prod(size(n))
end

"""
    modulation_contrast(psi, ndim) → Float64

Density modulation contrast (n_max - n_min) / (n_max + n_min).
Returns 0 for uniform density, approaches 1 for strong modulation.
"""
function modulation_contrast(psi::AbstractArray{<:Complex}, ndim::Int)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    n_min = minimum(n)
    (n_max - n_min) / (n_max + n_min + eps(Float64))
end
