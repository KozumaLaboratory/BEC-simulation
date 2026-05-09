# --- Analysis result types ---
#
# Outputs from Bogoliubov scans, TOF imaging, instability maps,
# hysteresis sweeps, and supersolid predictions. The analyses themselves
# live in src/analysis/.

export TOFParams, BdGResult, InstabilityMap, RotonParams, SupersolidPrediction,
    HysteresisResult

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
