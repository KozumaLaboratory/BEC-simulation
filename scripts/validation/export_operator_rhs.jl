#!/usr/bin/env julia
#
# Level 10 deliverable: export operator-RHS artifact for cross-code comparison
# with the Ueda lab spinor-BEC code.
#
# Given a YAML config that ends with a ground_state step (and optionally a
# `:hpsi_export` analyzer), this script:
#
#   1. Runs the YAML pipeline to obtain a converged ψ₀.
#   2. Saves `operator_rhs.jld2` containing:
#         - psi          : ψ₀ on host (n_pts × D)
#         - Hpsi         : H·ψ₀ (operator action, NOT 2·∂E/∂ψ*)
#         - E_decomp     : per-term energy Dict (kin / trap / zeeman /
#                          density / spin / ddi / lhy / tensor / raman /
#                          light_shift / coriolis / total)
#         - grid / atom / interactions / ddi / dealias metadata
#         - conventions  : list of strings pinning all signs / factors
#   3. Writes a one-page `MANIFEST.md` next to the jld2 with the YAML
#      hash, git commit, Julia version, and a checksum of the export.
#
# This script is what we send to Ueda lab. Their counterpart script
# reads the YAML metadata, builds the same physical setup in their
# code, and emits their own `operator_rhs.jld2`. The bilateral diff is
# then run via `compare_operator_rhs.jl`.
#
# Usage:
#
#   julia --project=. scripts/validation/export_operator_rhs.jl \
#     <input.yaml> [output_dir]
#
# Defaults: output_dir = dirname(input.yaml). The output filename is
# always `operator_rhs.jld2` (per parameter contract §"Quick send to
# Ueda packet").

using SpinorBEC
using JLD2
using SHA
using Pkg
using Dates: now

function usage_and_exit()
    println(
        stderr,
        """
Usage: export_operator_rhs.jl <input.yaml> [output_dir]

Generates Level 10 operator-RHS artifact for cross-code
comparison with external spinor-BEC codes (e.g. Ueda lab).

See docs/validation/parameter_contract_with_Ueda.md for the
full convention contract that must be signed off BEFORE the
numerical diff is meaningful.
""",
    )
    exit(2)
end

length(ARGS) ∈ (1, 2) || usage_and_exit()
yaml_path = String(ARGS[1])
isfile(yaml_path) || (println(stderr, "ERROR: $yaml_path not found"); exit(1))

output_dir = length(ARGS) == 2 ? String(ARGS[2]) : dirname(abspath(yaml_path))
mkpath(output_dir)
output_path = joinpath(output_dir, "operator_rhs.jld2")
manifest_path = joinpath(output_dir, "MANIFEST.md")

println("=== Level 10 operator-RHS export ===")
println("input  : $yaml_path")
println("output : $output_path")
println("manifest: $manifest_path")
println()

# 1. Load and inspect the YAML. The `_analyze_hpsi_export` analyzer
#    must be present in the pipeline; if not, we suggest the fix.
yaml_text = read(yaml_path, String)
if !occursin("hpsi_export", yaml_text)
    println(
        stderr,
        """
WARNING: YAML does not contain an `hpsi_export` analyzer.

Append the following to your ground_state step's analyze: list:

    analyze:
      - hpsi_export:
          path: "$(basename(output_path))"

Otherwise the export will produce no operator-RHS data.
""",
    )
end

# 2. Run the pipeline. `_analyze_hpsi_export` writes the jld2 itself
#    to `<yaml_dir>/operator_rhs.jld2` by default (it picks up
#    `SPINORBEC_YAML_DIR`, which run_yaml overwrites with the YAML's
#    own directory — so we cannot redirect via ENV alone).
#
# Clear cache: run_yaml skips a run when `<run_dir>/point_001.jld2`
# already exists. Without clearing, the analyzer is never invoked and
# no operator_rhs.jld2 is written.
println("Clearing cache (if any)...")
yaml_dir = dirname(abspath(yaml_path))
expected_jld2 = joinpath(yaml_dir, "operator_rhs.jld2")
isfile(expected_jld2) && rm(expected_jld2)
yaml_stem = first(splitext(basename(yaml_path)))
if isdir(output_dir)
    for entry in readdir(output_dir; join=true)
        # Each scan point lives in `<yaml_stem>_<hash>/` with a
        # `point_NNN.jld2` inside; remove the whole directory so the
        # next run rebuilds it.
        basename(entry) == basename(output_path) && continue  # don't nuke our target
        if isdir(entry) && startswith(basename(entry), yaml_stem * "_")
            println("  clearing cached run dir: $entry")
            rm(entry; recursive=true, force=true)
        end
    end
end

println("Running pipeline...")
t_start = time()
try
    run_yaml(yaml_path; base_dir=output_dir, verbose=false)
catch e
    println(stderr, "ERROR running pipeline: $e")
    rethrow(e)
end
t_run = time() - t_start
println("Pipeline complete in $(round(t_run; digits=2))s")

# 3. The analyzer writes to the YAML's own directory; relocate to the
#    user-specified output_dir (which may be the same directory — in
#    which case the cp is a no-op).
if !isfile(expected_jld2)
    println(
        stderr,
        """
ERROR: $expected_jld2 was not produced.

Either:
- The YAML does not have an `- hpsi_export: {}` step under
  a top-level `analyze:` pipeline entry (see warning above), or
- the analyzer wrote to a different `path:` field (override
  via `analyze: [- hpsi_export: {path: "<rel>"}]`).
""",
    )
    exit(1)
end
expected_jld2 == output_path || cp(expected_jld2, output_path; force=true)

# 5. Verify the jld2 contents.
println("\nVerifying export contents...")
required_keys = (
    "psi", "Hpsi", "E_decomp", "grid_n_pts", "grid_box", "grid_dx",
    "atom_name", "atom_F", "atom_mass", "atom_a_s", "atom_mu_mag", "atom_g_F",
    "interactions_c0", "interactions_c1", "interactions_c_lhy",
    "interactions_c_extra", "ddi_c_dd",
    "dealias_enabled", "dealias_k_cut", "conventions",
)
JLD2.jldopen(output_path, "r") do f
    for k in required_keys
        haskey(f, k) || (println(stderr, "ERROR: jld2 missing key `$k`");
            exit(1))
    end
    println("  ψ shape       : $(size(f["psi"]))")
    println("  Hψ shape      : $(size(f["Hpsi"]))")
    println("  atom          : $(f["atom_name"]) (F=$(f["atom_F"]))")
    println("  E_decomp keys : $(sort(collect(keys(f["E_decomp"]))))")
    println("  E_total       : $(f["E_decomp"]["total"])")
    println("  c_dd          : $(f["ddi_c_dd"])")
    println("  dealias       : enabled=$(f["dealias_enabled"]), " *
            "k_cut=$(f["dealias_k_cut"])")
end

# 6. Compute checksum.
sha = open(output_path, "r") do io
    bytes2hex(SHA.sha256(io))
end
println("\nsha256: $sha")

# 7. Capture git commit + Julia version + Manifest hash.
git_commit = try
    chomp(read(`git -C $(dirname(abspath(yaml_path))) rev-parse HEAD`,
        String))
catch
    "unknown (not a git checkout)"
end
julia_ver = string(VERSION)
manifest_hash = try
    project_dir = Pkg.project().path |> dirname
    manifest_file = joinpath(project_dir, "Manifest.toml")
    isfile(manifest_file) ?
    bytes2hex(SHA.sha256(read(manifest_file))) :
    "no Manifest.toml"
catch
    "unavailable"
end

# 8. Write MANIFEST.md.
open(manifest_path, "w") do io
    write(
        io,
        """
  # Operator-RHS export manifest

  Generated: $(string(now()))
  Wall-time: $(round(t_run; digits=2)) s

  ## Inputs
  - YAML: `$(basename(yaml_path))`
  - YAML sha256: $(bytes2hex(SHA.sha256(read(yaml_path))))

  ## Outputs
  - JLD2: `$(basename(output_path))`
  - JLD2 sha256: $sha

  ## Environment
  - git commit: `$git_commit`
  - Julia version: $julia_ver
  - Manifest.toml sha256: $manifest_hash

  ## Cross-code comparison

  To compare against an external code (e.g. Ueda lab):

  1. Confirm `docs/validation/parameter_contract_with_Ueda.md` is
     signed off on both sides — every convention row must match
     or have a documented transformation.
  2. Send the receiver: this MANIFEST, the YAML, and the JLD2.
  3. Receiver builds the same physical setup, produces their own
     `operator_rhs.jld2`.
  4. Run:

         julia --project=. scripts/validation/compare_operator_rhs.jl \\
           $(basename(output_path)) <theirs.jld2>

  Acceptance (Level 10 PASS):
  - per-term `|E_ours - E_theirs| / |E_total| < 1e-10`
  - `‖Hψ_ours - Hψ_theirs‖_L² / ‖Hψ_ours‖_L² < 1e-10`

  If diff is ~1e-2 or larger, the bug is NOT in K3/LHY/long-time
  integration. It is in a convention row. Read down the contract.
  """,
    )
end

println("\n=== DONE ===")
println("Send these three files to the comparison partner:")
println("  1. $yaml_path")
println("  2. $output_path")
println("  3. $manifest_path")
println()
println("Plus a signed copy of docs/validation/parameter_contract_with_Ueda.md")
println()
exit(0)
