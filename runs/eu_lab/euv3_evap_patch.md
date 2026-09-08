# `euv3.ts` 側の変更（蒸発走査）

`evap_scan.ts` を `lib/evap.ts` に置いた前提。**変更は 3 か所だけ。**

## 1. import と、走査のノブ

```typescript
import { type Axis, type EvapStage, logLine, perturb, scanPlan }
	from "file:///C:/Users/eu_public/workspace/ts/lib/evap.ts";
```

`MODE` の並びの下に置く:

```typescript
/* 蒸発ランプの走査。null なら走査しない（＝いまの挙動）。
 *
 * ★走査するときは MODE = "bec" かつ SPIN_SEPARATION = false にすること。
 *   SG が入った像は m 成分に分かれるので、単峰フィットの幅は雲の大きさではなく
 *   分離幅になり、位相空間密度の代理量が無意味になる。表は普通に見えるので
 *   **気づけない**。 */
const EVAP_SCAN: { axes: Axis[]; batch: number; delta: number } | null = null;
```

走査するときだけ、たとえばこう書き換える（**§陽性対照** を参照）:

```typescript
const EVAP_SCAN = {
	axes: [
		{ kind: "power", stage: 7, beam: "h" },  // 最終段 = 最終トラップ深さ（応答が保証される軸）
		{ kind: "power", stage: 0, beam: "h" },  // 2026-09-03 に null だった軸（継続確認）
	] as Axis[],
	batch: 99,
	delta: 0.15,
};
```

## 2. 蒸発ランプを表にする

いまの 8 行の `euv.fort(...)` を**データに変える**。直書きのままでは摂動できない。

```typescript
/* 蒸発冷却。出なくなったら上から順に触る。
 * ★**下げ方向にしか掃かないこと。** FORT は下げ前提で校正されていて、途中で
 *   締め直すと断熱圧縮で加熱する。（最終トラップは別扱い。下の分岐はそのまま） */
const EVAP: EvapStage[] = [
	{ h: 4 * W, v: 1.8 * W, t: 300 * ms },
	{ h: 2 * W, v: 1.7 * W, t: 500 * ms },
	{ h: 1 * W, v: 1.6 * W, t: 400 * ms },
	{ h: 560 * mW, v: 1.5 * W, t: 600 * ms, note: "ここで hFORT が枯れる" },
	{ h: 260 * mW, v: 1.4 * W, t: 300 * ms },
	{ h: 160 * mW, v: 1 * W, t: 200 * ms, note: "ここで一部 BEC" },
	{ h: 120 * mW, v: 600 * mW, t: 100 * ms },
	{ h: 87 * mW, v: 90 * mW, t: 200 * ms, note: "-> BEC" },
];
```

（`euv3.ts` の外、`sequence` の外に置く。値は今と同じ。）

## 3. 流すところ

8 行の `euv.fort(...)` を、これに置き換える:

```typescript
	/* 走査しないときは trial が基準点なので、perturb は表をそのまま返す
	 * ＝ いまと同じ列が出る（`deno test` の 1 本目がそれを固定している）。 */
	const trial = EVAP_SCAN
		? euv.scan(scanPlan(EVAP_SCAN.axes, EVAP_SCAN.batch))
		: { axis: null, sign: 0 as const };
	const ramp = perturb(EVAP, trial, EVAP_SCAN?.delta ?? 0);
	for (const st of ramp) euv.fort({ h: st.h, v: st.v }, st.t, st.note);

	if (EVAP_SCAN) {
		euv.log(logLine(euv.shot, trial, EVAP_SCAN.delta, ramp, {
			trap: TRAP,
			mode: MODE,
			spinSeparation: SPIN_SEPARATION,
		}));
	}
```

**最終トラップの `if (TRAP === "hh")` はそのまま。** `vh` は h を 87 → 140 mW と
**上げる**ので、単調射影の対象に入れてはいけない（受け渡しであって蒸発ではない）。

---

## 走査しないときに列が変わらないことの根拠

`deno test` の 1 本目「基準点は元の表をそのまま返す」が、`perturb` が基準点で
恒等写像であることを固定している。`EVAP_SCAN = null` なら trial は常に基準点なので、
`euv.fort` に渡る値は今と同じ。

**ただし `euv.fort` を 8 回直書きするのとループで回すのとで、`euv.fort` の実装が
何か違うことをしないか**は lib を見ないと分からない。最初の 1 ショットは
`euv.log` の出力を見て、段の数と値が合っているか確かめること。

---

## 陽性対照 ── 最初にやる batch

**「効かない軸」と「見えていない測定系」は同じ出力を出す。** だから最初は
**物理的に応答が保証された軸**を、効かないと思われる軸と**同じ batch の中で**振る。

- **`stage: 7, beam: "h"`**（最終段 87 mW）= 最終トラップ深さそのもの。
  ここが動かなければ、測定系か目的関数が壊れている ⇒ 手を止める。
- **`stage: 0, beam: "h"`**（段 1、4 W）= 2026-09-03 に `Δ/SE = 1.23` で null
  だった軸。3σ 上限は 3.2 %。

設定: `MODE = "bec"`, `SPIN_SEPARATION = false`, 軸 2 本 × batch 99 →
rep 16、**96 ショット / 約 16 分**。

**これを飛ばして先に進まないこと。**

---

## 解析側

ログを 1 行 1 ショットで拾う:

```bash
grep '^EVAP ' run.log | sed 's/^EVAP //' > evap.jsonl
```

`runs/eu_evap_opt/analyze.py` は CSV を読む形なので、**JSONL → CSV の変換か、
読み込み部の差し替えが要る**。解析の中身（基準点からドリフトと σ を分離し、
軸ごとの時間窓で σ を測り直し、± の対応差を σ で規格化する）はそのまま使える。

必要な列は 2 つの出所を**ショット番号で突き合わせて**作る:

| 列 | 出所 |
|---|---|
| `shot` `axis` `sign` `delta` `h_mW` `v_mW` `t_ms` `sg` | このログ |
| 撮像の時刻・原子数・幅・画像 ID | 撮像系の記録 |

**測定値をシーケンスに持ち込まない**のは意図的 ── ホスト API への依存が増えるし、
撮像系は既に記録しているはずなので。

---

## 未確認（装置で最初に確かめること）

1. **`euv.scan(plan)` が `plan[euv.shot % plan.length]` か。**
   `euv3.ts` の使い方（`euv.scan(angles)` と `Math.floor(euv.shot / angles.length) % 41`）
   からの推測。99 要素を渡して 1 巡するか、ログの `axis` の並びで確かめる。
2. **`euv.log` の出力がファイルに残るか。** 残らないなら `storage` 相当の
   CSV 出力に差し替える（中身は同じで足りる）。
3. **`euv.fort` をループで呼んで直書きと同じ列が出るか**（上記）。
