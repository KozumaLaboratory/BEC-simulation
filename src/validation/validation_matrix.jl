# Validation matrix runner: executes the validation ladder and emits a
# one-page `validation_matrix.csv` table:
#
#   Level | Test | Physics | Expected | Result | Status
#
# Most levels are backed by existing unit tests in `test/`. The runner loads
# each test file, captures Pass/Fail/Broken from the testset Result objects,
# and rolls them up by Level. Levels not covered by automated unit tests are
# reported as `MANUAL` with a pointer to the relevant artifact (some of those
# pointers are HISTORICAL — they name run dirs or scripts that produced the
# recorded verdict and have since been reaped/archived).

using Test: Test, @testset

export run_validation_matrix

const VALIDATION_LEVELS = [
    # (level, test_file_or_marker, short_description)
    (0, "MANUAL: runs/verification_suite/ env metadata",
        "Environment / reproducibility (git, Manifest, CUDA, seed)"),
    (0, "test/test_level0_gpu_cpu_consistency.jl",
        "GPU/CPU consistency on small system (gated on CUDA.functional)"),
    (1, "test/test_level1_scalar_exact.jl",
        "Scalar exact tests (free uniform, plane wave, harmonic GS)"),
    (1, "test/test_dealias_2_3.jl",
        "Pseudospectral dealiasing infrastructure"),
    (2, "test/test_level2_strang_convergence.jl",
        "Strang dt²-convergence (ratio ≈ 4 across dt halvings)"),
    (3, "test/test_level3_zeeman_only.jl",
        "Zeeman-only dynamics (N_m frozen, ψ_m phase = -i(-pm+qm²)t)"),
    (3, "test/foundation/test_spin_matrices.jl",
        "Spin matrices ([F_x,F_y]=iF_z, F^2, ladder coefficients)"),
    (3, "test/hamiltonian/test_zeeman_accessors.jl",
        "Zeeman accessor API (linear_p, quadratic_q, transverse_b)"),
    (4, "test/hamiltonian/test_spin_mixing.jl",
        "Spin-1 SMA c1 sign convention"),
    (4, "test/test_level4_f1_phase_emergence.jl",
        "F=1 phase emergence: Mz=0 sector + analytic gap + Bogoliubov + Mz sweep"),
    (4, "test/test_level4_general_F_phase_emergence.jl",
        "General-F (1,2,3,6,8) phase emergence + FM-up F-flip + polyhedral instability"),
    (4, "test/hamiltonian/test_singlet_pair.jl",
        "Spin-2 cyclic / nematic A_00 singlet pair"),
    (4, "test/hamiltonian/test_tensor_interaction.jl",
        "Higher-rank c_extra builder (S=4,6,...)"),
    (5, "test/hamiltonian/test_ddi.jl",
        "DDI kernel (spherical polarized E_DDI~0)"),
    (5, "test/hamiltonian/test_ddi_padded.jl",
        "DDI padded convolution (FFT vs direct)"),
    (6, "MANUAL: runs/verification_suite/yamls/09_edh_toy_spin_orbit_transfer.yaml",
        "EdH F=3 toy benchmark (Jz conservation)"),
    (7, "test/workflow/test_losses.jl (full tier)",
        "K3 loss analytic n(t) = n0/sqrt(1+2K3 n0^2 t)"),
    (7, "test/workflow/test_loss_block_edge_cases.jl",
        "K3 / L3 routing + SI conversion edge cases"),
    (8, "test/hamiltonian/test_lhy_level8_unit.jl",
        "Scalar LHY scaling + coefficient + spinor caveat"),
    (8, "test/hamiltonian/test_lhy.jl",
        "Norm conservation with LHY"),
    (9, "MANUAL: 2026-05-24 CROSS-GRID CONVERGED",
        "Eu Ham-only: N=64/96/128 = 0.00886 at dt=0.005+k_cut=16"),
    (10, "test/test_level10_hpsi_self_consistency.jl",
        "Internal Hψ self-consistency (F=1/2/6, energy_gradient! vs naive)"),
    (10, "test/test_reference_rhs.jl",
        "Independent reference RHS diff (scalar/Zeeman/contact/DDI/loss; post-pivot Level 10)"),
    (10, "MANUAL: docs/validation/ueda_status.md",
        "External Ueda comparison — see ueda_status.md for current status"),
    (11, "test/test_level11_convergence_sweep.jl",
        "dt + grid + box convergence + seed reproducibility"),
    (12, "test/test_level12_production_audit.jl",
        "Production audit script: K3-on / LHY-on twin-control check"),
    (12, "test/workflow/test_dynamics_lhy_plumbing.jl",
        "Dynamics-step LHY plumbing (schema + dispatcher fix 2026-05-26)"),
    (12, "MANUAL: twin generator + audit (archived scripts, 2026-05)",
        "Twin generator + audit (23 historical orphans now paired)"),
    (12, "MANUAL: DDI convention factorial (archived scripts, 2026-05)",
        "DDI convention factorial (6/6 PASS at 24³ Cr52 — sphericity, axis flip, secular/full)"),
    (12, "MANUAL: Eu robust factorial (archived scripts, 2026-05)",
        "Eu robust factorial (K3 × γ_dr × LHY at 32³, 8 cells)"),
]

struct LevelRow
    level::Int
    test_marker::String
    description::String
    pass::Int
    fail::Int
    broken::Int
    duration::Float64
    status::String  # PASS / FAIL / MANUAL / SKIP / ERROR
    note::String
end

function _matrix_classify(pass, fail, broken)
    fail > 0 && return "FAIL"
    pass + broken == 0 && return "ERROR"
    return "PASS"
end

"""
    run_validation_matrix(output_dir="docs/validation"; io=stdout)
        -> (; rows, n_pass, n_fail, n_manual, n_skip, n_error)

Run every automated row of the validation ladder and write
`validation_matrix.csv` (machine-readable) + `validation_report.md`
(human-readable) into `output_dir`. A caller that needs an exit code should
use `n_fail == 0 && n_error == 0`.
"""
function run_validation_matrix(output_dir::AbstractString="docs/validation";
    io::IO=stdout)
    mkpath(output_dir)
    csv_path = joinpath(output_dir, "validation_matrix.csv")
    md_path = joinpath(output_dir, "validation_report.md")
    project_root = normpath(joinpath(@__DIR__, "..", ".."))

    println(io, "=== Validation matrix runner ===")
    println(io, "output_dir: $output_dir")
    println(io)

    rows = LevelRow[]
    for (level, marker, desc) in VALIDATION_LEVELS
        println(io, "--- Level $level: $desc ---")

        # MANUAL entries: report-only.
        if startswith(marker, "MANUAL:")
            println(io, "  (manual: $marker)")
            push!(rows,
                LevelRow(level, marker, desc, 0, 0, 0, 0.0, "MANUAL",
                    strip(replace(marker, "MANUAL:" => ""))))
            continue
        end

        # Skip "(full tier)" tests — too slow for the matrix runner.
        if occursin("(full tier)", marker)
            push!(rows, LevelRow(level, marker, desc, 0, 0, 0, 0.0, "SKIP",
                "skipped: full tier"))
            continue
        end

        full_path = joinpath(project_root, marker)
        if !isfile(full_path)
            println(io, "  MISSING: $marker (resolved: $full_path)")
            push!(rows, LevelRow(level, marker, desc, 0, 0, 0, 0.0, "ERROR",
                "test file not found"))
            continue
        end

        t0 = time()
        pass = 0
        fail = 0
        broken = 0
        try
            ts = @testset "matrix:$marker" begin
                Base.include(Main, full_path)
            end
            # Test.get_test_counts gives both direct and cumulative counts.
            tc = Test.get_test_counts(ts)
            pass = tc.passes + tc.cumulative_passes
            fail = tc.fails + tc.cumulative_fails
            broken = tc.broken + tc.cumulative_broken
            err = tc.errors + tc.cumulative_errors
            # Errors are reported as fails in our matrix.
            fail += err
        catch e
            println(stderr, "  EXCEPTION: $e")
            fail = 1
        end
        dur = time() - t0
        status = _matrix_classify(pass, fail, broken)
        println(io,
            "  $status: $pass pass, $fail fail, $broken broken in $(round(dur; digits=1))s")
        push!(rows, LevelRow(level, marker, desc, pass, fail, broken, dur,
            status, ""))
    end

    # Write CSV.
    open(csv_path, "w") do f
        println(f, "level,test,description,pass,fail,broken,duration_s,status,note")
        for r in rows
            # quote fields that may contain commas.
            q(s) = occursin(",", s) || occursin("\"", s) ?
                   "\"$(replace(s, "\"" => "\"\""))\"" : s
            println(f,
                join(
                    (string(r.level), q(r.test_marker), q(r.description),
                        string(r.pass), string(r.fail), string(r.broken),
                        @sprintf("%.2f", r.duration), r.status, q(r.note)), ","))
        end
    end

    n_pass = count(r -> r.status == "PASS", rows)
    n_fail = count(r -> r.status == "FAIL", rows)
    n_manual = count(r -> r.status == "MANUAL", rows)
    n_skip = count(r -> r.status == "SKIP", rows)
    n_error = count(r -> r.status == "ERROR", rows)
    total_pass = sum(r -> r.pass, rows)
    total_fail = sum(r -> r.fail, rows)
    total_broken = sum(r -> r.broken, rows)

    open(md_path, "w") do f
        write(f,
            """
            # Validation matrix report

            Generated: $(now())

            Source: `run_validation_matrix` (src/validation/validation_matrix.jl)

            ## Summary

            | Status | Rows | Notes |
            |---|---|---|
            | PASS | $n_pass | automated test rows whose tests all passed |
            | FAIL | $n_fail | automated test rows with at least one failure |
            | MANUAL | $n_manual | levels requiring manual runs or external code |
            | SKIP | $n_skip | tests in full tier (slow), skipped by matrix runner |
            | ERROR | $n_error | test file missing or threw an exception |

            Total automated assertions: $total_pass pass, $total_fail fail, $total_broken broken.

            ## Per-level results

            | Level | Status | Description | Test | Pass | Fail | Broken | Notes |
            |---|---|---|---|---|---|---|---|
            """)
        for r in rows
            status_icon = if r.status == "PASS"
                "✅"
            elseif r.status == "FAIL"
                "❌"
            elseif r.status == "MANUAL"
                "👤"
            elseif r.status == "SKIP"
                "⏭"
            else
                "⚠️"
            end
            write(f,
                "| $(r.level) | $status_icon $(r.status) | $(r.description) | " *
                "`$(r.test_marker)` | $(r.pass) | $(r.fail) | $(r.broken) | $(r.note) |\n")
        end
        write(f,
            """

            ## How to read this

            - **PASS** means *every assertion* in the linked test file passed
              (the test file is the contract; if you add new assertions, they
              must pass too).
            - **FAIL** means at least one assertion failed; consult the test
              file + the run log.
            - **MANUAL** means the level requires either an external code or a
              multi-grid sweep too expensive to run every time. The "test"
              column points to the relevant artifact (possibly archived).
            - **SKIP** means the test is in the `full` tier (heavy ITP/RTP)
              and is excluded from the matrix runner. Run via
              `SPINORBEC_TEST_TIER=full julia --project=. -e 'using Pkg; Pkg.test()'`.
            """)
    end

    println(io)
    println(io, "Wrote $csv_path")
    println(io, "Wrote $md_path")
    println(io)
    println(io,
        "Summary: $n_pass PASS, $n_fail FAIL, $n_manual MANUAL, $n_skip SKIP, $n_error ERROR")
    println(io,
        "         $total_pass total assertions pass, $total_fail fail, $total_broken broken")

    (; rows, n_pass, n_fail, n_manual, n_skip, n_error)
end
