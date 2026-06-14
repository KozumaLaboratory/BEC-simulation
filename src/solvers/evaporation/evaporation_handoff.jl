# --- Handoff: evaporation endpoint → GP ground-state trap config ---
#
# When the 0-D model reaches BEC, the final FORT geometry sets the trap the
# condensate lives in. This bridges the SI thermodynamic model to the
# dimensionless GP simulator (ℏ = m = ω_ref = 1): it converts the final per-axis
# trap frequencies to ω/ω_ref, reports the oscillator length a_ho, the BEC atom
# number, and T/T_c, and builds a dimensionless `HarmonicTrap` ready for
# `make_workspace` / `find_ground_state`.

export final_trap_frequencies, bec_handoff, harmonic_trap_dimless

"""
    final_trap_frequencies(trap, ramp) -> (ωx, ωy, ωz) [rad/s]

Per-axis trap frequencies at the end of the ramp (from the final FORT powers).
"""
function final_trap_frequencies(trap::EvapTrap, ramp::FortRamp)
    cdt = _trap_from_powers(trap, fort_power_at(ramp, ramp.times[end]))
    crossed_trap_frequencies(cdt, trap.mass)
end

"""
    bec_handoff(trap, ramp, result; omega_ref=nothing) -> NamedTuple

Parameters to seed a GP ground state from the evaporation endpoint:
- `omega_ref` [rad/s] — reference frequency (default: geometric-mean final trap ω̄)
- `omega_dimless` — `(ωx,ωy,ωz)/ω_ref` for the dimensionless GP `HarmonicTrap`
- `a_ho` [m] — `√(ℏ/(m ω_ref))`
- `N_BEC`, `T_BEC` [K], `T_over_Tc` — `T_BEC / T_c(N_BEC, ω̄)` (≈1 at onset)
"""
function bec_handoff(trap::EvapTrap, ramp::FortRamp, result::EvapResult; omega_ref=nothing)
    # Evaluate the trap at the BEC-onset time (where T_BEC, N_BEC were taken), so
    # T_BEC = T_c(N_BEC, ω̄) holds; the run stops at onset, so this is the trap the
    # condensate first forms in (the final-ramp trap is reached only if onset = ramp end).
    cdt = _trap_from_powers(trap, fort_power_at(ramp, result.t_BEC))
    ωx, ωy, ωz = crossed_trap_frequencies(cdt, trap.mass)
    ω̄ = cbrt(ωx * ωy * ωz)
    ωref = omega_ref === nothing ? ω̄ : Float64(omega_ref)
    m = trap.mass
    a_ho = sqrt(Units.HBAR / (m * ωref))
    Tc = Units.HBAR * ω̄ * (result.N_BEC / _ZETA3)^(1 / 3) / Units.KB
    (omega_ref=ωref,
        omega_dimless=(ωx / ωref, ωy / ωref, ωz / ωref),
        a_ho=a_ho,
        N_BEC=result.N_BEC,
        T_BEC=result.T_BEC,
        T_over_Tc=result.T_BEC / Tc)
end

"""
    harmonic_trap_dimless(trap, ramp, result; omega_ref=nothing) -> HarmonicTrap

The final trap as a dimensionless `HarmonicTrap` (ω in units of `omega_ref`),
ready to pass to `make_workspace(; potential=…)`.
"""
function harmonic_trap_dimless(
    trap::EvapTrap, ramp::FortRamp, result::EvapResult; omega_ref=nothing
)
    HarmonicTrap(bec_handoff(trap, ramp, result; omega_ref=omega_ref).omega_dimless)
end
