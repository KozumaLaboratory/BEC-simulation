#!/usr/bin/env bash
# 2026-09-08 第 2 投 — **最終磁場を残す**。第 1 投は 0 にしてしまっていた。
#
# ★第 1 投（submit_edh_baseline.sh）は BR_B_FINAL_GAUSS=0.0 で走った。指定は
#   「最後に弱い z を残す」だったので、あれは別の実験になっていた。無効ではなく
#   「B=0 極限」というきれいな参照だが、実験と比べる数字ではない。
#
# ★なぜ弱磁場が無視できないか。内部単位で omega_ref = 628.3 rad/s = 100 Hz なので
#   Omega = 0.80 は実周波数 80 Hz。回転座標系の共鳴は omega_L = Omega、すなわち
#       p = Omega  ->  B = 49.2 uG      （p/B = 16275.5 /G、走行ログの実測から）
#   実験側 euv3.ts の hold = 30 uG は共鳴の 0.61 倍で、**通り越した側**。
#   euv3.ts 自身が「80 Hz の共鳴は 49.2 uG」と警告を出す設計になっていて、
#   ここで計算した値と一致した。
#
#   ⇒ 30 uG は摂動ではない。omega_L/Omega = 0.61 で **Omega と同じ桁**。
#
# 腕の設計: 第 1 投（B=0）と 1 ノブだけ違う ── B_final。
#   30 uG × (+Omega / 0 / −Omega)   実験の条件そのもの。偶奇が B=0 とどう変わるか
#   49 uG × +Omega                  共鳴の上。ここで何か起きるかが最大の問い
#
# 使い方（TSUBAME のログインノードで）:
#   BR_HRT=6:00:00 bash runs/eu_barnett_redo/submit_bfinal.sh
#   BR_DRY=1 BR_HRT=6:00:00 bash runs/eu_barnett_redo/submit_bfinal.sh
set -euo pipefail

GROUP="${BR_GROUP:-tga-kozuma-kouhi}"
HRT="${BR_HRT:-}"
DRY="${BR_DRY:-0}"

if [[ -z "$HRT" ]]; then
  echo "BR_HRT が未設定。probe で測った s/step から決めること（推測しない）。" >&2
  echo "  第 1 投の実測: 傾いた段 0.220 s/step、quench 0.118 s/step (H100) -> 3.83 h" >&2
  exit 2
fi

# 第 1 投と同一。**B_FINAL_GAUSS だけが違う**。
COMMON="BR_PROTOCOL=adiabatic,BR_VARIANT=prod_box35,BR_B_GAUSS=0.03,BR_THETA=35,BR_T_STIR=20,BR_T_QUENCH=50,BR_T_ROT_BACK=3,BR_T_FIELD_DOWN=1,BR_FRAMES=8"

# 省略できない env を名前で要求する。既定値が別の実験になるものは、渡し忘れが
# 静かに通ってはいけない ── BR_PROTOCOL の既定 "sudden" で 6 腕を捨てた。
for req in BR_PROTOCOL BR_B_GAUSS BR_THETA BR_T_STIR BR_T_QUENCH; do
  case ",$COMMON," in
    *",$req="*) ;;
    *) echo "COMMON に $req が無い。拒否する。" >&2; exit 3 ;;
  esac
done
# B_FINAL は腕ごとに違うので COMMON に入れない。**入っていたら事故**なので弾く。
case ",$COMMON," in
  *",BR_B_FINAL_GAUSS="*) echo "B_FINAL が COMMON にある。腕ごとの値が上書きされる。" >&2; exit 3 ;;
esac

# 名前 | 変える所 | h_rt
ARMS=(
  "bf30_omp08 |BR_CELL=plus,BR_OMEGA=0.80,BR_B_FINAL_GAUSS=3.0e-5,BR_TAG=_bf30_omp08|$HRT"
  "bf30_om0   |BR_CELL=zero,BR_B_FINAL_GAUSS=3.0e-5,BR_TAG=_bf30_om0|$HRT"
  "bf30_omm08 |BR_CELL=minus,BR_OMEGA=0.80,BR_B_FINAL_GAUSS=3.0e-5,BR_TAG=_bf30_omm08|$HRT"
  "bf49_omp08 |BR_CELL=plus,BR_OMEGA=0.80,BR_B_FINAL_GAUSS=4.92e-5,BR_TAG=_bf49_omp08|$HRT"
)

mkdir -p logs/tsubame
echo "group=$GROUP  h_rt=$HRT  arms=${#ARMS[@]}"
echo "common: $COMMON"
echo

for spec in "${ARMS[@]}"; do
  name="${spec%%|*}"; name="${name// /}"
  rest="${spec#*|}"; vars="${rest%%|*}"; hrt="${rest#*|}"
  cmd=(qsub -g "$GROUP" -N "$name" -l gpu_1=1 -l "h_rt=$hrt"
       -o "logs/tsubame/${name}.log" -j y
       -v "${COMMON},${vars}"
       runs/eu_barnett_redo/tsubame_core.sh)
  if [[ "$DRY" == "1" ]]; then printf '%q ' "${cmd[@]}"; echo; else "${cmd[@]}"; fi
done

if [[ "$DRY" != "1" ]]; then
  echo
  echo "投入した。**バナーで 2 つ確認すること**:"
  echo "  seed polar=180.00 deg   （145 なら BR_PROTOCOL が効いていない）"
  echo "  p=-488.2664 (B=0.03 G)  （かき混ぜ磁場。最終磁場はバナーに出ない）"
  echo "  qstat -u \$USER"
fi
