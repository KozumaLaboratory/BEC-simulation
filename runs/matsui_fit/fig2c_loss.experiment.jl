# Fig. 2C の時系列に、較正済みのスピン依存三体損失を入れる
#
# 自由パラメータはゼロ。K3(m != -6) = 2.6e-28 cm^6/s は論文 Appendix D の
# 「トラップ内 26 % / 40 ms」から較正した値（単一磁場 40 ms で 1.0e-28 -> 13.6 %,
# 5.0e-28 -> 42.0 %, 2.0e-27 -> 69.4 % を測り、26 % に内挿）。m = -6 の係数は 0。
#
# 機構は論文が特定している:
#   "the atoms were likely to be lost in three-body collisions involving atoms
#    NOT in the m = -6 component"
#
# なぜ 5 ms の dip では検証できなかったか: 40 ms で 25 % 失う損失も、5 ms 時点
# では 4.7 % しか効かない（較正 arm の実測）。dip はその断面なので、損失が効く前
# に測っていた。40 ms の時系列なら十分効く。
#
# 前提（本 run の直前に確立）: 損失なしで我々は彼らのシミュレーションを 40 ms
# 全体・5 成分で rms 0.0075 で再現する。したがってここから先の差は我々の側の
# 問題ではない。
#
# 判定（起動前に記録）。Matsui のシミュレーション vs 実験の rms:
#   m=-6 0.263（最悪、シミュレーションが 0.24 転送しすぎ）
#   m=-5 0.053, m=-3 0.043（著者いわく「合う」）
#   m=-4 0.129, m=-2 0.158（著者いわく loss-free ゆえ「合わない」）
#
#   合格: 損失を入れて m=-6 の rms が 0.10 未満（現状の 40 % 未満）に落ち、
#         かつ m=-5/m=-3 が悪化しない（0.08 未満に留まる）
#   部分: m=-6 は改善するが他が悪化、または改善が半分以下
#   棄却: m=-6 がほとんど動かない（rms > 0.20）
#
# 損失は m != -6 の 12 成分に等係数。近似の明示: 実際の三体衝突は m=-6 の原子も
# 巻き込むが、per-m の exp(-K3_m n^2 dt/2) では m != -6 だけが失われる。総量は
# 較正で合うが、成分ごとの比は正確でない。
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
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "2.6e-28 cm^6/s", "0.0 cm^6/s"],
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
