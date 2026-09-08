#!/usr/bin/env bash
# 2026-09-08 第 3 投 — 梯子の端への飽和を見る。理論は PINNING_THEORY.md。
#
# 主張したい描像:
#   −Ω  十分注入すると F_z が −6 に飽和し、m = −6 に凍結（|F| = 6 に戻る）
#    0   飽和しない（F_z ≈ −2.3）
#   +Ω  全 m に広がり F_z が正へ
#
# ★閾値は 1 点で狙わない。注入が **加速**していて（率 0.143 → 0.324 /単位）、
#   2 次外挿で stir 46 が閾値だが、これは測定範囲の 2.3 倍の外挿。しかも渦が
#   立てば軌道の対価が下がって閾値は後ろへずれる（pk_s30 の腕が長いかき混ぜで
#   渦 22〜57 本を作っていた）。**だから −Ω を 3 点にして曲線の折れを測る。**
#
# ★予言は「鋭い閾値」ではなく「F_z(終) 対 J_z が折れて −6 に漸近する」。
#   一様 m = −6 でも DDI は組織を作りたいので、張り付きはエネルギーの釣り合い
#   であって絶対禁止ではない。折れが観測量。
#
# ★B_final = 30 µG（実験の条件）。ω_L/μ = 0.06 で変換は止まらないが、m = −6 が
#   Zeeman 基底状態なので **張り付きを助ける向き**。
#
# ★走行中に edge_frac を見ること。L_z ≈ 25 では雲が広がる。1e-6 を超えたその腕は
#   棄却（box28 が 68 % 漏れで汚染扱いになった前例がある）。
#
# 使い方（TSUBAME のログインノードで）:
#   BR_HRT=11:00:00 bash runs/eu_barnett_redo/submit_pinning.sh
set -euo pipefail

GROUP="${BR_GROUP:-tga-kozuma-kouhi}"
HRT="${BR_HRT:-}"
DRY="${BR_DRY:-0}"

if [[ -z "$HRT" ]]; then
  echo "BR_HRT が未設定。実測 s/step から: stir 60 で 6.27 h -> 11:00:00 を推奨" >&2
  exit 2
fi

# 第 1・2 投と同一。**T_STIR と CELL だけが腕ごとに違う**。
COMMON="BR_PROTOCOL=adiabatic,BR_VARIANT=prod_box35,BR_B_GAUSS=0.03,BR_THETA=35,BR_T_QUENCH=50,BR_T_ROT_BACK=3,BR_T_FIELD_DOWN=1,BR_B_FINAL_GAUSS=3.0e-5,BR_FRAMES=8"

for req in BR_PROTOCOL BR_B_GAUSS BR_THETA BR_T_QUENCH BR_B_FINAL_GAUSS; do
  case ",$COMMON," in
    *",$req="*) ;;
    *) echo "COMMON に $req が無い。拒否する。" >&2; exit 3 ;;
  esac
done
# T_STIR は腕ごと。COMMON に入っていたら上書き事故。
case ",$COMMON," in
  *",BR_T_STIR="*) echo "T_STIR が COMMON にある。腕ごとの値が消える。" >&2; exit 3 ;;
esac

# 名前 | 変える所 | h_rt
#   −Ω を 3 点（35 / 46 / 60）で閾値を挟む。46 は 2 次外挿が示す閾値そのもの。
#   Ω=0 と +Ω は最長の 60 で、張り付かない側と広がる側の対照。
ARMS=(
  "pin_m35 |BR_CELL=minus,BR_OMEGA=0.80,BR_T_STIR=35,BR_TAG=_pin_m35|8:00:00"
  "pin_m46 |BR_CELL=minus,BR_OMEGA=0.80,BR_T_STIR=46,BR_TAG=_pin_m46|10:00:00"
  "pin_m60 |BR_CELL=minus,BR_OMEGA=0.80,BR_T_STIR=60,BR_TAG=_pin_m60|$HRT"
  "pin_z60 |BR_CELL=zero,BR_T_STIR=60,BR_TAG=_pin_z60|$HRT"
  "pin_p60 |BR_CELL=plus,BR_OMEGA=0.80,BR_T_STIR=60,BR_TAG=_pin_p60|$HRT"
)

mkdir -p logs/tsubame
echo "group=$GROUP  arms=${#ARMS[@]}"
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
  echo "投入した。**走行中に 2 つ見ること**:"
  echo "  seed polar=180.00 deg   （145 なら BR_PROTOCOL が効いていない）"
  echo "  edge=...                （1e-6 を超えたらその腕は棄却。雲が箱に触っている）"
fi
