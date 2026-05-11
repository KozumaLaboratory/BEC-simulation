# Option γ rotating-basis ground_state step: ITP from a Gaussian seed
# in the rotating-basis workspace. Sets up grid, V_trap, B̂ initial
# orientation, and persists ws to pipeline_results for the subsequent
# dynamics step.

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
