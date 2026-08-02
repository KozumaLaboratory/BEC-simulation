# --- Miscellaneous analyzers ---
#
# `summary_json` is the only analyzer that needs the full
# `pipeline_results` dict — it dumps the accumulated step results
# plus user-supplied extras to a JSON file (one-shot, not for plot
# consumption). Other one-off analyzers can also live here as the
# rosters grow.

"""
    _analyze_hpsi_export(psi, grid, atom, params, ws_prev) -> NamedTuple

Level 10 deliverable: compute Hψ via `energy_gradient!` and save to JLD2
along with the wavefunction, per-term energy decomposition, and the full
parameter set. Used to hand off operator-level results to external labs
(e.g. Prof. Ueda's spinor-BEC code at U. Tokyo) for cross-code
verification.

YAML usage:

    analyze:
      - hpsi_export:
          path: "operator_rhs.jld2"  # optional; default in run dir

Output JLD2 keys:
  - `psi`             — host-array copy of ψ (shape n_pts × D)
  - `Hpsi`            — δE/δψ\\* (NOT 2·δE/δψ\\*), the operator action
  - `E_decomp`        — `Dict{String,Float64}` per-term energies
                        (kinetic / trap / zeeman / density / spin / ddi /
                        lhy / tensor / raman / light_shift / coriolis / total)
  - `grid_n_pts`, `grid_box`, `grid_dx`
  - `atom_name`, `atom_F`, `atom_mass`, `atom_a_s`, `atom_mu_mag`, `atom_g_F`
  - `interactions_c0`, `interactions_c1`, `interactions_c_lhy`, `interactions_c_high_rank`
  - `ddi_c_dd`
  - `dealias_enabled`, `dealias_k_cut`
  - `conventions`     — list of strings documenting Eu sign / 4π / ordering choices

Requires `ws_prev` (the live `Workspace`) — pipeline runner threads this
from the ground_state step. As with `energy_decomposition`, calling
without ws_prev throws.

Hψ coverage matches `energy_gradient!` in `src/solvers/lbfgs/energy_gradient.jl`:
kinetic + trap + Zeeman + c₀·n + LHY + c₁·⟨F̂⟩·F̂ + light_shift + DDI.
Does NOT include c₂·|A₀₀|² singlet-pair or higher-rank tensor couplings (n≥2).
Activate this analyzer on configs where those channels are zero.
"""
function _analyze_hpsi_export(psi, grid, atom, params, ws_prev)
    ws_prev === nothing && throw(
        ArgumentError(
            "`:hpsi_export` requires `ws_prev` (the live Workspace with " *
            "configured trap/DDI/LHY kernels). Add it after a ground_state " *
            "step in the pipeline."),
    )

    # Hψ via energy_gradient! (it returns 2·δE/δψ* by the complex-ψ
    # gradient convention; we divide by 2 to get the operator action).
    psi_dev = ws_prev.state.psi
    grad = similar(psi_dev)
    fill!(grad, zero(eltype(grad)))
    E_total = energy_gradient!(grad, psi_dev, ws_prev)
    Hpsi_host = Array(grad) ./ 2
    psi_host = Array(psi_dev)

    decomp = energy_decomposition(ws_prev)
    decomp_dict = Dict{String, Float64}(
        string(k) => Float64(getproperty(decomp, k)) for k in propertynames(decomp))

    # Default output path: under the run dir's analyze/ subtree so it
    # ends up next to other analyzer outputs. The user can override via
    # `path:` (absolute or relative to YAML dir).
    yaml_dir = get(ENV, "SPINORBEC_YAML_DIR", pwd())
    default_path = joinpath(yaml_dir, "operator_rhs.jld2")
    output_path = String(get(params, "path", default_path))
    isabspath(output_path) || (output_path = joinpath(yaml_dir, output_path))
    mkpath(dirname(output_path) == "" ? "." : dirname(output_path))

    JLD2.jldopen(output_path, "w") do f
        f["psi"] = psi_host
        f["Hpsi"] = Hpsi_host
        f["E_decomp"] = decomp_dict
        f["grid_n_pts"] = collect(ws_prev.grid.config.n_points)
        f["grid_box"] = collect(ws_prev.grid.config.box_size)
        f["grid_dx"] = collect(ws_prev.grid.dx)
        f["atom_name"] = atom.name
        f["atom_F"] = atom.F
        f["atom_mass"] = atom.mass
        f["atom_a_s"] = atom.a_s
        f["atom_mu_mag"] = atom.mu_mag
        f["atom_g_F"] = atom.g_F
        f["interactions_c0"] = ws_prev.interactions[0]
        f["interactions_c1"] = ws_prev.interactions[1]
        f["interactions_c_lhy"] = ws_prev.interactions.c_lhy
        # Sorted (n, c_n) pairs for higher-rank tensor couplings (n ≥ 2).
        # Sorted to give a deterministic layout for cross-code diff
        # regardless of Dict iteration order.
        f["interactions_c_high_rank"] = sort(
            [k => v
             for (k, v) in ws_prev.interactions.c
             if k >= 2];
            by=p -> p.first)
        f["ddi_c_dd"] = ws_prev.ddi === nothing ? 0.0 : ws_prev.ddi.C_dd
        f["dealias_enabled"] = DEALIAS_2_3_ENABLED[]
        f["dealias_k_cut"] = DEALIAS_K_CUTOFF[] === nothing ? -1.0 :
                             Float64(DEALIAS_K_CUTOFF[])
        f["conventions"] = String[
            "DDI: c_dd = mu_0*mu^2 (NO 4*pi factor)",
            "Q_ab(k) = khat_a*khat_b - delta_ab/3 (NO 4*pi factor)",
            "Q(k=0) = 0 by Pedri-Santos regularisation",
            "psi ordering: c=1 <-> m=+F, c=D <-> m=-F",
            "Zeeman: H_Z = -p*F_z + q*F_z^2 (with p, q in units of hbar*omega_ref)",
            "Hpsi = dE/dpsi^* (NOT 2*dE/dpsi^*, factor 2 stripped from energy_gradient!)",
            "Coverage: kinetic + trap + Zeeman + c0*n + LHY + c1*<F>*F + light_shift + DDI",
            "Does NOT cover: c2*|A_00|^2 singlet-pair, higher-rank tensor couplings (n≥2)",
        ]
    end

    dV = prod(ws_prev.grid.dx)
    (
        Hpsi_l2_norm=sqrt(sum(abs2, Hpsi_host) * dV),
        psi_l2_norm=sqrt(sum(abs2, psi_host) * dV),
        E_total=Float64(E_total),
        path=output_path,
    )
end

"""
    _analyze_trap_population(psi, grid, atom, params, ws_prev) -> NamedTuple

Split the surviving norm into the part still inside the trap region
(`r ≤ radius`) and the part that has spilled outside it. Quantifies atoms
that drifted toward the absorbing boundary / loss region; recording it
across the time series turns the bare norm decay into an inside-vs-outside
budget.

YAML usage:

    analyze:
      - trap_population:
          radius: 8.0          # optional; default = inscribed sphere (min box half-extent)
          center: [0.0, 0.0]   # optional; default grid origin

Returns `(inside, outside, total, outside_fraction, radius)` where the
first three are `∫|ψ|² dV` over the respective region.
"""
function _analyze_trap_population(psi, grid, atom, params, ws_prev)
    N = length(grid.config.n_points)
    default_radius = 0.5 * minimum(grid.config.box_size)
    radius = Float64(get(params, "radius", default_radius))
    center = let v = get(params, "center", nothing)
        v === nothing ? ntuple(_ -> 0.0, N) : ntuple(d -> Float64(v[d]), N)
    end
    pop = population_inside_radius(psi, grid, radius; center=center)
    merge(pop, (radius=radius,))
end

"""
    _analyze_cloud_shape(psi, grid, atom, params, ws_prev) -> NamedTuple

Cloud shape descriptors from the total-density covariance tensor: center
of mass, per-axis RMS widths, principal-axis widths, aspect ratio, and the
in-plane tilt angle. Recording it across a dynamics snapshot series turns a
density movie into quantitative deformation (anisotropic expansion, shear,
bending).

YAML usage:

    analyze:
      - cloud_shape: {}

Returns `(mass, com, widths, principal_widths, aspect_ratio, tilt)` with
the vector quantities as plain `Vector{Float64}` for serialisation.
"""
function _analyze_cloud_shape(psi, grid, atom, params, ws_prev)
    m = density_moments(psi, grid)
    (
        mass=m.mass,
        com=collect(m.com),
        widths=collect(m.widths),
        principal_widths=collect(m.principal_widths),
        aspect_ratio=m.aspect_ratio,
        tilt=m.tilt,
    )
end

function _analyze_summary_json(psi, grid, atom, params, ws_prev, pipeline_results)
    output_path = String(get(params, "path", "summary.json"))
    extras = get(params, "extras", Dict{String, Any}())
    summary = Dict{String, Any}()
    for (k, v) in pipeline_results
        if v isa Number || v isa AbstractString || v isa Bool || v === nothing
            summary[String(k)] = v
        end
    end
    if haskey(pipeline_results, :dynamics_result)
        dr = pipeline_results[:dynamics_result]
        summary["n_snapshots"] = length(dr.psi_snapshots)
        summary["t_initial"] = dr.times[1]
        summary["t_final"] = dr.times[end]
        if !isempty(dr.energies)
            summary["energy_initial"] = Float64(dr.energies[1])
            summary["energy_final"] = Float64(dr.energies[end])
            summary["norm_drift"] = Float64(abs(dr.norms[end] - dr.norms[1]))
        end
    end
    for (k, v) in extras
        summary[String(k)] = v
    end
    # What produced this number. `point_NNN.jld2` has carried an `env/` block
    # since the CAS reuse check needed one (`_assert_point_provenance` refuses a
    # cached point from a different commit), but `summary.json` — the file every
    # document and figure actually cites — carried none. Measured 2026-08-02 on
    # 226 stored results: not one summary recorded the commit, the config hash,
    # or the Julia version, and only 20 of the 226 had ANY file under version
    # control, so a cited number could not be re-derived or even attributed.
    #
    # `_env_metadata()` already exists and is what the jld2 stores; called here
    # rather than threaded through `pipeline_results` so this adds no key to a
    # dict that reaches `make_workspace` (CLAUDE.md, "Type stability
    # boundaries"). Two `git` subprocesses per summary write, against a pipeline
    # step measured in minutes.
    for (k, v) in _env_metadata()
        summary["_env_$k"] = v
    end
    summary["_written_at"] = _now_iso()
    mkpath(dirname(output_path) == "" ? "." : dirname(output_path))
    open(output_path, "w") do io
        JSON.print(io, summary, 2)
    end
    (path=output_path, n_fields=length(summary))
end
