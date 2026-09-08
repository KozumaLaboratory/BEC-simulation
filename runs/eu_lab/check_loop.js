// 閉ループを合成した応答の上で回す。
//
// なぜ必要か: 装置で回すと 1 巡 3 時間かかる。ループが「登る」ことも「登らない
// 軸を放置する」ことも、ここで確かめないと現地で分からない。
//
// 合成モデルは 2 軸だけが効く: 全体時間スケール x[16] と 1 段目の hFORT x[0]。
// どちらも最適が 0.5（= 半分にすると良い ── 事前研究が言う方向）。残り 15 軸は
// 目的関数に一切入らない。だから正しいループは:
//   (1) x[16] と x[0] を 0.5 に向けて動かす
//   (2) 残り 15 軸を 1.0 のまま放置する（σ の門が効いている証拠）
// (2) が壊れているループはノイズを信号として拾っており、装置では 3 時間かけて
// でたらめな表を作る。これは (1) より重要な性質。
var fs = require('fs');
var src = fs.readFileSync(process.argv[2], 'utf8');
var APPEND = process.argv[3] === 'append';// getPoints の 2 通りの意味論を両方試す
var NOISE = parseFloat(process.argv[4] || '0.05');

function grab(re) { var m = src.match(re); if (!m) { throw new Error('missing ' + re); } return m[0]; }

// ---- ホストのスタブ ----
// Node では識別子 `global` は globalThis.global を指すので、それをスタブに
// 差し替えると以降の `global.imageData = ...` がスタブ側に入ってしまう。
// 注入先は G に捕まえておく。シーケンス本体は 25 行目で
//   var global = Packages.labview.Global;
// としているので、被験コードから見える `global` はこの lv スタブになる。
var G = globalThis;
var store = {};// name -> [[x,y],...]
var lv = {
  addPoint: function (name, x, y) {
    if (!store[name]) { store[name] = []; }
    if (APPEND) { store[name].push([x, y]); return; }
    for (var i = 0; i < store[name].length; i++) {
      if (store[name][i][0] === x) { store[name][i][1] = y; return; }
    }
    store[name].push([x, y]);
  },
  getPoints: function (name) { return store[name] || []; }
};
function f() {}
G.global = lv;
G.imageData = { atoms: 0, fitNumberX: 0, fitNumberY: 0, fitWidthX: 1, fitWidthY: 1 };
G.storage = { createCSV: function () { return { put: f }; } };
G.gui = { getGraphFactory: function () { return { createOrLoadGraph: function () {
  return { clearData: f, setTitle: f, setHorizontalLabel: f, setVerticalLabel: f,
           addListPlot: f, show: f, setHorizontalLog: f, setVerticalLog: f }; } }; } };
var logLines = [];
G.console = { log: function (s) { logLines.push(String(s)); } };
G.ctr = 0;

// ---- 被験コード ----
var pre = [
  grab(/var FORT_CAL = \{[\s\S]*?\};/m),
  grab(/var EVAP_OPT_MODE[\s\S]*?var EVAP_OBJ = "psd";[^\n]*/m),
  grab(/var EVAP_OPT_NPAR = \d+;/m),
  grab(/var EVAP_OPT_AXES = \[[^\]]*\];/m),
  grab(/var evapGet = function[\s\S]*?\n\};/m),
  grab(/var evapGetAt = function[\s\S]*?\n\};/m),
  grab(/var evapPut = function[^\n]*\n/m),
  grab(/(?:var EV_[A-Z]+ *= *\d+;[^\n]*\n)+/m),
  grab(/var evapReadX = function[\s\S]*?\n\};/m),
  grab(/var evapRep = function[\s\S]*?\n\};/m),
  grab(/var evapOptPlan = function[\s\S]*?\n\};/m),
  grab(/var evapObjective = function[\s\S]*?\n\};/m),
  grab(/var evapPerturb = function[\s\S]*?\n\};/m),
  grab(/var evapOptStep = function[\s\S]*?\n\};/m),
].join('\n');
(0, eval)(pre);
var tbl = grab(/var EVAP_START = \[[\s\S]*?\n\t\];/m);
(0, eval)(tbl.replace(/\bvar EVAP_START\b/, 'var START').replace(/\bvar EVAP\b/, 'var BASE'));

// ---- 合成応答 ----
// 決定論的な擬似乱数（Math.random は使わない ── 落ちたとき再現できないため）
// xorshift32。前は LCG (mod 2^31) を Box-Muller に入れていたが、LCG の下位ビットは
// 相関が強く、連続値を sin/cos に入れると分布が歪む。ハーネスのノイズが本当に
// 指定した大きさかは下で実測して表示する（校正しない測定器は測定器ではない）。
var seed = parseInt(process.argv[6] || "2463534242", 10) >>> 0;
function rnd() {
  seed ^= seed << 13; seed >>>= 0;
  seed ^= seed >>> 17;
  seed ^= seed << 5;  seed >>>= 0;
  return seed / 4294967296;
}
function gauss() {
  var u = rnd(), v = rnd();
  if (u < 1e-12) { u = 1e-12; }
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
// ハーネスのノイズを実測する
(function () {
  var n = 20000, s = 0, s2 = 0, i, g;
  for (i = 0; i < n; i++) { g = gauss(); s += g; s2 += g * g; }
  var m = s / n, sd = Math.sqrt(s2 / n - m * m);
  process.stdout.write('ハーネスのノイズ実測: mean ' + m.toFixed(4)
                       + ', sd ' + sd.toFixed(4) + '  (期待 0, 1)\n');
}());

var BASE_T = 0, i0;
for (i0 = 0; i0 < BASE.length; i0++) { BASE_T += BASE[i0][2]; }
var BASE_H0 = BASE[0][0];
function respond(table) {
  var T = 0, i;
  for (i = 0; i < table.length; i++) { T += table[i][2]; }
  var rt = T / BASE_T;          // 1.0 が基準、最適 0.5
  var rh = table[0][0] / BASE_H0;
  // 0.5 に頂点を持つ滑らかな山。1.0 では 1.0、0.5 で 2.0。
  var g = function (r) { return 2.0 - 4.0 * (r - 0.5) * (r - 0.5); };
  var val = (process.argv[7] === 'null') ? 1.0e5
                                        : 1.0e5 * g(rt) * g(rh) / (g(1) * g(1));
  return val * (1 + NOISE * gauss());
}

// ---- ショットを回す ----
var NSHOT = parseInt(process.argv[5] || '4000', 10);
var NBLOCK = 0, NACCEPT = 0;
var s;
for (s = 0; s < NSHOT; s++) {
  G.ctr = s;
  var plan = evapOptPlan('search', s);
  var x = evapReadX();
  var delta = evapGetAt('evap_st', EV_DELTA, EVAP_OPT_DELTA);
  var t = evapPerturb(START, BASE, x, plan[0], plan[1], delta);
  var v = respond(t);
  G.imageData.fitNumberX = v; G.imageData.atoms = v;
  G.imageData.fitWidthX = 1; G.imageData.fitWidthY = 1;
  var phBefore = evapGetAt('evap_st', 0, 0);
  var accBefore = evapGetAt('evap_st', 6, 0);
  var nbBefore = evapGetAt('evap_st', 2, 0);
  evapOptStep('search', plan);
  if (evapGetAt('evap_st', 2, 0) === 0 && nbBefore > 0) { NBLOCK++; }
  if (evapGetAt('evap_st', 6, 0) > accBefore) { NACCEPT++; }
}

// ---- 判定 ----
var xf = evapReadX();
var phase = evapGetAt('evap_st', EV_PHASE, 1);
console_out('意味論: ' + (APPEND ? 'addPoint は追記' : 'addPoint は上書き')
            + ' / ノイズ ' + (NOISE * 100).toFixed(0) + ' % / ' + NSHOT + ' ショット');
console_out('phase = ' + phase + '  (2 = 収束)');
console_out('効く軸   x[0]  = ' + xf[0].toFixed(3) + '   (真の最適 0.5)');
console_out('効く軸   x[16] = ' + xf[16].toFixed(3) + '   (真の最適 0.5)');
var moved = [], j;
for (j = 1; j < 16; j++) { if (Math.abs(xf[j] - 1.0) > 1e-9) { moved.push('x[' + j + ']=' + xf[j].toFixed(3)); } }
console_out('効かない 15 軸のうち動いたもの: ' + (moved.length ? moved.join(' ') : 'なし'));
// σ の見積もりが実際のばらつきと合っているか
var best = respond(evapPerturb(START, BASE, xf, -1, 0, 0)) ;// 最終 x での応答（ノイズ 1 発）
console_out('best = ' + best.toPrecision(4) + '  (基準 1.000e5, 真の最大 4.0e5)');

var drift = 0;
var jlo = (process.argv[7] === 'null') ? 0 : 1;
var jhi = (process.argv[7] === 'null') ? 17 : 16;
for (j = jlo; j < jhi; j++) { if (Math.abs(xf[j] - 1.0) > drift) { drift = Math.abs(xf[j] - 1.0); } }
var reached = best / 4.0e5;
console_out('到達率 best/真の最大 = ' + reached.toFixed(3));
console_out('効かない軸の最大漂流 = ' + drift.toFixed(3) + '  (誤採用 ' + moved.length + ' 本)');
// 判定基準:
//  (a) 目的関数が真の最大の 95 % 以上 -> 登れている
//  (b) 効かない軸の漂流が 0.12 未満 -> 誤採用が「1〜2 歩」に留まり系統的でない
// 誤採用ゼロは要求しない。両側 3σ で 400 ブロックなら期待 1.1 件で、
// ゼロを要求する基準は 3σ という設計自体と矛盾する。
var ok = (reached > 0.95) && (drift < 0.12);
console_out('ブロック ' + NBLOCK + ' 回、採用 ' + NACCEPT + ' 件 -> 採用率 '
            + (NBLOCK ? (NACCEPT / NBLOCK).toFixed(4) : 'n/a'));
var acc = [];
for (var L = 0; L < logLines.length; L++) {
  var m = logLines[L].match(/p(\d+) 採用 sign=(-?\d+)/);
  if (m) { acc.push('p' + m[1] + (m[2] === '1' ? '+' : '-')); }
}
console_out('採用の内訳: ' + acc.join(' '));
console_out(ok ? 'PASS' : 'FAIL');
function console_out(s) { process.stdout.write(s + '\n'); }
process.exit(ok ? 0 : 1);
