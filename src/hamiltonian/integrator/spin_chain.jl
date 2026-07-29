# --- One V half-step as one pass over ψ ---
#
# `_half_potential_step!` builds V(τ) as
#
#     diag(τ/2) · [outer fwd] · DDI(τ) · [outer bwd] · diag(τ/2)
#
# and in the Eu production shape — c₀ + c₁ + DDI, axial field, no higher-rank
# channels — the outer chains reduce to a single spin-mixing rotation each, so
# the whole half-step is
#
#     diag(τ/2) · SM(τ/2) · DDI(τ) · SM(τ/2) · diag(τ/2)
#
# whose middle three factors are the SAME operator exp(-i a (v·F̂)) with
# different vector fields. Applied one at a time that is eight passes of ψ
# through HBM, three recomputations of ⟨F⟩(ψ_mf), and five kernel launches, for
# arithmetic that fits in one lane's registers.
#
# Three things make one pass possible:
#
#  * the midpoint predictor-corrector FREEZES the mean field over the half-step
#    (it passes `psi_mf`), so all three rotations want the same ⟨F⟩ — and the
#    DDI convolution already computes it on its way to Φ;
#  * a spin rotation is unitary, so it cannot change Σ_c|ψ_c|²; with a frozen
#    ψ_mf both diagonal steps therefore carry the identical voxel phase, which
#    can be computed once and multiplied in on the way in and out;
#  * only the per-component Zeeman factor differs between the two diagonal
#    halves, and that is D numbers, not a field.
#
# This is NOT a different splitting. The order, the operators and the arithmetic
# are what `_half_potential_step!` already does — only the round-trips between
# them are removed, so the result is bit-identical, and the gate demands exactly
# that. (`split_step_combined!` in combined_spin_step.jl is the other thing: it
# MERGES the three rotations into one, which is a genuinely different, opt-in
# splitting.)

"""
Switch for the fused realization. ON — it is bit-identical to the unfused
chain, so there is nothing to opt into physically. It exists because a gate
needs to run BOTH statements on the same input
(`test/oracles/test_spin_chain_fusion_parity.jl`), and to leave a one-line
bisect handle if a future backend kernel is ever suspect.
"""
const SPIN_CHAIN_FUSION_ENABLED = Ref(true)

"""
    _spin_chain_reason(ws, ip, psi_mf) -> String or nothing

Why the V half-step cannot be taken as one pass, or `nothing` if it can.

The fused path REPLACES the whole half-step, so this list must cover every
operator `_outer_operators_fwd!`/`_bwd!` can apply beyond the diagonal step and
spin-mixing, and every diagonal-step feature beyond `V + c₀n + scalar LHY` and
a uniform axial Zeeman. **If you add an operator to the outer chain, or a term
to the diagonal step, add it here** — otherwise the fused path would silently
drop it. `test/oracles/test_spin_chain_fusion_parity.jl` pins one arm per entry
and demands bit-identity for the eligible shape.

An entry belongs here only for something that sits BETWEEN the operators, or
that changes the diagonal phase's form. How Φ itself is computed is neither: the
zero-padded, open-boundary convolution gets a branch in the realization instead.
That distinction is load-bearing rather than stylistic — `DDI_PADDED_DEFAULT` is
`true` (9c117c05), so listing it here declined the fusion for every `run_yaml`
RTP run, while `bench/profile_rtp.jl` went on measuring the fused path because
it calls `make_workspace` directly, where `ddi_padding` defaults `false`.
"""
function _spin_chain_reason(ws::Workspace, ip::InteractionParams, psi_mf)
    SPIN_CHAIN_FUSION_ENABLED[] || return "SPIN_CHAIN_FUSION_ENABLED[] is off"
    psi_mf === nothing &&
        return "the mean field is not frozen (no midpoint predictor-corrector)"
    ws.ddi === nothing && return "no DDI substep to fuse with"
    ws.ddi_bufs === nothing && return "no DDI buffers"
    is_active(ip[1]) || return "c₁ = 0, so there is no spin-mixing rotation to fuse"
    is_active(get_cn(ip, 2)) && return "c₂ ≠ 0 (singlet-pair substep sits between them)"
    ws.tensor_cache === nothing || return "tensor channels sit between them"
    ws.raman === nothing || return "Raman sits between them"
    ws.light_shift === nothing || return "light shift sits between them"
    _lhy_needs_spin(ws.lhy) && return "a spatial-LHY spin substep sits between them"
    is_uniform(ws.zeeman) || return "a spatial Zeeman substep sits between them"
    let (bx, by) = transverse_b(ws.zeeman, ws.state.t)
        (bx != 0.0 || by != 0.0) &&
            return "a transverse Zeeman substep sits between them"
    end
    DEALIAS_2_3_ENABLED[] &&
        return "the Orszag F-filter reshapes ⟨F⟩ for DDI but not for spin-mixing"
    ws.magnetic_gradient === nothing ||
        return "a magnetic gradient mutates V around the diagonal step"
    # The fused kernel carries the diagonal phase as `V + c₀n + c·n^{3/2}`, the
    # same closed form the GPU diagonal kernel's `c_lhy` bound admits. A
    # tabulated LHY is a lookup, not that form.
    let l = ws.lhy !== nothing ? ws.lhy : ip.c_lhy
        l isa Union{Nothing, NoLHY, Float64, ScalarLHY} ||
            return "a tabulated LHY is not the closed-form diagonal phase"
    end
    nothing
end

"""
    _spin_chain_available(psi, ws) -> Bool

Whether this backend has a fused realization for `psi`. Asked BEFORE the
forward outer chain runs, since a `true` tells that chain to leave its
spin-mixing substep to `_apply_spin_chain!`. Generic backends say no and get
the operator-by-operator chain, which is the reference the fused kernel is
gated against.
"""
_spin_chain_available(psi, ws::Workspace) = false

"""
    _apply_spin_chain!(psi, ws, dt_half, ndim, imaginary_time, ip, psi_mf,
                       zeeman_diag_fwd, zeeman_diag_bwd)

Apply the whole `diag · SM · DDI · SM · diag` half-step in one pass. Only
called when `_spin_chain_reason` returned `nothing` AND `_spin_chain_available`
was `true`, so there is no generic method: a missing one is a wiring bug, not a
fallback.
"""
function _apply_spin_chain! end
