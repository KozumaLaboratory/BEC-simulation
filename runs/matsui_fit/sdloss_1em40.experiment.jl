# スピン依存三体損失の較正 — K3(m != -6) = 1.0e-28 cm^6/s
#
# 論文 Appendix D が機構と大きさを両方与えている:
#   "the atoms were likely to be lost in three-body collisions involving atoms
#    NOT in the m = -6 component"
#   トラップ内の寄与は 40 ms で 26 %（0.1 mT を 2 ms 遅らせた測定から）。
#   残り 12 % は撮像中の 0.1 mT 下 2 ms 膨張、2 % は偏極ガス固有（0.55 /s）。
#
# 以前の K3 走査（撤回済み）は全 13 成分に同じ係数を入れた「スピン非依存」で、
# n^3 は転送されず密度が高いところで最大になるため、場依存の向きが実験と逆に
# なった。ここでは m = -6 の係数を 0 にし、転送された成分だけが失われる形にする。
#
# 近似の明示: 実際の三体衝突は m = -6 の原子も巻き込むが、per-m の指数減衰
# exp(-K3_m n_tot^2 dt/2) では「m != -6 の原子だけが失われる」になる。総量の
# 減り方は較正で合わせられるが、成分ごとの比は正確ではない。
#
# 較正: この 3 本で 40 ms の総原子数減少を測り、26 % を与える K3 に内挿する。
# 手計算の見積もりは 5e-40 m^6/s = 5e-28 cm^6/s（偏極ガス値 1.2e-41 の 43 倍。
# 論文自身が 0.55/s と 26 %/40 ms でレート比 48 倍を報告しているので整合）。
#
# 較正後に dip を 1 本走らせ、以下で判定する（起動前に記録）:
#   幅   実験 11.800 +- 0.279、現状 13.140（4.8 sigma）
#   深さ 実験 0.3148 +- 0.0046、現状 0.2139（21.9 sigma）
#   合格: 両方 2 sigma 以内 -> 機構が確認された
#   部分: 片方のみ         -> 機構は効くが不足
#   棄却: どちらも 2 sigma 超 -> この形の損失では説明できない
# 中心は磁場軸の +-10 nT 系統誤差のため判定に使わない。
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: sdloss_1em40
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
            "duration" => 27.646016,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "1.0e-28 cm^6/s", "0.0 cm^6/s"],
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
