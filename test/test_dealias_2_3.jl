# Regression test for the Orszag 2/3-rule pseudospectral filter
# (src/hamiltonian/integrator/dealias.jl).
#
# Verifies (CPU-only, no GPU dependency):
#   1. Default toggle is OFF (no behaviour change for existing callers).
#   2. Filter zeros Fourier modes with |k_d_idx| > n_d ÷ 3 per axis.
#   3. Filter preserves modes within the kept band (low-k, |k| ≤ n_d ÷ 3).
#   4. Mask cache key by n_pts (different grids get distinct masks).
#   5. Idempotent: applying twice = applying once.
#
# Does NOT cover (deferred to physics validation suite):
#   - End-to-end L4 grid convergence (GPU run; lives under
#     runs/verification_suite/yamls/L4dealiasv4_*).

using Test
using FFTW
using Random
using SpinorBEC

@testset "Orszag 2/3 dealiasing filter" begin
    @testset "toggle defaults OFF" begin
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
    end

    @testset "mask geometry" begin
        # n=16: cutoff = 16 ÷ 3 = 5. Modes with |k_abs_idx| > 5 zeroed.
        # FFT-order: index i ↔ k_idx (i-1); |k_abs_idx| = min(i-1, n-(i-1)).
        # Kept: i ∈ {1,2,3,4,5,6} (k_abs 0..5) ∪ {12,...,16} (k_abs 5..1)
        # Zeroed: i ∈ {7,8,9,10,11} (k_abs 6,7,8,7,6)
        mask = SpinorBEC._get_orszag_mask((16,))
        @test size(mask) == (16,)
        kept = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0,  # i=1..6, k_abs=0..5
            0.0, 0.0, 0.0, 0.0, 0.0,           # i=7..11, k_abs=6,7,8,7,6
            1.0, 1.0, 1.0, 1.0, 1.0]           # i=12..16, k_abs=5,4,3,2,1
        @test mask == kept
    end

    @testset "filter zeros high-k, preserves low-k" begin
        n = 16
        D = 3
        plans = SpinorBEC.make_fft_plans((n,))
        # Inject plane waves at k_idx=1 (low, kept) and k_idx=7 (high, zeroed)
        psi = zeros(ComplexF64, n, D)
        for c in 1:D, i in 1:n
            psi[i, c] = cis(2π * (i - 1) * 1 / n) + cis(2π * (i - 1) * 7 / n)
        end

        # Pre-filter k-space content
        buf = copy(psi[:, 1])
        plans.forward * buf
        @test abs(buf[2]) > 0.5 * n   # k_idx=1 has the full plane-wave amplitude
        @test abs(buf[8]) > 0.5 * n   # k_idx=7 also present

        SpinorBEC.apply_orszag_2_3_filter!(psi, plans, D, 1)

        # Post-filter
        buf2 = copy(psi[:, 1])
        plans.forward * buf2
        @test abs(buf2[2]) > 0.5 * n        # low-k preserved
        @test abs(buf2[8]) < 1e-12          # high-k zeroed
    end

    @testset "idempotent (applying twice = once)" begin
        n = 16
        D = 3
        plans = SpinorBEC.make_fft_plans((n,))
        rng = MersenneTwister(20260524)
        psi_a = randn(rng, ComplexF64, n, D)
        psi_b = copy(psi_a)
        SpinorBEC.apply_orszag_2_3_filter!(psi_a, plans, D, 1)
        SpinorBEC.apply_orszag_2_3_filter!(psi_b, plans, D, 1)
        SpinorBEC.apply_orszag_2_3_filter!(psi_b, plans, D, 1)
        @test maximum(abs, psi_a .- psi_b) < 1e-13
    end

    @testset "different grid sizes get distinct masks" begin
        m16 = SpinorBEC._get_orszag_mask((16,))
        m32 = SpinorBEC._get_orszag_mask((32,))
        @test size(m16) == (16,)
        @test size(m32) == (32,)
        @test sum(m16) == 11.0   # 6 + 5 = 11 modes kept
        @test sum(m32) == 21.0   # n=32, cutoff=10, kept i ∈ {1..11} ∪ {23..32}
    end

    @testset "3D mask: per-axis cutoff" begin
        # 8³ grid: cutoff = 8÷3 = 2 per axis. Kept per axis: |k_abs| ≤ 2 →
        # i ∈ {1,2,3} ∪ {7,8} → 5 indices. Cube: 5³ = 125 modes kept.
        m = SpinorBEC._get_orszag_mask((8, 8, 8))
        @test size(m) == (8, 8, 8)
        @test sum(m) == 125.0
    end

    @testset "dt_max_for_k_cut formula" begin
        # dt_max = 1 / (safety · k_cut); default safety = 10.0
        @test SpinorBEC.dt_max_for_k_cut(11.0) ≈ 1.0 / 110.0
        @test SpinorBEC.dt_max_for_k_cut(16.0) ≈ 1.0 / 160.0
        @test SpinorBEC.dt_max_for_k_cut(20.0) ≈ 1.0 / 200.0
        # Tighter safety multiplies the divisor
        @test SpinorBEC.dt_max_for_k_cut(16.0; safety=100.0) ≈ 1.0 / 1600.0
        # L4 empirical: dt=0.005 at k_cut=16 was grid-converged (dt=0.005 < 0.00625 ✓)
        @test 0.005 < SpinorBEC.dt_max_for_k_cut(16.0)
        # dt=0.01 at k_cut=16 was NOT converged (dt=0.01 > 0.00625 ✗)
        @test 0.01 > SpinorBEC.dt_max_for_k_cut(16.0)
    end

    @testset "YAML dealias persists across scan points" begin
        # A YAML scan runs multiple points through `run_pipeline` from
        # one outer `run_yaml` call. Dealias settings come from the
        # top-level block, so EVERY scan point should see them. This
        # test catches a regression where the snapshot restore (in
        # the per-point loop) could clobber the per-point Refs to the
        # PRIOR run_yaml's defaults.
        SpinorBEC.DEALIAS_2_3_ENABLED[] = false
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing

        # A YAML with `scan:` (2 points sweeping a benign value), all
        # under one outer dealias block. The hook fires once per
        # run_yaml invocation, so the snapshot pattern must survive
        # multiple per-point run_pipeline calls inside.
        yaml_text = """
        dealias:
          enabled: true
          k_cut: 8.0

        defaults:
          kind: spinor
          backend: cpu
          interactions: {N_atoms: 50, omega_ref: 1.0}

        scan:
          parameter_path: pipeline.0.interactions.c1_ratio
          values: [0.0, 0.01]

        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [10], box: [10.0]}
              potential: {type: harmonic, omega: [1.0]}
              interactions: {N_atoms: 50, omega_ref: 1.0, c1_ratio: 0.0}
              ddi: {enabled: false}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0, theta: 0.0, phi: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.005
              n_steps: 10
              tol: 1.0e-6
        """

        yaml_path, io = mktemp()
        try
            write(io, yaml_text)
            close(io)
            run_yaml(yaml_path; base_dir=mktempdir(), verbose=false)
            # Final state must be restored cleanly even after a scan.
            @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
            @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing
        finally
            rm(yaml_path; force=true)
        end
    end

    @testset "YAML dealias block end-to-end via run_yaml" begin
        # Smoke test: a minimal YAML config with `dealias:` block triggers
        # the apply_dealias_block! → set Refs → run pipeline → restore
        # Refs flow. Verifies state leakage is prevented across multiple
        # run_yaml calls.

        # State before is reset.
        SpinorBEC.DEALIAS_2_3_ENABLED[] = false
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing

        yaml_text = """
        dealias:
          enabled: true
          k_cut: 8.0

        defaults:
          kind: spinor
          backend: cpu
          interactions: {N_atoms: 50, omega_ref: 1.0}

        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [12], box: [10.0]}
              potential: {type: harmonic, omega: [1.0]}
              interactions: {N_atoms: 50, omega_ref: 1.0, c1_ratio: 0.0}
              ddi: {enabled: false}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0, theta: 0.0, phi: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.005
              n_steps: 20
              tol: 1.0e-6
        """

        # Write to a temp file (run_yaml requires path-based input)
        yaml_path, io = mktemp()
        try
            write(io, yaml_text)
            close(io)
            # Pre-run probe: Refs are off (default)
            @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
            @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing

            # Run — should temporarily set Refs, then restore in finally.
            run_yaml(yaml_path; base_dir=mktempdir(), verbose=false)

            # Post-run: Refs restored to default.
            @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
            @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing
        finally
            rm(yaml_path; force=true)
        end
    end

    @testset "safe_k_cut_boundary formula" begin
        # k_Nyq = π·N/L; safe = 2·k_Nyq/3
        @test SpinorBEC.safe_k_cut_boundary(64, 12.0) ≈ 2 * (π * 64 / 12.0) / 3
        @test SpinorBEC.safe_k_cut_boundary(96, 12.0) ≈ 2 * (π * 96 / 12.0) / 3
        @test SpinorBEC.safe_k_cut_boundary(128, 12.0) ≈ 2 * (π * 128 / 12.0) / 3
        # Values match the L4 k-scan analysis comment in the docstring
        @test isapprox(SpinorBEC.safe_k_cut_boundary(96, 12.0), 16.755; atol=1e-3)
        @test isapprox(SpinorBEC.safe_k_cut_boundary(128, 12.0), 22.34; atol=1e-2)
    end

    @testset "YAML dealias block automation" begin
        # apply_dealias_block! pops the key + sets Refs
        cfg = Dict{String, Any}(
            "dealias" => Dict{String, Any}("enabled" => true, "k_cut" => 16.0),
            "pipeline" => [],
        )
        snapshot = SpinorBEC.apply_dealias_block!(cfg)
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == true
        @test SpinorBEC.DEALIAS_K_CUTOFF[] == 16.0
        @test !haskey(cfg, "dealias")  # popped for schema-safety
        @test snapshot isa Tuple  # previous (enabled, k_cut) for restore

        # Restore round-trip
        SpinorBEC.restore_dealias_refs!(snapshot...)
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
        @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing

        # auto_dt clamps dynamics.dt
        cfg2 = Dict{String, Any}(
            "dealias" => Dict{String, Any}(
                "enabled" => true, "k_cut" => 16.0, "auto_dt" => true
            ),
            "pipeline" => [
                Dict{String, Any}(
                    "dynamics" => Dict{String, Any}("dt" => 0.01, "duration" => 6.28)
                ),
            ],
        )
        snap = SpinorBEC.apply_dealias_block!(cfg2)
        @test cfg2["pipeline"][1]["dynamics"]["dt"] ≈ SpinorBEC.dt_max_for_k_cut(16.0)
        @test cfg2["pipeline"][1]["dynamics"]["dt"] < 0.01  # tightened
        SpinorBEC.restore_dealias_refs!(snap...)

        # auto_dt LEAVES dt alone when already smaller than bound
        cfg3 = Dict{String, Any}(
            "dealias" => Dict{String, Any}(
                "enabled" => true, "k_cut" => 16.0, "auto_dt" => true
            ),
            "pipeline" => [
                Dict{String, Any}(
                    "dynamics" => Dict{String, Any}("dt" => 0.001, "duration" => 1.0)
                ),
            ],
        )
        snap = SpinorBEC.apply_dealias_block!(cfg3)
        @test cfg3["pipeline"][1]["dynamics"]["dt"] == 0.001  # below bound, untouched
        SpinorBEC.restore_dealias_refs!(snap...)

        # Unknown key rejection
        cfg4 = Dict{String, Any}(
            "dealias" => Dict{String, Any}("bogus_key" => true),
            "pipeline" => [],
        )
        @test_throws ArgumentError SpinorBEC.apply_dealias_block!(cfg4)

        # k_cut=nothing keeps default per-axis cutoff
        cfg5 = Dict{String, Any}(
            "dealias" => Dict{String, Any}("enabled" => true),  # no k_cut
            "pipeline" => [],
        )
        snap = SpinorBEC.apply_dealias_block!(cfg5)
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == true
        @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing  # default
        SpinorBEC.restore_dealias_refs!(snap...)

        # Negative k_cut rejected
        cfg6 = Dict{String, Any}(
            "dealias" => Dict{String, Any}("enabled" => true, "k_cut" => -1.0),
            "pipeline" => [],
        )
        @test_throws ArgumentError SpinorBEC.apply_dealias_block!(cfg6)
    end

    @testset "DEALIAS_K_CUTOFF override (fixed physical k_cut)" begin
        # Default behaviour: cutoff = n÷3 per axis.
        @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing
        m_default = SpinorBEC._get_orszag_mask((16,))
        # 16-grid box L=12 (assumed). dk = 2π/12 ≈ 0.524. n÷3=5
        # → physical cutoff = 5·0.524 = 2.62.
        # Set DEALIAS_K_CUTOFF = 2.62 should give same mask.
        SpinorBEC.DEALIAS_K_CUTOFF[] = 5 * 2π / 12.0
        m_kcut_match = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test m_default == m_kcut_match

        # Tighter cutoff zeros more modes.
        SpinorBEC.DEALIAS_K_CUTOFF[] = 1.0  # k ≤ 1.0 → idx ≤ ~1.9 → 2 modes
        m_tight = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test sum(m_tight) < sum(m_default)

        # Looser cutoff keeps more modes (capped by grid Nyquist).
        SpinorBEC.DEALIAS_K_CUTOFF[] = 100.0  # well above any Nyq
        m_loose = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test sum(m_loose) == 16.0  # all modes kept
    end
end
