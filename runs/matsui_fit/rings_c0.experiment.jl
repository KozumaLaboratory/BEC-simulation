# リング本数の時間変化 — c1/c0 = 0.0、単一磁場 B = +2.5 nT
#
# 論文は m=-5 と m=-4 が「2 本と 3 本のリング」からなると述べ、c1~0 と c1<0 では
# 2 本しか出ないことを c1 決定の根拠にしている（Appendix E）。我々の 32^3 でも
# 5 ms の断面で再現できた: 1/36 -> m=-4 が 3 本、c1=0 -> 1 本、0.30 -> 3 本。
#
# だが 1/36 と 0.30 が両方 3 本になる。実験側からは、リング本数が時間とともに
# 1 -> 3 -> 2 と変化するとの指摘がある。もしそうなら 5 ms の一断面で c1 を
# 決めるのは脆く、論文の決定も「その時刻でたまたま 3 本だった」に過ぎない
# 可能性がある。
#
# この run は単一磁場で 40 ms（論文 Fig.2 と同じ範囲）まで走らせ、psi を 50 点
# 保存してリング本数の時間変化を測る。B スキャンではないので 1 点。
#
# 注意: 論文の 3 本は「横から見た像」(Fig.1E) の話で、z 方向に積分すると構造が
# 消える。Psi_-5 は z*rho*exp(-i phi) の形なので z=0 に節を持つ。
#
# duration = 27.646016 t.u. = 40 ms x 691.1504 ; 27646 steps, save every 553 -> 50 snapshots
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: rings_c0
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
                "c1_ratio" => 0.0,
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
                "N_atoms" => 50000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 553,
                "precision" => "f32",
                "psi" => true,
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
                "from" => 2.5e-5,
                "step" => 5.0e-6,
                "to" => 2.5e-5,
            ),
        ),
    ),
)
