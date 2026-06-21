# --- Spatial profile of the evaporating thermal cloud ---
#
# The 0-D model assumes a quasi-equilibrium thermal cloud, so at every saved step
# its SPATIAL state is a thermal Gaussian set by (N, T) and the per-axis trap
# frequencies: RMS width σ_i = √(k_B T/(m ω_i²)), peak density
# n₀ = N/((2π)^{3/2} σ_x σ_y σ_z), and n(r) = n₀ exp(−Σ r_i²/2σ_i²). This
# reconstructs how the cloud SHRINKS and DENSIFIES through evaporation (physical SI
# units, directly comparable to absorption images). Caveat: it is the BULK thermal
# Gaussian — the high-energy wings are truncated at the trap depth U (η = U/k_B T),
# so it is accurate within a few σ, not in the far tails.

export thermal_cloud_widths, thermal_cloud_density

# per-axis RMS widths [m] + peak density [m⁻³] at one saved step
function _widths_at(trap::EvapTrap, ramp::FortRamp, result::EvapResult, i::Int)
    m = trap.mass
    cdt = _trap_from_powers(trap, fort_power_at(ramp, result.t[i]))
    ωx, ωy, ωz = crossed_trap_frequencies(cdt, m)
    T, N = result.T[i], result.N[i]
    σ(ω) = ω > 0 ? sqrt(Units.KB * T / (m * ω^2)) : Inf
    σx, σy, σz = σ(ωx), σ(ωy), σ(ωz)
    n0 = N / ((2π)^1.5 * σx * σy * σz)
    (σx, σy, σz, n0)
end

"""
    thermal_cloud_widths(trap, ramp, result) -> NamedTuple

Per saved evaporation step, the thermal cloud's per-axis RMS widths `σ_i =
√(k_B T/(m ω_i²))` [m], the geometric mean `σ̄`, and the peak density
`n₀ = N/((2π)^{3/2} σ_x σ_y σ_z)` [m⁻³] — the cloud shrinking and densifying as it
cools. Returns `(; t, sigma_x, sigma_y, sigma_z, sigma_bar, n0)`.
"""
function thermal_cloud_widths(trap::EvapTrap, ramp::FortRamp, result::EvapResult)
    n = length(result.t)
    sx, sy, sz, sb, n0 = (zeros(n) for _ in 1:5)
    for i in 1:n
        σx, σy, σz, peak = _widths_at(trap, ramp, result, i)
        sx[i], sy[i], sz[i] = σx, σy, σz
        sb[i] = cbrt(σx * σy * σz)
        n0[i] = peak
    end
    (t=copy(result.t), sigma_x=sx, sigma_y=sy, sigma_z=sz, sigma_bar=sb, n0=n0)
end

"""
    thermal_cloud_density(trap, ramp, result, step; npts=64, span=4.0)
        -> (x, y, z, n)

3-D thermal-Gaussian density `n(r) = n₀ exp(−Σ r_i²/2σ_i²)` [m⁻³] at saved `step`,
on `npts` points per axis spanning ±`span`·σ_i. Returns the axis coordinates [m]
and the density array — a spatial snapshot of the evaporating cloud (column-density
for imaging = sum along the imaging axis × the cell size).
"""
function thermal_cloud_density(
    trap::EvapTrap, ramp::FortRamp, result::EvapResult, step::Int; npts::Int=64, span::Real=4.0)
    σx, σy, σz, n0 = _widths_at(trap, ramp, result, step)
    xs = collect(range(-span * σx, span * σx; length=npts))
    ys = collect(range(-span * σy, span * σy; length=npts))
    zs = collect(range(-span * σz, span * σz; length=npts))
    n = [n0 * exp(-(x^2 / (2σx^2) + y^2 / (2σy^2) + z^2 / (2σz^2)))
         for x in xs, y in ys, z in zs]
    (xs, ys, zs, n)
end
