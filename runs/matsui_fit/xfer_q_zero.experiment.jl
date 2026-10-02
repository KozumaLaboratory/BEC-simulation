# 転送レートの sensitivity table — xfer_q_zero
#
# q = 0。B = 2.6 nT から導けば q/h ~ 1e-6 Hz で実質ゼロ — 彼らのコードの ZeemanQ = 1 Hz は literal で、既知の食い違い
#
# 問い: m = -6 のカスケード転送が実験より速いのは、どのノブで動くか。
#
# なぜこの arm 群が必要か: 本キャンペーンのこれまでの全 arm は c1_ratio と q を
# 「彼らのコードが出荷する値」に固定していた。損失は m=-4 / m=-2 を 23 / 31 %
# 改善したが m=-6 は 6 % 悪化させた（docs/validation/matsui_fig2c_absolute_numbers.md
# §5）— 原子は転送で m=-6 を出てから初めて失われるので、損失は原理的に m=-6 の
# 個数を増やせない。残差は転送そのものにある。
#
# 派生量（c_total = 3281.1 は a_s と N で固定、c0 + 36 c1 = c_total）:
#   c1_ratio = 0.027778  =>  c0 = 1640.5, c1 = 45.57 （c1 は上限 91.1 の 50 %）
#   基準 (1/36) は c0 = 1640.5, c1 = 45.57
# c0 と c1 は独立でない — a_s が両方を決める。両方を報告すること。特異点
# r = -1/36 からは全候補が遠い（全て正）。
#
# 判定（起動前に記録）。基準となる残差は m=-6 の rms 0.0926（初期原子数比、1-40 ms、
# 損失なし。損失を入れると 0.0986 に悪化する）:
#   感度あり : このノブが m=-6 の rms を 0.02 以上動かす（残差の 20 % 以上）
#              => そのノブが候補。改めて掃引する価値がある
#   感度なし : 0.02 未満しか動かない => 転送レートはこのノブから触れない。
#              m=-6 の残差は c1/q の外（想定: 撮像後の変換、あるいはモデル外の物理）
#   候補確定 : rms が 0.05 未満に落ちる => そのノブの値が実験と食い違っている
#
# 観測量は m = -6 の**絶対量**（初期原子数比）。生存原子で規格化した分率では
# 測らない — それは原子数の減衰を割り算で消す（同 doc §2）。
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
                    "to" => -0.0002,
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
                "from" => 2.6e-5,
                "step" => 5.0e-6,
                "to" => 2.6e-5,
            ),
        ),
    ),
)
