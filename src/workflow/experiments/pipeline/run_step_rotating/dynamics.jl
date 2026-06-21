# Option γ rotating-basis dynamics step: re-uses the GS workspace's
# couplings, hooks up the time-dependent B̂(t) waveforms (theta + phi
# const / ramp / chirp), dispatches the chosen integrator, and records
# observable history (norms, Lz, ⟨F_z⟩, per-m, optional ψ̃ snapshots).

@noinline function _run_rotating_basis_dynamics_inner(
    p::Dict{String, Any}, grid, pipeline_results::Dict;
    verbose::Bool=true,
)
    haskey(pipeline_results, :rotating_basis_gs) || throw(
        ArgumentError(
            "rotating_basis dynamics requires preceding ground_state with kind: rotating_basis"
        ),
    )
    # GS handoff: a plain NamedTuple (couplings + sm + tilde GS state), not a
    # RotatingBasisWS — the rotating engine is retired; both steps run on the
    # standard split-step path. Fields: p,q,c0,c1,c_dd,gamma_lhy,F,sm,psi_tilde,
    # V_trap,backend.
    ws_prev = pipeline_results[:rotating_basis_gs]

    duration = Float64(p["duration"])
    integrator_name = String(get(p, "integrator", _default_rotating_integrator(duration)))::String

    # dt resolution priority:
    #   1. explicit `dt:` in YAML (override)
    #   2. derive from `epsilon:` (target accumulated error) given integrator order
    #   3. sensible default (0.005)
    dt_rtp = if haskey(p, "dt")
        Float64(p["dt"])
    elseif haskey(p, "epsilon")
        ε = Float64(p["epsilon"])
        _dt_from_epsilon(ε, duration, integrator_name)
    else
        0.005   # default when neither ε nor dt is specified
    end
    n_steps = Int(round(duration / dt_rtp))

    # Larmor / Â regime guard: the Y6 ε-formula coefficient (0.1) assumes
    # commutator scales of O(1). For Klaus regime where p × F or
    # |Â| × |H_DDI| scale 10³–10⁵, ε=1e-3 is empirically too coarse and
    # produces non-physical depolarisation (audit 2026-04-28: p_3000
    # ε=1e-3 → 0.997→0.106 thermal scrambling; ε=1e-6 → 0.997→0.999
    # frozen). Warn when the per-step Larmor phase advance exceeds π —
    # the regime where the spin step's exp(-i p F_z dt) wraps inside one
    # solver step and Y6 commutator-error coefficients break the ε scaling.
    # This is a *predictive* check, not enforcing; user can pass an
    # explicit `dt:` to override.
    p_zeeman_abs = abs(ws_prev.p)
    F_atom_int = ws_prev.F
    larmor_phase = p_zeeman_abs * F_atom_int * dt_rtp
    if larmor_phase > π && !haskey(p, "dt")
        # Hard error in the audit-confirmed danger regime (ε ≥ 1e-3,
        # phase ≥ π) — the 2026-04-28 audit showed p=3000 ε=1e-3
        # produced fake-physics m=+F drift 0.997 → 0.106. The user
        # MUST either tighten ε or pass explicit dt.
        ε_used = haskey(p, "epsilon") ? Float64(p["epsilon"]) : NaN
        if !isnan(ε_used) && ε_used >= 1e-3
            throw(
                ArgumentError(
                    "rotating_basis: Larmor phase per step p·F·dt = " *
                    "$(round(larmor_phase; sigdigits=4)) > π combined with " *
                    "ε = $(round(ε_used; sigdigits=2)) ≥ 1e-3. This regime " *
                    "produced fake-physics in the 2026-04-28 audit (m=+F " *
                    "drift 0.997 → 0.106 was numerical, not physical). " *
                    "Tighten to ε ≤ 1e-6, or supply explicit " *
                    "dt < $(round(π / (p_zeeman_abs * F_atom_int); sigdigits=3))."),
            )
        elseif verbose
            # Warn in the marginal regime (ε < 1e-3 but phase > π still
            # near the edge — Y6 may still under-resolve commutator
            # corrections).
            @warn "rotating_basis: Larmor phase advance per step (p·F·dt = " *
                "$(round(larmor_phase; sigdigits=4))) > π with ε = " *
                "$(isnan(ε_used) ? "?" : round(ε_used; sigdigits=2)). " *
                "Y6 ε-formula may underestimate dt; consider ε ≤ 1e-6 " *
                "or explicit dt < $(round(π / (p_zeeman_abs * F_atom_int); sigdigits=3))."
        end
    end
    save_every = _resolve_save_every(p, duration, dt_rtp; n_steps=n_steps)

    B_hat_node = get(p, "B_direction", Dict{String, Any}())::Dict

    # Build θ(t) waveform: either constant or linear ramp. Save scalar
    # representatives (θ_repr, φ_omega_repr) for downstream Berry-connection
    # diagnostic + dyn_dict storage; for ramp/chirp we use the END value
    # (most-relevant for the steady-state portion of the step).
    # Canonical B_hat schema:
    #
    #   B_hat:
    #     theta: <scalar>                            const θ
    #     theta: {from, to, duration}                linear ramp θ
    #     phi:   {rate: <scalar>}                    const dφ/dt
    #     phi:   {rate: {from, to, duration}}        ramp dφ/dt (chirp)
    #
    # The `phi: {rate: ...}` form makes the integrator-relevant quantity
    # (dφ/dt) explicit without naming an axis "phi_dot" — phi is just an
    # angle, and `rate:` is the motion type that says "linearly increasing
    # at this rate".
    ω_ref_dimless = get(pipeline_results, :rotating_basis_omega_ref, NaN)::Float64
    _ω(node) = isnan(ω_ref_dimless) ? Float64(node) :
               _parse_dimless_freq(node, ω_ref_dimless)

    theta_func, theta_dot_func, θ_repr = _parse_b_hat_theta(B_hat_node)
    phi_func, phi_dot_func, φ_omega_repr = _parse_b_hat_phi(B_hat_node, _ω)

    # Build a NEW workspace re-using the same physics couplings + state, but
    # with the time-dep B̂(t) hooked up.
    F_atom = ws_prev.F
    V_trap = ws_prev.V_trap
    # Optional `loss:` block. SI K_3 conversion needs (atom, N_atoms, ω_ref);
    # all three are stashed in pipeline_results by the GS step.
    loss_atom = get(pipeline_results, :rotating_basis_atom, nothing)
    loss_n_atoms = get(pipeline_results, :rotating_basis_n_atoms, nothing)
    loss_omega_ref = get(pipeline_results, :rotating_basis_omega_ref, NaN)
    loss_omega_ref_arg = isnan(loss_omega_ref) ? nothing : loss_omega_ref
    loss_params = _parse_loss_params(get(p, "loss", nothing);
        atom=loss_atom, N_atoms=loss_n_atoms, omega_ref=loss_omega_ref_arg)
    loss_resolved = loss_params === nothing ? LossParams() : loss_params
    # --- UNIFIED PATH (2026-06-21): evolve on the STANDARD split-step path. ---
    # The rotating frame is no longer a separate engine: the standard path now
    # applies the Zeeman eigen-exactly with field-axis q, and `split_step_midpoint!`
    # (implicit-midpoint Picard) reproduces the rotating yoshida6 magnetostir to
    # ~1e-5 per-m at the same dt / step count, p-independently (gated by
    # test_rotating_yoshida6_vs_lab_midpoint.jl + the recorded-array parity gate).
    # We drive a lab-frame TimeDependentZeeman B̂(t)=(θ(t),φ(t)) and record the
    # SAME tilde-basis observables by transforming ψ_lab(t) → ψ̃(t)=U_B(t)†ψ_lab(t),
    # so the :rotating_basis_dynamics dict (consumer contract) is byte-compatible.
    sm = ws_prev.sm
    F_val = F_atom
    N_dim = length(grid.config.n_points)
    p_zee = ws_prev.p
    bz_wf = FunctionWaveform(t -> p_zee * cos(theta_func(t)))
    bx_wf = FunctionWaveform(t -> p_zee * sin(theta_func(t)) * cos(phi_func(t)))
    by_wf = FunctionWaveform(t -> p_zee * sin(theta_func(t)) * sin(phi_func(t)))
    zee_field = TimeDependentZeeman(bz_wf, ConstantWaveform(ws_prev.q), bx_wf, by_wf)

    c_dd_val = ws_prev.c_dd
    atom_for_ws = get(pipeline_results, :rotating_basis_atom, nothing)
    atom_for_ws = if atom_for_ws === nothing
        AtomSpecies("RotatingBasis", 1.66e-25, F_val, 0.0, 0.0, 0.0)
    else
        atom_for_ws
    end
    interactions = InteractionParams(
        Dict(0 => Float64(ws_prev.c0), 1 => Float64(ws_prev.c1));
        c_lhy=Float64(ws_prev.gamma_lhy),
    )

    # ψ_lab(0) = U_B(0) · ψ̃_GS (the GS tilde state, at the t=0 field orientation).
    psi_lab0 = Array{ComplexF64}(undef, size(ws_prev.psi_tilde)...)
    copyto!(psi_lab0, ws_prev.psi_tilde)
    _apply_UB!(psi_lab0, sm, Float64(theta_func(0.0)), Float64(phi_func(0.0)), N_dim)

    ws = make_workspace(;
        grid, atom=atom_for_ws, interactions, zeeman=zee_field,
        potential=NoPotential(),
        sim_params=SimParams(; dt=dt_rtp, n_steps, imaginary_time=false, save_every),
        psi_init=psi_lab0,
        enable_ddi=is_active(c_dd_val), c_dd=Float64(c_dd_val),
        loss=loss_resolved, backend=ws_prev.backend,
    )
    copyto!(ws.potential_values, ws_prev.V_trap)  # reuse the GS trap (array form)

    times_arr = Float64[]
    norms_arr = Float64[]
    Lz_arr = Float64[]
    per_m_arr = Vector{Vector{Float64}}()
    Fz_arr = Float64[]
    Fx_arr = Float64[];
    Fy_arr = Float64[]
    save_block = get(p, "save", Dict{Any, Any}())::AbstractDict
    save_psi = Bool(get(save_block, "psi", true))::Bool
    psi_snapshots = Vector{Array{ComplexF64, 4}}()
    ψtilde = similar(ws.state.psi)   # scratch for the per-save U_B† transform

    if verbose
        dt_source =
            haskey(p, "dt") ? "explicit" :
            (haskey(p, "epsilon") ? "ε=$(p["epsilon"])" : "default")
        println("  rotating_basis dynamics (unified→standard split_step_midpoint!): ",
            n_steps, " steps × dt=", round(dt_rtp; sigdigits=3),
            " ($dt_source, requested=", integrator_name,
            ", θ_repr=", round(θ_repr; digits=3),
            ", φ_omega_repr=", round(φ_omega_repr; digits=3),
            ", save_psi=", save_psi, ")")
    end

    dV = prod(grid.dx)
    _record =
        (step, t) -> begin
            if step == 1 || step % save_every == 0
                push!(times_arr, t)
                push!(norms_arr, sqrt(sum(abs2, ws.state.psi) * dV))
                # ⟨L_z⟩ is invariant under the spatially-uniform spin rotation U_B, so
                # compute it directly on ψ_lab.
                if N_dim == 3
                    push!(Lz_arr, orbital_angular_momentum(ws.state.psi, grid, ws.fft_plans))
                end
                # per-m in the tilde (field-following) frame: ψ̃ = U_B(t)† ψ_lab.
                copyto!(ψtilde, ws.state.psi)
                _apply_UB!(
                    ψtilde,
                    sm,
                    Float64(theta_func(t)),
                    Float64(phi_func(t)),
                    N_dim;
                    inverse=true,
                )
                pm = [sum(abs2, selectdim(ψtilde, N_dim + 1, c)) * dV for c in 1:(2F_val + 1)]
                psum = sum(pm)
                psum > 0 && (pm ./= psum)
                push!(per_m_arr, pm)
                push!(Fz_arr, sum((F_val - (c - 1)) * pm[c] for c in 1:length(pm)))
                push!(Fx_arr, 0.0);
                push!(Fy_arr, 0.0)
                if save_psi
                    snap = Array{ComplexF64, 4}(undef, size(ψtilde)...)
                    copyto!(snap, ψtilde)
                    push!(psi_snapshots, snap)
                end
            end
        end

    for step in 1:n_steps
        split_step_midpoint!(ws)
        _record(step, step * dt_rtp)
    end

    placeholder_atom = AtomSpecies("RotatingBasis", 1.66e-25, F_atom, 0.0, 0.0, 0.0)
    dyn_dict = Dict{Symbol, Any}(
        :times => times_arr,
        :norms => norms_arr,
        :Lz => Lz_arr,
        :Fz => Fz_arr,
        :Fx => Fx_arr,
        :Fy => Fy_arr,
        :per_m_history => per_m_arr,
        :theta_const => θ_repr,
        :phi_omega => φ_omega_repr,
        # Integrator metadata for postmortem analysis: lets a future audit
        # check whether a run was in the Larmor-stiff regime
        # (`p · F · dt > π`) without re-loading the YAML config.
        :dt_used => dt_rtp,
        :integrator => integrator_name,
        :epsilon_target => Float64(get(p, "epsilon", NaN)),
        :p_zeeman => ws_prev.p,
        :F_atom => F_atom_int,
        :larmor_phase_per_step => abs(ws_prev.p) * F_atom_int * dt_rtp,
    )
    if !isempty(psi_snapshots)
        dyn_dict[:psi_snapshots] = psi_snapshots
    end
    # Final tilde state ψ̃(T) = U_B(T)† ψ_lab(T) — the dynamics step's terminal ψ,
    # in the same tilde basis the old rotating engine returned.
    psi_tilde_final = Array{ComplexF64}(undef, size(ws.state.psi)...)
    copyto!(psi_tilde_final, ws.state.psi)
    _apply_UB!(psi_tilde_final, sm, Float64(theta_func(n_steps * dt_rtp)),
        Float64(phi_func(n_steps * dt_rtp)), N_dim; inverse=true)
    per_m_final = if isempty(per_m_arr)
        [sum(abs2, selectdim(psi_tilde_final, N_dim + 1, c)) * dV for c in 1:(2F_val + 1)]
    else
        per_m_arr[end]
    end
    step_result = Dict{Symbol, Any}(
        :rotating_basis_F => F_atom,
        :rotating_basis_per_m_final => per_m_final,
        :rotating_basis_dynamics => dyn_dict,
    )
    return (psi_tilde_final, grid, placeholder_atom, nothing, step_result)
end
