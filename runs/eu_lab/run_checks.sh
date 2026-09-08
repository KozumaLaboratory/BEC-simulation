#!/usr/bin/env bash
# 検査をまとめて走らせる。
#
# ★2026-09-05 に装置は euv3.ts (TypeScript) に移った。下の JS 向け検査は
#   euv4_transfer.js（Rhino 期）に対するもので、**もう装置に流すファイルではない**。
#   歴史として残してあり、euv4 を触るときだけ意味がある。
#
#   euv3.ts に対していまできる検査は check_context.py だけ ── ライブラリが
#   Windows 側 (C:/Users/eu_public/workspace/ts/lib/) にあるので、ここでは
#   型検査もトレースもできない。**構造を変えたら Windows 側で型検査を通すこと。**
#
# 何を保証して、何を保証しないか（JS 側）:
#   保証する  — プログラム内部の一貫性。DAQ 呼び出し列、単調性、方程式文字列、
#               閉ループがノイズを信号と読まないこと。
#   保証しない — ホストについての思い込み。全部「原文から作ったホストの模型」に
#               対する検査なので、実機側が違えば通ったまま壊れる。
#
# 使い方:
#   bash run_checks.sh [euv4_transfer.js のパス]
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:-$HERE/../../euv4_transfer.js}"
REF="${2:-$HERE/../../euv3r14_transfer.js}"

if [[ ! -f "$SRC" ]]; then
  echo "見つからない: $SRC" >&2
  exit 2
fi

fail=0
run() {  # run <名前> <コマンド...>
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    echo "  PASS  $name"
  else
    echo "  FAIL  $name"
    echo "$out" | sed 's/^/        /'
    fail=1
  fi
}

echo "== 検査 (JS 期: euv4_transfer.js / 現行: euv3.ts の参照) =="
echo "対象: $SRC"

# 1. DAQ 呼び出し列。r14 との差は「意図した 1 行 + CSV ログの 4 呼び出し」だけ。
#    ここが増えたら、意図しない挙動差が入った。
if [[ -f "$REF" ]]; then
  node "$HERE/trace.js" "$REF" > /tmp/euv4_t_ref.txt 2>/dev/null
  node "$HERE/trace.js" "$SRC" > /tmp/euv4_t_new.txt 2>/dev/null
  n=$(diff /tmp/euv4_t_ref.txt /tmp/euv4_t_new.txt | grep -c '^[<>]' || true)
  # 期待 7 = setAnalog の 1 行差 (2) + createCSV/getPoints/put/put (4) + calls 行 (1)
  if [[ "$n" -le 7 ]]; then
    echo "  PASS  trace 差分 $n 行（期待 7 以下）"
  else
    echo "  FAIL  trace 差分 $n 行 — 意図しない挙動差の可能性"
    diff /tmp/euv4_t_ref.txt /tmp/euv4_t_new.txt | sed 's/^/        /'
    fail=1
  fi
else
  echo "  SKIP  trace 差分（r14 が無い: $REF）"
fi

run "蒸発の摂動・単調性・ショット割り当て" node "$HERE/check_evap.js" "$SRC"
run "Barnett の方程式文字列 576 本"       node "$HERE/check_eq.js"   "$SRC"
run "ランプの符号（+- を作らない）"        node "$HERE/check_signs.js" "$SRC"

# 閉ループは陽性・陰性の両対照。陰性だけ通っても「門が固すぎて何も通らない」で
# 同じ結果になるので、両方見る。
echo "  -- 閉ループ（合成応答, 3 seed）--"
for s in 2463534242 111111 987654321; do
  neg=$(node "$HERE/check_loop.js" "$SRC" overwrite 0.05 4000 "$s" null 2>&1 \
        | grep -oE '採用 [0-9]+ 件' | head -1)
  pos=$(node "$HERE/check_loop.js" "$SRC" overwrite 0.05 4000 "$s" 2>&1 \
        | grep -oE '到達率 best/真の最大 = [0-9.]+' | head -1)
  echo "     seed $s  陰性: ${neg:-?}  陽性: ${pos:-?}"
done

echo "  -- batch 演算（設定を変えて何ショットになるか）--"
cases=$(python3 "$HERE/mkcases.py" "$SRC" 2>&1 | head -1)
echo "     $cases"

echo "  -- 解析スクリプトの自己検査 --"
run "analyze.py --selftest" python3 "$HERE/../eu_evap_opt/analyze.py" --selftest

# CONTEXT.md が実在しないファイル・シンボル・枝を指していないか。
# 別ハーネスに渡す文書で一番害があるのは腐った参照 ── 迷子になるだけでなく
# 「無いのは自分の環境が違うから」と誤解させる。
run "CONTEXT.md の参照が解決する" python3 "$HERE/check_context.py"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "すべて PASS（ただし上の「保証しないもの」を読むこと）"
else
  echo "FAIL あり"
fi
exit "$fail"
