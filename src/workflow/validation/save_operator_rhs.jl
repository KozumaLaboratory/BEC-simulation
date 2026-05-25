# --- save_operator_rhs(r, output_dir) — Level 10 hand-off ---
#
# Symmetric counterpart of `open_result`: writes a RunResult back to
# disk in the canonical operator_rhs.jld2 layout, plus a MANIFEST.md
# with sha256 + git commit + Julia version metadata. The pair is what
# we hand to external collaborators (Ueda lab) for bilateral
# operator-RHS diff per `docs/validation/parameter_contract_with_Ueda.md`.
#
# Usage (REPL — no scripts/validation/export_operator_rhs.jl needed):
#
#   r = open_result(point_001_path)
#   r.hpsi === nothing && error("rerun YAML with `hpsi_export` analyzer")
#   art = save_operator_rhs(r, "out_dir/")
#   # art.jld2_path / art.manifest_path / art.sha256

export save_operator_rhs

using SHA: sha256, bytes2hex
using Dates: now

"""
    save_operator_rhs(r::RunResult, output_dir::String) -> NamedTuple

Serialize `r` as `<output_dir>/operator_rhs.jld2` + write
`MANIFEST.md` next to it. Returns `(jld2_path, manifest_path, sha256)`.

Requires `r.hpsi !== nothing` (the RunResult must have come from a
pipeline that ran the `hpsi_export` analyzer, or `r.hpsi` was set
manually). Throws `ArgumentError` otherwise — the operator-RHS diff
is meaningless without Hψ.
"""
function save_operator_rhs(r::RunResult, output_dir::AbstractString)
    r.hpsi === nothing && throw(
        ArgumentError(
            "save_operator_rhs: RunResult has no Hψ — rerun the YAML " *
            "with an `hpsi_export` analyzer (writes operator_rhs.jld2), " *
            "then re-open."),
    )
    mkpath(output_dir)
    jld2_path = joinpath(output_dir, "operator_rhs.jld2")
    manifest_path = joinpath(output_dir, "MANIFEST.md")

    JLD2.jldopen(jld2_path, "w") do f
        f["psi"] = r.psi
        f["Hpsi"] = r.hpsi
        # Grid / atom / interactions
        f["grid_n_pts"] = collect(Int, r.grid.config.n_points)
        f["grid_box"] = collect(Float64, r.grid.config.box_size)
        f["grid_dx"] = collect(Float64, r.grid.dx)
        f["atom_name"] = r.atom.name
        f["atom_F"] = r.atom.F
        f["atom_mass"] = r.atom.mass
        f["atom_a_s"] = r.atom.a_s
        f["atom_mu_mag"] = r.atom.mu_mag
        f["atom_g_F"] = r.atom.g_F
        f["interactions_c0"] = get(r.interactions.c, 0, 0.0)
        f["interactions_c1"] = get(r.interactions.c, 1, 0.0)
        f["interactions_c_lhy"] = r.interactions.c_lhy
        f["interactions_c_high_rank"] = Pair{Int, Float64}[
            k => v for (k, v) in r.interactions.c if k >= 2]
        f["ddi_c_dd"] = Float64(get(r.metadata, "ddi_c_dd", 0.0))
        # Decomposition
        f["E_decomp"] = r.e_decomp
        f["dealias_enabled"] = Bool(get(r.metadata, "dealias_enabled", false))
        f["dealias_k_cut"] = Float64(get(r.metadata, "dealias_k_cut", -1.0))
        f["conventions"] = get(r.metadata, "conventions",
            _default_conventions_list())
    end

    sha = open(jld2_path, "r") do io
        bytes2hex(sha256(io))
    end

    _write_manifest(manifest_path, r, jld2_path, sha)

    (jld2_path=jld2_path, manifest_path=manifest_path, sha256=sha)
end

function _default_conventions_list()
    String[
        "DDI: c_dd = mu_0*mu^2 (NO 4*pi factor)",
        "Q_ab(k) = khat_a*khat_b - delta_ab/3 (NO 4*pi factor)",
        "Q(k=0) = 0 by Pedri-Santos regularisation",
        "psi ordering: c=1 <-> m=+F, c=D <-> m=-F",
        "Zeeman: H_Z = -p*F_z + q*F_z^2 (with p, q in units of hbar*omega_ref)",
        "psi normalization: integral |psi|^2 dV = 1 (N absorbed into c_n)",
    ]
end

function _write_manifest(
    manifest_path::String, r::RunResult, jld2_path::String, sha::String
)
    git_commit = try
        chomp(read(`git rev-parse HEAD`, String))
    catch
        "unknown (not a git checkout)"
    end
    julia_ver = string(VERSION)
    src_path_disp = isabspath(r.path) ? r.path : abspath(r.path)
    open(manifest_path, "w") do io
        write(
            io,
            """
  # Operator-RHS export manifest

  Generated: $(string(now()))

  ## Source RunResult
  - Loaded from: `$src_path_disp`
  - Atom: $(r.atom.name) (F=$(r.atom.F))
  - Grid: $(r.grid.config.n_points), box $(r.grid.config.box_size)

  ## Outputs
  - JLD2: `$(basename(jld2_path))`
  - JLD2 sha256: $sha

  ## Environment
  - git commit: `$git_commit`
  - Julia version: $julia_ver

  ## Cross-code comparison

  After the Ueda lab returns their `operator_rhs.jld2`:

      using SpinorBEC
      ours = open_result("$(basename(jld2_path))")
      theirs = open_result("their_operator_rhs.jld2")
      check(OperatorRHSSpec(; tol_hpsi=1e-10),
            compare_runs(ours, theirs; label_a="ours", label_b="ueda"))

  Pass criterion: `‖Hψ_ours − Hψ_ueda‖_L² / ‖Hψ_ours‖_L² < 1e-10`.

  See `docs/validation/parameter_contract_with_Ueda.md` for the
  full signed convention contract that must precede the diff.
  """,
        )
    end
end
