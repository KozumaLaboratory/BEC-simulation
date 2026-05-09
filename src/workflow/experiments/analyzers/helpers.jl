# --- Shared analyzer helpers ---
#
# Cheap geometry / phase utilities reused across imaging, topology,
# and spectroscopy analyzers. Kept in their own file so each topical
# analyzer module can `using` the parent module and reach them
# without re-declaring.

function _phase_diff(a::Float64, b::Float64)
    d = a - b
    if d > π
        d - 2π
    elseif d < -π
        d + 2π
    else
        d
    end
end

# --- droplet_profile helpers ---

"""Extract the 1D density line through `peak_idx` along dimension `d`."""
function _line_through_peak(n::AbstractArray, peak_idx::NTuple{D, Int}, d::Int) where {D}
    nd = size(n, d)
    line = Vector{Float64}(undef, nd)
    @inbounds for i in 1:nd
        idx = ntuple(k -> k == d ? i : peak_idx[k], D)
        line[i] = n[idx...]
    end
    line
end

"""
Full width at half maximum of a 1D profile with grid spacing `dx`.
Returns 0 if the profile never reaches half of its peak (degenerate).
Uses linear interpolation between adjacent grid points at the crossings.
"""
function _fwhm_1d(line::AbstractVector{Float64}, dx::Float64)
    pk = maximum(line)
    pk > 0 || return 0.0
    half = 0.5 * pk
    i_lo = findfirst(x -> x >= half, line)
    i_hi = findlast(x -> x >= half, line)
    (i_lo === nothing || i_hi === nothing || i_hi <= i_lo) && return 0.0
    lo_frac = if i_lo > 1
        prev = line[i_lo - 1];
        curr = line[i_lo]
        curr > prev ? (half - prev) / (curr - prev) : 0.0
    else
        0.0
    end
    hi_frac = if i_hi < length(line)
        curr = line[i_hi];
        nxt = line[i_hi + 1]
        curr > nxt ? (curr - half) / (curr - nxt) : 1.0
    else
        1.0
    end
    (i_hi + hi_frac - (i_lo - (1.0 - lo_frac))) * dx
end

"""Density-weighted RMS width of a 1D profile along a coordinate axis."""
function _rms_width_1d(line::AbstractVector{Float64}, dx::Float64, x::AbstractVector)
    tot = sum(line) * dx
    tot > 0 || return 0.0
    # Two fused reductions instead of three temp arrays
    # (`line .* x`, `x .- x̄`, `line .* (x .- x̄).^2`).
    sum_lx = 0.0
    @inbounds for i in eachindex(line, x)
        sum_lx += line[i] * x[i]
    end
    x̄ = sum_lx * dx / tot
    var_acc = 0.0
    @inbounds for i in eachindex(line, x)
        d = x[i] - x̄
        var_acc += line[i] * d * d
    end
    sqrt(max(var_acc * dx / tot, 0.0))
end

"""
    _count_domain_walls(fz, n, threshold, n_pts) → Int

Count sign changes in `fz` along CartesianIndices iteration order, masked
to voxels where `n[I] > threshold`. Shared by `domain_analysis`,
`defect_density(:domain_wall)`, and `kibble_zurek_stats` — all three
analyzers were carrying byte-identical copies of this loop.
"""
function _count_domain_walls(
    fz::AbstractArray, n::AbstractArray, threshold::Float64, n_pts::Tuple
)
    prev_sign = 0
    count = 0
    for I in CartesianIndices(n_pts)
        n[I] > threshold || continue
        s = sign(fz[I])
        if s != 0 && s != prev_sign && prev_sign != 0
            count += 1
        end
        s != 0 && (prev_sign = s)
    end
    count
end

"""Max absolute forward-difference derivative of density along axis `d`."""
function _max_forward_grad(n::AbstractArray{<:Real, D}, d::Int, dx::Float64) where {D}
    sz = size(n)
    gmax = 0.0
    @inbounds for I in CartesianIndices(ntuple(k -> k == d ? sz[k] - 1 : sz[k], D))
        Ip1 = CartesianIndex(ntuple(k -> k == d ? I[k] + 1 : I[k], D))
        g = abs(n[Ip1] - n[I]) / dx
        g > gmax && (gmax = g)
    end
    gmax
end
