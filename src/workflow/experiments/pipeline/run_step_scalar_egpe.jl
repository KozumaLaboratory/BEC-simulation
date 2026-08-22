# --- Scalar eGPE (adiabatic spin elimination) step dispatch ---
#
# The Larmor-fast limit: |Ψ(r,t)⟩ = ψ(r,t)·|B̂(t)⟩_F, leaving a one-component
# GPE with a dipolar kernel whose polarization axis moves. Use it when
# `recommend_spin_treatment` says `:scalar_adiabatic` — for Klaus-class
# magnetostirring that is by a factor of ~10⁴ in the scale hierarchy, and the
# spinor path would pay ~10⁴× the cost to resolve a sub-cycle the limit
# averages away. `docs/validation/klaus2022_primary_source.md` §4 has the
# numbers for the case this was built for.
#
# Isolation pattern is the same as binary / rotating_basis: concrete step types
# so the spinor `_run_step` inference world is not widened by these returns.

# Ω(t) protocol for the polarization axis. `omega`, `ramp_rate` and the θ ramp
# are all in reference units (Ω/ω_ref, ω_ref², 1/ω_ref) — Klaus's
# Ω̇ = 2π×50 Hz/s at ω_ref = 2π×50 Hz is `ramp_rate: 0.0031831`, which reaches
# Ω = ω_⊥ in exactly 1 s.
struct StirProtocol
    theta::Float64            # polar angle of B̂ (rad)
    theta_final::Float64      # target polar angle for the spiral-up phase
    theta_ramp_start::Float64 # when the θ ramp begins (∞ ⇒ never)
    theta_ramp_time::Float64  # its duration
    omega::Float64            # final Ω/ω_ref
    ramp_rate::Float64        # dΩ/dt; 0 ⇒ sudden start at `omega`
    phi0::Float64
end

function StirProtocol(d::AbstractDict)
    ω = Float64(get(d, "omega", 0.0))
    rate = Float64(get(d, "ramp_rate", 0.0))
    rate >= 0 || throw(ArgumentError("stir.ramp_rate must be ≥ 0, got $rate"))
    θ = Float64(get(d, "theta", 0.0))
    θf = Float64(get(d, "theta_final", θ))
    t0 = haskey(d, "theta_ramp_start") ? Float64(d["theta_ramp_start"]) : Inf
    tr = Float64(get(d, "theta_ramp_time", 0.0))
    (θf != θ && !isfinite(t0)) && throw(
        ArgumentError(
            "stir.theta_final differs from stir.theta but theta_ramp_start is unset — " *
            "the tilt would never happen and the run would silently be the wrong protocol"),
    )
    StirProtocol(θ, θf, t0, tr, ω, rate, Float64(get(d, "phi0", 0.0)))
end

"""Instantaneous rotation frequency Ω(t) of the polarization axis."""
function stir_omega(s::StirProtocol, t::Real)
    s.ramp_rate <= 0 && return s.omega
    min(s.omega, s.ramp_rate * t)
end

"""Accumulated azimuth φ(t) = φ₀ + ∫₀ᵗ Ω dt′ — integrated in closed form, not
stepped, so the axis is exact at any `t` a substep asks for."""
function stir_phi(s::StirProtocol, t::Real)
    if s.ramp_rate <= 0
        return s.phi0 + s.omega * t
    end
    t_r = s.omega / s.ramp_rate
    t <= t_r ? s.phi0 + s.ramp_rate * t^2 / 2 :
    s.phi0 + s.omega * t_r / 2 + s.omega * (t - t_r)
end

"""Polar angle θ(t): constant until `theta_ramp_start`, then linear to
`theta_final` (Klaus Fig. 4d "spiral up the magnetic field")."""
function stir_theta(s::StirProtocol, t::Real)
    (isfinite(s.theta_ramp_start) && t > s.theta_ramp_start) || return s.theta
    s.theta_ramp_time <= 0 && return s.theta_final
    f = min(1.0, (t - s.theta_ramp_start) / s.theta_ramp_time)
    s.theta + f * (s.theta_final - s.theta)
end

"""B̂(t) as the scalar propagator wants it."""
function stir_axis(s::StirProtocol, t::Real)
    θ = stir_theta(s, t);
    φ = stir_phi(s, t)
    SVector(sin(θ) * cos(φ), sin(θ) * sin(φ), cos(θ))
end

# --- Coupling assembly ---
#
# Every coefficient delegates to the existing single declaration:
# `compute_c_dd_dimless` (× F² for the full moment, the scalar convention its
# own docstring states), `scalar_lhy_coefficient` for Lima-Pelster Q₅, and the
# same c₀ = 4π(a_s/a_ho)N as the spinor path. Nothing is restated here.
function _scalar_egpe_couplings(p::AbstractDict)
    atom_name = Symbol(get(p, "atom", "Dy162"))
    base = resolve_atom(atom_name)
    inter = get(p, "interactions", Dict{String, Any}())
    N = Int(get(inter, "N_atoms", 10000))
    omega_ref = Float64(get(inter, "omega_ref", 1.0))
    omega_ref > 0 || throw(ArgumentError("interactions.omega_ref must be > 0"))
    a_ho = sqrt(Units.HBAR / (base.mass * omega_ref))

    # `a_s` is in BOHR RADII, the unit every paper quotes it in. Klaus's
    # a_s = 111(9) a₀ is itself fitted against simulations of this family, so
    # it is an input, not a knob — see the primary-source doc §2.
    a_s = haskey(p, "a_s") ? Float64(p["a_s"]) * Units.BOHR_RADIUS : base.a_s
    a_s > 0 || throw(ArgumentError("a_s must be > 0, got $(a_s)"))

    ddi_node = get(p, "ddi", false)
    ddi_on = ddi_node isa Bool ? ddi_node : Bool(get(ddi_node, "enabled", true))
    c_dd = ddi_on ?
           compute_c_dd_dimless(base; N_atoms=N, omega_ref=omega_ref) * base.F^2 : 0.0
    eps_dd = ddi_on ? compute_a_dd(base) / a_s : 0.0

    lhy_node = get(p, "lhy", Dict{String, Any}())
    lhy_kind = lhy_node isa AbstractDict ? String(get(lhy_node, "kind", "none")) : "none"
    γ = if lhy_kind == "none"
        0.0
    elseif lhy_kind == "scalar"
        scalar_lhy_coefficient(a_s / a_ho, N; eps_dd=eps_dd)
    else
        throw(
            ArgumentError(
                "scalar_egpe supports lhy.kind ∈ {none, scalar}; got '$lhy_kind'. " *
                "The spinor closed forms assume a spinor ansatz this path has eliminated."),
        )
    end

    (atom=base, N=N, omega_ref=omega_ref, a_ho=a_ho, a_s=a_s,
        g_contact=4π * (a_s / a_ho) * N, c_dd=c_dd, eps_dd=eps_dd, gamma_lhy=γ)
end

function _scalar_egpe_grid_and_trap(p::AbstractDict)
    g = p["grid"]
    n = Tuple(Int.(g["n"]))
    box = Tuple(Float64.(g["box"]))
    length(n) == 3 || throw(ArgumentError("scalar_egpe is 3D only; got n = $n"))
    grid = make_grid(GridConfig(n, box))
    pot = get(p, "potential", Dict{String, Any}())
    ω = if pot isa AbstractDict && get(pot, "type", "harmonic") == "harmonic"
        Tuple(Float64.(get(pot, "omega", [1.0, 1.0, 1.0])))
    else
        throw(ArgumentError("scalar_egpe supports potential.type = harmonic only"))
    end
    V = [
        0.5 * (ω[1]^2 * x^2 + ω[2]^2 * y^2 + ω[3]^2 * z^2)
        for x in grid.x[1], y in grid.x[2], z in grid.x[3]
    ]
    (grid, V, ω)
end

# --- Ground state ---

@noinline function _run_step(
    step::ScalarEGPEGroundStateStep, psi_prev, grid_prev, atom_prev, ws_prev;
    verbose=true, checkpoint_dir=nothing,
)
    p = step.params
    c = _scalar_egpe_couplings(p)
    grid, V, ω_trap = _scalar_egpe_grid_and_trap(p)

    pad = get(p, "ddi_pad", nothing)
    ws = make_scalar_ws(grid, V;
        g_contact=c.g_contact, c_dd=c.c_dd, F=1.0, gamma_lhy=c.gamma_lhy,
        ddi_pad=(pad === nothing ? nothing : Tuple(Int.(pad))))
    # F is folded into c_dd above (the scalar kernel weight is c_dd·F²), so the
    # workspace carries F = 1. Keeping the split would give two places where the
    # full moment is assembled.

    stir = StirProtocol(get(p, "B_direction", Dict{String, Any}()))
    B_hat = stir_axis(stir, 0.0)

    # Thomas-Fermi seed: ITP from a uniform state on a dipolar problem wanders
    # for thousands of steps before it finds the cloud.
    @inbounds for I in CartesianIndices(ws.psi)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        μ_guess = 10.0
        v = μ_guess - 0.5 * (ω_trap[1]^2 * x^2 + ω_trap[2]^2 * y^2 + ω_trap[3]^2 * z^2)
        ws.psi[I] = v > 0 ? sqrt(v) + 0im : 0im
    end
    normalize_scalar!(ws)

    dt = Float64(get(p, "dt", 0.002))
    n_steps = Int(get(p, "n_steps", 4000))
    μ = find_ground_state_scalar!(ws, n_steps, dt; B_hat=B_hat)
    E = scalar_energies(ws, B_hat)
    shape = planar_aspect_ratio(ws)

    verbose && println("  scalar eGPE ground state: μ = ", round(μ, digits=4),
        "  E = ", round(E.total, digits=4),
        "  AR_xy = ", round(shape.ratio, digits=4),
        "  σ_max = ", round(shape.sigma_max, digits=4),
        "  AR_z = ", round(scalar_aspect_ratio(ws), digits=4))

    report = spin_treatment_report(c.atom;
        B_gauss=Float64(get(p, "B_magnitude_gauss", 0.0)),
        omega_ref=c.omega_ref, mu_dimless=μ,
        f_trap_hz=maximum(ω_trap) * c.omega_ref / 2π,
        f_drive_hz=stir.omega * c.omega_ref / 2π, dt_physics=dt)

    psi_4d = reshape(ws.psi, (size(ws.psi)..., 1))
    step_result = Dict{Symbol, Any}(
        :scalar_ws => ws,
        :scalar_stir => stir,
        :scalar_couplings => c,
        :scalar_trap_omega => ω_trap,
        :scalar_gs => (mu=μ, energies=E, aspect_ratio_xy=shape.ratio,
            aspect_angle=shape.angle, sigma_max=shape.sigma_max,
            sigma_min=shape.sigma_min, aspect_ratio_z=scalar_aspect_ratio(ws)),
        :spin_treatment => report,
    )
    return (psi_4d, grid, c.atom, nothing, step_result)
end

# --- Dynamics ---

@noinline function _run_step(
    step::ScalarEGPEDynamicsStep, psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
    live_status_path::Union{Nothing, String}=nothing,
)
    pipeline_results !== nothing && haskey(pipeline_results, :scalar_ws) || throw(
        ArgumentError(
            "scalar_egpe dynamics requires a preceding " *
            "`ground_state` step with `kind: scalar_egpe`",
        ))
    return _run_scalar_egpe_dynamics(step.params, pipeline_results;
        verbose=verbose, live_status_path=live_status_path)
end

@noinline function _run_scalar_egpe_dynamics(
    p::Dict{String, Any}, results::Dict;
    verbose::Bool=true, live_status_path::Union{Nothing, String}=nothing,
)
    ws = results[:scalar_ws]
    gs_stir = results[:scalar_stir]::StirProtocol
    c = results[:scalar_couplings]

    stir = haskey(p, "B_direction") ? StirProtocol(p["B_direction"]) : gs_stir
    duration = Float64(p["duration"])
    dt = Float64(get(p, "dt", 0.002))
    n_steps = max(1, round(Int, duration / dt))
    save_node = get(p, "save", Dict{String, Any}())
    save_every = Int(get(save_node, "every", max(1, n_steps ÷ 200)))
    save_density = Bool(get(save_node, "column_density", false))

    seed_info = nothing
    wig = get(p, "wigner_seed", nothing)
    if wig isa AbstractDict
        seed_info = seed_scalar_thermal!(ws;
            kT=Float64(get(wig, "kT", 0.0)),
            omega=results[:scalar_trap_omega]::NTuple{3, Float64}, n_atoms=c.N,
            seed=haskey(wig, "seed") ? Int(wig["seed"]) : nothing,
            e_cut_ratio=Float64(get(wig, "e_cut_ratio", 2.0)), verbose=verbose)
    end

    times = Float64[];
    ar = Float64[];
    ar_angle = Float64[]
    lz = Float64[];
    norms = Float64[];
    omegas = Float64[]
    cols = Array{Float64, 2}[]

    function record!(t)
        s = planar_aspect_ratio(ws)
        push!(times, t);
        push!(ar, s.ratio);
        push!(ar_angle, s.angle)
        push!(lz, scalar_Lz(ws));
        push!(norms, scalar_norm(ws))
        push!(omegas, stir_omega(stir, t))
        save_density && push!(cols, scalar_column_density(ws))
        nothing
    end
    record!(0.0)

    B_func = t -> stir_axis(stir, t)
    t = 0.0
    # Progress + ETA (#408). This is the path whose silence cost 2 h × 3 jobs on
    # 2026-08-20: it printed `Step 2/2: ScalarEGPEDynamicsStep` and then nothing
    # for 110 minutes. Its own `verbose` line below fires every `save_every*10`
    # steps, which at 128³ is once per many minutes and carries neither a
    # fraction nor an ETA.
    cb_progress = _build_progress_reporter("scalar_egpe", n_steps, duration)
    for step_i in 1:n_steps
        split_step_scalar!(ws, dt, t, B_func)
        t += dt
        _progress!(cb_progress, step_i, t)
        if step_i % save_every == 0 || step_i == n_steps
            record!(t)
            isfinite(norms[end]) || throw(ErrorException(
                "NaN in scalar eGPE dynamics at t = $t (step $step_i)"))
            if live_status_path !== nothing
                _emit_live_status(live_status_path; step=step_i, t=t,
                    norm=norms[end],
                    norm_drift=abs(norms[end] - norms[1]) / max(norms[1], eps()))
            end
            verbose && step_i % (save_every * 10) == 0 &&
                println(
                    "    t = ", round(t, digits=2), "  Ω = ", round(omegas[end], digits=4),
                    "  AR = ", round(ar[end], digits=4), "  Lz = ", round(lz[end], digits=3))
        end
    end

    psi_4d = reshape(ws.psi, (size(ws.psi)..., 1))
    step_result = Dict{Symbol, Any}(
        :scalar_ws => ws,
        :scalar_stir => stir,
        :scalar_egpe_dynamics => (times=times, aspect_ratio=ar,
            aspect_angle=ar_angle, Lz=lz, norms=norms, omega=omegas,
            column_density=cols, dt=dt, duration=duration,
            wigner_seed=seed_info),
    )
    return (psi_4d, ws.grid, _scalar_results_atom(results), nothing, step_result)
end

_scalar_results_atom(results::Dict) =
    haskey(results, :scalar_couplings) ? results[:scalar_couplings].atom : nothing
