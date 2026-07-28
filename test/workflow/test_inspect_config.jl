using Test
using SpinorBEC

@testset "inspect_config" begin
    @testset "clean Klaus quench config — no warnings" begin
        path = joinpath(@__DIR__, "..", "..", "runs",
            "klaus_quench_omm0p1_holdonly_delay2ms_refine_90bfb48f",
            "config.yaml")
        if isfile(path)
            ins = inspect_config(path)
            @test ins isa SpinorBEC.ConfigInspection
            # Post-structural-lift: :info findings (Gauss strings,
            # auto-derived q) are expected. No :warn / :error / :block.
            @test !any(w -> w.severity in (:warn, :error, :block),
                ins.warnings)
            @test length(ins.steps) == 6              # 1 GS + 4 dynamics + 1 analyze
            # Zeeman trace exists for ground_state + 4 dynamics steps
            n_zeeman_traces = sum(1 for s in ins.steps
                                        if any(t -> t.kind === :zeeman, s.traces))
            @test n_zeeman_traces == 5
            # Step #3 is the Bz quench. The trace channels are the internal
            # operator coefficients (bx, by, bz, q in H = -(b·F) + q·F_z²), so
            # bz = p = -g_F μ_B B_z (K-U convention, B→p sign fix 5d75649d). The
            # dimensionless bz quenches from +148 to ~+0.385.
            quench = ins.steps[3]
            bz_trace = first(t for t in quench.traces if t.kind === :zeeman)
            bz = bz_trace.channels[:bz]
            @test first(bz) ≈ 148.0 rtol=0.01
            @test abs(last(bz)) < 1.0      # near-zero by end of quench
            @test maximum(bz) > last(bz) || isapprox(maximum(bz), last(bz))
        end
    end

    @testset "W1: B-direction theta dropped on split-step" begin
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {B_mag: "0.01 Gauss", theta: 3.14159, phi: 0.0}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        ins = SpinorBEC.inspect_config_string(src)
        # Structural kind: input_resolved_drop covers the theta drop.
        warns = filter(w -> w.kind === :input_resolved_drop &&
                            occursin("theta", w.title), ins.warnings)
        @test length(warns) == 1
        @test warns[1].severity === :warn
        @test warns[1].step_index == 1
        # theta=π in radians must NOT flip the field. The trace carries the
        # INTERNAL operator coefficient bz = p = -g_F μ_B B_z, which is negative
        # for an un-flipped +z lab field (a flip to -z would make it positive).
        bz_trace = first(t for t in ins.steps[1].traces if t.kind === :zeeman)
        @test first(bz_trace.channels[:bz]) < 0
    end

    @testset "W1 suppressed when direction is exactly zero" begin
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {B_mag: "0.01 Gauss", theta: 0.0, phi: 0.0}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        ins = SpinorBEC.inspect_config_string(src)
        @test !any(w -> w.kind === :input_resolved_drop &&
                        occursin("theta", w.title), ins.warnings)
    end

    @testset "W2: zero-duration ramp surfaced as quench" begin
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
          - dynamics:
              duration: 1.0
              dt: 0.01
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: {from: 0.01, to: 0.0001, duration: 0.0}}
        """
        ins = SpinorBEC.inspect_config_string(src)
        # Structural kind: boundary_value covers the zero-duration ramp.
        ws = filter(w -> w.kind === :boundary_value &&
                         occursin("instantaneous", w.title), ins.warnings)
        @test length(ws) == 1
        @test ws[1].step_index == 2
    end

    @testset "W3: Hz string conversion surfaced" begin
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
          - dynamics:
              duration: 0.1
              dt: 0.001
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: {sinusoidal: {amplitude: 0.001, frequency: "226 Hz"}}}
        """
        ins = SpinorBEC.inspect_config_string(src)
        # Structural kind: unit_conversion covers Hz strings (and Gauss, etc.).
        @test any(w -> w.kind === :unit_conversion &&
                       occursin("Hz", w.title), ins.warnings)
    end

    @testset "W4: rotating_frame_omega + GPU on spinor" begin
        src = """
        defaults: {kind: spinor, backend: gpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
          - dynamics:
              duration: 1.0
              dt: 0.01
              backend: gpu
              rotating_frame_omega: -0.2
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
        """
        ins = SpinorBEC.inspect_config_string(src)
        # Structural kind: feature_incompat, :warn severity. This was a :block
        # until 2026-07-28. The underlying crash — `_apply_1d_shear_batch!`
        # scalar-indexing GPU arrays in the Coriolis step — was fixed 2026-06-02
        # (the shear now dispatches on `psi isa Array`), so blocking the run was
        # advising users away from a path that works.
        ws = filter(w -> w.kind === :feature_incompat &&
                         occursin("rotating_frame_omega", w.title),
            ins.warnings)
        @test length(ws) == 1
        @test ws[1].severity === :warn
        @test ws[1].step_index == 2
    end

    @testset "to_dict round-trips for JSON" begin
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        ins = SpinorBEC.inspect_config_string(src)
        d = SpinorBEC.to_dict(ins)
        @test d isa Dict
        @test haskey(d, "raw")
        @test haskey(d, "normalised")
        @test haskey(d, "warnings")
        @test haskey(d, "steps")
        @test d["steps"][1]["traces"][1]["kind"] == "zeeman"
    end

    @testset "schema error surfaces as :normalize_failed" begin
        # Unknown step-level key under strict validation.
        src = """
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {Bz: "0.01 Gauss"}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
              definitely_unknown_key: 42
        """
        ins = SpinorBEC.inspect_config_string(src)
        @test any(w -> w.kind === :normalize_failed && w.severity === :error,
            ins.warnings)
    end

    @testset "runner-consumed top-level blocks are not schema errors" begin
        # `dealias:` and `units:` are real top-level blocks that the RUNNER pops
        # before validation — `dealias` onto global Refs, `units` after lab-unit
        # conversion. Inspect used to validate the raw dict, so it reported a
        # schema ERROR for ~20 configs that run fine, several already run on
        # TSUBAME. A preflight that fails valid configs is worse than none:
        # this severity feeds the autopilot gate.
        src = """
        units: {B: Gauss}
        dealias: {enabled: true, k_cut: 5.0}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              lhy: {kind: full_bdg}
              B: {Bz: "0.01 Gauss"}
              n_steps: 10
              tol: 1.0e-6
        """
        ins = SpinorBEC.inspect_config_string(src)
        @test !any(w -> w.kind === :normalize_failed, ins.warnings)
        @test !any(w -> w.kind === :input_resolved_drop &&
                        occursin("units", w.title), ins.warnings)
        # ...and inspecting must not leak the dealias Refs into the session.
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false

        # `kind: full_bdg` is no longer flagged. The ~3000× offset that rule
        # warned about was a UV counterterm bug, fixed 2026-07-27; full_bdg is
        # the general-spinor path and matches the closed forms to ~1e-4.
        @test !any(w -> w.kind === :full_bdg_f6_polar, ins.warnings)
    end

    @testset "a malformed dealias block is still an error" begin
        # Popping it must not mean ignoring it — the runner throws on this.
        src = """
        dealias: {enabled: true, no_such_key: 1}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              n_steps: 10
              tol: 1.0e-6
        """
        ins = SpinorBEC.inspect_config_string(src)
        @test any(w -> w.kind === :dealias_block_invalid && w.severity === :error,
            ins.warnings)
    end

    # --- run_yaml audit hook (:block aborts + opt-out) -------------------
    #
    # The hook lives in `_run_yaml_impl`; we exercise it via run_yaml with
    # `dry_run=true` so no simulator work happens. Each test writes a YAML
    # to a tempdir, then asserts on whether run_yaml threw and on what.
    #
    # The abort path used to be driven by W4 (rotating_frame_omega + GPU),
    # which was downgraded to :warn on 2026-07-28 once the underlying GPU
    # shear bug was confirmed fixed. `n_steps: 0` is used instead — it is a
    # boundary rule with `zero_meaning = :error`, hence a genuine :block, so
    # the abort coverage survives the downgrade. (`duration ≤ 0` would NOT
    # work: it is `:degenerate` and only emits a :warn.)
    _BLOCK_YAML = """
    defaults: {kind: spinor, backend: cpu}
    pipeline:
      - ground_state:
          atom: Eu151
          grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
          potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
          interactions: {N_atoms: 1000, omega_ref: 691.1504}
          B: {Bz: "0.01 Gauss"}
          dt: 0.01
          n_steps: 0
          tol: 1.0e-6
    """

    _W4_YAML = """
    defaults: {kind: spinor, backend: gpu}
    pipeline:
      - ground_state:
          atom: Eu151
          grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
          potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
          interactions: {N_atoms: 1000, omega_ref: 691.1504}
          B: {Bz: "0.01 Gauss"}
          dt: 0.01
          n_steps: 10
          tol: 1.0e-6
      - dynamics:
          duration: 1.0
          dt: 0.01
          backend: gpu
          rotating_frame_omega: -0.2
          interactions: {N_atoms: 1000, omega_ref: 691.1504}
          B: {Bz: "0.01 Gauss"}
    """

    @testset "audit hook: a :block finding aborts run_yaml" begin
        mktempdir() do tmp
            p = joinpath(tmp, "block.yaml")
            write(p, _BLOCK_YAML)
            err = nothing
            try
                run_yaml(p; dry_run=true, verbose=false, base_dir=tmp)
            catch e
                err = e
            end
            @test err isa ArgumentError
            @test occursin("audit blocked", err.msg)
            @test occursin("n_steps", err.msg)
        end
    end

    @testset "audit hook: W4 is a warning and does NOT abort" begin
        mktempdir() do tmp
            p = joinpath(tmp, "w4.yaml")
            write(p, _W4_YAML)
            ok = try
                run_yaml(p; dry_run=true, verbose=false, base_dir=tmp)
                true
            catch
                false
            end
            @test ok
        end
    end

    @testset "audit hook: audit=false bypasses" begin
        mktempdir() do tmp
            p = joinpath(tmp, "w4.yaml")
            write(p, _W4_YAML)
            # No throw is the success criterion. dry_run reaches the dry-run
            # printer rather than the sim; we only care that the audit didn't
            # intercept.
            ok = try
                run_yaml(p; dry_run=true, verbose=false, audit=false, base_dir=tmp)
                true
            catch
                false
            end
            @test ok
        end
    end

    @testset "audit hook: SPINORBEC_AUDIT=0 bypasses" begin
        mktempdir() do tmp
            p = joinpath(tmp, "w4.yaml")
            write(p, _W4_YAML)
            prev = get(ENV, "SPINORBEC_AUDIT", nothing)
            ENV["SPINORBEC_AUDIT"] = "0"
            ok = try
                run_yaml(p; dry_run=true, verbose=false, base_dir=tmp)
                true
            catch
                false
            finally
                if prev === nothing
                    delete!(ENV, "SPINORBEC_AUDIT")
                else
                    (ENV["SPINORBEC_AUDIT"] = prev)
                end
            end
            @test ok
        end
    end

    @testset "audit_loaded_data fast-path" begin
        # Inspector hot path: takes an already-normalised dict, returns
        # warnings only, no traces. Used by the run_yaml hook.
        src = """
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 1000, omega_ref: 691.1504}
              B: {B_mag: "0.01 Gauss", theta: 3.14159, phi: 0.0}
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        raw = SpinorBEC.YAML.load(src)
        normalised = deepcopy(raw)
        SpinorBEC._normalize_and_validate!(normalised; strict=true)
        ws = audit_loaded_data(normalised; raw)
        @test any(w -> w.kind === :input_resolved_drop &&
                       occursin("theta", w.title), ws)
    end
end
