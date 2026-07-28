# --- 0-D evaporation trajectory → SPGPE reservoir (T(t), μ(t)) ---
#
# The bridge that makes a SECOND-SCALE evaporation runnable as a c-field
# simulation. The incoherent region of the SPGPE is exactly what the 0-D
# truncated-Boltzmann model already describes: a thermal cloud with a number and
# a temperature, evolving on the experimental timescale. So instead of removing
# atoms with a mechanical energy knife on a timescale picked for numerical
# convenience — which is what made the earlier evaporation runs ~60× too fast and
# therefore non-adiabatic spilling rather than evaporation — the c-field is
# coupled to a reservoir whose (T, μ) follow the modelled ramp in real seconds.
#
# The c-field then condenses because the reservoir it is in equilibrium with got
# cold, which is what happens in the laboratory.

export spgpe_reservoir, reservoir_chemical_potential

"""
    reservoir_chemical_potential(N, T, ω̄, m, a_s) -> μ [J]

Chemical potential of a harmonically-trapped Bose gas of `N` atoms at temperature
`T`, in the two regimes the evaporation passes through:

- **Above `T_c`** the gas is non-degenerate and `μ` follows from the ideal-Bose
  phase-space density, `Li₃(z) = N(ℏω̄/k_BT)³` with `z = e^{μ/k_BT}` — negative,
  rising toward `0⁻` as the gas degenerates.
- **Below `T_c`** the thermal cloud saturates and `μ` is pinned by the condensate,
  `μ = ½ℏω̄(15N₀a_s/a_ho)^{2/5}` (Thomas–Fermi), with `N₀ = N − N_th` from
  [`condensate_split`](@ref).

Continuous at the transition: `N₀ → 0` sends the TF branch to `0` and the ideal
branch to `0⁻`.

The below-`T_c` branch is why an SPGPE run driven this way is a check on the
condensate's **dynamics** rather than an independent measurement of its **size**:
prescribing `μ` from the 0-D `N₀` means the c-field's equilibrium population is
pinned to the 0-D answer by construction. What the c-field is free to do — and
what the 0-D model cannot say — is *lag*: growth proceeds at a finite rate `γ`, so
a ramp faster than `1/γ` leaves `N₀(t)` behind its quasi-static value.
"""
function reservoir_chemical_potential(N::Real, T::Real, ω̄::Real, m::Real, a_s::Real)
    (N <= 0 || T <= 0 || ω̄ <= 0) && return 0.0
    kBT = Units.KB * Float64(T)
    N0, _ = condensate_split(N, T, ω̄)
    if N0 > 0
        a_ho = sqrt(Units.HBAR / (Float64(m) * Float64(ω̄)))
        return 0.5 * Units.HBAR * Float64(ω̄) * (15 * N0 * Float64(a_s) / a_ho)^0.4
    end
    ρ = Float64(N) * (Units.HBAR * Float64(ω̄) / kBT)^3      # phase-space density
    kBT * log(_invert_li3(min(ρ, _ZETA3)))
end

"""
    _invert_li3(ρ) -> z ∈ (0, 1]

Solve `Li₃(z) = ρ` for the fugacity, `Li₃(z) = Σ_{n≥1} z^n/n³`. Bisection: `Li₃`
is strictly increasing on `(0,1]` with `Li₃(1) = ζ(3)`, so `ρ ≥ ζ(3)` returns 1
(the saturated / degenerate case, handled by the condensate branch above).
"""
function _invert_li3(ρ::Float64)
    ρ <= 0 && return eps(Float64)
    ρ >= _ZETA3 && return 1.0
    lo, hi = 0.0, 1.0
    for _ in 1:200
        mid = 0.5 * (lo + hi)
        _li3(mid) < ρ ? (lo = mid) : (hi = mid)
    end
    0.5 * (lo + hi)
end

function _li3(z::Float64)
    z <= 0 && return 0.0
    s = 0.0
    zn = z
    for n in 1:2000
        term = zn / n^3
        s += term
        term <= 1e-16 * s && break
        zn *= z
    end
    s
end

"""
    spgpe_reservoir(r::EvapBecResult, trap::EvapTrap, ramp::FortRamp;
                    omega_ref, a_s, k_cut, t_start=nothing, t_end=nothing,
                    omega_mult=(t -> 1.0), kwargs...)
        -> (; reservoir, t_internal, T_int, mu_int, N0_ref, N_ref, omega_bar,
              duration_s, duration_internal)

Turn a two-component 0-D evaporation trajectory ([`run_evaporation_bec`](@ref))
into an [`SPGPEReservoir`](@ref) whose `T(t)` and `μ(t)` are piecewise-linear
waveforms in **internal simulation time** (`t_internal = t_SI · ω_ref`).

This is the interface that makes the second-scale ramp physical: a 1.5 s
laboratory evaporation at `ω_ref = 2π·284 rad/s` is ≈ 2700 internal time units,
and the reservoir walks the modelled `(T, μ)` across exactly that span.

- `omega_ref` [rad/s] — the internal frequency unit.
- `a_s` [m] — scattering length; converted to `a_ho` units for the rate formulas
  and used for the Thomas–Fermi branch of `μ`.
- `k_cut` — the c-field projector cutoff in internal units. `ϵ_cut = ½k_cut²`
  must exceed `μ(t)` for the whole window or the reservoir formulas are undefined;
  this is checked and reported rather than left to blow up mid-run.
- `t_start`, `t_end` [s] — restrict to a window of the ramp (default: the whole
  trajectory). Use to run only the transition region.
- `omega_mult` — the same tightness multiplier passed to `run_evaporation_bec`,
  so `ω̄(t)` matches the trajectory that produced `r`.

Returned alongside the reservoir: the 0-D `N0_ref(t)` and `N_ref(t)` on the same
internal-time axis, which is the quasi-static curve the c-field result is compared
against, and `duration_s` / `duration_internal` so a caller can state the physical
timescale it is about to run (and notice if it is about to run a millisecond).
"""
function spgpe_reservoir(
    r::EvapBecResult, trap::EvapTrap, ramp::FortRamp;
    omega_ref::Real, a_s::Real, k_cut::Real,
    t_start=nothing, t_end=nothing, omega_mult=(t -> 1.0),
    number_damping::Bool=true, energy_damping::Bool=true,
    gamma=nothing, M=nothing,
)
    isempty(r.t) && throw(ArgumentError("spgpe_reservoir: empty evaporation trajectory"))
    ωref = Float64(omega_ref)
    m = trap.mass
    a_ho = sqrt(Units.HBAR / (m * ωref))
    eps_cut = 0.5 * Float64(k_cut)^2

    t0 = t_start === nothing ? r.t[1] : Float64(t_start)
    t1 = t_end === nothing ? r.t[end] : Float64(t_end)
    t1 > t0 || throw(ArgumentError("spgpe_reservoir: need t_end > t_start, got ($t0, $t1)"))
    sel = findall(t -> t0 <= t <= t1, r.t)
    length(sel) >= 2 || throw(
        ArgumentError(
            "spgpe_reservoir: window [$t0, $t1] s contains $(length(sel)) trajectory " *
            "points; widen it or run the 0-D model with a smaller save_every"),
    )

    # ω̄(t) along the same ramp the trajectory was generated on.
    grid = evap_trap_grid(trap, ramp)
    ω̄_of = function (tq)
        tg, ωg, dtg = grid.tg, grid.ωg, grid.dtg
        ng = length(tg)
        ω = if tq <= tg[1]
            ωg[1]
        elseif tq >= tg[end]
            ωg[ng]
        else
            j = clamp(floor(Int, (tq - tg[1]) / dtg) + 1, 1, ng - 1)
            f = (tq - (tg[1] + (j - 1) * dtg)) / dtg
            ωg[j] * (1 - f) + ωg[j + 1] * f
        end
        ω * omega_mult(tq)
    end

    # Zero the axis on the first SELECTED sample, not on the requested window
    # edge: the requested edge generally falls between trajectory points, which
    # would leave t_internal[1] slightly positive and make `evaluate(w, 0)`
    # extrapolate off the front of the waveform.
    t_ref = r.t[sel[1]]

    t_int = Float64[]
    T_int = Float64[]
    mu_int = Float64[]
    ωbar = Float64[]
    for i in sel
        ω̄ = ω̄_of(r.t[i])
        μ_SI = reservoir_chemical_potential(r.N[i], r.T[i], ω̄, m, a_s)
        push!(t_int, (r.t[i] - t_ref) * ωref)
        push!(T_int, Units.KB * r.T[i] / (Units.HBAR * ωref))
        push!(mu_int, μ_SI / (Units.HBAR * ωref))
        push!(ωbar, ω̄)
    end

    μ_max = maximum(mu_int)
    μ_max < eps_cut || throw(
        ArgumentError(
            "spgpe_reservoir: μ reaches $(round(μ_max; sigdigits=4)) but ϵ_cut = " *
            "½k_cut² = $(round(eps_cut; sigdigits=4)); the C region must extend above μ. " *
            "Raise k_cut to > $(round(sqrt(2 * μ_max); sigdigits=4)) (and the grid with it)."),
    )

    res = SPGPEReservoir(;
        T=PiecewiseLinearWaveform(t_int, T_int),
        mu=PiecewiseLinearWaveform(t_int, mu_int),
        a_s=Float64(a_s) / a_ho, k_cut=Float64(k_cut),
        number_damping, energy_damping, gamma, M,
    )

    # duration is the span actually COVERED by trajectory samples, not the span
    # requested — so a caller that prints it is printing what will be simulated.
    (; reservoir=res, t_internal=t_int, T_int, mu_int,
        N0_ref=r.N0[sel], N_ref=r.N[sel], omega_bar=ωbar,
        duration_s=r.t[sel[end]] - t_ref, duration_internal=t_int[end])
end
