# --- Crossed optical-dipole-trap geometry: depth + frequencies (analytic) ---
#
# Analytic helpers layered on the existing `GaussianBeam` / `CrossedDipoleTrap`
# (src/hamiltonian/optics/optical_trap.jl). No `Grid` — these feed the 0-D
# evaporation model with the instantaneous trap depth U [J] and mean trap
# frequency ω̄ [rad/s] as the FORT powers are ramped.
#
# Conventions: red-detuned dipole trap, V(r) = -α I(r), α > 0 (attractive);
# I₀ = 2P/(π w₀²) at the focus. Trap frequencies from the quadratic expansion of
# V at the minimum; trap DEPTH from a 1-D escape-barrier search per lab axis,
# with gravity tilting the vertical direction (the shallow end-trap is gravity-
# limited). The gravity-corrected depth is the least-standard piece — it is the
# minimum barrier over the six ±lab-axis escape directions.

export rayleigh_range, beam_depth, beam_frequencies
export crossed_trap_frequencies, mean_trap_frequency, crossed_trap_depth

const _G_EARTH = 9.80665   # m/s²

"""
    rayleigh_range(beam) -> z_R [m]

Rayleigh range `z_R = π w₀² / λ` of a Gaussian beam.
"""
rayleigh_range(beam::GaussianBeam) = π * beam.waist^2 / beam.wavelength

"""
    beam_depth(beam, α) -> U₀ [J]

Peak optical trap depth `U₀ = α · 2P / (π w₀²)` at the focus. `α` is the scalar
polarizability (`CrossedDipoleTrap.polarizability`, units J/(W/m²)).
"""
beam_depth(beam::GaussianBeam, alpha::Real) = alpha * 2 * beam.power / (π * beam.waist^2)

"""
    beam_frequencies(beam, α, m) -> (ω_radial, ω_axial) [rad/s]

Single-beam trap frequencies for atom mass `m`:
`ω_r = √(4 U₀ / (m w₀²))` (transverse), `ω_ax = √(2 U₀ / (m z_R²))` (along the
propagation axis). Zero power ⇒ zero frequencies.
"""
function beam_frequencies(beam::GaussianBeam, alpha::Real, m::Real)
    U0 = beam_depth(beam, alpha)
    U0 <= 0 && return (0.0, 0.0)
    zR = rayleigh_range(beam)
    (sqrt(4U0 / (m * beam.waist^2)), sqrt(2U0 / (m * zR^2)))
end

# Diagonal lab-axis curvature contribution of one beam: a circular beam has
# curvature m·ω_r² in the plane ⟂ to d̂ and m·ω_ax² along d̂, so the lab-axis-a
# diagonal is m·ω_r²(1-d_a²) + m·ω_ax²·d_a². (Off-diagonal cross terms are
# dropped — exact when the crossing beams lie along lab axes, the usual case.)
function _axis_curvatures(trap::CrossedDipoleTrap, m::Real)
    κ = zeros(3)
    for beam in trap.beams
        ωr, ωax = beam_frequencies(beam, trap.polarizability, m)
        kr = m * ωr^2
        kax = m * ωax^2
        d = beam.direction
        nrm = sqrt(d[1]^2 + d[2]^2 + d[3]^2)
        nrm == 0 && continue
        for a in 1:3
            da = d[a] / nrm
            κ[a] += kr * (1 - da^2) + kax * da^2
        end
    end
    κ
end

"""
    crossed_trap_frequencies(trap, m) -> (ωx, ωy, ωz) [rad/s]

Lab-axis trap frequencies of a crossed dipole trap: per-beam curvatures add, then
`ω_a = √(κ_a / m)`. Diagonal approximation (beams ≈ along lab axes).
"""
function crossed_trap_frequencies(trap::CrossedDipoleTrap, m::Real)
    κ = _axis_curvatures(trap, m)
    (sqrt(max(κ[1], 0.0) / m), sqrt(max(κ[2], 0.0) / m), sqrt(max(κ[3], 0.0) / m))
end

"""
    mean_trap_frequency(trap, m) -> ω̄ [rad/s]

Geometric mean `ω̄ = (ωx ωy ωz)^{1/3}`.
"""
function mean_trap_frequency(trap::CrossedDipoleTrap, m::Real)
    ωx, ωy, ωz = crossed_trap_frequencies(trap, m)
    cbrt(ωx * ωy * ωz)
end

# Optical potential of one Gaussian beam at point r (m), V = -α I(r) [J].
function _beam_potential_point(beam::GaussianBeam, alpha::Real, r::NTuple{3, Float64})
    beam.power <= 0 && return 0.0
    d = beam.direction
    nrm = sqrt(d[1]^2 + d[2]^2 + d[3]^2)
    nrm == 0 && return 0.0
    dx = (r[1] - beam.position[1], r[2] - beam.position[2], r[3] - beam.position[3])
    ζ = (dx[1] * d[1] + dx[2] * d[2] + dx[3] * d[3]) / nrm          # axial coord
    ρ2 = max(dx[1]^2 + dx[2]^2 + dx[3]^2 - ζ^2, 0.0)                # radial²
    zR = rayleigh_range(beam)
    wz2 = beam.waist^2 * (1 + (ζ / zR)^2)
    I0 = 2 * beam.power / (π * beam.waist^2)
    I = I0 * (beam.waist^2 / wz2) * exp(-2ρ2 / wz2)
    -alpha * I
end

_trap_potential_point(trap::CrossedDipoleTrap, r::NTuple{3, Float64}) =
    sum(_beam_potential_point(b, trap.polarizability, r) for b in trap.beams)

"""
    crossed_trap_depth(trap, m; gravity_axis=3, n_scan=400, reach=8.0) -> U [J]

Gravity-corrected trap depth: the smallest escape barrier over the six ±lab-axis
directions. Along each axis the total optical potential (plus `m g s` gravitational
tilt on `gravity_axis`) is scanned out to `reach` × the largest beam waist; the
barrier is `max V_outward − V_center`. The minimum over directions is the depth
that sets `η = U / (k_B T)`. Returns `0.0` if the trap is not bound (no positive
barrier — e.g. gravity overwhelms a near-zero-power trap).
"""
function crossed_trap_depth(
    trap::CrossedDipoleTrap, m::Real; gravity_axis::Int=3, n_scan::Int=600, reach::Float64=6.0)
    isempty(trap.beams) && return 0.0
    grav(s, a) = a == gravity_axis ? m * _G_EARTH * s : 0.0
    Vc = _trap_potential_point(trap, (0.0, 0.0, 0.0)) + grav(0.0, gravity_axis)
    Udepth = Inf
    @inbounds for a in 1:3
        # per-axis scan length: a beam confines weakly (∝ Rayleigh range) ALONG its
        # own axis and tightly (∝ waist) transverse to it. Use the largest relevant
        # scale so both the radial barrier (~1.5 w₀) and the axial one (~z_R) are
        # resolved — a single beam's escape is axial over z_R ≫ w₀.
        Lscale = 0.0
        for b in trap.beams
            b.power <= 0 && continue
            d = b.direction
            nrm = sqrt(d[1]^2 + d[2]^2 + d[3]^2)
            nrm == 0 && continue
            da = abs(d[a] / nrm)
            Lscale = max(Lscale, da > 0.7 ? rayleigh_range(b) : b.waist)
        end
        Lscale == 0 && continue
        for sgn in (-1.0, 1.0)
            barrier = -Inf
            for i in 1:n_scan
                s = sgn * reach * Lscale * i / n_scan
                r = ntuple(k -> k == a ? s : 0.0, 3)
                V = _trap_potential_point(trap, r) + grav(s, a)
                barrier = max(barrier, V - Vc)
            end
            Udepth = min(Udepth, barrier)
        end
    end
    isfinite(Udepth) ? max(Udepth, 0.0) : 0.0
end
