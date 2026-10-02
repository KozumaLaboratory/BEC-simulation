# 転送レート — q = 0 の交絡除去 (xfer_q0_bm, B = 1.92 nT, 下側)
#
# 交絡: q は転送レートだけでなく**共鳴位置**を動かす。q/h = 1 Hz は m=-6 -> -5 の
# 間隔を 42.3 Hz のうち 11 Hz 動かす = 共鳴位置 0.68 nT ぶん
# （runs/matsui_fig4b/fig4b_scan_n35k_n32.experiment.jl）。B = 2.6 nT 固定で q を変えた
# xfer_q_zero / xfer_q_high は、レートと離調を同時に動かしている。
# 「q が敏感」は確立したが「転送が速すぎるのは q が違うから」はまだ言えない。
#
# この 2 本は符号を決めずに両側を挟む: q = 0 で B = 1.92 / 3.28 nT。
#
# 実効磁場は **scan の override** `pipeline.1.B.Bz.to` で決まる。pipeline 内の
# インライン `to:` は上書きされて効かない — そちらだけ書き換えると 2.6 nT のまま
# 走る（実際に一度やった）。両方を一致させてある。
#
# 既に測った 4 本（tasks 50-53、m=-6 の rms、基準 0.0926）:
#   r = 1/72 : 0.1408 (+0.048 悪化)   r = 1/9 : 0.1292 (+0.037 悪化)
#     => c1_ratio は両方向で悪化。1/36 は m=-6 について局所最適
#   q = 0    : 0.0726 (-0.020 改善、ただし離調と交絡)
#   q = 10Hz : 0.3105 (+0.218)、転送は基準の 1.4-1.8 倍速い
#
# 判定（起動前に記録）: 2 点のうち良い方の m=-6 rms が
#   0.073 付近（B 固定の q=0 と同等）  => 改善はレートの効果
#   0.093 付近（基準と同等）           => 改善は離調の効果で、q は答えではない
#   0.05 未満                          => q = 0 が正しく、残差の主要因
# NO loss block — their Fig. 2/4 theory curves are loss-free.
# m=-6 → -5 transfer is DRIVEN by DDI, not seeded
# of the hold — point_001's saved psi cannot be trusted

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 35000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0104 Gauss",
                "phi" => 0.0,
                "q" => 0.0,
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
                "N_atoms" => 35000,
                "c1_ratio" => 0.027777777777777776,
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
                    "to" => 1.92e-5,
                ),
                "phi" => 0.0,
                "q" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2,
                "padded" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 27.646016,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 35000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f32",
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
                "from" => 1.92e-5,
                "step" => 5.0e-6,
                "to" => 1.92e-5,
            ),
        ),
    ),
)
