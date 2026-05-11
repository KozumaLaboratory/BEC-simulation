# Option γ rotating-basis dynamics step: re-uses the GS workspace's
# couplings, hooks up the time-dependent B̂(t) waveforms (theta + phi
# const / ramp / chirp), dispatches the chosen integrator, and records
# observable history (norms, Lz, ⟨F_z⟩, per-m, optional ψ̃ snapshots).

@noinline function _run_rotating_basis_dynamics_inner(
    p::Dict{String, Any}, grid, pipeline_results::Dict;
    verbose::Bool=true,
)
    haskey(pipeline_results, :rotating_basis_ws) || throw(
        ArgumentError(
            "rotating_basis dynamics requires preceding ground_state with kind: rotating_basis"
        ),
    )
    ws_prev = pipeline_results[:rotating_basis_ws]::RotatingBasisWS

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
        0.005   # legacy default
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
    F_atom_int = ws_prev.spin_matrices.system.F
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

    B_hat_node = get(p, "B_hat", Dict{String, Any}())::Dict

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
    F_atom = ws_prev.spin_matrices.system.F
    V_trap = ws_prev.V_trap
    ws = make_rotating_basis_ws(grid, F_atom, V_trap;
        p=ws_prev.p, q=ws_prev.q,
        c0=ws_prev.c0, c1=ws_prev.c1,
        c_dd=ws_prev.ddi_params.C_dd, gamma_lhy=ws_prev.gamma_lhy,
        theta_func=theta_func, phi_func=phi_func,
        theta_dot_func=theta_dot_func, phi_dot_func=phi_dot_func,
        gauge_fix=ws_prev.gauge_fix,
        backend=ws_prev.backend,                  # inherit device from GS
    )
    copyto!(ws.psi_tilde, ws_prev.psi_tilde)

    times_arr = Float64[]
    norms_arr = Float64[]
    Lz_arr = Float64[]
    per_m_arr = Vector{Vector{Float64}}()
    Fz_arr = Float64[]                   # ⟨F_z⟩(t) for EdH conservation
    Fx_arr = Float64[];
    Fy_arr = Float64[]
    # ψ̃ snapshots: optional, controlled by save_psi_snapshots flag.
    # Enables per-m density (Fig 4), spin texture (Fig 3) — heavy memory but
    # only every save_every step, so 200ms × dt=0.005 / save_every=50 = 80 frames.
    save_psi = Bool(get(p, "save_psi_snapshots", true))::Bool
    psi_snapshots = Vector{Array{ComplexF64, 4}}()

    if verbose
        dt_source =
            haskey(p, "dt") ? "explicit" :
            (haskey(p, "epsilon") ? "ε=$(p["epsilon"])" : "default")
        println("  rotating_basis dynamics: ", n_steps, " steps × dt=", round(dt_rtp; sigdigits=3),
            " ($dt_source, integrator=", integrator_name,
            ", θ_repr=", round(θ_repr; digits=3),
            ", φ_omega_repr=", round(φ_omega_repr; digits=3),
            ", save_psi=", save_psi, ")")
    end

    # Integrator dispatch
    evolve_fn = if integrator_name == "strang"
        evolve_rotating!
    elseif integrator_name == "yoshida4"
        evolve_rotating_yoshida4!
    elseif integrator_name == "yoshida6"
        evolve_rotating_yoshida6!
    elseif integrator_name == "cfet4"
        evolve_rotating_cfet4_real!   # experimental, not order-4 in current form
    else
        throw(
            ArgumentError(
                "Unknown integrator '$integrator_name'. Use: strang, yoshida4, yoshida6, cfet4"
            ),
        )
    end

    evolve_fn(ws, n_steps, dt_rtp; t0=0.0,
        on_step=(step, t, w) -> begin
            if step == 1 || step % save_every == 0
                push!(times_arr, t)
                push!(norms_arr, rotating_norm(w))
                if length(grid.config.n_points) == 3
                    push!(Lz_arr, rotating_Lz(w))
                end
                pm = rotating_per_m_norms(w)
                push!(per_m_arr, pm)
                # ⟨F_z⟩ = Σ_m m·N_m (m runs F, F-1, ..., -F as idx 1..D)
                F_val = w.spin_matrices.system.F
                fz_sum = 0.0
                for m_idx in 1:length(pm)
                    fz_sum += (F_val - (m_idx - 1)) * pm[m_idx]
                end
                push!(Fz_arr, fz_sum)
                # ⟨F_x⟩, ⟨F_y⟩ from spinor-resolved current density (defer for now;
                # placeholder zeros — implemented in next analyzer iteration if
                # needed for spin texture animation. Total magnetization
                # in lab frame can be derived via Û_B(t) rotation in post.)
                push!(Fx_arr, 0.0);
                push!(Fy_arr, 0.0)
                if save_psi
                    snap = Array{ComplexF64, 4}(undef, size(w.psi_tilde)...)
                    copyto!(snap, w.psi_tilde)
                    push!(psi_snapshots, snap)
                end
            end
        end,
    )

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
    step_result = Dict{Symbol, Any}(
        :rotating_basis_ws => ws,
        :rotating_basis_F => F_atom,
        :rotating_basis_per_m_final => rotating_per_m_norms(ws),
        :rotating_basis_dynamics => dyn_dict,
    )
    # See note in _run_rotating_basis_ground_state_step: ws stashed in Dict only,
    # psi_tilde concrete-typed (Complex eltype, supports both F32 and F64).
    psi_concrete = ws.psi_tilde::AbstractArray{<:Complex, 4}
    return (psi_concrete, grid, placeholder_atom, nothing, step_result)
end
