#!/usr/bin/env bash
# 2026-09-09 第 4 投 — **磁場ランプを断熱にする。**
#
# 何を測るか: 既存の bf30 の 3 腕は field_down が 1 単位の線形ランプで、これは
# 終端 30 uG で A = |dp/dt|/gap^2 = 2050、つまり完全なクエンチ。だから Omega = 0
# でも F_z が振動する。同じ状態から**断熱ランプ**で降ろすと、振動が消えて
# 終着点そのものが読めるはず。
#
# ★なぜ断熱が可能か（「不可能」と一度言ったのは私の誤り）:
#   断熱条件 |dp/dt| < A p^2 は**局所条件**なので、線形ランプは最悪の形。
#   1/p を時間に線形にすると A が一定になり、コストは
#       T = (1/|p_f| - 1/|p_i|) / A = 2.046 / A
#   A = 0.1 で T = 20.5。線形で同じ終端 A を出すには 3.7e4 かかる ── 1800 倍。
#   投入前に検算済み: adiabatic は A が 0.097〜0.102（max/min 1.05）、
#   linear は 1e-4〜92.8（90 万倍振れる）。
#
# ★前半 33 単位は再計算しない。frames_*.jld2 の frame_032 が t = 33.0 ちょうど
#   （rotate_back 終了）なので、そこから再開する。**線形の腕と同一の状態から
#   分岐する**ので、比較は ramp の形だけの差になる。run_core.jl 側で cell /
#   omega / ddi / grid / box / t / norm / peak を全部照合して、違えば拒否する。
#
# ★コスト: フル 84 単位が実測 3h45m。ここは 45 単位 + JIT で ~2h。
#
# 使い方（TSUBAME のログインノードで）:
#   bash runs/eu_barnett_redo/submit_adiabatic.sh
set -euo pipefail

GROUP="${BR_GROUP:-tga-kozuma-kouhi}"
HRT="${BR_HRT:-4:00:00}"
DRY="${BR_DRY:-0}"
DATA="$PWD/runs/eu_barnett_redo/data"

T_FD="${BR_FD:-20}"        # field_down。A = 2.046/20 = 0.102
T_HOLD="${BR_HOLD:-25}"    # 降ろしきってからの保持

COMMON="BR_PROTOCOL=adiabatic,BR_VARIANT=prod_box35,BR_B_GAUSS=0.03,BR_THETA=35"
COMMON="$COMMON,BR_T_STIR=20,BR_T_ROT_BACK=3,BR_B_FINAL_GAUSS=3.0e-5"
COMMON="$COMMON,BR_FIELD_DOWN_SHAPE=adiabatic,BR_T_FIELD_DOWN=$T_FD,BR_T_QUENCH=$T_HOLD"
COMMON="$COMMON,BR_RESTART_T=33,BR_FRAMES=0,BR_COLFRAMES=1"

# 落とすと黙って別のものが走る env は、名指しで存在確認する。
# （第 2 投で BR_PROTOCOL を落とし、6 腕 45 分ぶんを sudden で走らせた前例。）
for req in BR_PROTOCOL BR_B_GAUSS BR_THETA BR_B_FINAL_GAUSS \
           BR_FIELD_DOWN_SHAPE BR_T_FIELD_DOWN BR_RESTART_T BR_T_STIR BR_T_ROT_BACK; do
  case ",$COMMON," in
    *",$req="*) ;;
    *) echo "COMMON に $req が無い。拒否する。" >&2; exit 3 ;;
  esac
done
# BR_RESTART_FRAMES は腕ごと。COMMON に入っていたら 3 腕とも同じ状態から走る。
case ",$COMMON," in
  *",BR_RESTART_FRAMES="*)
    echo "BR_RESTART_FRAMES が COMMON にある。3 腕が同じ初期状態になる。" >&2; exit 3 ;;
esac

# 名前 | cell | omega | 再開元
ARMS=(
  "ad_p|plus |0.80|plus_bf30_omp08"
  "ad_z|zero |0.00|zero_bf30_om0"
  "ad_m|minus|0.80|minus_bf30_omm08"
)

# 再開元が **全部** 揃っていることを 1 本も投げる前に確かめる。
# 途中で落ちると 1 腕だけ走って「3 腕の比較」が 2 腕になる。
for spec in "${ARMS[@]}"; do
  IFS='|' read -r _name _cell _om src <<< "$spec"
  f="$DATA/frames_${src}_prod_box35.jld2"
  [[ -f "$f" ]] || { echo "再開元が無い: $f" >&2; exit 4; }
  sz=$(stat -c%s "$f")
  [[ "$sz" -gt 1000000000 ]] || { echo "再開元が小さすぎる ($sz B): $f" >&2; exit 4; }
  echo "  再開元 OK  $(basename "$f")  $((sz / 1024 / 1024 / 1024)) GiB"
done

echo "field_down $T_FD + hold $T_HOLD = $((T_FD + T_HOLD)) 単位 / 腕、h_rt $HRT"

for spec in "${ARMS[@]}"; do
  IFS='|' read -r name cell om src <<< "$spec"
  cell="${cell// /}"
  env="$COMMON,BR_CELL=$cell,BR_OMEGA=$om,BR_TAG=_$name"
  env="$env,BR_RESTART_FRAMES=$DATA/frames_${src}_prod_box35.jld2"
  cmd=(qsub -g "$GROUP" -N "$name" -l "h_rt=$HRT" -v "$env"
       runs/eu_barnett_redo/tsubame_core.sh)
  if [[ "$DRY" == "1" ]]; then
    printf '%q ' "${cmd[@]}"; echo
  else
    "${cmd[@]}"
  fi
done
