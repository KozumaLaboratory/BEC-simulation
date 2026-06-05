# --- Static Zeeman builders ---
#
# Named-kwargs wrappers around `TimeDependentZeeman` to eliminate the
# `(0, 0, p_lab, 0)` positional footgun that surfaced as the M1
# in-plane-vs-Bz misidentification (memory:
# m1_in_plane_bx_disambiguation_2026_06_04). The slot order is
# `TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)` — p is Bz, NOT Bx.
#
# Sign source-of-truth (b_block_builders.jl:27):
#     H_Zeeman = −(g_F μ_B B · F) + q F_z²

export static_zeeman, static_zeeman_lab

"""
    static_zeeman(; Bz=0.0, Bx=0.0, By=0.0, q=0.0) → TimeDependentZeeman

Build a time-independent `TimeDependentZeeman` from dimensionless slot
values. The kwargs correspond directly to the components of the rotated
Zeeman Hamiltonian (sign convention `H = −(g_F μ_B B·F) + q F_z²`):

  * `Bz` (the slot historically named `p`)
  * `q`  (quadratic Zeeman)
  * `Bx`, `By` (transverse)

Use this instead of the 4-arg positional `TimeDependentZeeman(...)`
constructor — names make slot identity explicit and prevent the M1
incident class (p_lab meant Bx, not Bz).
"""
function static_zeeman(;
    Bz::Real=0.0, Bx::Real=0.0, By::Real=0.0, q::Real=0.0
)
    return TimeDependentZeeman(
        ConstantWaveform(Float64(Bz)),
        ConstantWaveform(Float64(q)),
        ConstantWaveform(Float64(Bx)),
        ConstantWaveform(Float64(By)),
    )
end

"""
    static_zeeman_lab(preset; Bz_nT=0.0, Bx_nT=0.0, By_nT=0.0, q=0.0)
        → TimeDependentZeeman

Lab-units convenience: nT → dimensionless via `preset.p_per_nT`. The
quadratic term `q` is still passed dimensionless (auto-derive from |B|²
is the YAML pipeline's job; for scripted runs `q` is usually 0 or
hand-set).
"""
function static_zeeman_lab(
    preset::Preset;
    Bz_nT::Real=0.0, Bx_nT::Real=0.0, By_nT::Real=0.0, q::Real=0.0,
)
    p = preset.p_per_nT
    return static_zeeman(;
        Bz=p * Bz_nT, Bx=p * Bx_nT, By=p * By_nT, q=q
    )
end
