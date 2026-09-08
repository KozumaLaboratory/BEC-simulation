/**
 * 蒸発ランプの走査 ── シーケンス側に必要な最小限。
 *
 * 置き場所: `lib/evap.ts` に置いて `euv3.ts` から import するか、`euv3.ts` に
 * そのまま貼る。lib 側に置くほうが、走査の有無で `euv3.ts` の差分が小さくなる。
 *
 * ────────────────────────────────────────────────────────────────────
 * 設計: **装置は「出す」と「残す」だけ。判定はオフライン。**
 * ────────────────────────────────────────────────────────────────────
 * 旧 JS 版は目的関数の計算と閉ループ（採用/棄却）まで装置に載せていた。TS では
 * 載せない。理由は 2 つ:
 *
 *   ・**運用が「100 ショット取って外で解析、繰り返す」に決まっている。**
 *     閉ループの利点（人が寝ている間に登る）が要らないなら、装置に載せるのは
 *     リスクだけ。判定が人の目を通らず、壊れた履歴の上で静かに最適化しうる。
 *   ・**σ は同じ batch の中でしか測れない**（下記）。オフラインなら、σ の推定も
 *     ドリフトの除去も判定基準も、データを見てから決め直せる。
 *
 * だからここにあるのは 3 つだけ:
 *   1. ランプを**データ**にする（直書きの `euv.fort` 8 行では摂動できない）
 *   2. 摂動して、**単調性と上下限を射影**する
 *   3. **出した値そのもの**を 1 行に残す（軸番号ではなく値。あとで表を編集しても
 *      過去の行の意味が復元できるように）
 *
 * ────────────────────────────────────────────────────────────────────
 * 走査の形: 3 ショット周期 [基準点, +δ, −δ]
 * ────────────────────────────────────────────────────────────────────
 * この系は不安定で、100 ショット（約 17 分）の間に原子数の水準が動く。
 *
 *   ・**± を隣接させる** → ペアが 1 ショット差なのでドリフトの 1 次が差で落ちる
 *   ・**基準点を 3 ショットごとに挟む** → σ とドリフトを事後に分離できる。
 *     1/3 のショットを払うが、払わないと**その batch は解析不能**になる
 *   ・**σ を別 batch から持ち込まない** → σ 自体が動く（真空度・ロック・MOT の
 *     重なり）。2026-09-03 の実測では同じ 17 分の中で 8.1 %〜12.9 % に動いていた
 *
 * `euv.scan()` はショットごとに配列を巡回するので、走査計画を配列にして渡せば
 * それだけで周期ができる。新しいホスト機能は要らない。
 */

import { mW, ms, W, type Watts } from "file:///C:/Users/eu_public/workspace/ts/lib/units.ts";

/** 段の長さの型。`units.ts` の時間型の名前を知らないので `ms` から取る。 */
type Duration = typeof ms;

/** 蒸発の 1 段。**始値は前段の終値**なので、書くのは終値だけ。 */
export type EvapStage = {
	h: Watts;
	v: Watts;
	t: Duration;
	note?: string;
};

/**
 * 単位付きの量を無次元倍する。
 *
 * ★**`units.ts` の実装に依存する唯一の場所。** `Watts` が
 * `number & {__brand}` のような branded type なら `x * k` は素の `number` に
 * 落ちるので、キャストで型を戻している。`units.ts` が乗算を型付きで定義して
 * いるなら、この関数は消して直接掛けてよい。
 */
const scale = <T extends number>(x: T, k: number): T => (x * k) as T;

/** 走査する軸。`"time"` は全段の長さを一律にスケールする。 */
export type Axis =
	| { kind: "power"; stage: number; beam: "h" | "v" }
	| { kind: "time" };

/** 1 ショットで何をするか。`axis` が `null` なら基準点。 */
export type Trial = { axis: Axis | null; sign: -1 | 0 | 1 };

/**
 * FORT の上限。
 *
 * ★いまは `calibration.volts.{hfort,vfort,sfort}` の**コメント**にしか書いて
 * いない（「// 上限 6.0 W」）。コメントは射影に使えないので、ここに写している ──
 * **写しはいずれ食い違う**。`calibration` に `maxPower: { h, v, s }` を足して
 * ここはそれを読むようにするのが正しい。足すまでの暫定。
 */
export const FORT_MAX = { h: scale(W, 6), v: scale(W, 5.5) };

/** パワーの下限。0 にするとトラップが消えるので、走査では踏ませない。 */
export const FORT_FLOOR = scale(mW, 20);

/** 蒸発が始まる時点の hFORT（`FORT_LOAD_POWER`）。1 段目はこれを超えられない。 */
export const LOAD_POWER = scale(W, 6);

/**
 * 摂動した表を返す。**元の表は変更しない。**
 *
 * ★単調性を落とせない理由: FORT は下げ方向にしか掃かない前提で校正されており、
 *   途中で締め直すと断熱圧縮で加熱する。0-D モデル側でも「トラップを締め直す
 *   最適解は実行するスケジュールに使うな」と明示されている。
 *
 * ★ただし**単調性は蒸発 8 段の中だけ**。そのあとの最終トラップ（`vh` は
 *   h 87 mW → 140 mW と**上げる**）は蒸発ではなく受け渡しなので、この関数の
 *   対象外に置くこと。混ぜると正しい設定が射影で潰される。
 *
 * ★射影は最後に 1 度だけ通す。摂動のたびに局所クランプすると、適用の順番で
 *   結果が変わり「同じ点を撮り直したはずが違う表」になる。
 */
export function perturb(table: readonly EvapStage[], trial: Trial, delta: number): EvapStage[] {
	const out: EvapStage[] = table.map((st) => ({ ...st }));
	const { axis, sign } = trial;

	// ★ここで早期 return してはいけない。最初そう書いて、`time` 軸が下の射影を
	//   まるごと飛ばしていた（δ = 2 で段の長さが負になる）。摂動の種類にかかわらず
	//   射影は必ず通す。
	if (axis?.kind === "time") {
		const k = 1 + sign * delta;
		for (const st of out) st.t = scale(st.t, k);
	}
	if (axis?.kind === "power") {
		const st = out[axis.stage];
		if (st) st[axis.beam] = scale(st[axis.beam], 1 + sign * delta);
	}

	// 上下限 → 単調性の順で 1 度だけ射影する
	for (const beam of ["h", "v"] as const) {
		for (const st of out) {
			if (st[beam] > FORT_MAX[beam]) st[beam] = FORT_MAX[beam];
			if (st[beam] < FORT_FLOOR) st[beam] = FORT_FLOOR;
		}
		// h は 1 段目もロード時のパワーを超えられない。
		// v の 1 段目は 0 → 1.8 W の点灯なので上からの制約が無い（ここで
		// LOAD_POWER と比べると v が 0 に潰れる）。
		if (beam === "h" && out[0] && out[0].h > LOAD_POWER) out[0].h = LOAD_POWER;
		// 前方比較は常に 1 段目の次から。1 段だけ直すと 2 段先で単調性が破れる
		// （V[0] を 1.8→1.53 に下げても V[2]=1.6 が残って上がる）。
		for (let j = 1; j < out.length; j++) {
			if (out[j][beam] > out[j - 1][beam]) out[j][beam] = out[j - 1][beam];
		}
	}
	// 段の長さが 0 以下になると段が壊れる
	for (const st of out) if (!(st.t > 0)) st.t = ms;
	return out;
}

/**
 * 走査計画。`euv.scan(plan)` に渡すとショットごとに 1 つ返る。
 *
 * 1 軸あたり `3 * rep` ショット。`rep` は batch と軸数から**導出**する ──
 * 「1 点あたりの繰り返し数」をノブにすると、99 ショット撮りたい人が 99 と書いて
 * 891 ショット (2.5 h) になる（実際に起きた）。人が考える単位を batch にする。
 *
 * `rep` の下限が 5 なのは、解析側が ± 2 群から σ を作るとき自由度 2(rep−1) が
 * 要るから。rep 3 だと自由度 4 で σ̂ の相対誤差が 35 % になり、判定が意味を失う。
 * **短くしたいなら軸を減らす。rep ではない。**
 */
export function scanPlan(axes: readonly Axis[], batch: number): Trial[] {
	const rep = Math.max(5, Math.floor(batch / (3 * axes.length)));
	const plan: Trial[] = [];
	for (const axis of axes) {
		for (let i = 0; i < rep; i++) {
			plan.push({ axis: null, sign: 0 }); // 基準点
			plan.push({ axis, sign: +1 }); // ± は隣接させる
			plan.push({ axis, sign: -1 });
		}
	}
	return plan;
}

/** 軸を読める名前にする（ログ用）。 */
export function axisName(axis: Axis | null): string {
	if (!axis) return "ref";
	if (axis.kind === "time") return "time";
	return `${axis.beam}${axis.stage + 1}`;
}

/**
 * 1 ショット分の記録。**`euv.log` に流す 1 行。**
 *
 * ★CSV を書くホスト機能に依存していない。ログさえ残ればオフラインで解析できる。
 *   （旧版は `storage.createCSV` を使っていたが、それが TS 側にあるか未確認。
 *   あるなら CSV に流したほうが解析は楽 ── 中身はこの JSON と同じで足りる。）
 *
 * ★残すのは**実際に出した値そのもの**。軸番号だけだと、表を編集したあとで
 *   過去の行が何を意味していたか復元できない。単調射影で 1 軸の摂動が複数段を
 *   動かすので、なおさら値が要る。
 *
 * ★測定値（フィット結果）はここに入れない。撮像系が別に記録しているはずなので、
 *   **ショット番号で突き合わせる**。シーケンスにフィット結果を持ち込もうとすると
 *   ホスト API への依存が増える。
 */
export function logLine(
	shot: number,
	trial: Trial,
	delta: number,
	table: readonly EvapStage[],
	context: { trap: string; mode: string; spinSeparation: boolean },
): string {
	return "EVAP " + JSON.stringify({
		schema: 3,
		shot,
		axis: axisName(trial.axis),
		sign: trial.sign,
		delta,
		// 単位で割って裸の数にする。解析側が単位を知らなくても読めるように
		h_mW: table.map((st) => Math.round(st.h / mW)),
		v_mW: table.map((st) => Math.round(st.v / mW)),
		t_ms: table.map((st) => Math.round(st.t / ms)),
		trap: context.trap,
		mode: context.mode,
		// ★SG が入った像は m 成分に分かれるので、単峰フィットの幅は雲の大きさでは
		//   ない。SG あり/なしの行を混ぜて解析できないので必ず残す。
		sg: context.spinSeparation,
	});
}
