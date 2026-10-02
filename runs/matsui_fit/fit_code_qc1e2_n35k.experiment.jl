# N = 35000, c1_ratio = 0.0002777777777777778、q は |B|^2 から自動導出（q: 行を削除）
#
# 同梱コード time.f90 を読んで見つかった 3 件の食い違いのうち 2 件を測る。
#
# (1) 二次 Zeeman が固定されている。setup_parameters は
#         ZeemanQ = 1.d0 !Hz calculate from Bfield shen ZeemanQ=0
#     と 1 Hz を直接与えており（0 にすれば B^2 から計算する経路がある）、主ループは
#     ZeemanP だけを更新して ZeemanQ は触らない。だが q = (g_F mu_B B)^2 / E_hf なので、
#     1.04 uT -> 2.6 nT の 400 分の 1 の変化に対し q は 16 万分の 1 になるはず。
#     初期磁場での正しい値ですら 0.162 Hz で、1 Hz とは 6 倍違う。保持中の正しい値は
#     ~1e-6 Hz、すなわち実質ゼロ。campaign の測定では q/h = 1 Hz は m=-6/-5 間隔を
#     11 Hz 動かし、共鳴位置に直すと 0.68 nT に相当する。
#
# (2) c1/c0 が論文と 100 倍違う。NM==6 分岐は
#         cc1 = cc0 * 1.d-2/36.d0
#     で実効 c1/c0 = 1/3600。論文本文は c0 = 2*pi*hbar^2*a12/M,
#     c1 = (1/18)*pi*hbar^2*a12/M すなわち 1/36。我々はこれまで論文側 (1/36) を
#     使いつつ N は同梱コード側 (3.5e4) を使う混成だった。
#
# 3 件目（Ehf = 1.772e9 は Na23 の超微細分裂で Eu のものではない）は、ZeemanQ が
# 直接与えられているため q の計算に使われず、他に使用箇所も無いので無害。
#
# 中心は磁場軸の +-10 nT 系統誤差のため実験比較には使えない。使えるのは幅と深さ、
# および「彼らの公開曲線をどちらの設定が再現するか」というコード対コードの判定。
#
# 一次情報: docs/validation/matsui_experiment_parameters.md
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: fit_code_qc1e2_n35k
# grid_n: 32
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
                "c1_ratio" => 0.0002777777777777778,
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
                "N_atoms" => 35000,
                "c1_ratio" => 0.0002777777777777778,
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
