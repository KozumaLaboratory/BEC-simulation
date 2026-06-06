# sigma_polar / delta_polar lookup wrappers around SIGMA_TABLE /
# DELTA_TABLE. The tables are included by the umbrella before this file.

"""
    sigma_polar(F::Int, m::Int, g_dict) -> Float64

Polar phase σ_m via lookup table (50-digit sympy values cast to Float64).
"""
@inline function sigma_polar(F::Int, m::Int, g_dict)::Float64
    haskey(SIGMA_TABLE, F) || error("F=$F not pre-computed (supported: 1..8)")
    coefs = SIGMA_TABLE[F][abs(m) + 1]
    s = 0.0
    @inbounds for (Sv, c) in coefs
        s += c * g_dict[Sv]
    end
    return s
end

"""
    delta_polar(F::Int, m::Int, g_dict) -> Float64

Polar phase δ_m via lookup table (anomalous BdG channel coupling).
"""
@inline function delta_polar(F::Int, m::Int, g_dict)::Float64
    haskey(DELTA_TABLE, F) || error("F=$F not pre-computed (supported: 1..8)")
    coefs = DELTA_TABLE[F][abs(m) + 1]
    d = 0.0
    @inbounds for (Sv, c) in coefs
        d += c * g_dict[Sv]
    end
    return d
end
