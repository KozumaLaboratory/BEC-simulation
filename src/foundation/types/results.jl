# --- Analysis result types ---
#
# Outputs from Bogoliubov scans, TOF imaging, instability maps,
# hysteresis sweeps, and supersolid predictions. The analyses themselves
# live in src/analysis/.

export TOFParams,
    ImagingParams, BdGResult, InstabilityMap, RotonParams,
    SupersolidPrediction, HysteresisResult

struct TOFParams
    t_tof::Float64
    gradient::Float64
    imaging_axis::Int

    function TOFParams(t_tof::Float64, gradient::Float64, imaging_axis::Int)
        t_tof >= 0 || throw(ArgumentError("t_tof must be non-negative"))
        1 <= imaging_axis <= 3 || throw(ArgumentError("imaging_axis must be 1, 2, or 3"))
        new(t_tof, gradient, imaging_axis)
    end
end

TOFParams(; t_tof::Float64, gradient::Float64=0.0, imaging_axis::Int=3) = TOFParams(
    t_tof, gradient, imaging_axis
)

"""
    ImagingParams(; view_geometry, sg_tof, sigma_eff, sigma_sg_pixels,
                  psf_sigma_pixels, photons_per_pixel, read_noise_sigma,
                  n_shots_avg)

Bundles the SG/TOF physics, optical-pumping σ_eff(m) table, and the noise
chain for a single absorption-imaging protocol. `view_geometry` is the SBI
embedding tag (`:face_on` → SO(2) equivariance, `:edge_on` → z→−z D₁ only).
`sg_tof` carries the existing TOF + Stern-Gerlach physics (re-used so the
existing analyzer + imaging plumbing flows through unchanged).
`sigma_eff` is the rate-eq output `build_sigma_eff_table(OpticalPumpingParams)`
of length 2F+1 indexed `m = i - F - 1`.

The `view_geometry` tag does NOT alter the column-integration axis (which
remains `sg_tof.imaging_axis::Int`) — it is a separate physical-interpretation
field used by downstream SBI embeddings to choose the correct symmetry group.
"""
struct ImagingParams
    view_geometry::Symbol
    sg_tof::TOFParams
    sigma_eff::Vector{Float64}
    sigma_sg_pixels::Float64
    psf_sigma_pixels::Float64
    photons_per_pixel::Float64
    read_noise_sigma::Float64
    n_shots_avg::Int

    function ImagingParams(view_geometry, sg_tof, sigma_eff,
        sigma_sg_pixels, psf_sigma_pixels,
        photons_per_pixel, read_noise_sigma, n_shots_avg)
        view_geometry in (:face_on, :edge_on) || throw(ArgumentError(
            "view_geometry must be :face_on or :edge_on (got $view_geometry)"))
        sigma_sg_pixels >= 0 || throw(ArgumentError("sigma_sg_pixels must be ≥ 0"))
        psf_sigma_pixels >= 0 || throw(ArgumentError("psf_sigma_pixels must be ≥ 0"))
        photons_per_pixel >= 0 || throw(ArgumentError("photons_per_pixel must be ≥ 0"))
        read_noise_sigma >= 0 || throw(ArgumentError("read_noise_sigma must be ≥ 0"))
        n_shots_avg >= 1 || throw(ArgumentError("n_shots_avg must be ≥ 1"))
        all(>=(0.0), sigma_eff) || throw(ArgumentError("sigma_eff entries must be ≥ 0"))
        new(view_geometry, sg_tof, sigma_eff, sigma_sg_pixels, psf_sigma_pixels,
            photons_per_pixel, read_noise_sigma, n_shots_avg)
    end
end

ImagingParams(; view_geometry::Symbol, sg_tof::TOFParams, sigma_eff::Vector{Float64},
    sigma_sg_pixels::Real=0.0, psf_sigma_pixels::Real=0.0,
    photons_per_pixel::Real=0.0, read_noise_sigma::Real=0.0,
    n_shots_avg::Int=1) = ImagingParams(view_geometry, sg_tof, sigma_eff,
    Float64(sigma_sg_pixels), Float64(psf_sigma_pixels),
    Float64(photons_per_pixel), Float64(read_noise_sigma), n_shots_avg)

struct BdGResult
    k_values::Vector{Float64}
    omega::Matrix{ComplexF64}
    max_growth_rate::Float64
    unstable::Bool
end

struct InstabilityMap
    k_values::Vector{Float64}
    directions::Vector{NTuple{3, Float64}}
    growth_rates::Matrix{Float64}
    max_growth_rate::Float64
    unstable::Bool
    most_unstable_k::Float64
    most_unstable_direction::NTuple{3, Float64}
    k_unstable_range::Tuple{Float64, Float64}
    predicted_wavelength::Float64
    angular_growth_map::Vector{Float64}
end

struct RotonParams
    k_roton::Float64
    omega_roton::Float64
    roton_gap::Float64
    has_roton::Bool
end

struct SupersolidPrediction
    wavelength::Float64
    pattern_type::Symbol
    k_roton::Float64
    angular_anisotropy::Float64
end

struct HysteresisResult
    param_values::Vector{Float64}
    forward::Vector{NamedTuple}
    backward::Vector{NamedTuple}
    hysteresis_intervals::Vector{Tuple{Float64, Float64}}
    transition_points::Vector{Float64}
end
