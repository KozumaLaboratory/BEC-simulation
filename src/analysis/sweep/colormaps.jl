# Reference colormap LUTs (frozen for reproducibility) + per-cell hex resolution.
#
# cmocean `balance` (signed) and viridis (positive) LUTs, sampled once and frozen
# so `colormap_version: "1.0"` pins them for renderer-comparison gates. The
# `resolve_*_cell_hex` helpers are the single point where a value becomes a fill
# colour; renderers do the lookup, the dispatcher picks the LUT.

export sweep_balance_lut,
    sweep_viridis_lut,
    resolve_signed_cell_hex,
    resolve_positive_cell_hex

# --- Reference colormap LUTs (frozen for reproducibility) -------------

"""
    sweep_balance_lut(n=256) -> Vector{NTuple{3, UInt8}}

cmocean `balance` LUT, sampled at `n` points. Perceptually uniform
diverging (deep blue → off-white → deep red), suitable for signed
observables centred at 0 with symmetric clip.

Values are an inline 11-stop sampling of the published cmocean balance
(Crameri & Hartley 2020). For renderer comparison gates the
`colormap_version` field in the golden table pins this exact LUT.
"""
function sweep_balance_lut(n::Int=256)
    stops = [
        (0.0, (24, 28, 67)),
        (0.1, (33, 60, 109)),
        (0.2, (42, 93, 152)),
        (0.3, (75, 126, 174)),
        (0.4, (140, 168, 198)),
        (0.5, (235, 235, 230)),
        (0.6, (210, 154, 142)),
        (0.7, (192, 96, 85)),
        (0.8, (165, 45, 47)),
        (0.9, (113, 19, 33)),
        (1.0, (60, 8, 20)),
    ]
    _interp_lut(stops, n)
end

"""
    sweep_viridis_lut(n=256) -> Vector{NTuple{3, UInt8}}

Viridis LUT (deep purple → teal → bright yellow), sampled at `n` points.
Perceptually uniform monotonic; suitable for positive / monotone
observables (E, f_max, ‖∇E‖ with `scale=:log`).
"""
function sweep_viridis_lut(n::Int=256)
    stops = [
        (0.0, (68, 1, 84)),
        (0.1, (72, 35, 116)),
        (0.2, (64, 67, 135)),
        (0.3, (52, 94, 141)),
        (0.4, (41, 121, 142)),
        (0.5, (32, 144, 140)),
        (0.6, (34, 167, 132)),
        (0.7, (68, 190, 112)),
        (0.8, (121, 209, 81)),
        (0.9, (189, 222, 38)),
        (1.0, (253, 231, 36)),
    ]
    _interp_lut(stops, n)
end

function _interp_lut(stops, n::Int)
    out = Vector{NTuple{3, UInt8}}(undef, n)
    for i in 1:n
        t = (i - 1) / (n - 1)
        # find bracketing stops
        idx = findlast(s -> first(s) <= t, stops)
        idx === nothing && (idx = 1)
        idx == length(stops) && (idx = length(stops) - 1)
        s0, c0 = stops[idx]
        s1, c1 = stops[idx + 1]
        u = (t - s0) / max(s1 - s0, eps())
        r = clamp(round(Int, c0[1] * (1 - u) + c1[1] * u), 0, 255)
        g = clamp(round(Int, c0[2] * (1 - u) + c1[2] * u), 0, 255)
        b = clamp(round(Int, c0[3] * (1 - u) + c1[3] * u), 0, 255)
        out[i] = (UInt8(r), UInt8(g), UInt8(b))
    end
    return out
end

const SWEEP_COLORMAP_VERSION = "1.0"

# Serialise a LUT as a hex-string vector so Vega-Lite can drive its own
# `scale.range`. This is the single point where the dispatcher hands the
# LUT to the renderer; the renderer does only the value→colour lookup
# (mechanical), not the LUT choice (dispatcher decision).
function _lut_hex_array(lut::Vector{NTuple{3, UInt8}})
    return [
        string("#",
            lpad(string(r; base=16), 2, '0'),
            lpad(string(g; base=16), 2, '0'),
            lpad(string(b; base=16), 2, '0'))
        for (r, g, b) in lut
    ]
end

# Diverging blue→grey→red palette for dominant-m in [-F, +F]. Physical
# meaning: -F (full m_- pin) at deep blue, m=0 (zero magnetization) at
# off-white, +F (full m_+ pin) at deep red. "mixed" sits in neutral grey
# so it reads as "no decision" rather than "extreme".
function _dominant_m_palette(F::Int)
    n = 2F + 1
    out = Vector{String}(undef, n)
    for (i, m) in enumerate(F:-1:-F)
        t = (Float64(m) + F) / (2F)  # m=+F → t=1, m=-F → t=0
        r = round(Int, 60 * (1 - t) + 165 * t)
        g = round(Int, 8 * (1 - t) + 45 * t)
        b = round(Int, 20 * (1 - t) + 47 * t)
        # Brighten toward the middle so m=0 isn't lost
        u = 1 - abs(t - 0.5) * 2  # peaks at t=0.5
        r = clamp(round(Int, r * (1 - 0.55u) + 235 * 0.55u), 0, 255)
        g = clamp(round(Int, g * (1 - 0.55u) + 235 * 0.55u), 0, 255)
        b = clamp(round(Int, b * (1 - 0.55u) + 230 * 0.55u), 0, 255)
        out[i] = string("#", lpad(string(r; base=16), 2, '0'),
            lpad(string(g; base=16), 2, '0'),
            lpad(string(b; base=16), 2, '0'))
    end
    return out
end

# --- Resolve per-cell hex ---------------------------------------------

"""
    resolve_signed_cell_hex(value, vmin, vmax; lut=sweep_balance_lut())
        -> String

Return the per-cell fill hex for a signed observable. NaN → neutral
grey (#9aa0a6) so unresolved cells are visibly distinct from oracle
centre. Out-of-clip values saturate to the LUT endpoint, NOT extrapolate.
"""
function resolve_signed_cell_hex(value::Real, vmin::Real, vmax::Real;
    lut::Vector{NTuple{3, UInt8}}=sweep_balance_lut())
    isnan(value) && return "#9aa0a6"
    t = (value - vmin) / max(vmax - vmin, eps())
    t = clamp(t, 0.0, 1.0)
    idx = clamp(round(Int, t * (length(lut) - 1)) + 1, 1, length(lut))
    r, g, b = lut[idx]
    return string("#",
        lpad(string(r; base=16), 2, '0'),
        lpad(string(g; base=16), 2, '0'),
        lpad(string(b; base=16), 2, '0'))
end

"""
    resolve_positive_cell_hex(value, vmin, vmax; scale=:linear,
                              lut=sweep_viridis_lut()) -> String
"""
function resolve_positive_cell_hex(value::Real, vmin::Real, vmax::Real;
    scale::Symbol=:linear,
    lut::Vector{NTuple{3, UInt8}}=sweep_viridis_lut())
    isnan(value) && return "#9aa0a6"
    t = if scale === :log
        v = max(value, eps())
        vn = max(vmin, eps())
        vx = max(vmax, eps())
        (log10(v) - log10(vn)) / max(log10(vx) - log10(vn), eps())
    else
        (value - vmin) / max(vmax - vmin, eps())
    end
    t = clamp(t, 0.0, 1.0)
    idx = clamp(round(Int, t * (length(lut) - 1)) + 1, 1, length(lut))
    r, g, b = lut[idx]
    return string("#",
        lpad(string(r; base=16), 2, '0'),
        lpad(string(g; base=16), 2, '0'),
        lpad(string(b; base=16), 2, '0'))
end
