# --- active: is this slot part of the computation? ---
#
# ONE file for every method, so "the activity rule lives in one place" is a
# property a test can assert (`all(m.file == @__FILE__ for m in methods(active))`)
# rather than a convention a reviewer has to notice. A second `active` method
# defined next to a term would be the first accretion.
#
# Every predicate delegates to `is_active` (`foundation/thresholds.jl:43`) rather
# than open-coding `!= 0.0`. The tolerance matters and the codebase currently
# disagrees with itself: `make_workspace` gates the centrifugal and Barnett
# shifts on `is_active(Ω, ROTATION_TOL)` and the Coriolis cache on a bare
# `!= 0.0`, in the same function — so an Ω of 1e-16 gets two of the three terms.
# Couplings use `COUPLING_TOL` (1e-30); rotation rates use `ROTATION_TOL` (1e-15).
#
# For a time-dependent knob the test is on `waveform_magnitude`, the largest
# value the knob ever takes — not on its value at t=0, which would drop a pulse
# that starts from rest.

export active, active_slots

"""
    active(spec) -> Bool

Whether the slot contributes to the computation. An inactive slot is omitted
from the serialised model (invariant 3), which is lossless because every spec
constructor normalises an inactive spec to a single canonical representation.
"""
active(::GridSpec) = true          # no inactive value: every computation has a grid
active(::AtomSpecies) = true       # no inactive value: every computation has a species
active(::InteractionSpec) = true   # carries omega_ref, without which nothing is interpretable

active(s::PotentialSpec) = any(f -> any(active, getfield(s, f)), fieldnames(PotentialSpec))

active(s::ZeemanSpec) =
    s.spatial_kind !== :uniform ||
    any(w -> is_active(waveform_magnitude(w)), (s.p, s.q, s.bx, s.by))

active(s::DDISpec) = is_active(s.c_dd)

active(s::LHYSpec) = s.kind !== :none

active(s::RamanSpec) = is_active(waveform_magnitude(s.omega_r))

active(s::LightShiftSpec) = is_active(s.eta_vector) || is_active(s.eta_tensor)

active(s::GradientSpec) = is_active(waveform_magnitude(s.gradient))

active(s::FrameSpec) =
    is_active(s.rotating_omega, ROTATION_TOL) ||
    is_active(s.spin_rotating_omega, ROTATION_TOL)

active(s::GeometrySpec) = s.quasi_2d || is_active(s.absorbing.strength)

active(s::ReservoirSpec) =
    is_active(s.sgpe_gamma) || is_active(s.projection_k_cut) ||
    is_active(s.photon_rate)

# `LossParams` is reused verbatim from `foundation/types/ddi_loss.jl` — it is
# already concrete, non-parametric and immutable. Evaporation needs BOTH of its
# fields, per that type's own docstring.
active(s::LossParams) =
    is_active(s.gamma_dr) || is_active(s.L3) ||
    is_active(s.K3_cubic) || any(is_active, s.L3_per_m) ||
    any(is_active, s.K3_per_m_cubic) ||
    (is_active(s.evap_energy_cutoff) && is_active(s.evap_rate))

# --- trap terms ---

active(s::HarmonicSpec) =
    any(w -> is_active(waveform_magnitude(w)), s.omega) ||
    any(is_active, s.lambda)
active(s::LatticeSpec) = any(is_active, s.depth)
active(s::RingSpec) = is_active(s.strength)
active(s::BoxSpec) = is_active(s.wall_strength)
active(s::GravitySpec) = is_active(s.g)
active(s::DoubleWellSpec) = is_active(s.barrier) || any(is_active, s.omega)
active(s::BeamSpec) = is_active(s.amplitude)
# NOT `is_active`: `polarizability` is SI (J/(W/m²); the calibrated Eu value is
# 5.88e-37, `solvers/evaporation/euv3.jl:36`) while `COUPLING_TOL = 1e-30` is
# documented for DIMENSIONLESS couplings, so `is_active` reads every real
# polarizability as zero. A resolved value has no measurement noise to absorb,
# so the off state is exact zero — and a beam with no power carries no trap.
active(s::DipoleTrapSpec) = s.polarizability != 0.0 && any(b -> b.power != 0.0, s.beams)

"""
    active_slots(m::Model) -> Vector{Symbol}

Slot names that contribute to `m`, in declaration order. This is the set a
fingerprint should digest: a slot nobody used cannot invalidate the result.
"""
active_slots(m::Model) = Symbol[f for f in slots(Model)
             if f in REQUIRED_SLOTS || active(getfield(m, f))]
