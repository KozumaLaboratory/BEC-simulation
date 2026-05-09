# --- Synthetic dimension observables ---
#
# Treat the spinor m-axis as an extra ("synthetic") spatial dimension.

export synthetic_axis_current, synthetic_dim_dispersion, synthetic_localization_length

# For Raman-coupled or RF-driven spinor BECs, the m index behaves like a
# discrete lattice site, and bulk physics — currents, band structure,
# edge states — has a natural transcription. The pipeline analyzer
# `:synthetic_dim` (in pipeline_analyzers.jl) wraps the more useful
# scalars; the lower-level functions here return the raw vectors / 2D
# arrays for downstream plotting and per-paper analyses.

"""
    synthetic_axis_current(psi, grid) -> Vector{Float64}

Site-resolved synthetic-axis "current" — the imaginary part of the
overlap between adjacent spinor components, integrated over real space.
For a Raman / RF coupling that hops m → m±1 this is proportional to the
real flow of population across the synthetic ladder bond between site
m and m+1. Returns a vector of length D-1 (D = 2F+1) where entry c is
the bond between m_c and m_{c+1}.

Convention: positive value means net flow from higher m to lower m
(the spin-down direction in the Zeeman ladder), matching the standard
gauge for synthetic-axis SOC dispersion plots.
"""
function synthetic_axis_current(psi::AbstractArray{Complex{T}}, grid) where {T}
    ndim = ndims(psi) - 1
    D = size(psi, ndim + 1)
    dV = cell_volume(grid)
    n_pts = grid.config.n_points
    out = Vector{Float64}(undef, D - 1)
    @inbounds for c in 1:(D - 1)
        idx_lo = _component_slice(ndim, n_pts, c)
        idx_hi = _component_slice(ndim, n_pts, c + 1)
        psi_lo = view(psi, idx_lo...)
        psi_hi = view(psi, idx_hi...)
        # J_c = -2 Im( ψ_{c+1}^* ψ_c ) integrated over real space
        acc = 0.0
        for i in eachindex(psi_lo)
            z = conj(psi_hi[i]) * psi_lo[i]
            acc += imag(z)
        end
        out[c] = -2.0 * acc * dV
    end
    out
end

"""
    synthetic_dim_dispersion(psi, grid; axis=1) -> NamedTuple

2D FFT along the chosen real-space axis and the synthetic (m) axis.
Returns a NamedTuple with:

  spectrum    — Matrix{Float64} of shape (n_axis, D), the |FT|² of ψ
                summed over the orthogonal real axes
  k_real      — wavevectors along the chosen real axis (length n_axis)
  k_synth     — synthetic-axis wavevectors q ∈ {-π, ... +π} per
                shifted DFT convention (length D)

Useful for extracting spin-orbit-coupling-style dispersion images:
peaks in `spectrum` trace out the lower / upper bands of the synthetic
dimension's Hamiltonian.
"""
function synthetic_dim_dispersion(psi::AbstractArray{Complex{T}}, grid; axis::Int=1) where {T}
    ndim = ndims(psi) - 1
    1 <= axis <= ndim || throw(ArgumentError("axis $axis out of range 1:$ndim"))
    D = size(psi, ndim + 1)
    n_axis = size(psi, axis)

    # Sum |ψ|² in k-space over orthogonal real axes so the result is a
    # 2D (k_real, m_synthetic) field. Then FFT along the m axis to map
    # m → q_synth.
    psi_k = copy(psi)
    plan = plan_fft!(psi_k, (axis,))
    plan * psi_k
    # Reduce orthogonal real axes → keep (axis, m).
    other = setdiff(1:ndim, axis)
    n_pts = ntuple(d -> size(psi, d), ndim)
    plane = abs2.(psi_k)
    if !isempty(other)
        plane = sum(plane; dims=Tuple(other))
        plane = dropdims(plane; dims=Tuple(other))
    end
    # `plane` has shape (n_axis, D); FFT along m axis.
    plane_complex = Complex{Float64}.(plane)
    fft!(plane_complex, 2)
    spectrum = abs2.(plane_complex)

    # Real-axis k-grid: matches the standard FFT layout used elsewhere in
    # the project (see foundation/grid.jl).
    box_axis = grid.config.box_size[axis]
    dx = box_axis / n_axis
    k_real = fftfreq(n_axis, 2π / dx)
    # Synthetic axis: a unit lattice spacing on the integer m site index.
    k_synth = fftfreq(D, 2π)
    (spectrum=spectrum, k_real=collect(k_real), k_synth=collect(k_synth))
end

"""
    synthetic_localization_length(psi) -> Float64

Inverse-participation-ratio length on the synthetic ladder, computed
from the per-m density profile p(m) = ∫|ψ_m|² dV (normalised to 1):

    ξ = (Σ_m p(m)²)^(-1)

For a uniformly-spread state ξ = D; for a fully-localised state ξ = 1.
A handy diagnostic for Wannier-Stark localisation under a Zeeman
gradient.
"""
function synthetic_localization_length(psi::AbstractArray{Complex{T}}, grid) where {T}
    ndim = ndims(psi) - 1
    D = size(psi, ndim + 1)
    dV = cell_volume(grid)
    n_pts = grid.config.n_points
    p = zeros(Float64, D)
    @inbounds for c in 1:D
        idx = _component_slice(ndim, n_pts, c)
        p[c] = real(sum(abs2, view(psi, idx...))) * dV
    end
    s = sum(p)
    s > 0 || return Float64(D)
    p ./= s
    1.0 / sum(p .^ 2)
end
