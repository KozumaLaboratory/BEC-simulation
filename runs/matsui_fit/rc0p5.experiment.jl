# c1/c0 = 0.5 — リング本数で c1 を挟む、上限を探す
#
# 5 ms の m=-4 リング本数（B=+2.5 nT, 32^3, N=5e4）は既存 run から:
#   c1/c0 = -1/72 -> 2,  0 -> 1,  0.0069 -> 1,  0.0278 -> 3,
#           0.056 / 0.111 / 0.15 / 0.20 / 0.25 / 0.30 -> すべて 3
# 下限の境界は 0.0069 と 0.0278 の間。上限は 0.30 まで動かないので未定。
# 分解能非依存であることは 32/64/128^3 で確認済み（5 ms は 3 格子とも一致）。
#
# この arm は 0.30 より上で本数が変わるかを見る
#
# 論文の値は 1/36 = 0.0278、同梱コードの実効値は 1e-2/36 = 0.000278（1 本になり、
# 論文が図示する 3 本を再現しない）。
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: rc0p5
# grid_n: 32
# NO loss block — their Fig. 2/4 theory curves are loss-free.
# m=-6 → -5 transfer is DRIVEN by DDI, not seeded
# of the hold — point_001's saved psi cannot be trusted

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0104 Gauss",
                "phi" => 0.0,
                "q" => 0.00909116,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2,
                "padded" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [16.0, 16.0, 16.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.5,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 4000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-10,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.1037,
                    "from" => 0.0104,
                    "to" => -0.0002,
                ),
                "phi" => 0.0,
                "q" => 0.00909116,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2,
                "padded" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 3.4558,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.5,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 108,
                "precision" => "f64",
                "psi" => false,
            ),
            "seed_amplitude" => 0.0,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "zip" => Dict{String, Any}(
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
        ),
    ),
)
