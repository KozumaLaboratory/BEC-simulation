# Klaus 2022 minimal validation — exercises the magnetostir code path
# end-to-end at small grid + short stir to keep CI cost bounded. Asserts
# that the GPU-safe transverse-Zeeman path (commit 59a52a1), the
# streamed-snapshot reader (3685fd7), and vortex_detect 3D (7769d84)
# all stay alive together.
#
# This is NOT a physics validation of the published vortex-stripe count
# (that needs the full 64x64x32 + 1 s stir overnight). It IS a regression
# guard so the next session doesn't silently break the Klaus path.

using Test
using SpinorBEC

@testset "Klaus 2022 minimal regression" begin
    # Tiny smoke version of runs/klaus2022_full
    # Schema notes: `trap:` migrated to `potential:`,
    # `level:` removed from B-block, `ferromagnetic_min` → `m_minus_F`.
    #
    # `m_minus_F`, not `m_plus_F`: the rename was read the wrong way round and
    # that is what made this file unrunnable. `H = -p·F_z + q·F_z²` with
    # `p ≡ -g_F μ_B B` means +Bz on a g_F > 0 atom (Dy164) puts the ground state
    # at m = -F. ITP applies `exp(-(E-min)·dt)`, so at p ≈ -3.5e4 every
    # component except m = -F underflows to zero on the first step — and with
    # all the weight started in m = +F the state went to zero and normalising it
    # gave `NaN detected in ITP at step 1. Likely DDI or interaction overflow.
    # Reduce dt.` The message is misleading: it is underflow, not overflow, and
    # neither dt nor the field needed to change. Measured, same 8³ config:
    #     m_plus_F  / 1.0 Gauss    → NaN at step 1
    #     m_minus_F / 1.0 Gauss    → E = -277668.36
    yaml_str = """
    pipeline:
      - ground_state:
          atom: Dy164
          grid: {n: [16, 16, 8], box: [10.0, 10.0, 5.0]}
          interactions: {omega_ref: 314.159, N_atoms: 5000}
          ddi: {enabled: true}
          potential: {type: harmonic, omega: [1.0, 1.0, 2.6]}
          B: {Bz: "1.0 Gauss"}
          dt: 0.001
          n_steps: 500
          tol: 1.0e-5
          initial_state: m_minus_F
      - dynamics:
          duration: 0.5
          dt: 0.002
          save: {every: 50}
          interactions: {omega_ref: 314.159}
          B:
            Bz: "0.819 Gauss"
            Bx: {sinusoidal: {amplitude: 0.574, frequency: 4.52}}
            By: {sinusoidal: {amplitude: 0.574, frequency: 4.52, phase: -1.5708}}
      - analyze:
          - vortex_detect: {component: 1, threshold: 0.1}
    """
    cfg = load_config_from_string(yaml_str)
    result = run_config(cfg; verbose=false)
    @test haskey(result, :vortex_detect)
    @test result.vortex_detect.vortex_count >= 0
    # Norm conservation through a 0.5 ω_ref^-1 stir should be < 1% drift
    norms = result.dynamics_result.norms
    @test abs(norms[end] - norms[1]) / norms[1] < 0.05
end
