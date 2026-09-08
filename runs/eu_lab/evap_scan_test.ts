/**
 * `evap_scan.ts` の振る舞いの検査。`deno test` で走る。
 *
 * **型検査は単調性を見ない。** 単位の取り違えは型が捕まえるが、「トラップを
 * 締め直す表を出してしまう」「基準点が入っていない」「± が同数でない」は
 * 実行して確かめるしかない。旧 JS 版ではこの種のバグを 2 度入れ、2 度とも
 * 同じ検査が捕まえた。
 *
 * 各検査に**陽性対照**を付けてある ── 検出できない検査は検査ではない。
 *
 * 走らせ方（lib のパスを解決できる環境で）:
 *     deno test --allow-none evap_scan_test.ts
 */

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert";
import { mW, ms, W } from "file:///C:/Users/eu_public/workspace/ts/lib/units.ts";
import {
	type Axis,
	axisName,
	type EvapStage,
	FORT_FLOOR,
	FORT_MAX,
	LOAD_POWER,
	logLine,
	perturb,
	scanPlan,
	type Trial,
} from "./evap_scan.ts";

/** 現行の蒸発ランプ（`euv3.ts` の `euv.fort` 8 行と同じ値）。 */
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

const ALL_AXES: Axis[] = [
	...[0, 1, 2, 3, 4, 5, 6, 7].map((stage) => ({ kind: "power", stage, beam: "h" } as const)),
	...[0, 1, 2, 3, 4, 5, 6, 7].map((stage) => ({ kind: "power", stage, beam: "v" } as const)),
	{ kind: "time" },
];

/** 表が「下げ方向だけ」「上下限の内側」かを見る。違反を並べて返す。 */
function violations(table: readonly EvapStage[]): string[] {
	const bad: string[] = [];
	for (const beam of ["h", "v"] as const) {
		for (let j = 0; j < table.length; j++) {
			const x = table[j][beam];
			if (x > FORT_MAX[beam] + 1e-12) bad.push(`${beam}[${j}] が上限超過`);
			if (x < FORT_FLOOR - 1e-12) bad.push(`${beam}[${j}] が下限未満`);
			if (j > 0 && x > table[j - 1][beam] + 1e-12) {
				bad.push(`${beam} が非単調: ${table[j - 1][beam]} -> ${x}`);
			}
		}
		if (beam === "h" && table[0].h > LOAD_POWER + 1e-12) bad.push("h[0] がロード時を超過");
	}
	for (let j = 0; j < table.length; j++) if (!(table[j].t > 0)) bad.push(`t[${j}] が非正`);
	return bad;
}

Deno.test("基準点は元の表をそのまま返す（= 走査 off が無影響であることの根拠）", () => {
	const ref = perturb(EVAP, { axis: null, sign: 0 }, 0.15);
	assertEquals(ref.length, EVAP.length);
	for (let i = 0; i < EVAP.length; i++) {
		assertAlmostEquals(ref[i].h, EVAP[i].h, 1e-15);
		assertAlmostEquals(ref[i].v, EVAP[i].v, 1e-15);
		assertAlmostEquals(ref[i].t, EVAP[i].t, 1e-15);
	}
	// 元の表を壊していないこと（不変性）
	assertAlmostEquals(EVAP[3].h, 560 * mW, 1e-15);
});

Deno.test("全軸 × 両符号で、単調性・上下限を破らない", () => {
	const bad: string[] = [];
	for (const axis of ALL_AXES) {
		for (const sign of [+1, -1] as const) {
			bad.push(...violations(perturb(EVAP, { axis, sign }, 0.15)).map((m) => `${axisName(axis)}${sign > 0 ? "+" : "-"}: ${m}`));
		}
	}
	assertEquals(bad, [], `違反:\n${bad.join("\n")}`);
});

Deno.test("陽性対照: 射影しない実装なら違反が出る（検査が働いている証拠）", () => {
	// 射影を外した素朴な摂動。これで違反が 0 なら、上の検査は何も見ていない。
	//
	// ★**v を使う。** 最初 h で書いて、壊れた実装でも違反が 0 件だった ── h の
	//   段差は約 2 倍あるので ±15 % では隣を跨げない。v は 1.8→1.7→1.6 と刻みが
	//   細かいので、1.8 を 15 % 下げると 1.53 になって 1.7 を割る。これは過去に
	//   実際に入れたバグの形そのもの。**対照は「壊れ方が起きうる場所」で取る。**
	const naive = (stage: number, sign: number): EvapStage[] => {
		const out = EVAP.map((st) => ({ ...st }));
		out[stage].v = out[stage].v * (1 + sign * 0.15);
		return out;
	};
	let n = 0;
	for (let stage = 0; stage < EVAP.length; stage++) n += violations(naive(stage, -1)).length;
	assert(n > 0, "射影なしでも違反が出ない ── 検査が働いていない");
});

Deno.test("大きい δ でも壊れない（上限・下限に当たる領域）", () => {
	for (const delta of [0.5, 0.9, 2.0]) {
		for (const axis of ALL_AXES) {
			for (const sign of [+1, -1] as const) {
				const bad = violations(perturb(EVAP, { axis, sign }, delta));
				assertEquals(bad, [], `delta=${delta} ${axisName(axis)}: ${bad.join(", ")}`);
			}
		}
	}
});

Deno.test("走査計画: 基準点 1/3、± 同数、± が隣接", () => {
	const axes = ALL_AXES.slice(0, 3);
	const plan = scanPlan(axes, 99);
	assertEquals(plan.length, 99, "batch 99 / 軸 3 本 -> 99 ショット");

	const refs = plan.filter((p) => p.axis === null).length;
	assertEquals(refs, 33, "基準点は 1/3");

	for (const axis of axes) {
		const name = axisName(axis);
		const mine = plan.filter((p) => p.axis && axisName(p.axis) === name);
		assertEquals(mine.length, 22, `${name}: 各軸 2*rep ショット`);
		assertEquals(mine.reduce((a, p) => a + p.sign, 0), 0, `${name}: ± が同数`);
	}

	// ± が基準点をまたがず隣接して交替する（ドリフトの 1 次が差で落ちる条件）
	let prev: Trial | null = null;
	for (const p of plan) {
		if (p.axis === null) { prev = null; continue; }
		if (prev) assert(prev.sign !== p.sign, "同じ符号が連続している");
		prev = p;
	}
});

Deno.test("rep の下限: 軸を増やしても自由度を割らない（batch は伸びる）", () => {
	// 軸 8 本 × batch 99 なら rep=4 になるところ、下限 5 で 120 ショットに伸びる。
	// **黙って自由度を割るより、batch が伸びるほうが安全。**
	const plan = scanPlan(ALL_AXES.slice(0, 8), 99);
	assertEquals(plan.length, 8 * 3 * 5, "rep が 5 に持ち上げられる");
});

Deno.test("記録は「実際に出した値」を持つ（軸番号だけでは復元できない）", () => {
	const axis = ALL_AXES[0]; // h 段1
	const table = perturb(EVAP, { axis, sign: +1 }, 0.15);
	const line = logLine(7, { axis, sign: +1 }, 0.15, table, {
		trap: "hh",
		mode: "bec",
		spinSeparation: false,
	});
	assert(line.startsWith("EVAP "), "接頭辞で grep できること");
	const rec = JSON.parse(line.slice(5));
	assertEquals(rec.shot, 7);
	assertEquals(rec.axis, "h1");
	assertEquals(rec.sign, 1);
	assertEquals(rec.sg, false, "SG の有無は必ず残る（混ぜて解析できないので）");
	assertEquals(rec.h_mW.length, EVAP.length);
	assertEquals(rec.h_mW[0], 4600, "+15 % が値として残っている");
	assertEquals(rec.h_mW[1], 2000, "触っていない段はそのまま");
	assertEquals(rec.t_ms[0], 300);
});

Deno.test("time 軸は全段を一律にスケールし、パワーを動かさない", () => {
	const table = perturb(EVAP, { axis: { kind: "time" }, sign: -1 }, 0.5);
	const total = table.reduce((a, st) => a + st.t, 0);
	const base = EVAP.reduce((a, st) => a + st.t, 0);
	assertAlmostEquals(total / base, 0.5, 1e-12);
	for (let i = 0; i < EVAP.length; i++) assertAlmostEquals(table[i].h, EVAP[i].h, 1e-15);
});
