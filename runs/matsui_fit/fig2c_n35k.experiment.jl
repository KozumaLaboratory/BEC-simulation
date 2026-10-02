# Fig. 2C の時系列を彼らの条件で再現する — N = 3.5e4, B = 2.6 nT, 40 ms
#
# 既存の 40 ms run は c1 走査の副産物で N = 5e4 / B = +2.5 nT だった。論文 Fig. 2C
# は 2.6 nT・40 ms で、彼らのシミュレーションは実効 N = 3.5e4（同梱コードの Ntot）。
# コード対コードの比較にはこの条件が要る。
#
# 判定（起動前に記録）: Fig. 4B では N = 3.5e4 で彼らの曲線を per-field rms 1.1 %
# で再現した。Fig. 2C でも同程度（各成分の rms < 0.02）なら、我々の再現は時系列
# 全体で確立し、実験との差を我々の側から論じられる。rms が 0.05 を超えるなら
# 条件が揃っていないか、時系列には Fig. 4B に無い依存性がある。
#
# 参考（N = 5e4 / +2.5 nT で測った既存 run のコード対コード差、40 ms 平均）:
#   m=-6 rms 0.109, m=-5 0.065, m=-4 0.107, m=-3 0.049, m=-2 0.107
#
# 著者の主張（本文）は「m <= -5 は実験と合う、m >= -4 は loss-free なので合わない」。
# 実測すると彼らのシミュレーション vs 実験は m=-5 rms 0.053 / m=-3 0.043 に対し
# m=-4 0.129 / m=-2 0.158 で、主張と整合する。ただし m=-6 は rms 0.263 で最悪、
# シミュレーションが 0.24 も転送しすぎており、Fig. 4B の残差と同じ向き。
#
# psi は保存しない（成分個体数の時系列のみ必要）。every=100 で 276 点。
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
                "from" => 2.6e-5,
                "step" => 5.0e-6,
                "to" => 2.6e-5,
            ),
        ),
    ),
)
