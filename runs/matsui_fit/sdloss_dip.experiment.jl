# スピン依存三体損失を較正値で入れた dip スキャン
#
# K3(m != -6) = 2.6e-28 cm^6/s。較正: 単一磁場 40 ms で総原子数の減少が
# 論文 Appendix D の「トラップ内 26 % / 40 ms」に一致するよう内挿した
# （1.0e-28 -> 13.6 %、5.0e-28 -> 42.0 %、2.0e-27 -> 69.4 %）。
# m = -6 の係数は 0、他 12 成分に同値。自由パラメータではない。
#
# 棄却基準（起動前に記録、単一磁場での較正 arm から引き継ぎ）:
#   幅   実験 11.800 +- 0.279、損失なしで 13.140（4.8 sigma）
#   深さ 実験 0.3148 +- 0.0046、損失なしの dip 最小値 0.2139（21.9 sigma）
#   合格: 両方 2 sigma 以内 / 部分: 片方 / 棄却: どちらも超過
#   中心は磁場軸の +-10 nT 系統誤差のため判定に使わない
#
# 注意: 較正 arm で B = +2.5 nT 固定の m=-6 割合は損失なしで既に 0.3151 で、
# 実験の dip 最小値 0.3148 とほぼ一致する。だがそれは別の量（実験の 0.3148 は
# B ~ -3.4 nT の dip 最小）。同じ量どうしで比べるためにこのスキャンが要る。
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: sdloss_dip
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
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "0.0 cm^6/s"],
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
