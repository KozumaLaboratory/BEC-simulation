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
export incoherent_population, mu_from_total_number
export FeedbackWaveform, number_conserving_callback

"""
    reservoir_chemical_potential(N, T, ω̄, m, a_s; branch=:condensate) -> μ [J]

Chemical potential of a harmonically-trapped Bose gas of `N` atoms at temperature
`T`. Above `T_c` it follows from the ideal-Bose phase-space density,
`Li₃(z) = N(ℏω̄/k_BT)³` with `z = e^{μ/k_BT}` — negative, rising toward `0⁻` as the
gas degenerates. Below `T_c` the two branches differ:

- `:condensate` (default) — the thermal cloud is saturated and `μ` is pinned by
  the condensate, `μ = ½ℏω̄(15N₀a_s/a_ho)^{2/5}` (Thomas–Fermi), with `N₀` from
  [`condensate_split`](@ref). Continuous at the transition: `N₀ → 0` sends this to
  `0` and the ideal branch to `0⁻`.
- `:thermal` — ideal-Bose throughout, i.e. `μ` saturates at `0⁻`.

# `:thermal` FORBIDS condensation — do not reach for it as the "less circular" option

It looks like the principled choice: the SPGPE reservoir is the I region, so take
its `μ` and let `N₀` come out as a prediction. Measured on the euv3 window, it
does not work, and not marginally:

    branch       μ range              drive μ−ε₀ > 0 at
    :condensate  −4.46 → 1.74 (max 10.80)   436/447 points
    :thermal     −4.46 → 0.00 (max  0.00)     0/447 points

An ideal Bose gas caps `μ` at `0`, while the trap ground state sits at
`ε₀ = 3/2 ω̄ = 0.62–1.50`. So `μ − ε₀ < 0` everywhere and the growth term can
never build a condensate: `N₀ ≡ 0` is *imposed*, not predicted.

# The circularity is the ensemble, not this function

The `:condensate` branch does tie the c-field's equilibrium population to the 0-D
`N₀`, so "does a condensate form" is an input. But no choice here fixes that: in a
GRAND-CANONICAL SPGPE, `μ` below `ε₀` forbids a condensate and `μ` above it sets
the equilibrium size through `μ = ε₀ + c₀n₀`. Prescribing `μ` *is* prescribing
`N₀`, whatever `μ` is derived from.

What the c-field genuinely adds on top of a prescribed `μ(t)` is the **lag** —
growth proceeds at finite `γ`, so a ramp faster than `1/γ` leaves the condensate
behind its quasi-static value, which the 0-D model cannot produce. Answering
"how many atoms condense" instead needs a number-conserving formulation, where
`μ(t)` is solved so that `N_C + N_I` matches a measured total; that is not this
function.
"""
function reservoir_chemical_potential(
    N::Real, T::Real, ω̄::Real, m::Real, a_s::Real; branch::Symbol=:condensate
)
    branch in (:condensate, :thermal) ||
        throw(
            ArgumentError(
                "reservoir_chemical_potential: branch must be " *
                ":condensate or :thermal, got $branch",
            ),
        )
    (N <= 0 || T <= 0 || ω̄ <= 0) && return 0.0
    kBT = Units.KB * Float64(T)
    N0, _ = condensate_split(N, T, ω̄)
    if N0 > 0 && branch === :condensate
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
    omega_ref::Real, a_s::Real, k_cut=nothing, cutoff_n_T::Real=0.3,
    mu_branch::Symbol=:condensate,
    t_start=nothing, t_end=nothing, omega_mult=(t -> 1.0),
    number_damping::Bool=true, energy_damping::Bool=true,
    gamma=nothing, M=nothing,
)
    isempty(r.t) && throw(ArgumentError("spgpe_reservoir: empty evaporation trajectory"))
    ωref = Float64(omega_ref)
    m = trap.mass
    a_ho = sqrt(Units.HBAR / (m * ωref))

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
        μ_SI = reservoir_chemical_potential(r.N[i], r.T[i], ω̄, m, a_s; branch=mu_branch)
        push!(t_int, (r.t[i] - t_ref) * ωref)
        push!(T_int, Units.KB * r.T[i] / (Units.HBAR * ωref))
        push!(mu_int, μ_SI / (Units.HBAR * ωref))
        push!(ωbar, ω̄)
    end

    # Cutoff. The DEFAULT tracks the reservoir, ϵ_cut − μ = cutoff_n_T·k_BT, because
    # a cutoff fixed in absolute energy across a ramp with dynamic range in T drives
    # (ϵ_cut−μ)/T up and collapses both rates exponentially — see `tracking_cutoff`.
    # Passing a Number pins it, which is what the earlier run did and why it froze.
    k_cut_wave = if k_cut === nothing
        tracking_cutoff(t_int, mu_int, T_int; n_T=cutoff_n_T)
    else
        _as_waveform(k_cut)
    end
    k_cut_series = [evaluate(k_cut_wave, t) for t in t_int]
    eps_cut_series = 0.5 .* k_cut_series .^ 2

    bad = findall(i -> eps_cut_series[i] <= mu_int[i], eachindex(t_int))
    isempty(bad) || throw(
        ArgumentError(
            "spgpe_reservoir: ϵ_cut ≤ μ at $(length(bad)) of $(length(t_int)) trajectory " *
            "points (worst: ϵ_cut=$(round(eps_cut_series[bad[1]]; sigdigits=4)) vs " *
            "μ=$(round(mu_int[bad[1]]; sigdigits=4))); the C region must extend above μ " *
            "everywhere. Raise k_cut above $(round(sqrt(2 * maximum(mu_int)); sigdigits=4)) " *
            "(and the grid with it), or leave k_cut=nothing to track the reservoir."),
    )

    res = SPGPEReservoir(;
        T=PiecewiseLinearWaveform(t_int, T_int),
        mu=PiecewiseLinearWaveform(t_int, mu_int),
        a_s=Float64(a_s) / a_ho, k_cut=k_cut_wave,
        number_damping, energy_damping, gamma, M,
    )

    # duration is the span actually COVERED by trajectory samples, not the span
    # requested — so a caller that prints it is printing what will be simulated.
    (; reservoir=res, t_internal=t_int, T_int, mu_int,
        k_cut=k_cut_series, eps_cut=eps_cut_series, k_cut_max=maximum(k_cut_series),
        N0_ref=r.N0[sel], N_ref=r.N[sel], omega_bar=ωbar,
        duration_s=r.t[sel[end]] - t_ref, duration_internal=t_int[end])
end

"""
    incoherent_population(mu, T, eps_cut; omega=1.0, n_max=4000) -> Float64

Bose population of the I region — every harmonic level above `eps_cut` — at
chemical potential `mu` and temperature `T`, in internal units:

    N_I(μ,T) = Σ_{n : ε_n > ϵ_cut} g_n / (exp((ε_n − μ)/T) − 1),
    ε_n = (n + 3/2)ω̄,   g_n = (n+1)(n+2)/2

Strictly increasing in `mu` and divergent as `mu → ϵ_cut⁻`, which is what makes
[`mu_from_total_number`](@ref) invertible.
"""
function incoherent_population(mu::Real, T::Real, eps_cut::Real;
    omega::Real=1.0, n_max::Int=4000)
    (T <= 0) && return 0.0
    s = 0.0
    for n in 0:n_max
        ε = (n + 1.5) * Float64(omega)
        ε > eps_cut || continue
        x = (ε - Float64(mu)) / Float64(T)
        x > 0 || return Inf                      # μ above an occupied I level
        x > 60 && break                          # remaining terms are below 1e-26
        s += 0.5 * (n + 1) * (n + 2) / expm1(x)
    end
    s
end

"""
    mu_from_total_number(N_total, N_C, T, eps_cut; omega=1.0) -> Float64

The chemical potential at which the atoms NOT in the c-field fill the I region:
solve `N_I(μ,T) = N_total − N_C` for `μ`. Returns `NaN` when there is no solution.

# Why this and not `reservoir_chemical_potential`

That function maps a total `N` to a `μ` through an assumed equilibrium split — the
Thomas–Fermi branch gives `μ = μ_TF(N₀)`, the thermal branch inverts `Li₃`. Either
way `μ` is computed from `N` under an assumption about how `N` divides, and in a
grand-canonical SPGPE **prescribing `μ` prescribes `N₀`**: `μ < ε₀` forbids a
condensate and `μ > ε₀` fixes the size through `μ = ε₀ + c₀n₀`. So a run built that
way cannot answer "how many atoms condense" — the answer was in the input. That is
why the euv3 evaporation verdict was retracted: it moved with a one-parameter `K₃`
fit and flipped at `K₃/fit ≈ 0.3`.

This takes `N_C` from the field instead. What is prescribed is the **total**, an
extensive measured quantity, and the split is left to the dynamics. The feedback is
restoring rather than circular: a c-field holding few atoms leaves many for the I
region, which at fixed `T` requires a higher `μ`, which drives growth — and the
converse. `N₀` is then an output.

What it does not fix: `N_total(t)` still comes from the 0-D model and still carries
the `K₃` systematic. The difference is that `K₃` now moves the total rather than
deciding whether a condensate exists at all.

Requires `μ < ϵ_cut`, since the lowest I level sits there and a Bose occupation
above it diverges. `NaN` is returned rather than a clamped value when
`N_total ≤ N_C` (nothing left for the reservoir) or when the demand cannot be met
below the cutoff — an unsatisfiable constraint is a fact about the trajectory, not
something to paper over with a default.
"""
function mu_from_total_number(N_total::Real, N_C::Real, T::Real, eps_cut::Real;
    omega::Real=1.0, rtol::Real=1e-8, iters::Int=200)
    N_I_target = Float64(N_total) - Float64(N_C)
    (N_I_target <= 0 || T <= 0) && return NaN

    # ϵ_cut is the pole; bracket strictly below it. The lower end is walked down
    # until the I region is under-filled, so the bracket is found rather than
    # assumed — a hard-coded lower bound would silently fail for a cold reservoir.
    hi = Float64(eps_cut) - 1e-9 * max(abs(eps_cut), 1.0)
    incoherent_population(hi, T, eps_cut; omega) >= N_I_target || return NaN
    lo = hi - Float64(T)
    for _ in 1:60
        incoherent_population(lo, T, eps_cut; omega) < N_I_target && break
        lo -= max(Float64(T), abs(lo))
        lo < -1e12 && return NaN
    end

    for _ in 1:iters
        mid = 0.5 * (lo + hi)
        n = incoherent_population(mid, T, eps_cut; omega)
        (n < N_I_target) ? (lo = mid) : (hi = mid)
        abs(hi - lo) <= rtol * max(abs(hi), 1.0) && break
    end
    0.5 * (lo + hi)
end

"""
    FeedbackWaveform(value) <: Waveform

A waveform whose value is read from a `Ref` at every step, so a controller can
change it while the run is in progress.

`SPGPEReservoir` evaluates `mu` once per step, and a precomputed
`PiecewiseLinearWaveform` is the right representation when `μ(t)` is known in
advance. It is the wrong one for [`mu_from_total_number`](@ref), which needs `N_C`
from the field and therefore cannot be tabulated before the run.
"""
struct FeedbackWaveform <: Waveform
    value::Base.RefValue{Float64}
end
FeedbackWaveform(x::Real=0.0) = FeedbackWaveform(Ref(Float64(x)))
evaluate(w::FeedbackWaveform, ::Float64) = w.value[]
max_frequency(::FeedbackWaveform) = 0.0

"""
    number_conserving_callback(mu_ref, N_total_of, T_of, eps_cut; omega=1.0, every=1)

An `on_step` callback that keeps `mu_ref` at the value where the atoms outside the
c-field fill the I region: `N_I(μ,T) = N_total(t) − N_C(t)`, with `N_C` measured
from the field.

`N_total_of(t)` supplies the total — from a 0-D evaporation trajectory, or from a
measurement. The condensate number is then an OUTPUT of the run rather than a
consequence of the `μ` that was fed in.

When the demand cannot be met — `N_C` already exceeds the total, or the I region
cannot hold the remainder below the cutoff — [`mu_from_total_number`](@ref) returns
`NaN` and this leaves `mu_ref` at its previous value and counts the event. A
trajectory that spends most of its steps unsatisfiable is not describing the
experiment, and `n_unsatisfiable` is what says so; silently clamping would hide
exactly the kind of imposed answer this whole mechanism exists to remove.
"""
function number_conserving_callback(
    mu_ref::Base.RefValue{Float64}, N_total_of, T_of, eps_cut;
    omega::Real=1.0, every::Int=1, counter::Base.RefValue{Int}=Ref(0),
    t_offset::Real=0.0,
)
    function (ws, step, args...)
        step % every == 0 || return nothing
        # t_offset because a c-field run may start PART WAY through a ramp — the
        # classical field cannot represent the hot end of an evaporation at all, so
        # the 0-D model carries the cooling and this takes over for the formation.
        # Without the offset N_total_of and T_of would be read as if the ramp had
        # restarted from zero.
        t = Float64(t_offset) + step * ws.sim_params.dt
        N_C = real(sum(abs2, ws.state.psi)) * cell_volume(ws.grid)
        # eps_cut may be a NUMBER or a FUNCTION of time. It has to be allowed to
        # move: both reservoir coefficients depend on the cutoff only through
        # (eps_cut - mu)/T, so holding it fixed while T falls drives that ratio up and
        # decouples the reservoir — a failure this repo already gates elsewhere. And
        # the controller must use the same cutoff the projector does, or it solves for
        # a mu against an I region the field does not have.
        ec = eps_cut isa Real ? Float64(eps_cut) : Float64(eps_cut(t))
        mu = mu_from_total_number(N_total_of(t), N_C, T_of(t), ec; omega)
        isnan(mu) ? (counter[] += 1) : (mu_ref[] = mu)
        nothing
    end
end
