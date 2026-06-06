# --- Experiment configuration value types ---

export PotentialConfig, ConstantValue, LinearRamp, interpolate_value

struct ConstantValue
    value::Float64
end

struct LinearRamp
    from::Float64
    to::Float64
end

interpolate_value(v::ConstantValue, ::Float64) = v.value
interpolate_value(v::LinearRamp, t_frac::Float64) =
    v.from + (v.to - v.from) * clamp(t_frac, 0.0, 1.0)

struct PotentialConfig
    type::Symbol
    params::Dict{String, Any}
end
