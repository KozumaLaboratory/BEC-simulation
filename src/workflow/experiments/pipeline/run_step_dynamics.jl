# --- DynamicsStep dispatch + parsing helpers + streaming ---

# --- DynamicsStep field-resolution helpers ---
#
# Same `@noinline + ::ConcreteType` pattern as the GS helpers above:
# isolate Dict{String,Any} parsing locals from the abstract-dispatch
# inference world that runs `_run_step` (CLAUDE.md "Type stability
# boundaries").

@noinline function _resolve_dyn_absorbing_boundary(p::Dict{String, Any})
    ab_raw = get(p, "absorbing_boundary", nothing)
    ab_raw isa Dict || return nothing
    return AbsorbingBoundary(;
        strength=Float64(ab_raw["strength"]),
        width=Float64(ab_raw["width"]),
        power=Int(get(ab_raw, "power", 2)),
    )
end

@noinline function _resolve_dyn_time_dep_interactions(
    p::Dict{String, Any}, interactions::InteractionParams, duration::Float64
)
    inter_raw = get(p, "interactions", nothing)
    inter_raw isa Dict || return nothing
    c0_spec = get(inter_raw, "c0", nothing)
    c1_spec = get(inter_raw, "c1", nothing)
    (c0_spec isa Dict) || (c1_spec isa Dict) || return nothing
    c0_wf = _make_waveform(c0_spec !== nothing ? c0_spec : interactions[0], duration)
    c1_wf = _make_waveform(c1_spec !== nothing ? c1_spec : interactions[1], duration)
    return TimeDependentInteractions(c0_wf, c1_wf)
end

@noinline function _resolve_dyn_magnetic_gradient(
    p::Dict{String, Any}, ndim::Int, duration::Float64
)
    mg_raw = get(p, "magnetic_gradient", nothing)
    mg_raw isa Dict || return nothing
    grad_spec = mg_raw["gradient"]
    axis = Int(get(mg_raw, "axis", ndim))
    g_F = Float64(get(mg_raw, "g_F", 1.0))
    if grad_spec isa Dict
        wf = _make_waveform(grad_spec, duration)
        return TimeDependentMagneticGradient{ndim}(wf, axis, g_F)
    else
        return MagneticGradient{ndim}(Float64(grad_spec), axis, g_F)
    end
end

function _run_step(
    step::DynamicsStep, psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    live_status_path::Union{Nothing, String}=nothing,
)
    psi_prev !== nothing ||
        throw(ArgumentError("dynamics step requires a preceding ground_state step"))
    grid !== nothing || throw(ArgumentError("dynamics step requires grid from preceding step"))
    p = step.params
    ndim = length(grid.config.n_points)
    F = atom.F

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = _resolve_save_every(p, duration, dt)

    prev_interactions =
        ws_prev !== nothing ? ws_prev.interactions : InteractionParams(Dict{Int, Float64}())
    prev_potential = ws_prev !== nothing ? ws_prev.potential : HarmonicTrap(ntuple(_ -> 1.0, ndim))
    prev_ddi = ws_prev !== nothing ? ws_prev.ddi : nothing
    prev_c_dd = prev_ddi !== nothing ? prev_ddi.C_dd : NaN
    prev_enable_ddi = prev_ddi !== nothing

    ddi_raw = get(p, "ddi", nothing)
    enable_ddi = if ddi_raw === nothing
        prev_enable_ddi
    elseif ddi_raw isa Bool
        ddi_raw
    elseif ddi_raw isa Dict
        Bool(get(ddi_raw, "enabled", prev_enable_ddi))
    else
        prev_enable_ddi
    end
    c_dd_val = if ddi_raw isa Dict && haskey(ddi_raw, "c_dd")
        Float64(ddi_raw["c_dd"])
    else
        prev_c_dd
    end
    # DDI truncation / padding (Tier A/B). Like `secular`, these are not carried
    # on the inherited `DDIParams` (the kernel bakes them in), so dynamics only
    # applies them when an explicit dynamics `ddi:` block requests it; otherwise
    # the bare kernel is rebuilt.
    ddi_trunc = if ddi_raw isa Dict
        _parse_ddi_trunc_radius(get(ddi_raw, "trunc_radius", nothing))
    else
        NaN
    end
    ddi_padded_b = ddi_raw isa Dict ? Bool(get(ddi_raw, "padded", false)) : false
    ddi_pf = ddi_raw isa Dict ? _parse_ddi_pad_factor(get(ddi_raw, "pad_factor", nothing)) : 2.0

    # Match the GS path: route the inner B dict through
    # `_build_zeeman_from_b_block` (:dimless → `_parse_zeeman`,
    # :cartesian / :spherical → Gauss converters). The previous wrapper
    # Dict construction — `Dict("ground_state" => Dict("B" => ...))` —
    # only existed because `_build_phase_zeeman` re-extracts that path,
    # but `_build_zeeman_from_b_block` accepts the inner dict directly.
    z_raw = get(p, "B", Dict())
    zeeman =
        if z_raw isa Dict
            _build_zeeman_from_b_block(z_raw, duration, atom, p)
        else
            ZeemanParams(0.0, 0.0)
        end

    pot_d = get(p, "potential", nothing)
    potential = pot_d !== nothing ? _parse_and_build_potential(pot_d, ndim) : prev_potential

    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    n_steps = round(Int, duration / dt)
    rf_omega = Float64(get(p, "rotating_frame_omega", 0.0))
    # Spin rotating-frame transformation is subsumed by `kind:
    # rotating_basis` (Option γ removes Larmor analytically).
    spin_rf_omega = 0.0
    sp = SimParams(; dt, n_steps, save_every,
        rotating_frame_omega=rf_omega,
        spin_rotating_frame_omega=spin_rf_omega)

    inter = get(p, "interactions", nothing)
    interactions = inter !== nothing ? _parse_gs_interactions(inter, atom) : prev_interactions

    backend = ws_prev !== nothing ? ws_prev.backend : CPUBackend()

    absorbing_boundary = _resolve_dyn_absorbing_boundary(p)

    ls_raw = get(p, "light_shift", nothing)
    light_shift = _parse_light_shift(ls_raw, F, nothing, backend)

    # Loss parser may need (atom, N_atoms, omega_ref) when SI-unit K_3 is used
    inter_raw = get(p, "interactions", Dict{String, Any}())
    n_atoms_for_loss = get(inter_raw, "N_atoms", nothing)
    omega_ref_for_loss = get(inter_raw, "omega_ref", nothing)
    loss = _parse_loss_params(get(p, "loss", nothing);
        atom=atom, N_atoms=n_atoms_for_loss, omega_ref=omega_ref_for_loss)

    raman = _build_raman(p, duration)

    time_dep_interactions = _resolve_dyn_time_dep_interactions(p, interactions, duration)
    magnetic_gradient = _resolve_dyn_magnetic_gradient(p, ndim, duration)

    # Pulse sequence: compile into TimeDep* overrides (type-narrowed to avoid
    # inference blow-up when `run_pipeline` dispatches abstractly on PipelineStep)
    zeeman, raman, time_dep_interactions = _apply_pulse_sequence(
        get(p, "pulse_sequence", nothing), duration, interactions,
        zeeman, raman, time_dep_interactions,
    )

    # LHY in dynamics:
    #   * `lhy:` absent + scalar LHY active in GS: propagates automatically
    #     via `interactions.c_lhy > 0` fallback in `make_workspace`.
    #     Non-scalar LHY does NOT propagate this way and would be silently
    #     dropped — this is the historical foot-gun (see
    #     docs/validation/self_contained_validation_report.md → known
    #     limitations).
    #   * `lhy:` present: build the LHY object explicitly via the same
    #     `spinor_lhy=Symbol` dispatch as GS. Overrides any implicit
    #     inheritance.
    spinor_lhy_mode = let v = get(p, "lhy", nothing)
        v isa Dict ? Symbol(get(v, "kind", "none")) : nothing
    end
    if spinor_lhy_mode === :none
        spinor_lhy_mode = nothing
    end

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman, potential,
        sim_params=sp,
        psi_init=psi_prev,
        enable_ddi, c_dd=c_dd_val, ddi_trunc_radius=ddi_trunc,
        ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
        backend,
        absorbing_boundary,
        light_shift,
        loss,
        raman,
        time_dep_interactions,
        magnetic_gradient,
        spinor_lhy=spinor_lhy_mode,
        lhy_opts=get(p, "lhy_opts", LHYTableOpts())::LHYTableOpts,
    )

    if temp_ratio !== nothing
        psi_noisy = add_thermal_seed(
            ws.state.psi, F; T_over_Tc=temp_ratio, seed=Int(get(p, "noise_seed", 42))
        )
        ws.state.psi .= psi_noisy
    end

    # Hard-polarize: project ψ onto a single m component, zero the rest,
    # renormalise. ITP-converged Fz floats at ~5e-6 below |F| (numerical
    # floor in spin-mixing/DDI bilinear steps); DDI then amplifies that
    # floor in a grid-dependent way, producing a spurious "32 ≡ 48 ≪ 64"
    # ladder. Hard-polarize gives a numerically clean (m=±F) starting
    # state so dynamics-driven transfer can be compared across grids.
    polarize = get(p, "hard_polarize", nothing)
    if polarize !== nothing
        target_m = Float64(polarize)
        target_c = Int(round(F - target_m)) + 1   # c = F - m + 1
        (1 <= target_c <= 2F + 1) ||
            throw(ArgumentError("hard_polarize: m=$(target_m) not in [-F, F]"))
        psi = ws.state.psi
        n_pts_h = ntuple(d -> size(psi, d), ndim)
        D = 2F + 1
        for c in 1:D
            if c != target_c
                idx_c = SpinorBEC._component_slice(ndim, n_pts_h, c)
                view(psi, idx_c...) .= 0
            end
        end
        # Physical-norm renormalisation: ∫|ψ|² dr̃ = sum(|ψ|²) · dV = 1
        dV_h = SpinorBEC.cell_volume(grid)
        norm_sq = sum(abs2, psi) * dV_h
        norm_sq > 0 && (psi ./= sqrt(norm_sq))
    end

    seed_amp = let v = get(p, "seed_amplitude", nothing)
        v === nothing ? nothing : Float64(v)
    end
    if seed_amp !== nothing
        seed_k_cut = let v = get(p, "seed_k_cut", nothing)
            v === nothing ? nothing : Float64(v)
        end
        add_symmetry_breaking_seed!(
            ws.state.psi, F;
            amplitude=seed_amp,
            seed=Int(get(p, "noise_seed", 42)),
            k_cut=seed_k_cut,
            grid=seed_k_cut === nothing ? nothing : grid,
        )
    end

    # Deterministic single-mode seed (grid-convergence diagnostic).
    # Picks the m=dominant±1 transverse component, adds amplitude·peak|ψ|·
    # exp(i k·r + iφ). No RNG → identical seed across grids at fixed (k, φ).
    seed_mode_raw = get(p, "seed_mode", nothing)
    if seed_mode_raw isa Dict
        k_vec = seed_mode_raw["k_vec"]
        amp = Float64(seed_mode_raw["amplitude"])
        phase = Float64(get(seed_mode_raw, "phase", 0.0))
        add_deterministic_mode_seed!(
            ws.state.psi, F;
            k_vec=Tuple(Float64(k) for k in k_vec),
            amplitude=amp,
            grid=grid,
            phase=phase,
        )
    end

    twa_raw = get(p, "twa", nothing)
    if twa_raw !== nothing
        twa_config = _parse_twa_config(twa_raw)
        store_traj = Bool(get(twa_raw, "store_trajectories", false))
        ensemble = run_twa(;
            psi_gs=psi_prev, grid, atom, interactions, zeeman, potential,
            sim_params=sp, twa_config, enable_ddi, c_dd=c_dd_val, backend,
            store_trajectories=store_traj, verbose,
        )

        verbose && @printf("  TWA ensemble: %d trajectories, %d snapshots\n",
            ensemble.n_trajectories, length(ensemble.times))

        # Hand the last-trajectory SimulationResult to downstream steps so
        # the canonical auto-save (`_concat_dynamics_phases`) streams the
        # Phase-2 snapshots that `run_simulation!` already accumulated.
        # Pull the post-evolution ψ from `psi_snapshots[end]` — that's the
        # last frame run_simulation! recorded; for the typical case where
        # save_every divides n_steps it equals `ws.state.psi` exactly.
        traj = ensemble.last_trajectory
        psi_out = if traj !== nothing && !isempty(traj.psi_snapshots)
            copy(traj.psi_snapshots[end])
        else
            copy(psi_prev)
        end
        step_result = Dict{Symbol, Any}(
            :ensemble_result => ensemble,
            :dynamics_workspace => ws,
            :dynamics_result => traj,
            :save_psi_snapshots => traj !== nothing && !isempty(traj.psi_snapshots),
            :snapshot_tmp_path => nothing,
            :snapshot_count => traj === nothing ? 0 : length(traj.psi_snapshots),
        )
        return (psi_out, grid, atom, ws, step_result)
    end

    # Unified `save:` block reads — see schema.jl SAVE_SCHEMA.
    save_block = get(p, "save", Dict{Any, Any}())::AbstractDict
    save_psi_snap = Bool(get(save_block, "psi", false))
    save_compress = Bool(get(save_block, "compression", false))
    snap_precision_str = String(get(save_block, "precision", "f32"))
    snap_precision_cf =
        if snap_precision_str == "f64"
            ComplexF64
        elseif snap_precision_str == "f32"
            ComplexF32
        else
            throw(
                ArgumentError(
                    "save.precision must be \"f32\" or \"f64\", got " *
                    snap_precision_str,
                ),
            )
        end

    cb_sgpe = _build_sgpe_callback(get(p, "sgpe", nothing), Float64(sp.dt))
    cb_pgp = _build_pgp_callback(get(p, "projected_gp", nothing))
    cb_photon = _build_photon_callback(get(p, "photon_scattering", nothing), Float64(sp.dt))
    # live_monitor defaults ON (every=50). Disable explicitly with
    # `live_monitor: false` for batch / TSUBAME / no-dashboard runs.
    cb_live = _build_live_callback(get(p, "live_monitor", true), live_status_path)
    extra_cb = _compose_callbacks(cb_sgpe, cb_pgp, cb_photon, cb_live)

    result, snap_tmp_path, snap_count = _run_dynamics_with_optional_streaming!(
        ws, save_psi_snap, save_compress, snap_precision_cf;
        extra_on_step=extra_cb,
    )

    if verbose
        println("  $(n_steps) steps, E_final=$(round(result.energies[end]; sigdigits=6))")
        flush(stdout);
        ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
    end

    psi_out = copy(ws.state.psi)
    step_result = Dict{Symbol, Any}(
        :dynamics_result => result,
        :dynamics_workspace => ws,
        :save_psi_snapshots => save_psi_snap,
        :save_snapshot_compression => save_compress,
        :snapshot_tmp_path => snap_tmp_path,
        :snapshot_count => snap_count,
    )
    (psi_out, grid, atom, ws, step_result)
end

"""
    _run_dynamics_with_optional_streaming!(ws, save_psi, compress)
        -> (result, tmp_path_or_nothing, snapshot_count)

When `save_psi` is false, run the simulation the normal way. When true,
open a scratch JLD2 file for snapshot streaming before the sim, install
an on_snapshot callback that downcasts to ComplexF32 and writes one
frame per key, then close the file. Peak host RAM while dynamics runs
is now one snapshot (~26 MB at 64³×13) instead of the full accumulated
vector (~8 GB at 154 snapshots).
"""
function _run_dynamics_with_optional_streaming!(
    ws, save_psi::Bool, compress::Bool,
    snap_type::Type{<:Complex}=ComplexF32;
    extra_on_step::Union{Nothing, Function}=nothing,
)
    if !save_psi
        cb = extra_on_step === nothing ? nothing :
             SimulationCallbacks(; on_step=extra_on_step)
        return (run_simulation!(ws; callbacks=cb), nothing, 0)
    end

    snap_tmp = _dynamics_scratch_path()
    jld_kwargs = compress ? (; compress=ZlibCompressor()) : (;)
    snap_file = jldopen(snap_tmp, "w"; jld_kwargs...)

    n_pts = ntuple(d -> size(ws.state.psi, d), ndims(ws.state.psi) - 1)
    D = size(ws.state.psi, ndims(ws.state.psi))
    snap_file["spatial_shape"] = collect(n_pts)
    snap_file["n_components"] = D
    snap_file["snap_eltype"] = string(snap_type)

    buf = Array{snap_type}(undef, n_pts..., D)
    frame_count = Ref(0)

    on_snap = function (_ws, _step, psi_snap)
        frame_count[] += 1
        buf .= snap_type.(psi_snap)
        snap_file["frame_" * lpad(string(frame_count[]), 5, '0')] = buf
        return nothing
    end

    result = try
        run_simulation!(
            ws;
            callbacks=SimulationCallbacks(;
                on_snapshot=on_snap,
                on_step=extra_on_step,
            ),
            stream_snapshots=true,
        )
    finally
        snap_file["n_snapshots"] = frame_count[]
        close(snap_file)
    end

    return (result, snap_tmp, frame_count[])
end
