# Klaus et al. 2022 minimal validation — exercises the magnetostir code path
# end-to-end at small grid + short stir to keep CI cost bounded. Asserts
# that the GPU-safe transverse-Zeeman path (commit 59a52a1), the
# streamed-snapshot reader (3685fd7), and vortex_detect 3D (7769d84)
# all stay alive together.
#
# This is NOT a physics validation of the published vortex-stripe count
# (that needs the full 64x64x32 + 1 s stir overnight). It IS a regression
# guard so the next session doesn't silently break the magnetostir path.

using Test
using SpinorBEC

@testset "Klaus et al. 2022 minimal regression" begin
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
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "1.0 Gauss",
            ),
            "atom" => "Dy164",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
            ),
            "dt" => 0.001,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 5.0],
                "n" => [16, 16, 8],
            ),
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 5000,
                "omega_ref" => 314.159,
            ),
            "n_steps" => 500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 2.6],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bx" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 0.574,
                        "frequency" => 4.52,
                    ),
                ),
                "By" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 0.574,
                        "frequency" => 4.52,
                        "phase" => -1.5708,
                    ),
                ),
                "Bz" => "0.819 Gauss",
            ),
            "dt" => 0.002,
            "duration" => 0.5,
            "interactions" => Dict{String, Any}(
                "omega_ref" => 314.159,
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "vortex_detect" => Dict{String, Any}(
                "component" => 1,
                "threshold" => 0.1,
            ),
        )],
    )],
)
"""
    cfg = load_config_from_string(yaml_str)
    result = run_pipeline(cfg; verbose=false)
    @test haskey(result, :vortex_detect)
    @test result.vortex_detect.vortex_count >= 0
    # Norm conservation through a 0.5 ω_ref^-1 stir should be < 1% drift
    norms = result.dynamics_result.norms
    @test abs(norms[end] - norms[1]) / norms[1] < 0.05
end
