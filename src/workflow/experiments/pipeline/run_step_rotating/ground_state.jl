# Resolve atom name to AtomSpecies via the canonical ATOM_REGISTRY (defined in
# src/workflow/initialization/atoms.jl). Returns nothing if unknown, which
# triggers the manual c0/c_dd interaction path below. Keeps type inference
# narrow: return type is Union{AtomSpecies, Nothing}.
@noinline function _resolve_atom_or_nothing(atom_name::AbstractString)::Union{AtomSpecies, Nothing}
    return try
        SpinorBEC.resolve_atom(Symbol(atom_name))::AtomSpecies
    catch err
        err isa ArgumentError ? nothing : rethrow()
    end
end

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
        _resolve_atom_or_nothing(atom_name)
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
    # N_atoms / omega_ref live inside `interactions:` per current schema
    # (INTERACTIONS_SCHEMA). Older configs put them at top of the GS
    # step, so accept either location.
    n_atoms_node = get(inter, "N_atoms", get(p, "N_atoms", nothing))
    omega_ref_node = get(inter, "omega_ref", get(p, "omega_ref", nothing))
    auto_path =
        atom_obj !== nothing &&
        n_atoms_node !== nothing &&
        omega_ref_node !== nothing
    c0_auto = 0.0;
    c_dd_auto = 0.0;
    γ_auto = 0.0;
    ε_dd_phys = NaN
    N_atoms_int = 0
    ω_ref_val = NaN
    if auto_path
        N_atoms_int = Int(n_atoms_node)
        ω_ref_val = Float64(omega_ref_node)
        c0_auto = compute_c_total(atom_obj; N_atoms=N_atoms_int, omega_ref=ω_ref_val)
        c_dd_auto = compute_c_dd_dimless(atom_obj; N_atoms=N_atoms_int, omega_ref=ω_ref_val)
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom_obj.mass * ω_ref_val))
        ε_dd_phys = compute_a_dd(atom_obj) / atom_obj.a_s
        # Lima-Pelster γ_LHY (only nonzero if ε_dd worth stabilising)
        γ_auto =
            ε_dd_phys > 0.5 ?
            compute_gamma_lhy(atom_obj.a_s / a_ho, ε_dd_phys, N_atoms_int) : 0.0
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
            "  rotating_basis physics: atom=$(atom_obj.name), N=$(N_atoms_int), ω_ref=$(ω_ref_val) rad/s\n";
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

    zee = p["B"]::Dict
    p_z = Float64(get(zee, "p", 0.0))
    q_z = Float64(get(zee, "q", 0.0))

    B_hat = get(p, "B_direction", Dict{String, Any}())::Dict
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

    sm = spin_matrices(F_atom)
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
    elseif atom_obj !== nothing && n_atoms_node !== nothing
        ω_ref = omega_ref_node !== nothing ? Float64(omega_ref_node) : 314.159
        a_ho = sqrt(Units.HBAR / (atom_obj.mass * ω_ref))
        N = Float64(n_atoms_node)
        μ = 0.5 * (15.0 * N * atom_obj.a_s / a_ho)^(2.0 / 5.0)
        ω_axes = ntuple(i -> Float64(V_trap.omega[i]), length(V_trap.omega))
        R_TF = ntuple(i -> sqrt(2.0 * μ / ω_axes[i]^2), length(ω_axes))
        prod_R = prod(R_TF)
        prod_R^(1.0 / length(R_TF))
    else
        1.0  # fallback when R_TF is unavailable
    end
    # `initial_state: from_jld2` short-circuits the Gaussian seed + ITP —
    # the ψ is loaded directly from a prior run's result.jld2 (streamed
    # snapshot layout), letting the user continue a Klaus / EdH run that
    # already paid for the spin-up phase. `init_state_params: {path: ...,
    # snap: last|N}` selects the snapshot; grid + D must match.
    initial_state_str = String(get(p, "initial_state", "polar"))::String
    use_from_jld2 = initial_state_str == "from_jld2"

    psi_init_host = if use_from_jld2
        isp = get(p, "init_state_params", Dict{Any, Any}())::AbstractDict
        path_node = get(isp, "path", nothing)
        path_node !== nothing ||
            throw(ArgumentError("initial_state: from_jld2 requires init_state_params.path"))
        path = String(path_node)::String
        snap = get(isp, "snap", "last")
        loaded = _load_psi_from_jld2(path, snap)
        size(loaded) == (grid.config.n_points..., D) || throw(
            ArgumentError(
                "loaded ψ shape $(size(loaded)) ≠ expected $((grid.config.n_points..., D))" *
                " — grid + D must match the source run",
            ),
        )
        loaded
    else
        # Build Gaussian on host (CPU) then copyto! to device — avoids GPU
        # scalar indexing on every cell. For 32×32×16 grid: ~50 KB host alloc.
        host = zeros(ComplexF64, grid.config.n_points..., D)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            r2 = 0.0
            for d in 1:length(n)
                r2 += grid.x[d][I[d]]^2
            end
            host[I, init_m_idx] = exp(-r2 / (2σ_init^2))
        end
        host
    end
    n_steps = Int(get(p, "n_steps", use_from_jld2 ? 0 : 200))
    dt_itp = Float64(get(p, "dt", 0.005))
    ndim = length(n)

    # UNIFIED (2026-06-21): GS on the STANDARD split-step path (rotating engine
    # retired). Static tilted field B̂=(θ_init,φ_init) via TimeDependentZeeman
    # (eigen-exact, field-axis q). The seed `psi_init_host` is in the tilde basis
    # (m=init_m_idx aligned with B̂); lift it to the lab frame ψ_lab = U_B·ψ̃ for
    # the lab-frame ITP, and transform the converged GS back to tilde for the
    # dynamics handoff.
    psi_lab_seed = Array{Complex{T_float}}(undef, size(psi_init_host)...)
    copyto!(psi_lab_seed, psi_init_host)
    _apply_UB!(psi_lab_seed, sm, Float64(θ_init), Float64(φ_init), ndim)

    atom_ws = if atom_obj === nothing
        AtomSpecies("RotatingBasis", 1.66e-25, F_atom, 0.0, 0.0, 0.0)
    else
        atom_obj
    end
    zee_gs = TimeDependentZeeman(
        ConstantWaveform(p_z * cos(θ_init)), ConstantWaveform(q_z),
        ConstantWaveform(p_z * sin(θ_init) * cos(φ_init)),
        ConstantWaveform(p_z * sin(θ_init) * sin(φ_init)),
    )
    ws = make_workspace(;
        grid, atom=atom_ws,
        interactions=InteractionParams(
            Dict(0 => Float64(c0), 1 => Float64(c1)); c_lhy=Float64(γ)
        ),
        zeeman=zee_gs, potential=NoPotential(),
        sim_params=SimParams(;
            dt=dt_itp, n_steps=max(n_steps, 1), imaginary_time=true, normalize_every=0
        ),
        psi_init=psi_lab_seed,
        enable_ddi=abs(c_dd) > 1e-30, c_dd=Float64(c_dd),
        backend=backend_obj, dtype=T_float,
    )
    copyto!(ws.potential_values, V_trap)

    if verbose
        seed_kind = use_from_jld2 ? "from_jld2" : "gaussian"
        println("  rotating_basis GS (unified→standard split_step!): F=", F_atom,
            " D=", D, " p=", p_z,
            " ε_dd_eff=", round(c_dd * F_atom^2 / (3 * c0); digits=3),
            " seed=", seed_kind, " ITP_steps=", n_steps)
    end

    # Imaginary-time loop with manual norm-decay μ estimate (same definition as
    # the retired rotating ITP: μ = -ln‖ψ‖/(2dt) per step, then renormalize).
    dV_gs = prod(grid.dx)
    μ_final = 0.0
    for _ in 1:n_steps
        split_step!(ws)
        n_before = sqrt(sum(abs2, ws.state.psi) * dV_gs)
        if n_before > 0
            μ_final = -log(n_before) / (2 * dt_itp)
            ws.state.psi ./= n_before
        end
    end

    # ψ̃_GS = U_B(θ_init,φ_init)† ψ_lab_GS — tilde basis for the dynamics handoff.
    psi_tilde_gs = Array{Complex{T_float}}(undef, size(ws.state.psi)...)
    copyto!(psi_tilde_gs, ws.state.psi)
    _apply_UB!(psi_tilde_gs, sm, Float64(θ_init), Float64(φ_init), ndim; inverse=true)
    per_m_gs = [sum(abs2, selectdim(psi_tilde_gs, ndim + 1, c)) * dV_gs for c in 1:D]
    ps_gs = sum(per_m_gs)
    ps_gs > 0 && (per_m_gs ./= ps_gs)

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
        # Handoff to the dynamics step: plain couplings + sm + tilde GS state
        # (NOT a RotatingBasisWS — the engine is retired). Stashed in the
        # Any-typed Dict so it never pollutes PipelineStep dispatch inference.
        :rotating_basis_gs => (
            p=p_z, q=q_z, c0=Float64(c0), c1=Float64(c1), c_dd=Float64(c_dd),
            gamma_lhy=Float64(γ), F=F_atom, sm=sm,
            psi_tilde=psi_tilde_gs, V_trap=V_trap, backend=backend_obj,
        ),
        :rotating_basis_F => F_atom,
        :rotating_basis_mu => μ_final,
        :rotating_basis_per_m => per_m_gs,
        # Stash omega_ref so downstream rotating_basis dynamics steps
        # can convert physical-unit fields ("226 Hz") to dimensionless
        # ratios via _parse_dimless_freq. NaN if manual c0/c_dd path.
        :rotating_basis_omega_ref => auto_path ? ω_ref_val : NaN,
        # Stash atom + N_atoms for downstream loss-block SI→dimless conversion
        # (`K3_per_m_si: ["1e-41 m^6/s", ...]` needs n0 = N/a_ho³ which
        # depends on atom mass + N + ω_ref). Atom may be `nothing` for the
        # manual c0/c_dd path; loss SI conversion will then error explicitly.
        :rotating_basis_atom => atom_obj,
        :rotating_basis_n_atoms => auto_path ? N_atoms_int : nothing,
    )
    # Type assertion: pin to a concrete 4D Complex array (either F32 or F64
    # eltype). Earlier this hard-asserted ComplexF64 to keep downstream
    # inference narrow, but that broke the F32 path. The Complex Union
    # still constrains inference enough to avoid abstract dispatch.
    psi_concrete = psi_tilde_gs::AbstractArray{<:Complex, 4}
    return (psi_concrete, grid, placeholder_atom, nothing, step_result)
end

"""
    _load_psi_from_jld2(path, snap) -> Array{ComplexF64, 4}

Read one snapshot of ψ from a result.jld2 file. Supports the streamed
layout (dynamics/psi_snapshots_streamed/frame_NNNNN) and the older
top-level `psi` storage. `snap` is `"last"` / `:last`, a positive
integer (1-indexed), or negative for from-end (-1 = last).

Used by the `initial_state: from_jld2` recipe on rotating_basis
ground_state to seed a follow-up run from a prior simulation's final
state — extends a 1 s run to 1.5 s without paying the spin-up cost
again.
"""
function _load_psi_from_jld2(path::AbstractString, snap)
    isfile(path) || throw(ArgumentError(
        "initial_state: from_jld2: file not found: $path"
    ))
    jldopen(path, "r") do f
        if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
            n_snaps = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
            idx = if snap === :last || snap == "last"
                n_snaps
            else
                k = Int(snap)
                k < 0 ? n_snaps + 1 + k : k
            end
            (1 <= idx <= n_snaps) || throw(ArgumentError(
                "snap=$idx out of range 1..$n_snaps in $path"
            ))
            key = "dynamics/psi_snapshots_streamed/frame_" * lpad(idx, 5, '0')
            haskey(f, key) || throw(ArgumentError(
                "$key missing in $path"
            ))
            ComplexF64.(f[key])
        elseif haskey(f, "psi")
            ComplexF64.(f["psi"])
        else
            throw(
                ArgumentError(
                    "$path has no recognised ψ storage" *
                    " (expected dynamics/psi_snapshots_streamed/ or top-level psi)",
                ),
            )
        end
    end
end
