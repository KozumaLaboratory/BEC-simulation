#!/usr/bin/env python3
"""euv4 の evap_opt.csv から蒸発ランプの感度表を出す。

使い方:
    python3 analyze.py evap_opt.csv [more.csv ...]     # 解析
    python3 analyze.py --selftest                      # 自己検査（陽性対照）

--------------------------------------------------------------------------
なぜこの構造なのか
--------------------------------------------------------------------------
この系は不安定で、100 ショット（約 17 分）の間に原子数の水準が動く。だから
euv4 は 3 ショット周期 [基準点, +δ, −δ] でデータを取る。その構造がここでの
解析を決める:

  ・**ドリフトは基準点系列から測る。** 基準点は 3 ショットごとに入るので、
    その時間依存を局所回帰で追える。これが「水準」。
  ・**σ は基準点の残差から測る。** 水準を引いた残りがショット間ばらつき。
    ドリフトを σ に混ぜると σ が膨らみ、本物の感度を見逃す。逆に無視すると
    σ が小さく出て、ドリフトを感度と読む。分離が要点。
  ・**感度は隣接した ± の差から測る。** ペアは 1 ショット差なのでドリフトの
    1 次が落ちる。さらに各ペアを直近の基準点で規格化して、乗算型のゆらぎ
    （原子数のばらつきは割合で効く）も落とす。

出力は ΔN/σ の表。**ほとんどの軸はゼロになるのが正常で、それが結果**
（どの軸を最適化しても無駄かが分かる）。

--------------------------------------------------------------------------
このスクリプトが見えないもの（先に書く）
--------------------------------------------------------------------------
・**凝縮体の個数は分からない。** ホストは単峰 Gauss フィットしか返さない。
  ここで最大化しているのは位相空間密度の代理量 N/(w_x·w_y)^{3/2} で、
  「凝縮しやすさ」であって「凝縮体の数」ではない。BEC が出たあとの微調整に
  使うなら、CSV の rowID から画像に戻って二峰フィットをすること。
・**ドリフトの 2 次以上は落ちない。** ± ペアが落とすのは 1 次まで。水準が
  1 ショットの間に曲がるほど不安定なら、この設計では足りない。基準点系列の
  残差が σ_shot より大きく出たらそれを疑う（下で警告する）。
・**軸間の相互作用は測っていない。** 1 軸ずつ振っているので、2 軸を同時に
  動かしたときの効果は分からない。
"""

import csv
import math
import sys

SCHEMA_EXPECTED = 2
AXIS_NAMES = (
    [f"hFORT 段{i + 1}" for i in range(8)]
    + [f"vFORT 段{i + 1}" for i in range(8)]
    + ["全段の時間スケール"]
)


def load(paths):
    """CSV を読む。ヘッダ行が複数回現れる（batch を継ぎ足した）場合も通す。"""
    rows = []
    schemas = set()
    for path in paths:
        with open(path, newline="", encoding="utf-8") as fh:
            for raw in csv.reader(fh):
                if not raw or raw[0] == "schema":
                    continue
                rows.append(raw)
                schemas.add(raw[0])
    if not rows:
        raise SystemExit("行が 1 つも読めなかった。CSV のパスを確認して。")
    unknown = schemas - {str(SCHEMA_EXPECTED)}
    if unknown:
        raise SystemExit(
            f"想定していない schema {sorted(unknown)} が混ざっている。"
            f"期待は {SCHEMA_EXPECTED}。列が変わっているので、この解析を"
            f"当てる前に euv4 側の EVAP_CSV_SCHEMA を確認して。"
        )
    return rows


COL = {
    "t_ms": 1, "rowID": 2, "mode": 3, "sg": 4, "ctr": 5, "param": 6,
    "sign": 7, "delta": 8, "rep": 9, "nx": 10, "ny": 11, "wx": 12, "wy": 13,
    "obj": 16, "obj_kind": 17,
}


def parse(rows):
    """(t, ctr, param, sign, delta, obj) に落とす。失敗ショットは捨てて数える。

    ★Stern-Gerlach あり／なしの行は **混ぜない**。SG が入った像は m 成分に
      分かれた 13 個の塊なので、ホストの単峰 Gauss フィットが返す幅は雲の
      大きさではなく分離幅。目的関数 N/(w_x·w_y)^{3/2} は位相空間密度と
      無関係になる。ここで弾かないと、表は普通に見えるまま意味を失う。
    """
    good, dropped, sg_seen = [], 0, set()
    for r in rows:
        try:
            obj = float(r[COL["obj"]])
            t = float(r[COL["t_ms"]]) / 1000.0
            sg = int(r[COL["sg"]])
            rec = (t, int(r[COL["ctr"]]), int(r[COL["param"]]),
                   int(r[COL["sign"]]), float(r[COL["delta"]]), obj)
        except (ValueError, IndexError):
            dropped += 1
            continue
        if not (obj > 0) or not math.isfinite(obj):
            dropped += 1
            continue
        sg_seen.add(sg)
        good.append((sg, rec))
    if sg_seen == {0, 1}:
        n1 = sum(1 for (s, _r) in good if s == 1)
        raise SystemExit(
            f"Stern-Gerlach あり ({n1} 行) と なし ({len(good) - n1} 行) が"
            f"混ざっている。SG ありの像は m 成分に分離しているので、単峰フィットの"
            f"幅は雲の大きさではない ── 目的関数が別物になる。混ぜて解析はしない。\n"
            f"SG あり行だけ / なし行だけに分けてから渡して。"
            f"（euv4 の EVAP_SG_MODE = \"auto\" なら最適化モードでは自動で切れる）"
        )
    if sg_seen == {1}:
        print("!! この CSV は Stern-Gerlach ありの行だけ。単峰フィットの幅は")
        print("   m 成分の分離幅で、雲の大きさではない。obj 列は位相空間密度の")
        print("   代理量として使えない ── 以下の感度表は信用しないこと。\n")
    good = [r for (_s, r) in good]
    good.sort(key=lambda x: x[0])
    return good, dropped


def local_level(refs, t, half_width):
    """時刻 t での基準点の水準。窓内の基準点の中央値（外れ値に強い）。"""
    win = [o for (tt, o) in refs if abs(tt - t) <= half_width]
    if not win:
        # 窓が空なら最も近い 3 点で代用する。ここを平均 1 点で埋めると
        # 「測れなかった」と「ばらつきが無い」が区別できなくなる。
        near = sorted(refs, key=lambda p: abs(p[0] - t))[:3]
        if not near:
            return None
        win = [o for (_, o) in near]
    win.sort()
    n = len(win)
    return win[n // 2] if n % 2 else 0.5 * (win[n // 2 - 1] + win[n // 2])


def analyse(recs, half_width=180.0):
    refs = [(t, o) for (t, _c, p, _s, _d, o) in recs if p < 0]
    if len(refs) < 6:
        raise SystemExit(
            f"基準点が {len(refs)} 点しかない。ドリフトと σ を分離できないので"
            f"解析を拒否する。euv4 の EVAP_OPT_MODE が 'sens' か 'noise' に"
            f"なっているか確認して（'off' では全行が基準点扱いになる）。"
        )

    # --- ドリフトと σ の分離 ---
    resid = []
    for t, o in refs:
        lv = local_level(refs, t, half_width)
        if lv:
            resid.append(o / lv - 1.0)
    n = len(resid)
    mean_r = sum(resid) / n
    sigma_rel = math.sqrt(sum((x - mean_r) ** 2 for x in resid) / max(n - 1, 1))
    lv_all = [local_level(refs, t, half_width) for (t, _o) in refs]
    lv_all = [v for v in lv_all if v]
    drift = (max(lv_all) / min(lv_all) - 1.0) if len(lv_all) > 1 else 0.0
    span_min = (refs[-1][0] - refs[0][0]) / 60.0

    print(f"基準点 {len(refs)} 点 / 全 {len(recs)} 点、{span_min:.0f} 分")
    print(f"ショット間ばらつき sigma = {100 * sigma_rel:.1f} %   (水準を引いた残差)")
    print(f"水準のドリフト          = {100 * drift:.1f} %   (窓 {half_width / 60:.0f} 分の中央値の最大/最小)")
    if drift > 3 * sigma_rel:
        print("  !! ドリフトがばらつきの 3 倍を超えている。絶対値の比較は使えない。")
        print("     この解析は ± ペアの差だけを使うので 1 次は落ちているが、")
        print("     2 次が残る可能性がある。batch を短くする方が確実。")

    # --- 軸ごとの感度 ---
    # 時刻も一緒に持つ。σ を軸ごとの時間窓で測り直すため（下記）。
    by_axis = {}
    for t, _c, p, s, d, o in recs:
        if p < 0:
            continue
        lv = local_level(refs, t, half_width)
        if not lv:
            continue
        by_axis.setdefault((p, d), {1: [], -1: []})[s].append((t, o / lv))

    if not by_axis:
        # mode = "off" の行だけを渡すとここに来る（全行が基準点扱い）。
        # 「効く軸が無い」と「軸を振っていない」は別なので、混ぜて報告しない。
        print("\n±δ の行が 1 つも無い。この CSV は基準点だけ ── 感度は測れない。")
        print("上の sigma とドリフトは有効なので、系の安定性の記録としては使える。")
        print("感度を測るには euv4 の EVAP_OPT_MODE を 'sens' にして撮り直す。")
        return sigma_rel, drift, []

    out = []
    sig_by_axis = {}
    for (p, d), arms in sorted(by_axis.items()):
        up = [v for (_t, v) in arms[1]]
        dn = [v for (_t, v) in arms[-1]]
        if not up or not dn:
            out.append((p, d, None, None, len(up), len(dn), None))
            continue
        mu = sum(up) / len(up)
        md = sum(dn) / len(dn)
        # 片側どちらが良いかではなく、両側の差を見る。奇関数成分が感度。
        diff = mu - md

        # ★σ はこの軸を撮った時間窓の中だけで測る。batch 全体でプールしない。
        #
        # σ 自体が動く（真空度、レーザーのロック、MOT の重なり）。99 ショットは
        # 17 分あり、その中で σ が変わっていれば、全体でプールした σ は
        # 「平均的なばらつき」であってどの軸のものでもない。軸ごとに測れば
        # その軸の SE が正しくなり、しかも **σ が動いたかどうか自体が見える**。
        times = [t for (t, _v) in arms[1]] + [t for (t, _v) in arms[-1]]
        t0, t1 = min(times), max(times)
        local_ref = [(t, o) for (t, o) in refs if t0 <= t <= t1]
        if len(local_ref) >= 4:
            res = []
            for t, o in local_ref:
                lv = local_level(refs, t, half_width)
                if lv:
                    res.append(o / lv - 1.0)
            m = sum(res) / len(res)
            s_ax = math.sqrt(sum((x - m) ** 2 for x in res) / max(len(res) - 1, 1))
            # σ̂ 自身の推定誤差ぶん上に寄せる（見誤りの代償が非対称）
            s_ax *= 1 + 1 / math.sqrt(2 * max(len(res) - 1, 1))
        else:
            # 窓内の基準点が足りないときは全体の σ に落とす。落としたことを
            # 表に出す（黙って代用すると「測れた」と読める）。
            s_ax = None
        sig_use = s_ax if s_ax else sigma_rel
        sig_by_axis[(p, d)] = s_ax
        se = sig_use * math.sqrt(1.0 / len(up) + 1.0 / len(dn))
        out.append((p, d, diff, diff / se if se > 0 else None,
                    len(up), len(dn), s_ax))

    print("\n感度表（+δ と −δ の差。基準点で規格化、σ は軸ごとの時間窓で測定）")
    print(f"{'軸':<22} {'δ':>6} {'Δ(相対)':>10} {'Δ/SE':>7} "
          f"{'σ_軸':>6} {'n+':>3} {'n-':>3}  判定")
    ranked = sorted(out, key=lambda r: -abs(r[3] or 0))
    for p, d, diff, z, nu, nd, s_ax in ranked:
        name = AXIS_NAMES[p] if 0 <= p < len(AXIS_NAMES) else f"p{p}"
        stxt = f"{100 * s_ax:.1f}%" if s_ax else "全体"
        if diff is None:
            print(f"{name:<22} {d:>6.3f} {'片側のみ':>10} {'-':>7} "
                  f"{stxt:>6} {nu:>3} {nd:>3}  データ不足")
            continue
        verdict = "効く" if abs(z) > 3 else ("たぶん" if abs(z) > 2 else "ゼロ")
        arrow = "" if abs(z) <= 2 else ("  → " + ("+δ 側" if diff > 0 else "−δ 側"))
        print(f"{name:<22} {d:>6.3f} {diff:>+10.3f} {z:>+7.2f} "
              f"{stxt:>6} {nu:>3} {nd:>3}  {verdict}{arrow}")

    # σ が軸の間で動いているかを明示する。動いていれば「全体の σ」は
    # どの軸のものでもないので、使い回してはいけないことの証拠になる。
    got = [s for s in sig_by_axis.values() if s]
    if len(got) >= 2:
        lo, hi = min(got), max(got)
        print(f"\nσ は軸の間で {100 * lo:.1f} % 〜 {100 * hi:.1f} % に動いている"
              f"（全体プールは {100 * sigma_rel:.1f} %）")
        if hi > 1.5 * lo:
            print("  !! σ が 1.5 倍以上動いている。**別の batch で測った σ を"
                  "持ち込んではいけない**。判定は必ず同じ batch の σ で。")

    live = [r for r in ranked if r[3] and abs(r[3]) > 3]
    print()
    if not live:
        print("3σ を超えた軸は無い。この batch では **どの軸も効いていない**。")
        print("次の手は 2 つ: δ を大きくする（いまの δ では応答が σ に埋もれている）、")
        print("または別の軸に移る。REP を増やすのは SE が √n でしか縮まないので割が悪い。")
    else:
        print("3σ を超えた軸:")
        for p, d, diff, z, _nu, _nd, _s in live:
            name = AXIS_NAMES[p] if 0 <= p < len(AXIS_NAMES) else f"p{p}"
            side = "+" if diff > 0 else "-"
            print(f"  {name}: {side}δ 側が {abs(diff) * 100:.1f} % 良い (Δ/SE = {z:+.1f})")
        print("次の batch では、この軸をその向きに 1 歩動かした表を基準点にして測り直す。")
        print("同じ batch の中で歩かないこと ── 歩くと基準点が変わり、σ の意味が変わる。")
    return sigma_rel, drift, ranked


def selftest():
    """既知の感度とドリフトを入れた合成 CSV を作り、回収できるかを見る。

    これが無いと、表に並んだ数字が「測れた結果」なのか「読めていないだけ」なのか
    区別できない。陽性対照（効く軸を入れて検出できるか）と陰性対照（効かない軸を
    ゼロと言えるか）を同時に見る。
    """
    import random
    random.seed(7)
    axes = [0, 8, 16]
    true_sens = {0: 0.30, 8: 0.0, 16: 0.0}   # 軸 0 だけが効く
    sigma, drift_per_min = 0.08, 0.15         # 8 % ばらつき、15 %/分 の右下がり
    rows, ctr, t = [], 0, 0.0
    rep = 11
    for ax in axes:
        for _ in range(rep):
            for slot in range(3):
                p = -1 if slot == 0 else ax
                s = 0 if slot == 0 else (1 if slot == 1 else -1)
                base = 1.0e5 * (1.0 - drift_per_min * t / 60.0 / 10.0)
                eff = 1.0 + (true_sens[ax] * s / 2.0 if p >= 0 else 0.0)
                obj = base * eff * (1.0 + sigma * random.gauss(0, 1))
                rows.append([str(SCHEMA_EXPECTED), f"{t * 1000:.0f}", f"r{ctr}",
                             "sens", "0", str(ctr), str(p), str(s), "0.150", "0",
                             f"{obj:.1f}", "0", "1", "1", "0", "0",
                             f"{obj:.4f}", "psd", "", "", "", "", "5000", "false"])
                ctr += 1
                t += 10.0
    print("=== 自己検査 ===")
    print(f"仕込んだ真値: 軸 0 の感度 30 %、軸 8 と 16 は 0、σ = {sigma * 100:.0f} %、"
          f"ドリフト {drift_per_min * 100:.0f} %/10 分")
    recs, dropped = parse(rows)
    print(f"読めた {len(recs)} 行、捨てた {dropped} 行\n")
    sig, dr, ranked = analyse(recs)
    top = ranked[0]
    ok = (top[0] == 0 and abs(top[3] or 0) > 3
          and abs(sig - sigma) < 0.03
          and all(abs(r[3] or 0) < 3 for r in ranked if r[0] != 0))
    print("\n判定:", "回収できた -> ok" if ok else "FAIL（真値を回収できていない）")
    return 0 if ok else 1


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if args[0] == "--selftest":
        return selftest()
    rows = load(args)
    recs, dropped = parse(rows)
    print(f"読めた {len(recs)} 行、捨てた {dropped} 行"
          f"（フィット不良・欠損）\n")
    if dropped > 0.2 * (len(recs) + dropped):
        print("!! 2 割以上を捨てている。撮像かフィットが不調な可能性。")
        print("   rowID から画像を見て、捨てた条件に偏りが無いか確認して。\n")
    analyse(recs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
