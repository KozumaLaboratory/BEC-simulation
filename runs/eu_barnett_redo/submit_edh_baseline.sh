#!/usr/bin/env bash
# 2026-09-08 の投入 — EdH 基準つきの 1 ノブ組。設計は SUBMISSION_2026_09_08.md。
#
# ★なぜ組にするか: 手元の 3 腕は磁場・Omega・クエンチ長が同時に違い、互いに
#   比較できなかった。しかも Omega = 0 が「何も起きない対照」ではなく **EdH が
#   +3.13 走っている**ことが分かった（30 mG 腕の +1.68 はそれより小さい）。
#   だから 1 ノブだけ違う組を撮る。**基準（#1）が無いと他の数字は意味を持たない。**
#
# 使い方（TSUBAME のログインノードで、送ったツリーの中から）:
#   bash runs/eu_barnett_redo/submit_edh_baseline.sh            # 投入
#   BR_DRY=1 bash runs/eu_barnett_redo/submit_edh_baseline.sh   # コマンドを表示だけ
#
# h_rt は環境変数で渡す。**推測しない** ── probe で測った s/step から決める。
#   BR_HRT=14:00:00 bash ...
set -euo pipefail

GROUP="${BR_GROUP:-tga-kozuma-kouhi}"
HRT="${BR_HRT:-}"
DRY="${BR_DRY:-0}"

if [[ -z "$HRT" ]]; then
  echo "BR_HRT が未設定。probe で s/step を測ってから渡すこと（推測で決めない）。" >&2
  echo "  例: BR_HRT=14:00:00 bash $0" >&2
  exit 2
fi

# 共通条件。**ここを 1 か所にするのが組の定義**。
#   30 mG / theta 35 / box35 240^3 / dt 1e-3 / stir 20 / quench 50
# quench を 50 にするのは conv35 腕が t~70 で飽和しているため。20 では打ち切りに
# なる（それが 30 mG 腕の t=51 で、F_z がまだ動いていた）。
# ★BR_PROTOCOL=adiabatic は**省略できない**。既定は "sudden" で、そちらは
#   傾け段が無く、スピンを最初から傾いた向きに置く（seed polar 145 deg）。
#   2026-09-08 に渡し忘れて 6 腕を投入し、45 分走らせて捨てた ── ログの段名が
#   `tilt` ではなく `stir` から始まり、Fz が −4.91 に留まらず +0.48〜−3.02 で
#   振動していたので気づいた。**バナーの seed polar が 180 deg でなければ違う実験。**
COMMON="BR_PROTOCOL=adiabatic,BR_VARIANT=prod_box35,BR_B_GAUSS=0.03,BR_THETA=35,BR_T_STIR=20,BR_T_QUENCH=50,BR_T_ROT_BACK=3,BR_T_FIELD_DOWN=1,BR_B_FINAL_GAUSS=0.0,BR_FRAMES=8"

# 投入前の検算。**省略できない env を名前で要求する** ── 既定値が別の実験に
# なるものは、渡し忘れが静かに通ってはいけない。
for req in BR_PROTOCOL BR_B_GAUSS BR_THETA BR_T_STIR BR_T_QUENCH; do
  case ",$COMMON," in
    *",$req="*) ;;
    *) echo "COMMON に $req が無い。既定値が別の実験になる可能性があるので拒否する。" >&2
       exit 3 ;;
  esac
done

# 各腕: 名前 | 変える所
#   ★Omega は CELL=zero では run_core が 0 に固定する（typo で壊せない設計）
# 3 列目は h_rt。**腕ごとに分ける** ── dt を半分にすれば歩数は倍で、
# 共通の h_rt にすると dt=5e-4 の腕だけが必ず時間切れになる（dry-run で気づいた）。
# 見積りは probe の実測から: 傾いた段 0.220 s/step、quench 0.118 s/step (H100)。
#   dt=1e-3 -> 3.71 h、dt=5e-4 -> 7.30 h。余裕 60 %。
ARMS=(
  "b8_om0   |BR_CELL=zero,BR_TAG=_b8_om0|$HRT"
  "b8_omp08 |BR_CELL=plus,BR_OMEGA=0.80,BR_TAG=_b8_omp08|$HRT"
  "b8_omp09 |BR_CELL=plus,BR_OMEGA=0.90,BR_TAG=_b8_omp09|$HRT"
  "b8_omm08 |BR_CELL=minus,BR_OMEGA=0.80,BR_TAG=_b8_omm08|$HRT"
  "b8_nodd  |BR_CELL=plus_nodd,BR_OMEGA=0.80,BR_TAG=_b8_nodd|$HRT"
  "b8_dt5e4 |BR_CELL=plus,BR_OMEGA=0.80,BR_DT=5.0e-4,BR_TAG=_b8_dt5e4|${BR_HRT_LONG:-12:00:00}"
)

mkdir -p logs/tsubame
echo "group=$GROUP  h_rt=$HRT (dt5e4 は ${BR_HRT_LONG:-12:00:00})  arms=${#ARMS[@]}"
echo "common: $COMMON"
echo

for spec in "${ARMS[@]}"; do
  name="${spec%%|*}"; name="${name// /}"
  rest="${spec#*|}"
  vars="${rest%%|*}"
  hrt="${rest#*|}"
  cmd=(qsub -g "$GROUP" -N "$name" -l gpu_1=1 -l "h_rt=$hrt"
       -o "logs/tsubame/${name}.log" -j y
       -v "${COMMON},${vars}"
       runs/eu_barnett_redo/tsubame_core.sh)
  if [[ "$DRY" == "1" ]]; then
    printf '%q ' "${cmd[@]}"; echo
  else
    "${cmd[@]}"
  fi
done

if [[ "$DRY" != "1" ]]; then
  echo
  echo "投入した。監視:"
  echo "  qstat -u \$USER"
  echo "  tail -f logs/tsubame/b8_om0.log"
  echo
  echo "★見るのは leak/conversion の行。窓は 2026-09-08 に直してあるので"
  echo "  rampdown を含まない（含めていたとき 48.9% の誤報が出ていた）。"
fi
