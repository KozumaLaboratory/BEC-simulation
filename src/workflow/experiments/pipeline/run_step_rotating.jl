# --- Option γ rotating-basis step dispatch + chirp helpers ---

# --- Option γ rotating-basis pipeline ---
#
# YAML schema:
#
#   ground_state:
#     kind: rotating_basis
#     atom: Eu151                      # name; pulled to populate F via atom DB
#     grid: {n: [16, 16, 16], box: [12, 12, 12]}
#     potential: {type: harmonic, omega: [1, 1, 1]}
#     interactions: {c0: 100, c1: 0, c_dd: 5, gamma_lhy: 0}
#     zeeman: {p: 5000, q: 0}
#     B_hat: {theta: 0, phi: 0}        # constant B̂ during ITP
#     gauge_fix: false                 # default true; set false to recover ψ_lab=Û_B ψ̃
#     n_steps: 200
#     dt: 0.005
#     init_m_idx: 1                    # start in m=+F (default 1)
#
#   dynamics:
#     kind: rotating_basis
#     duration: 1.0
#     dt: 0.005
#     B_hat:                           # time-dep field. Constant theta + linear phi
#       theta_const: 0.611             # rad
#       phi_omega:  4.524              # rad/dimless. φ(t) = phi_omega * t
#     save_every: 10                   # for trajectory observables (norm, per_m, L_z)
#
# Future-extensible: full waveform spec for theta(t), theta_dot(t),
# phi(t), phi_dot(t) (deferred this session — constant tilt + linear
# rotation covers Klaus magnetostir).

# Concrete callable types instead of closures, to avoid the closure-type
# pollution warned about in memory `pitfall_pipeline_inference.md`. Each
# closure site has a unique type → multiplies specialization combinatorics.
# These are reused across all rotating-basis pipeline runs.
struct _ConstAngle <: Function
    val::Float64
end
(c::_ConstAngle)(::Float64) = c.val

struct _LinearPhi <: Function
    omega::Float64
end
(c::_LinearPhi)(t::Float64) = c.omega * t

struct _ConstZero <: Function end
(::_ConstZero)(::Float64) = 0.0

const _ZERO_FUNC = _ConstZero()

# Linear ramp θ(t) = θ_start + (θ_end - θ_start)·clamp(t/T, 0, 1).
# `θ_dot(t) = (θ_end - θ_start)/T` for t ∈ [0,T], else 0.
struct _LinearRamp <: Function
    start_val::Float64
    end_val::Float64
    duration::Float64
end
(r::_LinearRamp)(t::Float64) =
    r.start_val + (r.end_val - r.start_val) * clamp(t / r.duration, 0.0, 1.0)

struct _LinearRampDot <: Function
    rate::Float64           # = (end - start) / duration
    duration::Float64
end
(r::_LinearRampDot)(t::Float64) = (0.0 ≤ t ≤ r.duration) ? r.rate : 0.0

# Linear chirp φ̇(t) = ω_start + (ω_end - ω_start)·clamp(t/T, 0, 1)
# φ(t) = ω_start·t + (ω_end - ω_start)·t²/(2T) for t ≤ T, then steady ω_end·t after.
struct _LinearChirpPhi <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhi)(t::Float64)
    if t ≤ c.duration
        c.omega_start * t + (c.omega_end - c.omega_start) * t^2 / (2 * c.duration)
    else
        # After ramp ends, phase continues at constant ω_end
        c.omega_start * c.duration + (c.omega_end - c.omega_start) * c.duration / 2 +
        c.omega_end * (t - c.duration)
    end
end

struct _LinearChirpPhiDot <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhiDot)(t::Float64)
    if t ≤ c.duration
        c.omega_start + (c.omega_end - c.omega_start) * t / c.duration
    else
        c.omega_end
    end
end

@noinline function _run_rotating_basis_ground_state_step(
    p::Dict{String, Any}; verbose::Bool=true
)
    grid_node = p["grid"]::Dict
    n = Int.(grid_node["n"])
    box = Float64.(grid_node["box"])

    # Float precision: see V_trap allocation below for context. Grid must
    # match V_trap precision so make_rotating_basis_ws's `T` parameter is
    # consistent across all inputs.
    dtype_str = String(get(p, "dtype", "f64"))::String
    T_float = dtype_str == "f32" ? Float32 : Float64

    grid = make_grid(GridConfig(Tuple(n), Tuple(box)); dtype=T_float)

    pot_node = p["potential"]::Dict
    get(pot_node, "type", "harmonic") == "harmonic" || throw(
        ArgumentError(
            "rotating_basis ground_state currently supports only `potential.type: harmonic`"),
    )
    ω_vec = Float64.(pot_node["omega"])::Vector{Float64}
    length(ω_vec) == length(n) ||
        throw(ArgumentError("potential.omega length must match grid ndim"))

    # T_float was resolved earlier (must match grid precision). Allocate
    # V_trap at the same precision.
    V_trap = zeros(T_float, Tuple(n)...)
    @inbounds for I in CartesianIndices(V_trap)
        V_local = T_float(0)
        for d in 1:length(n)
            x_d = T_float(grid.x[d][I[d]])
            V_local += T_float(ω_vec[d])^2 * x_d^2
        end
        V_trap[I] = T_float(0.5) * V_local
    end

    # --- Physical-parameter path (recommended) ------------------------------
    # Spec: `atom: Eu151` + `N_atoms: 60000` + `omega_ref: 314.159 rad/s`
    # auto-derives c0, c_dd, gamma_lhy via project's canonical helpers.
    # Manual c0/c_dd literals in `interactions:` override the auto-computed
    # values but emit a warning since the convention is easy to get wrong
    # (project uses spinor convention c_dd = μ₀(μ/F)², where the F² returns
    # via spin operators in the Hamiltonian).
    atom_obj = if haskey(p, "atom")
        atom_name = string(p["atom"])::String
        if atom_name == "Eu151"
            ;
            SpinorBEC.Eu151
        elseif atom_name == "Dy164"
            ;
            SpinorBEC.Dy164
        elseif atom_name == "Dy162"
            ;
            SpinorBEC.Dy162
        elseif atom_name == "Cr52"
            ;
            SpinorBEC.Cr52
        elseif atom_name == "Rb87"
            ;
            SpinorBEC.Rb87
        else
            ;
            nothing
        end
    else
        nothing
    end
    F_atom = if haskey(p, "F")
        Int(p["F"])::Int
    elseif atom_obj !== nothing
        atom_obj.F
    else
        1
    end

    inter = p["interactions"]::Dict
    auto_path = atom_obj !== nothing && haskey(p, "N_atoms") && haskey(p, "omega_ref")
    c0_auto = 0.0;
    c_dd_auto = 0.0;
    γ_auto = 0.0;
    ε_dd_phys = NaN
    if auto_path
        N_atoms = Int(p["N_atoms"])::Int
        ω_ref = Float64(p["omega_ref"])
        c0_auto = compute_c_total(atom_obj; N_atoms=N_atoms, omega_ref=ω_ref)
        c_dd_auto = compute_c_dd_dimless(atom_obj; N_atoms=N_atoms, omega_ref=ω_ref)
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom_obj.mass * ω_ref))
        ε_dd_phys = compute_a_dd(atom_obj) / atom_obj.a_s
        # Lima-Pelster γ_LHY (only nonzero if ε_dd worth stabilising)
        γ_auto = ε_dd_phys > 0.5 ?
                 compute_gamma_lhy(atom_obj.a_s / a_ho, ε_dd_phys, N_atoms) : 0.0
    end

    c0 = haskey(inter, "c0") ? Float64(inter["c0"]) : c0_auto
    c_dd = haskey(inter, "c_dd") ? Float64(inter["c_dd"]) : c_dd_auto
    γ = haskey(inter, "gamma_lhy") ? Float64(inter["gamma_lhy"]) : γ_auto
    c1 = Float64(get(inter, "c1", 0.0))

    if verbose && auto_path
        # Show physical ε_dd alongside the dimensionless effective ε_dd_eff
        # (= c_dd·F²/(3·c0)) so user can verify convention immediately.
        ε_dd_eff = c0 > 0 ? c_dd * F_atom^2 / (3 * c0) : NaN
        printstyled(
            "  rotating_basis physics: atom=$(atom_obj.name), N=$(p["N_atoms"]), ω_ref=$(p["omega_ref"]) rad/s\n";
            color=:cyan,
        )
        @printf "    c0=%.3e c_dd=%.3e γ_LHY=%.3e\n" c0 c_dd γ
        @printf "    ε_dd_phys = a_dd/a_s = %.4f, ε_dd_eff (solver) = %.4f  ← MUST match\n" ε_dd_phys ε_dd_eff
    end
    if !auto_path && verbose
        printstyled(
            "  ⚠️  rotating_basis: manual c0/c_dd path (no `atom`+`N_atoms`+`omega_ref`).\n";
            color=:yellow,
        )
        printstyled(
            "       Convention reminder: c_dd uses spinor `μ₀(μ/F)²` (F² returns via spin ops).\n";
            color=:yellow,
        )
    end

    zee = p["zeeman"]::Dict
    p_z = Float64(get(zee, "p", 0.0))
    q_z = Float64(get(zee, "q", 0.0))

    B_hat = get(p, "B_hat", Dict{String, Any}())::Dict
    θ_init = Float64(get(B_hat, "theta", 0.0))
    φ_init = Float64(get(B_hat, "phi", 0.0))
    gauge_fix_flag = Bool(get(p, "gauge_fix", true))

    # Device backend: "cpu" (default) or "gpu"
    backend_name = String(get(p, "backend", "cpu"))::String
    backend_obj = if backend_name == "gpu"
        CUDABackend()
    else
        CPUBackend()
    end

    ws = make_rotating_basis_ws(grid, F_atom, V_trap;
        p=p_z, q=q_z, c0=c0, c1=c1, c_dd=c_dd, gamma_lhy=γ,
        theta_func=_ConstAngle(θ_init), phi_func=_ConstAngle(φ_init),
        theta_dot_func=_ZERO_FUNC, phi_dot_func=_ZERO_FUNC,
        gauge_fix=gauge_fix_flag,
        backend=backend_obj,
    )

    D = 2F_atom + 1
    init_m_idx = Int(get(p, "init_m_idx", p_z > 0 ? 1 : D))::Int
    # Auto-derive init_sigma from Thomas-Fermi radius if user omits.
    # Geomean of per-axis R_TF gives the natural scale for an isotropic
    # Gaussian seed approximating the eventual TF profile:
    #   μ_TF/(ℏω) = 0.5 (15·N·a_s/a_ho)^(2/5)         (isotropic harmonic)
    #   R_TF[d]   = sqrt(2 μ_TF / ω_d²)                (per axis, dimless)
    #   σ_init    = (∏_d R_TF[d])^(1/N_dim)
    σ_init = if haskey(p, "init_sigma")
        Float64(p["init_sigma"])
    elseif atom_obj !== nothing && haskey(p, "N_atoms")
        ω_ref = Float64(get(p, "omega_ref", 314.159))
        a_ho = sqrt(Units.HBAR / (atom_obj.mass * ω_ref))
        N = Float64(p["N_atoms"])
        μ = 0.5 * (15.0 * N * atom_obj.a_s / a_ho)^(2.0 / 5.0)
        ω_axes = ntuple(i -> Float64(V_trap.omega[i]), length(V_trap.omega))
        R_TF = ntuple(i -> sqrt(2.0 * μ / ω_axes[i]^2), length(ω_axes))
        prod_R = prod(R_TF)
        prod_R^(1.0 / length(R_TF))
    else
        1.0  # legacy fallback
    end
    # Build Gaussian on host (CPU) then copyto! to device — avoids GPU scalar
    # indexing on every cell. For 32×32×16 grid this is ~50 KB host alloc.
    psi_init_host = zeros(ComplexF64, grid.config.n_points..., D)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r2 = 0.0
        for d in 1:length(n)
            r2 += grid.x[d][I[d]]^2
        end
        psi_init_host[I, init_m_idx] = exp(-r2 / (2σ_init^2))
    end
    copyto!(ws.psi_tilde, psi_init_host)
    normalize_rotating!(ws)

    n_steps = Int(get(p, "n_steps", 200))
    dt_itp = Float64(get(p, "dt", 0.005))

    if verbose
        println("  rotating_basis GS: F=", F_atom, " D=", D,
            " p=", p_z, " ε_dd_eff=", round(c_dd * F_atom^2 / (3 * c0); digits=3))
    end

    μ_final = find_ground_state_rotating!(ws, n_steps, T_float(dt_itp))

    placeholder_atom = AtomSpecies("RotatingBasis", 1.66e-25, F_atom, 0.0, 0.0, 0.0)
    # IMPORTANT: keep RotatingBasisWS OUT of the return tuple. The 23-type-param
    # Workspace (or our 6-param RotatingBasisWS) propagates through abstract
    # PipelineStep dispatch into make_workspace inference combinatorics, which
    # the memory `pitfall_pipeline_inference.md` documents as a 30+ min hang.
    # Stash ws inside the Dict{Symbol,Any} step_result (Any-typed, inference-safe).
    # Also type-assert psi_tilde to a CONCRETE 4D array — RotatingBasisWS.psi_tilde
    # is declared as `Array{Complex{T}}` (any dim), and an abstract array element
    # in the return tuple pollutes downstream step's psi argument inference.
    step_result = Dict{Symbol, Any}(
        :rotating_basis_ws => ws,
        :rotating_basis_F => F_atom,
        :rotating_basis_mu => μ_final,
        :rotating_basis_per_m => rotating_per_m_norms(ws),
        # Stash omega_ref so downstream rotating_basis dynamics steps
        # can convert physical-unit fields ("226 Hz") to dimensionless
        # ratios via _parse_dimless_freq. NaN if manual c0/c_dd path.
        :rotating_basis_omega_ref => auto_path ? Float64(p["omega_ref"]) : NaN,
    )
    # Type assertion: pin to a concrete 4D Complex array (either F32 or F64
    # eltype). Earlier this hard-asserted ComplexF64 to keep downstream
    # inference narrow, but that broke the F32 path. The Complex Union
    # still constrains inference enough to avoid abstract dispatch.
    psi_concrete = ws.psi_tilde::AbstractArray{<:Complex, 4}
    return (psi_concrete, grid, placeholder_atom, nothing, step_result)
end

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
            throw(ArgumentError(
                "rotating_basis: Larmor phase per step p·F·dt = " *
                "$(round(larmor_phase; sigdigits=4)) > π combined with " *
                "ε = $(round(ε_used; sigdigits=2)) ≥ 1e-3. This regime " *
                "produced fake-physics in the 2026-04-28 audit (m=+F " *
                "drift 0.997 → 0.106 was numerical, not physical). " *
                "Tighten to ε ≤ 1e-6, or supply explicit " *
                "dt < $(round(π / (p_zeeman_abs * F_atom_int); sigdigits=3))."))
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

@noinline function _run_step(
    step::RotatingBasisGroundStateStep,
    psi_prev, grid_prev, atom_prev, ws_prev;
    verbose=true, checkpoint_dir=nothing,
)
    return _run_rotating_basis_ground_state_step(step.params; verbose=verbose)
end

@noinline function _run_step(
    step::RotatingBasisDynamicsStep,
    psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
)
    grid !== nothing || throw(
        ArgumentError(
            "rotating_basis dynamics step requires grid from preceding ground_state step"),
    )
    pipeline_results !== nothing || throw(ArgumentError(
        "rotating_basis dynamics step requires preceding ground_state results"))
    return _run_rotating_basis_dynamics_inner(step.params, grid, pipeline_results;
        verbose=verbose)
end
