# --- Distributionally-robust FORT ramp optimization over operational errors ---
#
# The nominal-optimal evaporation ramp evaporates HARD EARLY, which parks η_start
# just above the eta_min floor — so a small adverse shift in the loaded trap depth
# (α / power calibration low, or T₀ high) drops η_start below the floor and the gas
# no longer evaporates AT ALL (a cliff: N_BEC → 0). `param_uncertainty_ensemble` +
# `optimize_ramp_monotone(...; ensemble=)` already hedge α and K₃; an `EvapScenario`
# generalizes an ensemble member to the full set of things the LAB gets wrong —
# per-beam power calibration (common-mode ≡ α, and beam-to-beam imbalance a crossed
# ODT's two servos cannot hold exactly), ramp timing, and the shot-to-shot scatter
# of the loaded (N₀, T₀). `optimize_ramp_robust` maximizes the WORST-CASE N_BEC over
# a whole scenario set, so the returned schedule keeps its atoms across the apparatus's
# real operating envelope instead of sitting on a cliff.

export EvapScenario, robustness_scenarios, optimize_ramp_robust, robustness_report

"""
    EvapScenario(; trap, p, N0, T0, beam_factor=ones, time_factor=1.0, label="")

One perturbed evaporation evaluation: the `(trap, p, N0, T0)` a candidate ramp is
scored against, with an OPERATIONAL error applied when the ramp is realized —
`beam_factor[b]` multiplies beam `b`'s power at every breakpoint (common-mode ≡ an α
/ absolute-power calibration error; a per-beam split ≡ crossed-ODT imbalance) and
`time_factor` scales the ramp duration (timing error). `N0`/`T0` carry the loaded
scatter. `label` names the axis+sign for reporting. Build the set with
[`robustness_scenarios`](@ref); optimize the worst case with [`optimize_ramp_robust`](@ref).
"""
Base.@kwdef struct EvapScenario
    trap::EvapTrap
    p::EvapParams
    N0::Float64
    T0::Float64
    beam_factor::Vector{Float64} = ones(n_beams(trap))
    time_factor::Float64 = 1.0
    label::String = ""
end

# Apply a scenario's operational error to a candidate ramp: scale each beam's powers
# and the time axis. (A pure-geometry α/K₃ shift lives in the scenario's trap/p, not here.)
function _perturb_ramp(sc::EvapScenario, ramp::FortRamp)
    (all(==(1.0), sc.beam_factor) && sc.time_factor == 1.0) && return ramp
    pw = copy(ramp.powers_W)
    @inbounds for b in 1:size(pw, 1)
        pw[b, :] .*= sc.beam_factor[b]
    end
    FortRamp(ramp.times .* sc.time_factor, pw)
end

# _ramp_score contract, but on the scenario's perturbed evaluation: a scenario that
# misses BEC scores in [−1,0) by how close its peak PSD came to ζ(3); one that reaches
# BEC returns N_BEC. The worst (min) over a scenario set is the robust objective.
function _scenario_score(sc::EvapScenario, ramp::FortRamp)
    _ramp_score(sc.trap, sc.p, _perturb_ramp(sc, ramp), sc.N0, sc.T0)[1]
end

"""
    robustness_scenarios(trap, p; N0, T0, power_frac=0.0, imbalance_frac=0.0,
                         T0_frac=0.0, N0_frac=0.0, time_frac=0.0, K3_hi_factor=1.0)
        -> Vector{EvapScenario}

Build the operational uncertainty set for [`optimize_ramp_robust`](@ref) as
**one-axis-at-a-time extremes** (linear in the number of axes, not the exponential
box of joint corners — the worst case for each cliff is that axis's own adverse
extreme, and a per-axis set protects every cliff without over-pessimizing on rare
joint corners). Each nonzero `*_frac` is a 1-σ (or worst-plausible) fractional
tolerance; the nominal `(trap, p, N0, T0)` is prepended by `optimize_ramp_robust`.
Axes (each adds its adverse extreme, and its benign one where it is informative):

- `power_frac` — absolute FORT power / polarizability calibration (COMMON mode, all
  beams). Since the optical depth is `∝ αP`, a −power_frac common shift is identical to
  α×(1−power_frac): the dominant depth-cliff axis. Adds the −frac scenario (the cliff).
- `imbalance_frac` — beam-to-beam power split a crossed ODT's independent servos cannot
  hold exactly. Adds ±frac applied with OPPOSITE sign per beam (H up / V down and vice
  versa) — the two aspect-ratio extremes.
- `T0_frac` — loaded-temperature scatter. Higher T₀ lowers η_start (adverse); adds +frac.
- `N0_frac` — loaded-number scatter. Lower N₀ lowers the collision rate (adverse); adds −frac.
- `time_frac` — ramp-timing error. Adds ±frac (faster under-evaporates, slower over-loses).
  NOTE physically ~negligible: a nanosecond ARTIQ/DDS grain over a multi-second ramp is
  ~10⁻⁸ fractional (Szmuk/ARTIQ), 6–8 orders below the other axes — default 0, keep it 0
  unless modelling a deliberately coarse schedule.
- `K3_hi_factor` — three-body rate upside (Eu K₃ unmeasured); adds a K₃×factor scenario.
"""
function robustness_scenarios(
    trap::EvapTrap, p::EvapParams; N0::Float64, T0::Float64,
    power_frac::Real=0.0, imbalance_frac::Real=0.0, T0_frac::Real=0.0,
    N0_frac::Real=0.0, time_frac::Real=0.0, K3_hi_factor::Real=1.0)
    nb = n_beams(trap)
    scale_alpha(f) = EvapTrap(; wavelength=trap.wavelength, alpha=trap.alpha * f,
        waists=trap.waists, directions=trap.directions, positions=trap.positions,
        mass=trap.mass, gravity_axis=trap.gravity_axis, gravity_factor=trap.gravity_factor)
    scale_K3(f) = EvapParams(; a_s=p.a_s, tau_bg=p.tau_bg, K3=p.K3 * f,
        eta_min=p.eta_min, heating_rate=p.heating_rate)
    base(; kw...) = EvapScenario(; trap=trap, p=p, N0=N0, T0=T0, kw...)

    scs = EvapScenario[]
    # common-mode power / α — the depth cliff (adverse = low). Implement via α so it
    # perturbs BOTH the light depth and the frequencies exactly (× the ramp powers would too,
    # but α keeps the scenario's own ramp-independent).
    if power_frac > 0
        push!(
            scs,
            EvapScenario(; trap=scale_alpha(1 - power_frac), p=p, N0=N0, T0=T0,
                label="power/α −$(round(Int,100*power_frac))%"),
        )
    end
    # beam imbalance — opposite signs per beam (the two crossed-ODT aspect-ratio extremes)
    if imbalance_frac > 0 && nb >= 2
        up = ones(nb);
        up[1] = 1 + imbalance_frac;
        up[2] = 1 - imbalance_frac
        dn = ones(nb);
        dn[1] = 1 - imbalance_frac;
        dn[2] = 1 + imbalance_frac
        push!(
            scs, base(; beam_factor=up, label="imbalance H+/V− $(round(Int,100*imbalance_frac))%")
        )
        push!(
            scs, base(; beam_factor=dn, label="imbalance H−/V+ $(round(Int,100*imbalance_frac))%")
        )
    end
    T0_frac > 0 && push!(scs, base(; T0=T0 * (1 + T0_frac),
        label="T₀ +$(round(Int,100*T0_frac))%"))                      # hotter ⇒ lower η_start
    N0_frac > 0 && push!(scs, base(; N0=N0 * (1 - N0_frac),
        label="N₀ −$(round(Int,100*N0_frac))%"))                      # fewer ⇒ lower γ_el
    if time_frac > 0
        push!(scs, base(; time_factor=1 - time_frac, label="timing −$(round(Int,100*time_frac))%"))
        push!(scs, base(; time_factor=1 + time_frac, label="timing +$(round(Int,100*time_frac))%"))
    end
    K3_hi_factor > 1 && push!(
        scs,
        EvapScenario(; trap=trap, p=scale_K3(K3_hi_factor), N0=N0, T0=T0,
            label="K₃ ×$(round(K3_hi_factor, digits=1))"),
    )
    scs
end

"""
    optimize_ramp_robust(trap, p, base_ramp; N0, T0, scenarios,
                         frac_bounds=(0.02,1.0), n_sweeps=10, n_line=21,
                         restarts=8, seed=1) -> (; fracs, ramp, result, N_BEC, worst)

Optimize the monotone-decreasing FORT ramp (same physical family as
[`optimize_ramp_monotone`](@ref)) to maximize the **worst-case** N_BEC over the nominal
`(trap, p, N0, T0)` PLUS every [`EvapScenario`](@ref) in `scenarios` — an apparatus-error
uncertainty set built with [`robustness_scenarios`](@ref). A schedule is rewarded only if
it reaches BEC across the WHOLE envelope, so the optimizer first pulls every scenario off
its cliff (any scenario missing BEC scores in [−1,0), dominating the worst-case) and only
then trades toward peak atom number. Warm-started from the lab ramp's own ratios, so the
robust optimum can only match-or-beat it in the worst case.

Returns the drop-fraction matrix, the optimized `FortRamp`, its `EvapResult`/`N_BEC` at the
NOMINAL `(trap, p)`, and `worst` = the worst-case objective across the set (a positive
N_BEC ⇒ every scenario reaches BEC). Inspect the per-scenario breakdown with
[`robustness_report`](@ref).
"""
function optimize_ramp_robust(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    N0::Float64, T0::Float64, scenarios::Vector{EvapScenario},
    frac_bounds::Tuple{Float64, Float64}=(0.02, 1.0),
    n_sweeps::Int=10, n_line::Int=21, restarts::Int=8, seed::Int=1)
    nominal = EvapScenario(; trap=trap, p=p, N0=N0, T0=T0, label="nominal")
    members = vcat([nominal], scenarios)
    function score_ramp(ramp::FortRamp)
        worst = Inf
        for sc in members
            worst = min(worst, _scenario_score(sc, ramp))
        end
        worst
    end
    d = _descend_monotone_family(
        base_ramp, frac_bounds, n_sweeps, n_line, restarts, seed, score_ramp
    )
    _, best_res = _ramp_score(trap, p, d.ramp, N0, T0)
    (fracs=d.fracs, ramp=d.ramp, result=best_res,
        N_BEC=best_res.reached_bec ? best_res.N_BEC : NaN, worst=d.score)
end

"""
    robustness_report(trap, p, ramp; N0, T0, scenarios) -> Vector{NamedTuple}

Per-scenario `(; label, reached_bec, N_BEC, eta_start)` for a fixed `ramp` — the nominal
`(trap,p,N0,T0)` first, then every scenario. Use it to compare a nominal-optimal ramp
against a robust ramp and see WHICH apparatus errors each one survives (`N_BEC = NaN`
where BEC is missed).
"""
function robustness_report(
    trap::EvapTrap, p::EvapParams, ramp::FortRamp;
    N0::Float64, T0::Float64, scenarios::Vector{EvapScenario})
    nominal = EvapScenario(; trap=trap, p=p, N0=N0, T0=T0, label="nominal")
    map(vcat([nominal], scenarios)) do sc
        r = run_evaporation(sc.trap, _perturb_ramp(sc, ramp), sc.p; N0=sc.N0, T0=sc.T0)
        (label=sc.label, reached_bec=r.reached_bec,
            N_BEC=r.reached_bec ? r.N_BEC : NaN, eta_start=r.eta[1])
    end
end
