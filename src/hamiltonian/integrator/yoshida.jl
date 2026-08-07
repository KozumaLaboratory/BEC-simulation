"""
Refuse a composition that the DDI path cannot realise at its nominal order.

`use_mid` swaps the merged ABA product for an un-merged triple jump of symmetric
midpoint cores at the weights `b`. For Yoshida-4/6 and Suzuki those weights ARE
the S2 sub-step sizes and the order carries over; for the two RKN methods
(`:omelyan_pefrl`, `:blanes_moan_srkn6b`) the extra order conditions come from
the a/b interleaving, and the jump collapses to **order 2** — measured, see the
table in `split_step_composers.jl`. That is four to six stages per step for the
order one Strang step already delivers, and nothing said so: the order gate
tested the ABA form, and the DDI path never takes it.

Refusing rather than warning, and rather than silently substituting: an
integrator that quietly runs a different method than the one named is what the
`epsilon:`/`integrator:` mismatch in the rotating handler was, fixed the same
day. No config under `runs/` selects either method.
"""
function _assert_jump_realisable(requested, comp, use_mid::Bool)
    use_mid || return nothing
    jo = get(comp, :jump_order, nothing)
    ord = get(comp, :order, nothing)
    if jo === nothing || ord === nothing
        @warn "composition has no declared jump_order; on the DDI path it is " *
            "composed as a triple jump of S2 cores, which does not preserve " *
            "the order of an RKN method" requested
        return nothing
    end
    jo < ord && throw(
        ArgumentError(
            "composition $(requested) is order $(ord) as an ABA product but " *
            "only order $(jo) as the triple jump of S2 cores that the DDI " *
            "path builds. Use :yoshida (4), :suzuki (4) or :yoshida_s6 (6), " *
            "which keep their order in both forms, or disable the midpoint base.",
        ),
    )
    nothing
end

"""
Adaptive 4th-order Yoshida integration with embedded Strang error estimator.

Uses S₄(dt) as propagator and ‖S₄(dt)ψ - S₂(dt)ψ‖/‖ψ‖ as error estimate.
The difference is dominated by the 3rd-order Strang error, giving a reliable
measure of splitting error that the L2 estimator misses.

PI controller exponent: (tol/err)^{1/(p+1)} with p=4 (4th-order global).
Cost: ~4 Strang steps per accepted step; benefits from larger dt at same accuracy.

!!! note "DDI lab path: midpoint base restores nominal order"
    The plain base `_strang_core!` evaluates the mean field at each inner-V
    substep's entry; on the DDI lab path the central DDI substep's one-sided
    O(τ) error breaks time symmetry and the composition collapses (measured
    ~1.0 for Y4 on Eu151 F=6 spinor+DDI). When DDI is active (and
    `MEANFIELD_MIDPOINT_ENABLED[]`) this routine instead composes the
    time-symmetric midpoint core as an UN-MERGED triple-jump
    (`_composition_midpoint_core!`), recovering the nominal order — measured
    Y4 → 4.0 on Eu F=6 + DDI (`bench/conv_order4c.jl`). The merged-ABA form
    caps at ~2.5 regardless of Picard count; un-merged full-step composition
    is the fix. Without DDI the cheaper merged `_aba_step!` is used (already
    nominal order). The Y4/Y6 coefficients match Yoshida 1990.
"""
function run_simulation_yoshida!(
    ws::Workspace{N};
    adaptive::AdaptiveDtParams=AdaptiveDtParams(),
    t_end::Float64,
    save_interval::Float64,
    callback::Union{Nothing, Function}=nothing,
    composition::Union{Symbol, NamedTuple{(:a, :b)}}=:yoshida,
) where {N}
    n_comp = ws.spin_matrices.system.n_components
    sys = ws.spin_matrices.system
    comp = composition isa Symbol ? _resolve_composition(composition) : composition

    dt = clamp(adaptive.dt_init, adaptive.dt_min, adaptive.dt_max)

    psi_old = similar(ws.state.psi)
    psi_strang = similar(ws.state.psi)

    times = Float64[]
    energies = Float64[]
    norms = Float64[]
    mags = Float64[]
    snapshots = Array{ComplexF64}[]
    _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)

    next_save = ws.state.t + save_interval
    n_accepted = 0
    n_rejected = 0

    while ws.state.t < t_end - 1e-14
        dt_step = min(dt, t_end - ws.state.t)
        remaining_to_save = next_save - ws.state.t
        if remaining_to_save > 1e-14 && remaining_to_save < dt_step
            dt_step = remaining_to_save
        end
        dt_step = max(dt_step, adaptive.dt_min)

        is_clamped = dt_step < dt * 0.99

        psi_old .= ws.state.psi
        t_base = ws.state.t

        # On the DDI lab path the plain composition (mean field at substep
        # entry) collapses below its nominal order; the midpoint base composed
        # as an un-merged triple-jump restores it. The S₂ error estimate uses
        # the matching midpoint core so ‖S_high − S₂‖ stays a clean estimate.
        use_mid = MEANFIELD_MIDPOINT_ENABLED[] && ws.ddi !== nothing

        # n_picard=3: the implicit-midpoint Picard must converge enough that
        # the base is time-symmetric to the order the 4th-order Richardson
        # cancellation needs. Measured Y4 order vs n_picard (Eu F=6 + DDI,
        # bench/conv_order4c.jl): np=1 → 3.85, np=2 → 3.8, np=3 → 3.99. np<3
        # leaves a residual ~3rd-order term.
        if use_mid
            _strang_midpoint_core!(ws, dt_step, n_comp; t_base, n_picard=3)
        else
            _strang_core!(ws, dt_step, n_comp; t_base)
        end
        psi_strang .= ws.state.psi

        ws.state.psi .= psi_old
        if use_mid
            _composition_midpoint_core!(ws, dt_step, n_comp, comp.b; t_base, n_picard=3)
        else
            _aba_step!(ws, dt_step, n_comp, comp.a, comp.b; t_base)
        end

        err = _wavefunction_l2_change(ws.state.psi, psi_strang)

        if !is_clamped && err > adaptive.tol && dt_step > adaptive.dt_min * 1.01
            ws.state.psi .= psi_old
            factor = max(0.3, 0.9 * (adaptive.tol / err)^0.2)
            dt = max(dt_step * factor, adaptive.dt_min)
            n_rejected += 1
            continue
        end

        apply_rt_dissipation!(ws, dt_step, n_comp, N)

        ws.state.t += dt_step
        ws.state.step += 1
        n_accepted += 1

        if !is_clamped
            factor = err > 1e-300 ? min(3.0, 0.9 * (adaptive.tol / err)^0.2) : 3.0
            dt = clamp(dt * factor, adaptive.dt_min, adaptive.dt_max)
        end

        if ws.state.t >= next_save - 1e-14
            E_now = total_energy(ws)
            nrm_now = total_norm(ws.state.psi, ws.grid)
            _check_energy_drift(energies, norms, E_now, nrm_now, ws.state.t)

            push!(times, ws.state.t)
            push!(energies, E_now)
            push!(norms, nrm_now)
            push!(mags, magnetization(ws.state.psi, ws.grid, sys))
            push!(snapshots, copy(ws.state.psi))
            callback !== nothing && callback(ws, n_accepted)
            next_save += save_interval
        end
    end

    if isempty(times) || abs(times[end] - ws.state.t) > 1e-12
        _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)
    end

    (
        result=SimulationResult(times, energies, norms, mags, snapshots),
        n_accepted=n_accepted,
        n_rejected=n_rejected,
        final_dt=dt,
    )
end

"""
    split_step_yoshida4_midpoint!(ws; dt=ws.sim_params.dt)

One 4th-order Yoshida step with the `(ws; dt)` signature `adaptive_step!`
expects, advancing `ws.state.t` by `dt`. On the DDI lab path it composes the
time-symmetric implicit-midpoint core as an un-merged triple-jump (n_picard=3,
the count that makes the base time-symmetric enough for the 4th-order Richardson
cancellation — see `_composition_midpoint_core!`); otherwise the cheaper plain
`_yoshida_core!` (already 4th order without DDI). RTP.

This is the 4th-order base for `adaptive_run!`: with it the Hairer-Wanner defect
estimator and the p=4 controller are consistent, giving a genuinely 4th-order
adaptive integrator on the DDI path (the previous default `split_step_midpoint!`
is only 2nd order, so `adaptive_run!` was 2nd order despite the p=4 controller).
"""
function split_step_yoshida4_midpoint!(ws::Workspace{N}; dt::Float64=ws.sim_params.dt) where {N}
    n_comp = ws.spin_matrices.system.n_components
    t_base = ws.state.t
    if MEANFIELD_MIDPOINT_ENABLED[] && ws.ddi !== nothing
        _composition_midpoint_core!(ws, dt, n_comp, _COMP_YOSHIDA.b; t_base, n_picard=3)
    else
        _yoshida_core!(ws, dt, n_comp; t_base)
    end
    ws.sim_params.imaginary_time || apply_rt_dissipation!(ws, dt, n_comp, N)
    ws.state.t = t_base + dt
    ws.state.step += 1
    nothing
end

export split_step_yoshida4_midpoint!
